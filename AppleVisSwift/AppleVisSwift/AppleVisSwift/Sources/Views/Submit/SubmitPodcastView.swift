import SwiftUI
import UniformTypeIdentifiers

/// Ported against src/services/drupalForm.ts's `/podcasts/upload` webform
/// (multipart, includes an audio file) and app/submit-podcast.
///
/// RN requires sign-in (submission silently no-ops without a user, and posts
/// under the account's name with no email field at all — verified via
/// `app/submit-podcast/review.tsx`'s `if (!user) return` + `name: user.name,
/// email: ''`) — Swift previously had no sign-in gate and asked for free-text
/// name/email instead.
///
/// Two-step wizard: Episode & Audio → Review.
struct SubmitPodcastView: View {
    private enum Step: Int { case audio, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool

    @State private var step: Step = .audio
    @State private var showSignIn = false
    @State private var description = ""
    @State private var audioFileURL: URL?
    @State private var showFileImporter = false
    @State private var isSubmitting = false
    @State private var error: String?

    /// Set when opened from the Share Extension with a shared podcast URL.
    /// This form needs an actual audio file upload — a shared link can't
    /// satisfy that — so the URL is dropped into the description as context
    /// rather than claimed as an attachment.
    init(prefillSharedURL: String? = nil) {
        if let prefillSharedURL {
            _description = State(initialValue: "Shared from: \(prefillSharedURL)\n\n")
        }
    }

    private var audioValid: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty && audioFileURL != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInRequiredView
                } else {
                    Form {
                        switch step {
                        case .audio:  audioSection
                        case .review: reviewSection
                        }
                        if let error {
                            Section { Text(error).foregroundStyle(.red) }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit a Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .audio ? "Cancel" : "Back") {
                        if step == .audio {
                            SoundPlayer.shared.play(.screenClose)
                            dismiss()
                        } else {
                            goBack()
                        }
                    }
                }
                if auth.isSignedIn {
                    if step == .audio && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Rewrite") {
                                Task {
                                    if let result = await intelligence.rewrite(subject: nil, body: description, isTopic: false) {
                                        description = result.body
                                    } else {
                                        toast.error("Couldn't rewrite this. Try again.")
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
                                .disabled(!audioValid)
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { audioFileURL = url }
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
            Text("You need to be signed in to your AppleVis account to submit a podcast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") { showSignIn = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var audioSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 1, total: 2, title: "Episode & Audio", isFocused: $isStepFocused)
                Text("Share your podcast about accessibility, Apple products, or blindness with the AppleVis community.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: description, isTopic: false) {
                                description = result.body
                            } else {
                                toast.error("Couldn't translate this. Try again.")
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
            Section("Episode Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 120)
                    .onChange(of: description) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
            }
            Section("Audio File") {
                Button {
                    showFileImporter = true
                } label: {
                    Label(audioFileURL?.lastPathComponent ?? "Choose Audio File", systemImage: "waveform")
                }
                .accessibilityHint("Opens the Files app to pick an audio file for this episode.")
            }
        }
    }

    private var reviewSection: some View {
        Group {
            Section { WizardStepIndicator(step: 2, total: 2, title: "Review & Submit", isFocused: $isStepFocused) }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("Episode") {
                WizardReviewRow(label: "Description", value: description)
                WizardReviewRow(label: "Audio File", value: audioFileURL?.lastPathComponent ?? "")
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
        step = Step(rawValue: step.rawValue - 1) ?? .audio
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
        let result = await DrupalFormClient.submitPodcast(name: user.name, email: "", description: description, audioFileURL: audioFileURL)
        switch result {
        case .ok:
            toast.success("Podcast submitted for review")
            dismiss()
        case .failure(let message):
            error = message
        }
        isSubmitting = false
    }
}
