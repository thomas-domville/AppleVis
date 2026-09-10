import SwiftUI
import UIKit

/// Per-kind accent color used to color-code Saved/Following rows — matches
/// the old RN app's `KIND_ACCENT_SAVED` palette (foryou.tsx).
extension ContentKind {
    var accentColor: Color {
        switch self {
        case .forumTopic:     return Color(red: 0.388, green: 0.400, blue: 0.945) // indigo
        case .podcastEpisode: return Color(red: 0.976, green: 0.451, blue: 0.086) // orange
        case .appListing:     return Color(red: 0.231, green: 0.510, blue: 0.965) // blue
        case .resource:       return Color(red: 0.063, green: 0.725, blue: 0.506) // green
        case .blogPost:       return Color(red: 0.545, green: 0.361, blue: 0.965) // purple
        case .bugReport:      return Color(red: 0.976, green: 0.451, blue: 0.086) // orange
        }
    }
}

/// Whether Follow's UI shows up everywhere it normally would. Was briefly
/// flipped off while Follow looked like it might be shelved, then flipped
/// back on the same session once "Subscriptions" (`/user/{uid}/message-
/// subscribe`) turned out to be the exact same `subscribe_node` flag —
/// confirmed directly against that page's own unflag link, just labeled
/// "Subscribe/Unsubscribe" there instead of "Follow/Unfollow." Kept as a
/// single flag (rather than reverting the gating outright) since every call
/// site already checks it — cheap to shelve again later if ever needed.
let followFeatureEnabled = true

/// Shared save/follow/share actions (swipe + context menu) for any content row
/// or detail screen. Save is local-only (no server concept — see
/// `PersistenceStore`); follow is server-backed via the generic JSON:API
/// flagging endpoint (`APIClient.shared.flags`).
struct ContentActionsModifier: ViewModifier {
    let id: String
    let kind: ContentKind
    let title: String
    let lastActivityAt: Date?
    let url: String?
    var supportsFollow: Bool = true
    /// Fired after a save/follow toggle actually happens — lets a screen
    /// that owns its own "list of saved/followed items" (Saved, Following)
    /// prune the item locally instead of showing a stale row that still
    /// claims to be saved/followed after the user just toggled it off.
    var onSaveToggle: ((Bool) -> Void)? = nil
    var onFollowToggle: ((Bool) -> Void)? = nil
    /// Current total comment/reply/review count — lets this modifier offer
    /// "Mark as Read" itself (RN's browse-list FeedCard had this on every
    /// row with new activity, not just Home's feed row). Omit to hide the
    /// action entirely.
    var currentCommentCount: Int? = nil
    /// Real "Add Comment" handler for the content types RN wired one
    /// to directly from the list (Forums, Podcasts — opens a reply/comment
    /// composer without navigating in first). Every other kind gets RN's
    /// exact original stub behavior automatically when this is left nil.
    var onAddComment: (() -> Void)? = nil
    /// Only meaningful for `.forumTopic` — RN gave forum topic owners their
    /// own "Edit Topic"/"Delete Topic" actions, separate from (and in
    /// addition to, if the user happens to be both) admin moderation.
    var authorId: String? = nil
    /// Fired after an admin/owner delete succeeds — lets the parent list
    /// prune the row, matching the onDelete pattern comment rows already use.
    var onContentDeleted: (() -> Void)? = nil
    /// Kind-specific primary actions (Play/Add to Queue for podcasts, Open
    /// App Store for apps) shown at the top of the menu, above the generic
    /// actions every kind shares.
    var extraMenuItems: AnyView = AnyView(EmptyView())

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var isSaved = false
    @State private var isFollowing = false
    @State private var isRecommended = false
    @State private var showBrowser = false
    @State private var editingNode: EditableNode?
    @State private var showUnpublishConfirm = false
    @State private var showDeleteConfirm = false

    private var newCount: Int {
        guard let currentCommentCount else { return 0 }
        return PersistenceStore.shared.newReplyCount(kind: kind, id: id, currentCount: currentCommentCount)
    }

    /// Was previously app-specific on app listings only — but this action's
    /// actual behavior (`addComment()` below) is identical for every kind
    /// with no `onAddComment` handler wired in: a stub toast telling the
    /// user to open the item first. The label promised something app rows
    /// alone didn't actually do, and it was the only kind that read
    /// differently from the rest of the row types for the same action.
    /// Reported directly.
    private var addCommentLabel: String { "Add Comment" }

    private var isAdmin: Bool { auth.user?.isAdmin ?? false }

    /// `followFeatureEnabled` hides *starting* a new follow while it's
    /// shelved, but never hides Unfollow for something already followed —
    /// see that flag's doc comment.
    private var canOfferFollow: Bool {
        supportsFollow && auth.isSignedIn && (followFeatureEnabled || isFollowing)
    }

