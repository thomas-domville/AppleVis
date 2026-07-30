import SwiftUI

struct WhatsNewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                versionHeader
                    .padding()

                ForEach(ChangeItem.current) { item in
                    ChangeCard(item: item)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                ForEach(HistorySection.all) { section in
                    HistoryCard(section: section)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                Color.clear.frame(height: 40)
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionHeader: some View {
        VStack(spacing: 8) {
            Text("Version \(ChangeItem.currentVersion)")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityHidden(true)

            Text("A new Apple Watch app, sharing into AppleVis from other apps, picking up where you left off on another device, iPad keyboard shortcuts, and a big pass making sure everything actually works as expected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("What's new in AppleVis version \(ChangeItem.currentVersion)")
    }
}

// MARK: - Change card

private struct ChangeCard: View {
    let item: ChangeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.body).fontWeight(.bold)
                        TagBadge(tag: item.tag)
                    }
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.tag.rawValue): \(item.title). \(item.description)")
    }
}

// MARK: - Tag badge

private struct TagBadge: View {
    let tag: ChangeTag

    var body: some View {
        Text(tag.rawValue)
            .font(.caption2).fontWeight(.bold)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(tag.foregroundColor)
            .background(tag.backgroundColor, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}

// MARK: - History card

private struct HistoryCard: View {
    let section: HistorySection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Also in \(section.title)")
    }
}

// MARK: - Data

enum ChangeTag: String {
    case new = "New"
    case improved = "Improved"
    case fixed = "Fixed"

    var backgroundColor: Color {
        switch self {
        case .new:      return Color(red: 0.93, green: 0.99, blue: 0.96)
        case .improved: return Color(red: 0.94, green: 0.96, blue: 1.0)
        case .fixed:    return Color(red: 1.0, green: 0.97, blue: 0.93)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .new:      return Color(red: 0.02, green: 0.37, blue: 0.27)
        case .improved: return Color(red: 0.11, green: 0.30, blue: 0.85)
        case .fixed:    return Color(red: 0.60, green: 0.20, blue: 0.07)
        }
    }
}

struct ChangeItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let tag: ChangeTag
    let title: String
    let description: String

    static let currentVersion = "2026.0.7"

    static let current: [ChangeItem] = [
        ChangeItem(
            systemImage: "applewatch",
            tag: .new,
            title: "AppleVis on Apple Watch",
            description: "A brand-new Apple Watch app lets you see what episode is playing, play or pause, and skip forward or back right from your wrist — no need to take out your phone. It also shows how many forum replies are waiting for you."
        ),
        ChangeItem(
            systemImage: "square.and.arrow.up",
            tag: .new,
            title: "Share Into AppleVis From Other Apps",
            description: "Found an app, podcast, or article somewhere else? Use the Share button in Safari or any other app and choose AppleVis. It opens the right submission form automatically with the link already filled in."
        ),
        ChangeItem(
            systemImage: "laptopcomputer.and.iphone",
            tag: .new,
            title: "Pick Up Where You Left Off on Another Device",
            description: "Reading a topic or listening to a podcast on your iPhone? With Handoff, an AppleVis icon appears on your nearby iPad or Mac so you can jump straight back in on that device."
        ),
        ChangeItem(
            systemImage: "keyboard",
            tag: .new,
            title: "Keyboard Shortcuts on iPad",
            description: "If you use an external keyboard with your iPad, hold down the Command key to see new shortcuts — jump to Search, Settings, or straight to Forums, Apps, Podcasts, or Resources."
        ),
        ChangeItem(
            systemImage: "checkmark.seal",
            tag: .fixed,
            title: "Several Features Now Actually Work",
            description: "A thorough check turned up a number of features that looked fine but were not fully working behind the scenes. Apple Intelligence, Siri Shortcuts, AirPlay, Spotlight search results, Lock Screen and Control Center playback controls, Voice Boost, Trim Silence, on-device podcast artwork descriptions, and iCloud sync of your podcast library are now all working properly."
        ),
        ChangeItem(
            systemImage: "bell.badge",
            tag: .improved,
            title: "AppleVis Categories in Focus Settings",
            description: "AppleVis notification categories now appear in Settings → Focus, so you can start choosing which ones — like mentions or new episodes — you want to allow through during a Focus mode."
        ),
    ]
}

