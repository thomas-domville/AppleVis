import SwiftUI
import UIKit

struct ResourceDetailView: View {
    let resourceId: String
    @State private var detail: ResourceDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCompose = false
    @State private var isLoadingMoreComments = false
    @State private var hasMoreComments = true
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedCommentId: String?
    @EnvironmentObject private var auth: AuthStore
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
    private func content(_ detail: ResourceDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(detail.kind.displayName, systemImage: detail.kind.systemImage)
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            RelativeDateLabel(date: detail.updatedAt)
                        }
                        Text(detail.title)
                            .font(.title2).fontWeight(.semibold)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isTitleFocused)
                        Text("by \(detail.authorName)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if !detail.categories.isEmpty {
                            Text(detail.categories.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    HTMLTextView(html: detail.body)
                        .padding(.horizontal)

                    Divider()

                    // Comments
                    commentsSection(detail, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
                .padding(.vertical)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if auth.isSignedIn {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Add comment")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(id: detail.id, kind: .resource, title: detail.title, lastActivityAt: detail.updatedAt, url: detail.url)
        }
        .sheet(isPresented: $showCompose) {
            ComposeResourceCommentView(resourceId: detail.id, title: detail.title) { comment in
                self.detail?.comments.append(comment)
            }
        }
    }

    @ViewBuilder
    private func commentsSection(_ detail: ResourceDetail, proxy: ScrollViewProxy) -> some View {
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
                    commentId: comment.id, authorId: comment.authorId, commentType: "comment_node_guides",
                    onDelete: {
                        self.detail?.comments.removeAll { $0.id == comment.id }
                    },
                    onEdit: { newText in
                        guard let idx = self.detail?.comments.firstIndex(where: { $0.id == comment.id }) else { return }
                        self.detail?.comments[idx] = ResourceComment(id: comment.id, authorName: comment.authorName, authorId: comment.authorId, body: newText, createdAt: comment.createdAt)
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
    private func announceThreadOverview(_ detail: ResourceDetail) {
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
            detail = try await APIClient.shared.resources.detail(id: resourceId)
            // Was `>= 100` (the page size requested, not what the server
            // actually returns — Drupal JSON:API commonly clamps a
            // requested page[limit] down to a lower site-configured max).
            // Comparing against the guide's own known commentCount is
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
                SpotlightIndexer.index(Resource(
                    id: detail.id, title: detail.title, kind: detail.kind, authorName: detail.authorName,
                    authorId: detail.authorId, categories: detail.categories, summary: detail.body,
                    createdAt: detail.createdAt, updatedAt: detail.updatedAt,
                    commentCount: detail.commentCount, url: detail.url, isSaved: false
                ))
            }
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load guide." }
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
    /// page — the server clamps each request to its own max page size, so a
    /// guide with many comments could otherwise take several manual
    /// "Load More" taps to fully unroll.
    private func loadMoreComments() async {
        isLoadingMoreComments = true
        do {
            while let current = self.detail, current.comments.count < current.commentCount {
                let more = try await APIClient.shared.resources.moreComments(resourceId: current.id, offset: current.comments.count)
                guard !more.isEmpty else { break }
                self.detail?.comments.append(contentsOf: more)
            }
        } catch {
            toast.error("Couldn't load more comments.")
        }
        hasMoreComments = (self.detail?.comments.count ?? 0) < (self.detail?.commentCount ?? 0)
        isLoadingMoreComments = false
    }

    /// "Jump to Last Comment" custom action on the Community Discussion
    /// heading — loads any not-yet-fetched comments first so it always
    /// lands on the true last one, then moves VoiceOver focus there (a
    /// scroll alone doesn't relocate the VoiceOver cursor).
    private func jumpToLastComment(proxy: ScrollViewProxy) async {
        if hasMoreComments { await loadMoreComments() }
        guard let lastId = self.detail?.comments.last?.id else { return }
        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedCommentId = lastId
    }
}

// MARK: - Generic comment row (shared across resource/blog/podcast)

struct CommentRow: View {
    let authorName: String
    let text: String
    let date: Date
    var index: Int = 0
    var total: Int = 1
    var commentId: String? = nil
    var authorId: String? = nil
    var commentType: String? = nil
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    /// Set by the parent when it supports "Jump to Last Comment" — lets
    /// that action move VoiceOver focus here, not just scroll the viewport.
    var focusBinding: AccessibilityFocusState<String?>.Binding? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private var canDelete: Bool {
        guard let user = auth.user, let authorId, commentId != nil, commentType != nil else { return false }
        return !authorId.isEmpty && (user.isAdmin || user.uuid == authorId)
    }

    private var headerAccessibilityLabel: String {
        "Comment \(index + 1) of \(total). \(authorName). \(date.formatted(.relative(presentation: .named)))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(authorName).fontWeight(.medium)
                Spacer()
                RelativeDateLabel(date: date)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(headerAccessibilityLabel)
            .accessibilityHint("Actions available: copy, share, and more.")
            .modifier(OptionalReplyFocus(binding: focusBinding, id: commentId ?? "\(authorName)-\(date.timeIntervalSince1970)"))
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { presentShareSheet() }
            .accessibilityAction(named: Text("Mark as Helpful")) {
                toast.warning("Helpful votes are coming once the Drupal Flags API is confirmed.")
            }
            .accessibilityAction(named: Text("Report Comment")) {
                toast.warning("Reporting is coming once the Drupal Flags API is confirmed.")
            }
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Edit Comment") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Delete Comment") { showDeleteConfirm = true })

            HTMLTextView(html: text)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contextMenu {
            if canDelete {
                Button { showEditSheet = true } label: {
                    Label("Edit Comment", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(title: "Edit Comment", initialText: text) { newText in
                guard let user = auth.user, let commentId, let commentType else { return }
                try await APIClient.shared.content.editComment(
                    commentType: commentType, commentId: commentId, newBody: newText, format: "basic_html", csrfToken: user.csrfToken
                )
                onEdit?(newText)
                toast.success("Comment updated")
            }
        }
    }

    private func copyText() {
        UIPasteboard.general.string = text.strippingHTMLTags()
        toast.success("Comment text copied.")
    }

    private func presentShareSheet() {
        let message = "\(authorName) on AppleVis:\n\n\(text.strippingHTMLTags())"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }

    private func delete() async {
        guard let user = auth.user, let commentId, let commentType else { return }
        do {
            try await APIClient.shared.content.deleteComment(commentType: commentType, commentId: commentId, csrfToken: user.csrfToken)
            onDelete?()
            toast.success("Comment deleted")
        } catch {
            toast.error("Couldn't delete comment.")
        }
    }
}

// MARK: - Compose comment

struct ComposeResourceCommentView: View {
    let resourceId: String
    let title: String
    let onPosted: (ResourceComment) -> Void

    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Re: \(title)")
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
            let comment = try await APIClient.shared.resources.submitComment(
                resourceId: resourceId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success("Comment posted")
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
