import SwiftUI

// MARK: - Welcome

struct AuthFlowView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Text("Axolotls").font(.largeTitle.bold())
                Text("Snap a memory. Reveal it later.").foregroundStyle(.secondary)
                Spacer()
                NavigationLink("Get Started") { SignUpView() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                NavigationLink("I already have an account") { SignInView() }
                    .padding(.bottom, 32)
            }
            .padding()
        }
    }
}

// MARK: - Sign up

struct SignUpView: View {
    @StateObject private var vm = SignUpViewModel()

    var body: some View {
        Form {
            Section("About you") {
                TextField("Display name", text: $vm.displayName)
                TextField("Username", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("Login") {
                TextField("Email", text: $vm.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                SecureField("Password (6+ characters)", text: $vm.password)
                    .textContentType(.newPassword)
            }
            if let error = vm.errorMessage {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
            Section {
                Button {
                    Task { await vm.submit() }
                } label: {
                    HStack { Spacer(); if vm.isWorking { ProgressView() } else { Text("Create Account") }; Spacer() }
                }
                .disabled(!vm.canSubmit)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Sign Up")
    }
}

// MARK: - Sign in

struct SignInView: View {
    @StateObject private var vm = SignInViewModel()

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $vm.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                SecureField("Password", text: $vm.password)
                    .textContentType(.password)
            }
            if let error = vm.errorMessage { Text(error).foregroundStyle(.red).font(.footnote) }
            if let info = vm.infoMessage { Text(info).foregroundStyle(.green).font(.footnote) }
            Section {
                Button {
                    Task { await vm.signIn() }
                } label: {
                    HStack { Spacer(); if vm.isWorking { ProgressView() } else { Text("Sign In") }; Spacer() }
                }
                .disabled(!vm.canSignIn)

                Button("Forgot password?") { Task { await vm.resetPassword() } }
                    .disabled(vm.email.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Sign In")
    }
}
