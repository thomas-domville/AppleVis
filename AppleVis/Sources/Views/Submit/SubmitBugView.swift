import SwiftUI

/// Ported against src/services/drupalForm.ts's `/form/community-bug-report-form`
/// webform and src/contexts/BugWizardContext.tsx.
///
/// RN requires sign-in (submission silently no-ops without a user, and posts
/// under the account's name with no email field at all — verified via
/// `app/submit-bug/review.tsx`'s `if (!user) return` + `name: user.name,
/// email: ''`) — Swift previously had no sign-in gate and asked for free-text
/// name/email instead.
///
/// Three-step wizard: Describe the Bug → Environment → Review.
struct SubmitBugView: View {
    private enum Step: Int { case description, bugInfo, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    @State private var step: Step = .description
    @State private var showSignIn = false
    @State private var title = ""
    /// This webform's `email` field is genuinely required, same as the
    /// Blog submission form's — previously hardcoded to an empty string at
    /// submit time. Reported directly.
    @State private var email = ""
    @State private var appleFeedbackId = ""
    @State private var platform = "iOS"
    @State private var softwareVersion = ""
    @State private var canReproduce = "Yes, always"
    @State private var description = ""
    @State private var recognition = "Yes - please use my AppleVis username"
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @State private var submitted = false
    @State private var descriptionMinimumAnnounced = false

    private let platforms = ["iOS", "iPadOS", "macOS"]
    private let reproduceOptions = ["Yes, always", "Yes, sometimes", "No"]
    private let recognitionOptions = [
        "Yes - please use my name.",
        "Yes - please use my AppleVis username",
        "No - please thank/recognize me anonymously",
    ]

    /// 30-char minimum on the description matches legacy's
    /// `submit-bug/description.tsx` `canContinue`, dropped in the native
    /// port (title had no floor legacy either — a non-empty check is enough).
    private var descriptionLength: Int { description.trimmingCharacters(in: .whitespacesAndNewlines).count }

    private var descriptionValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && descriptionLength >= 30 && email.contains("@")
    }

