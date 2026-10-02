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
    @AppStorage(ListenSpeed.storageKey) private var listenSpeed: ListenSpeed = .mySettings
    /// One focus for all of Fetch: a heading ("heading.<id>"), a preview
    /// ("preview.<id>"), a comment (its id), the header, or All Caught Up.
    /// Shared so marking something read can move VoiceOver on to what's
    /// next, even in another item.
    @AccessibilityFocusState private var focus: String?

    /// Only items with something to read: new, or with new comments.
    /// Activity with no new comment (an edit, say) used to show as "0 new
    /// comments" with nothing under it. Reported directly (2026-10-02).
    private var groups: [FetchListener.Group] {
        vm.newItems
            .map { FetchListener.Group(item: $0, newCount: vm.newReplyCount(for: $0), isBrandNew: vm.isBrandNew($0)) }
            .filter { $0.isBrandNew || $0.newCount > 0 }
    }

    var body: some View {
        header
            .id(FetchHeadingsRotor.headerID)
            .listRowSeparator(.hidden)
            .modifier(FetchMagicTap(groups: groups))
            .modifier(FetchHeadingsRotor(groups: groups))

        if groups.isEmpty {
            caughtUp
                .listRowSeparator(.hidden)
        } else {
            ForEach(groups, id: \.item.id) { group in
                FetchGroupRows(
                    group: group,
                    isFinished: store.finishedIds.contains(group.item.id),
                    isBeingRead: listener.currentItemId == group.item.id,
                    onReachedEnd: { if markReadAtEnd { store.finishedIds.insert(group.item.id) } },
                    onMarkRead: { markRead(group) },
                    focus: $focus,
                    onMarkReadThrough: { comment, content in markRead(group, through: comment, in: content) }
                )
                .modifier(FetchMagicTap(groups: groups))
                .modifier(FetchHeadingsRotor(groups: groups))
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
                .accessibilityFocused($focus, equals: FetchHeadingsRotor.headerID)
            }

            listenControls
            speedPicker

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
            .disabled(groups.isEmpty)
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

    /// How fast Listen to Fetch reads; swipe up or down with VoiceOver. A
    /// change mid-read starts the current sentence again at the new speed.
    /// Requested directly (2026-09-30).
    private var speedPicker: some View {
        Picker("Listening Speed", selection: $listenSpeed) {
            ForEach(ListenSpeed.allCases) { speed in
                Text(speed.name).tag(speed)
            }
        }
        .pickerStyle(.menu)
        .font(.subheadline)
        .accessibilityValue(Text(listenSpeed.name))
        .accessibilityHint(String(localized: "My Settings uses the voice and speed you chose for VoiceOver or Spoken Content. Swipe up or down to change it."))
        .accessibilityAdjustableAction { direction in
            let all = ListenSpeed.allCases
            guard let idx = all.firstIndex(of: listenSpeed) else { return }
            switch direction {
            case .increment: if idx + 1 < all.count { listenSpeed = all[idx + 1] }
            case .decrement: if idx > 0 { listenSpeed = all[idx - 1] }
            @unknown default: break
            }
        }
        .onChange(of: listenSpeed) { _, _ in listener.speedChanged() }
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
        .accessibilityFocused($focus, equals: Self.caughtUpID)
    }

    // MARK: Marking read

    private static let caughtUpID = "fetch.caughtUp"

    /// The whole item: it leaves Fetch, and VoiceOver moves to the next
    /// item's heading (or the one before, or All Caught Up), instead of
    /// losing its place when the item disappears. Requested directly.
    private func markRead(_ group: FetchListener.Group) {
        let target = focusTarget(replacing: group.item)
        store.finishedIds.remove(group.item.id)
        // Through the last comment Fetch loaded, which can be past Home's
        // count when more arrived since Home refreshed.
        let shownCount = group.isBrandNew ? group.item.commentCount : group.newCount
        if case .loaded(let content)? = store.state(for: group.item, newCount: shownCount) {
            vm.markAsRead(group.item, through: content.throughCount)
        } else {
            vm.markAsRead(group.item)
        }
        // Said before the move, so the jump to the next heading has a
        // reason. Requested directly (2026-10-01).
        moveFocus(to: target, announcing: String(localized: "Group marked as read."))
    }

    /// "Mark Read Up to Here": this comment and the ones before it are
    /// read; newer ones stay, and VoiceOver moves to the first of them.
    /// On the last comment, the whole item is read. Kept on this device,
    /// like all read status. Requested directly.
    private func markRead(_ group: FetchListener.Group, through comment: FetchComment, in content: FetchContent) {
        guard let index = content.comments.firstIndex(where: { $0.id == comment.id }) else { return }
        let remaining = content.comments.count - index - 1
        guard remaining > 0 else { markRead(group); return }
        let shownCount = group.isBrandNew ? group.item.commentCount : group.newCount
        // Counted from the comments Fetch loaded, not Home's total: on a
        // busy topic Home's total can be behind, which marked too few as
        // read, so ones already read came back. Reported directly
        // (2026-10-02).
        let seen = content.seenBefore + index + 1
        store.keepAfter(index, of: group.item, from: shownCount, newCount: max(0, group.item.commentCount - seen))
        vm.markRead(group.item, seenCount: seen)
        moveFocus(to: content.comments[index + 1].id,
                  announcing: String(localized: "Marked as read. \(String(localized: "\(remaining) new comments")) left."))
    }

    private func focusTarget(replacing item: FeedItem) -> String {
        let ids = groups.map(\.item.id)
        guard let index = ids.firstIndex(of: item.id) else { return Self.caughtUpID }
        if index + 1 < ids.count { return "heading.\(ids[index + 1])" }
        if index > 0 { return "heading.\(ids[index - 1])" }
        return Self.caughtUpID
    }

    /// After marking something read, puts VoiceOver on what's next. Every
    /// Fetch row shares `focus`, so when the marked rows vanish, VoiceOver
    /// lands on whichever row slides into their place and that row claims
    /// `focus`. The shared helper took that as "the user moved on" and gave
    /// up, leaving focus in the middle of nowhere, mostly further down the
    /// list. This keeps asking for the target for about a second, the only
    /// time a move here is wanted. Reported directly (2026-10-01).
    ///
    /// With `announcing`, the message is spoken first: just after the rows
    /// vanish (so VoiceOver reading wherever it fell doesn't cut it off),
    /// and the move waits until it's been said.
    private func moveFocus(to target: String, announcing message: String? = nil) {
        focus = nil
        Task {
            guard UIAccessibility.isVoiceOverRunning else { return }
            var delays = [350, 650, 1000]
            if let message {
                try? await Task.sleep(for: .milliseconds(250))
                UIAccessibility.post(notification: .announcement, argument: message)
                delays = [message.count > 30 ? 2000 : 1300, 500, 700]
            }
            for delayMs in delays {
                try? await Task.sleep(for: .milliseconds(delayMs))
                focus = nil
                focus = target
            }
        }
    }
}

/// VoiceOver's Headings rotor only finds headings that have been built, and
/// Home's list only builds rows near the screen, so an item further down
/// Fetch couldn't be reached by heading until you'd swiped close to it.
/// While VoiceOver is anywhere in Fetch, this Headings rotor lists every
/// item, on screen or not, and moves straight to it. Home's other views
/// keep the usual Headings rotor. Reported directly (2026-09-28).
private struct FetchHeadingsRotor: ViewModifier {
    let groups: [FetchListener.Group]
    static let headerID = "fetch.header"

    static func headingID(_ item: FeedItem) -> String { "fetch.heading.\(item.id)" }

    func body(content: Content) -> some View {
        content.accessibilityRotor(.headings) {
            AccessibilityRotorEntry(String(localized: "Fetch"), id: Self.headerID)
            ForEach(groups, id: \.item.id) { group in
                AccessibilityRotorEntry(
                    FetchText.heading(group.item, newCount: group.newCount, isBrandNew: group.isBrandNew),
                    id: Self.headingID(group.item)
                )
            }
        }
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
    /// Fetch's shared focus. Also the row VoiceOver returns to after coming
    /// back from the page it opened.
    let focus: AccessibilityFocusState<String?>.Binding
    let onMarkReadThrough: (FetchComment, FetchContent) -> Void

    @ObservedObject private var store = FetchStore.shared
    @State private var showsOriginal = false
    @State private var replyingTo: FetchComment?

    private var item: FeedItem { group.item }
    /// A brand-new item's comments are all new to you.
    private var commentCount: Int { group.isBrandNew ? item.commentCount : group.newCount }

    var body: some View {
        headingRow
            .id(FetchHeadingsRotor.headingID(item))
            .task { await store.load(item, newCount: commentCount) }
            .sheet(item: $replyingTo) { comment in
                replySheet(for: comment)
            }

        switch store.state(for: item, newCount: commentCount) {
        case .loaded(let content)?:
            // With no new comments, the post is the end of the item. This
            // used to be an empty, invisible row, which VoiceOver stopped
            // on with a click. Reported directly (2026-09-30).
            if group.isBrandNew {
                previewRows(content, isEnd: content.comments.isEmpty)
            } else {
                originalPostRow(content)
                    .onAppear { if content.comments.isEmpty { onReachedEnd() } }
                if showsOriginal { previewRows(content, isEnd: false) }
            }
            ForEach(Array(content.comments.enumerated()), id: \.element.id) { index, comment in
                commentRows(comment, isEnd: index == content.comments.count - 1)
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
                    Task { await retryAccessibilityFocus(into: focus, returningTo: rowId) }
                }
        } label: {
            label()
        }
    }

    // MARK: Rows

    private var headingRow: some View {
        link(item.fetchTarget, rowId: "heading.\(item.id)") {
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
        // On the combined element, not inside it, so VoiceOver can land on
        // it. Fixed 2026-10-01.
        .accessibilityFocused(focus, equals: "heading.\(item.id)")
        .accessibilityLabel(FetchText.heading(item, newCount: group.newCount, isBrandNew: group.isBrandNew))
        .accessibilityAddTraits(.isHeader)
        // "Mark This Group as Read": plain Mark as Read didn't say it clears
        // the post and all its comments. Requested directly (2026-10-01).
        .accessibilityAction(named: Text("Mark This Group as Read"), onMarkRead)
        // The same actions every item has elsewhere in the app: Save,
        // Follow, Share, Open in Browser, Recommend on apps, Add to Queue on
        // episodes — as swipe actions, the touch-and-hold menu, and the
        // VoiceOver Actions rotor.
        // Admins also get Edit, Unpublish, and Delete here, and authors Edit
        // and Delete on their own topics (`authorId`). A deleted or
        // unpublished item leaves Fetch.
        .contentActions(
            id: item.contentId, entityId: item.nid ?? 0, kind: item.kind, title: item.title,
            lastActivityAt: item.lastActivityAt, url: item.fetchURL,
            authorId: loadedContent?.authorId, onContentDeleted: onMarkRead
        ) {
            Button(action: onMarkRead) {
                Label("Mark This Group as Read", systemImage: "checkmark.circle")
            }
            .accessibilityHidden(true)
        }
    }

    private var loadedContent: FetchContent? {
        if case .loaded(let content)? = store.state(for: item, newCount: commentCount) { return content }
        return nil
    }

    /// The post, whole, as one row. Long posts and comments were briefly
    /// split into several rows; back to one each, as requested directly
    /// (2026-10-01).
    private func previewRows(_ content: FetchContent, isEnd: Bool) -> some View {
        link(item.fetchTarget, rowId: "preview.\(item.id)") {
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
        .accessibilityFocused(focus, equals: "preview.\(item.id)")
        .onAppear { if isEnd { onReachedEnd() } }
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

    /// One comment, whole, as one row.
    private func commentRows(_ comment: FetchComment, isEnd: Bool) -> some View {
        commentRow(comment, isLast: isEnd)
            .onAppear { if isEnd { onReachedEnd() } }
    }

    private func commentRow(_ comment: FetchComment, isLast: Bool) -> some View {
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
        .accessibilityFocused(focus, equals: comment.id)
        .accessibilityHint(String(localized: "Double-tap to open this comment in its thread."))
        // Reply (quoting this comment, without leaving Fetch), Copy, Share,
        // Report, and Edit / Unpublish / Delete where allowed.
        .modifier(FetchCommentActions(
            comment: comment, item: item,
            onReply: { replyingTo = comment },
            isLastInGroup: isLast,
            onMarkReadThrough: { if let content = loadedContent { onMarkReadThrough(comment, content) } },
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
    /// On the group's last comment, where marking it read clears the
    /// whole group.
    var isLastInGroup = false
    /// "Mark Read Up to Here": this comment and the ones before it.
    let onMarkReadThrough: () -> Void

    /// On the last comment, Mark Read Up to Here clears the whole group,
    /// so it's named for that, the same as on the heading. Requested
    /// directly (2026-10-01).
    private var markReadName: LocalizedStringKey {
        isLastInGroup ? "Mark This Group as Read" : "Mark Read Up to Here"
    }
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
            .accessibilityAction(named: Text(markReadName)) { onMarkReadThrough() }
            .modifier(ConditionalAccessibilityAction(isActive: auth.isSignedIn, name: "Reply to this Comment") { onReply() })
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { share() }
            .accessibilityAction(named: Text("Report Comment")) { showReportSheet = true }
            .modifier(ConditionalAccessibilityAction(isActive: canEdit, name: "Edit Comment") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: isAdmin, name: "Unpublish Comment") { showUnpublishConfirm = true })
            .modifier(ConditionalAccessibilityAction(isActive: canEdit, name: "Delete Comment") { showDeleteConfirm = true })
            .voiceOverAwareSwipeActions {
                Button(action: onMarkReadThrough) {
                    Label(markReadName, systemImage: "checkmark.circle")
                }
                .tint(.green)
            } trailing: {
                if auth.isSignedIn {
                    Button(action: onReply) {
                        Label("Reply to this Comment", systemImage: "arrowshape.turn.up.left")
                    }
                    .tint(.blue)
                }
            }
            .contextMenu {
                Button(action: onMarkReadThrough) {
                    Label(markReadName, systemImage: "checkmark.circle")
                }
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
