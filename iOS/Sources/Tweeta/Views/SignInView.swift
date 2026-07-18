import SwiftUI

struct SignInView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var username = ""
  @State private var password = ""
  @State private var isSigningIn = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Username", text: $username)
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          SecureField("Password", text: $password)
            .textContentType(.password)
            .onSubmit(signIn)
        } header: {
          Text("\(store.selectedInstance.host) account")
        }

        if let errorMessage {
          Section {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .navigationTitle("Sign in")
      .navigationBarTitleDisplayMode(.inline)
      .disabled(isSigningIn)
      .overlay {
        if isSigningIn {
          ProgressView("Signing in…")
            .padding(20)
            .tweetaGlass(in: RoundedRectangle(cornerRadius: 18))
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sign in", action: signIn)
            .fontWeight(.semibold)
            .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || password.isEmpty || isSigningIn)
        }
      }
    }
  }

  private func signIn() {
    guard !isSigningIn else { return }
    let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !username.isEmpty, !password.isEmpty else { return }
    isSigningIn = true
    errorMessage = nil
    Task {
      do {
        try await store.signIn(username: username, password: password)
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
        isSigningIn = false
      }
    }
  }
}
