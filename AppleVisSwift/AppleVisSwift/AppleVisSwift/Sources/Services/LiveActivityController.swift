import ActivityKit
import Foundation

/// Struct is intentionally duplicated in the LiveActivityExtension target
/// (AppleVisLiveActivityWidget.swift) — see that file's header comment.
struct AppleVisPodcastAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var positionSeconds: Double
        var durationSeconds: Double
        var speed: Double
        var chapterTitle: String
    }
    var episodeTitle: String
    var showTitle: String
    var episodeId: String
}

/// Starts, updates, and ends the podcast playback Live Activity shown on the
/// Lock Screen and Dynamic Island. PlayerStore calls this from the same
/// places it already updates Now Playing info.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private init() {}

    private var activity: Activity<AppleVisPodcastAttributes>?
    private var lastUpdateAt: Date = .distantPast

    /// ActivityKit updates are rate-limited system-wide; forced calls (play,
    /// pause, seek) always go through, but the frequent position-observer
    /// tick is throttled to this interval.
    private static let minUpdateInterval: TimeInterval = 20

    func start(episodeId: String, episodeTitle: String, showTitle: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let activity, activity.attributes.episodeId == episodeId { return }
        if activity != nil { end() }

        let attrs = AppleVisPodcastAttributes(episodeTitle: episodeTitle, showTitle: showTitle, episodeId: episodeId)
        let state = AppleVisPodcastAttributes.ContentState(
            isPlaying: false, positionSeconds: 0, durationSeconds: 0, speed: 1, chapterTitle: ""
        )
        do {
            activity = try Activity.request(attributes: attrs, contentState: state, pushType: nil)
            lastUpdateAt = .distantPast
        } catch {
            #if DEBUG
            print("[LiveActivity] start error: \(error)")
            #endif
        }
    }

    func update(
        isPlaying: Bool, position: TimeInterval, duration: TimeInterval,
        speed: Double, chapterTitle: String, force: Bool = false
    ) {
        guard activity != nil else { return }
        guard force || Date().timeIntervalSince(lastUpdateAt) >= Self.minUpdateInterval else { return }
        lastUpdateAt = Date()

        let state = AppleVisPodcastAttributes.ContentState(
            isPlaying: isPlaying, positionSeconds: position, durationSeconds: duration,
            speed: speed, chapterTitle: chapterTitle
        )
        Task { await activity?.update(using: state) }
    }

    func end() {
        let current = activity
        activity = nil
        Task { await current?.end(dismissalPolicy: .immediate) }
    }
}
