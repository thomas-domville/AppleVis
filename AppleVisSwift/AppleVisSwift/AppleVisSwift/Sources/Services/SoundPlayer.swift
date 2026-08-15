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
        guard sound.shouldPlay else { return }
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
