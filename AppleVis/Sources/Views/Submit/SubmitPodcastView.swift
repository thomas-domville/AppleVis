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
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var communityAgreement: CommunityAgreementStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    @State private var step: Step = .audio
    @State private var showSignIn = false
    /// Gates `showSignIn` above via `.communityAgreementGate(...)` below —
    /// see `CommunityAgreementStore`.
    @State private var showCommunityAgreement = false
    @State private var description = ""
    @State private var audioFileURL: URL?
    @State private var audioFileData: Data?
    @State private var showFileImporter = false
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @State private var submitted = false
    @State private var descriptionMinimumAnnounced = false
    @State private var justRewrote = false

    /// Set when opened from the Share Extension with a shared podcast URL,
    /// or with a shared audio file itself. This form needs an actual audio
    /// file upload — a shared link can't satisfy that on its own — so a
    /// shared URL is dropped into the description as context rather than
    /// claimed as an attachment, while a shared audio file goes straight
    /// into the same state a manual "Choose Audio File" pick would.
    ///
    /// A previous pass here added an editable "Your Email" field, on the
    /// same reasoning that fixed Blog and Bug's genuinely-required email
    /// fields — checked directly against this form's own live HTML and
    /// that reasoning turns out not to apply: for a signed-in submitter,
    /// the real form shows name and email as plain read-only text (Drupal
    /// `item` elements, populated from the account), not editable inputs
    /// at all — there's no `name="mail"` field on the real form to send in
    /// the first place. Reverted; `DrupalFormClient.submitPodcast` no
    /// longer takes an email parameter either. Reported directly.
    init(prefillSharedURL: String? = nil, prefillAudioData: Data? = nil, prefillAudioFileName: String? = nil) {
        if let prefillSharedURL {
            _description = State(initialValue: "Shared from: \(prefillSharedURL)\n\n")
        }
        if let prefillAudioData, let prefillAudioFileName {
            _audioFileData = State(initialValue: prefillAudioData)
            _audioFileURL = State(initialValue: URL(fileURLWithPath: prefillAudioFileName))
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
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Minimum length reached. You can now continue."))
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
                        heading: "You did it — thanks!",
                        message: "Your podcast has been sent to our team. Thank you for sharing it. We'll let you know when it's ready to appear on AppleVis.",
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
                // Previously showed "Back" (not "Cancel") on Review, leaving
                // no way to actually leave the wizard from that step without
                // stepping backward first. Cancel now stays put regardless
                // of step; step-backward navigation moved to its own
                // in-content button below, matching Submit App/Blog/Bug's
                // existing convention. Reported directly.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn {
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button("Submit") { Task { await submit() } }
                                .disabled(isSubmitting || !networkMonitor.isConnected)
                                .accessibilityHint(networkMonitor.isConnected ? "" : String(localized: "You're offline. Reconnect to submit this."))
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
        .communityAgreementGate(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
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
                .accessibilityFocused($isStepFocused)
            Text("You need to be signed in to your AppleVis account to submit a podcast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") {
                communityAgreement.requestSignIn(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var audioSection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Episode & Audio", stepIndex: 1, stepTotal: 2, headerFocus: $isStepFocused)
                Text("Share your podcast about accessibility, Apple products, or blindness with the AppleVis community.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: description, isTopic: false) {
                                description = result.body
                                justRewrote = true
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
                        draftText: description,
                        context: "Submit Podcast",
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: description, isTopic: false) {
                                    description = result.body
                                    justRewrote = true
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
                .transition(UIAccessibility.isReduceMotionEnabled ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
            Section {
                // Combined label+counter into one live-updating swipe-stop,
                // and hid the trailing caption from VoiceOver — it repeats
                // text already in the field's own hint below. Same fix
                // applied to every minimum-length field across every
                // wizard. Reported directly.
                HStack {
                    Text("Episode Description").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(descriptionLength < 20 ? "\(descriptionLength) / 20 min" : "\(descriptionLength) chars")
                        .font(.caption)
                        .fontWeight(descriptionLength < 20 ? .bold : .regular)
                        .foregroundStyle(descriptionLength < 20 ? .red : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(descriptionLength < 20 ? String(localized: "Episode Description: \(descriptionLength) of 20 minimum characters") : String(localized: "Episode Description: \(descriptionLength) characters"))
                .accessibilityAddTraits(.updatesFrequently)
                TextEditor(text: $description)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Episode Description"))
                    .accessibilityHint(String(localized: "Required, at least 20 characters. Describe the topics, guests, or themes, so listeners know what to expect."))
                    .rewriteFlash($justRewrote)
                    .onChange(of: description) { _, newValue in
                        handleDescriptionChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                Text("Tell listeners what this episode covers, such as the topics, guests, or themes, so they know what to expect before they play it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                rewriteButton
            }
            Section("Audio File") {
                Button {
                    showFileImporter = true
                } label: {
                    Label(audioFileURL?.lastPathComponent ?? String(localized: "Choose Audio File"), systemImage: "waveform")
                }
                .accessibilityHint(String(localized: "Opens the Files app to pick an audio file for this episode."))
            }
            Section {
                WizardBlockingNote(reasons: audioBlockingReasons)
                WizardBottomButton(String(localized: "Next"), isEnabled: audioValid, action: goNext)
            }
        }
    }

    private var audioBlockingReasons: [String] {
        var reasons: [String] = []
        if descriptionLength < 20 {
            reasons.append(String(localized: "Write at least \(20 - descriptionLength) more characters to continue."))
        }
        if audioFileData == nil {
            reasons.append(String(localized: "Choose an audio file to continue."))
        }
        return reasons
    }

    /// Was a toolbar button under the overflow "More" menu — easy to miss,
    /// and its scope wasn't obvious from a generic toolbar label. Now sits
    /// directly under the field it rewrites, matching Submit App/Blog's
    /// existing pattern. Reported directly.
    @ViewBuilder
    private var rewriteButton: some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: nil, body: description, isTopic: false) {
                        description = result.body
                        justRewrote = true
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
                    .symbolEffect(.bounce, value: justRewrote)
            }
            .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
        }
    }

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepHeader(title: "Review & Submit", stepIndex: 2, stepTotal: 2, onBack: goBack, headerFocus: $isStepFocused)
                Text("Check your details, then tap Submit.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("Episode") {
                WizardReviewRow(label: "Description", value: description)
                WizardReviewRow(label: "Audio File", value: audioFileURL?.lastPathComponent ?? "")
            }
            if !networkMonitor.isConnected {
                Section {
                    OfflineComposeNotice()
                }
                .listRowSeparator(.hidden)
            }
            Section {
                WizardBottomButton(
                    String(localized: "Submit"),
                    isEnabled: !isSubmitting && networkMonitor.isConnected, isLoading: isSubmitting
                ) { Task { await submit() } }
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

    /// Was a single guessed 300ms delay — see SubmitAppView's identical fix
    /// for the full reasoning. Full app-wide focus audit, requested
    /// directly.
    private func focusStepAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isStepFocused) }
    }

    /// Step-backward navigation, separated from the toolbar's Cancel button
    /// so a user can discard the submission from any step.
    private func submit() async {
        // The real form derives the submitter from the authenticated
        // session server-side — no `name`/`mail` field to pass along (see
        // `DrupalFormClient.submitPodcast`) — but this screen still
        // shouldn't let a signed-out state reach the network call at all.
        guard auth.isSignedIn else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            body: description
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        let result = await DrupalFormClient.submitPodcast(
            description: description,
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
