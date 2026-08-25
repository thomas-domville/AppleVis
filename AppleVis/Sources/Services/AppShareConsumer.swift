import Foundation

/// Reads (and clears) pending values the Share Extension writes into the
/// shared App Group UserDefaults. The extension's `applevis://` deep link
/// already carries the same payload directly in its query items — this is
/// the fallback path for the rare case a Share Extension's `openURL`
/// request wasn't honored by whichever app presented the share sheet, so
/// `DeepLinkRouter` checks it on every foreground too.
enum AppShareConsumer {
    private static let appGroupSuite = "group.com.applevis.app"
    private static let pendingURLKey = "pendingAppShareURL"
    private static let pendingBlogTextKey = "pendingBlogText"
    private static let pendingPodcastURLKey = "pendingPodcastURL"
    private static let pendingAudioNameKey = "pendingPodcastAudioName"
    private static let sharedAudioFilename = "pending_podcast_audio"

    private static func consume(key: String) -> String? {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        let value = defaults?.string(forKey: key)
        defaults?.removeObject(forKey: key)
        return value
    }

    static func consumePendingAppStoreURL() -> String? { consume(key: pendingURLKey) }
    static func consumePendingBlogText() -> String? { consume(key: pendingBlogTextKey) }
    static func consumePendingPodcastURL() -> String? { consume(key: pendingPodcastURLKey) }

    /// Reads (and clears) a podcast audio file the Share Extension copied
    /// into the shared App Group *container* — UserDefaults can't hold a
    /// binary blob that size, so only the original filename lives there;
    /// the audio bytes themselves sit at a fixed path in the container the
    /// extension wrote to (`ShareViewController.handlePodcastAudio`).
    /// Reads happen here, in the main app process, deliberately — memory
    /// headroom is tight in a Share Extension but not here.
    static func consumePendingPodcastAudio() -> (data: Data, fileName: String)? {
        guard let fileName = consume(key: pendingAudioNameKey),
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite)
        else { return nil }
        let fileURL = containerURL.appendingPathComponent(sharedAudioFilename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        try? FileManager.default.removeItem(at: fileURL)
        return (data, fileName)
    }
}
