import Foundation
import os

// MARK: - Result type

enum APIError: LocalizedError {
    case network(underlying: Error)
    case timeout
    case unauthorized
    case forbidden
    case rateLimited
    case server(statusCode: Int)
    case decoding(underlying: Error)
    /// Also thrown (remapped from .unknown(400)) by single-item detail
    /// fetches — Drupal's JSON:API returns 400, not 404, for a UUID that
    /// doesn't resolve to a resource of the expected bundle, which happens
    /// for content that's been removed, unpublished, or moved since it was
    /// cached in a feed.
    case notFound
    case unknown(statusCode: Int)
    /// The content group's circuit breaker is down (or the live fetch
    /// failed) and there's no cached response to fall back to yet — see
    /// CachedFetch.swift.
    case offlineNoCache(group: String)

    var errorDescription: String? {
        switch self {
        case .network:       return "Network error. Check your connection and try again."
        case .timeout:       return "The request timed out. Try again."
        case .unauthorized:  return "Incorrect username or password."
        case .forbidden:     return "You don't have permission to do that."
        case .rateLimited:   return "Too many requests. Please wait a moment."
        case .server:        return "AppleVis is having trouble right now. Try again later."
        case .decoding: return "AppleVis sent back something this version of the app doesn't understand. Try updating the app."
        case .notFound: return "This item is no longer available. It may have been removed, moved, or is awaiting moderation."
        case .unknown: return "AppleVis sent back something unexpected. Try again in a moment."
        case .offlineNoCache(let group): return "No saved \(group) content yet. Connect to the internet to load content for the first time."
        }
    }
}

extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.network, .network): return true
        case (.timeout, .timeout): return true
        case (.unauthorized, .unauthorized): return true
        case (.forbidden, .forbidden): return true
        case (.rateLimited, .rateLimited): return true
        case (.server(let a), .server(let b)): return a == b
        case (.decoding, .decoding): return true
        case (.notFound, .notFound): return true
        case (.unknown(let a), .unknown(let b)): return a == b
        case (.offlineNoCache(let a), .offlineNoCache(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - HTTP client

final class APIClient {
    static let shared = APIClient()

    /// Set once at launch (see AppleVisApp.swift) so a 401 anywhere can
    /// trigger a local sign-out instead of surfacing a confusing generic
    /// error on whatever unrelated action happened to hit the expired
    /// session first.
    @MainActor static weak var authStore: AuthStore?
    @MainActor static weak var toastStore: ToastStore?

    // Compiled once instead of per-decoded-date-field — these ran through
    // the custom date-decoding strategy below on every timestamp in every
    // network response, and ISO8601DateFormatter construction/configuration
    // is comparatively expensive to repeat that often. Safe to share: only
    // ever read from (`.date(from:)`), never mutated after creation.
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private let session: URLSession
    private let baseURL = URL(string: "https://www.applevis.com")!
    private let jsonAPIBase = URL(string: "https://www.applevis.com/jsonapi")!
    private let v1Base = URL(string: "https://www.applevis.com/api/v1")!
    private let decoder: JSONDecoder
    private let rawDecoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = CloudflareBypass.headers(origin: "https://www.applevis.com")
        session = URLSession(configuration: config)

        func makeDateStrategy() -> (Decoder) throws -> Date {
            { decoder in
                let container = try decoder.singleValueContainer()
                // Try Unix timestamp first (Drupal JSON:API returns these as strings)
                if let str = try? container.decode(String.self), let ts = Double(str) {
                    return Date(timeIntervalSince1970: ts)
                }
                if let ts = try? container.decode(Double.self) {
                    return Date(timeIntervalSince1970: ts)
                }
                // Fall back to ISO8601
                let str = try container.decode(String.self)
                if let date = APIClient.iso8601WithFractional.date(from: str) { return date }
                if let date = APIClient.iso8601Plain.date(from: str) { return date }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(str)")
            }
        }

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(makeDateStrategy())

        // JSON:API attribute/relationship dictionaries are decoded into
        // [String: JSONValue] — their keys are Drupal field names (e.g.
        // "drupal_internal__tid", "field_device_used") and must NOT be
        // snake_case-converted, or every field lookup in Mappers.swift breaks.
        rawDecoder = JSONDecoder()
        rawDecoder.dateDecodingStrategy = .custom(makeDateStrategy())
    }

    // MARK: - Core request methods

    func get<T: Decodable>(_ path: String, base: BaseURL = .v1, query: [String: String] = [:], headers: [String: String] = [:]) async throws -> T {
        let url = buildURL(path: path, base: base, query: query)
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await perform(request: request)
    }

    /// Variant accepting `URLQueryItem`s directly, for endpoints that need
    /// repeated query keys (e.g. Drupal's `apple_only[]=265&apple_only[]=266`),
    /// which a `[String: String]` dictionary can't represent.
    func get<T: Decodable>(_ path: String, base: BaseURL = .v1, queryItems: [URLQueryItem], headers: [String: String] = [:]) async throws -> T {
        let url = buildURL(path: path, base: base, queryItems: queryItems)
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await perform(request: request)
    }

    func post<Body: Encodable, T: Decodable>(
        _ path: String,
        base: BaseURL = .v1,
        query: [String: String] = [:],
        body: Body,
        headers: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> T {
        let url = buildURL(path: path, base: base, query: query)
        var request = URLRequest(url: url, cachePolicy: cachePolicy)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request: request)
    }

    func postForm<T: Decodable>(_ path: String, base: BaseURL = .root, body: [String: String], headers: [String: String] = [:]) async throws -> T {
        let url = buildURL(path: path, base: base, query: [:])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)
        return try await perform(request: request)
    }

    func delete(_ path: String, base: BaseURL = .v1, query: [String: String] = [:], headers: [String: String] = [:]) async throws {
        let url = buildURL(path: path, base: base, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (_, response) = try await session.data(for: request)
        try validateStatus(response)
    }

    // MARK: - JSON:API convenience methods (application/vnd.api+json envelope)

    /// GET a JSON:API collection (list) endpoint, e.g. `/node/forum`.
    func jsonAPIList(_ path: String, query: [String: String] = [:], headers: [String: String] = [:]) async throws -> JsonApiCollectionResponse {
        var request = URLRequest(url: buildURL(path: path, base: .jsonAPI, query: query))
        jsonAPIHeaders(headers).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await performRaw(request: request)
    }

    /// GET a single JSON:API resource endpoint, e.g. `/node/forum/{id}`.
    func jsonAPISingle(_ path: String, query: [String: String] = [:], headers: [String: String] = [:]) async throws -> JsonApiSingleResponse {
        var request = URLRequest(url: buildURL(path: path, base: .jsonAPI, query: query))
        jsonAPIHeaders(headers).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await performRaw(request: request)
    }

    /// POST a JSON:API resource, e.g. creating a comment or node.
    /// `type` is the JSON:API resource type (`"comment--comment_forum"`, `"node--forum"`, ...).
    func jsonAPICreate(
        _ path: String,
        type: String,
        attributes: [String: AnyEncodable] = [:],
        relationships: [String: JsonApiRelationshipRef] = [:],
        headers: [String: String] = [:]
    ) async throws -> JsonApiSingleResponse {
        let body = JsonApiWriteBody(type: type, id: nil, attributes: attributes, relationships: relationships)
        return try await postJsonAPIEnvelope(path, body: body, method: "POST", headers: headers)
    }

    /// PATCH a JSON:API resource.
    func jsonAPIUpdate(
        _ path: String,
        type: String,
        id: String,
        attributes: [String: AnyEncodable] = [:],
        relationships: [String: JsonApiRelationshipRef] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let body = JsonApiWriteBody(type: type, id: id, attributes: attributes, relationships: relationships)
        let _: EmptyJSONAPIResponse = try await postJsonAPIEnvelope(path, body: body, method: "PATCH", headers: headers)
    }

    /// DELETE a JSON:API resource.
    func jsonAPIDelete(_ path: String, headers: [String: String] = [:]) async throws {
        try await delete(path, base: .jsonAPI, headers: jsonAPIHeaders(headers))
    }

    private func jsonAPIHeaders(_ extra: [String: String]) -> [String: String] {
        var headers = ["Accept": "application/vnd.api+json"]
        extra.forEach { headers[$0.key] = $0.value }
        return headers
    }

    private func postJsonAPIEnvelope<T: Decodable>(
        _ path: String,
        body: JsonApiWriteBody,
        method: String,
        headers: [String: String]
    ) async throws -> T {
        let url = buildURL(path: path, base: .jsonAPI, query: [:])
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        jsonAPIHeaders(headers).forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(JsonApiEnvelope(data: body))
        return try await performRaw(request: request)
    }

    // MARK: - Private helpers

    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            try validateStatus(response)
            return try decoder.decode(T.self, from: data)
        } catch let apiError as APIError {
            throw apiError
        } catch let urlError as URLError where urlError.code == .timedOut {
            AppLog.network.error("Request timed out: \(request.url?.path ?? "?", privacy: .public)")
            throw APIError.timeout
        } catch let urlError as URLError {
            AppLog.network.error("Network error on \(request.url?.path ?? "?", privacy: .public): \(urlError, privacy: .private)")
            throw APIError.network(underlying: urlError)
        } catch let decodeError as DecodingError {
            AppLog.network.error("Decode failed for \(request.url?.path ?? "?", privacy: .public): \(decodeError, privacy: .private)")
            throw APIError.decoding(underlying: decodeError)
        }
    }

    /// Same as `perform`, but decodes with `rawDecoder` (no snake_case→camelCase
    /// key conversion) — used for JSON:API responses whose dictionary keys are
    /// Drupal field names that must be looked up verbatim.
    private func performRaw<T: Decodable>(request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            try validateStatus(response)
            if data.isEmpty, let empty = EmptyJSONAPIResponse() as? T {
                return empty
            }
            return try rawDecoder.decode(T.self, from: data)
        } catch let apiError as APIError {
            throw apiError
        } catch let urlError as URLError where urlError.code == .timedOut {
            AppLog.network.error("Request timed out: \(request.url?.path ?? "?", privacy: .public)")
            throw APIError.timeout
        } catch let urlError as URLError {
            AppLog.network.error("Network error on \(request.url?.path ?? "?", privacy: .public): \(urlError, privacy: .private)")
            throw APIError.network(underlying: urlError)
        } catch let decodeError as DecodingError {
            AppLog.network.error("Decode failed for \(request.url?.path ?? "?", privacy: .public): \(decodeError, privacy: .private)")
            throw APIError.decoding(underlying: decodeError)
        }
    }

    private func validateStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401:
            Task { @MainActor in
                guard Self.authStore?.isSignedIn == true else { return }
                Self.authStore?.handleSessionExpired()
                Self.toastStore?.error(String(localized: "Your session expired. Please sign in again."))
            }
            throw APIError.unauthorized
        case 403:
            // A 403 on an otherwise-valid session most often means the
            // user's role changed server-side since we last resolved it
            // (see AuthStore.refreshRoles) — re-sync so a since-demoted
            // editor's Edit/Unpublish/Delete buttons disappear immediately
            // instead of persisting until the next foreground/relaunch.
            Task { @MainActor in
                guard Self.authStore?.isSignedIn == true else { return }
                await Self.authStore?.refreshRoles()
            }
            throw APIError.forbidden
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited
        case 500...599:
            AppLog.network.error("Server error \(http.statusCode) from \(http.url?.path ?? "?", privacy: .public)")
            throw APIError.server(statusCode: http.statusCode)
        default:
            AppLog.network.error("Unexpected status \(http.statusCode) from \(http.url?.path ?? "?", privacy: .public)")
            throw APIError.unknown(statusCode: http.statusCode)
        }
    }

    /// A content UUID sourced from a list/feed endpoint can outlive the
    /// node it pointed to (removed, unpublished, or moved) — Drupal's
    /// JSON:API returns 400, not 404, when a UUID doesn't resolve to a
    /// resource of the expected bundle. Single-item detail fetches wrap
    /// their call in this to surface a friendlier `.notFound` instead of a
    /// raw HTTP code in that specific case.
    func remapping400ToNotFound<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch APIError.unknown(400) {
            throw APIError.notFound
        }
    }

    private func resolvedBase(_ base: BaseURL) -> URL {
        switch base {
        case .root:    return self.baseURL
        case .jsonAPI: return self.jsonAPIBase
        case .v1:      return self.v1Base
        }
    }

    /// A handful of Drupal REST endpoints are conventionally written with
    /// their query string baked directly into the path literal, e.g.
    /// `"user/login?_format=json"` — `post(_:)` had no `query:` parameter to
    /// express this properly until now. That mattered because
    /// `appendingPathComponent` percent-encodes "?" as an ordinary path
    /// character instead of treating it as a query separator: the resulting
    /// request actually went to `/user/login%3F_format=json`, a route that
    /// doesn't exist, so Drupal 404'd and the app surfaced "This item is no
    /// longer available" on sign-in — a content-not-found message with
    /// nothing to do with what was actually wrong. Splitting any embedded
    /// query out of `path` before it reaches `appendingPathComponent` fixes
    /// every call site using this pattern, including `post(_:)` callers that
    /// still write their path this way instead of using its new `query:`
    /// parameter (`logout`, `contact_message` — same bug, previously masked
    /// there because both calls silently discard failures).
    private func splitEmbeddedQuery(from path: String) -> (path: String, query: [String: String]) {
        guard let queryStart = path.firstIndex(of: "?") else { return (path, [:]) }
        let pathOnly = String(path[path.startIndex..<queryStart])
        let queryString = path[path.index(after: queryStart)...]
        var result: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard let key = parts.first, !key.isEmpty else { continue }
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            result[String(key)] = rawValue.removingPercentEncoding ?? rawValue
        }
        return (pathOnly, result)
    }

    private func buildURL(path: String, base: BaseURL, queryItems: [URLQueryItem]) -> URL {
        let (pathOnly, embeddedQuery) = splitEmbeddedQuery(from: path)
        let resolved = resolvedBase(base).appendingPathComponent(pathOnly)
        guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            assertionFailure("Malformed endpoint path: \(path)")
            return resolved
        }
        let mergedItems = embeddedQuery.map { URLQueryItem(name: $0.key, value: $0.value) } + queryItems
        if !mergedItems.isEmpty { components.queryItems = mergedItems }
        return components.url ?? resolved
    }

    private func buildURL(path: String, base: BaseURL, query: [String: String]) -> URL {
        let baseURL: URL = switch base {
        case .root:    self.baseURL
        case .jsonAPI: self.jsonAPIBase
        case .v1:      self.v1Base
        }
        let (pathOnly, embeddedQuery) = splitEmbeddedQuery(from: path)
        let resolved = baseURL.appendingPathComponent(pathOnly)
        guard var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) else {
            assertionFailure("Malformed endpoint path: \(path)")
            return resolved
        }
        let mergedQuery = embeddedQuery.merging(query) { _, new in new }
        if !mergedQuery.isEmpty {
            components.queryItems = mergedQuery.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url ?? resolved
    }

    enum BaseURL { case root, jsonAPI, v1 }
}
