import Foundation
import Combine

struct DownloadedEpisodeMeta: Codable {
    let id: String
    let title: String
    let showTitle: String
    let downloadedAt: Date
    var fileSizeBytes: Int64
    var playCompletedAt: Date? = nil
}

/// Downloads podcast episodes for offline playback. Not `@MainActor` — the
/// `URLSessionDownloadDelegate` callbacks arrive on a background queue, and
/// `@Published` mutations are explicitly hopped to the main thread instead of
/// isolating the whole type (avoids cross-actor friction with the delegate
/// protocol, whose methods can't themselves be actor-isolated).
/// A download that ended in failure — screens observing `DownloadManager`
/// can react to this to tell the user, instead of the progress indicator
/// just silently reverting with no explanation (reported directly: this was
/// indistinguishable from the download never having been requested at all).
struct DownloadFailure: Equatable {
    let episodeId: String
    let episodeTitle: String
}

final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedEpisodeIds: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]
    @Published private(set) var activeDownloads: Set<String> = []
    @Published private(set) var lastFailure: DownloadFailure? = nil

    private var metadata: [String: DownloadedEpisodeMeta] = [:]
    private var tasks: [String: URLSessionDownloadTask] = [:]
    /// A background session, not `.default` — a foreground session's
    /// in-flight downloads stall or die as soon as the app is backgrounded
    /// or suspended, a completely normal thing to happen mid-download
    /// (PODCAST-02). The identifier must stay stable across launches: the OS
    /// relaunches the app in the background under this exact identifier to
    /// deliver completion events, which is why `DownloadManager.shared` is
    /// deliberately touched from `AppleVisAppDelegate.didFinishLaunching`
    /// (not just lazily on first UI access) so the session reattaches
    /// immediately even on a silent background relaunch.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.applevis.AppleVisSwift.podcastDownloads")
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    /// Stashed by `AppleVisAppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`;
    /// called once `urlSessionDidFinishEvents(forBackgroundURLSession:)`
    /// confirms every queued delegate callback for this background session
    /// has been delivered, telling the OS it can suspend the app again.
    var backgroundSessionCompletionHandler: (() -> Void)?

    private let metadataKey = "applevis.downloads.metadata.v1"

    private var downloadsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PodcastDownloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private override init() {
        super.init()
        loadMetadata()
        applyAutoDeletePolicy()
        reconcileActiveDownloadsFromSession()
    }

    /// After a background relaunch, in-memory `tasks`/`activeDownloads`/
    /// `progress` start empty even though the OS-level background session
    /// may still have downloads in flight from before the app was
    /// suspended/killed — ask the session directly instead of assuming
    /// nothing is happening, so the UI doesn't silently show an in-progress
    /// download as never-started.
    private func reconcileActiveDownloadsFromSession() {
        session.getAllTasks { [weak self] sessionTasks in
            guard let self else { return }
            let downloadTasks = sessionTasks.compactMap { $0 as? URLSessionDownloadTask }
            guard !downloadTasks.isEmpty else { return }
            DispatchQueue.main.async {
                for task in downloadTasks {
                    guard let id = task.taskDescription else { continue }
                    self.tasks[id] = task
                    self.activeDownloads.insert(id)
                    if self.progress[id] == nil { self.progress[id] = 0 }
                }
            }
        }
    }

    // MARK: - Queries

    func localURL(for episodeId: String) -> URL? {
        guard downloadedEpisodeIds.contains(episodeId) else { return nil }
        let url = fileURL(for: episodeId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloaded(_ episodeId: String) -> Bool { localURL(for: episodeId) != nil }

    /// Filtered to `downloadedEpisodeIds` (disk-verified at launch by
    /// `loadMetadata`) rather than raw `metadata.values` — otherwise a file
    /// removed externally (Files app, backup restore) left its metadata
    /// entry lingering here indefinitely: still listed as downloaded, still
    /// counted in storage totals, until the next app launch reconciled it.
    var downloadedEpisodes: [DownloadedEpisodeMeta] {
        metadata.values
            .filter { downloadedEpisodeIds.contains($0.id) }
            .sorted { $0.downloadedAt > $1.downloadedAt }
    }

    var totalSizeBytes: Int64 {
        metadata.values
            .filter { downloadedEpisodeIds.contains($0.id) }
            .reduce(0) { $0 + $1.fileSizeBytes }
    }

    // MARK: - Actions

    func download(_ episode: PodcastEpisode) {
        guard !isDownloaded(episode.id), !activeDownloads.contains(episode.id),
              let url = URL(string: episode.audioUrl), !episode.audioUrl.isEmpty else { return }
        activeDownloads.insert(episode.id)
        progress[episode.id] = 0
        metadata[episode.id] = DownloadedEpisodeMeta(
            id: episode.id, title: episode.title, showTitle: episode.showTitle,
            downloadedAt: Date(), fileSizeBytes: 0
        )
        let task = session.downloadTask(with: url)
        task.taskDescription = episode.id
        tasks[episode.id] = task
        task.resume()
    }

    func cancelDownload(_ episodeId: String) {
        tasks[episodeId]?.cancel()
        tasks[episodeId] = nil
        activeDownloads.remove(episodeId)
        progress[episodeId] = nil
        metadata[episodeId] = nil
        saveMetadata()
    }

    func delete(_ episodeId: String) {
        if let url = localURL(for: episodeId) { try? FileManager.default.removeItem(at: url) }
        downloadedEpisodeIds.remove(episodeId)
        metadata[episodeId] = nil
        saveMetadata()
    }

    /// Called when an episode finishes playing. Records the completion time
    /// (used by the Auto-Delete preference) and immediately applies the policy.
    func markPlayCompleted(_ episodeId: String) {
        guard metadata[episodeId] != nil else { return }
        metadata[episodeId]?.playCompletedAt = Date()
        saveMetadata()
        applyAutoDeletePolicy()
    }

    /// Deletes downloaded episodes whose completed-playback age exceeds the
    /// user's Auto-Delete preference. Safe to call anytime (app launch,
    /// after an episode finishes) — it's a no-op when the preference is Off.
    func applyAutoDeletePolicy() {
        let raw = UserDefaults.standard.string(forKey: "podcast.autoDelete") ?? PodcastAutoDelete.off.rawValue
        guard let policy = PodcastAutoDelete(rawValue: raw), policy != .off else { return }

        let threshold: TimeInterval
        switch policy {
        case .off:        return
        case .immediate:  threshold = 0
        case .oneDay:     threshold = 86_400
        case .threeDays:  threshold = 86_400 * 3
        case .sevenDays:  threshold = 86_400 * 7
        }

        let now = Date()
        for (id, meta) in metadata {
            guard let completedAt = meta.playCompletedAt, now.timeIntervalSince(completedAt) >= threshold else { continue }
            delete(id)
        }
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: downloadsDirectory)
        downloadedEpisodeIds.removeAll()
        metadata.removeAll()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        activeDownloads.removeAll()
        progress.removeAll()
        saveMetadata()
    }

    // MARK: - Storage

    private func fileURL(for episodeId: String) -> URL {
        downloadsDirectory.appendingPathComponent("\(episodeId).mp3")
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let decoded = try? JSONDecoder().decode([String: DownloadedEpisodeMeta].self, from: data) else { return }
        metadata = decoded
        downloadedEpisodeIds = Set(decoded.keys.filter {
            FileManager.default.fileExists(atPath: fileURL(for: $0).path)
        })
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        guard let episodeId = downloadTask.taskDescription else { return }
        let destination = fileURL(for: episodeId)
        try? FileManager.default.removeItem(at: destination)
        let moved = (try? FileManager.default.moveItem(at: location, to: destination)) != nil
        let size = moved ? ((try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0) : 0

        let title = metadata[episodeId]?.title ?? "Episode"
        DispatchQueue.main.async {
            if moved {
                self.metadata[episodeId]?.fileSizeBytes = size
                self.downloadedEpisodeIds.insert(episodeId)
                SoundPlayer.shared.play(.downloadComplete)
            } else {
                self.metadata[episodeId] = nil
                self.lastFailure = DownloadFailure(episodeId: episodeId, episodeTitle: title)
            }
            self.activeDownloads.remove(episodeId)
            self.progress[episodeId] = nil
            self.tasks[episodeId] = nil
            self.saveMetadata()
        }
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard let episodeId = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.progress[episodeId] = pct }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let episodeId = task.taskDescription else { return }
        let title = metadata[episodeId]?.title ?? "Episode"
        DispatchQueue.main.async {
            self.activeDownloads.remove(episodeId)
            self.progress[episodeId] = nil
            self.metadata[episodeId] = nil
            self.tasks[episodeId] = nil
            self.saveMetadata()
            self.lastFailure = DownloadFailure(episodeId: episodeId, episodeTitle: title)
        }
    }

    /// Required for a background session: tells the OS every delegate
    /// callback queued while the app was suspended has now been delivered,
    /// so it's safe to call the stashed completion handler and let the app
    /// be suspended again.
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundSessionCompletionHandler?()
            self.backgroundSessionCompletionHandler = nil
        }
    }
}
