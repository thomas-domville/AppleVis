import SwiftUI

/// In-app contact form — replaces linking out to Safari. Ported against the
/// live, verified `/contact` Drupal webform (see DrupalFormClient).
///
/// Three-step wizard: Your Details → Message → Review, matching the original
/// step-by-step design (index → details → compose → review).
struct ContactView: View {
    private enum Step: Int { case details, message, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool

    @State private var step: Step = .details
    @State private var name = ""
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var error: String?

    private var detailsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var messageValid: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .details:  detailsSection
                case .message:  messageSection
                case .review:   reviewSection
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Contact AppleVis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .details ? "Cancel" : "Back") {
                        if step == .details {
                            SoundPlayer.shared.play(.screenClose)
                            dismiss()
                        } else {
                            goBack()
                        }
                    }
                }
                if step == .message && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Rewrite") {
                            Task {
                                if let result = await intelligence.rewrite(subject: subject, body: message, isTopic: false) {
                                    subject = result.subject ?? subject
                                    message = result.body
                                }
                            }
                        }
                        .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .review {
                        Button("Send") { Task { await submit() } }
                            .disabled(isSubmitting)
                    } else {
                        Button("Next") { goNext() }
                            .disabled(step == .details ? !detailsValid : !messageValid)
                    }
                }
            }
            .onAppear {
                if name.isEmpty { name = auth.user?.name ?? "" }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 3, title: "Your Details", isFocused: $isStepFocused)
                Text("Send a bug report, feedback, suggestion, or recommendation to the AppleVis team.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Your Details") {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint("We'll reply to this address.")
            }
        }
    }

    private var messageSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 3, title: "Your Message", isFocused: $isStepFocused) }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: subject, body: message, isTopic: false) {
                                subject = result.subject ?? subject
                                message = result.body
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
            Section("Message") {
                TextField("Subject", text: $subject)
                TextEditor(text: $message)
                    .frame(minHeight: 160)
                    .onChange(of: message) { _, newValue in
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

    private var reviewSection: some View {
        Group {
            Section { WizardStepIndicator(step: 3, total: 3, title: "Review & Send", isFocused: $isStepFocused) }
            Section("Your Details") {
                WizardReviewRow(label: "Name", value: name)
                WizardReviewRow(label: "Email", value: email)
            }
            Section("Message") {
                WizardReviewRow(label: "Subject", value: subject)
                WizardReviewRow(label: "Message", value: message)
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
        step = Step(rawValue: step.rawValue - 1) ?? .details
        focusStepAfterTransition()
    }

    /// Moves VoiceOver focus to the new step's heading — previously Next/Back
    /// only played a sound, leaving focus on the previous step's now-gone
    /// controls with nothing announcing the step actually changed. Delayed
    /// since setting focus before the new section has laid out is a common
    /// way for it to silently fail.
    private func focusStepAfterTransition() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isStepFocused = true
        }
    }

    private func submit() async {
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitContact(name: name, email: email, subject: subject, message: message)
        switch result {
        case .ok:
            toast.success("Message sent")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
