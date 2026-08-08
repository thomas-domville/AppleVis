import SwiftUI
import Combine

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
    var colorScheme: ColorScheme? { theme.colorScheme }
    @AppStorage("appearance.cardDensity") var cardDensity: CardDensity = .comfortable

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
    @AppStorage("podcast.resumeRewind") var resumeRewindSeconds: Int = 0
    @AppStorage("podcast.trimSilence")  var trimSilence = false
    @AppStorage("podcast.voiceBoost")   var voiceBoost = false
    @AppStorage("podcast.eq")           var podcastEQ: PodcastEQ = .flat
    @AppStorage("podcast.autoDownload") var autoDownload: PodcastAutoDownload = .off
    @AppStorage("podcast.autoDelete")   var autoDelete: PodcastAutoDelete = .off

    // MARK: - Notifications (granular)
    @AppStorage("notif.forumReplies")   var notifyForumReplies  = false
    @AppStorage("notif.mentions")       var notifyMentions       = false
    @AppStorage("notif.newTopics")      var notifyNewTopics      = true
    @AppStorage("notif.followedTopics") var notifyFollowedTopics = false
    @AppStorage("notif.newEpisodes")    var notifyNewEpisodes    = true
    @AppStorage("notif.appUpdates")     var notifyAppUpdates     = false
    @AppStorage("notif.newResources")   var notifyNewResources   = false
    @AppStorage("notif.announcements")  var notifyAnnouncements  = true
    @AppStorage("notif.sound")          var notificationSound: NotificationSound = .mouseSqueak
    /// RN's `notifBadge` ("Shows a number on the AppleVis icon... tap the
    /// app and the badge clears") had no Swift equivalent at all.
    @AppStorage("notif.badgeCount")     var badgeCountEnabled    = true

    // MARK: - Accessibility
    @AppStorage("a11y.announcement")    var announcementLevel: AnnouncementLevel = .normal
    @AppStorage("a11y.helpfulTips")     var helpfulTipsEnabled = true
    @AppStorage("a11y.welcomeSummary")  var welcomeSummaryEnabled = true
    @AppStorage("a11y.homeStartup")     var homeStartupBehavior: HomeStartupBehavior = .helpful
    @AppStorage("a11y.searchAutoFocus") var searchAutoFocusEnabled = true

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
    @AppStorage("sync.settings")        var settingsSync = true
}

// MARK: - Enums

enum ThemeGroup: String, CaseIterable, Identifiable {
    case standard, appleVis, accessibility
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard:     return "Standard"
        case .appleVis:     return "AppleVis"
        case .accessibility: return "Accessibility"
        }
    }
}

/// 13 fixed themes plus System, across three groups — Standard, AppleVis, Accessibility.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark, midnight, warm, sepia
    case applevisClassic, mouseLight, mouseDark, orchard, goldenGate, nebula
    case highContrastLight, highContrastDark

    var id: String { rawValue }

    var group: ThemeGroup {
        switch self {
        case .system, .light, .dark, .midnight, .warm, .sepia:
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
        case .light:              return "Light"
        case .dark:                return "Dark"
        case .midnight:           return "Midnight"
        case .warm:               return "Warm"
        case .sepia:              return "Sepia"
        case .applevisClassic:   return "AppleVis Classic"
        case .mouseLight:        return "Mouse — Light"
        case .mouseDark:         return "Mouse — Dark"
        case .orchard:            return "Orchard"
        case .goldenGate:        return "Golden Gate"
        case .nebula:             return "Nebula"
        case .highContrastLight: return "High Contrast Light"
        case .highContrastDark:  return "High Contrast Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system:            return "Follows iOS appearance setting"
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
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .warm, .sepia, .applevisClassic, .mouseLight, .orchard, .goldenGate, .highContrastLight:
            return .light
        case .dark, .midnight, .mouseDark, .nebula, .highContrastDark:
            return .dark
        }
    }

    var accentColor: Color {
        switch self {
        case .system, .light, .dark: return .accentColor
        case .midnight:           return Color(red: 0.30, green: 0.55, blue: 1.0)
        case .warm:               return Color(red: 0.757, green: 0.490, blue: 0.169)
        case .sepia:              return Color(red: 0.55, green: 0.38, blue: 0.20)
        case .applevisClassic:   return Color(red: 0.039, green: 0.373, blue: 1.0)
        case .mouseLight, .mouseDark: return Color(red: 0.961, green: 0.651, blue: 0.137)
        case .orchard:            return Color(red: 0.800, green: 0.200, blue: 0.200)
        case .goldenGate:        return Color(red: 1.0, green: 0.420, blue: 0.169)
        case .nebula:             return Color(red: 0.655, green: 0.545, blue: 0.980)
        case .highContrastLight: return .black
        case .highContrastDark:  return .yellow
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
    var preview: String {
        switch self {
        case .simple: return "\"iOS 18 VoiceOver Tips. Forum.\""
        case .normal: return "\"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments.\""
        case .all:    return "\"iOS 18 VoiceOver Tips. Forum. By JaneD. 14 comments. Posted 2 days ago.\""
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
        case .system:              return "Your iPhone's standard notification tone."
        }
    }
    /// Value stored server-side in `field_push_sound` so a push payload can
    /// name the right sound file — matches the RN app's NOTIFICATION_SOUND_FILE map.
    var pushSoundFile: String {
        switch self {
        case .mouseSqueak:         return "Mouse Squeak.wav"
        case .appleCrunch:         return "Apple Crunch.wav"
        case .goldenRetrieverBark: return "Golden Retriever Bark.wav"
        case .system:              return "default"
        }
    }
}
