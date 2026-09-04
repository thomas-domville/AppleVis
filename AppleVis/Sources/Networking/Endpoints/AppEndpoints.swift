import Foundation

extension APIClient {
    var apps: AppEndpoints { AppEndpoints(client: self) }
}

/// The native REST app-directory API's own platform slugs — confirmed live
/// to differ from `AppPlatform.rawValue` for two of the four platforms:
/// `/api/v1/apps/watchos/categories` and `/api/v1/apps/macos/categories`
/// both 404; the real slugs are `watch` and `mac`. This silently broke Mac
/// category browsing in Discover → App Directory from the start (picking
/// "Mac" always showed "No Categories") — a separate, pre-existing bug
/// found while confirming Apple Watch's own real slug. `rawValue` itself is
/// left alone since it's also this type's `Codable` wire format elsewhere.
/// Reported directly.
private extension AppPlatform {
    var restSlug: String {
        switch self {
        case .ios:     return "ios"
        case .macos:   return "mac"
        case .watchos: return "watch"
        case .tvos:    return "tvos" // still 404 — Apple TV has no REST category endpoint at all; see `categories(platform:)` below.
        }
    }
}

struct AppEndpoints {
    let client: APIClient

    private static let pageSize = 20

    /// Native REST — not consumed by any current screen, kept for API completeness.
    func platforms() async throws -> [String] {
        let raw: [JSONValue] = try await client.get("apps/platforms")
        return raw.compactMap { $0.stringValue ?? $0["id"]?.stringValue ?? $0["name"]?.stringValue }
    }

    /// Native REST category list for a platform, e.g. `/api/v1/apps/ios/categories`.
    /// Confirmed live that this REST resource simply doesn't exist for
    /// tvOS — `/api/v1/apps/tvos/categories` 404s, unlike `/apps/ios/categories`
    /// (200) — so tvOS categories are built directly from the taxonomy UUIDs
    /// already verified for `submitTvApp`'s `tvCategoryUUIDs`, with no
    /// network call at all. No live per-category counts are available this
    /// way (JSON:API here exposes no total-count field); `count: 0` is
    /// treated as "unknown" by the category list UI, not "empty."
    func categories(platform: AppPlatform) async throws -> [AppCategory] {
        if platform == .tvos {
            return Self.tvCategoryUUIDs.keys.sorted().map { name in
                let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
                return AppCategory(id: Self.tvCategoryUUIDs[name]!, name: name, slug: slug, tid: 0, count: 0)
            }
        }
        let raw: [JSONValue] = try await client.get("apps/\(platform.restSlug)/categories")
        return raw.compactMap { item -> AppCategory? in
            guard let name = item["name"]?.stringValue, !name.isEmpty else { return nil }
            let tid = item["tid"]?.intValue ?? 0
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            let count = item["count"]?.intValue ?? item["appCount"]?.intValue ?? item["app_count"]?.intValue ?? 0
            return AppCategory(id: tid > 0 ? "\(tid)" : slug, name: name, slug: slug, tid: tid, count: count)
        }
    }

    /// Category-scoped list uses the native REST directory API (the confirmed
    /// working path for app-directory browsing). A general (no category) list
    /// falls back to the JSON:API node listing sorted by last change.
    func list(page: Int = 0, platform: AppPlatform? = nil, categoryTid: Int? = nil, limit: Int = pageSize, forceRefresh: Bool = false) async throws -> PagedListResult<AppListing> {
        if let platform, let categoryTid {
            let result = try await categoryListing(platform: platform, categoryId: "\(categoryTid)", page: page, limit: limit, forceRefresh: forceRefresh)
            return PagedListResult(items: result.items, hasMore: result.hasMore)
        }
        return try await fetchWithCache(group: .apps, key: "apps:list:\(page)") {
            let response = try await client.jsonAPIList(
                "node/ios_app_directory",
                query: ["include": "uid", "sort": "-changed", "page[limit]": "\(Self.pageSize)", "page[offset]": "\(page * Self.pageSize)"]
            )
            let items = response.data.map { Mappers.app($0, included: response.included ?? []) }
            return PagedListResult(items: items, hasMore: response.hasNextPage)
        }
    }

    private nonisolated struct CategoryListingPage: Codable, Sendable {
        let items: [AppListing]
        let hasMore: Bool
    }

    func categoryListing(platform: AppPlatform, categoryId: String, page: Int, limit: Int = 20, forceRefresh: Bool = false) async throws -> (items: [AppListing], hasMore: Bool) {
        // The native REST directory API this whole function otherwise
        // relies on (`/apps/{platform}/categories/{id}`) doesn't exist for
        // tvOS at all — confirmed live (404, unlike ios/macos/watchos,
        // which all 200). Apple TV goes straight to JSON:API, filtered by
        // `field_category_tv`'s relationship UUID (verified live against
        // `/jsonapi/node/tv_directory` — `categoryId` here is that UUID,
        // per `categories(platform:)` above building tvOS's `AppCategory`
        // list from `tvCategoryUUIDs` directly).
        if platform == .tvos {
            let result = try await fetchWithCache(group: .apps, key: "apps:category:tvos:\(categoryId):\(page)", forceRefresh: forceRefresh) {
                try await jsonAPITvCategoryListing(categoryUUID: categoryId, page: page, limit: limit)
            }
            return (result.items, result.hasMore)
        }
        // Apple Watch's REST category-item endpoint accepts the request
        // (200, unlike tvOS) but always returns an empty array regardless
        // of the real, nonzero counts its own category-list endpoint just
        // reported — confirmed live across multiple categories, not a
        // one-off. Goes straight to JSON:API instead of trusting it.
        // Reported directly.
        if platform == .watchos {
            let result = try await fetchWithCache(group: .apps, key: "apps:category:watchos:\(categoryId):\(page)", forceRefresh: forceRefresh) {
                try await jsonAPIWatchCategoryListing(categoryTid: categoryId, page: page, limit: limit)
            }
            return (result.items, result.hasMore)
        }
        let result = try await fetchWithCache(group: .apps, key: "apps:category:\(platform.rawValue):\(categoryId):\(page)", forceRefresh: forceRefresh) {
            let raw: JSONValue = try await client.get(
                "apps/\(platform.restSlug)/categories/\(categoryId)",
                query: ["page": "\(page + 1)", "limit": "\(limit)"]
            )
            let rawItems: [JSONValue]
            let hasMore: Bool
            if let arr = raw.arrayValue {
                rawItems = arr
                hasMore = arr.count >= limit
            } else {
                rawItems = raw["items"]?.arrayValue ?? []
                hasMore = raw["hasMore"]?.boolValue ?? false
            }
            let items = rawItems.map { mapDirectoryListing($0, platform: platform) }
            if items.isEmpty, platform == .ios {
                return try await jsonAPICategoryListing(categoryId: categoryId, page: page, limit: limit)
            }
            return CategoryListingPage(items: items, hasMore: hasMore)
        }
        return (result.items, result.hasMore)
    }

