import BackgroundTasks
import Foundation
import Network

/// Background auto-download of new podcast episodes, honoring the
/// `podcast.autoDownload` preference (off/wifiOnly/always) that's existed
/// since Phase 2 but had nothing consuming it. Registered as a
/// `BGProcessingTask` (not `BGAppRefreshTask`) since it does real network +
/// disk work rather than a quick refresh.
enum BackgroundDownloadTask {
    static let identifier = "com.applevis.autodownload"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGProcessingTask else { task.setTaskCompleted(success: false); return }
            handle(task)
        }
    }

    static func scheduleNext() {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGProcessingTask) {
        scheduleNext()

        let autoDownload = PodcastAutoDownload(
            rawValue: UserDefaults.standard.string(forKey: "podcast.autoDownload") ?? "off"
        ) ?? .off
        guard autoDownload != .off else {
            task.setTaskCompleted(success: true)
            return
        }

        let work = Task {
            let onWifiOnly = autoDownload == .wifiOnly
            if onWifiOnly, !NetworkStatus.isOnWiFi() {
                task.setTaskCompleted(success: true)
                return
            }
            guard let episodes = try? await APIClient.shared.podcasts.episodes(page: 0, sort: .recent) else {
                task.setTaskCompleted(success: false)
                return
            }
            for episode in episodes.items.prefix(3) {
                await MainActor.run { DownloadManager.shared.download(episode) }
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { work.cancel() }
    }
}

/// Minimal one-shot Wi-Fi vs. cellular check via NWPathMonitor.
enum NetworkStatus {
    static func isOnWiFi() -> Bool {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var onWiFi = false
        monitor.pathUpdateHandler = { path in
            onWiFi = path.usesInterfaceType(.wifi)
            semaphore.signal()
        }
        let queue = DispatchQueue(label: "com.applevis.networkstatus")
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 2)
        monitor.cancel()
        return onWiFi
    }
}
