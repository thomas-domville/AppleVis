import AVFoundation
import AudioToolbox
import UIKit

/// UI feedback sounds bundled in Resources/Sounds. Filenames match the case names.
enum AppSound: String {
    case tabChange       = "tab_change"
    /// A soft pop for each tab, pitched low for Home, middle for Discover,
    /// and high for For You, so the sound says where you landed. Chosen by
    /// the user (2026-10-07). See `tabSound(for:)`.
    case tabChangeHome     = "tab_change_home"
    case tabChangeDiscover = "tab_change_discover"
    case tabChangeForYou   = "tab_change_for_you"
    case articleOpen     = "article_open"
    case bookmarkSaved   = "bookmark_saved"
    case downloadComplete = "download_complete"
    case error
    case loadingStart    = "loading_start"
    case offline
    case pickerTick      = "picker_tick"
    case podcastPlay     = "podcast_play"
    case podcastPause    = "podcast_pause"
    /// Adding an episode to the queue or Play Next: the same soft mallet
    /// as Play and Pause, so the podcast sounds are one family. Chosen by
    /// the user (2026-10-07).
    case podcastQueue    = "podcast_queue"
    /// Following something: the bookmark clip's wooden tap, then a tiny bell
    /// for "you'll hear about this". Related to Save, but easy to tell
    /// apart. Chosen by the user (2026-10-07).
    case followed        = "followed"
    /// Recommending an app: the clip's tap, then a warm, bright pair of
    /// notes, a friendly nod, a step brighter than Save and Follow.
    case recommended     = "recommended"
    /// The "off" versions: softer, and the other way round from their "on"
    /// sound, so you can tell doing from undoing (2026-10-07).
    case unsaved         = "unsaved"
    case unfollowed      = "unfollowed"
    case unrecommended   = "unrecommended"
    case refresh
    case reply
    case screenClose     = "screen_close"
    case searchComplete  = "search_complete"
    case success
    case syncComplete    = "sync_complete"
    case tipPopup        = "tip_popup"
    case welcome
    /// Ask the Mouse's once-a-second "still searching" tick, for VoiceOver
    /// users who can't see the Mouse scurrying. Confirmation tier, so it's
    /// on unless Confirmation Sounds is off.
    case mousePatter     = "mouse_patter"
    /// A soft two-note chime when a guideline reminder appears while
    /// writing, like a spelling ding: you can stop and check it, or keep
    /// going. An original sound, not one of VoiceOver's. Confirmation tier,
    /// so it's on by default. Requested directly (2026-10-06).
    case guidelineDing   = "guideline_ding"
    /// A soft, low tick once a second while a refresh is still loading,
    /// for VoiceOver users (see RefreshHeartbeat). Quieter than the
    /// Mouse's patter so the two are easy to tell apart. Original sound.
    /// Confirmation tier, so it's on by default. Requested directly
    /// (2026-10-06).
    case refreshTick     = "refresh_tick"
    /// Two quick soft notes when a Fetch group is marked read, played as
    /// VoiceOver moves straight on, instead of waiting to say "Group marked
    /// as read." Original sound. Confirmation tier. Requested directly
    /// (2026-10-07).
    case markedRead      = "marked_read"
    /// Everything is read: the last item in Fetch or New, or Mark All as
    /// Read. Goldie's nod, a happy two-note "wuff-wuff" on the mallet and a
    /// soft bell, rather than the success sound, which means "sent" or
    /// "saved". Chosen by ear (caught_up_2_goldie_wuff, 2026-10-08).
    /// Confirmation tier.
    case allCaughtUp     = "all_caught_up"
    /// VoiceOver reached the last row of a group in Fetch: the last new
    /// comment, or the post itself when there are no comments. "End of the
    /// page", a tiny paper fold and a small low bell, so you can mark the
    /// group as read before moving on. Chosen by ear (end_of_group_5_page_end,
    /// 2026-10-10). Confirmation tier.
    case endOfGroup      = "end_of_group"

    /// The tab's own pop: 0 Home, 1 Discover, 2 For You.
    static func tabSound(for tab: Int) -> AppSound {
        switch tab {
        case 0: return .tabChangeHome
        case 1: return .tabChangeDiscover
        case 2: return .tabChangeForYou
        default: return .tabChange
        }
    }

    /// Non-essential UI chrome — docs/APPLEVIS_2026_1_MASTER_SPEC.md defaults
    /// these off (tab switching, picker changes, opening screens, list
    /// refresh), gated by PreferencesStore's `interfaceSoundsEnabled`.
    fileprivate static let interfaceSounds: Set<AppSound> = [
        .tabChange, .tabChangeHome, .tabChangeDiscover, .tabChangeForYou,
        .articleOpen, .screenClose, .pickerTick, .refresh,
        .searchComplete, .tipPopup, .syncComplete, .loadingStart, .welcome,
    ]

    /// Important functional signals, not decorative preference — always play
    /// regardless of either toggle.
    fileprivate static let alwaysOn: Set<AppSound> = [.error, .offline]

