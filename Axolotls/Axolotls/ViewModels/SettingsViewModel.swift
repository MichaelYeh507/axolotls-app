import Foundation
import Combine

// The model type from Models/UserProfile.swift. The view model below declares its own nested
// `NotificationPreferences`, which would hide the model inside the class, so we alias it here.
private typealias StoredNotificationPreferences = NotificationPreferences

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

    /// The form is filled from the saved profile once. After that the user's own edits stay put
    /// (so a toggle you turn off is not flipped back by a late Firestore update).
    private var didLoad = false
    /// The toggle values that are known to be saved in Firestore.
    private var savedPrefs = NotificationPreferences()

    // MARK: - Load saved values into the form

    /// Copies the user's saved profile into the form fields.
    /// Call from the view: `.onAppear { vm.load(from: session.profile) }`
    /// and `.onChange(of: session.profile) { _, p in vm.load(from: p) }`.
    func load(from profile: Any?) {
        guard !didLoad, let profile = profile as? UserProfile else { return }
        didLoad = true
        displayName = profile.displayName
        username = profile.username
        prefs = NotificationPreferences(
            groupInviteNotificationsEnabled: profile.notificationPreferences.groupInviteNotificationsEnabled,
            photosAvailableNotificationsEnabled: profile.notificationPreferences.photosAvailableNotificationsEnabled,
            questNotificationsEnabled: profile.notificationPreferences.questNotificationsEnabled
        )
        savedPrefs = prefs
    }

    // MARK: - Profile Management

    /// True when the form differs from the saved profile.
    /// If no profile is available yet, stays true so the Save button isn't stuck disabled.
    func profileChanged(from profile: Any?) -> Bool {
        guard let profile = profile as? UserProfile else { return true }
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines) != profile.displayName
            || AccountService.normalize(username) != profile.username
    }

    func saveProfile(uid: String, profile: Any?) async {
        isWorking = true
        errorMessage = nil
        message = nil
        defer { isWorking = false }

        guard let profile = profile as? UserProfile else {
            errorMessage = "Your profile hasn't loaded yet. Please try again."
            return
        }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Display name can't be empty."
            return
        }

        do {
            if name != profile.displayName {
                try await AccountService.shared.updateDisplayName(uid: uid, to: name)
            }
            if AccountService.normalize(username) != profile.username {
                try await AccountService.shared.changeUsername(uid: uid, from: profile.username, to: username)
            }
            message = "Profile saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Notification Preferences

    func prefsChanged(from profile: Any?) -> Bool {
        guard let profile = profile as? UserProfile else { return true }
        let saved = profile.notificationPreferences
        return prefs.groupInviteNotificationsEnabled != saved.groupInviteNotificationsEnabled
            || prefs.photosAvailableNotificationsEnabled != saved.photosAvailableNotificationsEnabled
            || prefs.questNotificationsEnabled != saved.questNotificationsEnabled
    }

    /// Saves the toggles only if they differ from what's already saved. Use this from the
    /// view's `.onChange(of: vm.prefs)` so each switch saves as soon as it's flipped.
    func autoSavePreferences(uid: String) async {
        guard prefs != savedPrefs else { return }
        await savePreferences(uid: uid)
    }

    func savePreferences(uid: String) async {
        isWorking = true
        errorMessage = nil
        message = nil
        defer { isWorking = false }

        let toSave = prefs
        let stored = StoredNotificationPreferences(
            groupInviteNotificationsEnabled: toSave.groupInviteNotificationsEnabled,
            photosAvailableNotificationsEnabled: toSave.photosAvailableNotificationsEnabled,
            questNotificationsEnabled: toSave.questNotificationsEnabled
        )

        do {
            try await AccountService.shared.updateNotificationPreferences(uid: uid, to: stored)
            savedPrefs = toSave
            message = "Preferences saved."
        } catch {
            prefs = savedPrefs          // switches go back to what's actually saved
            errorMessage = error.localizedDescription
        }
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

        do {
            try await AccountService.shared.requestEmailChange(
                currentPassword: currentPassword,
                newEmail: newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            newEmail = ""
            message = "Check your new inbox for a verification link to finish the change."
        } catch {
            errorMessage = error.localizedDescription
        }
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

        do {
            try await AccountService.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            newPassword = ""
            currentPassword = ""
            message = "Password updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func deleteAccount(session: AppSession) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        guard !currentPassword.isEmpty else {
            errorMessage = "Please enter your current password to delete your account."
            return
        }

        do {
            try await AccountService.shared.deleteAccount(currentPassword: currentPassword)
            didDeleteAccount = true   // the auth listener also returns the app to the signed-out screen
        } catch {
            errorMessage = error.localizedDescription
        }
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
