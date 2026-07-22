import SwiftUI

struct HelpView: View {
    private let sections: [HelpSection] = [
        HelpSection(title: "Getting Started", icon: "star", articles: [
            HelpArticle(title: "Welcome to AppleVis", summary: "An introduction to what AppleVis is and how it can help you.", url: "https://www.applevis.com/help/welcome"),
            HelpArticle(title: "Navigating the App with VoiceOver", summary: "How to move through tabs, lists, and detail pages using VoiceOver gestures.", url: "https://www.applevis.com/help/voiceover-navigation"),
            HelpArticle(title: "Creating an Account", summary: "Step-by-step guide to registering and signing in to AppleVis.", url: "https://www.applevis.com/help/creating-account"),
        ]),
        HelpSection(title: "Forums", icon: "bubble.left.and.bubble.right", articles: [
            HelpArticle(title: "How to Post in the Forums", summary: "Composing and submitting forum topics, including formatting tips.", url: "https://www.applevis.com/help/posting-forums"),
            HelpArticle(title: "Following Topics and Members", summary: "Stay updated on discussions that matter to you.", url: "https://www.applevis.com/help/following"),
        ]),
        HelpSection(title: "Podcasts", icon: "headphones", articles: [
            HelpArticle(title: "Listening to Podcasts", summary: "Using the audio player, chapters, and speed controls.", url: "https://www.applevis.com/help/listening-podcasts"),
            HelpArticle(title: "Managing Your Queue", summary: "Adding, reordering, and removing episodes from your listening queue.", url: "https://www.applevis.com/help/podcast-queue"),
        ]),
        HelpSection(title: "Accessibility", icon: "accessibility", articles: [
            HelpArticle(title: "VoiceOver Detail Level", summary: "Choosing how much information VoiceOver announces for each item.", url: "https://www.applevis.com/help/voiceover-detail"),
            HelpArticle(title: "Accessibility Settings Reference", summary: "A full guide to every accessibility option in the app.", url: "https://www.applevis.com/help/a11y-settings"),
        ]),
        HelpSection(title: "Contact & Support", icon: "envelope", articles: [
            HelpArticle(title: "Reporting a Bug", summary: "How to submit a bug report to the AppleVis team.", url: "https://www.applevis.com/help/bug-report"),
            HelpArticle(title: "Contact AppleVis", summary: "Get in touch with the team for questions or feedback.", url: "https://www.applevis.com/contact"),
        ]),
    ]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.articles) { article in
                        Link(destination: URL(string: article.url)!) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(article.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                        .accessibilityLabel("\(article.title). \(article.summary). Opens in browser.")
                    }
                } header: {
                    Label(section.title, systemImage: section.icon)
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let articles: [HelpArticle]
}

private struct HelpArticle: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let url: String
}
