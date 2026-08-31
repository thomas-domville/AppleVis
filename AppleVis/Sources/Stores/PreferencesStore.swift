import SwiftUI
import Combine
import UIKit

@MainActor
final class PreferencesStore: ObservableObject {
    /// Lets SoundPlayer (a plain singleton with no environment access) read
    /// the exact same in-memory property SwiftUI's Toggle reads/writes,
    /// instead of doing its own independent `UserDefaults.standard` lookup.
    /// The two were observed to disagree on-device (Settings showed
    /// "Interface Sounds" on; a raw UserDefaults read of the same key
    /// still came back nil) — going through the single AppStorage-backed
    /// property both places read/write removes any chance of that drift,
    /// regardless of the underlying cause.
    static weak var current: PreferencesStore?

    init() {
        PreferencesStore.current = self
    }

    // MARK: - Appearance
    @AppStorage("theme") var theme: AppTheme = .system
    /// Refreshed from `UITraitCollection.current` on every foreground
    /// (`AppleVisApp`'s `.onChange(of: scenePhase)`), not read live via
    /// SwiftUI's `@Environment(\.colorScheme)` — a `SystemAppearanceObserver`
    /// modifier tried exactly that and caused System (Inverted)
    /// (`.oppositeToSystem`) to flicker continuously the instant it was
    /// selected. The mechanism: `.preferredColorScheme(preferences.colorScheme)`
    /// is applied at the app root, and that modifier overrides the
    /// `colorScheme` environment value for everything beneath it —
    /// including a `.modifier()` chained after it, which is exactly where
    /// the observer sat. So it wasn't reading the true system appearance;
    /// it was reading its own app's already-inverted output. For every
    /// other theme, colorScheme() doesn't depend on `systemIsDark`, so nothing
    /// closes the loop — `.oppositeToSystem` is the one case where the
    /// observed value and the applied override are the same value, chasing
    /// itself: inverted-to-dark → environment reports dark → systemIsDark
    /// set true → recomputes inverted-to-light → environment reports light →
    /// systemIsDark set false → back to dark, forever. `UITraitCollection.current`
    /// is a plain UIKit global, untouched by what SwiftUI's environment is
    /// doing, so it can't self-trigger — the tradeoff is that a system
    /// appearance change made while the app sits actively foregrounded
    /// isn't picked up until the next foreground transition, rather than
    /// instantly. Reported directly: System (Inverted) "flashes... as if
    /// it's fighting with the system."
    @Published var systemIsDark: Bool = UITraitCollection.current.userInterfaceStyle == .dark
    var colorScheme: ColorScheme? { theme.colorScheme(systemIsDark: systemIsDark) }
    var colors: ThemeColors { theme.colors(systemIsDark: systemIsDark) }
    var accentColor: Color { theme.accentColor(systemIsDark: systemIsDark) }
    @AppStorage("appearance.cardDensity") var cardDensity: CardDensity = .comfortable
    @AppStorage("browsing.webMode") var webBrowsingMode: WebBrowsingMode = .inApp

    // MARK: - Home feed filters
    @AppStorage("feed.showForums")   var showForums   = true
    @AppStorage("feed.showPodcasts") var showPodcasts = true
    @AppStorage("feed.showApps")     var showApps     = true
    @AppStorage("feed.showGuides")   var showGuides   = true
    @AppStorage("feed.showBlogs")    var showBlogs    = true
    @AppStorage("feed.appleOnly")    var appleOnlyForums = false

    // MARK: - Podcast playback
    @AppStorage("podcast.speed")        var playbackSpeed: Double = 1.0
    @AppStorage("podcast.skipBack")     var skipBackInterval: Double = 10
    @AppStorage("podcast.skipForward")  var skipForwardInterval: Double = 30
    @AppStorage("podcast.autoPlay")     var autoPlayNext = true
    @AppStorage("podcast.sleepTimer")   var sleepTimerMinutes: Int = 0
    // RN defaulted this to 15 seconds; Swift's default of 0 meant fresh
    // installs got no resume-rewind at all out of the box.
    @AppStorage("podcast.resumeRewind") var resumeRewindSeconds: Int = 15
    @AppStorage("podcast.trimSilence")  var trimSilence = false
    @AppStorage("podcast.voiceBoost")   var voiceBoost = false
    @AppStorage("podcast.eq")           var podcastEQ: PodcastEQ = .flat
    @AppStorage("podcast.autoDownload") var autoDownload: PodcastAutoDownload = .off
    @AppStorage("podcast.autoDelete")   var autoDelete: PodcastAutoDelete = .off

