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

    @State private var step: Step = .description
    @State private var showSignIn = false
    @State private var title = ""
    @State private var appleFeedbackId = ""
    @State private var platform = "iOS"
    @State private var softwareVersion = ""
    @State private var canReproduce = "Yes, always"
    @State private var description = ""
    @State private var recognition = "Yes - please use my AppleVis username"
    @State private var isSubmitting = false
    @State private var error: String?

    private let platforms = ["iOS", "iPadOS", "macOS"]
    private let reproduceOptions = ["Yes, always", "Yes, sometimes", "No"]
    private let recognitionOptions = [
        "Yes - please use my name.",
        "Yes - please use my AppleVis username",
        "No - please thank/recognize me anonymously",
    ]

    private var descriptionValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInRequiredView
                } else {
                    Form {
                        switch step {
                        case .description: descriptionSection
                        case .bugInfo:     bugInfoSection
                        case .review:      reviewSection
                        }
                        if let error {
                            Section { Text(error).foregroundStyle(.red) }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit a Bug Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .description ? "Cancel" : "Back") {
                        if step == .description {
                            SoundPlayer.shared.play(.screenClose)
                            dismiss()
                        } else {
                            goBack()
                        }
                    }
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
                                .disabled(step == .description ? !descriptionValid : false)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
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
                Text("Report an accessibility bug for the community Bug Tracker. Apple does not see this directly — file Feedback Assistant separately if you want Apple to see it.")
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
                    GuidelinesReminderView(warning: warning) { guidelines.dismiss() }
                }
            }
            Section("Bug Details") {
                TextField("Title", text: $title)
            }
            Section("Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 160)
                    .onChange(of: description) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
            }
        }
    }

    private var bugInfoSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 3, title: "Environment", isFocused: $isStepFocused) }
            Section("Where It Happens") {
                Picker("Platform", selection: $platform) {
                    ForEach(platforms, id: \.self) { Text($0) }
                }
                TextField("Software Version", text: $softwareVersion)
                TextField("Apple Feedback ID (optional)", text: $appleFeedbackId)
                    .accessibilityHint(String(localized: "The FB number from Apple's Feedback Assistant, if you also filed this there."))
                Picker("Can you reproduce it?", selection: $canReproduce) {
                    ForEach(reproduceOptions, id: \.self) { Text($0) }
                }
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
            Section { WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused) }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("Bug") {
                WizardReviewRow(label: "Title", value: title)
                WizardReviewRow(label: "Description", value: description)
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

    private func focusStepAfterTransition() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isStepFocused = true
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitBug(
            name: user.name, email: "", title: title, appleFeedback: appleFeedbackId,
            platform: platform, softwareVersion: softwareVersion, canReproduce: canReproduce,
            description: description, recognition: recognition
        )
        switch result {
        case .ok:
            toast.success(String(localized: "Bug report submitted"))
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
