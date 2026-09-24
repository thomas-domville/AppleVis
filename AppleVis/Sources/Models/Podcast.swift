import Foundation

nonisolated struct PodcastEpisode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    /// Drupal's internal integer node ID — needed to call History's
    /// `/history/{nid}/read`, which is keyed on the classic integer ID,
    /// distinct from `id` (the JSON:API UUID).
    let nid: Int
    let title: String
    let showTitle: String
    let audioUrl: String
    // `var`, not `let` — the API never actually supplies either (duration
    // is hardcoded to 0 server-side; chapters are only ever present for
    // episodes a host bothered to chapter-mark in Drupal). Both get
    // overwritten in place once `PodcastAudioMetadataProbe` resolves real
    // values by reading the audio file itself, from the cache or a fresh
    // client-side probe.
    var duration: TimeInterval?
    let publishedAt: Date
    let lastActivityAt: Date
    let description: String
    /// See `ForumTopicDetail.rawBody`/`bodyFormat`'s doc comment.
    var rawDescription: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let artworkUrl: String?
    let transcriptUrl: String?
    var chapters: [Chapter]
    let tags: [PodcastTag]
    let commentCount: Int
    let authorName: String
    let url: String
    var isSaved: Bool
    var isDownloaded: Bool
    var downloadProgress: Double?
}

nonisolated struct Chapter: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

nonisolated struct PodcastTag: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let tid: Int
    let count: Int
}

nonisolated struct PodcastComment: Identifiable, Codable, Sendable {
    let id: String
    let authorName: String
    let authorId: String
    let subject: String
    let body: String
    let createdAt: Date
}

/// Single source of truth for formatting a duration, replacing five
/// near-identical private implementations that had drifted into visibly
/// different output for the same value across screens — "2:15:00" in the
/// player, "2h 15m" in the queue, "2 hr 15 min" in the browse list
/// (PODCAST-10).
nonisolated enum PodcastDuration {
    /// "1:23:45" or "23:45" — used for elapsed/remaining time in the player,
    /// scrubber, and chapter list, where seconds-level precision matters.
    static func colon(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    /// "2 hr 15 min" / "45 min" — used for a whole episode's total length in
    /// list/summary contexts, where second-level precision isn't useful.
    /// Was previously also hand-rolled as "2h 15m" in one call site
    /// (`QueueView`) while every other call site already used this
    /// Foundation-native, locale-aware form — standardized on the latter.
    static func abbreviated(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes]))
    }

    /// "1 minute, 23 seconds" / "1 hour, 2 minutes, 3 seconds" — used only
    /// for accessibility labels and announcements where colon-formatted time
    /// is ambiguous when spoken or read on a Braille display.
    static func accessibilityLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        var parts: [String] = []

        if hours > 0 {
            parts.append(unit(hours, singular: "hour", plural: "hours"))
        }
        if minutes > 0 {
            parts.append(unit(minutes, singular: "minute", plural: "minutes"))
        }
        if seconds > 0 || parts.isEmpty {
            parts.append(unit(seconds, singular: "second", plural: "seconds"))
        }

        return parts.joined(separator: ", ")
    }

    static func accessibilityPosition(current: TimeInterval, duration: TimeInterval?) -> String {
        let currentText = accessibilityLabel(current)
        guard let duration, duration > 0 else { return currentText }
        return "\(currentText) of \(accessibilityLabel(duration))"
    }

    static func accessibilityRemaining(_ seconds: TimeInterval) -> String {
        "\(accessibilityLabel(seconds)) remaining"
    }

    private static func unit(_ value: Int, singular: String, plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}