    private func jsonAPICategoryListing(categoryId: String, page: Int, limit: Int) async throws -> CategoryListingPage {
        let response = try await client.jsonAPIList(
            "node/ios_app_directory",
            query: [
                "include": "uid,taxonomy_vocabulary_1",
                "sort": "-changed",
                "page[limit]": "\(limit)",
                "page[offset]": "\(page * limit)",
                "filter[category][condition][path]": "taxonomy_vocabulary_1.drupal_internal__tid",
                "filter[category][condition][value]": categoryId,
            ]
        )
        let items = response.data.map { Mappers.app($0, included: response.included ?? []) }
        return CategoryListingPage(items: items, hasMore: response.hasNextPage)
    }

    /// `field_category_tv.id` is the target term's own JSON:API UUID —
    /// verified live that Drupal's JSON:API accepts filtering a relationship
    /// directly by its related resource's `id`, no `drupal_internal__tid`
    /// traversal needed the way `jsonAPICategoryListing` above requires for
    /// iOS's `taxonomy_vocabulary_1`.
    private func jsonAPITvCategoryListing(categoryUUID: String, page: Int, limit: Int) async throws -> CategoryListingPage {
        let response = try await client.jsonAPIList(
            "node/tv_directory",
            query: [
                "include": "uid",
                "sort": "-changed",
                "page[limit]": "\(limit)",
                "page[offset]": "\(page * limit)",
                "filter[field_category_tv.id]": categoryUUID,
            ]
        )
        let items = response.data.map { Mappers.tvApp($0, included: response.included ?? []) }
        return CategoryListingPage(items: items, hasMore: response.hasNextPage)
    }

    /// Unlike Apple TV, `field_category_watch`'s relationship accepts tid
    /// path traversal the same way iOS's `taxonomy_vocabulary_1` does —
    /// verified live — so this uses the numeric tid `categories(platform:)`
    /// already returns from the (working) REST category list, rather than
    /// needing a separate name→UUID table the way TV's relationship
    /// required.
    private func jsonAPIWatchCategoryListing(categoryTid: String, page: Int, limit: Int) async throws -> CategoryListingPage {
        let response = try await client.jsonAPIList(
            "node/watch_directory",
            query: [
                "include": "uid",
                "sort": "-changed",
                "page[limit]": "\(limit)",
                "page[offset]": "\(page * limit)",
                "filter[field_category_watch.drupal_internal__tid]": categoryTid,
            ]
        )
        let items = response.data.map { Mappers.watchApp($0, included: response.included ?? []) }
        return CategoryListingPage(items: items, hasMore: response.hasNextPage)
    }

