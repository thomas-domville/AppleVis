import SwiftUI
import UIKit

struct SignInView: View {
    /// Set when the app is asking the member to sign in again because the
    /// website ended their session.
    var expiredReason: AuthStore.ReSignInPrompt.Reason? = nil
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isSigningIn = false
    @State private var signInError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isErrorFocused: Bool
    /// Had no initial-load focus at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isIntroFocused: Bool

    var body: some View {
        AppNavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let expiredReason {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Please sign in again")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($isIntroFocused)
                            Text(expiredReason == .whileSending
                                 ? String(localized: "For your security, AppleVis signs you out every few weeks. Sign in again and what you were sending will go through. Nothing you wrote has been lost.")
                                 : String(localized: "For your security, AppleVis signs you out every few weeks. Sign in again to keep posting, replying, and saving."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    } else {
                    // Benefits card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("With a free AppleVis account you can:")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isIntroFocused)
                        benefitRow(String(localized: "Post and reply in the forums"))
                        benefitRow(String(localized: "Follow topics and get notified of replies"))
                        benefitRow(String(localized: "Save items and sync across devices"))
                        benefitRow(String(localized: "Receive push notifications for new content"))

                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.subheadline).foregroundStyle(.secondary)
                            WebLink(destination: URL(string: "https://www.applevis.com/user/register")!) {
                                Text("Sign up for free")
                            }
                            .font(.subheadline).fontWeight(.semibold)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username or email").font(.subheadline).fontWeight(.semibold)
                            TextField("Enter your username or email", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .accessibilityLabel(String(localized: "Username or email address"))
                                .accessibilityHint(String(localized: "Enter your AppleVis username or email. Both are accepted."))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password").font(.subheadline).fontWeight(.semibold)
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                                .onSubmit { Task { await signIn() } }
                                .accessibilityLabel(String(localized: "Password"))
                                .accessibilityHint(String(localized: "Enter your AppleVis account password."))
                        }

                        // Remember me (2026-09-28, requested directly): the
                        // website signs members out about every three weeks;
                        // with this on, the app signs them back in by itself.
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Remember me", isOn: $rememberMe)
                                .accessibilityHint(String(localized: "Keeps you signed in on this iPhone."))
                            Text("The website signs you out every few weeks. With this on, AppleVis signs you back in for you. Your password is kept securely in this iPhone's Keychain and is removed when you sign out.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
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
                                    WebLink(destination: URL(string: "https://www.applevis.com/user/password")!) {
                                        Text("Reset it on the website")
                                    }
                                    .font(.caption).fontWeight(.semibold)
                                }
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(localized: "\(err). If you have forgotten your password, you can reset it on the AppleVis website."))
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
                        .accessibilityLabel(String(localized: isSigningIn ? "Signing in, please wait" : "Sign In"))
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
            .task {
                // Signing in again after the website ended the session: the
                // username is already known.
                if expiredReason != nil, username.isEmpty, let name = auth.user?.name {
                    username = name
                }
                await retryAccessibilityFocus(into: $isIntroFocused)
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
            signInError = String(localized: "Please enter your AppleVis username or email address.")
            UIAccessibility.post(notification: .announcement, argument: signInError!)
            isErrorFocused = true
            return
        }
        guard !password.isEmpty else {
            signInError = String(localized: "Please enter your AppleVis password.")
            UIAccessibility.post(notification: .announcement, argument: signInError!)
            isErrorFocused = true
            return
        }
        isSigningIn = true
        signInError = nil
        await auth.signIn(username: name, password: password, rememberMe: rememberMe)
        isSigningIn = false
        // Checks the sign-in itself worked, not just that someone is signed
        // in: when signing in again after a session ends, the old account
        // is still on file, so a wrong password looked like success.
        if auth.isSignedIn && auth.error == nil {
            toast.success(String(localized: "Signed in as \(auth.user?.name ?? name)"))
            dismiss()
        } else {
            signInError = auth.error ?? String(localized: "Couldn't sign in. Try again.")
            isErrorFocused = true
        }
    }
}
