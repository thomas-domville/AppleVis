import Foundation

/// Shared between `APIClient` and `DrupalFormClient` — both target
/// applevis.com, which sits behind Cloudflare bot protection that blocks
/// requests without a recognized app signature (confirmed against the live
/// RN reference client's `COMMON_HEADERS`; a request missing these gets
/// served an HTML challenge page instead of real content).
///
/// Previously each client held its own independent string-literal copy of
/// these headers, including the `X-App-Auth` secret (ARCH-01/ARCH-03) — a
/// header or secret rotation had to be made in two places and could
/// silently drift between them. `ItunesAPI`/`ImageDescriber` intentionally
/// don't use this: they target genuinely different hosts (Apple's iTunes
/// API, on-device Vision) that don't sit behind this same protection.
enum CloudflareBypass {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026"
    static let appAuthSecret = "2ff01dc7bf35469d93c6"

    static func headers(origin: String) -> [String: String] {
        [
            "User-Agent": userAgent,
            "Accept-Language": "en-US,en;q=0.9",
            "Origin": origin,
            "Referer": "\(origin)/",
            "X-App-Auth": appAuthSecret,
        ]
    }
}
