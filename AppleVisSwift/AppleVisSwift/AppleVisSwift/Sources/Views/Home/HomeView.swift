import SwiftUI

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
    @State private var hasAnnouncedWelcome = false

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if auth.isSignedIn {
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle")
                        }
                    } else {
                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                        }
                    }
                }
            }
            .refreshable { await vm.load() }
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

    // MARK: - Feed list

    private var feedList: some View {
        List {
            greetingCard

            if !networkMonitor.isConnected && !vm.items.isEmpty {
                OfflineBanner()
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
            }

            if !vm.newActivitySummary.isEmpty {
                Section {
                    Text(vm.newActivitySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(vm.items) { item in
                FeedRow(item: item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if vm.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .task { await vm.loadMore() }
            }
        }
        .listStyle(.plain)
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
            Image(systemName: "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Filter feed")
        }
        .onChange(of: preferences.showForums)   { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showPodcasts) { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showApps)     { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showGuides)   { _, _ in Task { await vm.load() } }
        .onChange(of: preferences.showBlogs)    { _, _ in Task { await vm.load() } }
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
