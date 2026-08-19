import Foundation

extension APIClient {
    var apps: AppEndpoints { AppEndpoints(client: self) }
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
    func categories(platform: AppPlatform) async throws -> [AppCategory] {
        let raw: [JSONValue] = try await client.get("apps/\(platform.rawValue)/categories")
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
    func list(page: Int = 0, platform: AppPlatform? = nil, categoryTid: Int? = nil) async throws -> PagedListResult<AppListing> {
        if let platform, let categoryTid {
            let result = try await categoryListing(platform: platform.rawValue, categoryId: "\(categoryTid)", page: page)
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

    private struct CategoryListingPage: Codable {
        let items: [AppListing]
        let hasMore: Bool
    }

    func categoryListing(platform: String, categoryId: String, page: Int, limit: Int = 20) async throws -> (items: [AppListing], hasMore: Bool) {
        let result = try await fetchWithCache(group: .apps, key: "apps:category:\(platform):\(categoryId):\(page)") {
            let raw: JSONValue = try await client.get(
                "apps/\(platform)/categories/\(categoryId)",
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
            return CategoryListingPage(items: rawItems.map { mapDirectoryListing($0) }, hasMore: hasMore)
        }
        return (result.items, result.hasMore)
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
        return response.data.map { Mappers.app($0, included: response.included ?? []) }
    }

    /// Title-contains lookup against the existing directory, run before a new
    /// submission — legacy's `submit-wizard/confirm.tsx` `checkForDuplicate()`
    /// had no native equivalent anywhere (SUBMIT-004): a submitter had no way
    /// to know they were about to duplicate an existing entry.
    func checkForDuplicate(appName: String) async throws -> [AppListing] {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response = try await client.jsonAPIList(
            "node/ios_app_directory",
            query: ["include": "uid", "filter[title][operator]": "CONTAINS", "filter[title][value]": trimmed, "page[limit]": "5"]
        )
        return response.data.map { Mappers.app($0, included: response.included ?? []) }
    }

    /// Fetches an app listing with full body text and all reviews.
    /// Review bundle confirmed: comment_node_ios_app_directory.
    func detail(id: String) async throws -> AppDetail {
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

            let reviews: [AppReview]
            if let reviewsResponse = try? await reviewsRes {
                reviews = reviewsResponse.data.map { Mappers.appReview($0, included: reviewsResponse.included ?? []) }
            } else {
                reviews = []
            }

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

    /// Fetches the next page of reviews beyond the initial 100 (used by
    /// "Load more reviews") — previously reviews had no pagination at all,
    /// the same bug class already fixed for Forums/Blogs/Guides/Podcasts:
    /// an app with more than 100 reviews permanently hid the rest.
    func moreReviews(appId: String, offset: Int) async throws -> [AppReview] {
        let response = try await client.jsonAPIList(
            "comment/comment_node_ios_app_directory",
            query: ["filter[entity_id.id]": appId, "sort": "-created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { Mappers.appReview($0, included: response.included ?? []) }
    }

    @discardableResult
    func submitReview(appId: String, subject: String = "Review", body: String, csrfToken: String) async throws -> AppReview {
        let response = try await client.jsonAPICreate(
            "comment/comment_node_ios_app_directory",
            type: "comment--comment_node_ios_app_directory",
            attributes: [
                "subject": AnyEncodable(subject.isEmpty ? "Review" : subject),
                "comment_body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--ios_app_directory", id: appId),
                "comment_type": JsonApiRelationshipRef(type: "comment_type--comment_type", id: "comment_node_ios_app_directory"),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        return Mappers.appReview(response.data, included: response.included ?? [])
    }

    /// Submit a new app entry. Category UUIDs are fixed vocabulary_1 term IDs
    /// (ported from the RN reference client's confirmed live mapping).
    func submitApp(payload: SubmitAppPayload, csrfToken: String) async throws -> (nid: Int, nodeUrl: String) {
        var attributes: [String: AnyEncodable] = [
            "title": AnyEncodable(payload.appName),
            "status": AnyEncodable(true),
            "field_link2": AnyEncodable(LinkValue(uri: payload.appStoreUrl, title: "")),
            "field_version": AnyEncodable(payload.appVersion),
            "field_cost": AnyEncodable(payload.price),
            "field_device_used": AnyEncodable(payload.supportedDevices.joined(separator: ", ")),
            "field_ios_version": AnyEncodable(payload.osVersion),
            "field_voiceover": AnyEncodable(payload.voiceOverPerformance),
            "field_labelling": AnyEncodable(payload.buttonLabelling),
            "field_usability": AnyEncodable(payload.usabilityNotes),
            "field_comments": AnyEncodable(RichTextValue(value: payload.accessibilityComments, format: "basic_html")),
        ]
        if !payload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            attributes["field_other_comments"] = AnyEncodable(RichTextValue(value: payload.otherComments, format: "basic_html"))
        }
        if !payload.appStoreDescription.isEmpty || !payload.shortSummary.isEmpty {
            attributes["body"] = AnyEncodable(RichTextBodyValue(value: payload.appStoreDescription, summary: payload.shortSummary, format: "basic_html"))
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
    var appStoreDescription = ""
    var category = ""
    var osVersion = ""
    var voiceOverPerformance = ""
    var buttonLabelling = ""
    var usabilityNotes = ""
    var accessibilityComments = ""
    var otherComments = ""
    var shortSummary = ""
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
private func mapDirectoryListing(_ item: JSONValue) -> AppListing {
    let id = item["id"]?.stringValue ?? item["uuid"]?.stringValue ?? item["nid"]?.stringValue ?? UUID().uuidString
    let name = item["name"]?.stringValue ?? item["title"]?.stringValue ?? ""
    let rawSummary = item["summary"]?.stringValue ?? item["body"]?.stringValue ?? ""
    let url = item["url"]?.stringValue ?? item["path"]?.stringValue ?? ""
    let changedRaw = item["lastUpdatedAt"]?.stringValue ?? item["last_updated_at"]?.stringValue
        ?? item["changed"]?.stringValue ?? item["updated"]?.stringValue
    return AppListing(
        id: id,
        name: name,
        developer: item["developer"]?.stringValue ?? "",
        platform: .ios,
        category: item["category"]?.stringValue ?? "",
        categoryId: "",
        reviewCount: item["reviewCount"]?.intValue ?? item["review_count"]?.intValue
            ?? item["commentCount"]?.intValue ?? item["comment_count"]?.intValue ?? 0,
        lastUpdatedAt: changedRaw.flatMap(parseFlexibleDate) ?? .distantPast,
        lastActivityAt: .distantPast,
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
