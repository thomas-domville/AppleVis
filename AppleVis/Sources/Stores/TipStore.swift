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
            title: "Getting Around Comments Faster",
            message: "Here's a handy one: every comment header in Community Discussion has its own set of VoiceOver actions tucked away. Rotate two fingers to bring up the Actions rotor, then flick up or down to reach things like Reply to this Comment, Copy Comment Text, Share Comment, or Report Comment — no extra buttons to hunt for. This applies to the comment list itself, not the topic text up top.",
            icon: "list.bullet",
            screenReaderOnly: true
        ),
        .playerMagicTap: TipContent(
            title: "Quick Play and Pause, Anywhere",
            message: "Don't want to leave what you're doing just to hit pause? A two-finger double-tap anywhere on the screen plays or pauses whatever episode is loaded — no need to open the player first. It's called a Magic Tap, and it works throughout AppleVis, so it's always within reach.",
            icon: "play.circle"
        ),
        .episodeChapters: TipContent(
            title: "This One Has Chapters!",
            message: "Good news — this episode has chapter markers, so you don't have to scrub around to find the part you want. Head to the Chapters section and pick one to jump straight there. With VoiceOver, just swipe through the list and double-tap the chapter you're after.",
            icon: "bookmark"
        ),
        .savedSwipeActions: TipContent(
            title: "Faster Episode Actions",
            message: "A little shortcut for your Saved and Downloaded lists: swipe left on any episode to reveal quick actions for deleting, sharing, or marking it as played. Prefer the full picture? A long-press opens the complete action menu instead.",
            icon: "hand.point.left"
        ),
        .downloadsOffline: TipContent(
            title: "Take It Offline",
            message: "Downloaded episodes live right on your device, so they'll keep playing with no signal at all — great for flights, commutes, or that one spot with terrible reception. They're yours to keep until you decide to remove them.",
            icon: "arrow.down.circle"
        ),
        .reviewStarRating: TipContent(
            title: "Rating With VoiceOver",
            message: "In the Write Comment form, the star rating works like an adjustable slider — flick up to raise it, flick down to lower it. Or bring up the VoiceOver rotor, choose Value, and flick from there instead.",
            icon: "star",
            screenReaderOnly: true
        ),
        .settingsIntelligence: TipContent(
            title: "Ask Siri About AppleVis",
            message: "On supported iPhone and iPad models, AppleVis plays nicely with Apple Intelligence — ask Siri to open a topic, check what's new in your podcast feed, or look up an app, all in plain language. You can turn this on in Settings → Siri & Intelligence.",
            icon: "cpu"
        ),
        .followTopicNotifications: TipContent(
            title: "You're Following This Topic",
            message: "Nice — you'll hear about new replies here from now on. Want to see everything you're following, or unfollow something? Head to For You → Following. Notification preferences live in Settings → Notifications, whenever you want to fine-tune them.",
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