    // MARK: - Notifications (granular)
    // All default off — opt-in, not opt-out. Three of these (newTopics,
    // newEpisodes, announcements) previously defaulted on, so a fresh
    // install effectively signed every user up for push notifications
    // they'd never explicitly asked for. Reported directly by a beta
    // tester during onboarding review.
    @AppStorage("notif.forumReplies")   var notifyForumReplies  = false
    @AppStorage("notif.mentions")       var notifyMentions       = false
    @AppStorage("notif.newTopics")      var notifyNewTopics      = false
    @AppStorage("notif.followedTopics") var notifyFollowedTopics = false
    @AppStorage("notif.newEpisodes")    var notifyNewEpisodes    = false
    @AppStorage("notif.appUpdates")     var notifyAppUpdates     = false
    @AppStorage("notif.newResources")   var notifyNewResources   = false
    @AppStorage("notif.announcements")  var notifyAnnouncements  = false
    /// Comments on any content type (forum/podcast/app/blog/guide), regardless
    /// of follow status — distinct from `notifyForumReplies`, which is only
    /// replies to topics the user themselves started. Defaults off: this is
    /// the highest-volume category by far.
    @AppStorage("notif.newComments")    var notifyNewComments    = false
    @AppStorage("notif.sound")          var notificationSound: NotificationSound = .mouseSqueak
    /// RN's `notifBadge` ("Shows a number on the AppleVis icon... tap the
    /// app and the badge clears") had no Swift equivalent at all.
    @AppStorage("notif.badgeCount")     var badgeCountEnabled    = true

    // MARK: - Accessibility
    @AppStorage("a11y.announcement")    var announcementLevel: AnnouncementLevel = .normal
    @AppStorage("a11y.helpfulTips")     var helpfulTipsEnabled = true
    @AppStorage("a11y.welcomeSummary")  var welcomeSummaryEnabled = true
    @AppStorage("a11y.homeStartup")     var homeStartupBehavior: HomeStartupBehavior = .helpful
    // Defaults off — auto-raising the keyboard whenever Discover's Search
    // tab is opened meant a VoiceOver user who just wanted to browse the
    // hub grid had to dismiss the keyboard first every time. Reported
    // directly. Still available as an opt-in for anyone who prefers landing
    // straight in Search.
    @AppStorage("a11y.searchAutoFocus") var searchAutoFocusEnabled = false
    @AppStorage("privacy.signedOutHistory") var rememberSignedOutHistory = true

    // MARK: - Forums
    @AppStorage("forums.defaultFilter") var forumsDefaultFilter: ForumFilter = .recent

    // MARK: - Sounds & Haptics
    // docs/APPLEVIS_2026_1_MASTER_SPEC.md: "All app sounds must be optional.
    // Default on: notification, save confirmation, download complete, and
    // podcast actions. Default off: tab switching, picker changes, opening
    // screens, and list refresh sounds." SoundPlayer.swift reads these same
    // keys directly (it has no environment access to this store).
    @AppStorage("sound.interface")    var interfaceSoundsEnabled = false
    @AppStorage("sound.confirmation") var confirmationSoundsEnabled = true
    /// Mirrors `confirmationSoundsEnabled`'s scope exactly — only the same
    /// "something happened, worth confirming" tier of sounds gets a paired
    /// haptic (save, follow/recommend, submit success, sign in, errors);
    /// the "interface" chrome tier (refresh, tab switching, picker ticks)
    /// never does, matching how that tier is already off by default for
    /// sound too. See `AppSound.shouldPlayHaptic`.
    @AppStorage("sound.haptics") var hapticsEnabled = true

    // MARK: - Intelligence / Smart Features
    @AppStorage("intel.nonEnglish")         var nonEnglishDetectionEnabled = true
    @AppStorage("intel.composeRewrite")     var composeRewriteEnabled = true
    @AppStorage("intel.composeTranslation") var composeTranslationEnabled = true
    @AppStorage("intel.searchTranslation")  var searchTranslationEnabled = true
    @AppStorage("intel.aiSummaries")        var aiSummariesEnabled = true

