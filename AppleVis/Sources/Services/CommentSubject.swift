import Foundation

/// The subject a comment or reply is posted with. Every comment on
/// AppleVis has one, and the website shows it as the comment's title. The
/// app used to send "Reply" or "Comment" for everything, so on the website
/// every post from the app was titled just that. Reported by a beta tester
/// (2026-10-09).
///
/// Checked live against the website's forms (2026-10-09): Subject is
/// required there (up to 64 characters), and a reply's form starts it as
/// "Re: " and the subject being answered, never "Re: Re:". The site stores
/// a blank subject as blank when the app sends one, so in the app, where
/// Subject is optional:
/// - What the person typed in Subject, if anything. A reply's Subject
///   starts filled in like the website's (`replyPrefill`).
/// - Replying to someone's comment: "Re: " and that comment's subject.
/// - Otherwise, the first few words of the comment, cut at a word, with
///   "…", the way Drupal shortens text.
enum CommentSubject {
    /// Drupal's longest comment subject.
    static let maxLength = 64
    /// How much of the comment Drupal uses for a blank subject.
    private static let fromBodyLength = 29

    /// What the Subject field starts with when replying to a comment:
    /// "Re: " and its subject, as the website's reply form fills it in
    /// (checked live, 2026-10-09). Empty when not replying.
    static func replyPrefill(_ parentSubject: String?) -> String {
        guard let parent = parentSubject?.trimmingCharacters(in: .whitespacesAndNewlines), !parent.isEmpty else { return "" }
        return make(typed: "", body: "", replyingTo: parent)
    }

    static func make(typed: String, body: String, replyingTo parentSubject: String? = nil) -> String {
        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return String(typed.prefix(maxLength)) }

        if let parent = parentSubject?.trimmingCharacters(in: .whitespacesAndNewlines), !parent.isEmpty {
            var base = parent
            while base.lowercased().hasPrefix("re:") {
                base = String(base.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            if !base.isEmpty { return String(("Re: " + base).prefix(maxLength)) }
        }

        // The comment's own words, without the quote a reply starts with
        // ("Alex wrote:" and lines beginning ">").
        // Lines first: plainText joins every line into one.
        let ownLines = body
            .components(separatedBy: .newlines)
            .filter {
                let line = $0.trimmingCharacters(in: .whitespaces)
                return !line.hasPrefix(">") && !line.hasPrefix("&gt;") && !line.hasSuffix(" wrote:")
            }
            .joined(separator: " ")
        let words = HTMLText.plainText(fromHTML: ownLines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !words.isEmpty else { return "Comment" }
        guard words.count > fromBodyLength else { return words }
        let cut = words.prefix(fromBodyLength - 1)
        let atWord = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)
        return atWord.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
