import SwiftUI
import Combine
import UIKit

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
/// Note: `.reviewStarRating` (adjustable star-rating input) describes a feature
/// that can't exist in this app — AppleVis's review comment bundle has no
/// rating field on the backend (see `ComposeAppReviewView` in
/// AppDetailView.swift), so there's nothing to add a rating control to
/// without silently discarding whatever the user picks. Content kept here in
/// case the backend ever adds one; nothing currently calls
/// `TipStore.show(.reviewStarRating)`.
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

    /// RN's every call site delayed presentation 800-1500ms after the
    /// triggering screen appeared, so the tip never collided with that
    /// screen's own entrance animation or VoiceOver announcement. Swift
    /// fired immediately; a single representative delay here (rather than
    /// re-tuning every call site) captures the same intent.
    private static let presentationDelay: Duration = .milliseconds(1000)

    /// Seen-tip flags are also written to iCloud key-value storage (RN's
    /// icloudStorage.ts) so "don't show this again" carries across a user's
    /// devices, not just this install — falls back to UserDefaults alone
    /// when iCloud isn't available.
    private static func isSeen(_ key: TipKey) -> Bool {
        let fullKey = keyPrefix + key.rawValue
        return NSUbiquitousKeyValueStore.default.bool(forKey: fullKey) || UserDefaults.standard.bool(forKey: fullKey)
    }

    private static func markSeen(_ key: TipKey) {
        let fullKey = keyPrefix + key.rawValue
        UserDefaults.standard.set(true, forKey: fullKey)
        NSUbiquitousKeyValueStore.default.set(true, forKey: fullKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func show(_ key: TipKey) {
        guard PreferencesStore.current?.helpfulTipsEnabled ?? true else { return }
        guard !seenThisSession.contains(key), let content = Tips.content[key] else { return }
        guard !Self.isSeen(key) else {
            seenThisSession.insert(key)
            return
        }

        if content.screenReaderOnly {
            guard UIAccessibility.isVoiceOverRunning else { return }
        }

        seenThisSession.insert(key)
        Task {
            try? await Task.sleep(for: Self.presentationDelay)
            guard !Task.isCancelled else { return }
            SoundPlayer.shared.play(.tipPopup)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeTip = ActiveTip(key: key, content: content)
        }
    }

    func dismissActiveTip() {
        guard let activeTip else { return }
        Self.markSeen(activeTip.key)
        self.activeTip = nil
    }
}
