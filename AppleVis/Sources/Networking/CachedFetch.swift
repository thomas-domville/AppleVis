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

    // A page known to be behind the website (you just commented on it, or
    // Home saw new comments) loads live once (2026-10-09).
    let forceRefresh = forceRefresh ? true : await OutdatedPages.shared.take(key)

    // forceRefresh skips straight to a live fetch even within the normal
    // "fresh" window — a deliberate pull-to-refresh is the user explicitly
    // asking "is there anything new," and silently replaying an
    // hours-old cached response would defeat that. Doesn't apply above:
    // if the circuit breaker's already down, there's no live fetch to force.
    // While the banner says the site isn't answering, go live again so it
    // clears as soon as the site is back, rather than lingering.
    if !forceRefresh, !NetworkStatusStore.shared.degradedGroups.contains(group),
       let cached = await ContentCache.shared.get(T.self, key: key), cached.freshness == .fresh {
        return cached.data
    }

    // A forced refresh skips the phone's HTTP cache too, or it could
    // still get a response from up to a minute before.
    func attempt() async throws -> T {
        forceRefresh
            ? try await HTTPCacheBypass.$isOn.withValue(true) { try await fetch() }
            : try await fetch()
    }

    do {
        let result: T
        do {
            result = try await attempt()
        } catch let error where isDroppedConnection(error) {
            // A request still running when the phone put the app to sleep
            // comes back as "connection lost" on return, even on good
            // Wi-Fi. One quick retry, rather than calling the site down.
            try await Task.sleep(for: .milliseconds(300))
            result = try await attempt()
        }
        ContentCache.shared.set(result, key: key)
        await ApiHealthMonitor.shared.markUp(group)
        NetworkStatusStore.shared.markHealthy(group)
        return result
    } catch {
        if case APIError.unauthorized = error { throw error }
        // A cancelled request (Home refreshing again, a screen closing) is
        // not the website failing. It used to mark the whole group down
        // and show "You're offline" on a good connection. Reported by a
        // tester (2026-10-08).
        if isCancellation(error) { throw error }
        // Content the app couldn't read is a bug in one response, not a
        // site outage: use the saved copy without the offline banner.
        if case APIError.decoding = error {
            if let cached = await ContentCache.shared.get(T.self, key: key), cached.freshness != .expired {
                return cached.data
            }
            throw error
        }
        // .notFound means the item is confirmed gone (removed, unpublished,
        // or moderated away) — not a network/availability problem. Falling
        // through to the cache fallback below would silently resurrect a
        // stale cached copy of exactly the content that was just deleted
        // (e.g. a moderated spam post), and markDown would wrongly trip the
        // whole content group's circuit breaker over one missing item.
        // Evict the stale entry instead so it can't zombie back later either.
        //
        // .forbidden gets the same treatment: Drupal's JSON:API returns 403,
        // not 404, when a node still exists but access has been withdrawn
        // (e.g. unpublished after this viewer already cached it) — from the
        // cache's point of view that's the identical "confirmed gone for
        // this viewer" signal, not a transient permission blip. A genuinely
        // transient 403 (stale role after a server-side permission change)
        // just means the next fetch re-populates the cache from scratch;
        // validateStatus already kicks off a role refresh in that case.
        if case APIError.notFound = error {
            ContentCache.shared.remove(key: key)
            throw error
        }
        if case APIError.forbidden = error {
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

/// The request was called off by the app, not refused by the website.
nonisolated func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError { return urlError.code == .cancelled }
    if case APIError.network(let underlying) = error { return isCancellation(underlying) }
    return false
}

/// The connection dropped mid-request, usually because the phone paused
/// the app while it was loading.
nonisolated func isDroppedConnection(_ error: Error) -> Bool {
    if case APIError.network(let underlying as URLError) = error { return underlying.code == .networkConnectionLost }
    return false
}
