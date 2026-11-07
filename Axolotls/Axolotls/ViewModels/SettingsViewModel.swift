
import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Profile

    @Published var displayName = ""
    @Published var username = ""

    // MARK: - Notification Preferences

    struct NotificationPreferences: Equatable {
        var groupInviteNotificationsEnabled = true
        var photosAvailableNotificationsEnabled = true
        var questNotificationsEnabled = true
    }

    @Published var prefs = NotificationPreferences()

    // MARK: - Account Security

    @Published var currentPassword = ""
    @Published var newEmail = ""
    @Published var newPassword = ""

    // MARK: - UI State

    @Published var isWorking = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var message: String?
    @Published var didDeleteAccount = false

    var isError: Bool {
        errorMessage != nil
    }

    // MARK: - Profile Management

    func profileChanged(from profile: Any?) -> Bool {
        // Connect this comparison to your UserProfile model.
        return true
    }

    func saveProfile(uid: String, profile: Any?) async {
        isWorking = true
        errorMessage = nil
        message = nil
        defer { isWorking = false }

        // TODO: Save displayName and username to Firestore.
        errorMessage = "Profile saving has not been connected to Firestore yet."
    }

    // MARK: - Notification Preferences

    func prefsChanged(from profile: Any?) -> Bool {
        return true
    }

    func savePreferences(uid: String) async {
        isWorking = true
        errorMessage = nil
        message = nil
        defer { isWorking = false }

        // TODO: Save notification preferences to Firestore.
        errorMessage = "Preference saving has not been connected to Firestore yet."
    }

    // MARK: - Change Email

    func changeEmail() async {
        isWorking = true
        errorMessage = nil
        message = nil
        defer { isWorking = false }

        guard !newEmail.isEmpty, !currentPassword.isEmpty else {
            errorMessage = "Please enter your new email and current password."
            return
        }

        // TODO: Connect to Firebase Auth email update.
        errorMessage = "Email updating has not been connected to Firebase yet."
    }

    // MARK: - Change Password

    func changePassword() async {
        isWorking = true
        errorMessage = nil
        message = nil
        defer { isWorking = false }

        guard !newPassword.isEmpty, newPassword.count >= 6 else {
            errorMessage = "Your new password must contain at least 6 characters."
            return
        }

        guard !currentPassword.isEmpty else {
            errorMessage = "Please enter your current password."
            return
        }

        // TODO: Connect to Firebase Auth password update.
        errorMessage = "Password updating has not been connected to Firebase yet."
    }

    // MARK: - Delete Account

    func deleteAccount(session: AppSession) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        // TODO: Reauthenticate and delete the Firebase account.
        errorMessage = "Account deletion has not been connected to Firebase yet."
    }

    // MARK: - Sign Out

    func signOut(session: AppSession) {
        do {
            try AccountService.shared.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Clear Messages

    func clearError() {
        errorMessage = nil
    }

    func clearMessage() {
        message = nil
    }
}

