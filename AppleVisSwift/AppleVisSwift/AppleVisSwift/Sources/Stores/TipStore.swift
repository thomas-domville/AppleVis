import SwiftUI
import Combine

struct TipContent {
    let title: String
    let message: String
    let icon: String
    /// Only shown when VoiceOver is running — used for tips describing
    /// screen-reader-specific interactions (rotor actions, adjustable controls).
    var screenReaderOnly: Bool = false
}

enum TipKey: String {
    case forumRotorActions        = "forum_rotor_actions"
    case playerMagicTap           = "player_magic_tap"
    case episodeChapters          = "episode_chapters"
    case savedSwipeActions        = "saved_swipe_actions"
    case downloadsOffline         = "downloads_offline"
    case reviewStarRating         = "review_star_rating"
    case settingsIntelligence     = "settings_intelligence"
    case followTopicNotifications = "follow_topic_notifications"
}

/// Ready-made tip content for every TipKey. Matches the original AppleVis tip library.
///
/// Note: `.forumRotorActions` (VoiceOver rotor custom actions on forum comments) and
/// `.reviewStarRating` (adjustable star-rating input) describe features that don't
/// exist in this app yet — their content is kept here for when those land, but
/// nothing currently calls `TipStore.show(.forumRotorActions, ...)` or `.reviewStarRating`.
enum Tips {
    static let content: [TipKey: TipContent] = [
        .forumRotorActions: TipContent(
            title: "Community Comment Actions",
            message: "In the Community Discussion section, each comment header has VoiceOver actions. Rotate two fingers to the Actions rotor, then flick up or down to choose options such as Reply to this Comment, Copy Comment Text, Share Comment, or Report Comment. This tip applies to the comment list, not the main topic text.",
            icon: "list.bullet",
            screenReaderOnly: true
        ),
        .playerMagicTap: TipContent(
            title: "Quick Play and Pause",
            message: "Two-finger double-tap anywhere on the screen plays or pauses the current episode. This works from any screen in the app while an episode is loaded — you do not need to open the player first. This is called a Magic Tap and is available throughout AppleVis.",
            icon: "play.circle"
        ),
        .episodeChapters: TipContent(
            title: "This Episode Has Chapters",
            message: "This podcast includes chapter markers. In the Chapters section, activate any chapter to jump directly to that part of the episode. With VoiceOver, swipe through the chapter list and double-tap your chosen chapter.",
            icon: "bookmark"
        ),
        .savedSwipeActions: TipContent(
            title: "Quick Actions on Episodes",
            message: "In saved or downloaded episode lists, swipe left on an episode to reveal quick action buttons for deleting, sharing, or marking as played. You can also long-press an episode to open the full action menu.",
            icon: "hand.point.left"
        ),
        .downloadsOffline: TipContent(
            title: "Listening Without Internet",
            message: "Downloaded episodes are stored on your device and play without an internet connection — perfect for flights, commutes, or areas with poor signal. Downloads stay on your device until you remove them.",
            icon: "arrow.down.circle"
        ),
        .reviewStarRating: TipContent(
            title: "Rating With VoiceOver",
            message: "In the Write Comment form, the star rating control works like an adjustable slider. Flick up to increase the rating and flick down to decrease it. You can also use the VoiceOver rotor to choose Value, then flick up or down.",
            icon: "star",
            screenReaderOnly: true
        ),
        .settingsIntelligence: TipContent(
            title: "Apple Intelligence in AppleVis",
            message: "On supported iPhone and iPad models, AppleVis works with Apple Intelligence. You can ask Siri to open topics, check the podcast feed, or look up app information using natural language. Enable features in Settings → Siri & Intelligence.",
            icon: "cpu"
        ),
        .followTopicNotifications: TipContent(
            title: "Managing Followed Topics",
            message: "You are now following this topic and will be notified of new replies. To see all your followed topics or turn off notifications for specific ones, go to your Profile → Followed Topics, or adjust notification settings in Settings → Notifications.",
            icon: "bell"
        ),
    ]
}

/// Shows one-time contextual tips (the "AppleVis Tip" popovers) — each tip key is
/// shown at most once per install, tracked in UserDefaults.
@MainActor
final class TipStore: ObservableObject {
    struct ActiveTip: Identifiable {
        let key: TipKey
        let content: TipContent
        var id: String { key.rawValue }
    }

    @Published private(set) var activeTip: ActiveTip?

    private var seenThisSession: Set<TipKey> = []
    private static let keyPrefix = "applevis.tip."

    func show(_ key: TipKey) {
        guard !seenThisSession.contains(key), let content = Tips.content[key] else { return }
        guard !UserDefaults.standard.bool(forKey: Self.keyPrefix + key.rawValue) else {
            seenThisSession.insert(key)
            return
        }

        if content.screenReaderOnly {
            guard UIAccessibility.isVoiceOverRunning else { return }
        }

        seenThisSession.insert(key)
        SoundPlayer.shared.play(.tipPopup)
        activeTip = ActiveTip(key: key, content: content)
    }

    func dismissActiveTip() {
        guard let activeTip else { return }
        UserDefaults.standard.set(true, forKey: Self.keyPrefix + activeTip.key.rawValue)
        self.activeTip = nil
    }
}
