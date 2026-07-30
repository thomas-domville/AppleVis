import SwiftUI

// Renders Drupal HTML content as attributed text using NSAttributedString.
struct HTMLTextView: View {
    let html: String
    @State private var attributedString: AttributedString = AttributedString()

    var body: some View {
        Text(attributedString)
            .task(id: html) { attributedString = parse(html) }
    }

    private func parse(_ html: String) -> AttributedString {
        let data = Data(html.utf8)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
              let result = try? AttributedString(ns, including: \.uiKit) else {
            return AttributedString(html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }
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
}
