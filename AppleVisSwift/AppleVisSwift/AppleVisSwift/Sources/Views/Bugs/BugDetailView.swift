import SwiftUI

struct BugDetailView: View {
    let bugId: String
    @State private var detail: BugReportDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @State private var showCompose = false
    @State private var quotedComment: BugComment?
    @State private var bugSummary: String?
    @State private var isSummarizingBug = false
    @State private var discussionSummary: String?
    @State private var isSummarizingDiscussion = false
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore

    /// Matches the old app's exact "Report to Apple" / "Apple Feedback ID"
    /// destination.
    private static let feedbackAssistantURL = URL(string: "https://feedbackassistant.apple.com/")!

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
                        SegmentedHTMLView(html: detail.body).padding(.horizontal)
                    }

                    if let steps = detail.stepsToReproduce, !steps.isEmpty {
                        sectionHeading("Steps to Reproduce")
                        SegmentedHTMLView(html: steps).padding(.horizontal)
                    }

                    if let workaround = detail.workaround, !workaround.isEmpty {
                        sectionHeading("Workaround")
                        SegmentedHTMLView(html: workaround).padding(.horizontal)
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
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if auth.isSignedIn {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(String(localized: "Add comment"))
                }
                Link(destination: Self.feedbackAssistantURL) {
                    Image(systemName: "flag")
                }
                .accessibilityLabel(String(localized: "Report to Apple"))
                .accessibilityHint(String(localized: "Opens Feedback Assistant to file this with Apple directly."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(id: detail.id, kind: .bugReport, title: detail.title, lastActivityAt: detail.changedAt, url: detail.url)
        }
        .sheet(isPresented: $showCompose) {
            ComposeBugCommentView(platform: detail.platform, bugId: detail.id, title: detail.title) { comment in
                self.detail?.comments.append(comment)
            }
        }
        .sheet(item: $quotedComment) { target in
            ComposeBugCommentView(platform: detail.platform, bugId: detail.id, title: detail.title, quotedComment: target) { comment in
                self.detail?.comments.append(comment)
            }
        }
    }

    /// Matches the old app's tappable "Apple Feedback ID" row — the field
    /// was already fetched (`field_apple_feedback_`) but never displayed or
    /// used anywhere.
    private func feedbackIdRow(_ feedbackId: String) -> some View {
        Link(destination: Self.feedbackAssistantURL) {
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
        VStack(alignment: .leading, spacing: 12) {
            bugSummaryRow(detail)
            if detail.comments.count >= 5 {
                Divider()
                discussionSummaryRow(detail)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedBackground(Color.accentColor, opacity: 0.08, cornerRadius: 10)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func bugSummaryRow(_ detail: BugReportDetail) -> some View {
        if let bugSummary {
            VStack(alignment: .leading, spacing: 4) {
                Label("Bug Report Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.accentColor)
                Text(bugSummary).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizeBug(detail) }
            } label: {
                if isSummarizingBug {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Summarize Bug Report", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizingBug)
            .accessibilityLabel(String(localized: isSummarizingBug ? "Summarizing bug report, please wait" : "Summarize Bug Report"))
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

    private func summarizeBug(_ detail: BugReportDetail) async {
        isSummarizingBug = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing bug report. This may take a moment.")
        var parts = ["Bug report: \(detail.title)", detail.body.strippingHTMLTags().prefix(1500).description]
        if let steps = detail.stepsToReproduce, !steps.isEmpty {
            parts.append("Steps to reproduce: \(steps.strippingHTMLTags().prefix(800))")
        }
        if let workaround = detail.workaround, !workaround.isEmpty {
            parts.append("Workaround: \(workaround.strippingHTMLTags().prefix(500))")
        }
        let input = parts.joined(separator: "\n\n")
        if let summary = await IntelligenceService.summarize(input) {
            bugSummary = summary
        } else {
            toast.error(String(localized: "Couldn't generate a summary for this bug report. Try again."))
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate a summary for this bug report.")
        }
        isSummarizingBug = false
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
            Text(label + ":")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    /// Matches BugReportEndpoints' private `commentBundle(for:)` — Edit/
    /// Delete need this comment-type string to hit the right Drupal bundle.
    private func bugCommentType(_ platform: BugPlatform) -> String {
        platform == .ios ? "comment_node_ios_bug_report" : "comment_node_os_x_bug_report"
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.headline)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func commentsSection(_ detail: BugReportDetail, proxy: ScrollViewProxy) -> some View {
        CommunityDiscussionHeading(
            count: detail.commentCount,
            onThreadOverview: { announceThreadOverview(detail) },
            onJumpToLast: { Task { await jumpToLastComment(proxy: proxy) } }
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
                    subject: comment.subject, parentTitle: detail.title,
                    commentId: comment.id, authorId: comment.authorId, commentType: bugCommentType(detail.platform),
                    onDelete: {
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
                    ProgressView().frame(maxWidth: .infinity).padding()
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

    /// VoiceOver "Thread overview" custom action on the comments heading —
    /// a spoken summary in place of manually reading through every comment.
    /// No "Original post by" line: BugReportDetail doesn't expose a
    /// submitter name (unlike forum topics, blog posts, and resources).
    private func announceThreadOverview(_ detail: BugReportDetail) {
        let mostRecent = detail.comments.max { $0.createdAt < $1.createdAt }
        var summary = "Thread has \(detail.comments.count) comment\(detail.comments.count == 1 ? "" : "s")."
        if let mostRecent {
            summary += " Most recent comment by \(mostRecent.authorName), \(mostRecent.createdAt.formatted(.relative(presentation: .named)))."
        }
        UIAccessibility.post(notification: .announcement, argument: summary)
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
                Task { await loadMoreComments() }
            }
            if let detail {
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
        focusTitleAfterLoad()
    }

    /// VoiceOver lands on the back button after push navigation by default;
    /// this moves it to the page heading instead, per
    /// docs/IMPLEMENTATION_NOTES.md's "VoiceOver Detail Page Navigation"
    /// guidance. Delayed slightly since setting focus before the new content
    /// has actually laid out is a common way for it to silently fail.
    private func focusTitleAfterLoad() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isTitleFocused = true
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

    /// "Jump to Last Comment" link on the Community Discussion heading —
    /// loads any not-yet-fetched comments first so it always lands on the
    /// true last one, then moves VoiceOver focus there.
    private func jumpToLastComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await loadMoreComments() }
        guard let lastId = self.detail?.comments.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = lastId
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

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
                Text(quotedComment != nil ? "Replying to \(quotedComment!.authorName) — Re: \(title)" : "Re: \(title)")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
                TextEditor(text: $commentText).padding()
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
        isSubmitting = true; submitError = nil
        do {
            let comment = try await APIClient.shared.bugReports.submitComment(
                platform: platform, bugId: bugId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Comment posted"))
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
