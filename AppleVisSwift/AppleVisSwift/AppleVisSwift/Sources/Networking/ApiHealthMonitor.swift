import Foundation

/// Content types that get their own cache/health bucket — mirrors the old
/// RN app's `ApiGroup` (src/services/apiHealth.ts).
enum ContentGroup: String {
    case forums, podcasts, apps, resources, blogs, bugs
}

/// Session-scoped circuit breaker — the Swift equivalent of the old RN
/// app's src/services/apiHealth.ts. A single failed fetch marks its content
/// group "down" for `recoverySeconds`; while down, `fetchWithCache` skips
/// the network entirely and serves cache instead of waiting out another
/// timeout against an endpoint that's already failing. The mark expires on
/// its own so a one-off transient failure doesn't lock a whole content
/// category out of live fetches for the rest of the session.
actor ApiHealthMonitor {
    static let shared = ApiHealthMonitor()

    private enum Status { case unknown, up, down }

    private static let recoverySeconds: TimeInterval = 60

    private var status: [ContentGroup: Status] = [:]
    private var downSince: [ContentGroup: Date] = [:]

    func isAvailable(_ group: ContentGroup) -> Bool {
        guard status[group] == .down else { return true }
        if let since = downSince[group], Date().timeIntervalSince(since) > Self.recoverySeconds {
            status[group] = .unknown
            downSince[group] = nil
            return true
        }
        return false
    }

    func markDown(_ group: ContentGroup) {
        status[group] = .down
        downSince[group] = Date()
    }

    func markUp(_ group: ContentGroup) {
        status[group] = .up
        downSince[group] = nil
    }
}
