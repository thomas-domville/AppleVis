import SwiftUI

/// One top-level block of HTML content — heading, blockquote, code block,
/// or ordinary prose.
enum HTMLSegmentKind: Equatable {
    case heading(level: Int)
    case quote
    case code
    case prose
}

struct HTMLSegment: Identifiable {
    let id = UUID()
    let kind: HTMLSegmentKind
    let html: String
    let plainText: String

    var isHeading: Bool {
        if case .heading = kind { return true }
        return false
    }
}

/// Splits body HTML into top-level segments instead of treating the whole
/// body as one undifferentiated blob — per docs/IMPLEMENTATION_NOTES.md-style
/// guidance already followed elsewhere in the app (comments render header
/// and body as two separate accessible areas), quotes and code blocks
/// buried inside a single flat Text made Braille navigation unpredictable
/// and gave no way to jump directly to a heading. A best-effort top-level
/// regex scan rather than a full HTML parser — good enough for the
/// well-formed HTML Drupal's rich-text editor actually produces.
enum HTMLSegmenter {
    /// `SegmentedHTMLView.body` previously called `segment(_:)` fresh on
    /// every SwiftUI re-render (it was a computed property, re-invoked
    /// whenever anything in the view re-evaluated, not just when `html`
    /// itself changed) — a full regex scan over potentially thousands of
    /// characters repeated for no reason on every unrelated state change.
    /// Views only ever call this from the main thread, so a plain
    /// dictionary cache (no lock) is safe.
    private static var cache: [String: [HTMLSegment]] = [:]
    /// Insertion order for eviction — keyed by the full HTML string, so a
    /// long session browsing many distinct forum/blog bodies doesn't grow
    /// this unboundedly. Capped well above what a normal session touches;
    /// this is a low-priority safety net, not a response to an observed
    /// memory problem (individual bodies are a few KB at most).
    private static var order: [String] = []
    private static let maxEntries = 200

    static func segment(_ html: String) -> [HTMLSegment] {
        if let cached = cache[html] { return cached }
        let result = computeSegments(html)
        cache[html] = result
        order.append(html)
        if order.count > maxEntries {
            cache.removeValue(forKey: order.removeFirst())
        }
        return result
    }

    private static func computeSegments(_ html: String) -> [HTMLSegment] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?is)<(h[1-6]|blockquote|pre)\b[^>]*>.*?</\1>"#
        ) else {
            return [HTMLSegment(kind: .prose, html: html, plainText: html.strippingHTMLTags())]
        }

        let ns = html as NSString
        var segments: [HTMLSegment] = []
        var cursor = 0
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            if match.range.location > cursor {
                appendProse(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)), to: &segments)
            }
            let tag = ns.substring(with: match.range(at: 1)).lowercased()
            let blockHTML = ns.substring(with: match.range)
            let plain = blockHTML.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty {
                if tag.hasPrefix("h"), let level = Int(tag.dropFirst()) {
                    segments.append(HTMLSegment(kind: .heading(level: level), html: blockHTML, plainText: plain))
                } else if tag == "blockquote" {
                    segments.append(HTMLSegment(kind: .quote, html: blockHTML, plainText: plain))
                } else if tag == "pre" {
                    segments.append(HTMLSegment(kind: .code, html: blockHTML, plainText: plain))
                }
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            appendProse(ns.substring(from: cursor), to: &segments)
        }

        return segments.isEmpty
            ? [HTMLSegment(kind: .prose, html: html, plainText: html.strippingHTMLTags())]
            : segments
    }

    private static func appendProse(_ html: String, to segments: inout [HTMLSegment]) {
        let plain = html.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return }
        segments.append(HTMLSegment(kind: .prose, html: html, plainText: plain))
    }
}

