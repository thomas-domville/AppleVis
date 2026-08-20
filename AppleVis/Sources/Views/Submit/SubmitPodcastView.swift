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
    @AccessibilityFocusState private var isErrorFocused: Bool

    @State private var step: Step = .audio
    @State private var showSignIn = false
    @State private var description = ""
    @State private var audioFileURL: URL?
    @State private var audioFileData: Data?
    @State private var showFileImporter = false
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @State private var submitted = false
    @State private var descriptionMinimumAnnounced = false

    /// Set when opened from the Share Extension with a shared podcast URL.
    /// This form needs an actual audio file upload — a shared link can't
    /// satisfy that — so the URL is dropped into the description as context
    /// rather than claimed as an attachment.
    init(prefillSharedURL: String? = nil) {
        if let prefillSharedURL {
            _description = State(initialValue: "Shared from: \(prefillSharedURL)\n\n")
        }
    }

    /// 20-char minimum on the description matches legacy's
    /// `submit-podcast/index.tsx` `canContinue`, dropped in the native port
    /// (SUBMIT-017).
    private var descriptionLength: Int { description.trimmingCharacters(in: .whitespacesAndNewlines).count }

    private var audioValid: Bool {
        descriptionLength >= 20 && audioFileData != nil
    }

    /// Mirrors Contact's crossing-the-threshold announcement so VoiceOver
    /// users learn the moment they can continue, not just via Next's
    /// disabled state.
    private func handleDescriptionChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !descriptionMinimumAnnounced && length >= 20 {
            descriptionMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached. You can now continue.")
        } else if descriptionMinimumAnnounced && length < 20 {
            descriptionMinimumAnnounced = false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: "mic",
                        heading: "Podcast submitted!",
                        message: "Thanks for sharing your podcast. The AppleVis team will review it before it appears in the directory.",
                        doneLabel: "Done",
                        onDone: { dismiss() }
                    )
                } else if !auth.isSignedIn {
                    signInRequiredView
                } else {
                    Form {
                        switch step {
                        case .audio:  audioSection
                        case .review: reviewSection
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
            .navigationTitle("Submit a Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .audio ? "Cancel" : "Back") {
                        if step == .audio {
                            requestCancel()
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
                                .disabled(!audioValid)
                        }
                    }
                }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio], onCompletion: handleFileImport)
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
    }

    /// RN confirmed before discarding a filled-out form; Cancel here
    /// previously dismissed immediately with no warning, silently losing a
    /// selected audio file/description with one accidental tap — same
    /// regression already fixed for Submit App, now matched here.
    private func requestCancel() {
        let hasProgress = audioFileData != nil || !description.trimmingCharacters(in: .whitespaces).isEmpty
        if hasProgress {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
    }

    /// fileImporter hands back a security-scoped URL for files outside the
    /// sandbox (iCloud Drive, other Files providers) — that access is only
    /// valid for the duration of this callback, and `submit()` runs much
    /// later after Review. Read the bytes into memory now, while the scope
    /// is open, instead of deferring the read to submit time (which
    /// previously read via `try? Data(contentsOf:)` with no scope at all,
    /// silently producing no data and no error for iCloud Drive picks —
    /// the audio was simply omitted from the multipart body server-side).
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                toast.error(String(localized: "Couldn't read that audio file. Try choosing it again."))
                return
            }
            audioFileURL = url
            audioFileData = data
        case .failure:
            toast.error(String(localized: "Couldn't read that audio file. Try choosing it again."))
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
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: description, isTopic: false) {
                                    description = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }
            Section {
                HStack {
                    Text("Episode Description").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(descriptionLength < 20 ? "\(descriptionLength) / 20 min" : "\(descriptionLength) chars")
                        .font(.caption)
                        .fontWeight(descriptionLength < 20 ? .bold : .regular)
                        .foregroundStyle(descriptionLength < 20 ? .red : .secondary)
                        .accessibilityLabel(descriptionLength < 20 ? String(localized: "\(descriptionLength) of 20 minimum characters") : String(localized: "\(descriptionLength) characters"))
                }
                TextEditor(text: $description)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Episode Description"))
                    .accessibilityHint(String(localized: "Required. Minimum 20 characters."))
                    .onChange(of: description) { _, newValue in
                        handleDescriptionChange(newValue)
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
                .accessibilityHint(String(localized: "Opens the Files app to pick an audio file for this episode."))
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
        if let message = ContentSubmissionPolicy.blockingMessage(
            body: description,
            detectNonEnglish: preferences.nonEnglishDetectionEnabled
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitPodcast(
            name: user.name, email: "", description: description,
            audioFileName: audioFileURL?.lastPathComponent, audioFileData: audioFileData
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
