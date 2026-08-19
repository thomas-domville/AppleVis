import Foundation
import os

/// Local-only persistence for content the server has no concept of ("saved"
/// items are never sent to Drupal — see src/services/persistence.ts in the RN
/// reference client) plus a local cache of what this device has followed,
/// since there is no bulk "list my followed items" endpoint on the backend.
@MainActor
final class PersistenceStore {
    static let shared = PersistenceStore()

    private let savedKey = "applevis.saved.v1"
    private let followedKey = "applevis.followed.v1"
    private let notificationHistoryKey = "applevis.notificationHistory.v1"
    private let notificationHistoryLimit = 20
    private let defaults = UserDefaults.standard

    /// Every browse-list row (Forums/Podcasts/Apps/Resources/Blogs) calls
    /// through `savedItems()`/`followedItems()`/`allItemVisits()` on every
    /// render to compute its saved/following/new-reply state — without this,
    /// that meant a full JSON decode of the entire collection on every
    /// single row's body evaluation, on every scroll/re-render. Cached
    /// in-memory per key, filled on first read and kept in sync by
    /// `persist(_:key:)` itself.
    private var cache: [String: Any] = [:]

    private init() {}

    // MARK: - Saved items

    func savedItems() -> [SavedItem] {
        load(key: savedKey) ?? []
    }

    func isSaved(id: String) -> Bool {
        savedItems().contains { $0.id == id }
    }

