import SwiftUI

struct BugDetailView: View {
    let bugId: String
    /// Set when opened via a card's "Jump to First New Comment" action —
    /// see the same property on ForumTopicDetailView for the full
    /// reasoning; routed the same way through DeepLinkRouter.pendingContentIntent.
    var focusFirstNewCommentOnAppear: Bool = false
    @State private var hasAppliedFirstNewCommentFocus = false
    /// Set when opened from the admin Guideline Violation Check screen for a
    /// flagged comment — see `ForumTopicDetailView.targetCommentId` for the
    /// full reasoning.
    var targetCommentId: String? = nil
    @State private var hasAppliedTargetCommentFocus = false
    @State private var detail: BugReportDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    // Mirrors ForumTopicDetailView.loadAllRepliesTask — prevents load()'s
    // background drain-all and "Jump to First New Comment"/"Jump to Last
    // Comment" from both starting their own concurrent loadMoreComments()
    // loop, which raced on comments.count and duplicated pages.
    @State private var loadAllCommentsTask: Task<Void, Never>?
    @State private var newCommentCount = 0
    @State private var pendingFocusCommentId: String?
    @State private var showCompose = false
    @State private var quotedComment: BugComment?
    @State private var discussionSummary: String?
    @State private var isSummarizingDiscussion = false
    // Bug report-level moderation — mirrors ForumTopicDetailView's own
    // Edit/Unpublish/Delete via DetailActionsMenu; the original reporter
    // gets Edit + Delete, an admin/editor gets Edit + Unpublish + Delete.
    // Previously bug reports had no owner or admin moderation at all.
    @State private var editingBugNode: EditableNode?
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore

    /// Matches the old app's exact "Report to Apple" / "Apple Feedback ID"
    /// destination.
    private static let feedbackAssistantURL = URL(string: "https://feedbackassistant.apple.com/")!

    private func isOwnBugReport(_ detail: BugReportDetail) -> Bool {
        guard let user = auth.user else { return false }
        return !detail.authorId.isEmpty && user.uuid == detail.authorId
    }

    private func bugNodeTypeSuffix(for platform: BugPlatform) -> String {
        platform == .ios ? "ios_bug_report" : "os_x_bug_report"
    }

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
    private func content(_ detail: BugReportDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status banner
                    statusBanner(detail).padding(.horizontal)

                    // Title
                    Text(detail.title)
                        .font(.title2).fontWeight(.semibold)
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)

                    // Metadata
                    metaGrid(detail).padding(.horizontal)

                    if let feedbackId = detail.feedbackId, !feedbackId.isEmpty {
                        feedbackIdRow(feedbackId).padding(.horizontal)
                    }

                    Divider()

                    // Description
                    if !detail.body.isEmpty {
                        sectionHeading("Description")
                        SegmentedHTMLView(html: detail.body, contentKind: "bugReport", contentId: detail.id, field: "description").padding(.horizontal)
                    }

                    if let steps = detail.stepsToReproduce, !steps.isEmpty {
                        sectionHeading("Steps to Reproduce")
                        SegmentedHTMLView(html: steps, contentKind: "bugReport", contentId: detail.id, field: "steps").padding(.horizontal)
                    }