/// Renders HTML as separate per-segment accessible elements (heading/quote/
/// code/prose) instead of one flat block, with two opt-in features:
/// a jump-to-heading table of contents, and collapsing very long bodies
/// behind a "Show Full ..." action — both only appear when there's
/// actually more than one heading / actually hidden content, matching
/// docs/IMPLEMENTATION_NOTES.md's "only render expand controls when there
/// is actually hidden content" guidance.
struct SegmentedHTMLView: View {
    let html: String
    /// When set, collapses to this many segments by default with an expand
    /// button — omit to always show everything.
    var collapsedSegmentLimit: Int? = nil
    var expandLabel = "Show Full Content"
    /// When true, headings before the first shown segment get a
    /// jump-to-heading table of contents above the content.
    var showTableOfContents = false

    @State private var expanded = false

    private var allSegments: [HTMLSegment] { HTMLSegmenter.segment(html) }

    var body: some View {
        let all = allSegments
        let shouldCollapse = !expanded && collapsedSegmentLimit != nil && all.count > collapsedSegmentLimit!
        let visible = shouldCollapse ? Array(all.prefix(collapsedSegmentLimit!)) : all
        let headings = all.filter(\.isHeading)

        VStack(alignment: .leading, spacing: 12) {
            if showTableOfContents && headings.count > 1 {
                TableOfContentsView(headings: headings)
            }
            ForEach(visible) { segment in
                segmentView(segment)
                    .id(segment.id)
            }
            if shouldCollapse {
                Button(expandLabel) { expanded = true }
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func segmentView(_ segment: HTMLSegment) -> some View {
        switch segment.kind {
        case .heading(let level):
            HTMLTextView(html: segment.html)
                .font(level <= 2 ? .title3.weight(.semibold) : .headline)
                .accessibilityAddTraits(.isHeader)
        case .quote:
            // Matches RN's quote styling (amber border + tinted background,
            // topic/[id].tsx) — Swift's was a plain gray border with no
            // background tint, much less visually distinct from prose.
            HTMLTextView(html: segment.html)
                .padding(.leading, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255).opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255)).frame(width: 3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Quoted: \(segment.plainText)"))
        case .code:
            VStack(alignment: .leading, spacing: 4) {
                Text("CODE")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                HTMLTextView(html: segment.html)
                    .font(.system(.footnote, design: .monospaced))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Code: \(segment.plainText)"))
        case .prose:
            HTMLTextView(html: segment.html)
        }
    }
}

/// Table of contents jump list — a real, visible, separately-focusable
/// list of headings above the content (not a hidden custom action), same
/// discoverability lesson learned from "Jump to Last Comment" earlier.
private struct TableOfContentsView: View {
    let headings: [HTMLSegment]
    @State private var expanded = false
    @Namespace private var scrollNamespace

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(headings) { heading in
                    ScrollLinkButton(title: heading.plainText, targetId: heading.id)
                }
            }
            .padding(.top, 6)
        } label: {
            Text("Table of Contents (\(headings.count) sections)")
                .font(.subheadline).fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A tappable heading title that scrolls the nearest enclosing
/// ScrollViewReader to the matching segment — resolved dynamically since
/// SegmentedHTMLView doesn't always have direct access to an ancestor
/// ScrollViewProxy; this reads it from the environment if the parent
/// screen supplies one via `.environment(\.contentScrollProxy, proxy)`.
private struct ScrollLinkButton: View {
    let title: String
    let targetId: UUID
    @Environment(\.contentScrollProxy) private var proxy

    var body: some View {
        Button {
            withReduceMotionAwareAnimation { proxy?.scrollTo(targetId, anchor: .top) }
        } label: {
            HStack {
                Text(title).foregroundStyle(Color.accentColor)
                Spacer()
                Image(systemName: "arrow.down.right")
            }
        }
        .accessibilityHint(String(localized: "Jumps to this section."))
    }
}

private struct ContentScrollProxyKey: EnvironmentKey {
    static let defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    /// Lets a detail screen's outer ScrollViewReader be reachable from
    /// nested content (like SegmentedHTMLView's table of contents) without
    /// threading a proxy parameter through every intermediate view.
    var contentScrollProxy: ScrollViewProxy? {
        get { self[ContentScrollProxyKey.self] }
        set { self[ContentScrollProxyKey.self] = newValue }
    }
}
