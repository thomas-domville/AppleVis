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
    /// Derived from the raw numeric `price` field, not by string-matching
    /// `price`/`formattedPrice` — those are already-localized display text
    /// ("Free", "$2.99"), and matching against the literal word "Free"
    /// would silently break for any country/language other than the
    /// hardcoded `country=us` this app already requests, or if Apple ever
    /// changes that wording.
    let isFree: Bool
    let version: String
    let releaseNotes: String
    let appStoreRating: Double?
    let appStoreRatingCount: Int
    let fileSizeMb: String
    let minimumOsVersion: String
    let ageRating: String
    let screenshotUrls: [String]
    let appStoreDescription: String
    let languageCodes: [String]
    /// The app's original App Store debut — Apple's own `releaseDate`,
    /// distinct from `currentVersionReleaseDate` below. `nil` if the raw
    /// value is missing or unparseable rather than defaulting to "now."
    let releaseDate: Date?
    /// When the version currently shown was released — Apple's own
    /// `currentVersionReleaseDate`. Equal to `releaseDate` for an app
    /// that's never been updated since it first launched; that's expected,
    /// not a parsing bug.
    let currentVersionReleaseDate: Date?
    /// Friendly device families ("iPhone", "iPad", "Apple Watch", "Mac",
    /// "Apple TV") derived from the lookup's raw `supportedDevices`
    /// codename array and `features` flags. Still can't confirm a
    /// genuinely separate native Mac app — that ships as its own App Store
    /// listing with its own track id this lookup has no way to link back
    /// to this one — so AppDetailView still fills Mac in from AppleVis's
    /// own submitted data as a fallback. Apple TV support, unlike Mac,
    /// *can* be confirmed without guessing: a `tvSoftware`-entity lookup on
    /// the very same track id returns it directly when present — see
    /// `ItunesAPI.fetchTvOSSupport`/`confirmAppleTVSupport(for:)`.
    let deviceFamilies: [String]

    /// `languageCodes` arrives as raw ISO 639-1 codes ("EN", "ES", "FR") —
    /// spoken and read as letters by VoiceOver with no indication they're
    /// language codes at all. Expanded to full names via `Locale` in the
    /// current app language (a French user reading this page sees "Anglais,
    /// Espagnol, Français", not the English names), sorted for a stable,
    /// scannable order. Falls back to the raw code for anything `Locale`
    /// doesn't recognize rather than silently dropping it.
    var languageNames: String {
        languageCodes
            .map { Locale.current.localizedString(forLanguageCode: $0.lowercased()) ?? $0 }
            .sorted()
            .joined(separator: ", ")
    }

    /// Returns a copy with an additional confirmed device family merged in
    /// — used when a supplementary lookup (`ItunesAPI.fetchTvOSSupport`)
    /// confirms something the original lookup's entity couldn't see on its
    /// own (a `software`-entity lookup never reports Apple TV support, even
    /// when the same app genuinely has it — confirmed live).
    func addingDeviceFamily(_ family: String) -> ItunesMetadata {
        guard !deviceFamilies.contains(family) else { return self }
        return ItunesMetadata(
            appStoreId: appStoreId, artistId: artistId, appName: appName, developerName: developerName,
            category: category, appStoreUrl: appStoreUrl, artworkUrl: artworkUrl, price: price, isFree: isFree,
            version: version, releaseNotes: releaseNotes, appStoreRating: appStoreRating, appStoreRatingCount: appStoreRatingCount,
            fileSizeMb: fileSizeMb, minimumOsVersion: minimumOsVersion, ageRating: ageRating, screenshotUrls: screenshotUrls,
            appStoreDescription: appStoreDescription, languageCodes: languageCodes,
            releaseDate: releaseDate, currentVersionReleaseDate: currentVersionReleaseDate,
            deviceFamilies: deviceFamilies + [family]
        )
    }
}

