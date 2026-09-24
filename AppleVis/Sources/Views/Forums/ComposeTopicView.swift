import SwiftUI

struct ComposeTopicView: View {
    /// Previously discarded — ForumsBrowseView had no way to show the new
    /// topic or move VoiceOver focus to it without a manual pull-to-refresh.
    var onPosted: (ForumTopic) -> Void = { _ in }

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedCategory: ForumCategory?
    @State private var categories: [ForumCategory] = []
    /// Seeded from Settings > Notifications > Replies to My Posts (see the
    /// `.task` below) rather than always defaulting to true — that Settings
    /// toggle is the one actual control for "notify me when someone replies
    /// to something I posted," so this screen's own toggle should reflect
    /// it, not silently override it with a hardcoded default. Still a
    /// per-post override: switch it off here for just this one topic
    /// without touching the Settings preference. Best-effort on submit (see
    /// `submit()`) — a failed follow-along never blocks or reverts the
    /// topic post itself. Requested directly.
    @State private var followOnPost = true
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
    /// Gates `showSignIn` above via `.communityAgreementGate(...)` below —
    /// see `CommunityAgreementStore`.
    @State private var showCommunityAgreement = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var communityAgreement: CommunityAgreementStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @State private var justRewrote = false
    /// Now focuses the header, not the title field — matches how every
    /// other wizard-style screen in the app (Setup, the Welcome Tour,
    /// Submit/Contact) focuses its heading first, not straight into a
    /// field. Previously focused the title field directly for the reason
    /// given in the (now removed) comment here; this brings it in line
    /// with the rest of the app instead.
    @AccessibilityFocusState private var isHeaderFocused: Bool

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedCategory != nil
    }

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
                        Section {
                            WizardStepHeader(
                                title: "New Topic", icon: "plus.bubble",
                                stepIndex: 1, stepTotal: 1, headerFocus: $isHeaderFocused
                            )
                            Text("Share a new discussion with the AppleVis community.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Section("Title") {
                            TextField("Topic title", text: $title)
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
                                    draftText: bodyText,
                                    context: "Forum Topic",
                                    onDismiss: { guidelines.dismiss() },
                                    onRewriteRespectfully: {
                                        Task {
                                            if let result = await intelligence.rewriteRespectfully(subject: title, body: bodyText, isTopic: true) {
                                                title = result.subject ?? title
                                                bodyText = result.body
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
                        Section("Body") {
                            TextEditor(text: $bodyText)
                                .frame(minHeight: 200)
                                .rewriteFlash($justRewrote)
                                .onChange(of: bodyText) { _, newValue in
                                    guidelines.textChanged(newValue)
                                    intelligence.textChanged(
                                        newValue,
                                        translationEnabled: preferences.composeTranslationEnabled,
                                        detectionEnabled: preferences.nonEnglishDetectionEnabled
                                    )
                                }
                            rewriteButton
                        }
                        Section {
                            Toggle("Follow This Topic", isOn: $followOnPost)
                                .accessibilityHint(String(localized: "Notifies you when someone replies. You can unfollow anytime from the topic itself."))
                        } footer: {
                            Text("Get notified when people reply to your topic. Starts on or off based on Settings > Notifications > Replies to My Posts — turn it off here for just this one topic without changing that setting.")
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
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut, value: guidelines.topWarning?.id)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await submit() }
                        } label: {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Post")
                            }
                        }
                        .disabled(!isValid || isSubmitting)
                    }
                }
            }
            .task { await loadCategories() }
            .task { followOnPost = preferences.notifyForumReplies }
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
            .communityAgreementGate(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
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
            Button("Sign In") {
                communityAgreement.requestSignIn(showCommunityAgreement: $showCommunityAgreement, showSignIn: $showSignIn)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    if let result = await intelligence.rewrite(subject: title, body: bodyText, isTopic: true) {
                        title = result.subject ?? title
                        bodyText = result.body
                        justRewrote = true
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
                    .symbolEffect(.bounce, value: justRewrote)
            }
            .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
        }
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
            var posted = try await APIClient.shared.forums.submitTopic(title: title, body: bodyText, categoryTid: cat.tid, csrfToken: user.csrfToken)
            toast.success(String(localized: "Topic posted"))
            if followOnPost {
                posted.isFollowing = await followNewTopic(posted, token: user.csrfToken)
            }
            onPosted(posted)
            dismiss()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = String(localized: "Couldn't post topic. Try again.") }
        isSubmitting = false
    }

    /// Best-effort — the topic itself already posted successfully by the
    /// time this runs, so a failed follow-along (network blip, etc.)
    /// shouldn't block, revert, or alarm the user over it. They can always
    /// follow manually from the topic itself if this quietly doesn't stick.
    private func followNewTopic(_ topic: ForumTopic, token: String) async -> Bool {
        do {
            try await APIClient.shared.forums.follow(nodeUuid: topic.id, entityId: topic.nid ?? 0, token: token)
            PersistenceStore.shared.markFollowed(FollowedItem(
                id: topic.id, kind: .forumTopic, nodeType: "node--forum",
                title: topic.title, followedAt: Date(), lastActivityAt: topic.lastActivityAt, url: topic.url
            ))
            FollowStore.shared.markFollowed(topic.id)
            return true
        } catch {
            return false
        }
    }
}

