import SwiftUI

struct HelpView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showContact = false
    @State private var query = ""
    /// Had no focus management at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isIntroFocused: Bool

    private var filteredSections: [HelpSection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return HelpContent.sections }
        let lowerQuery = trimmed.lowercased()
        return HelpContent.sections.compactMap { section in
            if section.title.lowercased().contains(lowerQuery) {
                return section
            }
            let matchingArticles = section.articles.filter { article in
                article.title.lowercased().contains(lowerQuery)
                    || article.summary.lowercased().contains(lowerQuery)
            }
            guard !matchingArticles.isEmpty else { return nil }
            return HelpSection(
                id: section.id,
                title: section.title,
                icon: section.icon,
                description: section.description,
                articles: matchingArticles
            )
        }
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

            Section {
                TextField("Search help...", text: $query)
                    .autocorrectionDisabled()
                    .accessibilityLabel(String(localized: "Search help"))
                    .accessibilityHint(String(localized: "Filters help articles by title and summary."))
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
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HelpArticle.self) { article in
            HelpArticleDetailView(article: article)
        }
        .sheet(isPresented: $showContact) {
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
