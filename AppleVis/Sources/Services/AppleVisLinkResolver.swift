import Foundation
import os

/// Turns an applevis.com web address into the native screen it points to —
/// forum topic, blog post, guide, podcast episode, app entry, or bug report.
///
/// The site has no path-alias lookup (`/router/translate-path` isn't
/// installed, and JSON:API can't filter on `path.alias` — both confirmed
/// live, 2026-09-23), so resolution is two steps:
/// 1. The path's leading segments decide the content type, with no network
///    call — so a link that isn't content at all (a help page, a category
///    listing, search) can go straight to the browser without waiting.
/// 2. The page's own HTML carries its node number in
///    `data-history-node-id` on every content type; that number is then
///    looked up in JSON:API, filtered to the expected type, for the UUID
///    every detail screen takes. The type filter doubles as a sanity check:
///    a page whose number doesn't belong to the expected type resolves to
///    nil, and the link just opens in the browser as before.
///
/// Used for links tapped inside posts and comments (via ContentView's
/// `openURL` handler) and for Universal Links — which start arriving once
/// applevis.com publishes its apple-app-site-association file; until then
/// iOS never hands the app a web link at all.
enum AppleVisLinkResolver {
    struct Destination {
        let kind: ContentKind
        let nodeType: String
    }

    static func isAppleVisURL(_ url: URL) -> Bool {
        // `.contains` would also match a spoofed host like
        // "applevis.com.attacker.com".
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return false }
        return host == "applevis.com" || host.hasSuffix(".applevis.com")
    }

    /// The content type a link points to, judged from its path alone, or
    /// nil if it isn't a content page (so it should just open in a browser).
    /// Shapes confirmed against live aliases for every type, 2026-09-23:
    /// `/forum/{category}/{slug}`, `/blog/{slug}`, `/guides/{slug}`,
    /// `/podcasts/{slug}`, `/apps/{ios|mac|tv|watch}/{category}/{slug}`,
    /// `/bugs/{ios|mac}/{slug}`. Shorter paths on the same prefixes are
    /// listing pages (`/forum/macos-mac-apps`, `/apps/ios/games`).
    static func destination(for url: URL) -> Destination? {
        guard isAppleVisURL(url) else { return nil }
        let parts = url.path.split(separator: "/").map { $0.lowercased() }
        guard let first = parts.first else { return nil }

        switch (first, parts.count) {
        case ("forum", 3):
            return Destination(kind: .forumTopic, nodeType: "forum")
        case ("blog", 2):
            return Destination(kind: .blogPost, nodeType: "blog2")
        case ("guides", 2):
            return Destination(kind: .resource, nodeType: "guides")
        case ("podcasts", 2):
            return Destination(kind: .podcastEpisode, nodeType: "podcast")
        case ("apps", 4):
            switch parts[1] {
            case "ios":   return Destination(kind: .appListing, nodeType: "ios_app_directory")
            case "mac":   return Destination(kind: .appListing, nodeType: "mac_app_directory")
            case "tv":    return Destination(kind: .appListing, nodeType: "tv_directory")
            case "watch": return Destination(kind: .appListing, nodeType: "watch_directory")
            default:      return nil
            }
        case ("bugs", 3):
            switch parts[1] {
            case "ios": return Destination(kind: .bugReport, nodeType: "ios_bug_report")
            case "mac": return Destination(kind: .bugReport, nodeType: "os_x_bug_report")
            default:    return nil
            }
        default:
            return nil
        }
    }

    /// The content kind and JSON:API UUID a link points to, or nil if it
    /// isn't content or couldn't be resolved — callers fall back to opening
    /// the link in a browser either way.
    static func resolve(_ url: URL) async -> (kind: ContentKind, id: String)? {
        guard let destination = destination(for: url),
              let nid = await nodeNumber(forPageAt: url) else { return nil }
        do {
            let response = try await APIClient.shared.jsonAPIList(
                "node/\(destination.nodeType)",
                query: [
                    "filter[drupal_internal__nid]": nid,
                    "fields[node--\(destination.nodeType)]": "drupal_internal__nid",
                ]
            )
            guard let uuid = response.data.first?.id else { return nil }
            return (destination.kind, uuid)
        } catch {
            AppLog.network.error("Link lookup failed for node \(nid, privacy: .public)")
            return nil
        }
    }

    /// Fetches the page (always over https on www, regardless of how the
    /// link was written) and reads its node number. Uses URLSession.shared
    /// with the Cloudflare-bypass headers, same as DrupalFormClient.
    private static func nodeNumber(forPageAt url: URL) async -> String? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        components?.host = "www.applevis.com"
        components?.fragment = nil
        guard let pageURL = components?.url else { return nil }

        var request = URLRequest(url: pageURL)
        CloudflareBypass.headers(origin: "https://www.applevis.com").forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            AppLog.network.error("Link page fetch failed for \(pageURL.path, privacy: .public)")
            return nil
        }
        guard let range = html.range(of: #"data-history-node-id="(\d+)""#, options: .regularExpression) else { return nil }
        return String(html[range]).filter(\.isNumber)
    }
}
