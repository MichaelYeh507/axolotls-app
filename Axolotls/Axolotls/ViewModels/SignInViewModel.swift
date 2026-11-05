
import Foundation
import Combine

@MainActor
final class SignInViewModel: ObservableObject {

    // MARK: - Properties

    @Published var email = ""
    @Published var password = ""

    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?

    var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        !isWorking
    }

    // MARK: - Sign In

    func signIn() async {
        isWorking = true
        errorMessage = nil
        infoMessage = nil

        defer { isWorking = false }

        do {
            try await AccountService.shared.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reset Password

    func resetPassword() async {
        errorMessage = nil
        infoMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await AccountService.shared.sendPasswordReset(
                email: trimmedEmail
            )

            infoMessage = "Password reset email sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
