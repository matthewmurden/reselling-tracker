import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }

                if let err = errorText {
                    Text(err).foregroundColor(.red)
                }

                Section {
                    Button("Sign In", action: signIn)
                        .disabled(email.isEmpty || password.isEmpty)

                    Button("Create Account", action: signUp)
                        .disabled(email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Sign in")
        }
    }

    private func signIn() {
        errorText = nil
        Task { @MainActor in
            do {
                _ = try await Auth.auth().signIn(withEmail: email, password: password)
            } catch {
                let ns = error as NSError
                print("SIGN IN ERROR:", ns.domain, ns.code, ns.userInfo)
                errorText = ns.localizedDescription
            }
        }
    }

    private func signUp() {
        errorText = nil
        Task { @MainActor in
            do {
                _ = try await Auth.auth().createUser(withEmail: email, password: password)
            } catch {
                let ns = error as NSError
                print("SIGN UP ERROR:", ns.domain, ns.code, ns.userInfo)
                errorText = ns.localizedDescription
            }
        }
    }
}
