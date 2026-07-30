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
}

/// Plays short UI feedback sounds and notification-sound previews.
/// Uses the `.ambient` audio session category so playback mixes with other
/// audio and honors the silent switch, matching standard UI sound-effect behavior.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [String: AVAudioPlayer] = [:]
    private var sessionConfigured = false

    private init() {}

    func play(_ sound: AppSound) {
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
        configureSessionIfNeeded()

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

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