struct ComposeReplyView: View {
    let topicId: String
    let topicTitle: String
    /// Set when opened via a comment's "Reply to this Comment" action
    /// (ForumTopicDetailView) — the header below already says "Replying to
    /// [Author]," and `submit()` sends this comment's id as the real Drupal
    /// `pid` relationship. No longer prefills a text quote into the body:
    /// that was the only way to record "this is a reply to that" before the
    /// site exposed its own `pid` field via a "Reply" button (see
    /// `ForumReply.parentId`'s doc comment) — now that a real citation
    /// renders on the posted comment itself, baking a second, redundant
    /// "X wrote: > excerpt" into the permanent body text would just be
    /// clutter, and it's not how the website's own new Reply button works
    /// either (confirmed live: it never touches the body).
    var quotedReply: ForumReply? = nil
    let onPosted: (ForumReply) -> Void

    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var showDiscardConfirm = false
    @State private var justRewrote = false
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
    }

    /// RN confirmed before discarding a filled-out form; Cancel here
    /// previously dismissed immediately with no warning.
    private func requestCancel() {
        if !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                WizardStepHeader(
                    title: "Reply", icon: "arrowshape.turn.up.left",
                    stepIndex: 1, stepTotal: 1, headerFocus: $isHeaderFocused
                )
                .padding(.top)
                Text(quotedReply != nil ? String(localized: "Replying to \(quotedReply!.authorName) — Re: \(topicTitle)") : String(localized: "Re: \(topicTitle)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                // Read-only context, not part of the actual comment body —
                // see `quotedReply`'s doc comment for why this no longer
                // gets typed into `bodyText` itself. VoiceOver already has
                // this same text via the header above (announced first,
                // since this element isn't itself an accessibility stop);
                // this is here purely for a sighted/low-vision user glancing
                // at the compose screen while writing.
                if let quotedReply {
                    Text(quotedReply.body.strippingHTMLTags())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)
                }
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: bodyText, isTopic: false) {
                                bodyText = result.body
                                justRewrote = true
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
                        draftText: bodyText,
                        context: "Forum Reply",
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: bodyText, isTopic: false) {
                                    bodyText = result.body
                                    justRewrote = true
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(UIAccessibility.isReduceMotionEnabled ? .identity : .opacity.combined(with: .move(edge: .top)))
                }
                TextEditor(text: $bodyText)
                    .padding()
                    .rewriteFlash($justRewrote)
                    .onChange(of: bodyText) { _, newValue in
                        guidelines.textChanged(newValue, isReply: true)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                if let error {
                    Text(error).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut, value: guidelines.topWarning?.id)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { requestCancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Post")
                        }
                    }
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

    /// Was a toolbar button under the overflow "More" menu — easy to miss,
    /// and its scope wasn't obvious from a generic toolbar label. Now sits
    /// directly under the field it rewrites, matching Submit App/Blog's
    /// existing pattern. Reported directly.
    @ViewBuilder
    private var rewriteButton: some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: nil, body: bodyText, isTopic: false) {
                        bodyText = result.body
                        justRewrote = true
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
                    .symbolEffect(.bounce, value: justRewrote)
            }
            .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
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
            let reply = try await APIClient.shared.forums.submitReply(
                topicId: topicId, body: bodyText, csrfToken: user.csrfToken, replyToCommentId: quotedReply?.id
            )
            toast.success(String(localized: "Reply posted"))
            SoundPlayer.shared.play(.reply)
            onPosted(reply)
            dismiss()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = String(localized: "Couldn't post reply. Try again.") }
        isSubmitting = false
    }
}
