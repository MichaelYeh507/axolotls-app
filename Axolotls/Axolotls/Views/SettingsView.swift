
import SwiftUI
import Combine

// MARK: - Account Settings

struct SettingsView: View {

    @EnvironmentObject var session: AppSession
    @StateObject private var vm = SettingsViewModel()

    @State private var showDeleteConfirm = false

    var body: some View {
        Form {

            // MARK: - Profile

            Section("Profile") {

                TextField("Display name", text: $vm.displayName)

                TextField("Username", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save Profile") {
                    guard let uid = session.userID else {
                        vm.errorMessage = "You must be signed in."
                        return
                    }

                    Task {
                        await vm.saveProfile(
                            uid: uid,
                            profile: session.profile
                        )
                    }
                }
                .disabled(
                    !vm.profileChanged(from: session.profile) ||
                    vm.isWorking
                )
            }

            // MARK: - Notifications

            Section("Notifications") {

                Toggle(
                    "Group invites",
                    isOn: $vm.prefs.groupInviteNotificationsEnabled
                )

                Toggle(
                    "Photos available",
                    isOn: $vm.prefs.photosAvailableNotificationsEnabled
                )

                Toggle(
                    "Quests",
                    isOn: $vm.prefs.questNotificationsEnabled
                )

                Button("Save Preferences") {
                    guard let uid = session.userID else {
                        vm.errorMessage = "You must be signed in."
                        return
                    }

                    Task {
                        await vm.savePreferences(uid: uid)
                    }
                }
                .disabled(
                    !vm.prefsChanged(from: session.profile) ||
                    vm.isWorking
                )
            }

            // MARK: - Account Security

            Section {
                SecureField(
                    "Current password",
                    text: $vm.currentPassword
                )
                .textContentType(.password)

                Text(
                    "Signed in as \(session.email ?? "")"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                TextField("New email", text: $vm.newEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                Button("Change Email") {
                    Task {
                        await vm.changeEmail()
                    }
                }
                .disabled(
                    vm.newEmail.isEmpty ||
                    vm.currentPassword.isEmpty ||
                    vm.isWorking
                )

                SecureField(
                    "New password (6+ characters)",
                    text: $vm.newPassword
                )
                .textContentType(.newPassword)

                Button("Change Password") {
                    Task {
                        await vm.changePassword()
                    }
                }
                .disabled(
                    vm.newPassword.count < 6 ||
                    vm.currentPassword.isEmpty ||
                    vm.isWorking
                )

            } header: {
                Text("Security")
            } footer: {
                Text(
                    "Changing your email, changing your password, " +
                    "or deleting your account requires your current password."
                )
            }

            // MARK: - Status Messages

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let message = vm.message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }

            // MARK: - Account Actions

            Section("Account") {

                Button("Sign Out", role: .destructive) {
                    vm.signOut(session: session)
                }

                Button("Delete Account", role: .destructive) {
                    showDeleteConfirm = true
                }
            }

            // MARK: - Loading

            if vm.isWorking {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Please wait...")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    await vm.deleteAccount(session: session)
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This action may permanently delete your account and its associated data."
            )
        }
    }
}