    // MARK: - iCloud Sync
    @AppStorage("sync.iCloud")          var iCloudSync = true
    @AppStorage("sync.savedItems")      var savedItemsSync = true
    @AppStorage("sync.followedItems")   var followedItemsSync = true
    @AppStorage("sync.podcastPosition") var podcastPositionSync = true
    @AppStorage("sync.queue")           var queueSync = true
    @AppStorage("sync.readHistory")     var readHistorySync = true
    @AppStorage("sync.settings")        var settingsSync = true
}

// MARK: - Enums

enum ThemeGroup: String, CaseIterable, Identifiable {
    // Declaration order is display order (Appearance settings lists groups
    // via ThemeGroup.allCases) — Accessibility leads since it's the most
    // consequential choice for this app's audience, then AppleVis's own
    // branded themes, then the plain iOS-standard ones last. Reordered
    // directly per request.
    case accessibility, appleVis, standard
    var id: String { rawValue }
    var label: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .appleVis:     return "AppleVis"
        case .standard:     return "Standard"
        }
    }
}

/// 15 fixed theme IDs across three groups — Standard, AppleVis, Accessibility.
/// (RN's own header comments/settings copy claimed "13" or "14 themes" at
/// various points — both were stale; `src/theme/themes.ts`'s actual registry
/// is 15, including `oppositeToSystem`, which this port had dropped
/// entirely.)
enum AppTheme: String, CaseIterable, Identifiable {
    case system, oppositeToSystem, light, dark, midnight, warm, sepia
    case applevisClassic, mouseLight, mouseDark, orchard, goldenGate, nebula
    case highContrastLight, highContrastDark

    var id: String { rawValue }

    var group: ThemeGroup {
        switch self {
        case .system, .oppositeToSystem, .light, .dark, .midnight, .warm, .sepia:
            return .standard
        case .applevisClassic, .mouseLight, .mouseDark, .orchard, .goldenGate, .nebula:
            return .appleVis
        case .highContrastLight, .highContrastDark:
            return .accessibility
        }
    }

    var displayName: String {
        switch self {
        case .system:            return "System"
        case .oppositeToSystem: return "System (Inverted)"
        case .light:              return "Light"
        case .dark:                return "Dark"
        case .midnight:           return "Midnight"
        case .warm:               return "Warm"
        case .sepia:              return "Sepia"
        case .applevisClassic:   return "AppleVis Classic"
        case .mouseLight:        return "Mouse — Light"
        case .mouseDark:         return "Mouse — Dark"
        case .orchard:            return "Orchard"
        // Was "Golden Gate" — Apple's own macOS 26 code name, and not
        // worth the trademark risk for a theme name with no real
        // connection to it beyond both evoking San Francisco. Reported
        // directly by a beta tester. The `goldenGate` case name itself is
        // untouched — it's what `@AppStorage` actually persists, so
        // renaming it would silently reset this specific choice back to
        // the default for anyone who'd already picked it.
        case .goldenGate:        return "Cupertino Sunset"
        case .nebula:             return "Nebula"
        case .highContrastLight: return "High Contrast Light"
        case .highContrastDark:  return "High Contrast Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system:            return "Follows iOS appearance setting"
        case .oppositeToSystem: return "Always the opposite of your iOS appearance"
        case .light:              return "Always uses light colours"
        case .dark:                return "Always uses dark colours"
        case .midnight:           return "Deep black background for low-light use"
        case .warm:               return "Soft cream and amber tones that reduce blue light"
        case .sepia:              return "Warm, low-glare tones for extended reading"
        case .applevisClassic:   return "The blue and white scheme from applevis.com"
        case .mouseLight:        return "Warm, playful theme inspired by AnonyMouse"
        case .mouseDark:         return "The Mouse theme in a warm charcoal dark edition"
        case .orchard:            return "Fresh apple greens and deep reds"
        case .goldenGate:        return "Warm California sunset tones"
        case .nebula:             return "Deep indigo and soft lavender, space-inspired"
        case .highContrastLight: return "Maximum contrast on a light background"
        case .highContrastDark:  return "Maximum contrast on a dark background"
        }
    }

