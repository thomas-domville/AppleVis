import SwiftUI
import Combine

@MainActor
final class PreferencesStore: ObservableObject {

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

    // MARK: - Accessibility
    @AppStorage("a11y.reducedMotion")   var reducedMotion   = false
    @AppStorage("a11y.largerText")      var largerText      = false
    @AppStorage("a11y.announcement")    var announcementLevel: AnnouncementLevel = .normal
    @AppStorage("a11y.helpfulTips")     var helpfulTipsEnabled = true
    @AppStorage("a11y.welcomeSummary")  var welcomeSummaryEnabled = true
    @AppStorage("a11y.homeStartup")     var homeStartupBehavior: HomeStartupBehavior = .helpful
    @AppStorage("a11y.searchAutoFocus") var searchAutoFocusEnabled = true

    // MARK: - Forums
    @AppStorage("forums.defaultFilter") var forumsDefaultFilter: ForumFilter = .recent

    // MARK: - Intelligence / Smart Features
    @AppStorage("intel.nonEnglish")         var nonEnglishDetectionEnabled = true
    @AppStorage("intel.composeRewrite")     var composeRewriteEnabled = true
    @AppStorage("intel.composeTranslation") var composeTranslationEnabled = true
    @AppStorage("intel.searchTranslation")  var searchTranslationEnabled = true
    @AppStorage("intel.aiSummaries")        var aiSummariesEnabled = true

    // MARK: - iCloud Sync
    @AppStorage("sync.iCloud")          var iCloudSync = true
    @AppStorage("sync.savedItems")      var savedItemsSync = true
    @AppStorage("sync.readingPosition") var readingPositionSync = true
    @AppStorage("sync.podcastPosition") var podcastPositionSync = true
    @AppStorage("sync.queue")           var queueSync = true
    @AppStorage("sync.settings")        var settingsSync = true
}

// MARK: - Enums

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark, sepia, midnight, highContrastLight, highContrastDark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:            return "System"
        case .light:              return "Light"
        case .dark:                return "Dark"
        case .sepia:              return "Sepia"
        case .midnight:           return "Midnight"
        case .highContrastLight: return "High Contrast Light"
        case .highContrastDark:  return "High Contrast Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system:            return "Follows iOS appearance setting"
        case .light:              return "Always uses light colours"
        case .dark:                return "Always uses dark colours"
        case .sepia:              return "Warm, low-glare tones for extended reading"
        case .midnight:           return "Deep black background for low-light use"
        case .highContrastLight: return "Maximum contrast on a light background"
        case .highContrastDark:  return "Maximum contrast on a dark background"
        }
    }

    /// The underlying light/dark base every theme renders on top of —
    /// SwiftUI has no native "sepia" scheme, so themes differentiate via
    /// this base plus `accentColor` below.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:            return nil
        case .light, .sepia, .highContrastLight: return .light
        case .dark, .midnight, .highContrastDark: return .dark
        }
    }

    var accentColor: Color {
        switch self {
        case .system, .light, .dark: return .accentColor
        case .sepia:              return Color(red: 0.55, green: 0.38, blue: 0.20)
        case .midnight:           return Color(red: 0.30, green: 0.55, blue: 1.0)
        case .highContrastLight: return .black
        case .highContrastDark:  return .yellow
        }
    }
}

enum CardDensity: String, CaseIterable, Identifiable {
    case comfortable, compact
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var verticalPadding: CGFloat { self == .compact ? 2 : 6 }
}

enum ForumFilter: String, CaseIterable, Identifiable {
    case recent, appleOnly
    var id: String { rawValue }
    var displayName: String { self == .recent ? "All Recent" : "Apple Only" }
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
}
