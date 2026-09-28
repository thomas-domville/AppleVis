import SwiftUI

struct HelpView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showContact = false
    @State private var query = ""
    /// Had no focus management at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isIntroFocused: Bool
    @AccessibilityFocusState private var isContactFocused: Bool

    @State private var showAskTheMouse = false
    @AccessibilityFocusState private var isAskTheMouseFocused: Bool

    /// Searches every article's full text, not just titles and summaries,
    /// so something mentioned only inside an article can be found.
    /// Changed alongside Ask the Mouse (2026-09-28).
    private var filteredSections: [HelpSection] {
        MouseKnowledge.filterHelpSections(query)
    }

    /// Matches RN's "Read Help Summary" accessibility action format exactly:
    /// "{sectionCount} help sections and {articleCount} articles. Includes {section titles joined}."
    private var helpSummary: String {
        let sectionCount = HelpContent.sections.count
        let articleCount = HelpContent.sections.reduce(0) { $0 + $1.articles.count }
        let titles = HelpContent.sections.map(\.title).joined(separator: ", ")
        return String(localized: "\(sectionCount) help sections and \(articleCount) articles. Includes \(titles).")
    }

    var body: some View {
        List {
            Section {
                introCard
            }

            if IntelligenceService.isAvailable {
                Section {
                    Button {
                        showAskTheMouse = true
                    } label: {
                        HStack(spacing: 12) {
                            MouseMascotView(pose: .searching, size: 36, style: .face)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ask the Mouse")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("Ask in your own words, and the Mouse answers from Help, guides, and the rest of AppleVis.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Ask the Mouse"))
                    .accessibilityHint(String(localized: "Ask in your own words, and the Mouse answers from Help, guides, and the rest of AppleVis."))
                    .accessibilityFocused($isAskTheMouseFocused)
                }
            }

            Section {
                TextField("Search help...", text: $query)
                    .autocorrectionDisabled()
                    .accessibilityLabel(String(localized: "Search help"))
                    .accessibilityHint(String(localized: "Searches the text of every help article."))
            }

            if filteredSections.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Luck With That Search")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Try a different word, or reach out to us below — we're happy to help.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } else {
                ForEach(filteredSections) { section in
                    Section {
                        ForEach(section.articles) { article in
                            NavigationLink(value: article) {
                                articleRow(article)
                            }
                            .accessibilityLabel(articleAccessibilityLabel(article))
                        }
                    } header: {
                        sectionHeader(section)
                    } footer: {
                        Text(section.description)
                    }
                }
            }

            Section("Contact & Support") {
                Button {
                    showContact = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contact AppleVis")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("Didn't find what you needed? Send us a note — we'd love to hear from you.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityLabel(String(localized: "Contact AppleVis"))
                .accessibilityFocused($isContactFocused)
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HelpArticle.self) { article in
            HelpArticleDetailView(article: article)
        }
        // Back to the Contact button after sending or cancelling. Reported directly.
        .sheet(isPresented: $showAskTheMouse, onDismiss: {
            Task { await retryAccessibilityFocus(into: $isAskTheMouseFocused) }
        }) {
            AskTheMouseView()
        }
        .sheet(isPresented: $showContact, onDismiss: {
            Task { await retryAccessibilityFocus(into: $isContactFocused) }
        }) {
            ContactView()
        }
        .task { await retryAccessibilityFocus(into: $isIntroFocused) }
    }

    // MARK: - Intro card

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lifepreserver")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Offline Guide")
                    .font(.headline)
                Text("Everything you need to feel at home in AppleVis — tutorials, accessibility tips, settings help, smart features, and troubleshooting, all saved right here so it works even without a connection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isIntroFocused)
        .accessibilityAction(named: Text("Read Help Summary")) {
            UIAccessibility.post(notification: .announcement, argument: helpSummary)
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ section: HelpSection) -> some View {
        HStack {
            Label(section.title, systemImage: section.icon)
            Spacer()
            Text("\(section.articles.count)")
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .themedPill(preferences.colors)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(section.title), \(section.articles.count) articles"))
    }

    // MARK: - Article row

    private func articleRow(_ article: HelpArticle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let contentType = article.contentType {
                    Text(contentType.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .themedPill(preferences.colors)
                }
            }
            Text(article.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private func articleAccessibilityLabel(_ article: HelpArticle) -> String {
        if let contentType = article.contentType {
            return "\(article.title), \(contentType.label). \(article.summary)"
        }
        return "\(article.title). \(article.summary)"
    }
}
