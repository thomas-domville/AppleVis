import Foundation

// MARK: - JSONValue

/// A minimal dynamic JSON value, used to read Drupal JSON:API `attributes` /
/// `relationships` payloads whose shape varies per content type (mirrors how
/// the RN client treats `node.attributes` as a loosely-typed object).
nonisolated enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var intValue: Int? {
        if let d = doubleValue { return Int(d) }
        return nil
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        default: return nil
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    /// Drupal text fields are typically `{ value, format }` or `{ value, summary, format }`.
    /// Returns `.processed` — Drupal's own server-side rendering of `.value`
    /// through whichever text format was actually chosen when the content
    /// was written — falling back to `.value` only if `.processed` is
    /// missing (a sparse fieldset response that didn't request it).
    /// Previously preferred `.value` first, which is only safe to treat as
    /// HTML when the source format actually is HTML. Confirmed against a
    /// live episode: recent AppleVis Extra podcast bodies use a Markdown
    /// text format (`format: 7`) — `.value` is literal Markdown ("###
    /// Transcript", "* [link](url)"), which every `<h1-6>`/`<blockquote>`/
    /// `<pre>`/`<table>` regex scan in the app (HTMLSegmenter's transcript-
    /// heading detection among them) silently found nothing in, since none
    /// of those are real HTML tags — `.processed` correctly renders the
    /// same content as `<h3>Transcript</h3>`, etc. This is why recent
    /// episodes' Transcript button never appeared and the raw "###
    /// Transcript" text stayed inline in the show notes instead of being
    /// extracted. Reported directly.
    var richTextValue: String? {
        (self["processed"]?.stringValue) ?? (self["value"]?.stringValue)
    }

    var richTextSummary: String? {
        self["summary"]?.stringValue
    }

    /// Drupal `path` field: `{ alias, pid, langcode }`.
    var pathAlias: String? {
        self["alias"]?.stringValue
    }
}

// Compiled once instead of per-call in `parseDrupalDate` below, which runs
// on every date field of every mapped node. Safe to share across calls:
// only ever read from (`.date(from:)`), never mutated after creation.
nonisolated(unsafe) private let drupalDateISOWithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
nonisolated(unsafe) private let drupalDateISOPlain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

// MARK: - JSON:API node

nonisolated struct JsonApiNode: Decodable, Sendable {
    let id: String
    let type: String
    let attributes: [String: JSONValue]
    let relationships: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case id, type, attributes, relationships
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        attributes = try container.decodeIfPresent([String: JSONValue].self, forKey: .attributes) ?? [:]
        relationships = try container.decodeIfPresent([String: JSONValue].self, forKey: .relationships) ?? [:]
    }

    /// Reads a to-one relationship's target id, e.g. `relationships["uid"]`.
    func relationshipId(_ name: String) -> String? {
        relationships[name]?["data"]?["id"]?.stringValue
    }

    /// Reads a to-many relationship's target ids, e.g. `relationships["taxonomy_forums"]`.
    func relationshipIds(_ name: String) -> [String] {
        (relationships[name]?["data"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }
    }

    var createdDate: Date { JsonApiNode.parseDrupalDate(attributes["created"]) }
    var changedDate: Date { JsonApiNode.parseDrupalDate(attributes["changed"]) }

    /// Drupal timestamps arrive as Unix-epoch strings/numbers, or occasionally ISO8601.
    /// Falls back to `.distantPast` rather than throwing, since live content is
    /// frequently missing or malformed on individual fields.
    static func parseDrupalDate(_ value: JSONValue?) -> Date {
        guard let value else { return .distantPast }
        if let n = value.doubleValue {
            // Distinguish seconds vs milliseconds epoch.
            return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
        }
        if let s = value.stringValue {
            if let ts = Double(s) {
                return Date(timeIntervalSince1970: ts > 10_000_000_000 ? ts / 1000 : ts)
            }
            if let d = drupalDateISOWithFractional.date(from: s) { return d }
            if let d = drupalDateISOPlain.date(from: s) { return d }
        }
        return .distantPast
    }
}

// MARK: - Response envelopes

nonisolated struct JsonApiCollectionResponse: Decodable, Sendable {
    let data: [JsonApiNode]
    let included: [JsonApiNode]?
    let links: JSONValue?

    var hasNextPage: Bool { links?["next"] != nil }
}

