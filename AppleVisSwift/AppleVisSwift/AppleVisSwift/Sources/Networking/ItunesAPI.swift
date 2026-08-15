import Foundation

/// iTunes Search API — public, free, no authentication. Enriches app detail
/// pages with live App Store metadata: price, version, release notes,
/// rating, size, screenshots. Ported from src/services/itunesApi.ts.
struct ItunesMetadata {
    let appStoreId: String
    let artistId: Int?
    let appName: String
    let developerName: String
    let category: String
    let appStoreUrl: String
    let artworkUrl: String
    let price: String
    let version: String
    let releaseNotes: String
    let appStoreRating: Double?
    let appStoreRatingCount: Int
    let fileSizeMb: String
    let minimumOsVersion: String
    let ageRating: String
    let screenshotUrls: [String]
    let appStoreDescription: String
}

struct ItunesDeveloperApp: Identifiable {
    var id: String { appStoreId }
    let appStoreId: String
    let appName: String
    let artworkUrl: String
    let appStoreUrl: String
}

struct ItunesSearchHit: Identifiable {
    var id: String { appStoreId }
    let appStoreId: String
    let appName: String
    let developerName: String
    let artworkUrl: String
    let appStoreUrl: String
}

/// iTunes Search API's `entity` parameter differs per platform — needed so
/// the App Submission wizard's platform picker (iOS/macOS/tvOS) actually
/// changes what `ItunesAPI.search`/`fetchMetadata` look up, instead of every
/// platform silently searching iOS software only (SUBMIT-003: no platform
/// picker meant native could never submit a macOS or Apple TV app entry).
extension AppPlatform {
    var itunesEntity: String {
        switch self {
        case .ios:     return "software"
        case .macos:   return "macSoftware"
        case .tvos:    return "tvSoftware"
        case .watchos: return "software" // watchOS apps ship bundled in an iOS entry; no dedicated entity
        }
    }
}

enum ItunesAPI {
    static func search(_ query: String, limit: Int = 20, entity: String = "software") async -> [ItunesSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "country", value: "us"),
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return [] }

        return results.compactMap { r -> ItunesSearchHit? in
            guard let trackId = r["trackId"] as? Int, let name = r["trackName"] as? String else { return nil }
            return ItunesSearchHit(
                appStoreId: "\(trackId)",
                appName: name,
                developerName: (r["artistName"] as? String) ?? "",
                artworkUrl: (r["artworkUrl100"] as? String) ?? (r["artworkUrl60"] as? String) ?? "",
                appStoreUrl: (r["trackViewUrl"] as? String) ?? ""
            )
        }
    }

    /// Returns metadata on success, `nil` if the app isn't on the App Store
    /// (or the URL has no extractable numeric id) or the request failed.
    static func fetchMetadata(appStoreUrl: String, entity: String = "software") async -> ItunesMetadata? {
        guard let id = extractAppStoreId(appStoreUrl) else { return nil }
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&entity=\(entity)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultCount = json["resultCount"] as? Int, resultCount > 0,
              let results = json["results"] as? [[String: Any]], let r = results.first
        else { return nil }

        func str(_ key: String) -> String { (r[key] as? String) ?? "" }

        let price: String
        if let formatted = r["formattedPrice"] as? String {
            price = formatted
        } else if let numeric = r["price"] as? Double {
            price = numeric == 0 ? "Free" : "$\(numeric)"
        } else {
            price = ""
        }

        let rating = r["averageUserRating"] as? Double
        let ratingCount = (r["userRatingCount"] as? Int) ?? 0
        let fileSizeBytes = (r["fileSizeBytes"] as? String).flatMap(Int64.init) ?? Int64((r["fileSizeBytes"] as? NSNumber)?.int64Value ?? 0)

        return ItunesMetadata(
            appStoreId: id,
            artistId: r["artistId"] as? Int,
            appName: str("trackName"),
            developerName: str("artistName"),
            category: str("primaryGenreName"),
            appStoreUrl: (r["trackViewUrl"] as? String) ?? appStoreUrl,
            artworkUrl: (r["artworkUrl100"] as? String) ?? (r["artworkUrl60"] as? String) ?? "",
            price: price,
            version: str("version"),
            releaseNotes: str("releaseNotes"),
            appStoreRating: rating,
            appStoreRatingCount: ratingCount,
            fileSizeMb: formatBytes(fileSizeBytes),
            minimumOsVersion: str("minimumOsVersion"),
            ageRating: str("contentAdvisoryRating"),
            screenshotUrls: (r["screenshotUrls"] as? [String]) ?? [],
            appStoreDescription: str("description")
        )
    }

    /// Other apps by the same developer — the old app fetches and shows
    /// this on the app detail page (`fetchDeveloperApps`); Swift never had
    /// an equivalent at all.
    static func fetchDeveloperApps(artistId: Int, excluding appStoreId: String) async -> [ItunesDeveloperApp] {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(artistId)&entity=software&limit=25") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return [] }

        return results.compactMap { r -> ItunesDeveloperApp? in
            guard r["wrapperType"] as? String == "software",
                  let trackId = r["trackId"] as? Int, "\(trackId)" != appStoreId,
                  let name = r["trackName"] as? String
            else { return nil }
            return ItunesDeveloperApp(
                appStoreId: "\(trackId)",
                appName: name,
                artworkUrl: (r["artworkUrl100"] as? String) ?? (r["artworkUrl60"] as? String) ?? "",
                appStoreUrl: (r["trackViewUrl"] as? String) ?? ""
            )
        }
    }

    private static func extractAppStoreId(_ url: String) -> String? {
        guard let range = url.range(of: #"/id(\d+)"#, options: .regularExpression) else { return nil }
        return url[range].dropFirst(3).description
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}
