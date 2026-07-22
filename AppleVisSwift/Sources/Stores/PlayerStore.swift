import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var currentEpisode: PodcastEpisode?
    @Published private(set) var queue: [PodcastEpisode] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Playback control

    func load(_ episode: PodcastEpisode, startTime: TimeInterval = 0) async {
        guard let url = URL(string: episode.audioUrl) else { return }

        await setupAudioSession()
        player?.pause()
        removeTimeObserver()

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        currentEpisode = episode
        position = startTime
        duration = episode.duration ?? 0

        if startTime > 0 {
            await player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        }

        observeTime()
        observeDidFinish()
        updateNowPlayingInfo(episode: episode)
        setupRemoteCommands()

        player?.play()
        isPlaying = true
    }

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) async {
        await player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        position = time
    }

    func skip(by seconds: TimeInterval) async {
        let target = max(0, min(position + seconds, duration))
        await seek(to: target)
    }

    // MARK: - Queue

    func enqueue(_ episode: PodcastEpisode) {
        guard !queue.contains(where: { $0.id == episode.id }) else { return }
        queue.append(episode)
        saveQueue()
    }

    func removeFromQueue(id: String) {
        queue.removeAll { $0.id == id }
        saveQueue()
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        saveQueue()
    }

    func playNext() async {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        saveQueue()
        await load(next)
    }

    // MARK: - Now Playing / Lock Screen

    private func updateNowPlayingInfo(episode: PodcastEpisode) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:           episode.title,
            MPMediaItemPropertyArtist:          episode.showTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: Double(playbackSpeed),
        ]
        if let artUrl = episode.artworkUrl.flatMap(URL.init),
           let data = try? Data(contentsOf: artUrl),
           let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackState() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.play(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { await self?.skip(by: -15) }; return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { await self?.skip(by: 30) }; return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { await self?.playNext() }; return .success
        }
    }

    // MARK: - Private helpers

    private func setupAudioSession() async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func observeTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.position = time.seconds
            if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                self?.duration = duration
            }
        }
    }

    private func observeDidFinish() {
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
            .sink { [weak self] _ in
                Task { await self?.playNext() }
            }
            .store(in: &cancellables)
    }

    private func removeTimeObserver() {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        timeObserver = nil
    }

    // MARK: - Persistence

    private let queueKey = "applevis.playerQueue"

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    private func restoreQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let restored = try? JSONDecoder().decode([PodcastEpisode].self, from: data) else { return }
        queue = restored
    }
}
