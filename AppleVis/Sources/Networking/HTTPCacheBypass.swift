import Foundation

/// When on, AppleVis requests skip the phone's HTTP cache and go to the
/// site. The site lets responses be reused for 60 seconds, so a "load it
/// live" request (pull to refresh, Fetch, Refresh App Details, the App
/// Health Check) could still get the copy from before a change just made.
/// `fetchWithCache(forceRefresh: true)` turns it on for everything its
/// fetch does, including requests made in parallel. Reported directly
/// (2026-10-02): a Health Check rescan flagged entries just refreshed.
nonisolated enum HTTPCacheBypass {
    @TaskLocal static var isOn = false

    /// The cache policy for a request made now.
    static var policy: URLRequest.CachePolicy {
        isOn ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
    }
}
