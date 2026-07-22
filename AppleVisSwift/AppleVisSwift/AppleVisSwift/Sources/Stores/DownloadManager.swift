import Foundation
import Combine

struct DownloadedEpisodeMeta: Codable {
    let id: String
    let title: String
    let showTitle: String
    let downloadedAt: Date
    var fileSizeBytes: Int64
}

/// Downloads podcast episodes for offline playback. Not `@MainActor` — the
/// `URLSessionDownloadDelegate` callbacks arrive on a background queue, and
/// `@Published` mutations are explicitly hopped to the main thread instead of
/// isolating the whole type (avoids cross-actor friction with the delegate
/// protocol, whose methods can't themselves be actor-isolated).
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedEpisodeIds: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]
    @Published private(set) var activeDownloads: Set<String> = []

    private var metadata: [String: DownloadedEpisodeMeta] = [:]
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

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
    }

    // MARK: - Queries

    func localURL(for episodeId: String) -> URL? {
        guard downloadedEpisodeIds.contains(episodeId) else { return nil }
        let url = fileURL(for: episodeId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloaded(_ episodeId: String) -> Bool { localURL(for: episodeId) != nil }

    var downloadedEpisodes: [DownloadedEpisodeMeta] {
        metadata.values.sorted { $0.downloadedAt > $1.downloadedAt }
    }

    var totalSizeBytes: Int64 { metadata.values.reduce(0) { $0 + $1.fileSizeBytes } }

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

        DispatchQueue.main.async {
            if moved {
                self.metadata[episodeId]?.fileSizeBytes = size ?? 0
                self.downloadedEpisodeIds.insert(episodeId)
            } else {
                self.metadata[episodeId] = nil
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
        DispatchQueue.main.async {
            self.activeDownloads.remove(episodeId)
            self.progress[episodeId] = nil
            self.metadata[episodeId] = nil
            self.tasks[episodeId] = nil
            self.saveMetadata()
        }
    }
}
