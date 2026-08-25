import Foundation

/// Mirrors the old RN app's `cachedApi.fetchWithCache` (src/services/cachedApi.ts):
/// skip the network when the content group's circuit breaker is down and
/// serve cache instead; return a still-fresh cache hit instantly with no
/// network round trip; and on a live failure, fall back to the last cached
/// response (as long as it isn't expired) rather than a hard error. Every
/// list/detail endpoint that benefits from this — one per content group —
/// wraps its existing network call with this instead of changing its
/// return type, so call sites elsewhere in the app are unaffected.
func fetchWithCache<T: Codable & Sendable>(
    group: ContentGroup,
    key: String,
    forceRefresh: Bool = false,
    fetch: @MainActor () async throws -> T
) async throws -> T {
    if await !ApiHealthMonitor.shared.isAvailable(group) {
        if let cached = await ContentCache.shared.get(T.self, key: key) {
            NetworkStatusStore.shared.markDegraded(group)
            return cached.data
        }
        throw APIError.offlineNoCache(group: group.rawValue)
    }

    // forceRefresh skips straight to a live fetch even within the normal
    // "fresh" window — a deliberate pull-to-refresh is the user explicitly
    // asking "is there anything new," and silently replaying an
    // hours-old cached response would defeat that. Doesn't apply above:
    // if the circuit breaker's already down, there's no live fetch to force.
    if !forceRefresh, let cached = await ContentCache.shared.get(T.self, key: key), cached.freshness == .fresh {
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
        // .notFound means the item is confirmed gone (removed, unpublished,
        // or moderated away) — not a network/availability problem. Falling
        // through to the cache fallback below would silently resurrect a
        // stale cached copy of exactly the content that was just deleted
        // (e.g. a moderated spam post), and markDown would wrongly trip the
        // whole content group's circuit breaker over one missing item.
        // Evict the stale entry instead so it can't zombie back later either.
        if case APIError.notFound = error {
            ContentCache.shared.remove(key: key)
            throw error
        }
        await ApiHealthMonitor.shared.markDown(group)
        if let cached = await ContentCache.shared.get(T.self, key: key), cached.freshness != .expired {
            NetworkStatusStore.shared.markDegraded(group)
            return cached.data
        }
        throw error
    }
}
