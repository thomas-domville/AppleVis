import Foundation

/// Display-time language filter, gated by `PreferencesStore.filterProfanity`.
/// Separate from `ContentSubmissionPolicy.containsStrongVulgarLanguage`,
/// which only prevents *this app* from being the source of strong language —
/// it does nothing about content already on the site, or posted via the
/// website or another client, which reaches this app through the API
/// untouched. This filter masks the same strong words plus a wider "mild"
/// tier the site allows, so turning it on is a real backstop, not just a
/// convenience for the milder words. Masking is visual only — what a comment
/// or post actually contains is never altered, and posting is governed
/// entirely separately by `ContentSubmissionPolicy`, regardless of this
/// setting.
enum ProfanityFilter {
    /// Same 5 patterns `ContentSubmissionPolicy.containsStrongVulgarLanguage`
    /// hard-blocks at posting time, plus a wider "mild" tier the site
    /// otherwise allows through unfiltered. Deliberately not exhaustive —
    /// a starting list, easy to extend.
    private static let patterns: [String] = [
        #"\bf+[\W_]*u+[\W_]*c+[\W_]*k+(er|ing|ed|s)?\b"#,
        #"\bc+[\W_]*u+[\W_]*n+[\W_]*t+s?\b"#,
        #"\bm+[\W_]*o+[\W_]*t+[\W_]*h+[\W_]*e+[\W_]*r+[\W_]*f+[\W_]*u+[\W_]*c+[\W_]*k+(er|ing|ed|s)?\b"#,
        #"\bc+[\W_]*o+[\W_]*c+[\W_]*k+[\W_]*s+[\W_]*u+[\W_]*c+[\W_]*k+(er|ing|ed)?\b"#,
        #"\bc+[\W_]*u+[\W_]*m+[\W_]*s+[\W_]*h+[\W_]*o+[\W_]*t+s?\b"#,
        #"\bshit(s|ty|ting)?\b"#,
        #"\bass(es|hole|holes)?\b"#,
        #"\bbitch(es|y|ing)?\b"#,
        #"\bbastard(s)?\b"#,
        #"\bdamn(ed|it)?\b"#,
        #"\bcrap(py)?\b"#,
        #"\bdick(s|head|heads)?\b"#,
        #"\bpiss(ed|ing|y)?\b"#,
        #"\bprick(s)?\b"#,
        #"\bdouche(bag|bags)?\b"#,
        #"\btwat(s)?\b"#,
        #"\bslut(s|ty)?\b"#,
        #"\bwhore(s)?\b"#,
        #"\bbollocks\b"#,
        #"\bbugger(ed|ing)?\b"#,
        #"\bwanker(s)?\b"#,
    ]

    private static let combinedRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: patterns.joined(separator: "|"), options: [.caseInsensitive])
    }()

    static func containsProfanity(_ text: String) -> Bool {
        guard let combinedRegex else { return false }
        let ns = text as NSString
        return combinedRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
    }

    /// Masks matched words to e.g. "s***" (first letter kept, rest replaced
    /// with asterisks matching the original length) — visually recognizable
    /// as "something was filtered here" without spelling out the word. Only
    /// operates on text outside HTML tags, so a match can never land inside
    /// an attribute or tag name.
    static func maskForDisplay(html: String) -> String {
        guard let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#) else { return html }
        let ns = html as NSString
        let tagMatches = tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var result = ""
        var cursor = 0
        for tagMatch in tagMatches {
            if tagMatch.range.location > cursor {
                let run = ns.substring(with: NSRange(location: cursor, length: tagMatch.range.location - cursor))
                result += maskWords(in: run) { asteriskMask($0) }
            }
            result += ns.substring(with: tagMatch.range)
            cursor = tagMatch.range.location + tagMatch.range.length
        }
        if cursor < ns.length {
            result += maskWords(in: ns.substring(from: cursor)) { asteriskMask($0) }
        }
        return result
    }

    /// Masks matched words the same way visually ("s***") and audibly —
    /// spoken as the kept letter followed by "star" once per asterisk, e.g.
    /// "s star star star." Built explicitly with the localized word "star"
    /// rather than left to VoiceOver's own reading of literal "*"
    /// characters, since that depends on the user's punctuation verbosity
    /// setting and isn't guaranteed to say anything at all. Operates on
    /// plain text (no HTML tags to account for), since it's only ever used
    /// to build an accessibility label, never rendered visually.
    static func accessiblePlaceholder(for plainText: String) -> String {
        maskWords(in: plainText) { spokenMask($0) }
    }

    private static func asteriskMask(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first) + String(repeating: "*", count: max(word.count - 1, 1))
    }

    private static func spokenMask(_ word: String) -> String {
        guard let first = word.first else { return word }
        let star = String(localized: "star")
        let stars = Array(repeating: star, count: max(word.count - 1, 1)).joined(separator: " ")
        return "\(first) \(stars)"
    }

    private static func maskWords(in text: String, transform: (String) -> String) -> String {
        guard let combinedRegex else { return text }
        let ns = text as NSString
        let matches = combinedRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var result = ""
        var cursor = 0
        for match in matches {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += transform(ns.substring(with: match.range))
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
