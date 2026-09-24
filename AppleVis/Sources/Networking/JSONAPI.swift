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

    /// The original source text as written — Markdown, plain text, or raw
    /// HTML, whatever format the field actually uses — as opposed to
    /// `richTextValue`, which prefers Drupal's already-rendered `.processed`
    /// HTML. Editing needs this one: pre-filling an edit field with rendered
    /// HTML shows the user literal `<p>`/`<a href>` tags instead of the
    /// source they'd recognize. Display should keep using `richTextValue`.
    var rawTextValue: String? {
        self["value"]?.stringValue
    }

    /// The Drupal text format ID (e.g. "7" for Markdown, "8" for Plain
    /// Text) this field's `value` is actually written in — must be sent
    /// back unchanged on edit, or Drupal reinterprets the same raw text
    /// under a different format and can visibly corrupt it (e.g. Markdown
    /// source resubmitted as Plain Text shows literal "### heading" instead
    /// of rendering it).
    var textFormat: String? {
        self["format"]?.stringValue
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

    /// When the item last had real activity: its newest comment, from the
    /// comment-statistics field Drupal includes on every commentable node
    /// (`comment_node_blog2`, `comment_node_podcast`, …), falling back to
    /// `changed` when there's none. `changed` alone only moves when the post
    /// itself is edited — a blog post with fresh comments today but last
    /// edited six days ago read as "6 days ago" and never counted as new
    /// activity (2026-09-23, beta-tester report). App entries already did
    /// this inline; this is the same rule, shared. Pass `commentField` when
    /// the bundle's field is known; without it, any `comment*` field is used.
    func lastActivityDate(commentField: String? = nil) -> Date {
        let timestamps: [Double]
        if let commentField {
            timestamps = [attributes[commentField]?["last_comment_timestamp"]?.doubleValue].compactMap { $0 }
        } else {
            timestamps = attributes
                .filter { $0.key.hasPrefix("comment") }
                .compactMap { $0.value["last_comment_timestamp"]?.doubleValue }
        }
        guard let latest = timestamps.max(), latest > 0 else { return changedDate }
        return Date(timeIntervalSince1970: latest)
    }

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

// MARK: - Comment/node write requirements (confirmed live 2026-09-15)

/// Drupal text-format machine name for every rich-text field this app
/// writes — comment bodies, node bodies, submission fields, all of it. Was
/// `"basic_html"` until that stopped being a valid format entity on the
/// live site — confirmed live 2026-09-15 via a direct JSON:API test:
/// submitting `"basic_html"` now fails with "The value you selected is not
/// a valid choice," while every real comment and node body already on the
/// site (checked across all 10 comment bundles below, plus a forum topic's
/// own `body` field) stores `"8"` instead. An unusually terse machine name,
/// almost certainly a holdover from a much older Drupal version's numeric
/// format IDs that was never renamed on this install — but it's what every
/// real post on the site uses today, so it's the safe choice here too. This
/// one string is what makes every comment, reply, topic, and submission
/// body postable again; investigated while building forum reply-to-comment
/// support, but the breakage is universal, not forum-specific.
nonisolated let drupalDefaultTextFormat = "8"

/// Every comment bundle this app posts to, and the two extra things each
/// one's create request needs beyond the obvious `entity_id` relationship —
/// both confirmed live 2026-09-15 against the real site with a disposable
/// test account, same investigate-then-fix approach as `FlagEndpoints`'s
/// `entity_type`/`entity_id` requirement:
///
/// 1. The `comment_type` relationship's `id` must be this bundle's own
///    JSON:API **UUID**, not its machine name — every comment-posting call
///    site previously sent the machine name (e.g. `"comment_forum"`), which
///    404s with "The resource identified by ... could not be found." A
///    comment's own `relationships.comment_type.data.id` on read confirms
///    the real UUID; `comment_type` config entities aren't independently
///    listable without an admin permission this app's users don't have,
///    which is why these are hardcoded below rather than resolved at
///    request time — config entity UUIDs are fixed at creation and don't
///    change, so this is stable, not fragile.
/// 2. Two base-field attributes — `entity_type` (always `"node"` here) and
///    `field_name` (this bundle's own machine name) — must be sent
///    explicitly. Neither is inferable from `entity_id` alone; omitting
///    them fails with "This value should not be null."
enum CommentBundle: String {
    case forumTopic = "comment_forum"
    case guide = "comment_node_guides"
    case blogPost = "comment_node_blog2"
    case podcastEpisode = "comment_node_podcast"
    case iosApp = "comment_node_ios_app_directory"
    case macApp = "comment_node_mac_app_directory"
    case tvApp = "comment_node_tv_directory"
    case watchApp = "comment_node_watch_directory"
    case iosBugReport = "comment_node_ios_bug_report"
    case macBugReport = "comment_node_os_x_bug_report"

    var typeUuid: String {
        switch self {
        case .forumTopic:     return "e793db3b-8546-46b6-a0c8-6b7107c75a1a"
        case .guide:          return "96bfd690-7a09-43de-af67-b2fbb7b94026"
        case .blogPost:       return "8180a642-cf03-4189-98d2-61e1a6d94d2b"
        case .podcastEpisode: return "13036c94-8c55-4d91-ad78-928fdeeb3287"
        case .iosApp:         return "ee475b17-740d-4521-b17f-07ca26fd1ee8"
        case .macApp:         return "f2c92808-71e3-49dc-b703-04a377b5d720"
        case .tvApp:          return "83641144-7f81-41e0-871f-f9316a6622c4"
        case .watchApp:       return "8bf4d51d-0397-4813-8da7-6783cdbdd728"
        case .iosBugReport:   return "19d2c82b-8ade-4f26-9f30-621883761ca4"
        case .macBugReport:   return "b36f6a2c-dc72-4d02-b43c-cfcec8b50731"
        }
    }

    /// Standard JSON:API write attributes/relationships every comment on
    /// this bundle needs regardless of its own text/subject — merge with
    /// whatever's bundle-specific (subject, comment_body, entity_id, pid).
    var baseAttributes: [String: AnyEncodable] {
        ["entity_type": AnyEncodable("node"), "field_name": AnyEncodable(rawValue)]
    }

    var commentTypeRelationship: JsonApiRelationshipRef {
        JsonApiRelationshipRef(type: "comment_type--comment_type", id: typeUuid)
    }
}

struct EmptyJSONAPIResponse: Decodable {}

// MARK: - Text helpers (mirror src/services/api.ts textFromHtml/decodeHtml)

enum HTMLText {
    // Compiled once instead of per-call — these run on every forum post/bug
    // report/app listing mapped from a network response, and NSRegularExpression
    // compilation is comparatively expensive to repeat per item.
    // nonisolated: needed so `decodeEntities` below can be nonisolated for
    // `String.strippingHTMLTags()`. No `(unsafe)` needed — NSRegularExpression
    // is Sendable.
    nonisolated private static let numericEntityRegex = try? NSRegularExpression(pattern: "&#([0-9]+);")
    private static let scriptTagRegex = try? NSRegularExpression(pattern: "<script[\\s\\S]*?</script>")
    private static let styleTagRegex = try? NSRegularExpression(pattern: "<style[\\s\\S]*?</style>")
    private static let anyTagRegex = try? NSRegularExpression(pattern: "<[^>]+>")
    private static let whitespaceRunRegex = try? NSRegularExpression(pattern: "\\s+")

    private static func replace(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
        guard let regex else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    nonisolated static func decodeEntities(_ text: String) -> String {
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

    /// For deciding whether two pieces of text say the same thing — the
    /// App Directory Health Check and Refresh App Details both use this, so
    /// they can't disagree. `plainText`, minus invisible formatting
    /// characters (the App Store's web page leaves a left-to-right mark,
    /// U+200E, on titles copied from it — confirmed live on several
    /// entries, flagged as a "title change" with nothing visible to fix),
    /// with every kind of space collapsed to one. Case still counts: a
    /// capitalization change is a real, visible difference.
    static func comparableText(_ text: String) -> String {
        let visible = plainText(fromHTML: text).unicodeScalars.filter { $0.properties.generalCategory != .format }
        return String(String.UnicodeScalarView(visible))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
