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

    /// Whether "New" indicators (Home's What's New card, the New/Recap
    /// picker, and per-row "N new" badges everywhere) should actually be
    /// shown — not whether read/visit history gets *tracked*, which now
    /// always happens unconditionally regardless of sign-in state (see the
    /// functions below). Previously this same preference gated both at
    /// once: turning off "remember signed-out history" silently broke All/
    /// New/Recap for anyone who opted out, since without tracking there was
    /// nothing to compute "new" from. Splitting the two means someone who
    /// finds new-activity indicators distracting can turn just those off —
    /// the display, not the underlying (harmless, on-device-only, never
    /// transmitted while signed out) tracking a feature they might still
    /// want later depends on. Requested directly. Same key as before
    /// (`privacy.signedOutHistory`) so an existing "off" choice carries
    /// forward as "hide indicators" rather than resetting silently; applies
    /// to signed-in users too now, since wanting a quieter Home isn't
    /// specific to being signed out.
    var showsNewActivityIndicators: Bool {
        UserDefaults.standard.object(forKey: "privacy.signedOutHistory") as? Bool ?? true
    }

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
        Task { @MainActor in ICloudSyncManager.shared.pushReadHistory() }
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
        Task { @MainActor in ICloudSyncManager.shared.pushReadHistory() }
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

    /// Posted whenever an episode's Listened state changes (here, from
    /// playback finishing, or from iCloud) so episode rows can update their
    /// Listened checkmark without being reloaded.
    static let playedEpisodesDidChange = Notification.Name("applevis.playedEpisodesDidChange")

    /// One timestamped change per episode, so iCloud can tell "turned off"
    /// apart from "never synced": the old plain list was merged by union,
    /// so an episode turned back off on one device was re-added by the next
    /// sync from any other. The newest change for an episode wins.
    struct PlayedChange: Codable {
        let played: Bool
        let at: Date
    }

    private let playedChangesKey = "applevis.podcast.playedEpisodeChanges"

    func markEpisodePlayed(_ id: String) {
        setEpisodePlayed(id, played: true)
    }

    /// Previously marking an episode listened was a one-way door — the
    /// Episode Tools grid switched to a plain, non-interactive "Played"
    /// label with no way back, whether you tapped it by mistake or it
    /// arrived via iCloud sync from another device. Requested directly.
    func unmarkEpisodePlayed(_ id: String) {
        setEpisodePlayed(id, played: false)
    }

    private func setEpisodePlayed(_ id: String, played: Bool) {
        var changes = playedChanges()
        guard (changes[id]?.played ?? false) != played else { return }
        changes[id] = PlayedChange(played: played, at: Date())
        savePlayedChanges(changes)
        Task { @MainActor in ICloudSyncManager.shared.pushPlayedEpisodes() }
    }

    private func playedEpisodeIds() -> Set<String> {
        Set(playedChanges().filter(\.value.played).keys)
    }

    /// Falls back to the old plain list (pre-2026.17), treating each entry
    /// as marked long ago so any real change made since wins over it.
    func playedChanges() -> [String: PlayedChange] {
        if let data = defaults.data(forKey: playedChangesKey),
           let changes = try? JSONDecoder().decode([String: PlayedChange].self, from: data) {
            return changes
        }
        let legacy = defaults.stringArray(forKey: playedEpisodesKey) ?? []
        return Dictionary(legacy.map { ($0, PlayedChange(played: true, at: .distantPast)) }, uniquingKeysWith: { first, _ in first })
    }

    private func savePlayedChanges(_ changes: [String: PlayedChange]) {
        if let data = try? JSONEncoder().encode(changes) {
            defaults.set(data, forKey: playedChangesKey)
        }
        // Kept current for older builds reading the same defaults.
        defaults.set(changes.filter(\.value.played).map(\.key), forKey: playedEpisodesKey)
        NotificationCenter.default.post(name: Self.playedEpisodesDidChange, object: nil)
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

    func stampItemVisit(id: String, commentCount: Int, seenAt: Date = Date()) {
        var visits = allItemVisits()
        visits[id] = ItemVisit(seenAt: seenAt, commentCount: commentCount)
        persist(visits, key: itemVisitsKey)
        Task { @MainActor in ICloudSyncManager.shared.pushReadHistory() }
    }

    // MARK: - Feed baselines
    //
    // The comment count an item had when it first showed up in a feed,
    // for items never individually opened — so every row can show a real
    // "N new" count, not just the ones someone happened to open once.
    // Before this, a never-opened item had no count to diff against and
    // fell back to a single time comparison against Home's visit boundary,
    // which moves forward on every app launch — so any activity before the
    // most recent launch silently stopped counting as new, even if Home was
    // never actually looked at (e.g. launching straight into Profile).
    // Rows side by side disagreed for no visible reason: opened-once topics
    // showed "8 NEW," never-opened ones with fresh comments showed nothing.
    // Reported directly.
    //
    // Deliberately separate from `itemVisits`: a baseline isn't a read —
    // it never feeds "last visited," read-history sync, or Mark as Read,
    // and an item's visit (once it has one) always takes precedence.

    struct FeedBaseline: Codable {
        let firstSeenAt: Date
        let commentCount: Int
        /// Created since the visit boundary when first seen — shows the
        /// "NEW" badge (alongside any comment count) until opened or
        /// marked read, rather than only until the boundary next moves.
        let isNewItem: Bool
    }

    private let feedBaselinesKey = "applevis.home.feedBaselines.v1"
    /// Entries this old are dropped on write — anything not opened in two
    /// months has long since scrolled out of every feed anyway.
    private let feedBaselineMaxAge: TimeInterval = 60 * 24 * 60 * 60
    /// Read on every row render (via `newReplyCount`), so kept in memory
    /// rather than re-decoded from UserDefaults each time.
    private var cachedFeedBaselines: [String: FeedBaseline]?

    func allFeedBaselines() -> [String: FeedBaseline] {
        if let cachedFeedBaselines { return cachedFeedBaselines }
        let loaded: [String: FeedBaseline] = load(key: feedBaselinesKey) ?? [:]
        cachedFeedBaselines = loaded
        return loaded
    }

    /// Adds baselines only for keys that don't have one yet — a baseline
    /// is set once, at first sight, and never moved forward, which is what
    /// lets an unopened item's count keep building until it's cleared.
    func addFeedBaselines(_ new: [String: FeedBaseline]) {
        guard !new.isEmpty else { return }
        let cutoff = Date().addingTimeInterval(-feedBaselineMaxAge)
        var merged = allFeedBaselines().filter { $0.value.firstSeenAt > cutoff }
        for (key, baseline) in new where merged[key] == nil {
            merged[key] = baseline
        }
        cachedFeedBaselines = merged
        persist(merged, key: feedBaselinesKey)
    }

    struct ReadHistorySnapshot: Codable {
        var seenTopicIds: [String]
        var itemVisits: [String: ItemVisit]
        var forumsLastVisit: Date?
        var homeFirstVisit: Date?
        /// Mirrors HomeViewModel's `visitBoundaryKey` ("applevis.home.visitBoundary")
        /// — without this, a reinstall (or a genuinely new device) restored
        /// `homeFirstVisit` below and so counted as a returning visitor, but
        /// had no boundary to compare never-individually-visited items
        /// against, so HomeViewModel fell back to `.distantPast` and flagged
        /// nearly the entire feed as new. Reported directly: reinstalling
        /// while signed in showed a flood of "new" topics/podcasts that
        /// should have been suppressed the same way a true first launch is.
        var homeVisitBoundary: Date?
    }

    func readHistorySnapshot() -> ReadHistorySnapshot? {
        let forumsLastVisit = defaults.object(forKey: "applevis.forums.lastVisit") == nil ? nil : self.forumsLastVisit
        let homeFirstVisit = defaults.object(forKey: "applevis.lastVisit").map { _ in
            Date(timeIntervalSince1970: defaults.double(forKey: "applevis.lastVisit"))
        }
        let homeVisitBoundary = defaults.object(forKey: "applevis.home.visitBoundary").map { _ in
            Date(timeIntervalSince1970: defaults.double(forKey: "applevis.home.visitBoundary"))
        }
        return ReadHistorySnapshot(
            seenTopicIds: Array(seenTopicIds()),
            itemVisits: allItemVisits(),
            forumsLastVisit: forumsLastVisit,
            homeFirstVisit: homeFirstVisit,
            homeVisitBoundary: homeVisitBoundary
        )
    }

    func applyReadHistorySnapshot(_ snapshot: ReadHistorySnapshot) {
        let mergedSeen = seenTopicIds().union(snapshot.seenTopicIds)
        persist(Array(mergedSeen), key: seenTopicsKey)

        var mergedVisits = allItemVisits()
        for (id, remoteVisit) in snapshot.itemVisits {
            guard let localVisit = mergedVisits[id] else {
                mergedVisits[id] = remoteVisit
                continue
            }
            if remoteVisit.seenAt > localVisit.seenAt {
                mergedVisits[id] = remoteVisit
            } else if remoteVisit.seenAt == localVisit.seenAt, remoteVisit.commentCount > localVisit.commentCount {
                mergedVisits[id] = remoteVisit
            }
        }
        persist(mergedVisits, key: itemVisitsKey)

        if let remoteForums = snapshot.forumsLastVisit,
           defaults.object(forKey: "applevis.forums.lastVisit") == nil || remoteForums > forumsLastVisit {
            defaults.set(remoteForums.timeIntervalSince1970, forKey: "applevis.forums.lastVisit")
        }
        if let remoteHome = snapshot.homeFirstVisit,
           defaults.object(forKey: "applevis.lastVisit") == nil {
            defaults.set(remoteHome.timeIntervalSince1970, forKey: "applevis.lastVisit")
        }
        if let remoteBoundary = snapshot.homeVisitBoundary,
           defaults.object(forKey: "applevis.home.visitBoundary") == nil {
            defaults.set(remoteBoundary.timeIntervalSince1970, forKey: "applevis.home.visitBoundary")
        }
    }

    func playedEpisodeIdsSnapshot() -> [String] {
        Array(playedEpisodeIds())
    }

    /// Old-format cloud list, from a device on an older build: only fills
    /// in episodes this device has no record of at all.
    func applyPlayedEpisodeIds(_ ids: [String]) {
        var changes = playedChanges()
        var changed = false
        for id in ids where changes[id] == nil {
            changes[id] = PlayedChange(played: true, at: .distantPast)
            changed = true
        }
        if changed { savePlayedChanges(changes) }
    }

    /// Newest change per episode wins, whichever device made it.
    func applyPlayedChanges(_ remote: [String: PlayedChange]) {
        var changes = playedChanges()
        var changed = false
        for (id, change) in remote where change.at > (changes[id]?.at ?? .distantPast) {
            changes[id] = change
            changed = true
        }
        if changed { savePlayedChanges(changes) }
    }

    /// New replies/comments since this item was last visited — same
    /// calculation Home uses, exposed here so browse-list rows (Forums,
    /// Guides, Apps, Blogs, Podcasts, Bug Reports) can show the same
    /// per-item "N new" signal Home already has, instead of only Home
    /// knowing about it.
    /// Falls back to the item's feed baseline when it's never been opened.
    /// When "new" starts for a detail screen that marks individual
    /// comments as new (forum topics): the last visit, or failing that,
    /// when Home first saw the item — the same fallback `newReplyCount`
    /// uses, so what Home counts as new is what the topic shows as new.
    func newActivityCutoff(kind: ContentKind, id: String) -> Date? {
        let key = FeedItem.visitKey(kind: kind, contentId: id)
        return allItemVisits()[key]?.seenAt ?? allFeedBaselines()[key]?.firstSeenAt
    }

    func newReplyCount(kind: ContentKind, id: String, currentCount: Int) -> Int {
        guard showsNewActivityIndicators else { return 0 }
        let key = FeedItem.visitKey(kind: kind, contentId: id)
        guard let seenCount = allItemVisits()[key]?.commentCount ?? allFeedBaselines()[key]?.commentCount else { return 0 }
        return max(0, currentCount - seenCount)
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
        defaults.removeObject(forKey: feedBaselinesKey)
        cachedFeedBaselines = nil
        defaults.removeObject(forKey: episodeAudioMetadataKey)
        defaults.removeObject(forKey: mouseRecapDigestKey)
        defaults.removeObject(forKey: translationCacheKey)
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

    // MARK: - Mouse Recap digest cache (display-only; loadMouseRecap always
    // re-verifies against the API and overwrites this, so a stale cache can
    // never mask something added or removed server-side — it only avoids a
    // blank loading state on cold launch)

    private let mouseRecapDigestKey = "applevis.home.mouseRecapDigest"

    func cachedMouseRecapDigest() -> MouseRecapDigest? {
        load(key: mouseRecapDigestKey)
    }

    func saveMouseRecapDigest(_ digest: MouseRecapDigest) {
        persist(digest, key: mouseRecapDigestKey)
    }

    // MARK: - Reading-side content translation cache. Keyed by a composite
    // string (kind:id:field:targetLanguage) rather than id alone, since one
    // piece of content can have several translatable fields (a bug report's
    // description/steps/workaround, a title vs. a body paragraph) and a
    // device could switch content languages over its lifetime. `kind` is a
    // plain string rather than `ContentKind` since comments/replies and
    // Help articles need their own values ("forumReply", "helpArticle")
    // that aren't valid top-level `ContentKind` cases.
    //
    // Edit-invalidation: most content models here (forum topics/replies)
    // have no per-item edit timestamp at all, so this validates a content
    // hash on every read instead — unchanged source text still hits cache;
    // an editor changing so much as a character makes the hash miss and
    // silently triggers a fresh translation, no explicit invalidation pass
    // needed. `hash(_:)` is a stable content fingerprint, not a security
    // boundary, and deliberately isn't `String.hashValue`/`Hasher`, which
    // Swift randomizes per process — a persisted cache keyed on that would
    // miss everything after every single relaunch.

    private let translationCacheKey = "applevis.content.translationCache.v1"
    private let translationCacheMaxEntries = 500

    struct CachedTranslation: Codable {
        var sourceHash: String
        var targetLanguage: String
        var translatedText: String
    }

    func cachedTranslation(kind: String, id: String, field: String, targetLanguage: String, sourceText: String) -> String? {
        guard let entry = translationCache()[translationCacheEntryKey(kind: kind, id: id, field: field, targetLanguage: targetLanguage)],
              entry.sourceHash == Self.hash(sourceText)
        else { return nil }
        return entry.translatedText
    }

    func cacheTranslation(kind: String, id: String, field: String, targetLanguage: String, sourceText: String, translatedText: String) {
        var all = translationCache()
        if all.count >= translationCacheMaxEntries {
            // Soft cap, not true LRU — dictionary iteration order is
            // unspecified anyway, so evicting an arbitrary handful once the
            // cap is hit is no worse than tracking real recency for what's
            // just a local performance/storage bound.
            for key in all.keys.prefix(all.count - translationCacheMaxEntries + 1) {
                all.removeValue(forKey: key)
            }
        }
        all[translationCacheEntryKey(kind: kind, id: id, field: field, targetLanguage: targetLanguage)] = CachedTranslation(
            sourceHash: Self.hash(sourceText), targetLanguage: targetLanguage, translatedText: translatedText
        )
        persist(all, key: translationCacheKey)
    }

    private func translationCache() -> [String: CachedTranslation] {
        load(key: translationCacheKey) ?? [:]
    }

    private func translationCacheEntryKey(kind: String, id: String, field: String, targetLanguage: String) -> String {
        "\(kind):\(id):\(field):\(targetLanguage)"
    }

    /// FNV-1a — fast, stable across launches/devices/OS versions (unlike
    /// Hasher), which is all a cache-freshness fingerprint needs.
    private static func hash(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
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
