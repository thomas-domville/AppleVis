import SwiftUI

struct HelpView: View {
    @State private var showContact = false

    var body: some View {
        List {
            ForEach(HelpContent.sections) { section in
                Section {
                    ForEach(section.articles) { article in
                        NavigationLink(value: article) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(article.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                        .accessibilityLabel("\(article.title). \(article.summary)")
                    }
                } header: {
                    Label(section.title, systemImage: section.icon)
                } footer: {
                    Text(section.description)
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
                        Text("Get in touch with the team for questions or feedback.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityLabel("Contact AppleVis")
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HelpArticle.self) { article in
            HelpArticleDetailView(article: article)
        }
        .sheet(isPresented: $showContact) {
            ContactView()
        }
    }
}
