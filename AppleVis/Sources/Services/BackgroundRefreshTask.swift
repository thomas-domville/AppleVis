import BackgroundTasks
import Foundation
import Network

/// Keeps Home ready while AppleVis is closed (2026-10-08). iOS's Background
/// App Refresh wakes the app now and then, usually shortly before the times
/// someone tends to open it, and gives it about 30 seconds. In that time
/// this fetches Home's lists and saves them, picks up what was read on the
/// website, and sends any Mark as Read still waiting to reach it. On
/// opening, Home shows the saved lists straight away and then checks live.
///
/// iOS decides when, and how often, this runs. It doesn't run after the
/// app is swiped away in the app switcher (until it's opened again), in
/// Low Power Mode, or with Background App Refresh turned off for AppleVis.
/// It also skips itself in Low Data Mode. Requested directly.
enum BackgroundRefreshTask {
    static let identifier = "com.applevis.refresh"

    /// Delivered on the main queue: the work touches Home's view model and
    /// the stores, all of which live on the main actor.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            MainActor.assumeIsolated {
                guard let task = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
                handle(task)
            }
        }
    }

    /// Asks for the next refresh no sooner than an hour from now. iOS picks
    /// the actual moment.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        scheduleNext()
        if NetworkStatus.isLowDataMode() {
            task.setTaskCompleted(success: true)
            return
        }
        let completion = Completion(task)
        // When iOS wakes the app just for this, the screens (and the sign-in
        // they normally load) may not exist yet. Load the sign-in here so
        // website reads and waiting Mark as Read can go too. If the phone is
        // locked and the sign-in can't be read, only the public lists are
        // refreshed.
        let auth = AuthStore.current ?? AuthStore()
        let work = Task { @MainActor in
            let refreshed = await HomeViewModel.refreshInBackground()
            await APIClient.shared.history.sendPendingReadsNow()
            // Held by this task until the work is done.
            _ = auth
            completion.finish(refreshed && !Task.isCancelled)
        }
        // Time's up: stop, and tell iOS straight away (it expects that).
        task.expirationHandler = {
            Task { @MainActor in
                work.cancel()
                completion.finish(false)
            }
        }
    }

    /// Reports the task finished exactly once, whichever comes first: the
    /// work, or iOS running out of time.
    @MainActor
    private final class Completion {
        private let task: BGTask
        private var done = false
        init(_ task: BGTask) { self.task = task }
        func finish(_ success: Bool) {
            guard !done else { return }
            done = true
            task.setTaskCompleted(success: success)
        }
    }
}

extension NetworkStatus {
    /// True when Low Data Mode is on for the current connection.
    static func isLowDataMode() -> Bool {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var constrained = false
        monitor.pathUpdateHandler = { path in
            constrained = path.isConstrained
            semaphore.signal()
        }
        monitor.start(queue: DispatchQueue(label: "com.applevis.networkstatus.constrained"))
        _ = semaphore.wait(timeout: .now() + 2)
        monitor.cancel()
        return constrained
    }
}
