import Combine
import Foundation

/// Client-side cache of which apps the signed-in user has recommended.
/// Recommend is server-backed (see `FlagEndpoints`), unlike Saved/Followed
/// which live entirely in `PersistenceStore` — so a card's badge and the
/// detail page's button both read from here instead of each doing their own
/// per-row network check. Loaded once per sign-in session, then kept in
/// sync locally as recommend/unrecommend actions happen anywhere in the
/// app, so nothing ever disagrees mid-session.
@MainActor
final class RecommendationStore: ObservableObject {
    static let shared = RecommendationStore()

    @Published private(set) var recommendedAppIds: Set<String> = []
    private var hasLoaded = false

    private init() {}

    func isRecommended(_ appId: String) -> Bool {
        recommendedAppIds.contains(appId)
    }

    /// Cheap no-op after the first successful load this session — call
    /// freely from any row/screen that needs recommend state without
    /// worrying about redundant network calls.
    func loadIfNeeded(for user: AuthUser) async {
        guard !hasLoaded else { return }
        await reload(for: user)
    }

    /// Real refetch — call from the Recommended tab's pull-to-refresh, or
    /// anywhere state might have drifted (e.g. recommended from a second
    /// signed-in device).
    func reload(for user: AuthUser) async {
        guard let apps = try? await APIClient.shared.flags.recommendedApps(uid: user.uuid, csrfToken: user.csrfToken) else { return }
        recommendedAppIds = Set(apps.map(\.id))
        hasLoaded = true
    }

    func markRecommended(_ appId: String) {
        recommendedAppIds.insert(appId)
    }

    func markNotRecommended(_ appId: String) {
        recommendedAppIds.remove(appId)
    }

    /// Called on sign-out — otherwise the next person to sign in on a
    /// shared device would inherit the previous person's recommendation
    /// badges until their own list happened to load over it.
    func reset() {
        recommendedAppIds = []
        hasLoaded = false
    }
}
