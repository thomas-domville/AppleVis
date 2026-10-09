import Network
import Combine

/// Tracks device network reachability so the UI can show an offline banner
/// over stale content instead of silently failing refreshes.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private var pendingOffline: Task<Void, Never>?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.update(satisfied: satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "applevis.network-monitor"))
    }

    /// Back online counts at once. Going offline waits two seconds: when
    /// the phone wakes or switches between Wi-Fi and cellular, the
    /// connection can blink off for a moment, which showed "You're
    /// offline" on a good connection (2026-10-08).
    private func update(satisfied: Bool) {
        pendingOffline?.cancel()
        pendingOffline = nil
        if satisfied {
            isConnected = true
            return
        }
        pendingOffline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.isConnected = false
        }
    }
}