    /// The underlying light/dark base every theme renders on top of —
    /// SwiftUI has no native "sepia"/"nebula"/etc. scheme, so themes
    /// differentiate via this base plus `accentColor` below.
    /// `systemIsDark` must come from a reactive source (SwiftUI's
    /// `@Environment(\.colorScheme)`, forwarded via `PreferencesStore
    /// .systemIsDark`) rather than a raw `UITraitCollection.current` read —
    /// the latter is a one-time snapshot that goes stale until some
    /// unrelated re-render happens to recompute it.
    func colorScheme(systemIsDark: Bool) -> ColorScheme? {
        switch self {
        case .system: return nil
        case .oppositeToSystem: return systemIsDark ? .light : .dark
        case .light, .warm, .sepia, .applevisClassic, .mouseLight, .orchard, .goldenGate, .highContrastLight:
            return .light
        case .dark, .midnight, .mouseDark, .nebula, .highContrastDark:
            return .dark
        }
    }

    /// Full palette for this theme, ported verbatim from RN's
    /// `src/theme/themes.ts`. `.system`/`.oppositeToSystem` resolve off
    /// `systemIsDark`, matching RN's own runtime-resolved placeholders for
    /// those two entries.
    func colors(systemIsDark: Bool) -> ThemeColors {
        switch self {
        case .system:            return systemIsDark ? .dark : .light
        case .oppositeToSystem: return systemIsDark ? .light : .dark
        case .light:              return .light
        case .dark:                return .dark
        case .midnight:           return .midnight
        case .warm:               return .warm
        case .sepia:              return .sepia
        case .applevisClassic:   return .applevisClassic
        case .mouseLight:        return .mouseLight
        case .mouseDark:         return .mouseDark
        case .orchard:            return .orchard
        case .goldenGate:        return .goldenGate
        case .nebula:             return .nebula
        case .highContrastLight: return .highContrastLight
        case .highContrastDark:  return .highContrastDark
        }
    }

    /// Derived from `colors(systemIsDark:).accent` for every fixed palette
    /// so there's a single source of truth for each theme's accent — this
    /// used to hardcode its own independent RGB literals here, which had
    /// quietly drifted from the verified-against-RN `ThemeColors.accent`
    /// values for Midnight, Sepia, and High Contrast Light.
    func accentColor(systemIsDark: Bool) -> Color {
        switch self {
        case .system, .oppositeToSystem, .light, .dark: return .accentColor
        default: return colors(systemIsDark: systemIsDark).accent
        }
    }
}

/// Single source of truth for the playback-speed range docs/APPLEVIS_2026_1_MASTER_SPEC.md
/// requires (0.5x through 3.0x) — PodcastSettingsView's picker and
/// FullPlayerView's quick-cycle speed button used to keep their own
/// independent, out-of-sync copies of this list (the player's capped at
/// 2.0x and couldn't recognize a higher speed set from Settings).
enum PodcastSpeedOptions {
    static let all: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]
}

enum CardDensity: String, CaseIterable, Identifiable {
    case comfortable, compact
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var verticalPadding: CGFloat { self == .compact ? 2 : 6 }
}

/// Every web link the app opens (App Store/social/legal links, "Open in
/// Browser" actions, etc.) routes through `WebLink`/this preference instead
/// of always launching the external browser the way a bare SwiftUI `Link`
/// does — default is in-app so nobody leaves the app just to glance at a
/// page, with an explicit opt-out for anyone who wants their regular
/// browser's bookmarks, extensions, signed-in sessions, or Reader mode.
/// Requested directly.
enum WebBrowsingMode: String, CaseIterable, Identifiable {
    case inApp, external
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .inApp:    return "In-App Browser"
        case .external: return "Default Browser"
        }
    }
}

