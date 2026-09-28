import SwiftUI

/// Opens an item's page at one specific comment ("Open in Thread").
struct FetchThreadTarget: Hashable {
    let kind: ContentKind
    let contentId: String
    let platform: AppPlatform?
    let commentId: String?
}

extension FeedItem {
    /// Where Fetch's heading row goes: the item's own page.
    var fetchTarget: FetchThreadTarget {
        let platform: AppPlatform? = if case .appListing(let app) = self { app.platform } else { nil }
        return FetchThreadTarget(kind: kind, contentId: contentId, platform: platform, commentId: nil)
    }
}

/// Home > Fetch: Goldie fetches everything new, grouped by item. Each item
/// is a heading (so the Headings rotor jumps item to item), then its
/// preview — or, for an older post with new comments, who posted it and
/// when — then every new comment in full, one element each, oldest first.
/// Swipe straight through without opening anything; double-tap any row to
/// open it. Same items and "new since your last visit" rules as New.
/// Requested directly (2026-09-25).
struct FetchHomeContent: View {
    @ObservedObject var vm: HomeViewModel
    @ObservedObject private var listener = FetchListener.shared
    @ObservedObject private var store = FetchStore.shared
    @AppStorage("fetch.markReadAtEnd") private var markReadAtEnd = false

    private var groups: [FetchListener.Group] {
        vm.newItems.map { FetchListener.Group(item: $0, newCount: vm.newReplyCount(for: $0), isBrandNew: vm.isBrandNew($0)) }
    }

