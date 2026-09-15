import SwiftUI

/// One top-level block of HTML content — heading, blockquote, code block,
/// table, or ordinary prose.
enum HTMLSegmentKind: Equatable {
    case heading(level: Int)
    case quote
    case code
    case prose
    /// `rows[0]` is the header row's cell text when `hasHeaderRow` is true.
    case table(rows: [[String]], hasHeaderRow: Bool)
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
nonisolated enum HTMLSegmenter {
    /// `SegmentedHTMLView.body` previously called `segment(_:)` fresh on
    /// every SwiftUI re-render (it was a computed property, re-invoked
    /// whenever anything in the view re-evaluated, not just when `html`
    /// itself changed) — a full regex scan over potentially thousands of
    /// characters repeated for no reason on every unrelated state change.
    /// Guarded by `lock` rather than assumed main-thread-only: that
    /// assumption held for every in-app caller but not for the test suite,
    /// where Swift Testing's default parallel execution mutated this
    /// concurrently from multiple threads and corrupted the dictionary
    /// (surfaced as a `doesNotRecognizeSelector` crash inside
    /// `Dictionary.subscript.setter`).
    private static var cache: [String: [HTMLSegment]] = [:]
    /// Insertion order for eviction — keyed by the full HTML string, so a
    /// long session browsing many distinct forum/blog bodies doesn't grow
    /// this unboundedly. Capped well above what a normal session touches;
    /// this is a low-priority safety net, not a response to an observed
    /// memory problem (individual bodies are a few KB at most).
    private static var order: [String] = []
    private static let maxEntries = 200
    private static let lock = NSLock()

    static func segment(_ html: String) -> [HTMLSegment] {
        lock.lock()
        defer { lock.unlock() }
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
        // `table` added to the existing top-level block scan (GUIDES-02) —
        // previously tables fell into the generic .prose case and were
        // flattened by the HTML importer into unstructured text, with no
        // VoiceOver row/column semantics and no Braille cell boundaries.
        // Comparison tables are common in accessibility how-to guides
        // ("which gesture does what") — a sighted user can still visually
        // parse a mis-rendered table's grid; a VoiceOver/Braille user gets
        // no equivalent fallback once the structure is gone.
        guard let regex = try? NSRegularExpression(
            pattern: #"(?is)<(h[1-6]|blockquote|pre|table)\b[^>]*>.*?</\1>"#
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
            if tag == "table" {
                let (rows, hasHeaderRow) = parseTableRows(blockHTML)
                if !rows.isEmpty {
                    let plain = rows.map { $0.joined(separator: ", ") }.joined(separator: "; ")
                    segments.append(HTMLSegment(kind: .table(rows: rows, hasHeaderRow: hasHeaderRow), html: blockHTML, plainText: plain))
                }
                cursor = match.range.location + match.range.length
                continue
            }
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

    /// Best-effort `<tr>`/`<th>`/`<td>` extraction — good enough for the
    /// well-formed HTML Drupal's rich-text table editor actually produces,
    /// matching this file's existing regex-scan philosophy rather than a
    /// full HTML parser. A row is only kept if it has at least one cell;
    /// the header row is detected as a first row whose cells are all `<th>`.
    private static func parseTableRows(_ tableHTML: String) -> (rows: [[String]], hasHeaderRow: Bool) {
        guard let rowRegex = try? NSRegularExpression(pattern: #"(?is)<tr\b[^>]*>(.*?)</tr>"#),
              let cellRegex = try? NSRegularExpression(pattern: #"(?is)<(th|td)\b[^>]*>(.*?)</\1>"#)
        else { return ([], false) }

        let ns = tableHTML as NSString
        let rowMatches = rowRegex.matches(in: tableHTML, range: NSRange(location: 0, length: ns.length))

        var rows: [[String]] = []
        var hasHeaderRow = false
        for rowMatch in rowMatches {
            let rowContent = ns.substring(with: rowMatch.range(at: 1))
            let rowNs = rowContent as NSString
            let cellMatches = cellRegex.matches(in: rowContent, range: NSRange(location: 0, length: rowNs.length))
            guard !cellMatches.isEmpty else { continue }

            var cells: [String] = []
            var allHeaderCells = true
            for cellMatch in cellMatches {
                let cellTag = rowNs.substring(with: cellMatch.range(at: 1)).lowercased()
                if cellTag != "th" { allHeaderCells = false }
                let cellHTML = rowNs.substring(with: cellMatch.range(at: 2))
                cells.append(cellHTML.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if rows.isEmpty { hasHeaderRow = allHeaderCells }
            rows.append(cells)
        }
        return (rows, hasHeaderRow)
    }

    /// One prose segment per paragraph instead of one flattened block for
    /// however many paragraphs sat between the surrounding headings/quotes/
    /// code/tables (or the whole body, for the common case of a post with no
    /// heading structure at all) — matches the same reasoning
    /// `AuthorProfileButton`'s bio splitting already applies: a long
    /// multi-paragraph block flattened into a single accessibility element
    /// reads (or Braille-pans) as one undifferentiated stream, with no way
    /// to stop, re-read, or skip to a specific paragraph. Requested
    /// directly.
    private static func appendProse(_ html: String, to segments: inout [HTMLSegment]) {
        for paragraphHTML in splitIntoParagraphs(html) {
            let plain = paragraphHTML.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { continue }
            segments.append(HTMLSegment(kind: .prose, html: paragraphHTML, plainText: plain))
        }
    }

    /// Splits a prose chunk into individual paragraphs, same tiered fallback
    /// TranscriptView already uses for a structureless plain-text
    /// transcript, adapted for HTML: `<p>` tags first (Drupal's rich-text
    /// editor's normal output), then runs of 2+ `<br>` tags (the next most
    /// common paragraph-separation convention in older/pasted content that
    /// skipped `<p>` wrapping), then single `<br>` tags (a speaker-turn-per-
    /// line convention, matching TranscriptView's own line-based tier).
    /// Content with none of those falls back to `TextSegmentation`'s
    /// sentence-grouping — but ONLY when the chunk has no HTML markup at
    /// all (Drupal occasionally leaves a stray blob of plain text
    /// unwrapped): re-grouping by stripped-text sentence boundaries would
    /// silently drop any inline markup (links, bold, etc.) a chunk that
    /// still contains tags actually has, so that case stays a single piece
    /// instead — the same graceful degradation already accepted for a body
    /// with no heading structure at all.
    private static func splitIntoParagraphs(_ html: String) -> [String] {
        if let pieces = splitOnMatches(of: #"(?is)<p\b[^>]*>.*?</p>"#, in: html, keepMatchedText: true) { return pieces }
        if let pieces = splitOnMatches(of: #"(?is)(?:<br\s*/?>\s*){2,}"#, in: html) { return pieces }
        if let pieces = splitOnMatches(of: #"(?is)<br\s*/?>"#, in: html) { return pieces }
        if !html.contains("<") {
            let groups = TextSegmentation.sentenceGroups(html)
            if groups.count > 1 { return groups }
        }
        return [html]
    }

    /// Two different splitting jobs above this line: `<p>` tags become the
    /// pieces *between and including* each match; `<br>` tags are pure
    /// separators, discarded, keeping only the text *between* matches. Both
    /// share this helper's match-finding; each caller decides which via
    /// `keepMatchedText`.
    private static func splitOnMatches(of pattern: String, in html: String, keepMatchedText: Bool = false) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }
        if keepMatchedText {
            return matches.map { ns.substring(with: $0.range) }
        }
        var pieces: [String] = []
        var cursor = 0
        for match in matches {
            pieces.append(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
        }
        pieces.append(ns.substring(from: cursor))
        return pieces
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
    /// Identifies this body for the reading-side translation cache
    /// (`PersistenceStore.cachedTranslation`/`cacheTranslation`) — all three
    /// left `nil` (the default) means this instance behaves exactly as
    /// before, untranslated. `kind` is a plain string, not `ContentKind`,
    /// so comments/replies and Help articles (not valid top-level
    /// `ContentKind` cases) can use this same path. `field` distinguishes
    /// multiple translatable bodies on one piece of content — Bug's
    /// description/steps/workaround, App's about/accessibility-comments —
    /// so they don't collide in the cache.
    var contentKind: String? = nil
    var contentId: String? = nil
    var field: String = "body"

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var expanded = false
    /// Defaults to showing the translation (not the original) once one
    /// exists — matches the whole point of turning auto-translate on.
    /// Persistent for the life of this view, no dismiss button, same as
    /// Safari's own translate banner.
    @State private var showOriginal = false
    @State private var resolvedContent: [UUID: ResolvedSegmentContent] = [:]

    private enum ResolvedSegmentContent {
        case plain(String)
        /// Used only for segments containing at least one link — preserves
        /// the link as a real, tappable, VoiceOver-actionable run instead of
        /// flattening it to inert text. See `LinkSplitter`.
        case attributed(AttributedString)
    }

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
            if hasActiveTranslation {
                TranslationBanner(showOriginal: $showOriginal)
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
        .accessibilityElement(children: .contain)
        .task(id: translationTaskId) { await resolveTranslationIfNeeded() }
    }

    private var hasActiveTranslation: Bool {
        contentId != nil && preferences.effectiveContentLanguage != nil && !resolvedContent.isEmpty
    }

    private var translationTaskId: String {
        "\(html)|\(preferences.effectiveContentLanguage ?? "")|\(contentId ?? "")"
    }

    /// Not translated (nil `contentId`, translation off, or `showOriginal`
    /// tapped) shows exactly what always rendered here — zero behavior
    /// change for every call site that hasn't opted in. Tables are
    /// deliberately excluded (stay English-only for v1 — see `allSegments`
    /// filtering below); cell-by-cell translation of a grid wasn't judged
    /// worth the added complexity for how rarely guides use tables.
    private func isTranslated(_ segment: HTMLSegment) -> Bool {
        !showOriginal && resolvedContent[segment.id] != nil
    }

    @ViewBuilder
    private func segmentContent(_ segment: HTMLSegment) -> some View {
        if !showOriginal, let resolved = resolvedContent[segment.id] {
            switch resolved {
            // Link-containing translated segments aren't masked yet — doing
            // so would need to mask matched text while preserving the
            // AttributedString's per-run link attribute, materially more
            // work for what's already the minority case among translated
            // segments (see resolveTranslationIfNeeded's doc comment).
            case .plain(let text): Text(preferences.filterProfanity ? ProfanityFilter.maskForDisplay(html: text) : text)
            case .attributed(let attributed): Text(attributed)
            }
        } else {
            HTMLTextView(html: preferences.filterProfanity ? ProfanityFilter.maskForDisplay(html: segment.html) : segment.html)
        }
    }

    /// Plain-text stand-in for a segment's current content, translated or
    /// not — used to build accessibility labels without needing a second
    /// switch over `ResolvedSegmentContent`. When profanity filtering is on,
    /// this is also where masked words get their spoken form ("s star star
    /// star") built explicitly, rather than relying on VoiceOver's own
    /// unreliable reading of the literal asterisks `segmentContent` shows
    /// visually — see `ProfanityFilter.accessiblePlaceholder`'s doc comment.
    private func accessibilityText(for segment: HTMLSegment) -> String {
        let base: String
        if !showOriginal, let resolved = resolvedContent[segment.id] {
            switch resolved {
            case .plain(let text): base = text
            case .attributed(let attributed): base = String(attributed.characters)
            }
        } else {
            base = segment.plainText
        }
        return preferences.filterProfanity ? ProfanityFilter.accessiblePlaceholder(for: base) : base
    }

    /// Whether a segment needs its accessibility label explicitly set at
    /// all — translation already required this; filtering adds a second
    /// reason, but only for segments that actually contain something to
    /// mask, so the vastly more common case (no profanity present) keeps
    /// inheriting its label from the rendered text itself, unchanged.
    private func needsAccessibilityOverride(_ segment: HTMLSegment) -> Bool {
        isTranslated(segment) || (preferences.filterProfanity && ProfanityFilter.containsProfanity(segment.plainText))
    }

    /// Batches every translatable segment's text into as few
    /// `TranslationCoordinator.translateBatch` calls as possible (one for
    /// plain segments, one for every link-containing segment's pieces
    /// combined) rather than awaiting per-segment. Plain segments are
    /// cached in `PersistenceStore` keyed per-segment (an edit to one
    /// paragraph only invalidates that paragraph); segments containing a
    /// link are deliberately NOT persisted — reassembling a cached
    /// `AttributedString`'s link attribute correctly would need a small
    /// serialization format `PersistenceStore.CachedTranslation`'s plain
    /// `String` doesn't have, and links are the minority case, so those
    /// re-translate (still on-device, still batched) each time the screen
    /// loads rather than adding that schema complexity now.
    private func resolveTranslationIfNeeded() async {
        guard let contentId, let targetLanguage = preferences.effectiveContentLanguage else {
            resolvedContent = [:]
            return
        }
        let kind = contentKind ?? "content"
        let translatableSegments = allSegments.filter {
            if case .table = $0.kind { return false }
            return true
        }

        var plainItems: [(segment: HTMLSegment, cacheField: String)] = []
        var linkItems: [(segment: HTMLSegment, pieces: [LinkSplitter.Piece])] = []
        for segment in translatableSegments {
            let pieces = LinkSplitter.split(segment.html)
            let hasLink = pieces.contains { if case .link = $0 { return true } else { return false } }
            if hasLink {
                linkItems.append((segment, pieces))
            } else {
                plainItems.append((segment, "\(field).segment.\(segment.id)"))
            }
        }

        var newResolved: [UUID: ResolvedSegmentContent] = [:]

        if !plainItems.isEmpty {
            var results = [String?](repeating: nil, count: plainItems.count)
            var toTranslateIndices: [Int] = []
            for (index, item) in plainItems.enumerated() {
                if let cached = PersistenceStore.shared.cachedTranslation(
                    kind: kind, id: contentId, field: item.cacheField, targetLanguage: targetLanguage, sourceText: item.segment.plainText
                ) {
                    results[index] = cached
                } else {
                    toTranslateIndices.append(index)
                }
            }
            if !toTranslateIndices.isEmpty {
                let translated = await TranslationCoordinator.shared.translateBatch(
                    toTranslateIndices.map { plainItems[$0].segment.plainText }, to: targetLanguage
                )
                for (offset, index) in toTranslateIndices.enumerated() {
                    guard let text = translated[offset] else { continue }
                    results[index] = text
                    PersistenceStore.shared.cacheTranslation(
                        kind: kind, id: contentId, field: plainItems[index].cacheField, targetLanguage: targetLanguage,
                        sourceText: plainItems[index].segment.plainText, translatedText: text
                    )
                }
            }
            for (index, item) in plainItems.enumerated() {
                if let text = results[index] { newResolved[item.segment.id] = .plain(text) }
            }
        }

        if !linkItems.isEmpty {
            struct Unit { let segmentId: UUID; let pieceIndex: Int; let text: String }
            var units: [Unit] = []
            for item in linkItems {
                for (pieceIndex, piece) in item.pieces.enumerated() {
                    switch piece {
                    case .text(let text): units.append(Unit(segmentId: item.segment.id, pieceIndex: pieceIndex, text: text))
                    case .link(let label, _): units.append(Unit(segmentId: item.segment.id, pieceIndex: pieceIndex, text: label))
                    }
                }
            }
            let translatedUnits = await TranslationCoordinator.shared.translateBatch(units.map(\.text), to: targetLanguage)
            var translatedByKey: [String: String] = [:]
            for (unit, result) in zip(units, translatedUnits) {
                guard let result else { continue }
                translatedByKey["\(unit.segmentId)#\(unit.pieceIndex)"] = result
            }
            for item in linkItems {
                var attributed = AttributedString()
                for (pieceIndex, piece) in item.pieces.enumerated() {
                    if pieceIndex > 0 { attributed += AttributedString(" ") }
                    let key = "\(item.segment.id)#\(pieceIndex)"
                    switch piece {
                    case .text(let original):
                        attributed += AttributedString(translatedByKey[key] ?? original)
                    case .link(let label, let href):
                        var run = AttributedString(translatedByKey[key] ?? label)
                        run.link = URL(string: href)
                        attributed += run
                    }
                }
                newResolved[item.segment.id] = .attributed(attributed)
            }
        }

        resolvedContent = newResolved
    }

    @ViewBuilder
    private func segmentView(_ segment: HTMLSegment) -> some View {
        switch segment.kind {
        case .heading(let level):
            segmentContent(segment)
                .font(level <= 2 ? .title3.weight(.semibold) : .headline)
                .accessibilityAddTraits(.isHeader)
                .modifier(ContentAccessibilityLabel(
                    isOverridden: needsAccessibilityOverride(segment), isTranslated: isTranslated(segment), text: accessibilityText(for: segment)
                ))
        case .quote:
            // Matches RN's quote styling (amber border + tinted background,
            // topic/[id].tsx) — Swift's was a plain gray border with no
            // background tint, much less visually distinct from prose.
            segmentContent(segment)
                .padding(.leading, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255).opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255)).frame(width: 3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: isTranslated(segment)
                    ? "Translated quote: \(accessibilityText(for: segment))"
                    : "Quoted: \(accessibilityText(for: segment))"))
        case .code:
            VStack(alignment: .leading, spacing: 4) {
                Text("CODE")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                segmentContent(segment)
                    .font(.system(.footnote, design: .monospaced))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: isTranslated(segment)
                ? "Translated code: \(accessibilityText(for: segment))"
                : "Code: \(accessibilityText(for: segment))"))
        case .table(let rows, let hasHeaderRow):
            tableView(rows: rows, hasHeaderRow: hasHeaderRow)
        case .prose:
            segmentContent(segment)
                .modifier(ContentAccessibilityLabel(
                    isOverridden: needsAccessibilityOverride(segment), isTranslated: isTranslated(segment), text: accessibilityText(for: segment)
                ))
        }
    }

    /// SwiftUI has no dedicated table-cell accessibility role, so each data
    /// cell's spoken label folds in its column header text directly
    /// ("VoiceOver support: Full" rather than just "Full") — the practical
    /// equivalent of real row/column semantics given what's actually
    /// available, while each cell stays its own separately-focusable
    /// element for cell-by-cell navigation and natural Braille boundaries.
    @ViewBuilder
    private func tableView(rows: [[String]], hasHeaderRow: Bool) -> some View {
        let columnCount = rows.map(\.count).max() ?? 0
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { columnIndex in
                            let cellText = columnIndex < row.count ? row[columnIndex] : ""
                            let isHeaderCell = hasHeaderRow && rowIndex == 0
                            Text(cellText)
                                .font(.subheadline)
                                .fontWeight(isHeaderCell ? .semibold : .regular)
                                .accessibilityAddTraits(isHeaderCell ? .isHeader : [])
                                .accessibilityLabel(tableCellAccessibilityLabel(
                                    rows: rows, rowIndex: rowIndex, columnIndex: columnIndex, hasHeaderRow: hasHeaderRow
                                ))
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func tableCellAccessibilityLabel(rows: [[String]], rowIndex: Int, columnIndex: Int, hasHeaderRow: Bool) -> String {
        let cellText = columnIndex < rows[rowIndex].count ? rows[rowIndex][columnIndex] : ""
        guard hasHeaderRow, rowIndex > 0, columnIndex < rows[0].count else { return cellText }
        let headerText = rows[0][columnIndex]
        guard !headerText.isEmpty, headerText != cellText else { return cellText }
        return cellText.isEmpty
            ? String(localized: "\(headerText): blank")
            : String(localized: "\(headerText): \(cellText)")
    }
}

/// Applies a "Translated: " prefix to a segment's spoken label only when
/// it's actually showing translated content — a visual translation badge
/// alone (see `TranslationBanner`) would leave VoiceOver users, a large
/// share of this app's audience, as the one group never told they're
/// reading a machine translation instead of the author's own words.
/// Leaves the view's default accessibility behavior completely untouched
/// when not translated, so nothing changes for the vastly more common
/// untranslated case.
struct ContentAccessibilityLabel: ViewModifier {
    /// Whether this segment needs an explicit label at all — false for the
    /// common case (untranslated, nothing to mask), which leaves the
    /// view's default accessibility behavior completely untouched. Defaults
    /// false so existing translation-only call sites (HelpArticleDetailView,
    /// which has no profanity-filtering concern — it's curated staff
    /// content, not user-generated) don't need to change.
    let isOverridden: Bool = false
    let isTranslated: Bool
    /// Already fully resolved: translated and/or profanity-masked as
    /// needed, via `SegmentedHTMLView.accessibilityText(for:)`.
    let text: String

    func body(content: Content) -> some View {
        if isTranslated {
            content.accessibilityLabel(String(localized: "Translated: \(text)"))
        } else if isOverridden {
            content.accessibilityLabel(text)
        } else {
            content
        }
    }
}

/// Splits a segment's HTML at each `<a href="...">` boundary into alternating
/// plain-text and link pieces, so translation can process the surrounding
/// text and a link's label independently — the `href` itself is never
/// touched, and the label piece keeps its link attribute once reassembled
/// into an `AttributedString` (see `SegmentedHTMLView.resolveTranslationIfNeeded`).
/// Text outside a link still loses any other inline HTML (bold, italic) it
/// had, same as the "plain text except links" trade-off applied everywhere
/// else translated content renders — only the link itself is protected,
/// since losing emphasis is cosmetic but a dead link would defeat the point
/// of, say, a developer's "please test my app" post.
private enum LinkSplitter {
    enum Piece {
        case text(String)
        case link(label: String, href: String)
    }

    static func split(_ html: String) -> [Piece] {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<a\b[^>]*?\bhref\s*=\s*"([^"]*)"[^>]*>(.*?)</a>"#) else {
            return [.text(html.strippingHTMLTags())]
        }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [.text(html.strippingHTMLTags())] }

        var pieces: [Piece] = []
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                let before = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                    .strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty { pieces.append(.text(before)) }
            }
            let href = ns.substring(with: match.range(at: 1))
            let label = ns.substring(with: match.range(at: 2)).strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { pieces.append(.link(label: label, href: href)) }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            let after = ns.substring(from: cursor).strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty { pieces.append(.text(after)) }
        }
        return pieces
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