    /// Tied directly to `.appListing` rather than a separate opt-in flag —
    /// "Recommend This App" (confirmed live against the site's own app
    /// pages, which show a "Recommendations" count + "most recently
    /// recommended by" credit) is inherently app-only, so there's no call
    /// site that should ever need to remember to turn it on.
    private var canOfferRecommend: Bool {
        kind == .appListing && auth.isSignedIn
    }

    private var isOwnTopic: Bool {
        guard kind == .forumTopic, let authorId, let user = auth.user else { return false }
        return !authorId.isEmpty && user.uuid == authorId
    }

    func body(content: Content) -> some View {
        content
            // See `VoiceOverAwareSwipeActions`'s doc comment for why this
            // has to be an all-or-nothing gate on VoiceOver, not per-button
            // `.accessibilityHidden` (which was here before and did not
            // actually stop "Save"/"Share" from being announced a second
            // time, duplicating "Save Topic"/"Share Topic" below).
            .voiceOverAwareSwipeActions {
                Button {
                    toggleSave()
                } label: {
                    Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                .tint(.orange)
            } trailing: {
                if let url, let shareURL = URL(string: url) {
                    ShareLink(item: shareURL, subject: Text(title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
                if canOfferFollow {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Label(isFollowing ? "Unfollow" : "Follow", systemImage: isFollowing ? "bell.slash" : "bell")
                    }
                    .tint(.indigo)
                }
                if canOfferRecommend {
                    Button {
                        Task { await toggleRecommend() }
                    } label: {
                        Label(isRecommended ? "Unrecommend" : "Recommend", systemImage: isRecommended ? "hand.thumbsdown" : "hand.thumbsup")
                    }
                    .tint(.orange)
                }
            }
            // Previously gated to `!UIAccessibility.isVoiceOverRunning` to
            // stop Save/Share appearing twice when reading through the open
            // menu — but that also removed VoiceOver's own long-press
            // gesture entirely, since it's what opens this exact menu.
            // Reported directly: "long press doesn't seem to be working."
            // A non-functional gesture is worse than an occasional
            // duplicate, so this is back to unconditional; the duplication
            // needs a more targeted fix (likely to the menu content itself,
            // not to whether the menu is attached at all).
            // Every button below also has a corresponding .accessibilityAction
            // further down, so each is marked .accessibilityHidden(true) here
            // — otherwise SwiftUI exposes the context menu's own buttons as a
            // second, redundant set of VoiceOver custom actions alongside the
            // explicit ones (e.g. "Save Forum Topic" announced twice). Order
            // matches the .accessibilityAction chain below: routine actions
            // first, admin/destructive actions last.
            .contextMenu {
                extraMenuItems
                if newCount > 0 {
                    Button { markAsRead() } label: {
                        Label("Mark as Read", systemImage: "checkmark.circle")
                    }
                    .accessibilityHidden(true)
                    Button { jumpToFirstNewComment() } label: {
                        Label("Jump to First New Comment", systemImage: "arrow.down.to.line")
                    }
                    .accessibilityHidden(true)
                }
                Button {
                    toggleSave()
                } label: {
                    Label(isSaved ? "Unsave \(kind.saveActionNoun)" : "Save \(kind.saveActionNoun)", systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                .accessibilityHidden(true)
                if canOfferFollow {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Label(isFollowing ? "Unfollow \(kind.displayName)" : "Follow \(kind.displayName)", systemImage: isFollowing ? "bell.slash" : "bell")
                    }
                    .accessibilityHidden(true)
                }
                if canOfferRecommend {
                    Button {
                        Task { await toggleRecommend() }
                    } label: {
                        Label(isRecommended ? "I No Longer Recommend This App" : "Recommend This App", systemImage: isRecommended ? "hand.thumbsdown" : "hand.thumbsup")
                    }
                    .accessibilityHidden(true)
                }
                if let url, let shareURL = URL(string: url) {
                    ShareLink(item: shareURL, subject: Text(title)) {
                        Label("Share \(kind.displayName)", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityHidden(true)
                }
                if url.flatMap(URL.init) != nil {
                    Button { openInBrowser() } label: {
                        Label("Open \(kind.displayName) in Browser", systemImage: "safari")
                    }
                    .accessibilityHidden(true)
                }
                Button { addComment() } label: {
                    Label(addCommentLabel, systemImage: "bubble.left")
                }
                .accessibilityHidden(true)
                // Owner-only Edit/Delete are gated on !isAdmin: kind.displayName
                // resolves to "Topic" for forum topics either way, so an
                // owner who is also an admin previously saw two
                // indistinguishable "Edit Topic"/"Delete Topic" entries — the
                // admin block below already covers this case, plus Unpublish.
                if isOwnTopic && !isAdmin {
                    Button { startEdit() } label: {
                        Label("Edit Topic", systemImage: "pencil")
                    }
                    .accessibilityHidden(true)
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Topic", systemImage: "trash")
                    }
                    .accessibilityHidden(true)
                }
                if isAdmin {
                    Button { startEdit() } label: {
                        Label("Edit \(kind.displayName)", systemImage: "pencil")
                    }
                    .accessibilityHidden(true)
                    Button { showUnpublishConfirm = true } label: {
                        Label("Unpublish \(kind.displayName)", systemImage: "eye.slash")
                    }
                    .accessibilityHidden(true)
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete \(kind.displayName)", systemImage: "trash")
                    }
                    .accessibilityHidden(true)
                }
            }
            .modifier(ConditionalAccessibilityAction(isActive: newCount > 0, name: "Mark as Read") {
                markAsRead()
            })
            .modifier(ConditionalAccessibilityAction(isActive: newCount > 0, name: "Jump to First New Comment") {
                jumpToFirstNewComment()
            })
            .accessibilityAction(named: Text(isSaved ? "Unsave \(kind.saveActionNoun)" : "Save \(kind.saveActionNoun)")) {
                toggleSave()
            }
            .modifier(ConditionalAccessibilityAction(
                isActive: canOfferFollow,
                name: isFollowing ? "Unfollow \(kind.displayName)" : "Follow \(kind.displayName)"
            ) {
                Task { await toggleFollow() }
            })
            .modifier(ConditionalAccessibilityAction(
                isActive: canOfferRecommend,
                name: isRecommended ? "I No Longer Recommend This App" : "Recommend This App"
            ) {
                Task { await toggleRecommend() }
            })
            .modifier(ConditionalAccessibilityAction(
                isActive: url.flatMap(URL.init) != nil,
                name: "Share \(kind.displayName)"
            ) {
                presentShareSheet()
            })
            .modifier(ConditionalAccessibilityAction(
                isActive: url.flatMap(URL.init) != nil,
                name: "Open \(kind.displayName) in Browser"
            ) {
                openInBrowser()
            })
            .accessibilityAction(named: Text(addCommentLabel)) { addComment() }
            .modifier(ConditionalAccessibilityAction(isActive: isOwnTopic && !isAdmin, name: "Edit Topic") { startEdit() })
            .modifier(ConditionalAccessibilityAction(isActive: isOwnTopic && !isAdmin, name: "Delete Topic") { showDeleteConfirm = true })
            .modifier(ConditionalAccessibilityAction(isActive: isAdmin, name: "Edit \(kind.displayName)") { startEdit() })
            .modifier(ConditionalAccessibilityAction(isActive: isAdmin, name: "Unpublish \(kind.displayName)") { showUnpublishConfirm = true })
            .modifier(ConditionalAccessibilityAction(isActive: isAdmin, name: "Delete \(kind.displayName)") { showDeleteConfirm = true })
            .sheet(isPresented: $showBrowser) {
                if let url, let shareURL = URL(string: url) {
                    SafariView(url: shareURL)
                }
            }
            .sheet(item: $editingNode) { node in
                EditNodeSheet(initialTitle: node.title, initialBody: node.body) { newTitle, newBody in
                    try await saveEdit(nodeTypeSuffix: node.nodeTypeSuffix, title: newTitle, body: newBody)
                }
            }
            .confirmationDialog(
                "Unpublish this \(kind.displayName.lowercased())?",
                isPresented: $showUnpublishConfirm, titleVisibility: .visible
            ) {
                Button("Unpublish", role: .destructive) { Task { await unpublish() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This hides it from public view.")
            }
            .confirmationDialog(
                isOwnTopic ? "Delete this topic?" : "Delete this \(kind.displayName.lowercased())?",
                isPresented: $showDeleteConfirm, titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { Task { await deleteContent() } }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                isSaved = PersistenceStore.shared.isSaved(id: id)
                isFollowing = PersistenceStore.shared.isFollowed(id: id)
                if kind == .appListing {
                    isRecommended = RecommendationStore.shared.isRecommended(id)
                    if let user = auth.user {
                        Task {
                            await RecommendationStore.shared.loadIfNeeded(for: user)
                            isRecommended = RecommendationStore.shared.isRecommended(id)
                        }
                    }
                }
            }
    }

    /// A `.forumTopic`, `.podcastEpisode`, etc. is always a Drupal node
    /// under the hood — `nodeType` is only ever wrong for Bug Reports,
    /// whose actual bundle depends on the platform (iOS vs macOS), which
    /// isn't known from the row alone.
    private func resolvedNodeTypeSuffix() async -> String {
        let generic = String(kind.nodeType.dropFirst("node--".count))
        guard kind == .bugReport else { return generic }
        guard let d = try? await APIClient.shared.bugReports.detail(id: id) else { return generic }
        return d.platform == .ios ? "ios_bug_report" : "os_x_bug_report"
    }

    /// Fetches the full title+body before editing — list rows only carry
    /// summary data, and editNode needs the complete current body to avoid
    /// clobbering it.
    private func startEdit() {
        Task {
            guard let content = await fetchEditableContent() else {
                toast.error(String(localized: "Couldn't load \(kind.displayName.lowercased()) to edit."))
                return
            }
            editingNode = content
        }
    }

    private func fetchEditableContent() async -> EditableNode? {
        switch kind {
        case .forumTopic:
            guard let d = try? await APIClient.shared.forums.topicDetail(id: id) else { return nil }
            return EditableNode(title: d.title, body: d.body, nodeTypeSuffix: "forum")
        case .podcastEpisode:
            guard let d = try? await APIClient.shared.podcasts.episode(id: id) else { return nil }
            return EditableNode(title: d.title, body: d.description, nodeTypeSuffix: "podcast")
        case .appListing:
            guard let d = try? await APIClient.shared.apps.detail(id: id) else { return nil }
            let nodeTypeSuffix: String
            switch d.platform {
            case .tvos:    nodeTypeSuffix = "tv_directory"
            case .watchos: nodeTypeSuffix = "watch_directory"
            case .macos:   nodeTypeSuffix = "mac_app_directory"
            case .ios:     nodeTypeSuffix = "ios_app_directory"
            }
            return EditableNode(title: d.name, body: d.body, nodeTypeSuffix: nodeTypeSuffix)
        case .resource:
            guard let d = try? await APIClient.shared.resources.detail(id: id) else { return nil }
            return EditableNode(title: d.title, body: d.body, nodeTypeSuffix: "guides")
        case .blogPost:
            guard let d = try? await APIClient.shared.blogs.detail(id: id) else { return nil }
            return EditableNode(title: d.title, body: d.body, nodeTypeSuffix: "blog2")
        case .bugReport:
            guard let d = try? await APIClient.shared.bugReports.detail(id: id) else { return nil }
            return EditableNode(title: d.title, body: d.body, nodeTypeSuffix: d.platform == .ios ? "ios_bug_report" : "os_x_bug_report")
        }
    }

    private func saveEdit(nodeTypeSuffix: String, title: String, body: String) async throws {
        guard let user = auth.user else { return }
        try await APIClient.shared.content.editNode(nodeId: id, nodeType: nodeTypeSuffix, title: title, body: body, csrfToken: user.csrfToken)
        toast.success(String(localized: "\(kind.displayName) updated"))
    }

    private func unpublish() async {
        guard let user = auth.user else { return }
        let suffix = await resolvedNodeTypeSuffix()
        do {
            try await APIClient.shared.content.unpublishNode(nodeId: id, nodeType: suffix, csrfToken: user.csrfToken)
            toast.success(String(localized: "\(kind.displayName) unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish."))
        }
    }

    private func deleteContent() async {
        guard let user = auth.user else { return }
        let suffix = await resolvedNodeTypeSuffix()
        do {
            try await APIClient.shared.content.deleteNode(nodeId: id, nodeType: suffix, csrfToken: user.csrfToken)
            SpotlightIndexer.deindex(kind: kind, id: id)
            toast.success(String(localized: "\(kind.displayName) deleted"))
            onContentDeleted?()
        } catch {
            toast.error(String(localized: "Couldn't delete."))
        }
    }

    /// Matches RN's exact stub for content types with no real "reply from
    /// the list" flow (Guides/Blogs/Bug Reports): "Open the item to add a
    /// new comment." Forums/Podcasts pass a real `onAddComment` handler
    /// that opens a composer directly instead.
    private func addComment() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to add a new comment."))
            return
        }
        guard let onAddComment else {
            toast.warning(String(localized: "Open the item to add a new comment."))
            return
        }
        onAddComment()
    }

    private func markAsRead() {
        guard let currentCommentCount else { return }
        PersistenceStore.shared.stampItemVisit(id: FeedItem.visitKey(kind: kind, contentId: id), commentCount: currentCommentCount)
        UIAccessibility.post(notification: .announcement, argument: "Marked as read.")
    }

    /// Opens the item and lands VoiceOver focus directly on the first new
    /// reply/comment/review, instead of the top of the screen — every
    /// detail screen already has its own "Jump to First New Comment" logic
    /// (ForumTopicDetailView.jumpToFirstNewReply and its siblings); this
    /// just tells DeepLinkRouter which content to open with that intent
    /// already set, so it's ready the moment the screen finishes loading.
    /// Opens as a sheet rather than a push — see pendingContentIntent's doc
    /// comment on DeepLinkRouter for why.
    private func jumpToFirstNewComment() {
        deepLinkRouter.pendingContentIntent = .firstNewComment
        deepLinkRouter.pendingContent = (kind: kind, id: id)
    }

    /// ShareLink has no programmatic trigger, so the explicit VoiceOver
    /// Share action presents the same system share sheet directly via UIKit.
    private func presentShareSheet() {
        guard let url, let shareURL = URL(string: url) else { return }
        let activityVC = UIActivityViewController(activityItems: [shareURL], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }

    /// Matches WebLink's own in-app-vs-external branching so "Open ... in
    /// Browser" respects the same preference instead of always forcing the
    /// in-app SafariView sheet.
    private func openInBrowser() {
        guard let url, let shareURL = URL(string: url) else { return }
        switch preferences.webBrowsingMode {
        case .inApp:    showBrowser = true
        case .external: UIApplication.shared.open(shareURL)
        }
    }

    private func toggleSave() {
        if isSaved {
            PersistenceStore.shared.unsave(id: id)
            isSaved = false
            toast.success(String(localized: "Removed from Saved"))
        } else {
            PersistenceStore.shared.save(SavedItem(id: id, kind: kind, title: title, savedAt: Date(), lastActivityAt: lastActivityAt))
            isSaved = true
            toast.success(String(localized: "Saved"))
            SoundPlayer.shared.play(.bookmarkSaved)
        }
        onSaveToggle?(isSaved)
    }

    private func toggleFollow() async {
        guard let user = auth.user else { return }
        do {
            if isFollowing {
                try await APIClient.shared.flags.unfollow(nodeUuid: id, token: user.csrfToken)
                PersistenceStore.shared.markUnfollowed(id: id)
                isFollowing = false
                toast.success(String(localized: "Unfollowed"))
                onFollowToggle?(false)
            } else {
                try await APIClient.shared.flags.follow(nodeUuid: id, nodeType: kind.nodeType, token: user.csrfToken)
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: id, kind: kind, nodeType: kind.nodeType, title: title,
                    followedAt: Date(), lastActivityAt: lastActivityAt, url: url ?? ""
                ))
                isFollowing = true
                toast.success(String(localized: "Following"))
                if kind == .forumTopic { tips.show(.followTopicNotifications) }
                onFollowToggle?(true)
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't update follow status."))
        }
    }

    private func toggleRecommend() async {
        guard let user = auth.user else { return }
        do {
            if isRecommended {
                try await APIClient.shared.flags.unrecommend(nodeUuid: id, token: user.csrfToken)
                RecommendationStore.shared.markNotRecommended(id)
                isRecommended = false
                toast.success(String(localized: "Removed from Recommendations"))
            } else {
                try await APIClient.shared.flags.recommend(nodeUuid: id, nodeType: kind.nodeType, token: user.csrfToken)
                RecommendationStore.shared.markRecommended(id)
                isRecommended = true
                toast.success(String(localized: "You recommended this app!"))
                SoundPlayer.shared.play(.bookmarkSaved)
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't update your recommendation."))
        }
    }
}

/// Canonical action identity — every action `ContentActionsModifier` can
/// expose, independent of its (state-dependent) display label. Exists so the
/// ordering/dedup established in `body` above can be checked by a real
/// permutation test (`ContentActionsOrderingTests`) instead of only by
/// eyeballing the modifier chain — CARD-01/CARD-03/FORUM-03 (duplicate and
/// out-of-order VoiceOver actions, including an admin-who-owns-the-topic
/// seeing two indistinguishable "Edit Topic" entries) were exactly this kind
/// of drift going unnoticed.
///
/// IMPORTANT: this mirrors the conditions and order of the `.contextMenu`
/// block and `.accessibilityAction`/`ConditionalAccessibilityAction` chain in
/// `body` above by hand — it does not drive them. If you change which
/// actions appear, in what order, or under what condition up there, update
/// `canonicalActions` below to match, or the test suite will pass against a
/// mirror that no longer reflects the real UI.
enum ContentAction: Equatable {
    case markAsRead
    case jumpToFirstNewComment
    case save
    case follow
    case addComment
    case share
    case openInBrowser
    case editTopic
    case deleteTopic
    case editContent
    case unpublish
    case deleteContent
}

extension ContentActionsModifier {
    static func canonicalActions(
        hasNewCount: Bool,
        supportsFollow: Bool,
        isSignedIn: Bool,
        hasUrl: Bool,
        isOwnTopic: Bool,
        isAdmin: Bool,
        // Defaulted so existing call sites/tests written before Follow was
        // shelved keep compiling — mirrors `canOfferFollow`'s "hide
        // starting a new follow, but never hide undoing an existing one."
        isFollowing: Bool = false
    ) -> [ContentAction] {
        var actions: [ContentAction] = []
        if hasNewCount {
            actions.append(.markAsRead)
            actions.append(.jumpToFirstNewComment)
        }
        actions.append(.save)
        if (followFeatureEnabled || isFollowing) && supportsFollow && isSignedIn { actions.append(.follow) }
        actions.append(.addComment)
        if hasUrl { actions.append(.share) }
        if hasUrl { actions.append(.openInBrowser) }
        if isOwnTopic && !isAdmin {
            actions.append(.editTopic)
            actions.append(.deleteTopic)
        }
        if isAdmin {
            actions.append(.editContent)
            actions.append(.unpublish)
            actions.append(.deleteContent)
        }
        return actions
    }
}

/// Not private — `ForumTopicDetailView` reuses this and `EditNodeSheet`
/// directly for topic-level Edit/Delete/Unpublish, which previously had no
/// equivalent anywhere on the detail screen itself (only from a browse-list
/// row's long-press menu).
struct EditableNode: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let nodeTypeSuffix: String
}

/// Generic title+body editor for admin/owner "Edit" actions — reused across
/// every content kind (Forums/Podcasts/Apps/Guides/Blogs/Bug Reports) rather
/// than building 6 nearly-identical edit screens.
struct EditNodeSheet: View {
    let onSave: (String, String) async throws -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var isSubmitting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    /// Had no focus management at all — focuses the title field itself
    /// rather than a separate heading, matching ComposeTopicView's identical
    /// reasoning for a single-field-first edit form: otherwise it silently
    /// defaults to the back button. Full app-wide focus audit, requested
    /// directly.
    @AccessibilityFocusState private var isTitleFieldFocused: Bool

    init(initialTitle: String, initialBody: String, onSave: @escaping (String, String) async throws -> Void) {
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _bodyText = State(initialValue: initialBody)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                        .accessibilityFocused($isTitleFieldFocused)
                }
                Section("Body") {
                    if intelligence.showTranslatePrompt {
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
                    if let warning = guidelines.topWarning {
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
                    Text(error).foregroundStyle(.red)
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await submit() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .task { await retryAccessibilityFocus(into: $isTitleFieldFocused) }
        }
    }

    private func submit() async {
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: title,
            body: bodyText
        ) {
            error = message
            return
        }
        isSubmitting = true; error = nil
        do {
            try await onSave(title, bodyText)
            dismiss()
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't save changes."
        }
        isSubmitting = false
    }
}

/// Attaches an .accessibilityAction only when `isActive` — e.g. Share should
/// not appear as a VoiceOver action at all when there's no url, and Follow
/// shouldn't appear when signed out, rather than appearing as a no-op.
/// Internal (not private) so other rows/detail screens with the same
/// conditional-action need (e.g. ReplyView's Edit/Delete) can reuse it.
struct ConditionalAccessibilityAction: ViewModifier {
    let isActive: Bool
    let name: String
    let action: () -> Void

    func body(content: Content) -> some View {
        if isActive {
            content.accessibilityAction(named: Text(name), action)
        } else {
            content
        }
    }
}

/// Attaches `.swipeActions` only while VoiceOver is off.
///
/// `.accessibilityHidden(true)` on a swipe-action button does NOT stop it
/// from becoming its own VoiceOver custom action: List's leading/trailing
/// swipe actions are bridged straight to UIKit's row-action mechanism, and
/// VoiceOver derives an action from each button's title there — entirely
/// outside the SwiftUI accessibility tree `.accessibilityHidden` affects.
/// That's why every row using this pattern kept announcing a bare "Save"/
/// "Share"/"Cancel"/"Remove" back to back with its explicit, correctly-named
/// `.accessibilityAction` (e.g. "Save Topic") — hiding the button never
/// touched the actual source. The only real fix is to not attach
/// `.swipeActions` at all while VoiceOver is running: a VoiceOver user's
/// one-finger swipe is already claimed by element navigation, so the
/// gesture these buttons exist for isn't reachable to them anyway, and
/// every call site pairs each swipe button with an equivalent explicit
/// `.accessibilityAction`. Found independently duplicated (and subtly
/// wrong every time) in `ContentActionsModifier` and twice more in
/// `ForYouView`'s Downloads rows — reason enough to centralize it here
/// instead of hand-rolling the VoiceOver-status tracking a fourth time.
struct VoiceOverAwareSwipeActions<Leading: View, Trailing: View>: ViewModifier {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning

    func body(content: Content) -> some View {
        Group {
            if isVoiceOverRunning {
                content
            } else {
                content
                    .swipeActions(edge: .leading) { leading() }
                    .swipeActions(edge: .trailing) { trailing() }
            }
        }
        .onAppear { isVoiceOverRunning = UIAccessibility.isVoiceOverRunning }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
    }
}

extension View {
    /// Trailing-only convenience — most rows only need a trailing swipe set.
    func voiceOverAwareSwipeActions<Trailing: View>(
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        modifier(VoiceOverAwareSwipeActions(leading: { EmptyView() }, trailing: trailing))
    }

    /// Two-sided variant for rows that also need a leading swipe (e.g. Save).
    func voiceOverAwareSwipeActions<Leading: View, Trailing: View>(
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        modifier(VoiceOverAwareSwipeActions(leading: leading, trailing: trailing))
    }
}

private struct CardDensityPaddingModifier: ViewModifier {
    @AppStorage("appearance.cardDensity") private var cardDensity: CardDensity = .comfortable
    func body(content: Content) -> some View {
        content.padding(.vertical, cardDensity.verticalPadding)
    }
}

extension View {
    /// Applies the user's card-density preference (comfortable/compact row spacing).
    func cardDensityPadding() -> some View {
        modifier(CardDensityPaddingModifier())
    }

    /// Adds save/follow/share swipe actions + context menu to a row or detail screen.
    /// `extraMenuItems` inserts kind-specific primary actions (e.g. Play/Add
    /// to Queue for podcast rows) at the top of the shared context menu,
    /// visible to sighted long-press users the same way the VoiceOver-only
    /// equivalents already were — these used to only exist as
    /// `.accessibilityAction`s, invisible to anyone not using VoiceOver.
    func contentActions(
        id: String, kind: ContentKind, title: String,
        lastActivityAt: Date? = nil, url: String? = nil, supportsFollow: Bool = true,
        onSaveToggle: ((Bool) -> Void)? = nil, onFollowToggle: ((Bool) -> Void)? = nil,
        currentCommentCount: Int? = nil, onAddComment: (() -> Void)? = nil,
        authorId: String? = nil, onContentDeleted: (() -> Void)? = nil,
        @ViewBuilder extraMenuItems: () -> some View = { EmptyView() }
    ) -> some View {
        modifier(ContentActionsModifier(
            id: id, kind: kind, title: title, lastActivityAt: lastActivityAt, url: url, supportsFollow: supportsFollow,
            onSaveToggle: onSaveToggle, onFollowToggle: onFollowToggle,
            currentCommentCount: currentCommentCount, onAddComment: onAddComment,
            authorId: authorId, onContentDeleted: onContentDeleted,
            extraMenuItems: AnyView(extraMenuItems())
        ))
    }
}

/// Fixed bottom action bar for detail screens (Follow/Save/Share/Open in
/// Browser) — matches the old RN app's bottom `ToolbarButton` row (icon +
/// label, evenly spaced; `git show 655e6ca^:app/app-detail/[id].tsx`
/// confirms every content-detail screen used this pattern, not just forum
/// topics). Used to live crammed into the top navigation bar as icon-only
/// buttons; moved back to the bottom via `.safeAreaInset(edge: .bottom)` at
/// each call site, matching where users actually remember reaching for them.
struct ContentDetailActions: View {
    let id: String
    let kind: ContentKind
    let title: String
    let lastActivityAt: Date?
    let url: String?
    var supportsFollow: Bool = true
    /// Add Comment — the same compose flow every detail
    /// screen already had, previously sitting in the top toolbar and
    /// hidden entirely until signed in. Relocated into this bottom bar to
    /// match Forums, whose Reply button has always lived here rather than
    /// the toolbar, and switched from hidden-when-signed-out to always
    /// shown but gated on tap — matching the same shift ComposeTopicView
    /// and Home's Add menu already went through. Reported directly: "Add
    /// a New Comment" looked entirely missing from the topic detail page,
    /// which turned out to be true for every OTHER content kind's detail
    /// screen too (it lived in the toolbar, not here) and was additionally
    /// invisible whenever signed out.
    var onAddComment: () -> Void

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var isSaved = false
    @State private var isFollowing = false
    @State private var isRecommended = false
    @State private var showBrowser = false

    private var addCommentVisualLabel: String { "Comment" }
    private var addCommentAccessibilityLabel: String {
        String(localized: "Add Comment")
    }

    /// Same shelved-Follow gating as `ContentActionsModifier.canOfferFollow`
    /// — hides starting a new follow, never hides undoing an existing one.
    private var canOfferFollow: Bool {
        supportsFollow && (followFeatureEnabled || isFollowing)
    }

    /// Same app-only gating as `ContentActionsModifier.canOfferRecommend`.
    private var canOfferRecommend: Bool {
        kind == .appListing
    }

    private func requestRecommendToggle() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to recommend this app."))
            return
        }
        Task { await toggleRecommend() }
    }

    private func requestAddComment() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to add a comment."))
            return
        }
        onAddComment()
    }

