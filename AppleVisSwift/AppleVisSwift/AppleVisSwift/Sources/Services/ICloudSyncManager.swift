import Foundation

/// Syncs a curated set of user data across devices via iCloud Key-Value
/// storage, gated by the granular toggles in Settings → Saved & Sync.
///
/// Requires the "iCloud" capability (Key-value storage) to be added to this
/// target in Xcode's Signing & Capabilities tab. Without it, `NSUbiquitousKeyValueStore`
/// calls are harmless no-ops — nothing crashes, it just won't sync.
///
/// Note: `readingPositionSync` has no corresponding local feature to sync —
/// this app has no "reading position" concept for articles/guides — so it's
/// intentionally left unwired here rather than faked.
@MainActor
final class ICloudSyncManager {
    static let shared = ICloudSyncManager()

    /// Set once at launch by `AppleVisApp` so pulled queue/position data has
    /// somewhere to land — this manager doesn't own a `PlayerStore` itself.
    weak var player: PlayerStore?

    private let store = NSUbiquitousKeyValueStore.default

    /// Preference keys mirrored via Settings Sync. Not exhaustive — covers
    /// the settings most worth carrying across devices.
    private static let syncedSettingsKeys = [
        "theme", "appearance.cardDensity", "podcast.speed",
        "podcast.skipBack", "podcast.skipForward", "podcast.autoPlay",
    ]

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store
        )
        store.synchronize()
    }

    private func isSyncEnabled(_ subToggleKey: String) -> Bool {
        (UserDefaults.standard.object(forKey: "sync.iCloud") as? Bool ?? true) &&
        (UserDefaults.standard.object(forKey: subToggleKey) as? Bool ?? true)
    }

    // MARK: - Push (call after a local write)

    func pushSavedItems() {
        guard isSyncEnabled("sync.savedItems") else { return }
        setJSON(PersistenceStore.shared.savedItems(), key: "icloud.saved")
        setJSON(PersistenceStore.shared.followedItems(), key: "icloud.followed")
        store.synchronize()
    }

    func pushPodcastPositions(_ positions: [String: TimeInterval]) {
        guard isSyncEnabled("sync.podcastPosition") else { return }
        setJSON(positions, key: "icloud.podcastPositions")
        store.synchronize()
    }

    func pushQueue(_ queue: [PodcastEpisode]) {
        guard isSyncEnabled("sync.queue") else { return }
        setJSON(queue, key: "icloud.queue")
        store.synchronize()
    }

    func pushSettings() {
        guard isSyncEnabled("sync.settings") else { return }
        var snapshot: [String: AnyCodableSettingValue] = [:]
        for key in Self.syncedSettingsKeys {
            if let s = UserDefaults.standard.string(forKey: key) { snapshot[key] = .string(s) }
            else if UserDefaults.standard.object(forKey: key) is Bool { snapshot[key] = .bool(UserDefaults.standard.bool(forKey: key)) }
            else if UserDefaults.standard.object(forKey: key) != nil { snapshot[key] = .double(UserDefaults.standard.double(forKey: key)) }
        }
        setJSON(snapshot, key: "icloud.settings")
        store.synchronize()
    }

    // MARK: - Pull

    /// Call once at launch (after setting `player`) to adopt anything synced
    /// from another device.
    func pullAll() {
        pullSavedItems()
        if let player {
            pullPodcastPositions { player.applyPulledPositions($0) }
            pullQueue { player.applyPulledQueue($0) }
        }
        pullSettings()
    }

    private func pullSavedItems() {
        guard isSyncEnabled("sync.savedItems") else { return }
        if let saved: [SavedItem] = getJSON(key: "icloud.saved") {
            PersistenceStore.shared.replaceSavedItems(saved)
        }
        if let followed: [FollowedItem] = getJSON(key: "icloud.followed") {
            PersistenceStore.shared.replaceFollowedItems(followed)
        }
    }

    private func pullPodcastPositions(_ apply: ([String: TimeInterval]) -> Void) {
        guard isSyncEnabled("sync.podcastPosition") else { return }
        if let positions: [String: TimeInterval] = getJSON(key: "icloud.podcastPositions") {
            apply(positions)
        }
    }

    private func pullQueue(_ apply: ([PodcastEpisode]) -> Void) {
        guard isSyncEnabled("sync.queue") else { return }
        if let queue: [PodcastEpisode] = getJSON(key: "icloud.queue") {
            apply(queue)
        }
    }

    private func pullSettings() {
        guard isSyncEnabled("sync.settings") else { return }
        guard let snapshot: [String: AnyCodableSettingValue] = getJSON(key: "icloud.settings") else { return }
        for (key, value) in snapshot {
            switch value {
            case .string(let s): UserDefaults.standard.set(s, forKey: key)
            case .bool(let b):   UserDefaults.standard.set(b, forKey: key)
            case .double(let d): UserDefaults.standard.set(d, forKey: key)
            }
        }
    }

    @objc private func handleExternalChange(_ note: Notification) {
        Task { @MainActor in
            pullAll()
            SoundPlayer.shared.play(.syncComplete)
        }
    }

    // MARK: - Storage helpers

    private func setJSON<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: key)
    }

    private func getJSON<T: Decodable>(key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private enum AnyCodableSettingValue: Codable {
    case string(String), bool(Bool), double(Double)
}
