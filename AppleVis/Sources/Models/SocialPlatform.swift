import Foundation

/// Single source of truth for AppleVis's social media presence.
/// Previously duplicated independently in `SocialLinksView` and
/// `DiscoverView`, which had already drifted out of sync with each other
/// (different Facebook icons, different ordering) — both now read from here
/// instead of maintaining their own copy. Requested directly.
struct SocialPlatform: Identifiable {
    let id: String
    let name: String
    let icon: String
    let url: URL
}

enum AppleVisSocial {
    static let platforms: [SocialPlatform] = [
        SocialPlatform(id: "x", name: "X", icon: "at", url: URL(string: "https://x.com/AppleVis")!),
        SocialPlatform(id: "facebook", name: "Facebook", icon: "f.circle", url: URL(string: "https://www.facebook.com/AppleVis")!),
        SocialPlatform(id: "mastodon", name: "Mastodon", icon: "network", url: URL(string: "https://mastodon.online/@AppleVis")!),
    ]
}
