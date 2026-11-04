import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AccountError: LocalizedError {
    case invalidUsername
    case usernameTaken
    case notSignedIn
    case missingEmail

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Usernames must be 3–20 characters, start with a letter, and use only letters, numbers, or underscores."
        case .usernameTaken: return "That username is already taken."
        case .notSignedIn:   return "You need to be signed in to do that."
        case .missingEmail:  return "This account has no email address."
        }
    }
}

/// All account CRUD against Firebase Auth + Firestore.
/// Collections used: users/{uid}, users/{uid}/friends, usernames/{username}
final class AccountService {
    static let shared = AccountService()
    private init() {}

    private let db = Firestore.app
    private var auth: Auth { Auth.auth() }

    private var users: CollectionReference { db.collection("users") }
    private var usernames: CollectionReference { db.collection("usernames") }

    private static let takenDomain = "AccountService.usernameTaken"

    // MARK: - Username helpers

    static func normalize(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(username: String) -> Bool {
        username.range(of: "^[a-z][a-z0-9_]{2,19}$", options: .regularExpression) != nil
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let name = Self.normalize(username)
        guard Self.isValid(username: name) else { throw AccountError.invalidUsername }
        return !(try await usernames.document(name).getDocument().exists)
    }

    // MARK: - Create (sign up)

    /// Creates the Auth user, then atomically writes usernames/{username} + users/{uid}.
    /// If the Firestore write fails, the Auth user is removed so no half-made account is left.
    @discardableResult
    func signUp(email: String, password: String, username: String, displayName: String) async throws -> String {
        let name = Self.normalize(username)
        guard Self.isValid(username: name) else { throw AccountError.invalidUsername }
        guard try await isUsernameAvailable(name) else { throw AccountError.usernameTaken }

        let result = try await auth.createUser(withEmail: email, password: password)
        let uid = result.user.uid
        do {
            let profile = UserProfile(
                username: name,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: Date(),
                notificationPreferences: .default
            )
            try await createProfile(uid: uid, profile: profile)
        } catch {
            try? await result.user.delete()
            throw error
        }
        return uid
    }

    private func createProfile(uid: String, profile: UserProfile) async throws {
        let profileData = try Firestore.Encoder().encode(profile)
        let claimData = try Firestore.Encoder().encode(UsernameClaim(userId: uid))
        let claimRef = usernames.document(profile.username)
        let userRef = users.document(uid)

        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    if try transaction.getDocument(claimRef).exists {
                        errorPointer?.pointee = NSError(domain: Self.takenDomain, code: 1)
                        return nil
                    }
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                transaction.setData(claimData, forDocument: claimRef)
                transaction.setData(profileData, forDocument: userRef)
                return nil
            }
        } catch let error as NSError where error.domain == Self.takenDomain {
            throw AccountError.usernameTaken
        }
    }

    // MARK: - Sign in / out / reset

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    // MARK: - Read

    func fetchProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await users.document(uid).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UserProfile.self)
    }

    // MARK: - Update

    func updateDisplayName(uid: String, to newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await users.document(uid).updateData(["display_name": trimmed])
    }

    func updateNotificationPreferences(uid: String, to prefs: NotificationPreferences) async throws {
        let data = try Firestore.Encoder().encode(prefs)
        try await users.document(uid).updateData(["notification_preferences": data])
    }

    /// Atomically: claim the new username, release the old one, update the profile.
    func changeUsername(uid: String, from oldUsername: String, to newUsername: String) async throws {
        let newName = Self.normalize(newUsername)
        let oldName = Self.normalize(oldUsername)
        guard Self.isValid(username: newName) else { throw AccountError.invalidUsername }
        if newName == oldName { return }

        let claimData = try Firestore.Encoder().encode(UsernameClaim(userId: uid))
        let newRef = usernames.document(newName)
        let oldRef = usernames.document(oldName)
        let userRef = users.document(uid)

        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    if try transaction.getDocument(newRef).exists {
                        errorPointer?.pointee = NSError(domain: Self.takenDomain, code: 1)
                        return nil
                    }
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                transaction.setData(claimData, forDocument: newRef)
                transaction.deleteDocument(oldRef)
                transaction.updateData(["username": newName], forDocument: userRef)
                return nil
            }
        } catch let error as NSError where error.domain == Self.takenDomain {
            throw AccountError.usernameTaken
        }
    }

    /// Email and password live in Firebase Auth, not Firestore. Both need a recent login.
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let user = try await reauthenticate(password: currentPassword)
        try await user.updatePassword(to: newPassword)
    }

    /// Firebase emails a verification link to the new address; the change applies once it's clicked.
    func requestEmailChange(currentPassword: String, newEmail: String) async throws {
        let user = try await reauthenticate(password: currentPassword)
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }

    // MARK: - Delete

    /// Removes friendships, the username claim, the profile, then the Auth user.
    /// (Reauth happens first so the final Auth delete won't fail after data is gone.)
    func deleteAccount(currentPassword: String) async throws {
        let user = try await reauthenticate(password: currentPassword)
        let uid = user.uid

        let profile = try await fetchProfile(uid: uid)
        let friends = try await users.document(uid).collection("friends").getDocuments()

        let batch = db.batch()
        friends.documents.forEach { batch.deleteDocument($0.reference) }
        if let username = profile?.username {
            batch.deleteDocument(usernames.document(username))
        }
        batch.deleteDocument(users.document(uid))
        try await batch.commit()

        try await user.delete()
    }

    // MARK: - Private

    private func reauthenticate(password: String) async throws -> User {
        guard let user = auth.currentUser else { throw AccountError.notSignedIn }
        guard let email = user.email else { throw AccountError.missingEmail }
        try await user.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
        return user
    }
}
