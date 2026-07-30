import Foundation

/// Local-only persistence for content the server has no concept of ("saved"
/// items are never sent to Drupal — see src/services/persistence.ts in the RN
/// reference client) plus a local cache of what this device has followed,
/// since there is no bulk "list my followed items" endpoint on the backend.
final class PersistenceStore {
    static let shared = PersistenceStore()

    private let savedKey = "applevis.saved.v1"
    private let followedKey = "applevis.followed.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Saved items

    func savedItems() -> [SavedItem] {
        load(key: savedKey) ?? []
    }

    func isSaved(id: String) -> Bool {
        savedItems().contains { $0.id == id }
    }

    func save(_ item: SavedItem) {
        var items = savedItems()
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.insert(item, at: 0)
        persist(items, key: savedKey)
        Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() }
    }

    func unsave(id: String) {
        var items = savedItems()
        items.removeAll { $0.id == id }
        persist(items, key: savedKey)
        Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() }
    }

    /// Overwrites the local saved list — used when adopting an iCloud sync.
    func replaceSavedItems(_ items: [SavedItem]) {
        persist(items, key: savedKey)
    }

    // MARK: - Followed items (local cache; follow/unfollow itself is server-backed)

    func followedItems() -> [FollowedItem] {
        load(key: followedKey) ?? []
    }

    func isFollowed(id: String) -> Bool {
        followedItems().contains { $0.id == id }
    }

    func markFollowed(_ item: FollowedItem) {
        var items = followedItems()
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.insert(item, at: 0)
        persist(items, key: followedKey)
        Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() }
    }

    func markUnfollowed(id: String) {
        var items = followedItems()
        items.removeAll { $0.id == id }
        persist(items, key: followedKey)
        Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() }
    }

    /// Overwrites the local followed list — used when adopting an iCloud sync.
    func replaceFollowedItems(_ items: [FollowedItem]) {
        persist(items, key: followedKey)
    }

    // MARK: - Seen forum topics (backs the "Unread" forums filter)

    private let seenTopicsKey = "applevis.forums.seenTopics"

    func isTopicSeen(id: String) -> Bool {
        seenTopicIds().contains(id)
    }

    func markTopicSeen(id: String) {
        var ids = seenTopicIds()
        guard ids.insert(id).inserted else { return }
        persist(Array(ids), key: seenTopicsKey)
    }

    private func seenTopicIds() -> Set<String> {
        Set(load(key: seenTopicsKey) ?? [])
    }

    // MARK: - Forums last-visit (backs the New / Since Last Visit forums filters)

    var forumsLastVisit: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: "applevis.forums.lastVisit"))
    }

    func markForumsVisited() {
        defaults.set(Date().timeIntervalSince1970, forKey: "applevis.forums.lastVisit")
    }

    // MARK: - Storage

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func load<T: Decodable>(key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
