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
    func strippingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
