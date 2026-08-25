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
                    HistorySectionView(section: section)
                        .padding(.bottom, 4)
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

            Text("This update makes the App Directory more complete, adds clearer ways to open App Store and RSS links, shows when App Store listings may no longer be available, gives editors a safer way to refresh app information, improves submission forms, and smooths out VoiceOver focus across the app.")
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

// MARK: - History section

private struct HistorySectionView: View {
    let section: HistorySection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.items) { item in
                ChangeCard(item: item)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section.title)
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

    static let currentVersion = "2026.0.23"

    static let current: [ChangeItem] = [
        ChangeItem(
            systemImage: "arrow.up.forward.app",
            tag: .new,
            title: "Clearer App Store Button on App Pages",
            description: "App pages now include a large Open in App Store button near the top. The button makes clear that downloads and purchases are handled by Apple, not inside AppleVis."
        ),
        ChangeItem(
            systemImage: "dot.radiowaves.left.and.right",
            tag: .new,
            title: "RSS Feeds in Discover",
            description: "Discover now includes an RSS Feeds page. You can copy or share links for the main AppleVis feed, apps, blogs, guides, reviews, forums, Apple-only forum posts, and podcasts."
        ),
        ChangeItem(
            systemImage: "macbook.and.iphone",
            tag: .new,
            title: "More Complete App Directory",
            description: "Mac, Apple Watch, and Apple TV app entries now work more consistently across submitting, browsing, search, app pages, and comments."
        ),
        ChangeItem(
            systemImage: "calendar.badge.clock",
            tag: .new,
            title: "More App Store Details",
            description: "App pages can now show release and update dates, better device support, ratings, screenshots, version details, and other App Store information when available."
        ),
        ChangeItem(
            systemImage: "arrow.triangle.2.circlepath",
            tag: .new,
            title: "Editors Can Refresh App Information",
            description: "When signed in, AppleVis editors can update an app page from its App Store listing. This refreshes the title, description, App Store link, and current version without changing accessibility ratings, comments, reviews, category, price, or tested devices."
        ),
        ChangeItem(
            systemImage: "exclamationmark.triangle",
            tag: .new,
            title: "App Store Availability Notices",
            description: "If an AppleVis app entry has an App Store link that no longer works, the app page now lets you know that the listing may no longer be available."
        ),
        ChangeItem(
            systemImage: "gauge.with.needle",
            tag: .fixed,
            title: "Accessibility Ratings Are Easier to Scan",
            description: "VoiceOver, button labelling, and usability ratings on app pages now show the intended color gauge when the rating matches AppleVis's wording."
        ),
        ChangeItem(
            systemImage: "waveform.badge.plus",
            tag: .new,
            title: "Share Audio Into Podcast Submissions",
            description: "Share an MP3, M4A, or WAV file from Files or another app, choose AppleVis, and the podcast submission form opens with the audio already attached."
        ),
        ChangeItem(
            systemImage: "square.and.pencil",
            tag: .fixed,
            title: "Better Submission Forms",
            description: "Bug reports, blog posts, podcasts, and app submissions now better match what AppleVis needs, with clearer required fields and fewer surprises at the end."
        ),
        ChangeItem(
            systemImage: "hand.point.up.left",
            tag: .fixed,
            title: "Smoother VoiceOver Focus",
            description: "Many screens now move VoiceOver focus to the new page or field as soon as it opens, including Settings, Profile, Discover sections, app pages, podcasts, forums, and first-time setup."
        ),
        ChangeItem(
            systemImage: "paintbrush",
            tag: .fixed,
            title: "Theme and Text Size Polish",
            description: "More screens, banners, cards, and setup steps now follow your selected theme and text size settings."
        ),
        ChangeItem(
            systemImage: "eye.slash",
            tag: .fixed,
            title: "More Editorial Tools",
            description: "AppleVis editors can now see the right edit, unpublish, and delete actions in more places when signed in."
        ),
    ]

}

struct HistorySection: Identifiable {
    let id = UUID()
    let title: String
    let items: [ChangeItem]