enum ForumFilter: String, CaseIterable, Identifiable {
    case recent, new, unread, sinceLastVisit, following, saved
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .recent:         return "Recent"
        case .new:             return "New"
        case .unread:          return "Unread"
        case .sinceLastVisit: return "Since Last Visit"
        case .following:       return "Following"
        case .saved:           return "Saved"
        }
    }
    /// Following/Saved come from local persistence rather than the "recent" feed,
    /// so category/Apple-only refinement doesn't apply to them.
    var supportsRefinement: Bool { self == .recent || self == .new || self == .unread || self == .sinceLastVisit }

    var filterDescription: String? {
        switch self {
        case .recent, .new:   return nil
        case .sinceLastVisit: return "Topics that changed since you last opened AppleVis."
        case .unread:          return "Topics you have not opened yet on this device."
        case .following:       return "Topics you are following. Saved locally and synced via iCloud."
        case .saved:           return "Topics you saved for later. Synced via iCloud."
        }
    }
}

enum AnnouncementLevel: String, CaseIterable, Identifiable {
    case simple, normal, all
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .normal: return "Normal"
        case .all:    return "All Details"
        }
    }
    // Rewritten to match what a forum topic row actually says today (see
    // ForumTopicRow.topicLabel / the shared detailLevelLabel helper in
    // RowViews.swift) — the previous examples used a "Forum." sentence
    // fragment and period-separated clauses that don't match the real,
    // comma-joined format, and hadn't been updated as that format changed.
    // Kept in sync going forward per the Help-content-upkeep rule.
    var preview: String {
        switch self {
        case .simple: return "\"iOS 18 VoiceOver Tips, iOS and iPadOS topic.\""
        case .normal: return "\"iOS 18 VoiceOver Tips, iOS and iPadOS topic, by JaneD, 14 comments.\""
        case .all:    return "\"iOS 18 VoiceOver Tips, iOS and iPadOS topic, by JaneD, 14 comments, 2 days ago.\""
        }
    }
}

enum HomeStartupBehavior: String, CaseIterable, Identifiable {
    case quiet, helpful, detailed
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum PodcastEQ: String, CaseIterable, Identifiable {
    case flat, speech, bassBoost, trebleBoost
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .flat:        return "Flat"
        case .speech:      return "Speech Clarity"
        case .bassBoost:   return "Bass Boost"
        case .trebleBoost: return "Treble Boost"
        }
    }
}

enum PodcastAutoDownload: String, CaseIterable, Identifiable {
    case off, wifiOnly, always
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off:      return "Off"
        case .wifiOnly: return "Wi-Fi Only"
        case .always:   return "Always"
        }
    }
}

enum PodcastAutoDelete: String, CaseIterable, Identifiable {
    case off, immediate, oneDay, threeDays, sevenDays
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off:        return "Off"
        case .immediate:  return "Immediately After Playing"
        case .oneDay:     return "After 1 Day"
        case .threeDays:  return "After 3 Days"
        case .sevenDays:  return "After 7 Days"
        }
    }
}

enum NotificationSound: String, CaseIterable, Identifiable {
    case mouseSqueak, appleCrunch, goldenRetrieverBark, system
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mouseSqueak:         return "Mouse Squeak"
        case .appleCrunch:         return "Apple Crunch"
        case .goldenRetrieverBark: return "Golden Retriever Bark"
        case .system:              return "System Default"
        }
    }
    var description: String {
        switch self {
        case .mouseSqueak:         return "The AppleVis signature sound, soft and distinctive."
        case .appleCrunch:         return "A crisp apple crunch."
        case .goldenRetrieverBark: return "A friendly golden retriever bark, warm and cheerful."
        // iOS has no API for a third-party app to read or play back
        // exactly which alert tone a user has personally set as their
        // device default — this sends "default" in the push payload,
        // which does correctly tell the system to use whatever that tone
        // actually is when a real notification arrives. There's just
        // nothing to preview in-app beforehand that's guaranteed to match
        // it. Reworded after a beta tester's preview played Tri-Tone while
        // their actual configured default was Rebound.
        case .system:              return "Uses your device's own default alert tone when a notification arrives. Preview unavailable due to iOS system restrictions."
        }
    }
    /// Value stored server-side in `field_push_sound` so a push payload can
    /// name the right sound file — matches the RN app's NOTIFICATION_SOUND_FILE map.
    var pushSoundFile: String {
        switch self {
        case .mouseSqueak:         return "mouse_squeak.wav"
        case .appleCrunch:         return "apple_crunch.wav"
        case .goldenRetrieverBark: return "golden_retriever_bark.wav"
        case .system:              return "default"
        }
    }
}
