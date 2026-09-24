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
    case savedQuickActions        = "saved_quick_actions_v2"
    case savedRotorActions        = "saved_rotor_actions"
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
            title: "Actions on Comments",
            message: "Each comment in Community Discussion has its own VoiceOver actions. Turn the rotor to Actions, then swipe up or down to reach Reply to this Comment, Copy Comment Text, Share Comment, or Report Comment. This works on the comments, not on the topic text at the top.",
            icon: "list.bullet",
            screenReaderOnly: true
        ),
        .playerMagicTap: TipContent(
            title: "Play and Pause From Anywhere",
            message: "A two-finger double-tap, called a Magic Tap, plays or pauses the loaded episode from anywhere in AppleVis. You don't need to open the player first.",
            icon: "play.circle",
            // Magic Tap is itself a VoiceOver/Switch Control-only gesture —
            // .accessibilityAction(.magicTap) can only fire when one of those
            // is already active, so this can only ever be triggered by a
            // VoiceOver (or Switch Control) user in the first place. Flagging
            // it explicitly here is just honest bookkeeping, not a behavior
            // change — nothing was ever showing this to a sighted touch user.
            screenReaderOnly: true
        ),
        .episodeChapters: TipContent(
            title: "This Episode Has Chapters",
            message: "This episode has chapter markers. Go to the Chapters section and choose a chapter to go straight to it. With VoiceOver, swipe through the list and double-tap a chapter.",
            icon: "bookmark"
        ),
        // Split in two (2026-09-13, replacing the old `.savedSwipeActions`)
        // after a beta tester saved a forum topic, landed on For You, and got
        // a tip titled "Faster Episode Actions" describing swipe-to-delete
        // and mark-as-played — neither of which exists on a saved topic's
        // row (its only quick action is Unsave). The old tip also fired
        // unconditionally for every VoiceOver user too, describing a plain
        // one-finger swipe left, which under VoiceOver moves focus to the
        // previous item rather than revealing anything — actively wrong
        // instructions, not just irrelevant ones. New keys so beta users who
        // already dismissed the old, incorrect tip get to see the fix once.
        .savedQuickActions: TipContent(
            title: "Quick Actions on Your Saved List",
            message: "Swipe left on a saved item for quick actions, such as Unsave. Touch and hold an item to see all of its actions.",
            icon: "hand.point.left"
        ),
        .savedRotorActions: TipContent(
            title: "VoiceOver Actions on Your Saved List",
            message: "Each saved item has its own VoiceOver actions, such as Unsave. Turn the rotor to Actions, then swipe up or down to reach them.",
            icon: "hand.point.left",
            screenReaderOnly: true
        ),
        .downloadsOffline: TipContent(
            title: "Listen Offline",
            message: "Downloaded episodes are stored on your device, so they play without a connection. They stay until you remove them.",
            icon: "arrow.down.circle"
        ),
        .reviewStarRating: TipContent(
            title: "Rating With VoiceOver",
            message: "In the Write Comment form, the star rating works like an adjustable control. Swipe up to raise it and down to lower it. You can also turn the rotor to Value and swipe from there.",
            icon: "star",
            screenReaderOnly: true
        ),
        .settingsIntelligence: TipContent(
            title: "Ask Siri About AppleVis",
            message: "On supported iPhone and iPad models, you can ask Siri to open a topic, check what's new in your podcast feed, or look up an app, in your own words. Turn this on in Settings > Siri & Intelligence.",
            icon: "cpu"
        ),
        .followTopicNotifications: TipContent(
            title: "You're Following This Topic",
            message: "You'll be notified about new replies to this topic. To see everything you follow, or to unfollow, go to For You > Following. You can change notification settings in Settings > Notifications.",
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
