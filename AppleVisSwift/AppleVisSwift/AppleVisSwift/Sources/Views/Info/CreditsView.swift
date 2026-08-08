import SwiftUI

/// Ported verbatim from RN's `app/credits.tsx` — the previous version of this
/// screen had entirely fabricated content (generic "AppleVis Community" /
/// "AppleVis Podcast Team" placeholders and a fictional tech-stack list)
/// instead of the real named credits RN actually shipped.
struct CreditsView: View {
    @EnvironmentObject private var preferences: PreferencesStore

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
            title: "App Creation",
            icon: "hammer",
            body: "The AppleVis app was shaped by people who cared deeply about making the community easier, faster, and more enjoyable to use.",
            people: [
                ("Design and Coding", "Thomas Domville"),
                ("Wording and Quality", "Michael Hansen"),
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
            body: "Thank you to the AppleVis community for making the site what it is. Without the people who ask questions, share knowledge, review apps, post comments, and support one another, AppleVis would not be the same. This app is for you."
        ),
        CreditSection(
            title: "AppleVis Editorial Team",
            icon: "newspaper",
            body: "Thank you to the AppleVis Editorial Team, past and present, for the care, judgment, hard work, and steady commitment required to keep AppleVis maintained, updated, and moving forward."
        ),
        CreditSection(
            title: "David Goodwin",
            icon: "star",
            body: "Most of all, thank you to AppleVis founder David Goodwin. This app would not have come to life without the community he created for all of us to enjoy. His dedication, hard work, and commitment to AppleVis made everything that followed possible.",
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
                        .accessibilityLabel("\(person.label): \(person.name)")
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
    }
}
