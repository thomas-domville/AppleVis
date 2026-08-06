import SwiftUI

struct BugDetailView: View {
    let bugId: String
    @State private var detail: BugReportDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var toast: ToastStore

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

                    Divider()

                    // Description
                    if !detail.body.isEmpty {
                        sectionHeading("Description")
                        HTMLTextView(html: detail.body).padding(.horizontal)
                    }

                    if let steps = detail.stepsToReproduce, !steps.isEmpty {
                        sectionHeading("Steps to Reproduce")
                        HTMLTextView(html: steps).padding(.horizontal)
                    }

                    if let workaround = detail.workaround, !workaround.isEmpty {
                        sectionHeading("Workaround")
                        HTMLTextView(html: workaround).padding(.horizontal)
                    }

                    Divider()

                    // Comments
                    commentsSection(detail, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
                .padding(.vertical)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(id: detail.id, kind: .bugReport, title: detail.title, lastActivityAt: detail.changedAt, url: detail.url)
        }
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
        .background(
            (detail.status == .active ? Color.orange : Color.green).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(detail.status.displayName) bug on \(detail.platform.displayName). " +
            "\(detail.severity.displayName) severity."
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
            Text(label + ":")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
        }
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
                    commentId: comment.id,
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
            toast.error("Couldn't load more comments.")
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
        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = lastId
    }
}