/// ARCH-10: browse-list endpoints previously discarded this response's own
/// `hasNextPage` (the standard JSON:API `links.next`, provided automatically
/// by Drupal's JSON:API module) and left callers to guess "is there more"
/// from a client-side "did this page come back full" heuristic — wrong
/// whenever a page happens to land exactly full but no more data actually
/// exists. `fetchWithCache` requires a `Codable` return type (for its own
/// disk cache), so this wraps the true server signal in a small reusable
/// shape rather than each endpoint duplicating its own page-result struct.
nonisolated struct PagedListResult<Item: Codable & Sendable>: Codable, Sendable {
    let items: [Item]
    let hasMore: Bool
}

nonisolated struct JsonApiSingleResponse: Decodable, Sendable {
    let data: JsonApiNode
    let included: [JsonApiNode]?
}

// MARK: - JSON:API write support (POST/PATCH bodies)

/// Type-erased Encodable value, since Swift can't synthesize `Encodable`
/// conformance for a dictionary of existential `any Encodable` values.
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

/// A single JSON:API "to-one" relationship reference, e.g.
/// `relationships: { entity_id: { data: { type: "node--forum", id: "..." } } }`.
struct JsonApiRelationshipRef: Encodable {
    let type: String
    let id: String

    private struct DataRef: Encodable { let type: String; let id: String }
    private enum CodingKeys: String, CodingKey { case data }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(DataRef(type: type, id: id), forKey: .data)
    }
}

struct JsonApiWriteBody: Encodable {
    let type: String
    let id: String?
    let attributes: [String: AnyEncodable]
    let relationships: [String: JsonApiRelationshipRef]

    private enum CodingKeys: String, CodingKey { case type, id, attributes, relationships }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(id, forKey: .id)
        if !attributes.isEmpty { try container.encode(attributes, forKey: .attributes) }
        if !relationships.isEmpty { try container.encode(relationships, forKey: .relationships) }
    }
}

struct JsonApiEnvelope: Encodable {
    let data: JsonApiWriteBody
}

struct EmptyJSONAPIResponse: Decodable {}

// MARK: - Text helpers (mirror src/services/api.ts textFromHtml/decodeHtml)

enum HTMLText {
    // Compiled once instead of per-call — these run on every forum post/bug
    // report/app listing mapped from a network response, and NSRegularExpression
    // compilation is comparatively expensive to repeat per item.
    private static let numericEntityRegex = try? NSRegularExpression(pattern: "&#([0-9]+);")
    private static let scriptTagRegex = try? NSRegularExpression(pattern: "<script[\\s\\S]*?</script>")
    private static let styleTagRegex = try? NSRegularExpression(pattern: "<style[\\s\\S]*?</style>")
    private static let anyTagRegex = try? NSRegularExpression(pattern: "<[^>]+>")
    private static let whitespaceRunRegex = try? NSRegularExpression(pattern: "\\s+")

    private static func replace(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
        guard let regex else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    static func decodeEntities(_ text: String) -> String {
        var result = text
        // Drupal's WYSIWYG editor commonly emits named/numeric entities for
        // smart quotes, dashes, and ellipses — previously only the 7 basic
        // entities below were handled, so content using these showed up as
        // literal "&rsquo;"/"&#8217;" text in previews and Spotlight/
        // notification snippets instead of an apostrophe.
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""),
            ("&#039;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"),
            ("&rsquo;", "\u{2019}"), ("&lsquo;", "\u{2018}"),
            ("&rdquo;", "\u{201D}"), ("&ldquo;", "\u{201C}"),
            ("&mdash;", "\u{2014}"), ("&ndash;", "\u{2013}"),
            ("&hellip;", "\u{2026}"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Catch-all for any remaining decimal numeric entity (&#8217; etc.)
        // not already covered by name above, rather than enumerating every
        // possible code point.
        if let regex = numericEntityRegex {
            let ns = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                let codeRange = match.range(at: 1)
                guard let code = Int(ns.substring(with: codeRange)), let scalar = Unicode.Scalar(code) else { continue }
                result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
            }
        }
        return result
    }

    static func plainText(fromHTML html: String) -> String {
        var text = html
        text = replace(scriptTagRegex, in: text, with: " ")
        text = replace(styleTagRegex, in: text, with: " ")
        text = replace(anyTagRegex, in: text, with: " ")
        text = replace(whitespaceRunRegex, in: text, with: " ")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return decodeEntities(text)
    }
}
