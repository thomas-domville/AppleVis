import SwiftUI
import UIKit

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
            // The visible swipe buttons below are hidden from the
            // accessibility tree (.accessibilityHidden) and are NOT the
            // source of VoiceOver's custom actions — on this SDK,
            // .accessibilityLabel applied to a .swipeActions button doesn't
            // replace its auto-derived custom-action name, it adds a SECOND
            // one, so VoiceOver announced both "Save" and "Save Forum Topic"
            // back to back for the same action. The .accessibilityAction
            // block further down is the single, explicit source of truth
            // instead, giving full control with no duplicates.
            .swipeActions(edge: .leading) {
                Button {
                    toggleSave()
                } label: {
                    Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                .tint(.orange)
                .accessibilityHidden(true)
            }
            .swipeActions(edge: .trailing) {
                if let url, let shareURL = URL(string: url) {
                    ShareLink(item: shareURL, subject: Text(title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                    .accessibilityHidden(true)
                }
                if supportsFollow && auth.isSignedIn {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Label(isFollowing ? "Unfollow" : "Follow", systemImage: isFollowing ? "bell.slash" : "bell")
                    }
                    .tint(.indigo)
                    .accessibilityHidden(true)
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
            .accessibilityAction(named: Text(isSaved ? "Unsave \(kind.displayName)" : "Save \(kind.displayName)")) {
                toggleSave()
            }
            .modifier(ConditionalAccessibilityAction(
                isActive: url.flatMap(URL.init) != nil,
                name: "Share \(kind.displayName)"
            ) {
                presentShareSheet()
            })
            .modifier(ConditionalAccessibilityAction(
                isActive: supportsFollow && auth.isSignedIn,
                name: isFollowing ? "Unfollow \(kind.displayName)" : "Follow \(kind.displayName)"
            ) {
                Task { await toggleFollow() }
            })
            .onAppear {
                isSaved = PersistenceStore.shared.isSaved(id: id)
                isFollowing = PersistenceStore.shared.isFollowed(id: id)
            }
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

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @State private var isSaved = false
    @State private var isFollowing = false
    @State private var showBrowser = false

    var body: some View {
        HStack(spacing: 0) {
            if supportsFollow && auth.isSignedIn {
                DetailActionButton(
                    systemImage: isFollowing ? "bell.fill" : "bell",
                    visualLabel: isFollowing ? "Unfollow" : "Follow",
                    accessibilityLabel: isFollowing ? "Unfollow" : "Follow"
                ) { Task { await toggleFollow() } }
            }

            DetailActionButton(
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                visualLabel: isSaved ? "Unsave" : "Save",
                accessibilityLabel: isSaved ? "Unsave" : "Save"
            ) { toggleSave() }

            if let url, let shareURL = URL(string: url) {
                ShareLink(item: shareURL, subject: Text(title)) {
                    DetailActionButtonLabel(systemImage: "square.and.arrow.up", visualLabel: "Share")
                }
                .accessibilityLabel("Share")

                DetailActionButton(systemImage: "safari", visualLabel: "Browser", accessibilityLabel: "Open in Browser") {
                    showBrowser = true
                }
                .sheet(isPresented: $showBrowser) {
                    SafariView(url: shareURL)
                }
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
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
        .accessibilityLabel(accessibilityLabel)
    }
}

struct DetailActionButtonLabel: View {
    let systemImage: String
    let visualLabel: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
            Text(visualLabel)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}
