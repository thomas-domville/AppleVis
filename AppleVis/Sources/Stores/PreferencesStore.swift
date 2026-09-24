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
    @AppStorage("feed.appleOnly")    var appleOnlyForums = true

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
    // Detailed, not Helpful — Requested directly: a plain "Welcome back"
    // with no idea what actually changed since your last visit wasn't
    // pulling its weight as the default; the AI-generated summary is the
    // more genuinely useful first impression, and it already degrades to
    // the same short welcome Helpful gives when there's nothing new to
    // report, so nobody's worse off on a quiet day.
    @AppStorage("a11y.homeStartup")     var homeStartupBehavior: HomeStartupBehavior = .detailed
    // Defaults off — auto-raising the keyboard whenever Discover's Search
    // tab is opened meant a VoiceOver user who just wanted to browse the
    // hub grid had to dismiss the keyboard first every time. Reported
    // directly. Still available as an opt-in for anyone who prefers landing
    // straight in Search.
    @AppStorage("a11y.searchAutoFocus") var searchAutoFocusEnabled = false
    /// Whether Home's What's New card, the New/Recap picker, and per-row "N
    /// new" badges get shown — not whether reading history is tracked,
    /// which now always happens regardless (see
    /// `PersistenceStore.showsNewActivityIndicators`'s doc comment for why
    /// these used to be the same on/off switch and no longer are).
    @AppStorage("privacy.signedOutHistory") var showNewActivityIndicators = true
    /// Masks a wider set of profanity than AppleVis blocks from posting —
    /// see `ProfanityFilter`'s doc comment for why this defaults to *on*
    /// rather than opt-in: a default-off filter wouldn't actually protect
    /// anyone who never finds the setting, which defeats the point of
    /// having it. Purely a display preference; never affects what a user is
    /// allowed to post themselves, which `ContentSubmissionPolicy` enforces
    /// unconditionally regardless of this setting.
    @AppStorage("privacy.filterProfanity") var filterProfanity = true
    /// Remembers the last email address a signed-out guest typed into
    /// Contact Us or Report a Comment, purely so returning guests don't have
    /// to retype it every time — signed-in users never touch this, since
    /// their account email comes from AuthUser.email instead. Stored locally
    /// only, never sent anywhere on its own; cleared by "Clear All Local
    /// Data" in Settings > Privacy like other on-device convenience data.
    @AppStorage("privacy.lastGuestEmail") var lastGuestEmail = ""

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

    // MARK: - Content Translation
    // Reading-side translation (blog/forum/app/podcast/guide/bug content,
    // comments, and Help articles, via Apple's on-device Translation
    // framework) — separate from the "Intelligence" block above, which is
    // the opposite-direction, hardware-gated "translate my draft to English
    // before I post" feature. This one has no hardware requirement, so it
    // gets its own explicit opt-in rather than living under Intelligence,
    // where it would misleadingly imply the same Apple Intelligence gate.
    /// Off by default — opt-in via the launch prompt or Settings, never on
    /// without the user having chosen it.
    @AppStorage("content.autoTranslateEnabled")  var autoTranslateEnabled = false
    /// BCP-47 language code (e.g. "fr"); empty means "not yet chosen." Kept
    /// independent of the device's system language so a multilingual reader
    /// can pick a different content language than their UI language.
    @AppStorage("content.translationLanguage")   var contentLanguageCode = ""
    /// One-time gate for the launch-time opt-in prompt — set on either
    /// "Turn On Auto-Translate" or "Not Now" so it's never asked twice;
    /// Settings remains the permanent way to turn this on/off afterward.
    @AppStorage("content.launchPromptShown")     var contentTranslationPromptShown = false

    /// The single value every translation call site should branch on,
    /// collapsing "auto-translate is off" and "no language chosen yet" into
    /// one nil-check instead of two independently-duplicated conditions.
    var effectiveContentLanguage: String? {
        autoTranslateEnabled && !contentLanguageCode.isEmpty ? contentLanguageCode : nil
    }

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
        case .standard:     return String(localized: "Standard")
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
        case .system:            return String(localized: "System")
        case .oppositeToSystem: return String(localized: "System (Inverted)")
        case .light:              return String(localized: "Light")
        case .dark:                return String(localized: "Dark")
        case .midnight:           return "Midnight"
        case .warm:               return String(localized: "Warm")
        case .sepia:              return String(localized: "Sepia")
        case .applevisClassic:   return String(localized: "AppleVis Classic")
        case .mouseLight:        return String(localized: "Mouse — Light")
        case .mouseDark:         return String(localized: "Mouse — Dark")
        case .orchard:            return String(localized: "Orchard")
        // Was "Golden Gate" — Apple's own macOS 26 code name, and not
        // worth the trademark risk for a theme name with no real
        // connection to it beyond both evoking San Francisco. Reported
        // directly by a beta tester. The `goldenGate` case name itself is
        // untouched — it's what `@AppStorage` actually persists, so
        // renaming it would silently reset this specific choice back to
        // the default for anyone who'd already picked it.
        case .goldenGate:        return String(localized: "Cupertino Sunset")
        case .nebula:             return String(localized: "Nebula")
        case .highContrastLight: return String(localized: "High Contrast Light")
        case .highContrastDark:  return String(localized: "High Contrast Dark")
        }
    }

    var subtitle: String {
        switch self {
        case .system:            return String(localized: "Follows iOS appearance setting")
        case .oppositeToSystem: return String(localized: "Always the opposite of your iOS appearance")
        case .light:              return String(localized: "Always uses light colours")
        case .dark:                return String(localized: "Always uses dark colours")
        case .midnight:           return String(localized: "Deep black background for low-light use")
        case .warm:               return String(localized: "Soft cream and amber tones that reduce blue light")
        case .sepia:              return String(localized: "Warm, low-glare tones for extended reading")
        case .applevisClassic:   return String(localized: "The blue and white scheme from applevis.com")
        case .mouseLight:        return String(localized: "Warm, playful theme inspired by AnonyMouse")
        case .mouseDark:         return String(localized: "The Mouse theme in a warm charcoal dark edition")
        case .orchard:            return String(localized: "Fresh apple greens and deep reds")
        case .goldenGate:        return String(localized: "Warm California sunset tones")
        case .nebula:             return String(localized: "Deep indigo and soft lavender, space-inspired")
        case .highContrastLight: return String(localized: "Maximum contrast on a light background")
        case .highContrastDark:  return String(localized: "Maximum contrast on a dark background")
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
        case .inApp:    return String(localized: "In-App Browser")
        case .external: return String(localized: "Default Browser")
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
        case .simple: return String(localized: "Simple")
        case .normal: return String(localized: "Normal")
        case .all:    return String(localized: "All Details")
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
        case .simple: return String(localized: "\"iOS 18 VoiceOver Tips, iOS and iPadOS topic.\"")
        case .normal: return String(localized: "\"iOS 18 VoiceOver Tips, iOS and iPadOS topic, by JaneD, 14 comments.\"")
        case .all:    return String(localized: "\"iOS 18 VoiceOver Tips, iOS and iPadOS topic, by JaneD, 14 comments, 2 days ago.\"")
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
        case .flat:        return String(localized: "Flat")
        case .speech:      return String(localized: "Speech Clarity")
        case .bassBoost:   return String(localized: "Bass Boost")
        case .trebleBoost: return String(localized: "Treble Boost")
        }
    }
}

