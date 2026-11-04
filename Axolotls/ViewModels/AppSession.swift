import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// The logged-in / logged-out state everyone else relies on.
/// Inject once at the app root; read from any view with:
///     @EnvironmentObject var session: AppSession
/// Teammates use `session.userID` (B: creator/joiner, C: photographer_id, D: guesses).
@MainActor
final class AppSession: ObservableObject {
    enum State { case loading, signedOut, signedIn }
    
    @Published private(set) var state: State = .loading
    @Published private(set) var userID: String?
    @Published private(set) var email: String?
    @Published private(set) var profile: UserProfile?
    
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?
    
    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            let email = user?.email
            Task { @MainActor in self?.handleAuthChange(uid: uid, email: email) }
        }
    }
    
    private func handleAuthChange(uid: String?, email: String?) {
        profileListener?.remove()
        profileListener = nil
        
        guard let uid else {
            userID = nil
            self.email = nil
            profile = nil
            state = .signedOut
            return
        }
        
        userID = uid
        self.email = email
        state = .signedIn
        
        // Live-updates the profile so Settings and other screens always show current data.
        profileListener = Firestore.app.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Profile listener error: \(error)")
                }
                let decoded: UserProfile? = (snapshot?.exists ?? false)
                ? try? snapshot?.data(as: UserProfile.self) : nil
                Task { @MainActor in self?.profile = decoded }
            }
        
        /// Convenience for teammates who need a non-optional ID after sign-in.
        var requireUserID: String {
            guard let userID else { fatalError("requireUserID called while signed out") }
            return userID
        }
        
        func signOut() {
            try? AccountService.shared.signOut()
        }
    }
}