    /// Mirrors Contact's crossing-the-threshold announcement so VoiceOver
    /// users learn the moment they can continue, not just via Next's
    /// disabled state.
    private func handleDescriptionChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !descriptionMinimumAnnounced && length >= 30 {
            descriptionMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached. You can now continue.")
        } else if descriptionMinimumAnnounced && length < 30 {
            descriptionMinimumAnnounced = false
        }
    }

    /// Legacy's `submit-bug/index.tsx` blocked continuing past this step
    /// without a software version; the native Next button here was
    /// previously hardcoded to never disable regardless of step, so this
    /// gate could be skipped with Software Version left empty through
    /// submission. Apple Feedback # is also required here now — verified
    /// directly against the live form, whose own description reads "We
    /// will not accept reports unless they are first filed with Apple,"
    /// not the optional, only-if-you-also-filed-it framing this screen
    /// previously gave it. Format-checked for the "FB" prefix the field's
    /// own description asks for, same level of validation as the numeric
    /// FB number itself gets no further checking beyond that. Reported
    /// directly.
    private var bugInfoValid: Bool {
        !softwareVersion.trimmingCharacters(in: .whitespaces).isEmpty && isAppleFeedbackIdValid
    }

    private var isAppleFeedbackIdValid: Bool {
        appleFeedbackId.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("FB")
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: "ladybug",
                        heading: "You did it — thanks!",
                        message: "Your report is now in front of our team. We genuinely appreciate you taking the time to help make apps more accessible for everyone.",
                        doneLabel: "Done",
                        onDone: { dismiss() }
                    )
                } else if !auth.isSignedIn {
                    signInRequiredView
                } else {
                    Form {
                        switch step {
                        case .description: descriptionSection
                        case .bugInfo:     bugInfoSection
                        case .review:      reviewSection
                        }
                        if let error {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityFocused($isErrorFocused)
                            }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit a Bug Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                // Previously showed "Back" (not "Cancel") on every step past
                // Describe the Bug, leaving no way to actually leave the
                // wizard from Environment or Review without stepping
                // backward through every screen first. Cancel now stays put
                // regardless of step; step-backward navigation moved to its
                // own in-content button below, matching Submit App/Blog's
                // existing convention. Reported directly.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn {
                    if step == .description && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Rewrite") {
                                Task {
                                    if let result = await intelligence.rewrite(subject: title, body: description, isTopic: true) {
                                        title = result.subject ?? title
                                        description = result.body
                                    } else {
                                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                    }
                                }
                            }
                            .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button("Submit") { Task { await submit() } }
                                .disabled(isSubmitting)
                        } else {
                            Button("Next") { goNext() }
                                .disabled(step == .description ? !descriptionValid : !bugInfoValid)
                        }
                    }
                }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .confirmationDialog(
            "Discard this submission?",
            isPresented: $showDiscardConfirm, titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { SoundPlayer.shared.play(.screenClose); dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your progress will be discarded.")
        }
        // Step 1 previously got no explicit focus at all — only
        // goNext()/goBack() ever called focusStepAfterTransition(), so
        // opening this wizard left VoiceOver focus on system default
        // (typically Cancel). Full app-wide focus audit, requested directly.
        .task { focusStepAfterTransition() }
    }

    /// RN confirmed before discarding a filled-out form; Cancel here
    /// previously dismissed immediately with no warning, silently losing a
    /// written bug report with one accidental tap — same regression already
    /// fixed for Submit App, now matched here.
    private func requestCancel() {
        let hasProgress = !title.trimmingCharacters(in: .whitespaces).isEmpty
            || !description.trimmingCharacters(in: .whitespaces).isEmpty
            || !email.trimmingCharacters(in: .whitespaces).isEmpty
            || !appleFeedbackId.trimmingCharacters(in: .whitespaces).isEmpty
            || !softwareVersion.trimmingCharacters(in: .whitespaces).isEmpty
        if hasProgress {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
    }

    private var signInRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Sign In Required")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("You need to be signed in to your AppleVis account to submit a bug report.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") { showSignIn = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var descriptionSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 3, title: "Describe the Bug", isFocused: $isStepFocused)
                // Previously framed filing with Apple's Feedback Assistant
                // as optional ("if you want Apple to see it") — the live
                // form's own description says the opposite: AppleVis won't
                // accept a report that hasn't been filed with Apple first.
                // Surfaced here, at the very start of the wizard, rather
                // than as a surprise once Environment asks for the FB
                // number. Reported directly.
                Text("Report an accessibility bug for the community Bug Tracker. AppleVis requires every report to first be filed with Apple's Feedback Assistant — you'll need the FB number from that report to submit here.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: title, body: description, isTopic: true) {
                                title = result.subject ?? title
                                description = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                }
            }
            if let warning = guidelines.topWarning {
                Section {
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: title, body: description, isTopic: true) {
                                    title = result.subject ?? title
                                    description = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }
            Section("Bug Details") {
                TextField("Title", text: $title)
                    .accessibilityHint(String(localized: "Required."))
            }
            Section {
                TextField("Your Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Required. The AppleVis team may reply to follow up on your report."))
            } header: {
                Text("Your Email")
            }
            Section {
                HStack {
                    Text("Description").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(descriptionLength < 30 ? "\(descriptionLength) / 30 min" : "\(descriptionLength) chars")
                        .font(.caption)
                        .fontWeight(descriptionLength < 30 ? .bold : .regular)
                        .foregroundStyle(descriptionLength < 30 ? .red : .secondary)
                        .accessibilityLabel(descriptionLength < 30 ? String(localized: "\(descriptionLength) of 30 minimum characters") : String(localized: "\(descriptionLength) characters"))
                }
                TextEditor(text: $description)
                    .frame(minHeight: 160)
                    .accessibilityLabel(String(localized: "Description"))
                    .accessibilityHint(String(localized: "Required, minimum 30 characters. The more detail you can share — what happened, what you expected instead, and the exact steps to get there — the easier it is for us to reproduce and track down."))
                    .onChange(of: description) { _, newValue in
                        handleDescriptionChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                Text("The more detail you can share — what happened, what you expected instead, and the exact steps to get there — the easier it is for us to reproduce and track down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bugInfoSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 2, total: 3, title: "Environment", isFocused: $isStepFocused)
                backButton
            }
            Section("Where It Happens") {
                Picker("Platform", selection: $platform) {
                    ForEach(platforms, id: \.self) { Text($0) }
                }
                TextField("Software Version", text: $softwareVersion)
                    .accessibilityHint(String(localized: "Required."))
                Picker("Can you reproduce it?", selection: $canReproduce) {
                    ForEach(reproduceOptions, id: \.self) { Text($0) }
                }
            }
            // Genuinely required on the live form — see `bugInfoValid`'s
            // doc comment. Its own section (rather than folded into "Where
            // It Happens" with the rest) so the policy explanation has
            // room to stand out instead of reading like a minor aside next
            // to Platform/Software Version.
            Section {
                TextField("Apple Feedback #", text: $appleFeedbackId)
                    .textInputAutocapitalization(.characters)
                    .accessibilityHint(String(localized: "Required. Starts with FB."))
                if !appleFeedbackId.isEmpty && !isAppleFeedbackIdValid {
                    Text("Should start with \"FB\", matching your Feedback Assistant submission number.")
                        .font(.caption)
                        .foregroundStyle(preferences.colors.warning)
                }
            } header: {
                Text("Apple Feedback #")
            } footer: {
                Text("AppleVis does not accept bug reports that haven't first been filed with Apple's Feedback Assistant. This is kept confidential.")
            }
            Section("Recognition") {
                Picker("Recognize your contribution?", selection: $recognition) {
                    ForEach(recognitionOptions, id: \.self) { Text($0) }
                }
                .pickerStyle(.navigationLink)
                .accessibilityHint(String(localized: "Controls how you're credited if this report leads to a fix."))
            }
        }
    }

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused)
                backButton
            }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("Bug") {
                WizardReviewRow(label: "Title", value: title)
                WizardReviewRow(label: "Description", value: description)
                WizardReviewRow(label: "Email", value: email)
            }
            Section("Environment") {
                WizardReviewRow(label: "Platform", value: platform)
                WizardReviewRow(label: "Software Version", value: softwareVersion)
                WizardReviewRow(label: "Apple Feedback ID", value: appleFeedbackId)
                WizardReviewRow(label: "Can Reproduce", value: canReproduce)
                WizardReviewRow(label: "Recognition", value: recognition)
            }
        }
    }

    private func goNext() {
        SoundPlayer.shared.play(.pickerTick)
        step = Step(rawValue: step.rawValue + 1) ?? .review
        focusStepAfterTransition()
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        step = Step(rawValue: step.rawValue - 1) ?? .description
        focusStepAfterTransition()
    }

    /// Was a single guessed 300ms delay — see SubmitAppView's identical fix
    /// for the full reasoning. Full app-wide focus audit, requested
    /// directly.
    private func focusStepAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isStepFocused) }
    }

    /// Step-backward navigation, separated from the toolbar's Cancel button
    /// so a user can discard the submission from any step.
    private var backButton: some View {
        Button {
            goBack()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: title,
            body: [description, recognition].joined(separator: "\n\n")
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitBug(
            name: user.name, email: email.trimmingCharacters(in: .whitespacesAndNewlines), title: title, appleFeedback: appleFeedbackId,
            platform: platform, softwareVersion: softwareVersion, canReproduce: canReproduce,
            description: description, recognition: recognition
        )
        switch result {
        case .ok:
            SoundPlayer.shared.play(.success)
            submitted = true
        case .failure(let message):
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
