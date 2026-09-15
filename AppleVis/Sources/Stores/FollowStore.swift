import Combine
import Foundation

/// Server-backed cache of which items the signed-in user follows, mirroring
/// `RecommendationStore`'s exact shape. Follow itself already synced
/// correctly at the For You > Following list level (`FlagEndpoints
/// .followedItems` is a real server query, not `PersistenceStore`) — but
/// every per-item Follow/Unfollow button and row badge (detail screens,
/// context menus, Home's forum topic cards) only ever checked
/// `PersistenceStore`, which just as `RecommendationStore`'s doc comment
/// says of Saved, only knows about follows made inside this app. Something
/// followed on the website — or a different device — showed a plain
/// "Follow" button here even though it was already listed correctly in
/// Following. This closes that gap the same way Recommend's button state
/// already worked. Requested directly.
@MainActor
final class FollowStore: ObservableObject {
    static let shared = FollowStore()

    @Published private(set) var followedIds: Set<String> = []
    private var hasLoaded = false

    private init() {}

    func isFollowed(_ id: String) -> Bool {
        followedIds.contains(id)
    }

    /// Cheap no-op after the first successful load this session — call
    /// freely from any row/screen that needs follow state without worrying
    /// about redundant network calls.
    func loadIfNeeded(for user: AuthUser) async {
        guard !hasLoaded else { return }
        await reload(for: user)
    }

    /// Real refetch — call from Following's own pull-to-refresh, or anywhere
    /// state might have drifted (e.g. followed from the website or a second
    /// signed-in device).
    func reload(for user: AuthUser) async {
        guard let items = try? await APIClient.shared.flags.followedItems(uid: user.uuid, csrfToken: user.csrfToken) else { return }
        followedIds = Set(items.map(\.id))
        hasLoaded = true
    }

    func markFollowed(_ id: String) {
        followedIds.insert(id)
    }

    func markNotFollowed(_ id: String) {
        followedIds.remove(id)
    }

    /// Called on sign-out — otherwise the next person to sign in on a
    /// shared device would inherit the previous person's follow badges
    /// until their own list happened to load over it.
    func reset() {
        followedIds = []
        hasLoaded = false
    }
}
