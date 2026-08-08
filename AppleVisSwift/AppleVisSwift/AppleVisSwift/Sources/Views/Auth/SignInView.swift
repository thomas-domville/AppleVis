import SwiftUI
import UIKit

struct SignInView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var signInError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Benefits card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("With a free AppleVis account you can:")
                            .font(.headline)
                        benefitRow("Post and reply in the forums")
                        benefitRow("Follow topics and get notified of replies")
                        benefitRow("Save items and sync across devices")
                        benefitRow("Receive push notifications for new content")

                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Link("Sign up for free", destination: URL(string: "https://www.applevis.com/user/register")!)
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username or email").font(.subheadline).fontWeight(.semibold)
                            TextField("Enter your username or email", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Username or email address")
                                .accessibilityHint("Enter your AppleVis username or email. Both are accepted.")
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.subheadline).fontWeight(.semibold)
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                                .onSubmit { Task { await signIn() } }
                                .accessibilityLabel("Password")
                                .accessibilityHint("Enter your AppleVis account password.")
                        }

                        if let err = signInError {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                    Text(err).font(.subheadline).foregroundStyle(.red)
                                }
                                HStack(spacing: 4) {
                                    Text("Forgot your password?")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Link("Reset it on the website", destination: URL(string: "https://www.applevis.com/user/password")!)
                                        .font(.caption).fontWeight(.semibold)
                                }
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(err). If you have forgotten your password, you can reset it on the AppleVis website.")
                            .accessibilityFocused($isErrorFocused)
                        }

                        Button {
                            Task { await signIn() }
                        } label: {
                            Group {
                                if isSigningIn {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSigningIn || username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                        .accessibilityLabel(isSigningIn ? "Signing in, please wait" : "Sign in")
                    }
                }
                .padding()
            }
            .background(preferences.colors.background)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 3)
                .accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func signIn() async {
        let name = username.trimmingCharacters(in: .whitespaces)
        // The Sign In button is already disabled for empty fields, but
        // the password field's `.onSubmit` (hitting Return) bypassed that
        // and silently did nothing — give explicit feedback instead.
        guard !name.isEmpty else {
            signInError = "Please enter your AppleVis username or email address."
            UIAccessibility.post(notification: .announcement, argument: signInError!)
            isErrorFocused = true
            return
        }
        guard !password.isEmpty else {
            signInError = "Please enter your AppleVis password."
            UIAccessibility.post(notification: .announcement, argument: signInError!)
            isErrorFocused = true
            return
        }
        isSigningIn = true
        signInError = nil
        await auth.signIn(username: name, password: password)
        isSigningIn = false
        if auth.isSignedIn {
            toast.success("Signed in as \(auth.user?.name ?? name)")
            dismiss()
        } else {
            signInError = auth.error ?? "Sign in failed. Please try again."
            isErrorFocused = true
        }
    }
}
