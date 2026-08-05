import SwiftUI

/// Narrows the feed already loaded on Home to just what's new since the
/// last visit — distinct from "Customize Home," which controls which
/// content types are fetched in the first place, not which of them show.
enum HomeFeedFilter: String, CaseIterable, Identifiable {
    case all, new
    var id: String { rawValue }
    var label: String { self == .all ? "All" : "New" }
}

/// Time-of-day greeting shown on the Home tab's greeting card.
enum Greeting {
    static func text(for date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }

    static func accentColor(for date: Date = Date()) -> Color {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  return Color(red: 0.961, green: 0.620, blue: 0.043) // amber
        case 12..<17: return Color(red: 0.055, green: 0.647, blue: 0.914) // sky blue
        case 17..<22: return Color(red: 0.388, green: 0.400, blue: 0.945) // indigo
        default:      return Color(red: 0.486, green: 0.227, blue: 0.929) // purple
        }
    }
}

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @State private var hasAnnouncedWelcome = false
    @State private var homeFeedFilter: HomeFeedFilter = .all

    /// Items actually shown below the feed picker — narrowed to just what's
    /// new since the last visit when the "New" segment is selected. Distinct
    /// from the "Customize Home" menu, which controls which content TYPES
    /// are fetched at all, not which of the fetched items are shown.
    private var visibleItems: [FeedItem] {
        homeFeedFilter == .new ? vm.newItems : vm.items
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    LoadingView()
                } else if let error = vm.error, vm.items.isEmpty {
                    ErrorView(message: error) { await vm.load() }
                } else {
                    feedList
                }
            }
            .navigationTitle("Home")
            .toolbar {
                // Matches the original design: Customize Home in the
                // top-left, Profile/Settings in the top-right — not both
                // crowded onto the same side.
                ToolbarItem(placement: .navigationBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profile and Settings")
                }
            }
            .refreshable { await vm.load() }
            .onReceive(keyCommands.refreshRequested) { Task { await vm.load() } }
            .overlay(alignment: .top) { ToastOverlay() }
            .onChange(of: vm.isLoading) { _, isLoading in
                guard !isLoading else { return }
                announceWelcomeIfNeeded()
            }
            .navigationDestination(for: ForumTopic.self) { topic in
                ForumTopicDetailView(topicId: topic.id)
            }
            .navigationDestination(for: PodcastEpisode.self) { episode in
                EpisodeDetailView(episodeId: episode.id)
            }
            .navigationDestination(for: AppListing.self) { app in
                AppDetailView(appId: app.id)
            }
            .navigationDestination(for: Resource.self) { resource in
                ResourceDetailView(resourceId: resource.id)
            }
            .navigationDestination(for: BlogPost.self) { post in
                BlogDetailView(postId: post.id)
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Welcome

    private func announceWelcomeIfNeeded() {
        guard !hasAnnouncedWelcome, preferences.homeStartupBehavior != .quiet else { return }
        hasAnnouncedWelcome = true

        SoundPlayer.shared.play(.welcome)

        let baseText = vm.isReturningVisit
            ? "Welcome back to AppleVis. Returning to where you left off."
            : "Welcome to AppleVis. Home is ready."
        let welcomeText = preferences.homeStartupBehavior == .detailed && !vm.newActivitySummary.isEmpty
            ? "\(baseText) \(vm.newActivitySummary)."
            : baseText
        UIAccessibility.post(notification: .announcement, argument: welcomeText)
    }

    private var greetingCard: some View {
        let name = auth.user?.name ?? ""
        return Group {
            if !name.isEmpty {
                let today = Date().formatted(date: .complete, time: .omitted)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Greeting.text()),")
                        .font(.system(size: 20, weight: .light))
                    Text(name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text(today)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Greeting.accentColor())
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(Greeting.text()), \(name). Today is \(today).")
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
    }

    /// Forum topics new since the last Home visit — approximates the old
    /// app's per-topic "unread" tracking (ForumTopic.isUnread is hardcoded
    /// false server-side and never set; there's no real per-topic read
    /// tracking anywhere in the app), using the same last-visit comparison
    /// that already works for the What's New card.
    private var unreadForumTopics: [FeedItem] {
        vm.newItems.filter {
            if case .forumTopic = $0 { return true }
            return false
        }
    }

    // MARK: - Feed list

    private var feedList: some View {
        ScrollViewReader { proxy in
            List {
                greetingCard

                if !networkMonitor.isConnected && !vm.items.isEmpty {
                    OfflineBanner()
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                if !vm.failedSourceNames.isEmpty && !vm.items.isEmpty {
                    SourceErrorBanner(failedSources: vm.failedSourceNames) {
                        Task { await vm.load() }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if !vm.newItems.isEmpty && !vm.isNewActivityDismissed {
                    WhatsNewCard(
                        message: vm.newActivitySummary,
                        onTap: {
                            guard let first = vm.newItems.first else { return }
                            withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                        },
                        onDismiss: { vm.isNewActivityDismissed = true }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if let firstUnread = unreadForumTopics.first {
                    UnreadTopicsStrip(count: unreadForumTopics.count) {
                        withAnimation { proxy.scrollTo(firstUnread.id, anchor: .top) }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Picker("Home Feed", selection: $homeFeedFilter) {
                    ForEach(HomeFeedFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .onChange(of: homeFeedFilter) { _, filter in
                    SoundPlayer.shared.play(.pickerTick)
                    let announcement = filter == .new
                        ? "\(vm.newItems.count) new activity item\(vm.newItems.count == 1 ? "" : "s")."
                        : "Showing all Home activity."
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }

                if homeFeedFilter == .new && visibleItems.isEmpty {
                    Text("No new activity since your last visit.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }

                ForEach(visibleItems) { item in
                    FeedRow(item: item)
                        .id(item.id)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if vm.hasMore && homeFeedFilter == .all {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .task { await vm.loadMore() }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Filter menu

    private var filterMenu: some View {
        Menu {
            Section("Content Types") {
                Toggle("Forums", isOn: $preferences.showForums)
                Toggle("Podcasts", isOn: $preferences.showPodcasts)
                Toggle("Apps", isOn: $preferences.showApps)
                Toggle("Guides", isOn: $preferences.showGuides)
                Toggle("Blogs", isOn: $preferences.showBlogs)
            }
            Section("Forums") {
                Toggle("Apple Topics Only", isOn: $preferences.appleOnlyForums)
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .accessibilityLabel("Customize Home")
                .accessibilityHint("Choose what content types appear on your Home screen")
        }
        .onChange(of: preferences.showForums)   { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showPodcasts) { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showApps)     { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showGuides)   { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showBlogs)    { _, _ in Task { await vm.load() } }
    }
}

// MARK: - Source error banner

/// Shown when some (not all) of Home's sources failed to load — the rest of
/// the feed is still real, successfully-loaded data, not stale placeholder
/// content, so this stays a small dismissable-feeling banner rather than a
/// full-screen error.
private struct SourceErrorBanner: View {
    let failedSources: [String]
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Some sources could not be loaded: \(failedSources.joined(separator: ", ")).")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Retry Now", action: onRetry)
                .font(.footnote).fontWeight(.semibold)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Some sources could not be loaded: \(failedSources.joined(separator: ", ")).")
    }
}

// MARK: - What's New card

/// Dismissible, tappable "since last visit" summary — tapping scrolls to
/// the first new item, matching the old app's welcomeSummary card. Dismissal
/// isn't persisted across launches: it resets whenever a fresh load() finds
/// a new batch of newer-than-last-visit items, since the set of "what's new"
/// is itself different each time.
private struct WhatsNewCard: View {
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("What's New")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("What's New. \(message)")
            .accessibilityHint("Double-tap to jump to where you left off in the feed.")

            Button("Dismiss", action: onDismiss)
                .font(.caption).fontWeight(.semibold)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Dismiss welcome summary")
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

// MARK: - Unread topics strip

private struct UnreadTopicsStrip: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("\(count) unread topic\(count == 1 ? "" : "s")")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("Jump to first →")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) unread topic\(count == 1 ? "" : "s"). Activate to jump to first unread.")
    }
}

// MARK: - Feed row

struct FeedRow: View {
    let item: FeedItem

    var body: some View {
        Group {
            switch item {
            case .forumTopic(let t):     ForumTopicRow(topic: t)
            case .podcastEpisode(let e): PodcastEpisodeRow(episode: e)
            case .appListing(let a):     AppListingRow(app: a)
            case .resource(let r):       ResourceRow(resource: r)
            case .blogPost(let b):       BlogPostRow(post: b)
            }
        }
        .unreadIndicator(item.isUnread)
    }
}