    /// Cross-category, title-CONTAINS search across the full App Directory —
    /// previously the only way to find an app was Platform → Category →
    /// paged list, with no way to type a name directly (APPS-01), a named
    /// violation of the master spec's explicit "Search and filters"
    /// requirement for this screen.
    func search(_ query: String) async throws -> [AppListing] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response = try await client.jsonAPIList(
            "node/ios_app_directory",
            query: ["include": "uid", "filter[title][operator]": "CONTAINS", "filter[title][value]": trimmed, "sort": "-changed", "page[limit]": "25"]
        )
        var results = response.data.map { Mappers.app($0, included: response.included ?? []) }
        // Best-effort, not `try await` like the iOS query above — a failure
        // here shouldn't turn a working iOS search into an error page.
        // Apple TV, Apple Watch, and Mac entries each live in their own
        // separate content type this search never covered before
        // (node/ios_app_directory only), so a search for a real TV, Watch,
        // or Mac app's name came back "No Results" even though it existed.
        // Reported directly.
        if let tvResponse = try? await client.jsonAPIList(
            "node/tv_directory",
            query: ["include": "uid", "filter[title][operator]": "CONTAINS", "filter[title][value]": trimmed, "sort": "-changed", "page[limit]": "25"]
        ) {
            results += tvResponse.data.map { Mappers.tvApp($0, included: tvResponse.included ?? []) }
        }
        if let watchResponse = try? await client.jsonAPIList(
            "node/watch_directory",
            query: ["include": "uid", "filter[title][operator]": "CONTAINS", "filter[title][value]": trimmed, "sort": "-changed", "page[limit]": "25"]
        ) {
            results += watchResponse.data.map { Mappers.watchApp($0, included: watchResponse.included ?? []) }
        }
        if let macResponse = try? await client.jsonAPIList(
            "node/mac_app_directory",
            query: ["include": "uid", "filter[title][operator]": "CONTAINS", "filter[title][value]": trimmed, "sort": "-changed", "page[limit]": "25"]
        ) {
            results += macResponse.data.map { Mappers.macApp($0, included: macResponse.included ?? []) }
        }
        return results
    }

    /// Title-contains lookup against the existing directory, run before a new
    /// submission — legacy's `submit-wizard/confirm.tsx` `checkForDuplicate()`
    /// had no native equivalent anywhere (SUBMIT-004): a submitter had no way
    /// to know they were about to duplicate an existing entry.
    func checkForDuplicate(appName: String, appStoreUrl: String? = nil, platform: AppPlatform? = nil) async throws -> AppDuplicateCheckResult {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AppDuplicateCheckResult(matches: [], exactMatches: []) }
        let response = try await client.jsonAPIList(
            "node/ios_app_directory",
            query: ["include": "uid", "filter[title][operator]": "CONTAINS", "filter[title][value]": trimmed, "page[limit]": "25"]
        )
        var listings = response.data.map { Mappers.app($0, included: response.included ?? []) }
        if let appStoreId = Self.appStoreId(from: appStoreUrl) {
            for field in ["field_link2.uri", "field_link3.uri"] {
                if let linkResponse = try? await client.jsonAPIList(
                    "node/ios_app_directory",
                    query: ["include": "uid", "filter[\(field)][operator]": "CONTAINS", "filter[\(field)][value]": appStoreId, "page[limit]": "10"]
                ) {
                    listings += linkResponse.data.map { Mappers.app($0, included: linkResponse.included ?? []) }
                }
            }
            var seen: Set<String> = []
            listings = listings.filter { seen.insert($0.id).inserted }
        }
        return AppDuplicateCheckResult(
            matches: listings,
            exactMatches: listings.filter { candidate in
                guard platform == nil || candidate.platform == platform else { return false }
                return Self.sameAppStoreApp(candidate.appStoreUrl, appStoreUrl)
            }
        )
    }

    private static func sameAppStoreApp(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhsId = appStoreId(from: lhs), let rhsId = appStoreId(from: rhs) else { return false }
        return lhsId == rhsId
    }

    private static func appStoreId(from value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let patterns = [
            #"/id(\d+)"#,
            #"[?&]id=(\d+)"#,
            #"\bid(\d+)\b"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            guard let match = regex.firstMatch(in: value, range: range), match.numberOfRanges > 1,
                  let idRange = Range(match.range(at: 1), in: value)
            else { continue }
            return String(value[idRange])
        }
        return nil
    }

    /// Fetches an app listing with full body text and all reviews.
    /// `platform` picks which of the four entirely separate content types
    /// to query — `node--ios_app_directory` (iOS only — macOS turned out to
    /// have its own `node--mac_app_directory`, the same class of wrong
    /// assumption TV and Watch had, found while confirming Watch's real
    /// REST slug), `node--tv_directory`, `node--watch_directory`, or
    /// `node--mac_app_directory`. When `nil` (a deep link, Spotlight
    /// result, or notification only ever carries a content id, never a
    /// platform), this tries iOS first — the far larger directory — then
    /// TV, then Watch, then Mac, on successive not-founds, rather than
    /// silently assuming iOS and permanently failing to open an entry from
    /// one of the other three reached that way.
    func detail(id: String, platform: AppPlatform? = nil) async throws -> AppDetail {
        if platform == .tvos {
            return try await tvDetail(id: id)
        }
        if platform == .watchos {
            return try await watchDetail(id: id)
        }
        if platform == .macos {
            return try await macDetail(id: id)
        }
        if platform == nil {
            do {
                return try await iosDetail(id: id)
            } catch APIError.notFound {
                do {
                    return try await tvDetail(id: id)
                } catch APIError.notFound {
                    do {
                        return try await watchDetail(id: id)
                    } catch APIError.notFound {
                        return try await macDetail(id: id)
                    }
                }
            }
        }
        return try await iosDetail(id: id)
    }

    /// Review bundle confirmed: comment_node_ios_app_directory.
    private func iosDetail(id: String) async throws -> AppDetail {
        try await fetchWithCache(group: .apps, key: "apps:detail:\(id)") {
            async let appRes = client.jsonAPISingle("node/ios_app_directory/\(id)", query: ["include": "uid"])
            async let reviewsRes = client.jsonAPIList(
                "comment/comment_node_ios_app_directory",
                query: ["filter[entity_id.id]": id, "sort": "-created", "page[limit]": "100", "include": "uid"]
            )

            let appResponse: JsonApiSingleResponse
            do {
                appResponse = try await appRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = appResponse.data
            let a = node.attributes
            let listing = Mappers.app(node, included: appResponse.included ?? [])

            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let reviewsResponse = try await reviewsRes
            let reviews = reviewsResponse.data.map { Mappers.appReview($0, included: reviewsResponse.included ?? []) }

            return AppDetail(
                id: listing.id,
                nid: a["drupal_internal__nid"]?.intValue ?? 0,
                name: listing.name,
                developer: listing.developer,
                platform: listing.platform,
                category: listing.category,
                categoryId: listing.categoryId,
                reviewCount: listing.reviewCount,
                lastUpdatedAt: listing.lastUpdatedAt,
                createdAt: listing.createdAt,
                submittedBy: listing.submittedBy,
                submitterUid: listing.submitterUid,
                appStoreUrl: listing.appStoreUrl,
                iconUrl: listing.iconUrl,
                price: listing.price,
                supportedDevices: listing.supportedDevices,
                voiceOverPerformance: listing.voiceOverPerformance,
                buttonLabelling: a["field_labelling"]?.stringValue,
                usabilityNotes: a["field_usability"]?.stringValue,
                body: a["body"]?.richTextValue ?? "",
                reviewedVersion: a["field_version"]?.stringValue,
                testedOnIOS: a["field_ios_version"]?.stringValue,
                accessibilityComments: a["field_comments"]?.richTextValue,
                url: listing.url,
                reviews: reviews,
                isSaved: false
            )
        }
    }

    /// Apple TV's own, much smaller field set — verified live against
    /// `/jsonapi/node/tv_directory`: no `field_labelling`, `field_version`,
    /// or `field_ios_version` at all (those simply don't exist for this
    /// content type), and `field_usability_tv` instead of `field_usability`.
    /// Review bundle confirmed live: comment_node_tv_directory, same
    /// subject/comment_body/uid shape as iOS's.
    private func tvDetail(id: String) async throws -> AppDetail {
        try await fetchWithCache(group: .apps, key: "apps:detail:tv:\(id)") {
            async let appRes = client.jsonAPISingle("node/tv_directory/\(id)", query: ["include": "uid"])
            async let reviewsRes = client.jsonAPIList(
                "comment/comment_node_tv_directory",
                query: ["filter[entity_id.id]": id, "sort": "-created", "page[limit]": "100", "include": "uid"]
            )

            let appResponse: JsonApiSingleResponse
            do {
                appResponse = try await appRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = appResponse.data
            let a = node.attributes
            let listing = Mappers.tvApp(node, included: appResponse.included ?? [])

            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let reviewsResponse = try await reviewsRes
            let reviews = reviewsResponse.data.map { Mappers.appReview($0, included: reviewsResponse.included ?? []) }

            return AppDetail(
                id: listing.id,
                nid: a["drupal_internal__nid"]?.intValue ?? 0,
                name: listing.name,
                developer: listing.developer,
                platform: listing.platform,
                category: listing.category,
                categoryId: listing.categoryId,
                reviewCount: listing.reviewCount,
                lastUpdatedAt: listing.lastUpdatedAt,
                createdAt: listing.createdAt,
                submittedBy: listing.submittedBy,
                submitterUid: listing.submitterUid,
                appStoreUrl: listing.appStoreUrl,
                iconUrl: listing.iconUrl,
                price: listing.price,
                supportedDevices: listing.supportedDevices,
                voiceOverPerformance: listing.voiceOverPerformance,
                buttonLabelling: nil,
                usabilityNotes: a["field_usability_tv"]?.stringValue,
                body: a["body"]?.richTextValue ?? "",
                reviewedVersion: nil,
                testedOnIOS: nil,
                accessibilityComments: a["field_comments"]?.richTextValue,
                url: listing.url,
                reviews: reviews,
                isSaved: false
            )
        }
    }

    /// Apple Watch's own field set — verified live against
    /// `/jsonapi/node/watch_directory`: closer to iOS than TV (a real
    /// `field_link2` App Store link, plus its own `field_watchos_version`),
    /// but like TV, a single combined `field_usability_watch` instead of
    /// iOS's split `field_voiceover`/`field_labelling`. Review bundle
    /// confirmed live: comment_node_watch_directory, same
    /// subject/comment_body/uid shape as the other two.
    private func watchDetail(id: String) async throws -> AppDetail {
        try await fetchWithCache(group: .apps, key: "apps:detail:watch:\(id)") {
            async let appRes = client.jsonAPISingle("node/watch_directory/\(id)", query: ["include": "uid"])
            async let reviewsRes = client.jsonAPIList(
                "comment/comment_node_watch_directory",
                query: ["filter[entity_id.id]": id, "sort": "-created", "page[limit]": "100", "include": "uid"]
            )

            let appResponse: JsonApiSingleResponse
            do {
                appResponse = try await appRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = appResponse.data
            let a = node.attributes
            let listing = Mappers.watchApp(node, included: appResponse.included ?? [])

            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let reviewsResponse = try await reviewsRes
            let reviews = reviewsResponse.data.map { Mappers.appReview($0, included: reviewsResponse.included ?? []) }

            return AppDetail(
                id: listing.id,
                nid: a["drupal_internal__nid"]?.intValue ?? 0,
                name: listing.name,
                developer: listing.developer,
                platform: listing.platform,
                category: listing.category,
                categoryId: listing.categoryId,
                reviewCount: listing.reviewCount,
                lastUpdatedAt: listing.lastUpdatedAt,
                createdAt: listing.createdAt,
                submittedBy: listing.submittedBy,
                submitterUid: listing.submitterUid,
                appStoreUrl: listing.appStoreUrl,
                iconUrl: listing.iconUrl,
                price: listing.price,
                supportedDevices: listing.supportedDevices,
                voiceOverPerformance: listing.voiceOverPerformance,
                buttonLabelling: nil,
                usabilityNotes: a["field_usability_watch"]?.stringValue,
                body: a["body"]?.richTextValue ?? "",
                reviewedVersion: a["field_version"]?.stringValue,
                testedOnIOS: a["field_watchos_version"]?.stringValue,
                accessibilityComments: a["field_comments"]?.richTextValue,
                url: listing.url,
                reviews: reviews,
                isSaved: false
            )
        }
    }

    /// Mac's own field set — verified live against
    /// `/jsonapi/node/mac_app_directory`: `field_version` and its own
    /// `field_osx_version` ("Version Of macOS App Was Tested On"), the
    /// full 8-option iOS Usability vocabulary as a single `field_usability`
    /// field (no split VoiceOver/Labelling), and — unlike every other
    /// platform — a genuinely optional `field_link2` App Store link, plus
    /// its own `field_link_macupdate` fallback reference for apps not in
    /// the Mac App Store at all. Review bundle confirmed live:
    /// comment_node_mac_app_directory, same subject/comment_body/uid shape
    /// as the other three.
    private func macDetail(id: String) async throws -> AppDetail {
        try await fetchWithCache(group: .apps, key: "apps:detail:mac:\(id)") {
            async let appRes = client.jsonAPISingle("node/mac_app_directory/\(id)", query: ["include": "uid"])
            async let reviewsRes = client.jsonAPIList(
                "comment/comment_node_mac_app_directory",
                query: ["filter[entity_id.id]": id, "sort": "-created", "page[limit]": "100", "include": "uid"]
            )

            let appResponse: JsonApiSingleResponse
            do {
                appResponse = try await appRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = appResponse.data
            let a = node.attributes
            let listing = Mappers.macApp(node, included: appResponse.included ?? [])

            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let reviewsResponse = try await reviewsRes
            let reviews = reviewsResponse.data.map { Mappers.appReview($0, included: reviewsResponse.included ?? []) }

            return AppDetail(
                id: listing.id,
                nid: a["drupal_internal__nid"]?.intValue ?? 0,
                name: listing.name,
                developer: listing.developer,
                platform: listing.platform,
                category: listing.category,
                categoryId: listing.categoryId,
                reviewCount: listing.reviewCount,
                lastUpdatedAt: listing.lastUpdatedAt,
                createdAt: listing.createdAt,
                submittedBy: listing.submittedBy,
                submitterUid: listing.submitterUid,
                appStoreUrl: listing.appStoreUrl,
                iconUrl: listing.iconUrl,
                price: listing.price,
                supportedDevices: listing.supportedDevices,
                voiceOverPerformance: listing.voiceOverPerformance,
                buttonLabelling: nil,
                usabilityNotes: a["field_usability"]?.stringValue,
                body: a["body"]?.richTextValue ?? "",
                reviewedVersion: a["field_version"]?.stringValue,
                testedOnIOS: a["field_osx_version"]?.stringValue,
                accessibilityComments: a["field_comments"]?.richTextValue,
                url: listing.url,
                reviews: reviews,
                isSaved: false,
                macUpdateUrl: a["field_link_macupdate"]?["uri"]?.stringValue
            )
        }
    }

    /// Fetches the next page of reviews beyond the initial 100 (used by
    /// "Load more reviews") — previously reviews had no pagination at all,
    /// the same bug class already fixed for Forums/Blogs/Guides/Podcasts:
    /// an app with more than 100 reviews permanently hid the rest.
    func moreReviews(appId: String, offset: Int, platform: AppPlatform) async throws -> [AppReview] {
        let response = try await client.jsonAPIList(
            "comment/\(Self.commentBundle(for: platform))",
            query: ["filter[entity_id.id]": appId, "sort": "-created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { Mappers.appReview($0, included: response.included ?? []) }
    }

    private static func commentBundle(for platform: AppPlatform) -> String {
        switch platform {
        case .tvos:    return "comment_node_tv_directory"
        case .watchos: return "comment_node_watch_directory"
        case .macos:   return "comment_node_mac_app_directory"
        case .ios:     return "comment_node_ios_app_directory"
        }
    }

    private static func nodeType(for platform: AppPlatform) -> String {
        switch platform {
        case .tvos:    return "tv_directory"
        case .watchos: return "watch_directory"
        case .macos:   return "mac_app_directory"
        case .ios:     return "ios_app_directory"
        }
    }

    func updateAppInformation(detail: AppDetail, metadata: ItunesMetadata, csrfToken: String) async throws {
        let nodeType = Self.nodeType(for: detail.platform)
        let title = metadata.appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? detail.name : metadata.appName
        let description = metadata.appStoreDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? detail.body
            : metadata.appStoreDescription

        var attributes: [String: AnyEncodable] = [
            "title": AnyEncodable(title),
            "body": AnyEncodable(RichTextBodyValue(value: description, summary: "", format: "basic_html")),
        ]

        if detail.platform != .tvos {
            let appStoreUrl = metadata.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            let version = metadata.version.trimmingCharacters(in: .whitespacesAndNewlines)
            if !appStoreUrl.isEmpty {
                attributes["field_link2"] = AnyEncodable(LinkValue(uri: appStoreUrl, title: ""))
            }
            if !version.isEmpty {
                attributes["field_version"] = AnyEncodable(version)
            }
        }

        try await client.jsonAPIUpdate(
            "node/\(nodeType)/\(detail.id)",
            type: "node--\(nodeType)",
            id: detail.id,
            attributes: attributes,
            headers: ["X-CSRF-Token": csrfToken]
        )

        switch detail.platform {
        case .ios:
            ContentCache.shared.remove(key: "apps:detail:\(detail.id)")
        case .tvos:
            ContentCache.shared.remove(key: "apps:detail:tv:\(detail.id)")
        case .watchos:
            ContentCache.shared.remove(key: "apps:detail:watch:\(detail.id)")
        case .macos:
            ContentCache.shared.remove(key: "apps:detail:mac:\(detail.id)")
        }
    }

    @discardableResult
    func submitReview(appId: String, subject: String = "Review", body: String, csrfToken: String, platform: AppPlatform) async throws -> AppReview {
        let nodeType = Self.nodeType(for: platform)
        let commentBundle = Self.commentBundle(for: platform)
        let response = try await client.jsonAPICreate(
            "comment/\(commentBundle)",
            type: "comment--\(commentBundle)",
            attributes: [
                "subject": AnyEncodable(subject.isEmpty ? "Review" : subject),
                "comment_body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--\(nodeType)", id: appId),
                "comment_type": JsonApiRelationshipRef(type: "comment_type--comment_type", id: commentBundle),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        return Mappers.appReview(response.data, included: response.included ?? [])
    }

    /// Submit a new app entry. Category UUIDs are fixed vocabulary_1 term IDs
    /// (ported from the RN reference client's confirmed live mapping).
    ///
    /// Field list, required-ness, and exact allowed values below were all
    /// verified directly against the live HTML form at
    /// /node/add/ios_app_directory (not assumed) — several were wrong
    /// before this: `field_device_used` is a real Drupal list_string field
    /// taking an array of its exact term values, not a free-joined string;
    /// `body` is server-required, not conditional; and `field_link3`
    /// ("Developer's Website") existed on the form but was never submitted
    /// at all. Reported directly.
    func submitApp(payload: SubmitAppPayload, csrfToken: String) async throws -> (nid: Int, nodeUrl: String) {
        let bodySummary = await Self.bodySummary(
            appName: payload.appName,
            description: payload.appStoreDescription
        )
        var attributes: [String: AnyEncodable] = [
            "title": AnyEncodable(payload.appName),
            "status": AnyEncodable(true),
            "field_link2": AnyEncodable(LinkValue(uri: payload.appStoreUrl, title: "")),
            "field_version": AnyEncodable(payload.appVersion),
            "field_cost": AnyEncodable(payload.price),
            "field_device_used": AnyEncodable(payload.supportedDevices),
            "field_ios_version": AnyEncodable(payload.osVersion),
            "field_voiceover": AnyEncodable(payload.voiceOverPerformance),
            "field_labelling": AnyEncodable(payload.buttonLabelling),
            "field_usability": AnyEncodable(payload.usabilityNotes),
            "field_comments": AnyEncodable(RichTextValue(value: payload.accessibilityComments, format: "basic_html")),
            "body": AnyEncodable(RichTextBodyValue(value: payload.appStoreDescription, summary: bodySummary, format: "basic_html")),
        ]
        if !payload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_other_comments"] = AnyEncodable(RichTextValue(value: payload.otherComments, format: "basic_html"))
        }
        if !payload.developerWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_link3"] = AnyEncodable(LinkValue(uri: payload.developerWebsite, title: ""))
        }

        var relationships: [String: JsonApiRelationshipRef] = [:]
        if let uuid = Self.categoryUUIDs[payload.category] {
            relationships["taxonomy_vocabulary_1"] = JsonApiRelationshipRef(type: "taxonomy_term--vocabulary_1", id: uuid)
        }

        let response = try await client.jsonAPICreate(
            "node/ios_app_directory",
            type: "node--ios_app_directory",
            attributes: attributes,
            relationships: relationships,
            headers: ["X-CSRF-Token": csrfToken]
        )
        let a = response.data.attributes
        let nid = a["drupal_internal__nid"]?.intValue ?? 0
        let alias = a["path"]?.pathAlias
        let nodeUrl = alias.map { "https://www.applevis.com\($0)" } ?? "https://www.applevis.com/node/\(nid)"
        return (nid, nodeUrl)
    }

    private static func bodySummary(appName: String, description: String) async -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let aiSummary = await IntelligenceService.appDirectoryTeaser(appName: appName, description: trimmed) {
            let cleaned = cleanBodySummary(aiSummary)
            if !cleaned.isEmpty { return cleaned }
        }

        return fallbackBodySummary(from: trimmed)
    }

    private static func fallbackBodySummary(from description: String) -> String {
        let normalized = description
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        if let punctuationIndex = normalized.firstIndex(where: { ".!?".contains($0) }) {
            let end = normalized.index(after: punctuationIndex)
            return cleanBodySummary(String(normalized[..<end]))
        }
        return cleanBodySummary(normalized)
    }

    private static func cleanBodySummary(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        cleaned = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard cleaned.count > 220 else { return cleaned }

        let hardEnd = cleaned.index(cleaned.startIndex, offsetBy: 220)
        var shortened = String(cleaned[..<hardEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastSpace = shortened.lastIndex(of: " ") {
            shortened = String(shortened[..<lastSpace])
        }
        return shortened
    }

    /// Submits a standalone Apple TV app directory entry — a genuinely
    /// separate Drupal content type (`node--tv_directory`) from iOS's
    /// `node--ios_app_directory`, not a variant of it. Selecting "Apple TV"
    /// in the platform picker previously still called `submitApp` above,
    /// which always posted to the iOS content type regardless of platform
    /// — every field on that payload is shaped for iOS (App Store URL,
    /// Version, Device(s) Tested On, separate VoiceOver/Labelling ratings)
    /// and none of it matches what this content type actually accepts.
    /// Field list, required-ness, category taxonomy, and the exact
    /// `field_category_tv` relationship shape below were all verified
    /// live: the public HTML form at /node/add/tv_directory (not assumed —
    /// it has no App Store link, Version, Device(s) Tested On, or
    /// Developer's Website fields at all, and a single combined Usability
    /// scale instead of separate VoiceOver/Labelling questions), and the
    /// category vocabulary's real machine name and term UUIDs via a
    /// read-only JSON:API request against the live site (the vocabulary's
    /// actual machine name is `apple_tb_app_directory` — apparently a
    /// long-standing typo on Drupal's side, not a guess on this end).
    /// Reported directly.
    func submitTvApp(payload: SubmitTvAppPayload, csrfToken: String) async throws -> (nid: Int, nodeUrl: String) {
        var attributes: [String: AnyEncodable] = [
            "title": AnyEncodable(payload.appName),
            "status": AnyEncodable(true),
            "field_cost": AnyEncodable(payload.price),
            "field_usability_tv": AnyEncodable(payload.usability),
            "field_comments": AnyEncodable(RichTextValue(value: payload.accessibilityComments, format: "basic_html")),
            "body": AnyEncodable(RichTextBodyValue(value: payload.appDescription, summary: "", format: "basic_html")),
        ]
        if !payload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_other_comments"] = AnyEncodable(RichTextValue(value: payload.otherComments, format: "basic_html"))
        }

        var relationships: [String: JsonApiRelationshipRef] = [:]
        if let uuid = Self.tvCategoryUUIDs[payload.category] {
            relationships["field_category_tv"] = JsonApiRelationshipRef(type: "taxonomy_term--apple_tb_app_directory", id: uuid)
        }

        let response = try await client.jsonAPICreate(
            "node/tv_directory",
            type: "node--tv_directory",
            attributes: attributes,
            relationships: relationships,
            headers: ["X-CSRF-Token": csrfToken]
        )
        let a = response.data.attributes
        let nid = a["drupal_internal__nid"]?.intValue ?? 0
        let alias = a["path"]?.pathAlias
        let nodeUrl = alias.map { "https://www.applevis.com\($0)" } ?? "https://www.applevis.com/node/\(nid)"
        return (nid, nodeUrl)
    }

    /// Submits a standalone Apple Watch app directory entry — a genuinely
    /// separate Drupal content type (`node--watch_directory`), distinct
    /// from both `node--ios_app_directory` and `node--tv_directory`.
    /// Closer to iOS than TV: it has a real App Store link
    /// (`field_link2`/`field_link3`) and its own version fields
    /// (`field_version` and `field_watchos_version`), but — like TV — a
    /// single combined `field_usability_watch` scale instead of iOS's
    /// split VoiceOver/Labelling questions, and no Device(s) Tested On
    /// field at all. Field list, required-ness, and the category
    /// vocabulary's real machine name/term UUIDs below were all verified
    /// live against the public HTML form at /node/add/watch_directory and
    /// a read-only JSON:API request, the same way TV's were. Reported
    /// directly — this also corrects an old assumption baked into the
    /// platform picker before today ("watchOS apps ship bundled in an iOS
    /// entry, not submitted separately"), which turned out to be wrong.
    func submitWatchApp(payload: SubmitWatchAppPayload, csrfToken: String) async throws -> (nid: Int, nodeUrl: String) {
        var attributes: [String: AnyEncodable] = [
            "title": AnyEncodable(payload.appName),
            "status": AnyEncodable(true),
            "field_link2": AnyEncodable(LinkValue(uri: payload.appStoreUrl, title: "")),
            "field_version": AnyEncodable(payload.appVersion),
            "field_cost": AnyEncodable(payload.price),
            "field_watchos_version": AnyEncodable(payload.watchosVersion),
            "field_usability_watch": AnyEncodable(payload.usability),
            "field_comments": AnyEncodable(RichTextValue(value: payload.accessibilityComments, format: "basic_html")),
            "body": AnyEncodable(RichTextBodyValue(value: payload.appDescription, summary: "", format: "basic_html")),
        ]
        if !payload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_other_comments"] = AnyEncodable(RichTextValue(value: payload.otherComments, format: "basic_html"))
        }
        if !payload.developerWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_link3"] = AnyEncodable(LinkValue(uri: payload.developerWebsite, title: ""))
        }

        var relationships: [String: JsonApiRelationshipRef] = [:]
        if let uuid = Self.watchCategoryUUIDs[payload.category] {
            relationships["field_category_watch"] = JsonApiRelationshipRef(type: "taxonomy_term--apple_watch_app_directory", id: uuid)
        }

        let response = try await client.jsonAPICreate(
            "node/watch_directory",
            type: "node--watch_directory",
            attributes: attributes,
            relationships: relationships,
            headers: ["X-CSRF-Token": csrfToken]
        )
        let a = response.data.attributes
        let nid = a["drupal_internal__nid"]?.intValue ?? 0
        let alias = a["path"]?.pathAlias
        let nodeUrl = alias.map { "https://www.applevis.com\($0)" } ?? "https://www.applevis.com/node/\(nid)"
        return (nid, nodeUrl)
    }

    /// Submits a standalone Mac app directory entry — a genuinely separate
    /// Drupal content type (`node--mac_app_directory`), distinct from
    /// `node--ios_app_directory`. Field list, required-ness, category
    /// vocabulary, and the exact `taxonomy_vocabulary_16` relationship
    /// shape below were all verified live against the public HTML form at
    /// /node/add/mac_app_directory. The one field genuinely optional here
    /// that's required on every other platform's App Store link: a real,
    /// sizable share of Mac apps aren't in the Mac App Store at all
    /// (confirmed live against real AppleVis Mac entries — VMware Fusion,
    /// Xcode, 1Password, and others have none), which is exactly why this
    /// content type also has its own `field_link_macupdate` — a fallback
    /// reference to the app's MacUpdate.com listing, unique to Mac among
    /// all four directories. Reported directly, discussed explicitly.
    func submitMacApp(payload: SubmitMacAppPayload, csrfToken: String) async throws -> (nid: Int, nodeUrl: String) {
        var attributes: [String: AnyEncodable] = [
            "title": AnyEncodable(payload.appName),
            "status": AnyEncodable(true),
            "field_version": AnyEncodable(payload.appVersion),
            "field_cost": AnyEncodable(payload.price),
            "field_osx_version": AnyEncodable(payload.osxVersionTested),
            "field_usability": AnyEncodable(payload.usability),
            "field_comments": AnyEncodable(RichTextValue(value: payload.accessibilityComments, format: "basic_html")),
            "body": AnyEncodable(RichTextBodyValue(value: payload.appDescription, summary: "", format: "basic_html")),
        ]
        if !payload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_other_comments"] = AnyEncodable(RichTextValue(value: payload.otherComments, format: "basic_html"))
        }
        if !payload.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_link2"] = AnyEncodable(LinkValue(uri: payload.appStoreUrl, title: ""))
        }
        if !payload.developerWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_link3"] = AnyEncodable(LinkValue(uri: payload.developerWebsite, title: ""))
        }
        if !payload.macUpdateUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_link_macupdate"] = AnyEncodable(LinkValue(uri: payload.macUpdateUrl, title: ""))
        }

        var relationships: [String: JsonApiRelationshipRef] = [:]
        if let uuid = Self.macCategoryUUIDs[payload.category] {
            relationships["taxonomy_vocabulary_16"] = JsonApiRelationshipRef(type: "taxonomy_term--vocabulary_16", id: uuid)
        }

        let response = try await client.jsonAPICreate(
            "node/mac_app_directory",
            type: "node--mac_app_directory",
            attributes: attributes,
            relationships: relationships,
            headers: ["X-CSRF-Token": csrfToken]
        )
        let a = response.data.attributes
        let nid = a["drupal_internal__nid"]?.intValue ?? 0
        let alias = a["path"]?.pathAlias
        let nodeUrl = alias.map { "https://www.applevis.com\($0)" } ?? "https://www.applevis.com/node/\(nid)"
        return (nid, nodeUrl)
    }

    /// `vocabulary_16` term UUIDs — fetched live via
    /// /jsonapi/taxonomy_term/vocabulary_16, same approach as the other
    /// three category tables. Mac's own real 21-category set — note
    /// "Photography"/"Video"/"Sports" here where iOS uses "Photo and
    /// Video"/"Sports and Activities" instead; not a typo, verified
    /// against the live form's option text exactly.
    private static let macCategoryUUIDs: [String: String] = [
        "Business": "3ab1c107-3295-4f0b-8e56-2bf74d0d7569",
        "Developer Tools": "52c41775-c7ff-49e7-93af-ed08723c5210",
        "Education": "90db90ef-90a1-4027-9cd5-6473eb1f891e",
        "Entertainment": "50328f80-6bcf-47ef-ab22-48753996ed6e",
        "Finance": "57e5d9ba-47c6-429a-bb7f-d59522023ac1",
        "Games": "069a76c9-ebea-42a1-b355-54c8d9ad1c05",
        "Graphics and Design": "4e2deea5-1922-4561-a4fa-5a88023dda25",
        "Health and Fitness": "fd3ddbf7-9055-4bf7-9fd9-05a3a105770f",
        "Lifestyle": "b6d8e527-c46c-4e69-8827-8013b7438208",
        "Medical": "02b9fe1e-9e60-4f06-a043-658daf4f07f6",
        "Music": "6ad779ec-afa4-4893-928b-f9257d885142",
        "News": "c97f55d0-b187-40dc-8baf-4656d826fdbd",
        "Photography": "fa9cdba9-6059-415c-959a-1432071cc657",
        "Productivity": "9a0d439b-0f5a-4206-b85b-92169897d02e",
        "Reference": "fb2e57ba-89f5-4e80-b736-cddc0291b9cd",
        "Social Networking": "9d57670f-33ee-44e7-918a-d23a524cc0e0",
        "Sports": "81fa7761-60e1-46db-bcf2-d64fe655e4d8",
        "Travel": "3caf3488-ad25-465c-b3ba-42c0638cc4ce",
        "Utilities": "42ec734e-c72d-4d6f-bffb-abea85b50f65",
        "Video": "681c0e58-4595-427c-a904-f41135a41cfb",
        "Weather": "04c80db2-eb22-4580-81f3-5a0969699657",
    ]

    /// `apple_watch_app_directory` vocabulary term UUIDs — fetched live via
    /// /jsonapi/taxonomy_term/apple_watch_app_directory, same approach as
    /// `tvCategoryUUIDs` above. This directory's own real 21-category set,
    /// verified to match the live form's option values exactly.
    private static let watchCategoryUUIDs: [String: String] = [
        "Books": "a3b4aede-646d-43ce-a522-c76957a4c06d",
        "Business": "a756b2a8-20ef-41bf-b3bc-1a7cac4f2242",
        "Education": "237b4581-70ee-4760-8a24-024686cc9e6d",
        "Entertainment": "2506f784-3ab3-4e74-ac65-953d46f17623",
        "Finance": "07373c19-6bae-46d9-be1b-fc8cecf47337",
        "Food and Drink": "bd06a2e5-da74-4e37-aae7-f5a643e9ce82",
        "Games": "a40c79fe-9226-46ea-97c1-c7c8cbf8fa72",
        "Health and Fitness": "b00897e2-a715-494a-903b-1f072ce919af",
        "Lifestyle": "c32f0d74-d733-4158-a5c7-53f457e6e6a1",
        "Medical": "8f2010f5-17dd-4cdd-b345-b8fcd7ed025b",
        "Music": "9ec81d70-4b3c-4924-8711-6cf12966dbf2",
        "Navigation": "fbbdcf66-9a87-457a-ab5b-5b28329fa559",
        "News": "4e7c68e5-3a34-4d26-a0dd-4c1df5070729",
        "Photo and Video": "e91b3cd5-9b0d-4d50-918f-90611826aee6",
        "Productivity": "e3ef9722-0828-4cb6-b086-5ad48ae68171",
        "Reference": "03710f92-f8aa-434d-8c3f-bdefd7a1a3d6",
        "Social Networking": "0a40fc40-2d9b-453d-acff-5f7ccb0e090b",
        "Sports": "44adaf99-e018-4ed8-b6f8-aae96d93a1a6",
        "Travel": "0685af34-40fd-4415-a209-85753b6462d5",
        "Utilities": "53786823-b975-4581-85da-12560ba57971",
        "Weather": "3b2475c5-9610-4450-8c67-3c02e6848d0b",
    ]

    /// `apple_tb_app_directory` vocabulary term UUIDs — fetched live via
    /// /jsonapi/taxonomy_term/apple_tb_app_directory, same approach as
    /// `categoryUUIDs` above. Deliberately a shorter list than iOS's 27
    /// categories (14 here) — this is the TV directory's own real category
    /// set, not a trimmed copy.
    private static let tvCategoryUUIDs: [String: String] = [
        "Books": "edea6944-b567-4537-ad70-6fb3360b0037",
        "Business": "eb4e910f-112b-4329-ba5a-da318737bb16",
        "Catalogs": "7e836acf-52db-4249-879b-a785eaed1b03",
        "Entertainment": "622e1320-3b8f-44a4-82f0-ee50808ce82b",
        "Finance": "88f2c419-a2e2-4fc6-b31b-ccc62239ff68",
        "Games": "76cd1d66-f08f-4ed1-811b-ed03e9a9d74c",
        "Medical": "49bfac53-e00b-4d56-8a3a-b80e6592140d",
        "Music": "8db1d6cf-e7a7-4c03-a7b9-566f90a30e0d",
        "Productivity": "5e5608f5-fff1-47b8-b34a-3a9a6fd7d8ad",
        "Reference": "52679a05-3b0b-4892-8857-0a04dc19654c",
        "Social Networking": "e28d12da-5d8d-404c-9941-a3a0c11bca6a",
        "Travel": "5b525051-eeb0-45c4-9cb1-6e0f3ff0656b",
        "Utilities": "f356f594-292c-43d5-a2bc-29caf9c266a0",
        "Weather": "f76157d3-e055-447c-94ab-8c576008c5bc",
    ]

    // Vocabulary 1 category UUIDs — fetched from /jsonapi/taxonomy_term/vocabulary_1.
    private static let categoryUUIDs: [String: String] = [
        "Books": "bee9a94d-2a9c-4b1d-8ea7-8e9d0c3fc3dd",
        "Business": "20dcbad3-c417-48e3-8b5b-ff4069f87d7b",
        "Catalogs": "87aae28a-0741-4f66-b440-63aacccaf29f",
        "Developer Tools": "16251ccf-925e-453a-848d-8e1b33dffb71",
        "Education": "8726dafb-e470-4338-9dd0-a868144a5d7f",
        "Entertainment": "7f69826f-a3b0-4fc4-b7d4-7fbdacb5cfcc",
        "Finance": "6425c1d3-6ee4-4724-ac76-5443f58ec373",
        "Food and Drink": "b1a99efd-7626-4fb5-bfe4-1c14ad0947f2",
        "Games": "a63cc23a-836a-4068-8f23-b3afbf5b994e",
        "Graphics and Design": "a2cc7759-0e37-4188-a4a2-b9f2188793ce",
        "Health and Fitness": "0cb652cc-2b6c-4d43-bf50-5d42471c8b81",
        "Lifestyle": "387c7f86-4719-43ee-a36f-a2f043b10c44",
        "Medical": "c36d6ca0-fef3-41d8-9b96-5530828d4895",
        "Music": "042bdef6-e708-4375-bd86-b6b2ee53e484",
        "Navigation": "551ed39e-0816-40b5-8c5b-fb9c700eaf9e",
        "News": "62329830-4955-46a9-99b4-ccc2ff49a676",
        "Photo and Video": "a8cfec9b-e132-42ee-9169-a0e404204656",
        "Productivity": "cc18cc76-e08e-4037-a3bf-064f5f5b696f",
        "Reference": "a4475fb2-444b-420c-9bf5-d2c29bb02044",
        "Safari Extensions": "55a3c4a5-1b9f-43f1-8c3d-0eeee3eb57f2",
        "Shopping": "21d1f775-a5d3-45de-b421-3e90c9c51873",
        "Social Networking": "33821fa2-114a-467f-a7a1-04f699ee53b6",
        "Sports and Activities": "a901f670-1d53-4eb3-9e43-82653568e1f1",
        "Stickers": "2e3945ff-9876-403d-8aea-1178f4647864",
        "Travel": "17c20229-4532-4e40-8853-88da8d9a8c46",
        "Utilities": "870e83b5-6299-4d30-96e5-b54ae778dea5",
        "Weather": "5df92429-93bc-4d33-a882-a303b899959e",
    ]
}

