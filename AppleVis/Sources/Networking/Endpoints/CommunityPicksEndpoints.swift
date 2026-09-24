import Foundation

extension APIClient {
    var communityPicks: CommunityPicksEndpoints { CommunityPicksEndpoints(client: self) }
}

/// Discover → Community Picks.
///
/// NOT LIVE YET (2026-09-24): this calls `GET /api/v1/apps/recommendations`,
/// a native REST endpoint requested from the Drupal developer. It doesn't
/// exist yet, so today it 404s and the screen shows its "almost ready"
/// state. The app can't build these lists itself: recommendation flaggings
/// aren't readable through JSON:API for signed-out visitors (confirmed live —
/// every `flagging/recommend` item comes back "omitted because of
/// insufficient authorization"), and the website's two pages
/// (`/apps/recommended-latest`, `/apps/recommended-most`, both displays of
/// the `recommended_apps` view) have no date range and no per-app grouping.
///
/// Requested contract (adjust `list` and `Mappers.communityPick` if the
/// real one differs):
///
///     GET /api/v1/apps/recommendations
///       ?sort=latest|most      latest = newest recommendation first; most = highest count first
///       &since=<unix seconds>  optional; count only recommendations at or after this
///       &type=<bundle>         optional; ios_app_directory | mac_app_directory | watch_directory | tv_directory
///       &page=<0-based>        20 apps per page, like /api/v1/forums/recent
///
///     [ { "uuid", "nid", "title", "type", "url", "developer", "category",
///         "app_store_url", "comment_count", "last_comment_timestamp",
///         "created", "changed",
///         "recommendations",        // inside the `since` window
///         "total_recommendations",  // all time
///         "last_recommended" } ]    // unix seconds
///
/// Deliberately not wrapped in `fetchWithCache`: a 404 there would mark the
/// whole Apps content group as down and break ordinary app browsing too.
struct CommunityPicksEndpoints {
    let client: APIClient

    nonisolated static let pageSize = 20

    func list(
        sort: CommunityPicksSort,
        period: CommunityPicksPeriod,
        platform: AppPlatform?,
        page: Int
    ) async throws -> [CommunityPick] {
        var query = ["sort": sort.rawValue, "page": "\(page)"]
        if let since = period.since() {
            query["since"] = "\(Int(since.timeIntervalSince1970))"
        }
        if let platform {
            query["type"] = platform.drupalBundle
        }
        let raw: JSONValue = try await client.get("apps/recommendations", query: query)
        return (raw.arrayValue ?? []).compactMap { $0.objectValue }.compactMap { Mappers.communityPick($0) }
    }
}

extension Mappers {
    /// Maps one item from `/api/v1/apps/recommendations`. Returns nil
    /// without a real UUID, for the same reason as `forumFromRecent`: a row
    /// that can't open is worse than no row.
    static func communityPick(_ item: [String: JSONValue]) -> CommunityPick? {
        guard let uuid = item["uuid"]?.stringValue, UUID(uuidString: uuid) != nil else { return nil }
        let platform = item["type"]?.stringValue.flatMap(AppPlatform.init(drupalBundle:)) ?? .ios

        func date(_ key: String) -> Date? {
            guard let ts = item[key]?.doubleValue, ts > 0 else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        let changed = date("changed") ?? .distantPast
        let path = item["url"]?.stringValue ?? ""
        let url = path.hasPrefix("http") ? path : "https://www.applevis.com\(path)"
        let appStoreUrl = item["app_store_url"]?.stringValue ?? ""

        let app = AppListing(
            id: uuid,
            nid: item["nid"]?.intValue,
            name: item["title"]?.stringValue ?? "",
            developer: item["developer"]?.stringValue ?? "",
            platform: platform,
            category: item["category"]?.stringValue ?? "",
            categoryId: "",
            reviewCount: item["comment_count"]?.intValue ?? 0,
            lastUpdatedAt: changed,
            lastActivityAt: date("last_comment_timestamp") ?? changed,
            createdAt: date("created") ?? .distantPast,
            submittedBy: "",
            submitterUid: "",
            appStoreUrl: appStoreUrl.isEmpty ? nil : appStoreUrl,
            iconUrl: nil,
            price: "",
            supportedDevices: [],
            voiceOverPerformance: nil,
            summary: "",
            url: url,
            isSaved: PersistenceStore.shared.isSaved(id: uuid)
        )
        let total = item["total_recommendations"]?.intValue ?? 0
        let inPeriod = item["recommendations"]?.intValue ?? total
        return CommunityPick(
            app: app,
            periodCount: inPeriod,
            totalCount: max(total, inPeriod),
            lastRecommendedAt: date("last_recommended")
        )
    }
}
