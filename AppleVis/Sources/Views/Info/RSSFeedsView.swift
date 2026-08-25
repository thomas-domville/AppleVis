import SwiftUI

/// Verified directly against the live /feeds page — AppleVis offers 8 real
/// feeds, not just one, covering every major content type separately.
/// There's no single "RSS app" on iOS the way there's one Safari for a web
/// link, and no URL scheme every RSS reader recognizes, so each feed offers
/// Copy Link (paste into whatever reader you use) and Share (hand it
/// straight to a reader that registers as a share target) rather than just
/// opening the raw feed URL. Requested directly.
struct RSSFeedsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore

    private struct RSSFeed: Identifiable {
        let id: String
        let title: String
        let description: String
        let url: URL
    }

    private let feeds: [RSSFeed] = [
        RSSFeed(
            id: "all", title: "All New Content",
            description: "Everything posted to the AppleVis website.",
            url: URL(string: "https://www.applevis.com/feed.xml")!
        ),
        RSSFeed(
            id: "apps", title: "App Directory",
            description: "New apps posted to the App Directories.",
            url: URL(string: "https://www.applevis.com/feed/apps.xml")!
        ),
        RSSFeed(
            id: "blog", title: "Blog",
            description: "New AppleVis Blog posts.",
            url: URL(string: "https://www.applevis.com/feed/blog.xml")!
        ),
        RSSFeed(
            id: "guides", title: "Guides and Tutorials",
            description: "New Guides and Tutorials.",
            url: URL(string: "https://www.applevis.com/feed/guides.xml")!
        ),
        RSSFeed(
            id: "reviews", title: "Accessory Reviews",
            description: "New Accessory Reviews.",
            url: URL(string: "https://www.applevis.com/feed/reviews.xml")!
        ),
        RSSFeed(
            id: "forums", title: "Forum",
            description: "New posts to the AppleVis Forum.",
            url: URL(string: "https://www.applevis.com/feed/forums.xml")!
        ),
        RSSFeed(
            id: "forums-apple", title: "Forum (Apple Only)",
            description: "New Apple-related posts to the AppleVis Forum.",
            url: URL(string: "https://www.applevis.com/feed/forums-apple.xml")!
        ),
        RSSFeed(
            id: "podcasts", title: "Podcasts",
            description: "New Podcasts.",
            url: URL(string: "https://www.applevis.com/feed/podcasts")!
        ),
    ]

    var body: some View {
        Form {
            Section {
                Text("Subscribe to any of these feeds in your preferred RSS reader to get AppleVis updates automatically, without checking the app or site.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Feeds") {
                ForEach(feeds) { feed in
                    feedRow(feed)
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("RSS Feeds")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Title/description are combined into one non-interactive VoiceOver
    /// stop, but Copy Link and Share are deliberately left as their own,
    /// separately-focusable buttons rather than folded into that same
    /// combined element — `ShareLink`'s native share sheet isn't something
    /// that can be re-triggered from a custom `.accessibilityAction`
    /// closure, so combining the whole row would silently swallow it.
    private func feedRow(_ feed: RSSFeed) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(feed.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 20) {
                Button {
                    copyLink(feed)
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                ShareLink(item: feed.url, subject: Text(feed.title)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .accessibilityHint(String(localized: "Opens the share sheet with this feed's link."))
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private func copyLink(_ feed: RSSFeed) {
        UIPasteboard.general.string = feed.url.absoluteString
        toast.success(String(localized: "Link copied"))
        UIAccessibility.post(notification: .announcement, argument: "Link copied.")
    }
}
