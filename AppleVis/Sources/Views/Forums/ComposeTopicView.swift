import SwiftUI

struct ComposeTopicView: View {
    /// Previously discarded — ForumsBrowseView had no way to show the new
    /// topic or move VoiceOver focus to it without a manual pull-to-refresh.
    var onPosted: (ForumTopic) -> Void = { _ in }

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedCategory: ForumCategory?
    @State private var categories: [ForumCategory] = []
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    /// Was reachable only from a toolbar button already hidden behind
    /// `auth.isSignedIn` (ForumsBrowseView) — never actually needed to
    /// handle being opened signed-out. Now that Home's Add menu shows this
    /// entry point to everyone (matching how Discover's Contribute section
    /// already treats Submit App/Blog/Podcast/Bug), a signed-out tap needs
    /// its own graceful prompt instead of a Post button that silently
    /// no-ops (`submit()`'s `guard let user = auth.user` already bailed
    /// with no feedback at all).
    @State private var showSignIn = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    // Mirrors OnboardingView's SignInStep: this screen's primary action is
    // typing into a field, so VoiceOver focus lands there directly rather
    // than on a generic heading — otherwise, like every other pushed
    // screen, it silently defaults to the back button after the push.
    @AccessibilityFocusState private var isTitleFieldFocused: Bool

    /// RN confirmed before discarding a filled-out form; Cancel here
    /// previously dismissed immediately with no warning, silently losing a
    /// written topic with one accidental tap — same regression already
    /// fixed for Submit App, now matched here.
    private func requestCancel() {
        let hasProgress = !title.trimmingCharacters(in: .whitespaces).isEmpty || !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
        if hasProgress {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInRequiredView
                } else {
                    Form {
                        Section("Title") {
                            TextField("Topic title", text: $title)
                                .accessibilityFocused($isTitleFieldFocused)
                        }
                        Section("Category") {
                            Picker("Category", selection: $selectedCategory) {
                                Text("Choose…").tag(Optional<ForumCategory>.none)
                                ForEach(categories) { cat in
                                    Text(cat.name).tag(Optional(cat))
                                }
                            }
                        }
                        if intelligence.showTranslatePrompt {
                            Section {
                                TranslatePromptView(isProcessing: intelligence.isProcessing) {
                                    Task {
                                        if let result = await intelligence.translate(subject: title, body: bodyText, isTopic: true) {
                                            title = result.subject ?? title
                                            bodyText = result.body
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
                                            if let result = await intelligence.rewriteRespectfully(subject: title, body: bodyText, isTopic: true) {
                                                title = result.subject ?? title
                                                bodyText = result.body
                                            } else {
                                                toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        Section("Body") {
                            TextEditor(text: $bodyText)
                                .frame(minHeight: 200)
                                .onChange(of: bodyText) { _, newValue in
                                    guidelines.textChanged(newValue)
                                    intelligence.textChanged(
                                        newValue,
                                        translationEnabled: preferences.composeTranslationEnabled,
                                        detectionEnabled: preferences.nonEnglishDetectionEnabled
                                    )
                                }
                        }
                        if let error {
                            Section {
                                Text(error).foregroundStyle(.red)
                            }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .task { await retryAccessibilityFocus(into: $isTitleFieldFocused) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn {
                    if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Rewrite") {
                                Task {
                                    if let result = await intelligence.rewrite(subject: title, body: bodyText, isTopic: true) {
                                        title = result.subject ?? title
                                        bodyText = result.body
                                    } else {
                                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                    }
                                }
                            }
                            .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Post") { Task { await submit() } }
                            .disabled(!isValid || isSubmitting)
                    }
                }
            }
            .task { await loadCategories() }
            .confirmationDialog(
                "Discard this submission?",
                isPresented: $showDiscardConfirm, titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { SoundPlayer.shared.play(.screenClose); dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your progress will be discarded.")
            }
            .sheet(isPresented: $showSignIn) { SignInView() }
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
            Text("You need to be signed in to your AppleVis account to post a new topic.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") { showSignIn = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadCategories() async {
        categories = (try? await APIClient.shared.forums.categories()) ?? []
    }

    private func submit() async {
        guard let user = auth.user, let cat = selectedCategory else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: title,
            body: bodyText
        ) {
            error = message
            return
        }
        isSubmitting = true
        error = nil
        do {
            let posted = try await APIClient.shared.forums.submitTopic(title: title, body: bodyText, categoryTid: cat.tid, csrfToken: user.csrfToken)
            toast.success(String(localized: "Topic posted"))
            onPosted(posted)
            dismiss()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Failed to post topic." }
        isSubmitting = false
    }
}

struct ComposeReplyView: View {
    let topicId: String
    let topicTitle: String
    /// Set when opened via a comment's "Reply to this Comment" VoiceOver
    /// action (ForumTopicDetailView) — prefills a quoted excerpt the same
    /// way the old RN compose screen's replyToAuthor/replyToQuote params did.
    var quotedReply: ForumReply? = nil
    let onPosted: (ForumReply) -> Void

    @State private var bodyText: String
    private let initialBodyText: String
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isHeaderFocused: Bool

    init(topicId: String, topicTitle: String, quotedReply: ForumReply? = nil, onPosted: @escaping (ForumReply) -> Void) {
        self.topicId = topicId
        self.topicTitle = topicTitle
        self.quotedReply = quotedReply
        self.onPosted = onPosted
        let initial: String
        if let quotedReply {
            let plain = quotedReply.body.strippingHTMLTags()
            let excerpt = plain.count > 150 ? String(plain.prefix(150)).trimmingCharacters(in: .whitespaces) + "…" : plain
            initial = "\(quotedReply.authorName) wrote:\n> \(excerpt)\n\n"
        } else {
            initial = ""
        }
        _bodyText = State(initialValue: initial)
        initialBodyText = initial
    }

    /// RN confirmed before discarding a filled-out form; Cancel here
    /// previously dismissed immediately with no warning. Compares against
    /// `initialBodyText` rather than plain emptiness — a quoted reply
    /// prefills a non-empty quote excerpt, which isn't itself "progress"
    /// worth confirming a discard over.
    private func requestCancel() {
        if bodyText != initialBodyText {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(quotedReply != nil ? "Replying to \(quotedReply!.authorName) — Re: \(topicTitle)" : "Re: \(topicTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isHeaderFocused)
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: bodyText, isTopic: false) {
                                bodyText = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                if let warning = guidelines.topWarning {
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: bodyText, isTopic: false) {
                                    bodyText = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                TextEditor(text: $bodyText)
                    .padding()
                    .onChange(of: bodyText) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                if let error {
                    Text(error).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { requestCancel() } }
                if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Rewrite") {
                            Task {
                                if let result = await intelligence.rewrite(subject: nil, body: bodyText, isTopic: false) {
                                    bodyText = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                        .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
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
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            body: bodyText
        ) {
            error = message
            return
        }
        isSubmitting = true
        error = nil
        do {
            let reply = try await APIClient.shared.forums.submitReply(topicId: topicId, body: bodyText, csrfToken: user.csrfToken)
            toast.success(String(localized: "Reply posted"))
            SoundPlayer.shared.play(.reply)
            onPosted(reply)
            dismiss()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Failed to post reply." }
        isSubmitting = false
    }
}
