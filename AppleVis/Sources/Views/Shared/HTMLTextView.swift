import SwiftUI

/// Parsed-HTML cache — `NSAttributedString(html:)` is a known-slow,
/// WebKit-backed, main-thread-only API. Without this, scrolling a long
/// reply list out of and back into view (or re-opening the same topic)
/// re-parses identical HTML from scratch every time a row reappears.
/// In-memory only (cleared on relaunch) since re-parsing once per cold
/// launch is cheap relative to the disk I/O a persistent cache would add.
private let parsedHTMLCache = NSCache<NSString, NSAttributedStringWrapper>()

private final class NSAttributedStringWrapper {
    let value: AttributedString
    init(_ value: AttributedString) { self.value = value }
}

// Renders Drupal HTML content as attributed text using NSAttributedString.
struct HTMLTextView: View {
    let html: String
    @State private var attributedString: AttributedString = AttributedString()

    var body: some View {
        Text(attributedString)
            .task(id: html) { attributedString = parse(html) }
    }

    private func parse(_ html: String) -> AttributedString {
        let key = html as NSString
        if let cached = parsedHTMLCache.object(forKey: key) { return cached.value }

        let data = Data(html.utf8)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        let result: AttributedString
        if let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
           let parsed = try? AttributedString(ns, including: \.uiKit) {
            result = parsed
        } else {
            result = AttributedString(html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }
        parsedHTMLCache.setObject(NSAttributedStringWrapper(result), forKey: key, cost: html.utf8.count)
        return result
    }
}

extension String {
    /// Strips HTML tags for contexts that need plain text (e.g. feeding
    /// rich-text content to the on-device summarizer).
    ///
    /// Used to decode only `&nbsp;` and `&amp;`, so every other entity
    /// Drupal emits came through literally — Copy, Share, and Read Aloud of
    /// a comment turned "I've" into "I&#039;ve" (2026-09-23, spotted in a
    /// shared Guideline Violation Check item). Now uses the same full
    /// decoder the network mappers already use.
    nonisolated func strippingHTMLTags() -> String {
        HTMLText.decodeEntities(replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
