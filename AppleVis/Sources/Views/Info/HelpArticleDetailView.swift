import SwiftUI

struct HelpArticleDetailView: View {
    let article: HelpArticle

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showWelcomeTour = false
    /// Structurally this screen is a title + body article, just like the
    /// six content detail screens (Forum/Podcast/App/Blog/Bug/Guide) — but
    /// unlike them, it was never brought into their title-focus convention;
    /// the article's title only ever appears in the navigation bar, with no
    /// in-content focus target at all. Focuses the summary instead, the
    /// first substantial content a reader reaches, matching how Settings
    /// screens focus their own intro description. Full app-wide focus
    /// audit, requested directly.
    @AccessibilityFocusState private var isSummaryFocused: Bool

    /// Matches RN's "Read Article Summary" accessibility action format:
    /// "{title}. {summary}. {N} section headings. {M} steps."
    private var articleSummary: String {
        let headingCount = article.content.filter {
            if case .heading = $0 { return true }
            return false
        }.count
        let stepCount = article.content.reduce(0) { count, block -> Int in
            if case .steps(let items) = block { return count + items.count }
            return count
        }
        return String(localized: "\(article.title). \(article.summary). \(headingCount) section headings. \(stepCount) steps.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if let contentType = article.contentType {
                    HStack(spacing: 4) {
                        Image(systemName: contentType.icon)
                        Text(contentType.label.uppercased())
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(contentType.label)
                }

                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isSummaryFocused)
                    .accessibilityAction(named: Text("Read Article Summary")) {
                        UIAccessibility.post(notification: .announcement, argument: articleSummary)
                    }

                ForEach(article.content) { block in
                    HelpBlockView(block: block, articleId: article.id)
                        .padding(.horizontal)
                }

                if !article.relatedLinks.isEmpty {
                    relatedSection
                }

                Color.clear.frame(height: 24)
            }
            .padding(.vertical)
        }
        .background(preferences.colors.background)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWelcomeTour) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        }
        .task { await retryAccessibilityFocus(into: $isSummaryFocused) }
    }

    // MARK: - Related links

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related")
                .font(.headline)
                .padding(.top, 8).padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(article.relatedLinks.enumerated()), id: \.offset) { index, link in
                    relatedLinkRow(link)
                    if index < article.relatedLinks.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func relatedLinkRow(_ link: RelatedLink) -> some View {
        switch link.destination {
        case .article(let id):
            if let target = HelpContent.find(id) {
                NavigationLink(value: target) {
                    relatedLinkLabel(link)
                }
                .accessibilityLabel(link.label)
                .accessibilityHint(String(localized: "Opens this help article."))
            }
        case .guidedExperienceWelcome:
            Button {
                showWelcomeTour = true
            } label: {
                relatedLinkLabel(link)
            }
            .accessibilityLabel(link.label)
            .accessibilityHint(String(localized: "Opens the guided welcome tour."))
        case .whatsNew:
            NavigationLink {
                WhatsNewView()
            } label: {
                relatedLinkLabel(link)
            }
            .accessibilityLabel(link.label)
            .accessibilityHint(String(localized: "Opens What's New."))
        case .savedSyncSettings:
            NavigationLink {
                SavedSyncSettingsView()
            } label: {
                relatedLinkLabel(link)
            }
            .accessibilityLabel(link.label)
            .accessibilityHint(String(localized: "Opens Saved and Sync settings."))
        }
    }

    private func relatedLinkLabel(_ link: RelatedLink) -> some View {
        HStack(spacing: 10) {
            Image(systemName: link.type.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(link.label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct HelpBlockView: View {
    let block: HelpContentBlock
    /// Help articles are simpler to translate than HTML bodies elsewhere —
    /// already broken into discrete blocks, no HTML parsing needed. `field`
    /// keys are derived from `block.id` (itself content-derived, see
    /// `HelpContentBlock.id`) plus a sub-index for blocks holding several
    /// strings (bullets, steps, FAQ), so each string has its own stable
    /// cache entry under this article's id.
    let articleId: String

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translated: [String: String] = [:]

    /// Every translatable string in this block, keyed by its own field id.
    private var translatableTexts: [(field: String, text: String)] {
        switch block {
        case .heading(let text), .body(let text), .tip(let text), .note(let text), .warning(let text):
            return [(block.id, text)]
        case .bullets(let items), .steps(let items):
            return items.enumerated().map { ("\(block.id).\($0.offset)", $0.element) }
        case .faq(let question, let answer):
            return [("\(block.id).q", question), ("\(block.id).a", answer)]
        }
    }

    private func text(_ field: String, _ original: String) -> String {
        translated[field] ?? original
    }

    var body: some View {
        Group {
            switch block {
            case .heading(let originalText):
                Text(text(block.id, originalText))
                    .font(.headline)
                    .padding(.top, 8).padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
                    .modifier(ContentAccessibilityLabel(isTranslated: translated[block.id] != nil, text: text(block.id, originalText)))

            case .body(let originalText):
                Text(text(block.id, originalText))
                    .font(.body)
                    .padding(.bottom, 6)
                    .modifier(ContentAccessibilityLabel(isTranslated: translated[block.id] != nil, text: text(block.id, originalText)))

            case .bullets(let items):
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let field = "\(block.id).\(index)"
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(Color.accentColor)
                            Text(text(field, item))
                        }
                        .modifier(ContentAccessibilityLabel(isTranslated: translated[field] != nil, text: text(field, item)))
                    }
                }
                .padding(.bottom, 8)

            case .steps(let items):
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let field = "\(block.id).\(index)"
                        let displayText = text(field, item)
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption).fontWeight(.bold)
                                .frame(minWidth: 22, minHeight: 22)
                                .fixedSize()
                                .padding(4)
                                .background(Color.accentColor, in: Circle())
                                .foregroundStyle(.white)
                            Text(displayText)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(localized: translated[field] != nil
                            ? "Step \(index + 1). Translated: \(displayText)"
                            : "Step \(index + 1). \(displayText)"))
                    }
                }
                .padding(.bottom, 8)

            case .tip(let originalText):
                Callout(label: String(localized: "Tip"), text: text(block.id, originalText), color: .green, isTranslated: translated[block.id] != nil)
            case .note(let originalText):
                Callout(label: String(localized: "Note"), text: text(block.id, originalText), color: .blue, isTranslated: translated[block.id] != nil)
            case .warning(let originalText):
                Callout(label: String(localized: "Important"), text: text(block.id, originalText), color: .orange, isTranslated: translated[block.id] != nil)

            case .faq(let question, let answer):
                let qField = "\(block.id).q"
                let aField = "\(block.id).a"
                let qText = text(qField, question)
                let aText = text(aField, answer)
                VStack(alignment: .leading, spacing: 4) {
                    Text(qText).font(.body).fontWeight(.semibold)
                    Text(aText).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: (translated[qField] != nil || translated[aField] != nil)
                    ? "Question: \(qText). Answer: \(aText). Translated from English."
                    : "Question: \(qText). Answer: \(aText)"))
            }
        }
        .task(id: taskIdKey) { await resolveIfNeeded() }
    }

    private var taskIdKey: String {
        let joined = translatableTexts.map(\.text).joined(separator: "|")
        return ContentTranslation.taskId(field: block.id, text: joined, targetLanguage: preferences.effectiveContentLanguage)
    }

    private func resolveIfNeeded() async {
        guard let targetLanguage = preferences.effectiveContentLanguage else {
            translated = [:]
            return
        }
        let items = translatableTexts
        guard !items.isEmpty else { return }

        var resolved = [String?](repeating: nil, count: items.count)
        var toTranslateIndices: [Int] = []
        for (index, item) in items.enumerated() {
            if let cached = PersistenceStore.shared.cachedTranslation(
                kind: "helpArticle", id: articleId, field: item.field, targetLanguage: targetLanguage, sourceText: item.text
            ) {
                resolved[index] = cached
            } else {
                toTranslateIndices.append(index)
            }
        }
        if !toTranslateIndices.isEmpty {
            let translatedBatch = await TranslationCoordinator.shared.translateBatch(
                toTranslateIndices.map { items[$0].text }, to: targetLanguage
            )
            for (offset, index) in toTranslateIndices.enumerated() {
                guard let text = translatedBatch[offset] else { continue }
                resolved[index] = text
                PersistenceStore.shared.cacheTranslation(
                    kind: "helpArticle", id: articleId, field: items[index].field, targetLanguage: targetLanguage,
                    sourceText: items[index].text, translatedText: text
                )
            }
        }
        var results: [String: String] = [:]
        for (index, item) in items.enumerated() {
            if let value = resolved[index] { results[item.field] = value }
        }
        translated = results
    }
}

private struct Callout: View {
    let label: String
    let text: String
    let color: Color
    var isTranslated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(color)
            Text(text).font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 0).padding(.leading, -1))
        .overlay(alignment: .leading) {
            Rectangle().fill(color).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: isTranslated ? "\(label). Translated: \(text)" : "\(label). \(text)"))
    }
}
