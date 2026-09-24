import SwiftUI

/// Change Password / Change Email — a short, warm wizard reusing the same
/// step components the Submit/Contact wizards already use, rather than a
/// plain settings form. Both flows share the same shape (confirm current
/// password → new value → review) so one view handles both via `mode`.
struct AccountSecurityWizard: View {
    enum Mode: Hashable, Identifiable {
        case password, email
        var id: Self { self }

        // Pre-resolved for the same reason as PasswordStrength.label below —
        // this drives .navigationTitle(mode.title) directly, and a plain
        // String literal there would never reach the catalog.
        var title: String {
            switch self {
            case .password: return String(localized: "Change Password")
            case .email: return String(localized: "Change Email Address")
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
    /// Lets a caller land here already knowing what email to suggest — used
    /// by the "update your account email too?" prompt on Contact Us, Submit
    /// Bug Report, Submit Blog, and Report a Comment's thank-you screens, so
    /// someone who already typed the address once doesn't have to retype it
    /// here. Still requires confirming the current password on step 1
    /// regardless — this only pre-fills step 2's value.
    var initialEmail: String? = nil

    private enum Step: Int { case verify, newValue, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var domainChecker = EmailDomainChecker()

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

    /// Tightened from a bare 8-character minimum after a beta tester's
    /// suggestion — now also requires a digit and a symbol, the standard
    /// baseline most sites already enforce. These three are the only hard
    /// requirements; `passwordStrength` below is advisory on top of them,
    /// never blocking.
    private var newPasswordMeetsRequirements: Bool {
        newPassword.count >= 8
            && newPassword.contains(where: \.isNumber)
            && newPassword.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace })
    }

    private var newValueValid: Bool {
        switch mode {
        case .password:
            return newPasswordMeetsRequirements && newPassword == confirmPassword
        case .email:
            return newEmail.isValidEmailFormat
        }
    }

    enum PasswordStrength: CaseIterable {
        case weak, moderate, strong, veryStrong

        // Returns already-localized text (not a bare literal) — this gets
        // interpolated into another String(localized:) template below, and
        // a plain-String return here would insert untranslated English
        // into an otherwise-translated sentence, the same catalog-skipping
        // trap noted throughout this codebase for Text(String)/verbatim
        // interpolation.
        var label: String {
            switch self {
            case .weak: return String(localized: "Weak")
            case .moderate: return String(localized: "Moderate")
            case .strong: return String(localized: "Strong")
            case .veryStrong: return String(localized: "Very Strong")
            }
        }

        var color: Color {
            switch self {
            case .weak: return .red
            case .moderate: return .orange
            case .strong: return .yellow
            case .veryStrong: return .green
            }
        }
    }

    /// A nudge, not a gate — scores beyond the three hard requirements
    /// above (case variety, length past the minimum) so someone who meets
    /// the bare minimum can still see there's room to do better, without
    /// AppleVis ever refusing a password that meets its actual policy.
    private func passwordStrength(_ password: String) -> PasswordStrength? {
        guard !password.isEmpty else { return nil }
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: \.isUppercase) { score += 1 }
        if password.contains(where: \.isLowercase) { score += 1 }
        if password.contains(where: \.isNumber) { score += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }) { score += 1 }
        switch score {
        case 0...2: return .weak
        case 3...4: return .moderate
        case 5: return .strong
        default: return .veryStrong
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
                Text(mode == .password ? String(localized: "Your password change will be discarded.") : String(localized: "Your email change will be discarded."))
            }
            // Step 1 previously got no explicit focus at all — only
            // goNext()/goBack() ever called focusStepAfterTransition(), so
            // opening this wizard left VoiceOver focus on system default
            // (typically Cancel). Full app-wide focus audit, requested
            // directly.
            .task {
                if mode == .email, newEmail.isEmpty, let initialEmail {
                    newEmail = initialEmail
                }
                focusStepAfterTransition()
            }
        }
    }

    // MARK: - Step 1: Confirm current password

    private var verifySection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Confirm Your Password", stepIndex: 1, stepTotal: totalSteps, accentColor: mode.color, headerFocus: $isStepFocused)
                Text("For your security, enter your current AppleVis password to continue.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Current Password") {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                    .accessibilityHint(String(localized: "Required."))
            }
            Section {
                WizardBlockingNote(reasons: currentPassword.isEmpty ? [String(localized: "Enter your current password to continue.")] : [])
                WizardBottomButton(String(localized: "Next"), isEnabled: !currentPassword.isEmpty, action: goNext)
            }
        }
    }

    // MARK: - Step 2: New value

    private var newValueSection: some View {
        Group {
            Section {
                WizardStepHeader(
                    title: mode == .password ? "Choose a New Password" : "Enter Your New Email",
                    stepIndex: 2, stepTotal: totalSteps,
                    accentColor: mode.color, onBack: goBack, headerFocus: $isStepFocused
                )
                Text(mode == .password
                    ? String(localized: "Enter a new password meeting the requirements below, then confirm it.")
                    : String(localized: "Enter the new email address for your AppleVis account."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if mode == .password {
                // The requirement used to live only in a hint and in a
                // reactive warning that appeared after typing too little —
                // stating it in the field's own label instead means
                // VoiceOver hears it immediately, in the same swipe-stop as
                // the field, rather than needing a separate line that only
                // shows up once you've already gotten it wrong. A beta
                // tester's suggestion, generalized here.
                Section {
                    SecureField("New Password (8+ characters, 1 number, 1 symbol)", text: $newPassword)
                        .textContentType(.newPassword)
                        .accessibilityHint(String(localized: "Required."))
                    if let strength = passwordStrength(newPassword) {
                        Label(String(localized: "Password strength: \(strength.label)"), systemImage: "gauge.with.dots.needle.bottom.50percent")
                            .font(.caption)
                            .foregroundStyle(strength.color)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .accessibilityHint(String(localized: "Required. Must match the password above."))
                } header: {
                    Text("New Password")
                } footer: {
                    Text("Meeting the minimum is all that's required to continue — the strength meter above is just a nudge toward a password that's harder to guess.")
                }
                if newPasswordMeetsRequirements && !confirmPassword.isEmpty && confirmPassword != newPassword {
                    Section {
                        Text("Passwords don't match.")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            } else {
                Section {
                    TextField("Email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityHint(String(localized: "Required."))
                        .onChange(of: newEmail) { _, newValue in domainChecker.check(email: newValue) }
                } header: {
                    Text("New Email Address")
                } footer: {
                    if !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !newEmail.isValidEmailFormat {
                        Text("Enter a valid email address.")
                    } else {
                        EmailDomainWarning(checker: domainChecker)
                    }
                }
            }
            Section {
                WizardBlockingNote(reasons: newValueBlockingReasons)
                WizardBottomButton(String(localized: "Next"), isEnabled: newValueValid, action: goNext)
            }
        }
    }

    private var newValueBlockingReasons: [String] {
        guard !newValueValid else { return [] }
        switch mode {
        case .password:
            var reasons: [String] = []
            if newPassword.count < 8 {
                reasons.append(String(localized: "Enter a password of at least 8 characters to continue."))
            }
            if !newPassword.contains(where: \.isNumber) {
                reasons.append(String(localized: "Include at least one number to continue."))
            }
            if !newPassword.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }) {
                reasons.append(String(localized: "Include at least one special character to continue."))
            }
            if reasons.isEmpty && confirmPassword != newPassword {
                reasons.append(String(localized: "Confirm your new password to continue."))
            }
            return reasons
        case .email:
            return [String(localized: "Enter a valid email address to continue.")]
        }
    }

    // MARK: - Step 3: Review

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Review and Save", stepIndex: 3, stepTotal: totalSteps, accentColor: mode.color, onBack: goBack, headerFocus: $isStepFocused)
                Text("Check your change, then tap Save Changes.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                if mode == .password {
                    WizardReviewRow(label: "Change", value: String(localized: "Update your account password"))
                } else {
                    WizardReviewRow(label: "New Email Address", value: newEmail)
                }
            }
            Section {
                WizardBottomButton(
                    isSubmitting ? String(localized: "Saving…") : String(localized: "Save Changes"),
                    isEnabled: !isSubmitting
                ) { Task { await submit() } }
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
    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; error = nil
        do {
            guard let freshToken = try await APIClient.shared.account.verifyCurrentPassword(
                username: user.name, password: currentPassword
            ) else {
                let message = String(localized: "Your current password is incorrect.")
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
            UIAccessibility.post(notification: .announcement, argument: mode == .password ? String(localized: "Password updated.") : String(localized: "Email address updated."))
            submitted = true
        } catch let e as APIError {
            error = e.localizedDescription
            await announceWizardFailure(e.localizedDescription, focus: $isErrorFocused)
        } catch {
            let message = String(localized: "Couldn't save changes. Please try again.")
            self.error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