                    if let workaround = detail.workaround, !workaround.isEmpty {
                        sectionHeading("Workaround")
                        SegmentedHTMLView(html: workaround, contentKind: "bugReport", contentId: detail.id, field: "workaround").padding(.horizontal)
                    }

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
            // Keyed on isLoading so this waits for load() to finish: the
            // page can appear before the new-comment count is known (App
            // Store enrichment, Follow state), and jumping then found
            // nothing new and gave up — leaving VoiceOver on the title.
            // Reported directly.
            .task(id: isLoading) {
                guard !isLoading, focusFirstNewCommentOnAppear, !hasAppliedFirstNewCommentFocus else { return }
                hasAppliedFirstNewCommentFocus = true
                // Nothing to land on after all — load() skipped the title
                // for this, so put focus there instead of nowhere.
                if !(await jumpToFirstNewComment(proxy: proxy)), newCommentCount > 0 { focusTitleAfterLoad() }
            }
            .task {
                guard let targetCommentId, !hasAppliedTargetCommentFocus else { return }
                hasAppliedTargetCommentFocus = true
                if hasMoreComments { await ensureAllCommentsLoaded() }
                pendingFocusCommentId = targetCommentId
            }
            // See ForumTopicDetailView's identical pair for the full
            // reasoning; BugComment has no per-item "isNew" flag, so this
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
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Kept as its own dedicated icon rather than folded into
                // the actions menu below — filing with Apple directly is
                // this page's primary purpose, not a secondary action worth
                // an extra tap to reach, same reasoning as App Entry's
                // "Open in App Store."
                WebLink(
                    destination: Self.feedbackAssistantURL,
                    hint: String(localized: "Opens Feedback Assistant to file this with Apple directly."),
                    showsExternalIcon: false
                ) {
                    Image(systemName: "flag")
                }
                .accessibilityLabel(String(localized: "Report to Apple"))
                DetailActionsMenu(
                    id: detail.id, entityId: detail.nid, kind: .bugReport, title: detail.title, lastActivityAt: detail.changedAt, url: detail.url,
                    excerpt: .excerpt(from: detail.body),
                    isOwnContent: isOwnBugReport(detail),
                    onAddComment: { showCompose = true },
                    onEdit: { startEditBugReport(detail) },
                    onUnpublish: { await unpublishBugReport(detail) },
                    onDelete: { await deleteBugReport(detail) }
                )
            }
        }
        .sheet(item: $editingBugNode) { node in
            EditNodeSheet(initialTitle: node.title, initialBody: node.body, nodeTypeSuffix: node.nodeTypeSuffix) { newTitle, newBody in
                try await saveBugReportEdit(nodeTypeSuffix: node.nodeTypeSuffix, title: newTitle, body: newBody, format: node.format)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(
                id: detail.id, entityId: detail.nid, kind: .bugReport, title: detail.title, lastActivityAt: detail.changedAt, url: detail.url,
                onAddComment: { showCompose = true }
            )
        }
        .sheet(isPresented: $showCompose) {
            ComposeBugCommentView(platform: detail.platform, bugId: detail.id, title: detail.title) { comment in
                self.detail?.comments.append(comment)
                pendingFocusCommentId = comment.id
            }
        }
        .sheet(item: $quotedComment) { target in
            ComposeBugCommentView(platform: detail.platform, bugId: detail.id, title: detail.title, quotedComment: target) { comment in
                self.detail?.comments.append(comment)
                pendingFocusCommentId = comment.id
            }
        }
    }

    /// Matches the old app's tappable "Apple Feedback ID" row — the field
    /// was already fetched (`field_apple_feedback_`) but never displayed or
    /// used anywhere.
    private func feedbackIdRow(_ feedbackId: String) -> some View {
        WebLink(destination: Self.feedbackAssistantURL, showsExternalIcon: false) {
            HStack {
                Image(systemName: "exclamationmark.bubble").foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Feedback ID").font(.caption).foregroundStyle(.secondary)
                    Text(feedbackId).font(.subheadline).fontWeight(.medium)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Apple Feedback ID: \(feedbackId)."))
        .accessibilityHint(String(localized: "Double-tap to open Feedback Assistant."))
    }

    /// Two independent AI actions, matching Forums/Apps/Guides/Blogs —
    /// previously BugDetailView had no Apple Intelligence integration at
    /// all, the last content-detail screen without it.
    @ViewBuilder
    private func aiSummarySection(_ detail: BugReportDetail) -> some View {
        if detail.comments.count >= 5 {
            VStack(alignment: .leading, spacing: 12) {
                discussionSummaryRow(detail)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tintedBackground(Color.accentColor, opacity: 0.08, cornerRadius: 10)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func discussionSummaryRow(_ detail: BugReportDetail) -> some View {
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

    private func summarizeDiscussion(_ detail: BugReportDetail) async {
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
        let input = "Bug report: \(detail.title)\n\n\(parts.joined(separator: "\n\n"))"
        if let summary = await IntelligenceService.summarize(input) {
            discussionSummary = summary
        } else {
            toast.error(String(localized: "Couldn't generate a discussion summary. Try again."))
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate a discussion summary.")
        }
        isSummarizingDiscussion = false
    }

    private func statusBanner(_ detail: BugReportDetail) -> some View {
        HStack(spacing: 10) {
            Image(systemName: detail.status == .active ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(detail.status == .active ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(detail.status.displayName) · \(detail.severity.displayName) severity")
                    .font(.subheadline).fontWeight(.semibold)
                Text(detail.platform.displayName)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .tintedBackground(detail.status == .active ? Color.orange : Color.green, opacity: 0.1, cornerRadius: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(detail.status.displayName) bug on \(detail.platform.displayName). ") +
            String(localized: "\(detail.severity.displayName) severity.")
        )
    }

    private func metaGrid(_ detail: BugReportDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let firstSeen = detail.firstSeen {
                metaRow(label: "First Seen", value: firstSeen)
            }
            if let fixedIn = detail.fixedIn {
                metaRow(label: "Fixed In", value: fixedIn)
            }
            if let device = detail.device, !device.isEmpty {
                metaRow(label: "Device", value: device)
            }
            if let howOften = detail.howOften, !howOften.isEmpty {
                metaRow(label: "How Often", value: howOften)
            }
            metaRow(label: "Reported", value: detail.createdAt.formatted(.relative(presentation: .named)))
            metaRow(label: "Updated", value: detail.changedAt.formatted(.relative(presentation: .named)))
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // A fixed width here clipped the label at large accessibility
            // text sizes; minWidth keeps columns aligned at normal sizes
            // without capping how wide the label is allowed to grow.
            // Label was rendered verbatim (Text(String)) — never translated.
            (Text(LocalizedStringKey(label)) + Text(verbatim: ":"))
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Text(value)
                .font(.caption)
        }
        // Was missing here, unlike AppDetailView's structurally identical
        // infoRow — every metadata row (First Seen, Fixed In, Device, etc.)
        // exposed as two separate VoiceOver stops instead of one combined
        // "First Seen: March 2025"-style stop, doubling the swipes needed
        // to read through a bug's metadata block (BUGS-02).
        .accessibilityElement(children: .combine)
    }

    /// Matches BugReportEndpoints' private `commentBundle(for:)` — Edit/
    /// Delete need this comment-type string to hit the right Drupal bundle.
    private func bugCommentType(_ platform: BugPlatform) -> String {
        platform == .ios ? "comment_node_ios_bug_report" : "comment_node_os_x_bug_report"
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(LocalizedStringKey(text)).font(.headline)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func commentsSection(_ detail: BugReportDetail, proxy: ScrollViewProxy) -> some View {
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
                    commentId: comment.id, authorId: comment.authorId, commentType: bugCommentType(detail.platform),
                    onDelete: {
                        self.detail?.comments.removeAll { $0.id == comment.id }
                    },
                    onUnpublish: {
                        self.detail?.comments.removeAll { $0.id == comment.id }
                    },
                    onEdit: { newText in
                        guard let idx = self.detail?.comments.firstIndex(where: { $0.id == comment.id }) else { return }
                        self.detail?.comments[idx] = BugComment(
                            id: comment.id, authorName: comment.authorName, authorId: comment.authorId,
                            subject: comment.subject, body: newText, createdAt: comment.createdAt
                        )
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
                        Task { await ensureAllCommentsLoaded() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }

    /// VoiceOver "Thread overview" custom action on the comments heading —
    /// a spoken summary in place of manually reading through every comment.
    /// No "Original post by" line: BugReportDetail doesn't expose a
    /// submitter name (unlike forum topics, blog posts, and resources).
    private func announceThreadOverview(_ detail: BugReportDetail) {
        let mostRecent = detail.comments.max { $0.createdAt < $1.createdAt }
        ThreadOverview.announce(
            commentCount: detail.comments.count,
            mostRecentAuthor: mostRecent?.authorName,
            mostRecentDate: mostRecent?.createdAt
        )
    }

    private func startEditBugReport(_ detail: BugReportDetail) {
        editingBugNode = EditableNode(title: detail.title, body: detail.rawBody, format: detail.bodyFormat, nodeTypeSuffix: bugNodeTypeSuffix(for: detail.platform))
    }

    private func saveBugReportEdit(nodeTypeSuffix: String, title: String, body: String, format: String) async throws {
        guard let user = auth.user, let detail else { return }
        try await APIClient.shared.content.editNode(nodeId: detail.id, nodeType: nodeTypeSuffix, title: title, body: body, format: format, csrfToken: user.csrfToken)
        toast.success(String(localized: "Bug Report updated"))
        await load()
    }

    private func unpublishBugReport(_ detail: BugReportDetail) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.unpublishNode(nodeId: detail.id, nodeType: bugNodeTypeSuffix(for: detail.platform), csrfToken: user.csrfToken)
            toast.success(String(localized: "Bug Report unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish."))
        }
    }

    /// Deletes the bug report currently being viewed — unlike row-level
    /// deletion elsewhere, there's no list to prune; the only sensible next
    /// step is leaving the screen, matching ForumTopicDetailView.deleteTopic().
    private func deleteBugReport(_ detail: BugReportDetail) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteNode(nodeId: detail.id, nodeType: bugNodeTypeSuffix(for: detail.platform), csrfToken: user.csrfToken)
            toast.success(String(localized: "Bug Report deleted"))
            dismiss()
        } catch {
            toast.error(String(localized: "Couldn't delete."))
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            detail = try await APIClient.shared.bugReports.detail(id: bugId)
            hasMoreComments = (detail?.comments.count ?? 0) < (detail?.commentCount ?? 0)
            // Fetch every remaining page automatically instead of waiting for
            // a "Load More" tap — matches Forum/Blog/Guide/Podcast, which had
            // the same fix for the same reason: the heading shows the true
            // total, so leaving the rest behind a manual tap read as broken.
            if hasMoreComments {
                Task { await ensureAllCommentsLoaded() }
            }
            if let detail {
                // BugDetailView never called stampItemVisit at all — meaning
                // BugReportRow's existing "N new" badge (which reads
                // newReplyCount for .bugReport) could never show anything,
                // and this screen's own heading had no "new" count to show
                // either (ALL-01). Captured before the stamp overwrites it.
                newCommentCount = PersistenceStore.shared.newReplyCount(
                    kind: .bugReport, id: detail.id, currentCount: detail.commentCount
                )
                PersistenceStore.shared.stampItemVisit(
                    id: FeedItem.visitKey(kind: .bugReport, contentId: detail.id),
                    commentCount: detail.commentCount
                )
                // Keeps the website's own "read" state (Drupal core's
                // History module) in sync with what's viewed in the app —
                // signed-out users still rely on the local stamp above only.
                if let csrfToken = auth.user?.csrfToken {
                    Task { await APIClient.shared.history.markRead(nid: detail.nid, csrfToken: csrfToken) }
                }
                SpotlightIndexer.index(BugReport(
                    id: detail.id, title: detail.title, platform: detail.platform, status: detail.status,
                    severity: detail.severity, firstSeen: detail.firstSeen, fixedIn: detail.fixedIn,
                    feedbackId: detail.feedbackId, commentCount: detail.commentCount,
                    createdAt: detail.createdAt, changedAt: detail.changedAt,
                    summary: String(detail.body.prefix(200)), url: detail.url
                ))
            }
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load bug report." }
        isLoading = false
        // Opened via "Jump to First New Comment": that comment gets focus
        // instead. Title focus used to run regardless, and its retries could
        // pull focus straight back to the title. Reported directly.
        if !(focusFirstNewCommentOnAppear && newCommentCount > 0) { focusTitleAfterLoad() }
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
    /// page — same fix already applied to Forum/Blog/Guide/Podcast comments.
    private func loadMoreComments() async {
        isLoadingMoreComments = true
        do {
            while let current = self.detail, current.comments.count < current.commentCount {
                let more = try await APIClient.shared.bugReports.moreComments(
                    platform: current.platform, bugId: current.id, offset: current.comments.count
                )
                guard !more.isEmpty else { break }
                self.detail?.comments.append(contentsOf: more)
            }
        } catch {
            toast.error(String(localized: "Couldn't load more comments."))
        }
        hasMoreComments = (self.detail?.comments.count ?? 0) < (self.detail?.commentCount ?? 0)
        isLoadingMoreComments = false
    }

    /// Single-flight wrapper around loadMoreComments() — see
    /// loadAllCommentsTask's doc comment for why this exists.
    private func ensureAllCommentsLoaded() async {
        if let existing = loadAllCommentsTask {
            await existing.value
            return
        }
        let task = Task { await loadMoreComments() }
        loadAllCommentsTask = task
        await task.value
        loadAllCommentsTask = nil
    }

    /// "Jump to Last Comment" link on the Community Discussion heading —
    /// loads any not-yet-fetched comments first so it always lands on the
    /// true last one, then moves VoiceOver focus there.
    private func jumpToLastComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await ensureAllCommentsLoaded() }
        guard let lastId = self.detail?.comments.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = lastId
    }

    /// "Jump to First New Comment" (ALL-01) — comments arrive chronologically
    /// oldest-first, so the first of the `newCommentCount` most recently
    /// posted comments sits at `comments.count - newCommentCount`.
    @discardableResult
    private func jumpToFirstNewComment(proxy: ScrollViewProxy) async -> Bool {
        if hasMoreComments { await ensureAllCommentsLoaded() }
        let comments = self.detail?.comments ?? []
        let targetIndex = comments.count - newCommentCount
        guard newCommentCount > 0, targetIndex >= 0, targetIndex < comments.count else { return false }
        let targetId = comments[targetIndex].id
        withReduceMotionAwareAnimation { proxy.scrollTo(targetId, anchor: .top) }
        // Retried like the title focus — one assignment after a guessed
        // delay could miss a row that wasn't laid out yet.
        await retryAccessibilityFocus(targetId, into: $focusedCommentId)
        return true
    }
}

// MARK: - Compose bug comment

/// Bug report comments were read-only until now — no submitComment endpoint
/// existed at all, unlike every other content type. Matches the same
/// Compose*CommentView pattern used by Guides/Blogs/Podcasts.
struct ComposeBugCommentView: View {
    let platform: BugPlatform
    let bugId: String
    let title: String
    var quotedComment: BugComment? = nil
    let onPosted: (BugComment) -> Void

    @State private var commentText: String
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var justRewrote = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isHeaderFocused: Bool

    init(platform: BugPlatform, bugId: String, title: String, quotedComment: BugComment? = nil, onPosted: @escaping (BugComment) -> Void) {
        self.platform = platform
        self.bugId = bugId
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
                WizardStepHeader(
                    title: "Add Comment", icon: "text.bubble",
                    stepIndex: 1, stepTotal: 1, headerFocus: $isHeaderFocused
                )
                .padding(.top)
                Text(quotedComment != nil ? "Replying to \(quotedComment!.authorName) — Re: \(title)" : "Re: \(title)")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: commentText, isTopic: false) {
                                commentText = result.body
                                justRewrote = true
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
                        draftText: commentText,
                        context: "Bug Report Comment",
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: commentText, isTopic: false) {
                                    commentText = result.body
                                    justRewrote = true
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                        .transition(UIAccessibility.isReduceMotionEnabled ? .identity : .opacity.combined(with: .move(edge: .top)))
                }
                TextEditor(text: $commentText)
                    .padding()
                    .rewriteFlash($justRewrote)
                    .onChange(of: commentText) { _, newValue in
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
                if let err = submitError {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut, value: guidelines.topWarning?.id)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
                    .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    @ViewBuilder
    private var rewriteButton: some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: nil, body: commentText, isTopic: false) {
                        commentText = result.body
                        justRewrote = true
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
                    .symbolEffect(.bounce, value: justRewrote)
            }
            .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
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
            let comment = try await APIClient.shared.bugReports.submitComment(
                platform: platform, bugId: bugId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Comment posted"))
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Couldn't post comment. Try again." }
        isSubmitting = false
    }
}
