import SwiftUI

/// Change Password / Change Email — a short, warm wizard reusing the same
/// step components the Submit/Contact wizards already use, rather than a
/// plain settings form. Both flows share the same shape (confirm current
/// password → new value → review) so one view handles both via `mode`.
struct AccountSecurityWizard: View {
    enum Mode: Hashable, Identifiable {
        case password, email
        var id: Self { self }

        var title: String {
            switch self {
            case .password: return "Change Password"
            case .email: return "Change Email Address"
            }
        }
        var icon: String {
            switch self {
            case .password: return "lock.rotation"
            case .email: return "envelope.badge"
            }
        }
        var color: Color {
            switch self {
            case .password: return Color(red: 0.545, green: 0.361, blue: 0.965) // purple
            case .email: return Color(red: 0.231, green: 0.510, blue: 0.965) // blue
            }
        }
    }

    let mode: Mode

    private enum Step: Int { case verify, newValue, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .verify
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var newEmail = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    private let totalSteps = 3

    private var newValueValid: Bool {
        switch mode {
        case .password:
            return newPassword.count >= 8 && newPassword == confirmPassword
        case .email:
            return newEmail.contains("@") && newEmail.contains(".")
        }
    }

    private var canGoNext: Bool {
        switch step {
        case .verify:   return !currentPassword.isEmpty
        case .newValue: return newValueValid
        case .review:   return true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: mode.icon,
                        heading: mode == .password ? "Password updated!" : "Email address updated!",
                        message: mode == .password
                            ? "Your AppleVis password has been changed. You'll need it the next time you sign in on another device."
                            : "Your AppleVis account email has been updated to \(newEmail).",
                        doneLabel: "Done",
                        onDone: { dismiss() }
                    )
                } else {
                    Form {
                        switch step {
                        case .verify:   verifySection
                        case .newValue: newValueSection
                        case .review:   reviewSection
                        }
                        if let error {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .accessibilityFocused($isErrorFocused)
                            }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                    // Previously showed "Back" (not "Cancel") on every step
                    // past Confirm Your Password, leaving no way to actually
                    // leave the wizard from New Value or Review without
                    // stepping backward first. Cancel now stays put
                    // regardless of step; step-backward navigation moved to
                    // its own in-content button below, matching every other
                    // wizard's convention. Reported directly.
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { requestCancel() }
                            .accessibilityHint(String(localized: "Cancels and closes this form."))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button(isSubmitting ? "Saving…" : "Save Changes") { Task { await submit() } }
                                .disabled(isSubmitting)
                        } else {
                            Button("Next") { goNext() }
                                .disabled(!canGoNext)
                        }
                    }
                }
            }
            .disabled(isSubmitting)
            .confirmationDialog(
                "Discard changes?", isPresented: $showDiscardConfirm, titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text(mode == .password ? "Your password change will be discarded." : "Your email change will be discarded.")
            }
            // Step 1 previously got no explicit focus at all — only
            // goNext()/goBack() ever called focusStepAfterTransition(), so
            // opening this wizard left VoiceOver focus on system default
            // (typically Cancel). Full app-wide focus audit, requested
            // directly.
            .task { focusStepAfterTransition() }
        }
    }

    // MARK: - Step 1: Confirm current password

    private var verifySection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: totalSteps, title: "Confirm Your Password", isFocused: $isStepFocused, accentColor: mode.color)
                Text("For your security, enter your current AppleVis password to continue.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Current Password") {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                    .accessibilityHint(String(localized: "Required."))
            }
        }
    }

    // MARK: - Step 2: New value

    private var newValueSection: some View {
        Group {
            Section {
                WizardStepIndicator(
                    step: 2, total: totalSteps,
                    title: mode == .password ? "Choose a New Password" : "Enter Your New Email",
                    isFocused: $isStepFocused, accentColor: mode.color
                )
                backButton
            }
            if mode == .password {
                Section("New Password") {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                        .accessibilityHint(String(localized: "Required. At least 8 characters."))
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .accessibilityHint(String(localized: "Required. Must match the password above."))
                }
                if !newPassword.isEmpty && newPassword.count < 8 {
                    Section {
                        Text("Password must be at least 8 characters.")
                            .font(.caption).foregroundStyle(.red)
                    }
                } else if !confirmPassword.isEmpty && confirmPassword != newPassword {
                    Section {
                        Text("Passwords don't match.")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            } else {
                Section("New Email Address") {
                    TextField("Email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityHint(String(localized: "Required."))
                }
            }
        }
    }

    // MARK: - Step 3: Review

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 3, total: totalSteps, title: "Review and Save", isFocused: $isStepFocused, accentColor: mode.color)
                backButton
            }
            Section {
                if mode == .password {
                    WizardReviewRow(label: "Change", value: "Update your account password")
                } else {
                    WizardReviewRow(label: "New Email Address", value: newEmail)
                }
            }
        }
    }

    // MARK: - Navigation

    private func goNext() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .verify:   step = .newValue
        case .newValue: step = .review
        case .review:   break
        }
        focusStepAfterTransition()
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .verify:   break
        case .newValue: step = .verify
        case .review:   step = .newValue
        }
        focusStepAfterTransition()
    }

    private func requestCancel() {
        if currentPassword.isEmpty && newPassword.isEmpty && newEmail.isEmpty {
            dismiss()
        } else {
            showDiscardConfirm = true
        }
    }

    /// Was a single guessed 300ms delay — see SubmitAppView's identical fix
    /// for the full reasoning. Full app-wide focus audit, requested
    /// directly.
    private func focusStepAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isStepFocused) }
    }

    /// Step-backward navigation, separated from the toolbar's Cancel button
    /// so a user can discard the change from any step.
    private var backButton: some View {
        Button {
            goBack()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; error = nil
        do {
            guard let freshToken = try await APIClient.shared.account.verifyCurrentPassword(
                username: user.name, password: currentPassword
            ) else {
                let message = "Your current password is incorrect."
                error = message
                await announceWizardFailure(message, focus: $isErrorFocused)
                isSubmitting = false
                return
            }
            switch mode {
            case .password:
                try await APIClient.shared.account.changePassword(uuid: user.uuid, csrfToken: freshToken, newPassword: newPassword)
            case .email:
                try await APIClient.shared.account.changeEmail(uuid: user.uuid, csrfToken: freshToken, newEmail: newEmail)
            }
            SoundPlayer.shared.play(.success)
            UIAccessibility.post(notification: .announcement, argument: mode == .password ? "Password updated." : "Email address updated.")
            submitted = true
        } catch let e as APIError {
            error = e.localizedDescription
            await announceWizardFailure(e.localizedDescription, focus: $isErrorFocused)
        } catch {
            let message = "Couldn't save changes. Please try again."
            self.error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
