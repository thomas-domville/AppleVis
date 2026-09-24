import SwiftUI

/// Ported verbatim from RN's `app/credits.tsx` — the previous version of this
/// screen had entirely fabricated content (generic "AppleVis Community" /
/// "AppleVis Podcast Team" placeholders and a fictional tech-stack list)
/// instead of the real named credits RN actually shipped.
struct CreditsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    /// Had no focus management at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isTitleFocused: Bool

    private struct CreditSection: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let body: String
        var people: [(label: String, name: String)] = []
        var featured: Bool = false
    }

    private let sections: [CreditSection] = [
        CreditSection(
            title: "Ana Domville",
            icon: "heart.fill",
            body: "Thank you to my daughter, Ana Domville, who spent so many hours right alongside me making this app happen — getting GitHub set up, walking me through Apple's App Store Connect, and patiently teaching me my way around Xcode on my own MacBook. She helped me get Claude and Codex running on my Mac too, and never once lost patience doing any of it. Her help was immense, and this app simply would not exist without her. Thank you, Ana — I could not thank you enough.",
            featured: true
        ),
        CreditSection(
            title: "App Creation",
            icon: "hammer",
            body: "The AppleVis app was shaped by people who cared deeply about making the community easier, faster, and more enjoyable to use.",
            people: [
                (String(localized: "Design and Coding"), "Thomas Domville"),
                (String(localized: "Wording and Quality"), "Michael Hansen"),
            ]
        ),
        CreditSection(
            title: "Beta Testers",
            icon: "flask",
            body: "Thank you to every beta tester who shared feedback, suggested improvements, and found bugs before release. Your careful testing made this app better for everyone."
        ),
        CreditSection(
            title: "The AppleVis Community",
            icon: "person.2",
            body: "Thank you to the entire AppleVis community — the people who ask questions, answer them, share what they've learned, write reviews, post in the forums, and simply show up for each other, day after day. AppleVis isn't really a website or an app. It's the community itself, and this app was built for every one of you who makes it what it is."
        ),
        CreditSection(
            title: "AppleVis Editorial Team",
            icon: "newspaper",
            body: "Thank you to the AppleVis Editorial Team, past and present, for the care, judgment, hard work, and steady commitment required to keep AppleVis maintained, updated, and moving forward."
        ),
        CreditSection(
            title: "David Goodwin",
            icon: "star",
            body: "More than anyone, thank you to David Goodwin, the founder of AppleVis. He built a place for blind and low vision Apple users to learn from each other, support one another, and simply belong somewhere — and every part of this app exists only because that community exists first. None of this would be here without him building AppleVis, and without him continuing to care for it ever since. Thank you, David, for everything.",
            featured: true
        ),
        CreditSection(
            title: "Be My Eyes",
            icon: "heart",
            body: "Thank you to Be My Eyes for supporting AppleVis and helping keep the lights on, so people can continue to learn, participate, and contribute."
        ),
    ]

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityHidden(true)
                    Text("AppleVis Credits")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                    Text("AppleVis exists because of the people who build, write, test, maintain, support, and participate in this community.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            ForEach(sections) { section in
                Section {
                    Label(section.title, systemImage: section.icon)
                        .font(.headline)
                        .foregroundStyle(section.featured ? Color.accentColor : .primary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(section.people, id: \.label) { person in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(person.name)
                                .font(.body.bold())
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(localized: "\(person.label): \(person.name)"))
                    }

                    Text(section.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("To everyone who has helped AppleVis become what it is: thank you.")
                    .font(.body.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