    /// `sync` defaults to `true` for every normal caller (a user tapping
    /// Save). `ICloudSyncManager`'s pull passes `false` — it's adopting an
    /// item that just came FROM iCloud, so its shadow is already settled;
    /// pushing again immediately after would just be a same-data no-op
    /// round trip, multiplied by however many items a single pull adopts.
    func save(_ item: SavedItem, sync: Bool = true) {
        var items = savedItems()
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.insert(item, at: 0)
        persist(items, key: savedKey)
        if sync { Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() } }
    }

    func unsave(id: String, sync: Bool = true) {
        var items = savedItems()
        items.removeAll { $0.id == id }
        persist(items, key: savedKey)
        if sync { Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() } }
    }

    // MARK: - Notification history (on-device only — nothing server-side tracks this)

    func notificationHistory() -> [NotificationHistoryItem] {
        load(key: notificationHistoryKey) ?? []
    }

    func recordNotification(_ item: NotificationHistoryItem) {
        var items = notificationHistory()
        items.insert(item, at: 0)
        if items.count > notificationHistoryLimit {
            items.removeLast(items.count - notificationHistoryLimit)
        }
        persist(items, key: notificationHistoryKey)
    }

    // MARK: - Followed items (local cache; follow/unfollow itself is server-backed)

    func followedItems() -> [FollowedItem] {
        load(key: followedKey) ?? []
    }

    func isFollowed(id: String) -> Bool {
        followedItems().contains { $0.id == id }
    }

    func markFollowed(_ item: FollowedItem, sync: Bool = true) {
        var items = followedItems()
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.insert(item, at: 0)
        persist(items, key: followedKey)
        if sync { Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() } }
    }

    func markUnfollowed(id: String, sync: Bool = true) {
        var items = followedItems()
        items.removeAll { $0.id == id }
        persist(items, key: followedKey)
        if sync { Task { @MainActor in ICloudSyncManager.shared.pushSavedItems() } }
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

    /// Backs FORUM-14 ("remember forum list position by content ID, not
    /// only by scroll offset"): the id of the topic the user most recently
    /// opened from the Forums browse list, so returning to that list can
    /// scroll/focus back to it — tolerating that new activity may have
    /// reordered the list around it, since this is just an id lookup
    /// against whatever's currently loaded, not a fixed row index.
    var lastViewedForumTopicId: String? {
        get { defaults.string(forKey: "applevis.forums.lastViewedTopicId") }
        set { defaults.set(newValue, forKey: "applevis.forums.lastViewedTopicId") }
    }

    // MARK: - Played episodes

    private let playedEpisodesKey = "applevis.podcast.playedEpisodeIds"

    /// General-purpose "played" state for any episode, downloaded or not.
    /// `DownloadManager.markPlayCompleted(_:)` is a separate, narrower
    /// mechanism scoped only to downloaded episodes (it drives Auto-Delete
    /// and is a no-op with nothing downloaded) — What's New already
    /// advertised a user-facing "Mark as Played" action, but no general
    /// mechanism usable on any episode actually existed anywhere.
    func isEpisodePlayed(_ id: String) -> Bool {
        playedEpisodeIds().contains(id)
    }

    func markEpisodePlayed(_ id: String) {
        var ids = playedEpisodeIds()
        guard ids.insert(id).inserted else { return }
        defaults.set(Array(ids), forKey: playedEpisodesKey)
    }

    private func playedEpisodeIds() -> Set<String> {
        Set(defaults.stringArray(forKey: playedEpisodesKey) ?? [])
    }

    // MARK: - Per-item visit tracking (backs Home's "Mark as Read" and new-reply detection)

    private let itemVisitsKey = "applevis.home.itemVisits"

    /// When an item was last opened, and how many comments/replies it had at
    /// that moment — lets Home detect not just "brand new items since last
    /// visit" but "new replies on something you'd already seen before," and
    /// lets a single item be marked read without waiting for the global
    /// last-visit timestamp to advance.
    struct ItemVisit: Codable {
        let seenAt: Date
        let commentCount: Int
    }

    func allItemVisits() -> [String: ItemVisit] {
        load(key: itemVisitsKey) ?? [:]
    }

    func stampItemVisit(id: String, commentCount: Int) {
        var visits = allItemVisits()
        visits[id] = ItemVisit(seenAt: Date(), commentCount: commentCount)
        persist(visits, key: itemVisitsKey)
    }

    /// New replies/comments since this item was last visited — same
    /// calculation Home uses, exposed here so browse-list rows (Forums,
    /// Guides, Apps, Blogs, Podcasts, Bug Reports) can show the same
    /// per-item "N new" signal Home already has, instead of only Home
    /// knowing about it.
    func newReplyCount(kind: ContentKind, id: String, currentCount: Int) -> Int {
        guard let visit = allItemVisits()[FeedItem.visitKey(kind: kind, contentId: id)] else { return 0 }
        return max(0, currentCount - visit.commentCount)
    }

    /// Backs Settings > Privacy > "Clear All Local Data" — previously that
    /// action only cleared the URL cache, doing nothing to any of this,
    /// despite its own confirmation dialog explicitly promising it would.
    func clearAllLocalData() {
        defaults.removeObject(forKey: savedKey)
        defaults.removeObject(forKey: followedKey)
        defaults.removeObject(forKey: notificationHistoryKey)
        defaults.removeObject(forKey: seenTopicsKey)
        defaults.removeObject(forKey: itemVisitsKey)
        defaults.removeObject(forKey: episodeAudioMetadataKey)
        defaults.removeObject(forKey: "applevis.forums.lastVisit")
        defaults.removeObject(forKey: "applevis.lastVisit")
        cache.removeAll()
    }

    // MARK: - Probed episode audio metadata (duration/chapters read directly
    // from the audio file, since Drupal doesn't provide either — the API's
    // `duration` field is hardcoded to 0 server-side, and `field_chapters`
    // is only ever populated for episodes the host bothered to chapter-mark
    // in the CMS. `PodcastAudioMetadataProbe` reads both client-side;
    // cached here so a given episode is only ever probed once.

    private let episodeAudioMetadataKey = "applevis.podcast.audioMetadata.v1"

    struct EpisodeAudioMetadata: Codable {
        var duration: TimeInterval?
        var chapters: [Chapter]
    }

    func cachedAudioMetadata(episodeId: String) -> EpisodeAudioMetadata? {
        audioMetadataCache()[episodeId]
    }

    func cacheProbedDuration(episodeId: String, duration: TimeInterval) {
        var all = audioMetadataCache()
        var entry = all[episodeId] ?? EpisodeAudioMetadata(duration: nil, chapters: [])
        entry.duration = duration
        all[episodeId] = entry
        persist(all, key: episodeAudioMetadataKey)
    }

    func cacheProbedChapters(episodeId: String, chapters: [Chapter]) {
        var all = audioMetadataCache()
        var entry = all[episodeId] ?? EpisodeAudioMetadata(duration: nil, chapters: [])
        entry.chapters = chapters
        all[episodeId] = entry
        persist(all, key: episodeAudioMetadataKey)
    }

    private func audioMetadataCache() -> [String: EpisodeAudioMetadata] {
        load(key: episodeAudioMetadataKey) ?? [:]
    }

    // MARK: - Storage

    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
            cache[key] = value
        } catch {
            AppLog.persistence.error("Failed to encode \(key, privacy: .public): \(error, privacy: .private)")
        }
    }

    private func load<T: Decodable>(key: String) -> T? {
        if let cached = cache[key] as? T { return cached }
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: data)
        } catch {
            AppLog.persistence.error("Failed to decode \(key, privacy: .public): \(error, privacy: .private)")
            return nil
        }
        cache[key] = decoded
        return decoded
    }
}