enum ItunesMetadataLookupResult {
    case found(ItunesMetadata)
    case notFound
    case invalidLink
    case failed
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
        await rawSearchResults(query, limit: limit, entity: entity).compactMap(hitFromRaw)
    }

    /// Mac app search. Verified live that a Mac app can genuinely be
    /// either of two different things Apple's API tells apart: a real,
    /// separate Mac App Store listing (`kind: "mac-software"`, its own
    /// track id — found via the `macSoftware` entity), or a Mac Catalyst
    /// app that shares its iOS listing entirely (`features` contains
    /// `"macCatalyst"` — found via the plain `software` entity). Neither
    /// entity's search reliably filters to just one kind on its own (both
    /// can return apps of either kind for a matching name — confirmed
    /// live), so this searches both and filters client-side on the real
    /// signal, merging and de-duplicating by id.
    static func searchMacOS(_ query: String, limit: Int = 20) async -> [ItunesSearchHit] {
        async let macRaw = rawSearchResults(query, limit: limit, entity: "macSoftware")
        async let iosRaw = rawSearchResults(query, limit: limit, entity: "software")
        let macHits = await macRaw
            .filter { ($0["kind"] as? String) == "mac-software" }
            .compactMap(hitFromRaw)
        let catalystHits = await iosRaw
            .filter { (($0["features"] as? [String]) ?? []).contains("macCatalyst") }
            .compactMap(hitFromRaw)
        var seen: Set<String> = []
        return (macHits + catalystHits).filter { seen.insert($0.appStoreId).inserted }
    }

    private static func rawSearchResults(_ query: String, limit: Int, entity: String) async -> [[String: Any]] {
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
        return results
    }

    private static func hitFromRaw(_ r: [String: Any]) -> ItunesSearchHit? {
        guard let trackId = r["trackId"] as? Int, let name = r["trackName"] as? String else { return nil }
        return ItunesSearchHit(
            appStoreId: "\(trackId)",
            appName: name,
            developerName: (r["artistName"] as? String) ?? "",
            artworkUrl: (r["artworkUrl100"] as? String) ?? (r["artworkUrl60"] as? String) ?? "",
            appStoreUrl: (r["trackViewUrl"] as? String) ?? ""
        )
    }

    /// Returns metadata on success, `nil` if the app isn't on the App Store
    /// (or the URL has no extractable numeric id) or the request failed.
    static func fetchMetadata(appStoreUrl: String, entity: String = "software") async -> ItunesMetadata? {
        if case .found(let metadata) = await lookupMetadata(appStoreUrl: appStoreUrl, entity: entity) {
            return metadata
        }
        return nil
    }

    /// Same lookup, keyed directly by a known App Store id rather than a
    /// URL — needed for Apple TV directory entries, which have no stored
    /// App Store URL at all (see `searchTvOS`/`fetchTvOSSupport` below).
    static func fetchMetadata(appStoreId: String, entity: String = "software") async -> ItunesMetadata? {
        if case .found(let metadata) = await lookupMetadata(appStoreId: appStoreId, entity: entity) {
            return metadata
        }
        return nil
    }

    static func lookupMetadata(appStoreUrl: String, entity: String = "software") async -> ItunesMetadataLookupResult {
        guard let id = extractAppStoreId(appStoreUrl) else { return .invalidLink }
        return await lookupMetadata(appStoreId: id, entity: entity, fallbackAppStoreUrl: appStoreUrl)
    }

    static func lookupMetadata(appStoreId: String, entity: String = "software") async -> ItunesMetadataLookupResult {
        await lookupMetadata(appStoreId: appStoreId, entity: entity, fallbackAppStoreUrl: "")
    }

    private static func lookupMetadata(appStoreId id: String, entity: String, fallbackAppStoreUrl: String) async -> ItunesMetadataLookupResult {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&entity=\(entity)") else { return .failed }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failed
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultCount = json["resultCount"] as? Int,
              let results = json["results"] as? [[String: Any]]
        else { return .failed }
        guard resultCount > 0, let r = results.first else { return .notFound }
        return .found(parseMetadata(r, fallbackId: id, entity: entity, fallbackAppStoreUrl: fallbackAppStoreUrl))
    }

    /// Shared per-result parsing, factored out of the single-app lookup
    /// above so `batchLookup` below (App Directory Health Check's bulk
    /// delisting/title-change scan) can reuse it exactly rather than
    /// duplicating this field mapping. `fallbackId` is only used if the
    /// result itself has no `trackId` (shouldn't happen in practice, but
    /// matches the single-lookup path's own fallback-id behavior).
    private static func parseMetadata(_ r: [String: Any], fallbackId: String, entity: String, fallbackAppStoreUrl: String) -> ItunesMetadata {
        func str(_ key: String) -> String { (r[key] as? String) ?? "" }
        let id = (r["trackId"] as? NSNumber).map { "\($0.intValue)" } ?? fallbackId

        let numericPrice = r["price"] as? Double
        let price: String
        if let formatted = r["formattedPrice"] as? String {
            price = formatted
        } else if let numeric = numericPrice {
            price = numeric == 0 ? "Free" : "$\(numeric)"
        } else {
            price = ""
        }
        let isFree = (numericPrice ?? 0) == 0

        let rating = r["averageUserRating"] as? Double
        let ratingCount = (r["userRatingCount"] as? Int) ?? 0
        let fileSizeBytes = (r["fileSizeBytes"] as? String).flatMap(Int64.init) ?? Int64((r["fileSizeBytes"] as? NSNumber)?.int64Value ?? 0)
        let rawSupportedDevices = (r["supportedDevices"] as? [String]) ?? []
        let features = (r["features"] as? [String]) ?? []
        // A `tvSoftware`-entity lookup returns its Apple TV interface
        // screenshots under their own key — `screenshotUrls` (the field
        // every other entity uses) comes back empty instead. Verified live
        // against Disney+/Netflix/Sling TV.
        let screenshots = entity == "tvSoftware"
            ? ((r["appletvScreenshotUrls"] as? [String]) ?? [])
            : ((r["screenshotUrls"] as? [String]) ?? [])
        let releaseDate = (r["releaseDate"] as? String).flatMap(parseISO8601)
        let currentVersionReleaseDate = (r["currentVersionReleaseDate"] as? String).flatMap(parseISO8601)

        return ItunesMetadata(
            appStoreId: id,
            artistId: r["artistId"] as? Int,
            appName: str("trackName"),
            developerName: str("artistName"),
            category: str("primaryGenreName"),
            appStoreUrl: (r["trackViewUrl"] as? String) ?? fallbackAppStoreUrl,
            artworkUrl: (r["artworkUrl100"] as? String) ?? (r["artworkUrl60"] as? String) ?? "",
            price: price,
            isFree: isFree,
            version: str("version"),
            releaseNotes: str("releaseNotes"),
            appStoreRating: rating,
            appStoreRatingCount: ratingCount,
            fileSizeMb: formatBytes(fileSizeBytes),
            minimumOsVersion: str("minimumOsVersion"),
            ageRating: str("contentAdvisoryRating"),
            screenshotUrls: screenshots,
            appStoreDescription: str("description"),
            languageCodes: (r["languageCodesISO2A"] as? [String]) ?? [],
            releaseDate: releaseDate,
            currentVersionReleaseDate: currentVersionReleaseDate,
            deviceFamilies: deviceFamilies(supportedDevices: rawSupportedDevices, features: features)
        )
    }

    /// Looks up many apps in one request instead of one request per app —
    /// the iTunes Lookup API accepts a comma-separated id list. Built for
    /// the App Directory Health Check's bulk delisting/title-change scan,
    /// where checking every iOS app one at a time could mean hundreds of
    /// requests and risk Apple's (undocumented but real) rate limit. An id
    /// missing from the returned dictionary means Apple's lookup didn't
    /// return a match for it — i.e. that app is no longer on the App
    /// Store. Chunked by the caller (`AppEntryHealthScanner`), not here —
    /// this makes exactly one request per call, whatever the id count.
    static func batchLookup(appStoreIds: [String], entity: String = "software") async -> [String: ItunesMetadata] {
        guard !appStoreIds.isEmpty,
              let url = URL(string: "https://itunes.apple.com/lookup?id=\(appStoreIds.joined(separator: ","))&entity=\(entity)")
        else { return [:] }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else { return [:] }

        var byId: [String: ItunesMetadata] = [:]
        for r in results {
            let metadata = parseMetadata(r, fallbackId: "", entity: entity, fallbackAppStoreUrl: "")
            guard !metadata.appStoreId.isEmpty else { continue }
            byId[metadata.appStoreId] = metadata
        }
        return byId
    }

    /// iTunes's date fields (`releaseDate`, `currentVersionReleaseDate`)
    /// come back as plain ISO 8601 with no fractional seconds, e.g.
    /// "2019-11-11T08:00:00Z" — verified live.
    private static func parseISO8601(_ text: String) -> Date? {
        iso8601Formatter.date(from: text)
    }

    /// Buckets iTunes's raw per-model `supportedDevices` codenames (e.g.
    /// "iPhone15Pro-iPhone15Pro", "iPadAir4Cellular-iPadAir4Cellular",
    /// "AppleTV4KThirdGen-AppleTV4KThirdGen") into friendly device
    /// families, plus "Mac" when the `features` array flags a Mac Catalyst
    /// build. Verified against live lookups: e.g. Fantastical (a Universal
    /// Purchase app) returns `Watch*` entries here for its Apple Watch
    /// companion, but nothing Mac-related — its native Mac app is a
    /// separate track ID this endpoint has no way to expose. Apple TV
    /// codenames only ever appear on a `tvSoftware`-entity lookup — a
    /// plain `software`-entity lookup for the same app never includes them
    /// even when a real Apple TV build exists (verified live: Netflix's
    /// iOS-entity lookup has zero AppleTV-prefixed codenames, but the same
    /// track id's tvSoftware-entity lookup has four).
    static func deviceFamilies(supportedDevices: [String], features: [String]) -> [String] {
        var families: [String] = []
        if supportedDevices.contains(where: { $0.hasPrefix("iPhone") }) { families.append("iPhone") }
        if supportedDevices.contains(where: { $0.hasPrefix("iPad") }) { families.append("iPad") }
        if supportedDevices.contains(where: { $0.hasPrefix("iPodTouch") }) { families.append("iPod touch") }
        if supportedDevices.contains(where: { $0.hasPrefix("Watch") }) { families.append("Apple Watch") }
        if supportedDevices.contains(where: { $0.hasPrefix("AppleTV") }) { families.append("Apple TV") }
        if features.contains("macCatalyst") { families.append("Mac") }
        return families
    }

    /// Confirms whether a *known* App Store id (already resolved by a real
    /// `software`-entity search/lookup) genuinely has an Apple TV build,
    /// via a `tvSoftware`-entity lookup on that same id — not a name
    /// guess, since the id is already fixed. Returns the TV-flavored
    /// metadata (Apple TV screenshots, Apple TV device codenames) on
    /// confirmation, `nil` if the app has no Apple TV build or the lookup
    /// fails. Apple's public `search` endpoint's own `tvSoftware` entity is
    /// confirmed dead (always zero results, any query) — only `lookup` by
    /// id works, which is why this can't be a search.
    static func fetchTvOSSupport(appStoreId: String) async -> ItunesMetadata? {
        guard let meta = await fetchMetadata(appStoreId: appStoreId, entity: "tvSoftware"),
              meta.deviceFamilies.contains("Apple TV")
        else { return nil }
        return meta
    }

    /// Apple TV app search. Apple's `search` endpoint has no working
    /// `tvSoftware` entity (confirmed live: zero results for any query,
    /// including apps definitely on Apple TV like Disney+/Hulu/ESPN) — so
    /// this searches the `software` entity instead (which works reliably)
    /// and keeps only the candidates independently confirmed, via
    /// `fetchTvOSSupport`, to have a real Apple TV build. Checks are capped
    /// to the first `verifyLimit` raw hits to bound worst-case latency on
    /// a debounced search field, not because more candidates couldn't be
    /// legitimate matches.
    static func searchTvOS(_ query: String, limit: Int = 20, verifyLimit: Int = 8) async -> [ItunesSearchHit] {
        let candidates = await search(query, limit: limit, entity: "software")
        var confirmed: [ItunesSearchHit] = []
        for candidate in candidates.prefix(verifyLimit) {
            if await fetchTvOSSupport(appStoreId: candidate.appStoreId) != nil {
                confirmed.append(candidate)
            }
        }
        return confirmed
    }

    /// Mac metadata lookup — tries `macSoftware` first (a genuine, separate
    /// Mac App Store listing), then falls back to plain `software` (a Mac
    /// Catalyst app sharing its iOS listing entirely). Verified live that
    /// looking up a Catalyst app's id with `entity=macSoftware` returns
    /// zero results even though the app genuinely runs on Mac, and that a
    /// stale/removed id (AppleVis's own stored Mac App Store links can go
    /// stale — confirmed live against a real entry) simply returns `nil`
    /// from both, which every call site already handles by just not
    /// showing App Store data, same as any other failed lookup.
    static func fetchMacMetadata(appStoreUrl: String) async -> ItunesMetadata? {
        if case .found(let metadata) = await lookupMacMetadata(appStoreUrl: appStoreUrl) {
            return metadata
        }
        return nil
    }

    static func lookupMacMetadata(appStoreUrl: String) async -> ItunesMetadataLookupResult {
        let macResult = await lookupMetadata(appStoreUrl: appStoreUrl, entity: "macSoftware")
        if case .found = macResult { return macResult }
        if case .invalidLink = macResult { return macResult }

        let softwareResult = await lookupMetadata(appStoreUrl: appStoreUrl, entity: "software")
        if case .found = softwareResult { return softwareResult }
        if case .failed = macResult { return .failed }
        if case .failed = softwareResult { return .failed }
        return softwareResult
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

// Compiled once instead of per-call — same rationale as AppEndpoints.swift's
// own flexible-date formatters.
private let iso8601Formatter = ISO8601DateFormatter()
