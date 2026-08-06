import AVFoundation
import AudioToolbox

/// UI feedback sounds bundled in Resources/Sounds. Filenames match the case names.
enum AppSound: String {
    case tabChange       = "tab_change"
    case articleOpen     = "article_open"
    case bookmarkSaved   = "bookmark_saved"
    case downloadComplete = "download_complete"
    case error
    case loadingStart    = "loading_start"
    case offline
    case pickerTick      = "picker_tick"
    case podcastPlay     = "podcast_play"
    case podcastPause    = "podcast_pause"
    case refresh
    case reply
    case screenClose     = "screen_close"
    case searchComplete  = "search_complete"
    case success
    case syncComplete    = "sync_complete"
    case tipPopup        = "tip_popup"
    case welcome

    /// Non-essential UI chrome — docs/APPLEVIS_2026_1_MASTER_SPEC.md defaults
    /// these off (tab switching, picker changes, opening screens, list
    /// refresh), gated by PreferencesStore's `interfaceSoundsEnabled`.
    fileprivate static let interfaceSounds: Set<AppSound> = [
        .tabChange, .articleOpen, .screenClose, .pickerTick, .refresh,
        .searchComplete, .tipPopup, .syncComplete, .loadingStart, .welcome,
    ]

    /// Important functional signals, not decorative preference — always play
    /// regardless of either toggle.
    fileprivate static let alwaysOn: Set<AppSound> = [.error, .offline]

    /// Reads through PreferencesStore's own property — the exact same one
    /// SwiftUI's Settings Toggle reads and writes — instead of an
    /// independent `UserDefaults.standard` lookup. The two were observed to
    /// disagree live on-device (Settings showed "Interface Sounds" on; a
    /// raw UserDefaults read of "sound.interface" still came back nil even
    /// immediately after explicitly toggling it off and back on), so this
    /// removes any chance of that drift by going through the single
    /// AppStorage-backed property both places actually use.
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
        guard sound.shouldPlay else {
            #if DEBUG
            print("SoundPlayer: skipping '\(sound.rawValue)' — shouldPlay is false")
            #endif
            return
        }
        play(filename: sound.rawValue, ext: "wav")
    }

    func playNotificationPreview(_ sound: NotificationSound) {
        switch sound {
        case .mouseSqueak:
            play(filename: "Mouse Squeak", ext: "wav")
        case .appleCrunch:
            play(filename: "Apple Crunch", ext: "wav")
        case .goldenRetrieverBark:
            play(filename: "Golden Retriever Bark", ext: "wav")
        case .system:
            AudioServicesPlaySystemSound(1007)
        }
    }

    private func play(filename: String, ext: String) {
        configureSession()

        let key = filename
        if let cached = players[key] {
            cached.currentTime = 0
            let started = cached.play()
            #if DEBUG
            print("SoundPlayer: replaying '\(filename)', started=\(started), volume=\(cached.volume), session category=\(AVAudioSession.sharedInstance().category.rawValue), sessionActive=\(AVAudioSession.sharedInstance().isOtherAudioPlaying)")
            #endif
            return
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            #if DEBUG
            print("SoundPlayer: '\(filename).\(ext)' not found in bundle")
            #endif
            return
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            #if DEBUG
            print("SoundPlayer: failed to create AVAudioPlayer for '\(filename)'")
            #endif
            return
        }
        player.prepareToPlay()
        players[key] = player
        let started = player.play()
        #if DEBUG
        print("SoundPlayer: playing '\(filename)' for the first time, started=\(started), category=\(AVAudioSession.sharedInstance().category.rawValue)")
        #endif
    }

    /// Reasserts `.ambient`/`.mixWithOthers` whenever the shared session
    /// isn't already in that state, instead of only ever configuring it
    /// once. Podcast playback (PlayerStore) switches the shared
    /// AVAudioSession to `.playback` category while an episode is loaded;
    /// once that happens, a one-time "already configured" guard here left
    /// every UI sound effect permanently, silently broken for the rest of
    /// the app session (AVAudioPlayer.play() just no-ops under the wrong
    /// category, with no error anywhere) — this was reported directly as
    /// tab-change/refresh sounds going silent, and is also the most likely
    /// cause of a separate report that a tab's VoiceOver "selected"
    /// announcement was getting cut off: an audio session/category change
    /// while VoiceOver speech is in flight can interrupt it, and skipping
    /// the reassert when the category is already correct (the common case)
    /// avoids doing that on every single sound.
    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .ambient || !session.categoryOptions.contains(.mixWithOthers) else { return }
        #if DEBUG
        print("SoundPlayer: reconfiguring session, was category=\(session.category.rawValue) options=\(session.categoryOptions.rawValue)")
        #endif
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("SoundPlayer: failed to reconfigure session: \(error)")
            #endif
        }
    }
}
