import Foundation

/// Disk-backed TTL cache for list/detail API responses — the Swift
/// equivalent of the old RN app's src/services/contentCache.ts. Lets a
/// screen serve instantly from disk on a fresh cache hit (no network round
/// trip) and lets `fetchWithCache` (CachedFetch.swift) fall back to the
/// last-known-good response when a live fetch fails, instead of a hard
/// error with nothing to show.
final class ContentCache {
    static let shared = ContentCache()

    private nonisolated struct Entry<T: Codable & Sendable>: Codable, Sendable {
        let data: T
        let fetchedAt: Date
    }

    enum Freshness { case fresh, stale, expired }

    private let directory: URL
    private let queue = DispatchQueue(label: "com.applevis.contentCache", qos: .utility)

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("ContentCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sweepExpired()
    }

    /// `get(_:key:)` only ever inspects a key someone actively re-requests —
    /// an entry for content nobody revisits (an old forum topic, a since-
    /// deleted app listing) would otherwise sit on disk forever, since
    /// nothing previously deleted an `.expired` entry either on read or on
    /// any schedule. Runs once at launch on the background cache queue.
    private func sweepExpired() {
        queue.async {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.directory, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }
            let now = Date()
            for file in files {
                let key = file.lastPathComponent
                let expire = Self.ttl(for: key).expire
                guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      now.timeIntervalSince(modified) > expire
                else { continue }
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // Mirrors contentCache.ts's STALE_MS/EXPIRE_MS tables: more-specific
    // prefixes (":detail:") are checked before their generic parent.
    private static let staleSeconds: [(prefix: String, seconds: TimeInterval)] = [
        ("forums:detail:", 5 * 60),
        ("apps:detail:", 15 * 60),
        ("blogs:detail:", 10 * 60),
        ("resources:detail:", 10 * 60),
        ("bugs:detail:", 10 * 60),
        ("forums:", 30 * 60),
        ("podcasts:", 6 * 60 * 60),
        ("apps:", 6 * 60 * 60),
        ("resources:", 6 * 60 * 60),
        ("blogs:", 6 * 60 * 60),
        ("bugs:", 6 * 60 * 60),
    ]
    private static let expireSeconds: [(prefix: String, seconds: TimeInterval)] = [
        ("forums:detail:", 2 * 24 * 60 * 60),
        ("apps:detail:", 7 * 24 * 60 * 60),
        ("blogs:detail:", 7 * 24 * 60 * 60),
        ("resources:detail:", 7 * 24 * 60 * 60),
        ("bugs:detail:", 7 * 24 * 60 * 60),
        ("forums:", 7 * 24 * 60 * 60),
        ("podcasts:", 30 * 24 * 60 * 60),
        ("apps:", 30 * 24 * 60 * 60),
        ("resources:", 30 * 24 * 60 * 60),
        ("blogs:", 30 * 24 * 60 * 60),
        ("bugs:", 30 * 24 * 60 * 60),
    ]

    private static func ttl(for key: String) -> (stale: TimeInterval, expire: TimeInterval) {
        let stale = staleSeconds.first { key.hasPrefix($0.prefix) }?.seconds ?? 60 * 60
        let expire = expireSeconds.first { key.hasPrefix($0.prefix) }?.seconds ?? 7 * 24 * 60 * 60
        return (stale, expire)
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }

    /// Returns the cached value and how fresh it is, or `nil` if nothing is
    /// cached for `key`. Genuinely asynchronous (dispatches to the
    /// background cache queue via a continuation) rather than blocking the
    /// calling thread with `queue.sync` — this runs on every cached network
    /// fetch across the app (`fetchWithCache`), called from `@MainActor`
    /// view models, so a blocking call here risked stalling the caller's
    /// thread and, under concurrent fetches, starving the cooperative
    /// thread pool that queue.sync was contending with.
    func get<T: Codable & Sendable>(_ type: T.Type, key: String) async -> (data: T, freshness: Freshness)? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.getSync(type, key: key))
            }
        }
    }

    private func getSync<T: Codable & Sendable>(_ type: T.Type, key: String) -> (data: T, freshness: Freshness)? {
        guard let raw = try? Data(contentsOf: fileURL(for: key)),
              let entry = try? JSONDecoder().decode(Entry<T>.self, from: raw) else { return nil }
        let age = Date().timeIntervalSince(entry.fetchedAt)
        let (stale, expire) = Self.ttl(for: key)
        let freshness: Freshness = age > expire ? .expired : (age > stale ? .stale : .fresh)
        if freshness == .expired {
            try? FileManager.default.removeItem(at: fileURL(for: key))
        }
        return (entry.data, freshness)
    }

    func set<T: Codable & Sendable>(_ value: T, key: String) {
        let entry = Entry(data: value, fetchedAt: Date())
        queue.async {
            guard let raw = try? JSONEncoder().encode(entry) else { return }
            try? raw.write(to: self.fileURL(for: key), options: .atomic)
        }
    }

    /// Evicts a single cached entry outright — used when a live fetch
    /// confirms the underlying content is gone (APIError.notFound), so a
    /// deleted item can't keep serving from cache after that point.
    func remove(key: String) {
        queue.async {
            try? FileManager.default.removeItem(at: self.fileURL(for: key))
        }
    }

    /// Total on-disk size — surfaced by StorageView alongside the system
    /// URLCache so "Cached Content" actually reflects everything AppleVis
    /// caches, not just images/network responses.
    var totalSizeBytes: Int64 {
        queue.sync {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            return files.reduce(0) { total, url in
                total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
        }
    }

    /// Deletes every cached list/detail response — backs StorageView's
    /// "Clear Cached Content"/"Clear All Storage" actions.
    func clearAll() {
        queue.async {
            guard let files = try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: nil) else { return }
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
    }
}
