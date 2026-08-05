import SwiftUI

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

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @State private var isSaved = false
    @State private var isFollowing = false

    func body(content: Content) -> some View {
        content
            // .swipeActions buttons are what SwiftUI actually exposes to
            // VoiceOver as custom actions (reachable by swiping up/down once
            // an item is selected). .contextMenu items are NOT reliably
            // exposed the same way — Follow/Share used to live only in the
            // context menu, so VoiceOver users only ever heard "Save" repeat.
            // Per docs/APPLEVIS_2026_1_MASTER_SPEC.md: "Use custom actions
            // for Save, Follow, Share..." — this puts all three there.
            .swipeActions(edge: .leading) {
                Button {
                    toggleSave()
                } label: {
                    Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                .tint(.orange)
                // Visible button text stays short (swipe buttons truncate),
                // but VoiceOver gets the fuller, self-descriptive phrasing —
                // it announces this in isolation, without the row's own
                // label alongside it, so "Save" alone is ambiguous out of
                // context.
                .accessibilityLabel(isSaved ? "Unsave \(kind.displayName)" : "Save \(kind.displayName)")
            }
            .swipeActions(edge: .trailing) {
                if let url, let shareURL = URL(string: url) {
                    ShareLink(item: shareURL, subject: Text(title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                    .accessibilityLabel("Share \(kind.displayName)")
                }
                if supportsFollow && auth.isSignedIn {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Label(isFollowing ? "Unfollow" : "Follow", systemImage: isFollowing ? "bell.slash" : "bell")
                    }
                    .tint(.indigo)
                    .accessibilityLabel(isFollowing ? "Unfollow \(kind.displayName)" : "Follow \(kind.displayName)")
                }
            }
            .contextMenu {
                Button {
                    toggleSave()
                } label: {
                    Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                if supportsFollow && auth.isSignedIn {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Label(isFollowing ? "Unfollow" : "Follow", systemImage: isFollowing ? "bell.slash" : "bell")
                    }
                }
                if let url, let shareURL = URL(string: url) {
                    ShareLink(item: shareURL, subject: Text(title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                isSaved = PersistenceStore.shared.isSaved(id: id)
                isFollowing = PersistenceStore.shared.isFollowed(id: id)
            }
    }

    private func toggleSave() {
        if isSaved {
            PersistenceStore.shared.unsave(id: id)
            isSaved = false
            toast.success("Removed from Saved")
        } else {
            PersistenceStore.shared.save(SavedItem(id: id, kind: kind, title: title, savedAt: Date(), lastActivityAt: lastActivityAt))
            isSaved = true
            toast.success("Saved")
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
                toast.success("Unfollowed")
            } else {
                try await APIClient.shared.flags.follow(nodeUuid: id, nodeType: kind.nodeType, token: user.csrfToken)
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: id, kind: kind, nodeType: kind.nodeType, title: title,
                    followedAt: Date(), lastActivityAt: lastActivityAt, url: url ?? ""
                ))
                isFollowing = true
                toast.success("Following")
                if kind == .forumTopic { tips.show(.followTopicNotifications) }
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error("Couldn't update follow status.")
        }
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
    func contentActions(
        id: String, kind: ContentKind, title: String,
        lastActivityAt: Date? = nil, url: String? = nil, supportsFollow: Bool = true
    ) -> some View {
        modifier(ContentActionsModifier(
            id: id, kind: kind, title: title, lastActivityAt: lastActivityAt, url: url, supportsFollow: supportsFollow
        ))
    }
}

/// Toolbar-style variant for detail screens (save/follow as toolbar buttons + a
/// native `ShareLink`), rather than swipe/context-menu.
struct ContentDetailActions: View {
    let id: String
    let kind: ContentKind
    let title: String
    let lastActivityAt: Date?
    let url: String?
    var supportsFollow: Bool = true

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @State private var isSaved = false
    @State private var isFollowing = false

    var body: some View {
        Group {
            if supportsFollow && auth.isSignedIn {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Image(systemName: isFollowing ? "bell.fill" : "bell")
                }
                .accessibilityLabel(isFollowing ? "Unfollow" : "Follow")
            }

            Button {
                toggleSave()
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(isSaved ? "Unsave" : "Save")

            if let url, let shareURL = URL(string: url) {
                ShareLink(item: shareURL, subject: Text(title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            isSaved = PersistenceStore.shared.isSaved(id: id)
            isFollowing = PersistenceStore.shared.isFollowed(id: id)
        }
    }

    private func toggleSave() {
        if isSaved {
            PersistenceStore.shared.unsave(id: id)
            isSaved = false
            toast.success("Removed from Saved")
        } else {
            PersistenceStore.shared.save(SavedItem(id: id, kind: kind, title: title, savedAt: Date(), lastActivityAt: lastActivityAt))
            isSaved = true
            toast.success("Saved")
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
                toast.success("Unfollowed")
            } else {
                try await APIClient.shared.flags.follow(nodeUuid: id, nodeType: kind.nodeType, token: user.csrfToken)
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: id, kind: kind, nodeType: kind.nodeType, title: title,
                    followedAt: Date(), lastActivityAt: lastActivityAt, url: url ?? ""
                ))
                isFollowing = true
                toast.success("Following")
                if kind == .forumTopic { tips.show(.followTopicNotifications) }
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error("Couldn't update follow status.")
        }
    }
}
