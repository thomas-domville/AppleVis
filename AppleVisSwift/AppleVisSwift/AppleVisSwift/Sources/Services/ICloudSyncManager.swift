import Foundation
import os

/// Syncs a curated set of user data across devices via iCloud Key-Value
/// storage, gated by the granular toggles in Settings → Saved & Sync.
///
/// Requires the "iCloud" capability (Key-value storage) to be added to this
/// target in Xcode's Signing & Capabilities tab. Without it, `NSUbiquitousKeyValueStore`
/// calls are harmless no-ops — nothing crashes, it just won't sync.
///
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

    /// Previously a full-blob overwrite exactly like the settings bug fixed
    /// elsewhere in this file: pushed this device's entire saved/followed
    /// list every time, discarding anything another device had added to
    /// the cloud copy since this device's last pull. Same per-id "shadow"
    /// merge strategy as `pushSettings`/`pullSettings`, applied to sets of
    /// ids instead of scalar values.
    func pushSavedItems() {
        if isSyncEnabled("sync.savedItems") {
            let local = PersistenceStore.shared.savedItems()
            let shadow = readIdShadow(key: "icloud.saved.shadow")
            let cloud: [SavedItem] = getJSON(key: "icloud.saved") ?? []
            let locallyRemoved = shadow.subtracting(Set(local.map(\.id)))
            var merged = cloud.filter { !locallyRemoved.contains($0.id) }
            let mergedIds = Set(merged.map(\.id))
            merged += local.filter { !mergedIds.contains($0.id) }
            setJSON(merged, key: "icloud.saved")
            writeIdShadow(Set(merged.map(\.id)), key: "icloud.saved.shadow")
        }
        if isSyncEnabled("sync.followedItems") {
            let local = PersistenceStore.shared.followedItems()
            let shadow = readIdShadow(key: "icloud.followed.shadow")
            let cloud: [FollowedItem] = getJSON(key: "icloud.followed") ?? []
            let locallyRemoved = shadow.subtracting(Set(local.map(\.id)))
            var merged = cloud.filter { !locallyRemoved.contains($0.id) }
            let mergedIds = Set(merged.map(\.id))
            merged += local.filter { !mergedIds.contains($0.id) }
            setJSON(merged, key: "icloud.followed")
            writeIdShadow(Set(merged.map(\.id)), key: "icloud.followed.shadow")
        }
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

    /// Pushing always sent every synced setting as one blob, even keys this
    /// device never touched, using whatever possibly-stale local copy it
    /// happened to have. Two actively-used signed-in devices could silently
    /// stomp each other: Device A backgrounds (pushing its stale copy of a
    /// key Device B more recently changed) after Device B's push, and
    /// Device B loses that change the next time it pulls. Per-key "shadow"
    /// values (the last value this device knows to already be in sync) let
    /// push only overwrite the keys THIS device actually changed, merging
    /// everything else in from whatever's already in the cloud.
    func pushSettings() {
        guard isSyncEnabled("sync.settings") else { return }
        let shadow = readShadow()
        let cloud: [String: AnyCodableSettingValue] = getJSON(key: "icloud.settings") ?? [:]
        var merged = cloud
        var newShadow = shadow
        for key in Self.syncedSettingsKeys {
            guard let local = currentValue(for: key) else { continue }
            if shadow[key] != local {
                // Changed locally since this device last synced — this
                // device's copy wins for this key.
                merged[key] = local
                newShadow[key] = local
            } else if merged[key] == nil {
                // Never synced before and untouched locally — seed it.
                merged[key] = local
                newShadow[key] = local
            }
            // Otherwise unchanged locally: leave whatever's already in
            // `merged` (the cloud's copy, possibly newer from another
            // device) alone.
        }
        setJSON(merged, key: "icloud.settings")
        writeShadow(newShadow)
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

    /// Adopts cloud additions unconditionally (never a data-loss risk), but
    /// only removes a local item if this device hasn't independently
    /// touched it since the last sync checkpoint — i.e. it's exactly where
    /// the shadow last left it, so no local, not-yet-pushed change is at
    /// risk of being silently clobbered by a remote removal.
    private func pullSavedItems() {
        if isSyncEnabled("sync.savedItems"), let cloud: [SavedItem] = getJSON(key: "icloud.saved") {
            let shadow = readIdShadow(key: "icloud.saved.shadow")
            let cloudIds = Set(cloud.map(\.id))
            let localIds = Set(PersistenceStore.shared.savedItems().map(\.id))
            for item in cloud where !localIds.contains(item.id) {
                PersistenceStore.shared.save(item)
            }
            for id in shadow.intersection(localIds).subtracting(cloudIds) {
                PersistenceStore.shared.unsave(id: id)
            }
            writeIdShadow(Set(PersistenceStore.shared.savedItems().map(\.id)), key: "icloud.saved.shadow")
        }
        if isSyncEnabled("sync.followedItems"), let cloud: [FollowedItem] = getJSON(key: "icloud.followed") {
            let shadow = readIdShadow(key: "icloud.followed.shadow")
            let cloudIds = Set(cloud.map(\.id))
            let localIds = Set(PersistenceStore.shared.followedItems().map(\.id))
            for item in cloud where !localIds.contains(item.id) {
                PersistenceStore.shared.markFollowed(item)
            }
            for id in shadow.intersection(localIds).subtracting(cloudIds) {
                PersistenceStore.shared.markUnfollowed(id: id)
            }
            writeIdShadow(Set(PersistenceStore.shared.followedItems().map(\.id)), key: "icloud.followed.shadow")
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

    /// Only accepts a cloud value for a key this device hasn't itself
    /// changed since its last successful sync (per the `shadow` — if the
    /// local value still matches the shadow, nothing local is at risk).
    /// A key this device has locally dirtied but not yet pushed is left
    /// alone rather than clobbered by an older or unrelated remote copy.
    private func pullSettings() {
        guard isSyncEnabled("sync.settings") else { return }
        guard let snapshot: [String: AnyCodableSettingValue] = getJSON(key: "icloud.settings") else { return }
        var shadow = readShadow()
        for key in Self.syncedSettingsKeys {
            guard let cloudValue = snapshot[key] else { continue }
            let local = currentValue(for: key)
            guard local == shadow[key] else { continue } // locally dirty, don't clobber
            guard cloudValue != local else { continue }
            switch cloudValue {
            case .string(let s): UserDefaults.standard.set(s, forKey: key)
            case .bool(let b):   UserDefaults.standard.set(b, forKey: key)
            case .double(let d): UserDefaults.standard.set(d, forKey: key)
            }
            shadow[key] = cloudValue
        }
        writeShadow(shadow)
    }

    @objc private func handleExternalChange(_ note: Notification) {
        Task { @MainActor in
            pullAll()
            SoundPlayer.shared.play(.syncComplete)
        }
    }

    // MARK: - Settings merge helpers

    private func currentValue(for key: String) -> AnyCodableSettingValue? {
        if let s = UserDefaults.standard.string(forKey: key) { return .string(s) }
        if UserDefaults.standard.object(forKey: key) is Bool { return .bool(UserDefaults.standard.bool(forKey: key)) }
        if UserDefaults.standard.object(forKey: key) != nil { return .double(UserDefaults.standard.double(forKey: key)) }
        return nil
    }

    /// Local-only (never pushed to `store`) record of the last value this
    /// device knows to already be in sync for each key, keyed the same as
    /// `syncedSettingsKeys`.
    private func readShadow() -> [String: AnyCodableSettingValue] {
        guard let data = UserDefaults.standard.data(forKey: "icloud.settings.shadow") else { return [:] }
        return (try? JSONDecoder().decode([String: AnyCodableSettingValue].self, from: data)) ?? [:]
    }

    private func writeShadow(_ shadow: [String: AnyCodableSettingValue]) {
        guard let data = try? JSONEncoder().encode(shadow) else { return }
        UserDefaults.standard.set(data, forKey: "icloud.settings.shadow")
    }

    /// Same local-only "last known in sync" checkpoint concept as the
    /// settings shadow above, but for a set of item ids (Saved/Followed).
    private func readIdShadow(key: String) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    private func writeIdShadow(_ ids: Set<String>, key: String) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Storage helpers

    private func setJSON<T: Encodable>(_ value: T, key: String) {
        do {
            store.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            AppLog.sync.error("Failed to encode \(key, privacy: .public) for iCloud push: \(error, privacy: .public)")
        }
    }

    private func getJSON<T: Decodable>(key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            AppLog.sync.error("Failed to decode \(key, privacy: .public) from iCloud: \(error, privacy: .public)")
            return nil
        }
    }
}

private enum AnyCodableSettingValue: Codable, Equatable {
    case string(String), bool(Bool), double(Double)
}