    static let all: [HistorySection] = [
        HistorySection(title: "Also in 2026.0.10 - 2026.0.9", items: [
            ChangeItem(
                systemImage: "person.crop.circle",
                tag: .improved,
                title: "Cleaner For You",
                description: "For You now starts with Saved Items, then Following, Podcast Queue, and Downloads, with a simpler filter picker for saved items."
            ),
            ChangeItem(
                systemImage: "app.badge",
                tag: .new,
                title: "App Icon Badge",
                description: "AppleVis can show a badge count for new activity, based on the notification categories you have turned on."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .improved,
                title: "Redesigned App Directory",
                description: "The App Directory added platform filters, supported devices, and app pages that can use current App Store details."
            ),
            ChangeItem(
                systemImage: "slider.horizontal.3",
                tag: .improved,
                title: "Better Podcast Episode Pages",
                description: "Podcast episode pages added clearer playback controls, audio enhancements, real durations, chapters, and a Download button on episode cards."
            ),
            ChangeItem(
                systemImage: "plus.circle",
                tag: .new,
                title: "Add and Comment Buttons",
                description: "Home gained an Add button for forum topics and app entries, and detail pages gained a consistent Comment button."
            ),
            ChangeItem(
                systemImage: "dial.medium",
                tag: .new,
                title: "More VoiceOver Navigation",
                description: "New rotor options and card actions make it quicker to jump to new comments, replies to you, and podcast chapters."
            ),
            ChangeItem(
                systemImage: "icloud",
                tag: .improved,
                title: "Expanded iCloud Sync",
                description: "iCloud sync now covers more reading, podcast, saved item, and following state."
            ),
            ChangeItem(
                systemImage: "checkmark.shield",
                tag: .improved,
                title: "Safer Posting",
                description: "AppleVis now gives more guideline reminders, checks for duplicate app submissions, and can sync read status with the website when you are signed in."
            ),
            ChangeItem(
                systemImage: "wrench.and.screwdriver",
                tag: .fixed,
                title: "Reliability Fixes",
                description: "This release fixed repeated VoiceOver card actions, stale sign-in sessions, a duplicate Now Playing card, and a System theme flicker."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.8 - 2026.0.7", items: [
            ChangeItem(
                systemImage: "square.and.arrow.up",
                tag: .new,
                title: "Share Into AppleVis",
                description: "Sharing from Safari or another app can open the right AppleVis submission form with the link already filled in."
            ),
            ChangeItem(
                systemImage: "ipad.and.iphone",
                tag: .new,
                title: "Handoff",
                description: "You can pick up a topic or podcast on a nearby iPad or Mac from where you left off on iPhone."
            ),
            ChangeItem(
                systemImage: "keyboard",
                tag: .new,
                title: "iPad Keyboard Shortcuts",
                description: "Hold Command on iPad to see shortcuts for Search, Settings, Forums, Apps, Podcasts, and Resources."
            ),
            ChangeItem(
                systemImage: "sparkles",
                tag: .improved,
                title: "Smarter Apple Features",
                description: "Apple Intelligence, Siri Shortcuts, AirPlay, Spotlight, Lock Screen playback, Voice Boost, Trim Silence, artwork descriptions, and iCloud podcast sync all work more reliably."
            ),
            ChangeItem(
                systemImage: "moon",
                tag: .new,
                title: "Focus Filters",
                description: "AppleVis notification categories now appear in iOS Focus settings."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.6", items: [
            ChangeItem(
                systemImage: "envelope",
                tag: .new,
                title: "Contact App Support",
                description: "A new support wizard lets you contact the AppleVis team without leaving the app or opening Mail."
            ),
            ChangeItem(
                systemImage: "sparkles",
                tag: .new,
                title: "Apple Intelligence Tools",
                description: "Supported devices can summarize, simplify, and translate text on device."
            ),
            ChangeItem(
                systemImage: "mic",
                tag: .new,
                title: "More Siri Shortcuts",
                description: "Siri can resume your podcast, search AppleVis, or open saved items by voice."
            ),
            ChangeItem(
                systemImage: "music.note",
                tag: .improved,
                title: "Better Podcast Playback",
                description: "Podcast playback gained queue skipping, Lock Screen artwork, Control Center artwork, and clearer Dynamic Island status."
            ),
            ChangeItem(
                systemImage: "questionmark.circle",
                tag: .improved,
                title: "Updated Help and Icon",
                description: "The Help Centre was refreshed, and the app icon can adapt to your Home Screen style on supported iOS versions."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.5", items: [
            ChangeItem(
                systemImage: "ant",
                tag: .new,
                title: "Submit Bug Reports",
                description: "You can submit a bug report from inside the app with platform, OS version, title, Feedback ID, description, and recognition preference."
            ),
            ChangeItem(
                systemImage: "newspaper",
                tag: .new,
                title: "Submit Blog Posts",
                description: "You can write a blog post, import a text or Markdown file, or paste from the clipboard."
            ),
            ChangeItem(
                systemImage: "mic",
                tag: .new,
                title: "Submit Podcasts",
                description: "You can upload a podcast audio file directly from Files or iCloud Drive."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .new,
                title: "Submit App Entries",
                description: "You can submit App Directory entries with App Store search and accessibility ratings."
            ),
            ChangeItem(
                systemImage: "square.and.arrow.up",
                tag: .improved,
                title: "Smarter Share Extension",
                description: "Sharing App Store links, podcast URLs, and text files into AppleVis now opens the right wizard automatically."
            ),
            ChangeItem(
                systemImage: "speaker.wave.2",
                tag: .improved,
                title: "Help and Sounds",
                description: "The Help Centre gained guides for submission wizards, and the app sounds were refreshed."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.4 - 2026.0.3", items: [
            ChangeItem(
                systemImage: "pencil",
                tag: .new,
                title: "Edit Your Content",
                description: "You can edit and delete your own posts and comments from detail pages inside the app."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .improved,
                title: "App Pages Redesigned",
                description: "App pages added clearer accessibility ratings, developer contact, App Store links, and supported devices."
            ),
            ChangeItem(
                systemImage: "bubble.left.and.bubble.right",
                tag: .improved,
                title: "Forum Pages Redesigned",
                description: "Forum topics added category headers, reply animations, better Braille reading, author colors, and summaries."
            ),
            ChangeItem(
                systemImage: "book",
                tag: .improved,
                title: "Blog and Guide Pages Redesigned",
                description: "Blog and guide pages now better match the forum design and VoiceOver behavior."
            ),
            ChangeItem(
                systemImage: "house",
                tag: .improved,
                title: "Better Home Welcome",
                description: "The Home welcome flow was redesigned to restore focus and return you to your last-read position."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.2", items: [
            ChangeItem(
                systemImage: "speaker.wave.2",
                tag: .new,
                title: "More Sound Options",
                description: "A new alert sound was added, and all alert sounds were balanced to a more consistent volume."
            ),
            ChangeItem(
                systemImage: "house",
                tag: .improved,
                title: "Better Welcome Card",
                description: "The Welcome card shows new comment counts and can jump back to your last-read position."
            ),
            ChangeItem(
                systemImage: "eye",
                tag: .improved,
                title: "VoiceOver Detail Levels",
                description: "Simple, Normal, and All now provide clearer differences in how much detail VoiceOver reads."
            ),
            ChangeItem(
                systemImage: "bell.badge",
                tag: .new,
                title: "Follow Forum Topics",
                description: "You can follow forum topics and receive reply notifications."
            ),
            ChangeItem(
                systemImage: "text.bubble",
                tag: .improved,
                title: "More In-App Reading and Comments",
                description: "Blog posts, guides, app comments, forum threads, and redesigned detail pages work more fully inside the app."
            ),
            ChangeItem(
                systemImage: "hand.point.up.left",
                tag: .fixed,
                title: "More Reliable VoiceOver Focus",
                description: "VoiceOver focus now lands more reliably after feed loading and pull-to-refresh."
            ),
            ChangeItem(
                systemImage: "speedometer",
                tag: .fixed,
                title: "Playback Speed Fix",
                description: "Pitch correction now works correctly when changing podcast playback speed."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.1.3 - 2026.0.1.5", items: [
            ChangeItem(
                systemImage: "music.note",
                tag: .improved,
                title: "Refreshed Sounds",
                description: "The welcome tone, notification sounds, and system sounds were refreshed."
            ),
            ChangeItem(
                systemImage: "tray.full",
                tag: .improved,
                title: "Saved and Downloaded Episodes",
                description: "Saved and downloaded episodes gained Queue, Share, Mark as Played, and sorting actions."
            ),
            ChangeItem(
                systemImage: "text.alignleft",
                tag: .improved,
                title: "Better Episode Pages",
                description: "Episode pages gained cleaner About text, live links, full-screen transcripts, and artwork descriptions."
            ),
            ChangeItem(
                systemImage: "bubble.left.and.bubble.right",
                tag: .new,
                title: "Full Detail Pages",
                description: "Forum topics and episodes gained full detail screens with bottom toolbars for quick actions."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.1.1 - 2026.0.1.2", items: [
            ChangeItem(
                systemImage: "bubble.left.and.bubble.right",
                tag: .new,
                title: "Forums Inside the App",
                description: "You can read full forum threads and post replies directly inside AppleVis."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .new,
                title: "Full App Listings",
                description: "App listings now include all community comments inside the app."
            ),
            ChangeItem(
                systemImage: "book",
                tag: .new,
                title: "Full Guides and Articles",
                description: "Guides and articles can be read completely inside the app."
            ),
            ChangeItem(
                systemImage: "gearshape",
                tag: .improved,
                title: "More Settings",
                description: "Podcast, notification, theme, card size, and VoiceOver detail settings gained working controls and previews."
            ),
            ChangeItem(
                systemImage: "arrow.left",
                tag: .fixed,
                title: "Back Buttons Everywhere",
                description: "Settings, detail pages, and sub-screens now include a Back button."
            ),
            ChangeItem(
                systemImage: "hand.tap",
                tag: .new,
                title: "Magic Tap for Podcasts",
                description: "A two-finger double tap now plays and pauses podcasts."
            ),
        ]),
    ]
}