    var body: some View {
        header
            .listRowSeparator(.hidden)
            .modifier(FetchMagicTap(groups: groups))

        if vm.newItems.isEmpty {
            caughtUp
                .listRowSeparator(.hidden)
        } else {
            ForEach(groups, id: \.item.id) { group in
                FetchGroupRows(group: group, isFinished: store.finishedIds.contains(group.item.id), isBeingRead: listener.currentItemId == group.item.id) {
                    if markReadAtEnd { store.finishedIds.insert(group.item.id) }
                } onMarkRead: {
                    vm.markAsRead(group.item)
                }
                .modifier(FetchMagicTap(groups: groups))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                GoldieView(size: 76, holdingNewspaper: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fetch")
                        .font(.title3.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Goldie fetches everything new, with each post and its new comments together. Swipe through to read it all.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            listenControls

            Toggle("Mark as Read When Finished", isOn: $markReadAtEnd)
                .font(.subheadline)
                .accessibilityHint(String(localized: "Marks each item as read once you've gone past its last comment, when you leave Fetch."))

            if !vm.newItems.isEmpty {
                Button("Mark All as Read") {
                    listener.stop()
                    store.finishedIds = []
                    vm.markAllAsRead(vm.newItems)
                }
                .font(.subheadline)
                .accessibilityHint(String(localized: "Clears everything from Fetch and New."))
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            listener.onGroupFinished = { item in
                if UserDefaults.standard.bool(forKey: "fetch.markReadAtEnd") {
                    FetchStore.shared.finishedIds.insert(item.id)
                }
            }
        }
    }

    @ViewBuilder
    private var listenControls: some View {
        switch listener.status {
        case .idle:
            Button {
                listener.start(groups)
            } label: {
                Label("Listen to Fetch", systemImage: "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.newItems.isEmpty)
            .accessibilityHint(String(localized: "Reads everything new aloud. With VoiceOver, a two-finger double tap also plays and pauses."))
        case .playing, .paused:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button {
                        listener.previousGroup()
                    } label: {
                        Label("Previous Item", systemImage: "backward.end.fill")
                    }
                    Button {
                        listener.status == .playing ? listener.pause() : listener.resume()
                    } label: {
                        Label(listener.status == .playing ? "Pause" : "Resume",
                              systemImage: listener.status == .playing ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        listener.nextComment()
                    } label: {
                        Label("Skip", systemImage: "forward.fill")
                    }
                    Button {
                        listener.nextGroup()
                    } label: {
                        Label("Next Item", systemImage: "forward.end.fill")
                    }
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    listener.stop()
                } label: {
                    Label("Stop Listening", systemImage: "stop.fill")
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: All caught up

    private var caughtUp: some View {
        VStack(spacing: 10) {
            GoldieView(size: 110, happyEyes: true)
            Text("All caught up!")
                .font(.headline)
            Text("Goldie has fetched everything new. Check back later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

}

/// Magic Tap (two-finger double tap) plays and pauses Listen to Fetch from
/// any row in Fetch.
private struct FetchMagicTap: ViewModifier {
    let groups: [FetchListener.Group]

    func body(content: Content) -> some View {
        content.accessibilityAction(.magicTap) {
            FetchListener.shared.toggle(groups)
        }
    }
}

// MARK: - One group

/// Opens a Fetch target: an item's page, or its page at one comment.
struct FetchDestination: View {
    let target: FetchThreadTarget

    var body: some View {
        switch target.kind {
        case .forumTopic:     ForumTopicDetailView(topicId: target.contentId, targetCommentId: target.commentId)
        case .blogPost:       BlogDetailView(postId: target.contentId, targetCommentId: target.commentId)
        case .resource:       ResourceDetailView(resourceId: target.contentId, targetCommentId: target.commentId)
        case .podcastEpisode: EpisodeDetailView(episodeId: target.contentId, targetCommentId: target.commentId)
        case .appListing:     AppDetailView(appId: target.contentId, platform: target.platform, targetCommentId: target.commentId)
        case .bugReport:      BugDetailView(bugId: target.contentId, targetCommentId: target.commentId)
        }
    }
}

extension FeedItem {
    /// The item's web address, for Share and Open in Browser.
    var fetchURL: String {
        switch self {
        case .forumTopic(let t):     return t.url
        case .podcastEpisode(let e): return e.url
        case .appListing(let a):     return a.url
        case .resource(let r):       return r.url
        case .blogPost(let b):       return b.url
        }
    }
}

private struct FetchGroupRows: View {
    let group: FetchListener.Group
    let isFinished: Bool
    let isBeingRead: Bool
    let onReachedEnd: () -> Void
    let onMarkRead: () -> Void

    @ObservedObject private var store = FetchStore.shared
    @State private var showsOriginal = false
    @State private var replyingTo: FetchComment?
    /// The row VoiceOver returns to after coming back from the page it
    /// opened: "heading", "preview", or a comment's id.
    @AccessibilityFocusState private var focusedRow: String?

    private var item: FeedItem { group.item }
    /// A brand-new item's comments are all new to you.
    private var commentCount: Int { group.isBrandNew ? item.commentCount : group.newCount }

    var body: some View {
        headingRow
            .task { await store.load(item, newCount: commentCount) }
            .sheet(item: $replyingTo) { comment in
                replySheet(for: comment)
            }

        switch store.state(for: item, newCount: commentCount) {
        case .loaded(let content)?:
            if group.isBrandNew {
                previewRow(content)
            } else {
                originalPostRow(content)
                if showsOriginal { previewRow(content) }
            }
            ForEach(Array(content.comments.enumerated()), id: \.element.id) { index, comment in
                commentRow(comment)
                    .onAppear { if index == content.comments.count - 1 { onReachedEnd() } }
            }
            if content.comments.isEmpty {
                Color.clear.frame(height: 0).listRowSeparator(.hidden)
                    .onAppear(perform: onReachedEnd)
            }
        case .failed?:
            HStack {
                Text("Couldn't load this item.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Try Again") { Task { await store.retry(item, newCount: commentCount) } }
            }
            .font(.subheadline)
            .padding(.leading, 20)
        case .loading?, nil:
            HStack(spacing: 8) {
                ProgressView()
                Text(commentCount > 0
                     ? String(localized: "Loading \(String(localized: "\(commentCount) new comments"))…")
                     : String(localized: "Loading…"))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.leading, 20)
            .accessibilityElement(children: .combine)
        }
    }

    /// Opens `target`, and brings VoiceOver back to `rowId` on the way back.
    private func link<Label: View>(_ target: FetchThreadTarget, rowId: String, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            FetchDestination(target: target)
                .onDisappear {
                    Task { await retryAccessibilityFocus(into: $focusedRow, returningTo: rowId) }
                }
        } label: {
            label()
        }
        .accessibilityFocused($focusedRow, equals: rowId)
    }

    // MARK: Rows

    private var headingRow: some View {
        link(item.fetchTarget, rowId: "heading") {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.kind.accentColor)
                    if isBeingRead {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    if isFinished {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(group.isBrandNew
                     ? String(localized: "New")
                     : String(localized: "\(group.newCount) new comments"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 10)
        .overlay(alignment: .leading) {
            Rectangle().fill(item.kind.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
                .offset(x: -10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(FetchText.heading(item, newCount: group.newCount, isBrandNew: group.isBrandNew))
        .accessibilityAddTraits(.isHeader)
        .accessibilityAction(named: Text("Mark as Read"), onMarkRead)
        // The same actions every item has elsewhere in the app: Save,
        // Follow, Share, Open in Browser, Recommend on apps, Add to Queue on
        // episodes — as swipe actions, the touch-and-hold menu, and the
        // VoiceOver Actions rotor.
        // Admins also get Edit, Unpublish, and Delete here, and authors Edit
        // and Delete on their own topics (`authorId`). A deleted or
        // unpublished item leaves Fetch.
        .contentActions(
            id: item.contentId, entityId: item.nid ?? 0, kind: item.kind, title: item.title,
            lastActivityAt: item.lastActivityAt, url: item.fetchURL, currentCommentCount: item.commentCount,
            authorId: loadedContent?.authorId, onContentDeleted: onMarkRead
        )
    }

    private var loadedContent: FetchContent? {
        if case .loaded(let content)? = store.state(for: item, newCount: commentCount) { return content }
        return nil
    }

    private func previewRow(_ content: FetchContent) -> some View {
        link(item.fetchTarget, rowId: "preview") {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.preview)
                    .font(.body)
                    .foregroundStyle(.primary)
                if content.previewIsExcerpt {
                    Text("Continues. Double-tap to read the rest.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 20)
        .accessibilityElement(children: .combine)
    }

    private func originalPostRow(_ content: FetchContent) -> some View {
        Text(FetchText.originalPostLine(content))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.leading, 20)
            .accessibilityAction(named: Text(showsOriginal ? "Hide Original Post" : "Read Original Post")) {
                showsOriginal.toggle()
            }
            .contextMenu {
                Button(showsOriginal ? "Hide Original Post" : "Read Original Post") { showsOriginal.toggle() }
            }
    }

    private func commentRow(_ comment: FetchComment) -> some View {
        let target = FetchThreadTarget(kind: item.kind, contentId: item.contentId, platform: item.fetchTarget.platform, commentId: comment.id)
        return link(target, rowId: comment.id) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FetchText.commentHeader(comment))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let replyingTo = comment.replyingTo {
                    Text(String(localized: "Replying to \(replyingTo)."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(comment.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                if comment.isTruncated {
                    Text("Continues. Double-tap to read the rest.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 20)
        // A thin line joining the comments to their item, for sighted users.
        .overlay(alignment: .leading) {
            Rectangle().fill(item.kind.accentColor.opacity(0.35)).frame(width: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Double-tap to open this comment in its thread."))
        // Reply (quoting this comment, without leaving Fetch), Copy, Share,
        // Report, and Edit / Unpublish / Delete where allowed.
        .modifier(FetchCommentActions(
            comment: comment, item: item,
            onReply: { replyingTo = comment },
            onRemoved: { store.removeComment(comment.id, item: item, newCount: commentCount) },
            onEdited: { store.updateComment(comment.id, newText: $0, item: item, newCount: commentCount) }
        ))
    }

    /// Each kind's own compose screen, with the comment quoted — the same
    /// one its detail page uses for Reply.
    @ViewBuilder
    private func replySheet(for comment: FetchComment) -> some View {
        switch comment.source {
        case .forum(let reply):
            ComposeReplyView(topicId: item.contentId, topicTitle: item.title, quotedReply: reply) { _ in }
        case .blog(let quoted):
            ComposeBlogCommentView(blogId: item.contentId, title: item.title, quotedComment: quoted) { _ in }
        case .resource(let quoted):
            ComposeResourceCommentView(resourceId: item.contentId, title: item.title, quotedComment: quoted) { _ in }
        case .podcast(let quoted):
            ComposePodcastCommentView(episodeId: item.contentId, title: item.title, quotedComment: quoted) { _ in }
        case .app(let quoted):
            ComposeAppReviewView(appId: item.contentId, appName: item.title, quotedReview: quoted,
                                 platform: item.fetchTarget.platform ?? .ios) { _ in }
        }
    }
}

/// Everything a comment offers on its own detail page, on Fetch's comment
/// rows too: Reply, Copy, Share, Report, and — for its author or an admin —
/// Edit and Delete, plus Unpublish for admins. Same wording and behavior as
/// `CommentRow`, so the two never disagree. Requested directly.
private struct FetchCommentActions: ViewModifier {
    let comment: FetchComment
    let item: FeedItem
    let onReply: () -> Void
    let onRemoved: () -> Void
    let onEdited: (String) -> Void

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showUnpublishConfirm = false
    @State private var showEditSheet = false
    @State private var showReportSheet = false

    private var commentType: String { item.commentBundle.rawValue }
    private var isAdmin: Bool { auth.user?.isAdmin ?? false }
    private var canEdit: Bool {
        guard let user = auth.user else { return false }
        let authorId = comment.source.authorId
        return !authorId.isEmpty && (user.isAdmin || user.uuid == authorId)
    }

    func body(content: Content) -> some View {
        content
            .modifier(ConditionalAccessibilityAction(isActive: auth.isSignedIn, name: "Reply to this Comment") { onReply() })
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { share() }
            .accessibilityAction(named: Text("Report Comment")) { showReportSheet = true }
            .modifier(ConditionalAccessibilityAction(isActive: canEdit, name: "Edit Comment") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: isAdmin, name: "Unpublish Comment") { showUnpublishConfirm = true })
            .modifier(ConditionalAccessibilityAction(isActive: canEdit, name: "Delete Comment") { showDeleteConfirm = true })
            .voiceOverAwareSwipeActions {
                if auth.isSignedIn {
                    Button(action: onReply) {
                        Label("Reply to this Comment", systemImage: "arrowshape.turn.up.left")
                    }
                    .tint(.blue)
                }
            }
            .contextMenu {
                if auth.isSignedIn {
                    Button(action: onReply) {
                        Label("Reply to this Comment", systemImage: "arrowshape.turn.up.left")
                    }
                }
                Button(action: copyText) {
                    Label("Copy Comment Text", systemImage: "doc.on.doc")
                }
                Button(action: share) {
                    Label("Share Comment", systemImage: "square.and.arrow.up")
                }
                Button { showReportSheet = true } label: {
                    Label("Report Comment", systemImage: "flag")
                }
                if canEdit {
                    Button { showEditSheet = true } label: {
                        Label("Edit Comment", systemImage: "pencil")
                    }
                }
                if isAdmin {
                    Button { showUnpublishConfirm = true } label: {
                        Label("Unpublish Comment", systemImage: "eye.slash")
                    }
                }
                if canEdit {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Comment", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportCommentWizard(context: ReportCommentContext(
                    authorName: comment.author,
                    commentExcerpt: .excerpt(from: comment.text),
                    commentDate: comment.date,
                    contentTitle: item.title,
                    contentURL: item.fetchURL
                ))
            }
            .confirmationDialog("Unpublish this comment?", isPresented: $showUnpublishConfirm, titleVisibility: .visible) {
                Button("Unpublish", role: .destructive) { Task { await unpublish() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This hides it from public view.")
            }
            .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showEditSheet) {
                EditContentSheet(title: String(localized: "Edit Comment"), initialText: comment.source.rawBody) { newText in
                    guard let user = auth.user else { return }
                    try await APIClient.shared.content.editComment(
                        commentType: commentType, commentId: comment.id, newBody: newText,
                        format: comment.source.bodyFormat, csrfToken: user.csrfToken
                    )
                    onEdited(newText)
                    toast.success(String(localized: "Comment updated"))
                }
            }
    }

    private func copyText() {
        UIPasteboard.general.string = comment.text
        toast.success(String(localized: "Comment text copied"))
    }

    private func share() {
        let message = String(localized: "\(comment.author) on AppleVis:\n\n\(comment.text)")
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }

    private func delete() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteComment(commentType: commentType, commentId: comment.id, csrfToken: user.csrfToken)
            onRemoved()
            toast.success(String(localized: "Comment deleted"))
        } catch {
            toast.error(String(localized: "Couldn't delete comment."))
        }
    }

    private func unpublish() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.unpublishComment(commentType: commentType, commentId: comment.id, csrfToken: user.csrfToken)
            onRemoved()
            toast.success(String(localized: "Comment unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish comment."))
        }
    }
}