enum PodcastAutoDownload: String, CaseIterable, Identifiable {
    case off, wifiOnly, always
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off:      return "Off"
        case .wifiOnly: return String(localized: "Wi-Fi Only")
        case .always:   return String(localized: "Always")
        }
    }
}

enum PodcastAutoDelete: String, CaseIterable, Identifiable {
    case off, immediate, oneDay, threeDays, sevenDays
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off:        return "Off"
        case .immediate:  return String(localized: "Immediately After Playing")
        case .oneDay:     return String(localized: "After 1 Day")
        case .threeDays:  return String(localized: "After 3 Days")
        case .sevenDays:  return String(localized: "After 7 Days")
        }
    }
}

enum NotificationSound: String, CaseIterable, Identifiable {
    case mouseSqueak, appleCrunch, goldenRetrieverBark, system
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mouseSqueak:         return String(localized: "Mouse Squeak")
        case .appleCrunch:         return String(localized: "Apple Crunch")
        case .goldenRetrieverBark: return String(localized: "Golden Retriever Bark")
        case .system:              return String(localized: "System Default")
        }
    }
    var description: String {
        switch self {
        case .mouseSqueak:         return String(localized: "The AppleVis signature sound, soft and distinctive.")
        case .appleCrunch:         return String(localized: "A crisp apple crunch.")
        case .goldenRetrieverBark: return String(localized: "A friendly golden retriever bark, warm and cheerful.")
        // iOS has no API for a third-party app to read or play back
        // exactly which alert tone a user has personally set as their
        // device default — this sends "default" in the push payload,
        // which does correctly tell the system to use whatever that tone
        // actually is when a real notification arrives. There's just
        // nothing to preview in-app beforehand that's guaranteed to match
        // it. Reworded after a beta tester's preview played Tri-Tone while
        // their actual configured default was Rebound.
        case .system:              return String(localized: "Uses your device's own default alert tone when a notification arrives. Preview unavailable due to iOS system restrictions.")
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
