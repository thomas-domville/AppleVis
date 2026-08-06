import AVFoundation
import MediaPlayer
import Combine
import SwiftUI

@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var currentEpisode: PodcastEpisode?
    @Published private(set) var queue: [PodcastEpisode] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentChapter: Chapter?
    @Published private(set) var errorMessage: String?
    @Published private(set) var sleepTimerRemaining: TimeInterval?
    @Published private(set) var sleepAtEndOfEpisode = false
    @Published var playbackSpeed: Float {
        didSet { didSetPlaybackSpeed(oldValue) }
    }
    @Published var volume: Float {
        didSet { didSetVolume(oldValue) }
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var sleepTimer: Timer?

    // Per-episode saved playback position, in seconds.
    private var positions: [String: TimeInterval] = [:]

    init() {
        playbackSpeed = Float(UserDefaults.standard.object(forKey: Self.speedKey) as? Double ?? 1.0)
        volume = Float(UserDefaults.standard.object(forKey: Self.volumeKey) as? Double ?? 1.0)
        restoreQueue()
        restorePositions()
        restoreLastPlayed()
        observeLifecycle()
        observePlaybackSpeedPreference()
        observeAudioEffectsPreferences()
        AudioEffectsProcessor.shared.onSilenceSkip = { [weak self] seconds in
            Task { await self?.skip(by: seconds) }
        }
    }

    // MARK: - Playback control

    /// Loads and plays an episode. If this episode is already current and has
    /// an active player, just resumes/toggles instead of restarting from zero.
    func load(_ episode: PodcastEpisode, startTime: TimeInterval? = nil) async {
        if currentEpisode?.id == episode.id, player != nil {
            if !isPlaying { play() }
            return
        }

        savePositionOfCurrentEpisode()

        let resolvedStart: TimeInterval
        if let startTime {
            resolvedStart = startTime
        } else if let saved = positions[episode.id], saved > 0 {
            let rewind = TimeInterval(UserDefaults.standard.integer(forKey: "podcast.resumeRewind"))
            resolvedStart = max(0, saved - rewind)
        } else {
            resolvedStart = 0
        }

        guard let url = DownloadManager.shared.localURL(for: episode.id) ?? URL(string: episode.audioUrl) else {
            errorMessage = "This episode doesn't have a playable audio file."
            return
        }

        await setupAudioSession()
        player?.pause()
        removeTimeObserver()
        errorMessage = nil
        isBuffering = true
        currentChapter = nil

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        // Recommended for spoken-word content — keeps pitch natural at
        // non-1.0x playback rates instead of the classic "chipmunk" effect.
        item.audioTimePitchAlgorithm = .timeDomain

        // Voice Boost/Equaliser/Trim Silence run through this tap. Track
        // loading is async even for local files, so this can't block ahead
        // of AVPlayer construction — set audioMix as soon as it resolves;
        // if it resolves after playback starts, AVPlayerItem picks it up
        // on the next render pass rather than requiring a restart.
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
            item.audioMix = AudioEffectsProcessor.shared.makeAudioMix(for: audioTrack)
        }

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = volume
        player = newPlayer
        currentEpisode = episode
        position = resolvedStart
        duration = episode.duration ?? 0

        if resolvedStart > 0 {
            await newPlayer.seek(to: CMTime(seconds: resolvedStart, preferredTimescale: 600))
        }

        observeTime()
        observeDidFinish()
        observeBuffering()
        updateNowPlayingInfo(episode: episode)
        setupRemoteCommands()

        newPlayer.rate = playbackSpeed
        isPlaying = true
        saveLastPlayed()
    }

    func play() {
        guard player != nil else {
            // Restored on launch without an active AVPlayer yet — lazily load.
            if let episode = currentEpisode {
                Task { await load(episode, startTime: position) }
            }
            return
        }
        player?.rate = playbackSpeed
        isPlaying = true
        updateNowPlayingPlaybackState()
        SoundPlayer.shared.play(.podcastPlay)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        savePositionOfCurrentEpisode()
        updateNowPlayingPlaybackState()
        SoundPlayer.shared.play(.podcastPause)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Fully stops playback and dismisses the mini player — distinct from
    /// `pause()`, which keeps the episode loaded so it can resume. The old
    /// app's mini player has an explicit "Stop and dismiss" action; without
    /// this there was no way to clear the mini player short of loading a
    /// different episode, so it stayed pinned to the bottom of every tab
    /// indefinitely once anything had ever played.
    func stop() {
        pause()
        removeTimeObserver()
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentEpisode = nil
        position = 0
        duration = 0
        currentChapter = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        // Deliberately does NOT deactivate the shared AVAudioSession: doing
        // so broke every UI sound effect app-wide (SoundPlayer configures
        // its session once and never re-activates it, so once this
        // deactivated it, .ambient playback silently stopped working for
        // the rest of the app session with no error). Clearing playback
        // state and Now Playing info is enough to fully "stop" from the
        // user's perspective without that side effect.
    }

    func seek(to time: TimeInterval) async {
        await player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        position = time
        savePositionOfCurrentEpisode()
    }

    func skip(by seconds: TimeInterval) async {
        let target = max(0, min(position + seconds, duration))
        await seek(to: target)
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
    }

    func setVolume(_ v: Float) {
        volume = max(0, min(1, v))
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

    func clearQueue() {
        queue.removeAll()
        saveQueue()
    }

    func playNext() async {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        saveQueue()
        await load(next)
    }

    // MARK: - Sleep timer

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        sleepAtEndOfEpisode = false
        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickSleepTimer() }
        }
    }

    func startSleepTimerAtEndOfEpisode() {
        cancelSleepTimer()
        sleepAtEndOfEpisode = true
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = nil
        sleepAtEndOfEpisode = false
    }

    private func tickSleepTimer() {
        guard let remaining = sleepTimerRemaining else { return }
        if remaining <= 1 {
            pause()
            cancelSleepTimer()
        } else {
            sleepTimerRemaining = remaining - 1
        }
    }

    // MARK: - Now Playing / Lock Screen

    private func updateNowPlayingInfo(episode: PodcastEpisode) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.showTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: Double(playbackSpeed),
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        guard let artUrl = episode.artworkUrl.flatMap(URL.init) else { return }
        Task.detached {
            guard let (data, _) = try? await URLSession.shared.data(from: artUrl),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }
    }

    private func updateNowPlayingPlaybackState() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.playCommand.addTarget { [weak self] _ in self?.play(); return .success }

        center.pauseCommand.removeTarget(nil)
        center.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }

        center.togglePlayPauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }

        let skipBack = UserDefaults.standard.object(forKey: "podcast.skipBack") as? Double ?? 10
        let skipForward = UserDefaults.standard.object(forKey: "podcast.skipForward") as? Double ?? 30

        center.skipBackwardCommand.removeTarget(nil)
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBack)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            let interval = UserDefaults.standard.object(forKey: "podcast.skipBack") as? Double ?? 10
            Task { await self?.skip(by: -interval) }; return .success
        }

        center.skipForwardCommand.removeTarget(nil)
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForward)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            let interval = UserDefaults.standard.object(forKey: "podcast.skipForward") as? Double ?? 30
            Task { await self?.skip(by: interval) }; return .success
        }

        center.nextTrackCommand.removeTarget(nil)
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { await self?.playNext() }; return .success
        }

        // Matches platform convention (e.g. Podcasts/Music): previous restarts
        // the current episode, since there's no "previous episode" history stack.
        center.previousTrackCommand.removeTarget(nil)
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { await self?.seek(to: 0) }; return .success
        }

        center.changePlaybackPositionCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { await self?.seek(to: event.positionTime) }
            return .success
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
            MainActor.assumeIsolated {
                self?.position = time.seconds
                if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                    self?.duration = duration
                }
                self?.updateCurrentChapter()
            }
        }
    }

    /// Announces the chapter title and number as playback crosses into it —
    /// docs/APPLEVIS_2026_1_MASTER_SPEC.md's VoiceOver requirements
    /// explicitly call for this; previously chapters were only browsable
    /// from the episode detail page, with nothing surfaced during playback.
    private func updateCurrentChapter() {
        guard let chapters = currentEpisode?.chapters, !chapters.isEmpty else {
            currentChapter = nil
            return
        }
        let match = chapters.first { position >= $0.startTime && position < $0.endTime }
        guard match?.id != currentChapter?.id else { return }
        currentChapter = match
        if let match, let index = chapters.firstIndex(where: { $0.id == match.id }) {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Chapter \(index + 1) of \(chapters.count): \(match.title)."
            )
        }
    }

    private func observeBuffering() {
        statusCancellable = player?.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
    }

    private func observeDidFinish() {
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                if let episode = self.currentEpisode {
                    DownloadManager.shared.markPlayCompleted(episode.id)
                }
                if self.sleepAtEndOfEpisode {
                    self.pause()
                    self.cancelSleepTimer()
                    return
                }
                guard UserDefaults.standard.object(forKey: "podcast.autoPlay") as? Bool ?? true else { return }
                Task { await self.playNext() }
            }
            .store(in: &cancellables)
    }

    private func removeTimeObserver() {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        timeObserver = nil
        statusCancellable = nil
    }

    private func didSetPlaybackSpeed(_ oldValue: Float) {
        guard oldValue != playbackSpeed else { return }
        UserDefaults.standard.set(Double(playbackSpeed), forKey: Self.speedKey)
        if isPlaying { player?.rate = playbackSpeed }
        updateNowPlayingPlaybackState()
    }

    private func didSetVolume(_ oldValue: Float) {
        guard oldValue != volume else { return }
        UserDefaults.standard.set(Double(volume), forKey: Self.volumeKey)
        player?.volume = volume
    }

    /// PreferencesStore's Settings speed picker and this store's own in-player
    /// speed control share the "podcast.speed" UserDefaults key but are
    /// separate in-memory @Published/@AppStorage values with no built-in link.
    /// This keeps them in sync so a change in Settings actually affects
    /// playback immediately (and vice versa) instead of only on next launch.
    private func observePlaybackSpeedPreference() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let stored = Float(UserDefaults.standard.object(forKey: Self.speedKey) as? Double ?? 1.0)
                if stored != self.playbackSpeed {
                    self.playbackSpeed = stored
                }
            }
            .store(in: &cancellables)
    }

    /// Mirrors PodcastSettingsView's Audio Enhancement toggles/picker into
    /// AudioEffectsProcessor, which only reads plain properties (it can't
    /// hold an @AppStorage/EnvironmentObject reference — it runs on the
    /// real-time audio thread, not in SwiftUI). Same sync-via-UserDefaults-
    /// notification approach as observePlaybackSpeedPreference().
    private func observeAudioEffectsPreferences() {
        func sync() {
            let defaults = UserDefaults.standard
            AudioEffectsProcessor.shared.voiceBoostEnabled = defaults.bool(forKey: "podcast.voiceBoost")
            AudioEffectsProcessor.shared.trimSilenceEnabled = defaults.bool(forKey: "podcast.trimSilence")
            AudioEffectsProcessor.shared.eqPreset = (defaults.string(forKey: "podcast.eq")).flatMap(PodcastEQ.init(rawValue:)) ?? .flat
        }
        sync()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { _ in sync() }
            .store(in: &cancellables)
    }

    private func observeLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.savePositionOfCurrentEpisode()
                self?.saveLastPlayed()
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private static let queueKey = "applevis.playerQueue"
    private static let positionsKey = "applevis.playbackPositions"
    private static let lastPlayedKey = "applevis.lastPlayed"
    private static let speedKey = "podcast.speed"
    private static let volumeKey = "applevis.playerVolume"

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: Self.queueKey)
        }
        ICloudSyncManager.shared.pushQueue(queue)
    }

    /// Adopts a queue pulled from iCloud (another device added/reordered episodes).
    func applyPulledQueue(_ pulled: [PodcastEpisode]) {
        queue = pulled
        saveQueue()
    }

    /// Adopts playback positions pulled from iCloud, keeping whichever is
    /// further along for episodes present on both sides.
    func applyPulledPositions(_ pulled: [String: TimeInterval]) {
        for (id, time) in pulled {
            positions[id] = max(positions[id] ?? 0, time)
        }
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: Self.positionsKey)
        }
    }

    private func restoreQueue() {
        guard let data = UserDefaults.standard.data(forKey: Self.queueKey),
              let restored = try? JSONDecoder().decode([PodcastEpisode].self, from: data) else { return }
        queue = restored
    }

    private func savePositionOfCurrentEpisode() {
        guard let episode = currentEpisode else { return }
        positions[episode.id] = position
        if let data = try? JSONEncoder().encode(positions) {
            UserDefaults.standard.set(data, forKey: Self.positionsKey)
        }
        ICloudSyncManager.shared.pushPodcastPositions(positions)
    }

    private func restorePositions() {
        guard let data = UserDefaults.standard.data(forKey: Self.positionsKey),
              let restored = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else { return }
        positions = restored
    }

    private struct LastPlayed: Codable {
        let episode: PodcastEpisode
        let position: TimeInterval
    }

    private func saveLastPlayed() {
        guard let episode = currentEpisode else { return }
        if let data = try? JSONEncoder().encode(LastPlayed(episode: episode, position: position)) {
            UserDefaults.standard.set(data, forKey: Self.lastPlayedKey)
        }
    }

    /// Restores the last-played episode's metadata and position on launch
    /// WITHOUT creating an `AVPlayer` or starting playback — actual audio
    /// loading is deferred until the user taps play (see `play()`).
    private func restoreLastPlayed() {
        guard let data = UserDefaults.standard.data(forKey: Self.lastPlayedKey),
              let restored = try? JSONDecoder().decode(LastPlayed.self, from: data) else { return }
        currentEpisode = restored.episode
        position = restored.position
        duration = restored.episode.duration ?? 0
    }
}