struct SubmitAppPayload {
    var appName = ""
    var appStoreUrl = ""
    var appVersion = ""
    var price = ""
    var supportedDevices: [String] = []
    /// "Developer's Website" (field_link3) — genuinely optional on the live
    /// form, unlike everything else in this struct.
    var developerWebsite = ""
    var appStoreDescription = ""
    var category = ""
    var osVersion = ""
    var voiceOverPerformance = ""
    var buttonLabelling = ""
    var usabilityNotes = ""
    var accessibilityComments = ""
    var otherComments = ""
}

/// Separate from `SubmitAppPayload` because the two content types genuinely
/// don't share a field shape — no App Store link, Version, Device(s)
/// Tested On, Developer's Website, or split VoiceOver/Labelling ratings.
/// Verified directly against the live /node/add/tv_directory form.
struct SubmitTvAppPayload {
    var appName = ""
    var category = ""
    var appDescription = ""
    var price = ""
    var usability = ""
    var accessibilityComments = ""
    var otherComments = ""
}

/// Closer in shape to `SubmitAppPayload` than `SubmitTvAppPayload` is — a
/// real App Store link and version fields — but still its own struct:
/// no Device(s) Tested On, and a single `usability` field rather than
/// split VoiceOver/Labelling ratings. Verified directly against the live
/// /node/add/watch_directory form.
struct SubmitWatchAppPayload {
    var appName = ""
    var appStoreUrl = ""
    var appVersion = ""
    var watchosVersion = ""
    var price = ""
    var developerWebsite = ""
    var appDescription = ""
    var category = ""
    var usability = ""
    var accessibilityComments = ""
    var otherComments = ""
}

