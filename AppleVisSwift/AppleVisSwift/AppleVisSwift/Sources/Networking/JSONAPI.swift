import Foundation

// MARK: - JSONValue

/// A minimal dynamic JSON value, used to read Drupal JSON:API `attributes` /
/// `relationships` payloads whose shape varies per content type (mirrors how
/// the RN client treats `node.attributes` as a loosely-typed object).
enum JSONValue: Decodable {
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
    /// Returns `.value`, falling back to `.processed` (some REST responses use that key instead).
    var richTextValue: String? {
        (self["value"]?.stringValue) ?? (self["processed"]?.stringValue)
    }

    var richTextSummary: String? {
        self["summary"]?.stringValue
    }

    /// Drupal `path` field: `{ alias, pid, langcode }`.
    var pathAlias: String? {
        self["alias"]?.stringValue
    }
}

// MARK: - JSON:API node

struct JsonApiNode: Decodable {
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
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: s) { return d }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: s) { return d }
        }
        return .distantPast
    }
}

// MARK: - Response envelopes

struct JsonApiCollectionResponse: Decodable {
    let data: [JsonApiNode]
    let included: [JsonApiNode]?
    let links: JSONValue?

    var hasNextPage: Bool { links?["next"] != nil }
}

struct JsonApiSingleResponse: Decodable {
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
    static func decodeEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""),
            ("&#039;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    static func plainText(fromHTML html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return decodeEntities(text)
    }
}
