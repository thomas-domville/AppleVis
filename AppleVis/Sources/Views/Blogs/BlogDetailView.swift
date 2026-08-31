import SwiftUI

struct BlogDetailView: View {
    let postId: String
    /// Set when opened via a card's "Jump to First New Comment" action —
    /// see the same property on ForumTopicDetailView for the full
    /// reasoning; routed the same way through DeepLinkRouter.pendingContentIntent.
    var focusFirstNewCommentOnAppear: Bool = false
    @State private var hasAppliedFirstNewCommentFocus = false
    @State private var detail: BlogPostDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCompose = false
    @State private var quotedComment: BlogComment?
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var newCommentCount = 0
    @State private var pendingFocusCommentId: String?
    @State private var discussionSummary: String?
    @State private var isSummarizingDiscussion = false
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Group {
            if isLoading && detail == nil {
                LoadingView()
            } else if let err = error, detail == nil {
                ErrorView(message: err) { await load() }
            } else if let detail {
                content(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .handoff(title: detail?.title, url: detail?.url)
        .task {
            SoundPlayer.shared.play(.articleOpen)
            await load()
        }
    }

    @ViewBuilder
    private func content(_ detail: BlogPostDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Blog", systemImage: "newspaper")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            // Combined into one line/one VoiceOver stop
                            // rather than a separate swipe, per direct
                            // feedback.
                            Text(postAndActivityDateText(detail))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(detail.title)
                            .font(.title2).fontWeight(.semibold)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isTitleFocused)
                        // Inert plain text everywhere except Forums'
                        // matching topic header, despite authorId already
                        // being available (BLOGS-06).
                        AuthorProfileButton(name: "by \(detail.authorName)", authorId: detail.authorId)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    SegmentedHTMLView(html: detail.body)
                        .padding(.horizontal)

                    Divider()

                    if preferences.aiSummariesEnabled && IntelligenceService.isAvailable {
                        aiSummarySection(detail)
                    }

                    // Comments
                    commentsSection(detail, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
                .padding(.vertical)
            }
            .background(preferences.colors.background)
            // No focus confirmation after posting a comment, unlike Forums'
            // well-implemented equivalent (ALL-04).
            .onChange(of: pendingFocusCommentId) { _, newId in
                guard let newId else { return }
                withReduceMotionAwareAnimation { proxy.scrollTo(newId, anchor: .bottom) }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    focusedCommentId = newId
                    pendingFocusCommentId = nil
                }
            }
            .task {
                guard focusFirstNewCommentOnAppear, !hasAppliedFirstNewCommentFocus else { return }
                hasAppliedFirstNewCommentFocus = true
                await jumpToFirstNewComment(proxy: proxy)
            }
            // See ForumTopicDetailView's identical pair for the full
            // reasoning; BlogComment has no per-item "isNew" flag, so this
            // is the newest `newCommentCount` comments by position.
            .accessibilityRotor("New Comments") {
                ForEach(detail.comments.newestSuffix(count: newCommentCount)) { comment in
                    AccessibilityRotorEntry(comment.authorName, id: comment.id)
                }
            }
            .accessibilityRotor("Replies to Me") {
                ForEach(detail.comments.filter { comment in
                    guard let name = auth.user?.name else { return false }
                    return QuotedReply.isDirectedAt(name, body: comment.body)
                }) { comment in
                    AccessibilityRotorEntry(comment.authorName, id: comment.id)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(
                id: detail.id, kind: .blogPost, title: detail.title, lastActivityAt: detail.lastActivityAt, url: detail.url,
                onAddComment: { showCompose = true }
            )
        }
        .sheet(isPresented: $showCompose) {
            ComposeBlogCommentView(blogId: detail.id, title: detail.title) { comment in
                self.detail?.comments.append(comment)
                pendingFocusCommentId = comment.id
            }
        }
        .sheet(item: $quotedComment) { target in
            ComposeBlogCommentView(blogId: detail.id, title: detail.title, quotedComment: target) { comment in
                self.detail?.comments.append(comment)
                pendingFocusCommentId = comment.id
            }
        }
    }

    @ViewBuilder
    private func commentsSection(_ detail: BlogPostDetail, proxy: ScrollViewProxy) -> some View {
        CommunityDiscussionHeading(
            count: detail.commentCount,
            onThreadOverview: { announceThreadOverview(detail) },
            onJumpToLast: { Task { await jumpToLastComment(proxy: proxy) } },
            newCount: newCommentCount,
            onJumpToFirstNew: { Task { await jumpToFirstNewComment(proxy: proxy) } }
        )

        if detail.comments.isEmpty {
            Text("No comments yet.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal)
        } else {
            ForEach(Array(detail.comments.enumerated()), id: \.element.id) { index, comment in
                CommentRow(
                    authorName: comment.authorName, text: comment.body, date: comment.createdAt,
                    index: index, total: detail.comments.count,
                    subject: comment.subject, parentTitle: detail.title, parentURL: detail.url,
                    commentId: comment.id, authorId: comment.authorId, commentType: "comment_node_blog2",
                    supportsReport: false,
                    onDelete: {
                        self.detail?.comments.removeAll { $0.id == comment.id }
                    },
                    onUnpublish: {
                        self.detail?.comments.removeAll { $0.id == comment.id }
                    },
                    onEdit: { newText in
                        guard let idx = self.detail?.comments.firstIndex(where: { $0.id == comment.id }) else { return }
                        self.detail?.comments[idx] = BlogComment(id: comment.id, authorName: comment.authorName, authorId: comment.authorId, subject: comment.subject, body: newText, createdAt: comment.createdAt)
                    },
                    onReplyTo: {
                        guard auth.isSignedIn else {
                            toast.warning(String(localized: "Sign in to reply to comments."))
                            return
                        }
                        quotedComment = comment
                    },
                    focusBinding: $focusedCommentId
                )
                .id(comment.id)
                Divider().padding(.leading)
            }

            if hasMoreComments {
                if isLoadingMoreComments {
                    ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…")).padding()
                } else {
                    let remaining = detail.commentCount - detail.comments.count
                    Button(remaining > 0 ? "Load \(remaining) More Comments" : "Load More Comments") {
                        Task { await loadMoreComments() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }

    @ViewBuilder
    private func aiSummarySection(_ detail: BlogPostDetail) -> some View {
        if detail.comments.count >= 5 {
            VStack(alignment: .leading, spacing: 12) {
                discussionSummaryRow(detail)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func discussionSummaryRow(_ detail: BlogPostDetail) -> some View {
        if let discussionSummary {
            VStack(alignment: .leading, spacing: 4) {
                Label("Discussion Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.accentColor)
                Text(discussionSummary).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizeDiscussion(detail) }
            } label: {
                if isSummarizingDiscussion {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Summarize Discussion", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizingDiscussion)
            .accessibilityLabel(String(localized: isSummarizingDiscussion ? "Summarizing discussion, please wait" : "Summarize Discussion"))
        }
    }

    private func postAndActivityDateText(_ detail: BlogPostDetail) -> String {
        let posted = detail.publishedAt.formatted(.relative(presentation: .named))
        guard detail.commentCount > 0 else { return posted }
        return "\(posted), last comment \(detail.lastActivityAt.formatted(.relative(presentation: .named)))"
    }

    private func summarizeDiscussion(_ detail: BlogPostDetail) async {
        isSummarizingDiscussion = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing discussion. This may take a moment.")
        let maxTotalCharacters = 3000
        let maxPerComment = 220
        var parts: [String] = []
        var remaining = maxTotalCharacters
        for comment in detail.comments.prefix(20) {
            guard remaining > 0 else { break }
            let body = comment.body.strippingHTMLTags().prefix(maxPerComment)
            let part = "\(comment.authorName): \(body)"
            parts.append(String(part.prefix(remaining)))
            remaining -= part.count
        }
        let input = "Blog post: \(detail.title)\n\n\(parts.joined(separator: "\n\n"))"
        if let summary = await IntelligenceService.summarize(input) {
            discussionSummary = summary
        } else {
            toast.error(String(localized: "Couldn't generate a discussion summary. Try again."))
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate a discussion summary.")
        }
        isSummarizingDiscussion = false
    }

    /// VoiceOver "Thread overview" custom action on the comments heading —
    /// a spoken summary in place of manually reading through every comment.
    private func announceThreadOverview(_ detail: BlogPostDetail) {
        let mostRecent = detail.comments.max { $0.createdAt < $1.createdAt }
        var summary = "Thread has \(detail.comments.count) comment\(detail.comments.count == 1 ? "" : "s")."
        if let mostRecent {
            summary += " Most recent comment by \(mostRecent.authorName), \(mostRecent.createdAt.formatted(.relative(presentation: .named)))."
        }
        summary += " Original post by \(detail.authorName)."
        UIAccessibility.post(notification: .announcement, argument: summary)
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            detail = try await APIClient.shared.blogs.detail(id: postId)
            // Was `>= 100` (the page size requested, not what the server
            // actually returns — Drupal JSON:API commonly clamps a
            // requested page[limit] down to a lower site-configured max,
            // e.g. 50, so a post with hundreds of comments could get back
            // only 50 on the first page and this would never fire).
            // Comparing against the post's own known commentCount is
            // correct regardless of the server's actual page size.
            hasMoreComments = (detail?.comments.count ?? 0) < (detail?.commentCount ?? 0)
            // Fetch every remaining page automatically instead of waiting for
            // a "Load More" tap — the heading already shows the true total
            // (commentCount), so leaving the rest behind a manual tap just
            // contradicted what the count said was there.
            if hasMoreComments {
                Task { await loadMoreComments() }
            }
            if let detail {
                // Captured before stampItemVisit below overwrites it (ALL-01).
                newCommentCount = PersistenceStore.shared.newReplyCount(
                    kind: .blogPost, id: detail.id, currentCount: detail.commentCount
                )
                PersistenceStore.shared.stampItemVisit(
                    id: FeedItem.visitKey(kind: .blogPost, contentId: detail.id),
                    commentCount: detail.commentCount
                )
                // Keeps the website's own "read" state (Drupal core's
                // History module) in sync with what's viewed in the app —
                // signed-out users still rely on the local stamp above only.
                if let csrfToken = auth.user?.csrfToken {
                    Task { await APIClient.shared.history.markRead(nid: detail.nid, csrfToken: csrfToken) }
                }
                SpotlightIndexer.index(BlogPost(
                    id: detail.id, title: detail.title, authorName: detail.authorName, authorId: detail.authorId,
                    publishedAt: detail.publishedAt, lastActivityAt: detail.lastActivityAt,
                    summary: detail.body, commentCount: detail.commentCount, url: detail.url, isSaved: false
                ))
            }
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load post." }
        isLoading = false
        focusTitleAfterLoad()
    }

    /// VoiceOver lands on the back button after push navigation by default;
    /// this moves it to the page heading instead, per
    /// docs/IMPLEMENTATION_NOTES.md's "VoiceOver Detail Page Navigation"
    /// guidance. Retries at each delay rather than a single guessed one —
    /// a single attempt could silently go nowhere on a slower device or
    /// slower load. Reported directly.
    private func focusTitleAfterLoad() {
        Task {
            await retryAccessibilityFocus(into: $isTitleFocused)
        }
    }

    /// Loads every remaining page in one go instead of requiring a tap per
    /// page — the server clamps each request to its own max page size, so a
    /// post with many comments could otherwise take several manual
    /// "Load More" taps to fully unroll.
    private func loadMoreComments() async {
        isLoadingMoreComments = true
        do {
            while let current = self.detail, current.comments.count < current.commentCount {
                let more = try await APIClient.shared.blogs.moreComments(blogId: current.id, offset: current.comments.count)
                guard !more.isEmpty else { break }
                self.detail?.comments.append(contentsOf: more)
            }
        } catch {
            toast.error(String(localized: "Couldn't load more comments."))
        }
        hasMoreComments = (self.detail?.comments.count ?? 0) < (self.detail?.commentCount ?? 0)
        isLoadingMoreComments = false
    }

    /// "Jump to Last Comment" custom action on the Community Discussion
    /// heading — loads any not-yet-fetched comments first so it always
    /// lands on the true last one, then moves VoiceOver focus there.
    private func jumpToLastComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await loadMoreComments() }
        guard let lastId = self.detail?.comments.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = lastId
    }

    /// "Jump to First New Comment" (ALL-01) — comments arrive chronologically
    /// oldest-first, so the first of the `newCommentCount` most recently
    /// posted comments sits at `comments.count - newCommentCount`.
    private func jumpToFirstNewComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await loadMoreComments() }
        let comments = self.detail?.comments ?? []
        let targetIndex = comments.count - newCommentCount
        guard newCommentCount > 0, targetIndex >= 0, targetIndex < comments.count else { return }
        let targetId = comments[targetIndex].id
        withReduceMotionAwareAnimation { proxy.scrollTo(targetId, anchor: .top) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = targetId
    }
}

// MARK: - Compose blog comment

struct ComposeBlogCommentView: View {
    let blogId: String
    let title: String
    var quotedComment: BlogComment? = nil
    let onPosted: (BlogComment) -> Void

    @State private var commentText: String
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()

    init(blogId: String, title: String, quotedComment: BlogComment? = nil, onPosted: @escaping (BlogComment) -> Void) {
        self.blogId = blogId
        self.title = title
        self.quotedComment = quotedComment
        self.onPosted = onPosted
        if let quotedComment {
            _commentText = State(initialValue: QuotedReply.prefix(authorName: quotedComment.authorName, body: quotedComment.body))
        } else {
            _commentText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(quotedComment != nil ? "Replying to \(quotedComment!.authorName) — Re: \(title)" : "Re: \(title)")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: commentText, isTopic: false) {
                                commentText = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                    .padding(.horizontal)
                }
                if let warning = guidelines.topWarning {
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: commentText, isTopic: false) {
                                    commentText = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                }
                TextEditor(text: $commentText)
                    .padding()
                    .onChange(of: commentText) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                if let err = submitError {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            body: commentText
        ) {
            submitError = message
            return
        }
        isSubmitting = true; submitError = nil
        do {
            let comment = try await APIClient.shared.blogs.submitComment(
                blogId: blogId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Comment posted"))
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Couldn't post comment. Try again." }
        isSubmitting = false
    }
}
