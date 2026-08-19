import SwiftUI

struct WhatsNewView: View {
    @EnvironmentObject private var preferences: PreferencesStore

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
        .background(preferences.colors.background)
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

            Text("A new app icon badge, a redesigned App Directory page, better podcast episode info, a smoother setup process, and a batch of VoiceOver and sign-in fixes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "What's new in AppleVis version \(ChangeItem.currentVersion)"))
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
        .accessibilityLabel(String(localized: "\(item.tag.rawValue): \(item.title). \(item.description)"))
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
        .accessibilityLabel(String(localized: "Also in \(section.title)"))
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

    static let currentVersion = "2026.0.9"

    static let current: [ChangeItem] = [
        ChangeItem(
            systemImage: "app.badge",
            tag: .new,
            title: "App Icon Badge",
            description: "Turn on Badge Count in Settings → Notifications to see a number on the AppleVis icon for what's new — only counting the kinds of notifications you've actually turned on. Opening the app clears it."
        ),
        ChangeItem(
            systemImage: "hand.point.up.left",
            tag: .fixed,
            title: "Duplicate VoiceOver Actions on Cards",
            description: "VoiceOver no longer repeats \"Save\" and \"Share\" twice when swiping through the actions on a topic, episode, app, blog, or guide card. The same fix applies to downloaded episodes."
        ),
        ChangeItem(
            systemImage: "arrow.up.forward.app",
            tag: .improved,
            title: "App Entry Cards",
            description: "\"Write a Review\" is now called \"Add New Comment\", matching every other card. \"Open in App Store\" is also more reliable now with VoiceOver."
        ),
        ChangeItem(
            systemImage: "arrow.down.circle",
            tag: .new,
            title: "Download Episode on Podcast Cards",
            description: "Podcast cards now have their own Download button, so you can download, cancel, or remove an episode without opening it first. Saving an episode is still separate from downloading it."
        ),
        ChangeItem(
            systemImage: "plus.circle",
            tag: .new,
            title: "Add Button on Home",
            description: "A new Add button on the Home tab lets you start a new forum topic or add a new app to the App Directory. It's there whether or not you're signed in — tap it while signed out and you'll be asked to sign in first. Blog posts, podcasts, and bug reports still go through Discover's Contribute section, since those need to be reviewed before they're published."
        ),
        ChangeItem(
            systemImage: "bubble.left",
            tag: .fixed,
            title: "Comment Button on Detail Pages",
            description: "Every topic, episode, app, blog post, and guide page now has a Comment (or Write Review) button at the bottom of the screen, whether or not you're signed in."
        ),
        ChangeItem(
            systemImage: "arrow.down.to.line",
            tag: .new,
            title: "Jump to First New Comment from Any Card",
            description: "Cards with new activity now offer a \"Jump to First New Comment\" option, so you can go straight to what's new instead of scrolling through the whole page."
        ),
        ChangeItem(
            systemImage: "square.grid.2x2",
            tag: .fixed,
            title: "Tab Selection Announced",
            description: "Switching between Home, Discover, and For You with VoiceOver now tells you which tab you landed on, instead of just playing a sound."
        ),
        ChangeItem(
            systemImage: "person.crop.circle.badge.exclamationmark",
            tag: .fixed,
            title: "Sign In",
            description: "Fixed a bug where signing in with the correct username and password could fail with a confusing \"item is no longer available\" error."
        ),
        ChangeItem(
            systemImage: "arrow.clockwise",
            tag: .new,
            title: "Home Refreshes on Return",
            description: "Coming back to AppleVis after being away now refreshes the Home tab automatically — as long as you're on the Home tab and it's been more than 5 minutes since it last loaded."
        ),
        ChangeItem(
            systemImage: "app.badge",
            tag: .improved,
            title: "App Entry Page Redesigned",
            description: "App Directory pages are now easier to follow, with a clearer layout and a shortcut to new comments near the top. Screenshots now have real descriptions instead of just \"Screenshot 2 of 5.\""
        ),
        ChangeItem(
            systemImage: "dial.medium",
            tag: .new,
            title: "Custom VoiceOver Rotor Options",
            description: "New VoiceOver rotor options make it quicker to jump to new comments, replies to you, and podcast chapters, plus quick filters for what's new on the Home tab."
        ),
        ChangeItem(
            systemImage: "waveform",
            tag: .new,
            title: "Real Episode Duration and Chapters",
            description: "Podcast episodes now show their real length instead of a placeholder, and chapters are available even when they weren't included in AppleVis's own listing. The transcript no longer shows up twice on the episode page — use the Transcript button instead."
        ),
        ChangeItem(
            systemImage: "slider.horizontal.3",
            tag: .improved,
            title: "Episode Page Playback Controls",
            description: "Playback speed, sleep timer, and AirPlay are now available directly from the episode page, without needing to start playing first."
        ),
        ChangeItem(
            systemImage: "moon.stars",
            tag: .fixed,
            title: "System (Inverted) Theme",
            description: "Fixed a bug where selecting the System (Inverted) theme made the screen flicker back and forth between light and dark."
        ),
        ChangeItem(
            systemImage: "figure.wave",
            tag: .improved,
            title: "Setup Wizard",
            description: "Several improvements to the setup steps you see the first time you open the app: notifications now start off instead of on, clearer step-by-step wording throughout, and a theme name change."
        ),
        ChangeItem(
            systemImage: "ipad.and.iphone",
            tag: .new,
            title: "Supported Devices on App Entries",
            description: "App Directory pages now show which devices an app works on — iPhone, iPad, iPod touch, Apple Watch, Mac, and Apple TV."
        ),
    ]
}

struct HistorySection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]

    static let all: [HistorySection] = [
        HistorySection(title: "Also in 2026.0.8 – 2026.0.7", items: [
            "Share into AppleVis from other apps — Safari or any app's Share button opens the right submission form with the link already filled in",
            "Handoff — pick up a topic or podcast on a nearby iPad or Mac right where you left off on iPhone",
            "iPad keyboard shortcuts — hold Command for shortcuts to Search, Settings, Forums, Apps, Podcasts, and Resources",
            "Apple Intelligence, Siri Shortcuts, AirPlay, Spotlight search results, Lock Screen and Control Center playback, Voice Boost, Trim Silence, on-device podcast artwork descriptions, and iCloud podcast sync all fixed and working properly",
            "AppleVis notification categories now appear in Settings → Focus",
        ]),
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
