
import Foundation
import Combine

@MainActor
final class SignUpViewModel: ObservableObject {

    // MARK: - Properties

    @Published var displayName = ""
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""

    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        !isWorking
    }

    // MARK: - Sign Up

    func submit() async {
        errorMessage = nil

        guard canSubmit else {
            errorMessage = "Please complete all fields. Your password must contain at least 6 characters."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await AccountService.shared.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                username: username.trimmingCharacters(in: .whitespaces),
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )

            // AppSession's authentication listener
            // automatically detects the newly signed-in user.

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
