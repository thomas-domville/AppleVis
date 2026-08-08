import SwiftUI

struct HelpArticleDetailView: View {
    let article: HelpArticle

    @State private var showWelcomeTour = false

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
        return "\(article.title). \(article.summary). \(headingCount) section headings. \(stepCount) steps."
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
                    .accessibilityAction(named: Text("Read Article Summary")) {
                        UIAccessibility.post(notification: .announcement, argument: articleSummary)
                    }

                ForEach(article.content) { block in
                    HelpBlockView(block: block)
                        .padding(.horizontal)
                }

                if !article.relatedLinks.isEmpty {
                    relatedSection
                }

                Color.clear.frame(height: 24)
            }
            .padding(.vertical)
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWelcomeTour) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        }
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
                .accessibilityHint("Opens this help article.")
            }
        case .guidedExperienceWelcome:
            Button {
                showWelcomeTour = true
            } label: {
                relatedLinkLabel(link)
            }
            .accessibilityLabel(link.label)
            .accessibilityHint("Opens the guided welcome tour.")
        case .whatsNew:
            NavigationLink {
                WhatsNewView()
            } label: {
                relatedLinkLabel(link)
            }
            .accessibilityLabel(link.label)
            .accessibilityHint("Opens What's New.")
        case .savedSyncSettings:
            NavigationLink {
                SavedSyncSettingsView()
            } label: {
                relatedLinkLabel(link)
            }
            .accessibilityLabel(link.label)
            .accessibilityHint("Opens Saved and Sync settings.")
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

    var body: some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.headline)
                .padding(.top, 8).padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)

        case .body(let text):
            Text(text)
                .font(.body)
                .padding(.bottom, 6)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Color.accentColor)
                        Text(item)
                    }
                }
            }
            .padding(.bottom, 8)

        case .steps(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption).fontWeight(.bold)
                            .frame(minWidth: 22, minHeight: 22)
                            .fixedSize()
                            .padding(4)
                            .background(Color.accentColor, in: Circle())
                            .foregroundStyle(.white)
                        Text(item)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(index + 1). \(item)")
                }
            }
            .padding(.bottom, 8)

        case .tip(let text):
            Callout(label: "Tip", text: text, color: .green)
        case .note(let text):
            Callout(label: "Note", text: text, color: .blue)
        case .warning(let text):
            Callout(label: "Important", text: text, color: .orange)

        case .faq(let question, let answer):
            VStack(alignment: .leading, spacing: 4) {
                Text(question).font(.body).fontWeight(.semibold)
                Text(answer).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Question: \(question). Answer: \(answer)")
        }
    }
}

private struct Callout: View {
    let label: String
    let text: String
    let color: Color

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
        .accessibilityLabel("\(label). \(text)")
    }
}