struct HistorySection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]

    static let all: [HistorySection] = [
        HistorySection(title: "Also in 2026.0.6", items: [
            "Contact App Support wizard — reach the AppleVis team without leaving the app or using Mail",
            "Apple Intelligence features — summarize, simplify, and translate text on-device (iPhone 15 Pro+, iOS 26)",
            "Three new Siri Shortcuts — resume your podcast, search AppleVis, or open saved items by voice",
            "Skip to the next queued episode using AirPods or the Lock Screen",
            "Podcast artwork appears on the Lock Screen, Dynamic Island, and Control Center",
            "Help Centre fully refreshed to match the current app",
            "App icon adapts automatically to your Home Screen style (iOS 18+)",
            "Dynamic Island shows the correct play or pause icon",
        ]),
        HistorySection(title: "Also in 2026.0.5", items: [
            "Submit a bug report inside the app — four-step wizard with platform, OS version, title, Feedback ID, description, and recognition preference",
            "Submit a blog post inside the app — write, import a text or Markdown file, or paste from the clipboard",
            "Submit a podcast episode inside the app — upload your audio file directly from Files or iCloud Drive",
            "Submit an app entry to the App Directory inside the app — iTunes search, accessibility ratings, and immediate publication",
            "Share Extension now recognises App Store links, podcast URLs, and text files — each opens the right wizard automatically",
            "Help Centre step-by-step guides for all four submission wizards",
            "Refreshed UI sounds — cleaner versions throughout",
        ]),
        HistorySection(title: "Also in 2026.0.4 – 2026.0.3", items: [
            "Edit and delete your own posts and reviews directly from detail pages inside the app",
            "App Directory detail page redesigned — VoiceOver, labelling, and usability ratings, developer contact, iTunes link, and supported devices",
            "Forum topic category hero card, animated replies, braille-friendly paragraph splits, per-author avatar colours, and thread summary action",
            "Blog and guide detail pages match the forum topic visual design and VoiceOver behaviour",
            "Home tab welcome flow redesigned — focus-based, no announcements, jumps to last-read position",
        ]),
        HistorySection(title: "Also in 2026.0.2", items: [
            "Golden Retriever Bark added as a third alert sound option",
            "All alert sounds balanced to the same loudness level",
            "Welcome card shows new comment counts and jumps to last-read position",
            "Three genuinely different VoiceOver Detail Levels: Simple, Normal, and All",
            "Follow forum topics and receive reply notifications",
            "Blog posts and guides open fully inside the app with comments",
            "Write app reviews in-app with rating and accessibility assessment",
            "Load More button and Jump to First Unread in long forum threads",
            "Episode duration shown on feed cards after first play",
            "App detail pages show VoiceOver, labelling, and usability ratings",
            "Forum threads: category headers, colour-coded avatars, NEW badges, code blocks",
            "Blog, guide, episode, and resource detail pages redesigned",
            "VoiceOver focus lands correctly after feed load and pull-to-refresh",
            "Pitch correction applied correctly when switching playback speed",
        ]),
        HistorySection(title: "Also in 2026.0.1.3 – 2026.0.1.5", items: [
            "Welcome tone plays on every app launch",
            "Refreshed notification and system sounds",
            "Saved and downloaded episodes with full Queue, Share, Mark as Played actions",
            "Sort your saved and downloaded episodes by date, title, or duration",
            "VoiceOver announces \"Saved\" on bookmarked episode cards (Detail Level: All)",
            "Episode About section revamped — clean text, live links with icons",
            "Episode transcripts open in a dedicated full-screen modal",
            "Podcast artwork described by on-device iOS intelligence",
            "Full forum topic and episode detail screens",
            "Bottom toolbars on all detail pages for quick actions",
        ]),
        HistorySection(title: "Also in 2026.0.1.1 – 2026.0.1.2", items: [
            "Read full forum threads with all replies inside the app",
            "Post replies to forum topics directly from the app",
            "Full app listings with all community reviews",
            "Read complete guides and articles inside the app",
            "Podcast settings with working controls for speed, skip times, and more",
            "Notification settings with real on/off toggles for each category",
            "Theme and card size settings with instant preview",
            "VoiceOver Detail Level setting — choose Simple, Normal, or All",
            "Back button added to every settings, detail, and sub-screen",
            "Magic tap (two-finger double tap) plays and pauses podcasts",
        ]),
    ]
}