/// The only one of the four platform payloads where the App Store link is
/// genuinely optional, matching the live /node/add/mac_app_directory form
/// — a real share of Mac apps aren't in the Mac App Store at all.
/// `macUpdateUrl` is unique to this payload: a fallback reference to the
/// app's MacUpdate.com listing, for exactly that case. Uses the same
/// 8-option iOS Usability vocabulary as `SubmitAppPayload.usabilityNotes`
/// (as a single field, not iOS's split VoiceOver/Labelling), unlike
/// `SubmitTvAppPayload`/`SubmitWatchAppPayload`'s simpler 4-option scale.
struct SubmitMacAppPayload {
    var appName = ""
    var appStoreUrl = ""
    var macUpdateUrl = ""
    var appVersion = ""
    var osxVersionTested = ""
    var price = ""
    var developerWebsite = ""
    var appDescription = ""
    var category = ""
    var usability = ""
    var accessibilityComments = ""
    var otherComments = ""
}

private struct LinkValue: Encodable {
    let uri: String
    let title: String
}

private struct RichTextBodyValue: Encodable {
    let value: String
    let summary: String
    let format: String
}

/// Maps a loosely-shaped item from the native app-directory category REST
/// endpoint (field names vary/alias across responses — mirrors
/// mapDirectoryApiListing in the RN reference client).
private func mapDirectoryListing(_ item: JSONValue, platform: AppPlatform) -> AppListing {
    let id = item["id"]?.stringValue ?? item["uuid"]?.stringValue ?? item["nid"]?.stringValue ?? UUID().uuidString
    let rawName = item["name"]?.stringValue ?? item["title"]?.stringValue ?? ""
    let name = HTMLText.plainText(fromHTML: rawName)
    let rawSummary = item["summary"]?.stringValue ?? item["body"]?.stringValue ?? ""
    let url = item["url"]?.stringValue ?? item["path"]?.stringValue ?? ""
    let changedRaw = item["lastUpdatedAt"]?.stringValue ?? item["last_updated_at"]?.stringValue
        ?? item["changed"]?.stringValue ?? item["updated"]?.stringValue
    return AppListing(
        id: id,
        nid: item["nid"]?.intValue ?? item["node_id"]?.intValue,
        name: name,
        developer: item["developer"]?.stringValue ?? "",
        platform: platform,
        category: item["category"]?.stringValue ?? "",
        categoryId: "",
        reviewCount: item["reviewCount"]?.intValue ?? item["review_count"]?.intValue
            ?? item["commentCount"]?.intValue ?? item["comment_count"]?.intValue ?? 0,
        lastUpdatedAt: changedRaw.flatMap(parseFlexibleDate) ?? .distantPast,
        // This endpoint has no separate "last activity" field distinct from
        // "last updated" — reusing changedRaw here instead of .distantPast
        // avoids every category-listing row reading "2,026 years ago"
        // (RelativeDateLabel formats .distantPast relative to today).
        lastActivityAt: changedRaw.flatMap(parseFlexibleDate) ?? .distantPast,
        createdAt: .distantPast,
        submittedBy: "",
        submitterUid: "",
        appStoreUrl: item["appStoreUrl"]?.stringValue ?? item["app_store_url"]?.stringValue,
        iconUrl: item["iconUrl"]?.stringValue ?? item["icon_url"]?.stringValue,
        price: item["price"]?.stringValue ?? item["cost"]?.stringValue ?? item["field_cost"]?.stringValue ?? "",
        supportedDevices: [],
        voiceOverPerformance: item["voiceOverPerformance"]?.stringValue ?? item["voice_over_performance"]?.stringValue ?? item["field_voiceover"]?.stringValue,
        summary: HTMLText.plainText(fromHTML: rawSummary),
        url: url.isEmpty ? "" : (url.hasPrefix("http") ? url : "https://www.applevis.com\(url)"),
        isSaved: false
    )
}

// Compiled once instead of per-call — safe to share since only ever read
// from, never mutated after creation.
private let flexibleDateISOWithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
private let flexibleDateISOPlain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func parseFlexibleDate(_ text: String) -> Date? {
    if let ts = Double(text) {
        return Date(timeIntervalSince1970: ts > 10_000_000_000 ? ts / 1000 : ts)
    }
    if let d = flexibleDateISOWithFractional.date(from: text) { return d }
    return flexibleDateISOPlain.date(from: text)
}
