import Foundation

/// Mirrors the old RN app's `cachedApi.fetchWithCache` (src/services/cachedApi.ts):
/// skip the network when the content group's circuit breaker is down and
/// serve cache instead; return a still-fresh cache hit instantly with no
/// network round trip; and on a live failure, fall back to the last cached
/// response (as long as it isn't expired) rather than a hard error. Every
/// list/detail endpoint that benefits from this — one per content group —
/// wraps its existing network call with this instead of changing its
/// return type, so call sites elsewhere in the app are unaffected.
func fetchWithCache<T: Codable>(
    group: ContentGroup,
    key: String,
    fetch: () async throws -> T
) async throws -> T {
    if await !ApiHealthMonitor.shared.isAvailable(group) {
        if let cached = ContentCache.shared.get(T.self, key: key) {
            NetworkStatusStore.shared.markDegraded(group)
            return cached.data
        }
        throw APIError.offlineNoCache(group: group.rawValue)
    }

    if let cached = ContentCache.shared.get(T.self, key: key), cached.freshness == .fresh {
        return cached.data
    }

    do {
        let result = try await fetch()
        ContentCache.shared.set(result, key: key)
        await ApiHealthMonitor.shared.markUp(group)
        NetworkStatusStore.shared.markHealthy(group)
        return result
    } catch {
        if case APIError.unauthorized = error { throw error }
        await ApiHealthMonitor.shared.markDown(group)
        if let cached = ContentCache.shared.get(T.self, key: key), cached.freshness != .expired {
            NetworkStatusStore.shared.markDegraded(group)
            return cached.data
        }
        throw error
    }
}