    private func requestFollowToggle() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to follow \(kind.displayName.lowercased())."))
            return
        }
        Task { await toggleFollow() }
    }

    var body: some View {
        // Order matches ContentActionsModifier's canonical action order:
        // Save, Follow, Share, Browser, then Comment last.
        HStack(spacing: 0) {
            DetailActionButton(
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                visualLabel: isSaved ? "Unsave" : "Save",
                accessibilityLabel: isSaved ? String(localized: "Unsave \(kind.displayName)") : String(localized: "Save \(kind.displayName)")
            ) { toggleSave() }

            if canOfferFollow {
                DetailActionButton(
                    systemImage: isFollowing ? "bell.fill" : "bell",
                    visualLabel: isFollowing ? "Unfollow" : "Follow",
                    accessibilityLabel: isFollowing ? String(localized: "Unfollow \(kind.displayName)") : String(localized: "Follow \(kind.displayName)")
                ) { requestFollowToggle() }
            }

            if canOfferRecommend {
                DetailActionButton(
                    systemImage: isRecommended ? "hand.thumbsup.fill" : "hand.thumbsup",
                    visualLabel: isRecommended ? "Recommended" : "Recommend",
                    accessibilityLabel: isRecommended ? String(localized: "I No Longer Recommend This App") : String(localized: "Recommend This App")
                ) { requestRecommendToggle() }
            }

            if let url, let shareURL = URL(string: url) {
                ShareLink(item: shareURL, subject: Text(title)) {
                    DetailActionButtonLabel(systemImage: "square.and.arrow.up", visualLabel: "Share")
                }
                .accessibilityLabel(String(localized: "Share \(kind.displayName)"))

                DetailActionButton(systemImage: "safari", visualLabel: "Browser", accessibilityLabel: String(localized: "Open \(kind.displayName) in Browser")) {
                    switch preferences.webBrowsingMode {
                    case .inApp:    showBrowser = true
                    case .external: UIApplication.shared.open(shareURL)
                    }
                }
                .sheet(isPresented: $showBrowser) {
                    SafariView(url: shareURL)
                }
            }

            DetailActionButton(
                systemImage: "bubble.left",
                visualLabel: addCommentVisualLabel,
                accessibilityLabel: addCommentAccessibilityLabel
            ) { requestAddComment() }
        }
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .onAppear {
            isSaved = PersistenceStore.shared.isSaved(id: id)
            isFollowing = PersistenceStore.shared.isFollowed(id: id)
            if canOfferRecommend {
                isRecommended = RecommendationStore.shared.isRecommended(id)
                if let user = auth.user {
                    Task {
                        await RecommendationStore.shared.loadIfNeeded(for: user)
                        isRecommended = RecommendationStore.shared.isRecommended(id)
                    }
                }
            }
        }
    }

    private func toggleSave() {
        if isSaved {
            PersistenceStore.shared.unsave(id: id)
            isSaved = false
            toast.success(String(localized: "Removed from Saved"))
        } else {
            PersistenceStore.shared.save(SavedItem(id: id, kind: kind, title: title, savedAt: Date(), lastActivityAt: lastActivityAt))
            isSaved = true
            toast.success(String(localized: "Saved"))
            SoundPlayer.shared.play(.bookmarkSaved)
        }
    }

    private func toggleFollow() async {
        guard let user = auth.user else { return }
        do {
            if isFollowing {
                try await APIClient.shared.flags.unfollow(nodeUuid: id, token: user.csrfToken)
                PersistenceStore.shared.markUnfollowed(id: id)
                isFollowing = false
                toast.success(String(localized: "Unfollowed"))
            } else {
                try await APIClient.shared.flags.follow(nodeUuid: id, nodeType: kind.nodeType, token: user.csrfToken)
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: id, kind: kind, nodeType: kind.nodeType, title: title,
                    followedAt: Date(), lastActivityAt: lastActivityAt, url: url ?? ""
                ))
                isFollowing = true
                toast.success(String(localized: "Following"))
                if kind == .forumTopic { tips.show(.followTopicNotifications) }
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't update follow status."))
        }
    }

    private func toggleRecommend() async {
        guard let user = auth.user else { return }
        do {
            if isRecommended {
                try await APIClient.shared.flags.unrecommend(nodeUuid: id, token: user.csrfToken)
                RecommendationStore.shared.markNotRecommended(id)
                isRecommended = false
                toast.success(String(localized: "Removed from Recommendations"))
            } else {
                try await APIClient.shared.flags.recommend(nodeUuid: id, nodeType: kind.nodeType, token: user.csrfToken)
                RecommendationStore.shared.markRecommended(id)
                isRecommended = true
                toast.success(String(localized: "You recommended this app!"))
                SoundPlayer.shared.play(.bookmarkSaved)
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't update your recommendation."))
        }
    }
}

/// One icon+label button in a bottom detail action bar. Not private — reused
/// directly by ForumTopicDetailView's own bottom bar (which has a 5th
/// content-specific action, Reply, that ContentDetailActions doesn't cover)
/// so both bars look and behave identically.
struct DetailActionButton: View {
    let systemImage: String
    let visualLabel: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DetailActionButtonLabel(systemImage: systemImage, visualLabel: visualLabel)
        }
        .accessibilityLabel(String(localized: String.LocalizationValue(accessibilityLabel)))
    }
}

struct DetailActionButtonLabel: View {
    let systemImage: String
    let visualLabel: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                // CARD-11: fixed-point size didn't scale with Dynamic Type;
                // .title3 matches the prior 20pt default exactly while
                // still responding to the system text-size setting.
                .font(.title3)
            Text(String(localized: String.LocalizationValue(visualLabel)))
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}