    /// Reads through PreferencesStore's own property — the exact same one
    /// SwiftUI's Settings Toggle reads and writes — instead of an
    /// independent `UserDefaults.standard` lookup, so the two can never
    /// disagree with each other.
    @MainActor
    var shouldPlay: Bool {
        if Self.alwaysOn.contains(self) { return true }
        guard let preferences = PreferencesStore.current else {
            return !Self.interfaceSounds.contains(self)
        }
        return Self.interfaceSounds.contains(self)
            ? preferences.interfaceSoundsEnabled
            : preferences.confirmationSoundsEnabled
    }

    /// The haptic paired with this sound, if any. Deliberately `nil` for
    /// every `interfaceSounds` case (refresh, tab switching, picker ticks,
    /// screen open/close, etc.) — those are frequent, low-stakes chrome
    /// events, already off by default even for sound, and refresh
    /// specifically would double up on the haptic iOS's own pull-to-refresh
    /// control already fires at the pull-trigger point. Reserved for the
    /// "something happened, worth confirming" tier instead, matching each
    /// case's real-world weight rather than using one generic tap for all.
    fileprivate var haptic: (() -> Void)? {
        switch self {
        case .success, .downloadComplete:
            return { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        case .error:
            return { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        case .offline:
            return { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        case .bookmarkSaved, .reply, .podcastPlay, .podcastPause, .podcastQueue, .followed,
             .recommended, .unsaved, .unfollowed, .unrecommended:
            return { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        case .mousePatter:
            // A light tap with each tick, for braille and DeafBlind users.
            return { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }
        case .allCaughtUp:
            // Two taps, matching the "wuff-wuff", for braille and DeafBlind
            // users, who may not hear it.
            return {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.8)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.9)
                }
            }
        case .markedRead:
            // The cue for braille and DeafBlind users, who may not hear it.
            return { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8) }
        case .refreshTick:
            // The cue for braille and DeafBlind users, who may not hear it.
            return { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45) }
        case .guidelineDing:
            // The cue for braille and DeafBlind users, who may not hear it.
            return { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7) }
        case .endOfGroup:
            // A soft tap, for braille and DeafBlind users, who may not hear it.
            return { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }
        case .tabChange, .tabChangeHome, .tabChangeDiscover, .tabChangeForYou,
             .articleOpen, .loadingStart, .pickerTick, .refresh,
             .screenClose, .searchComplete, .syncComplete, .tipPopup, .welcome:
            return nil
        }
    }

    /// Same always-on/interface/confirmation split as `shouldPlay`, so
    /// haptics and sound can never disagree about which tier a given case
    /// belongs to — just gated on the separate `hapticsEnabled` toggle
    /// instead of the sound ones, since someone may want one channel
    /// without the other.
    @MainActor
    fileprivate var shouldPlayHaptic: Bool {
        guard haptic != nil else { return false }
        if Self.alwaysOn.contains(self) { return true }
        return PreferencesStore.current?.hapticsEnabled ?? true
    }
}

/// Plays short UI feedback sounds and notification-sound previews.
/// Uses the `.ambient` audio session category so playback mixes with other
/// audio and honors the silent switch, matching standard UI sound-effect behavior.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [String: AVAudioPlayer] = [:]

    private init() {}

    func play(_ sound: AppSound) {
        if sound.shouldPlayHaptic {
            sound.haptic?()
        }
        guard sound.shouldPlay else { return }
        play(filename: sound.rawValue, ext: "wav")
    }

    func playNotificationPreview(_ sound: NotificationSound) {
        switch sound {
        case .mouseSqueak:
            play(filename: "mouse_squeak", ext: "wav")
        case .appleCrunch:
            play(filename: "apple_crunch", ext: "wav")
        case .goldenRetrieverBark:
            play(filename: "golden_retriever_bark", ext: "wav")
        case .system:
            // Previously played system sound ID 1007 (a fixed Tri-Tone-like
            // alert) as if it were "the" system default — but there's no
            // per-device default to play back here at all: iOS has no API
            // exposing which alert tone a user has actually set as their
            // own default, so 1007 was frequently just wrong, not a
            // preview. A beta tester caught this directly (heard Tri-Tone,
            // their real default was Rebound). Silence here is honest;
            // NotificationSound.system's description explains why.
            break
        }
    }

    private func play(filename: String, ext: String) {
        configureSession()

        let key = filename
        if let cached = players[key] {
            cached.currentTime = 0
            cached.play()
            return
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            return
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.prepareToPlay()
        players[key] = player
        player.play()
    }

    /// Reasserts `.ambient`/`.mixWithOthers` whenever the shared session
    /// isn't already in that state, instead of only ever configuring it
    /// once. Podcast playback (PlayerStore) switches the shared
    /// AVAudioSession to `.playback` category while an episode is loaded;
    /// once that happens, a one-time "already configured" guard here left
    /// every UI sound effect permanently, silently broken for the rest of
    /// the app session (AVAudioPlayer.play() just no-ops under the wrong
    /// category, with no error anywhere).
    private func configureSession() {
        // Never reassert .ambient while a podcast episode is loaded — PlayerStore
        // sets the shared session to .playback/.spokenAudio, and every play/pause
        // (including Lock Screen remote commands) plays a confirmation sound here.
        // Resetting the category on every one of those calls silently downgraded
        // playback away from background/Lock-Screen eligibility on the first pause.
        guard PlayerStore.current?.currentEpisode == nil else { return }
        let session = AVAudioSession.sharedInstance()
        guard session.category != .ambient || !session.categoryOptions.contains(.mixWithOthers) else { return }
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
