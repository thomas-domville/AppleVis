import SwiftUI

struct DiscoverView: View {
    @State private var searchText = ""
    @State private var searchResults: SearchResults?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showSubmitApp = false
    @State private var showSubmitBlog = false
    @State private var showSubmitBug = false
    @State private var showSubmitPodcast = false
    @State private var showContact = false
    @State private var showTranslateSearchPrompt = false
    @State private var isTranslatingSearch = false
    @State private var lastAnnouncedResultCount: Int?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.openURL) private var openURL

    private static let bmeAppStoreURL = URL(string: "https://apps.apple.com/us/app/be-my-eyes/id905177575")!

    private struct SocialLink: Identifiable {
        let id: String
        let label: String
        let url: URL
        let systemImage: String
        var description: String { "Follow AppleVis on \(label)" }
    }

    private static let socialLinks: [SocialLink] = [
        SocialLink(id: "x", label: "X", url: URL(string: "https://x.com/AppleVis")!, systemImage: "at"),
        SocialLink(id: "facebook", label: "Facebook", url: URL(string: "https://www.facebook.com/AppleVis")!, systemImage: "person.3.fill"),
        SocialLink(id: "mastodon", label: "Mastodon", url: URL(string: "https://mastodon.online/@AppleVis")!, systemImage: "network"),
    ]

    init(initialSearchQuery: String? = nil) {
        _searchText = State(initialValue: initialSearchQuery ?? "")
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.trimmingCharacters(in: .whitespaces).count < 2 {
                    hubGrid
                } else {
                    VStack(spacing: 0) {
                        if showTranslateSearchPrompt {
                            TranslatePromptView(isProcessing: isTranslatingSearch) {
                                Task { await translateAndResearch() }
                            } onDismiss: {
                                showTranslateSearchPrompt = false
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        SearchResultsView(
                            results: searchResults, isSearching: isSearching,
                            onRetry: { runSearch(searchText) },
                            onClearSearch: { searchText = "" }
                        )
                    }
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profile and Settings")
                }
            }
            .searchable(text: $searchText, prompt: "Search AppleVis")
            .onChange(of: searchText) { _, newValue in runSearch(newValue) }
            .task {
                // .onChange doesn't fire for a prefilled initial value (e.g.
                // opened via the "Search AppleVis" Siri intent) — kick it off
                // manually in that case.
                if !searchText.isEmpty, searchResults == nil { runSearch(searchText) }
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
            .navigationDestination(for: BugReport.self) { bug in
                BugDetailView(bugId: bug.id)
            }
            .sheet(isPresented: $showSubmitApp) { SubmitAppView() }
            .sheet(isPresented: $showSubmitBlog) { SubmitBlogView() }
            .sheet(isPresented: $showSubmitBug) { SubmitBugView() }
            .sheet(isPresented: $showSubmitPodcast) { SubmitPodcastView() }
            .sheet(isPresented: $showContact) { ContactView() }
        }
    }

    private func runSearch(_ query: String) {
        searchTask?.cancel()
        // Matches the old RN app's minimum: below 2 characters is too broad
        // to be a useful title-CONTAINS search and just wastes a request.
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { searchResults = nil; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isSearching = true
            searchResults = try? await APIClient.shared.search.query(query)
            isSearching = false
            announceSearchResults()
            showTranslateSearchPrompt = preferences.searchTranslationEnabled && IntelligenceService.isAvailable
                && IntelligenceService.detectNonEnglish(query)
        }
    }

    /// Speaks a result summary once a search settles, since a VoiceOver user
    /// swiping into a silently-populated list has no way to know whether the
    /// search actually completed. Only plays the completion sound when the
    /// count changes so a slow typist isn't blipped on every debounced fetch.
    private func announceSearchResults() {
        guard let results = searchResults else { return }
        let total = results.forums.count + results.apps.count + results.guides.count
            + results.blogs.count + results.podcasts.count + results.bugs.count
        let categoryCount = [
            !results.forums.isEmpty, !results.apps.isEmpty, !results.guides.isEmpty,
            !results.blogs.isEmpty, !results.podcasts.isEmpty, !results.bugs.isEmpty,
        ].filter { $0 }.count
        var message = total == 0
            ? "No results found."
            : "\(total) result\(total == 1 ? "" : "s") found in \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")."
        if !results.failedCategories.isEmpty {
            message += " Some results may be missing: \(results.failedCategories.joined(separator: ", "))."
        }
        UIAccessibility.post(notification: .announcement, argument: message)

        if lastAnnouncedResultCount != total {
            SoundPlayer.shared.play(.searchComplete)
            lastAnnouncedResultCount = total
        }
    }

    private func translateAndResearch() async {
        isTranslatingSearch = true
        defer { isTranslatingSearch = false }
        guard let translated = await IntelligenceService.translateSearchQuery(searchText) else {
            toast.error("Couldn't translate this search. Try again.")
            return
        }
        showTranslateSearchPrompt = false
        searchText = translated
        isSearching = true
        searchResults = try? await APIClient.shared.search.query(translated)
        isSearching = false
        announceSearchResults()
    }

    // MARK: - Hub grid (shown when not searching)

    private var hubGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hubSection(title: "App Directory", subtitle: "Browse accessible apps by platform and category.", accent: .green) {
                    HubCard(title: "Apps", subtitle: "iOS accessibility apps", systemImage: "square.grid.2x2", color: .green) {
                        AnyView(AppBrowseView())
                    }
                }
                hubSection(title: "Community", subtitle: "Find discussions and recent posts from AppleVis members.", accent: .blue) {
                    HubCard(title: "Forums", subtitle: "Discussion & help", systemImage: "bubble.left.and.bubble.right", color: .blue) {
                        AnyView(ForumsBrowseView())
                    }
                    HubCard(title: "Blogs", subtitle: "Articles & news", systemImage: "newspaper", color: .red) {
                        AnyView(BlogBrowseView())
                    }
                }
                hubSection(title: "Learn", subtitle: "Explore guides, podcast episodes, and practical accessibility resources.", accent: .orange) {
                    HubCard(title: "Guides", subtitle: "Tutorials & resources", systemImage: "book", color: .orange) {
                        AnyView(GuideBrowseView())
                    }
                    HubCard(title: "Podcasts", subtitle: "Audio content", systemImage: "mic.fill", color: .purple) {
                        AnyView(PodcastBrowseView())
                    }
                }
                hubSection(title: "Bug Tracker", subtitle: "Browse active accessibility bugs reported by the AppleVis community.", accent: .brown) {
                    HubCard(title: "Bug Reports", subtitle: "Known accessibility bugs", systemImage: "ant", color: .brown) {
                        AnyView(BugBrowseView())
                    }
                }

                beMyEyesSection
                contributeSection
                connectSection
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func hubSection<Content: View>(
        title: String, subtitle: String, accent: Color, @ViewBuilder cards: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HubSectionHeader(title: title, subtitle: subtitle, accent: accent)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                cards()
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 22)
    }

    // MARK: - Be My Eyes

    private var beMyEyesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HubSectionHeader(
                title: "Be My Eyes",
                subtitle: "Free visual assistance — connect with volunteers, AI, and accessible services.",
                accent: .teal
            )
            VStack(spacing: 0) {
                externalAppRow(
                    "Call a Volunteer",
                    subtitle: "Connect instantly with a sighted volunteer via live video, 24/7 in 185 languages.",
                    icon: "person.2.fill"
                ) { openBME(URL(string: "bemyeyes://volunteer")!) }
                Divider().padding(.leading)
                externalAppRow(
                    "Be My AI",
                    subtitle: "Ask AI to describe images, read text, or answer visual questions in 36 languages.",
                    icon: "sparkles"
                ) { openBME(URL(string: "bemyeyes://ai")!) }
                Divider().padding(.leading)
                externalAppRow(
                    "Service Directory",
                    subtitle: "Reach accessible customer service at hundreds of companies and government departments.",
                    icon: "building.2"
                ) { openBME(URL(string: "bemyeyes://partner/applevis")!) }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.bottom, 22)
    }

    private func externalAppRow(_ title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.teal)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
        .accessibilityHint("Opens the Be My Eyes app.")
    }

    /// Tries the Be My Eyes deep link directly rather than pre-checking with
    /// `canOpenURL` (which silently returns false for schemes not whitelisted
    /// in Info.plist's LSApplicationQueriesSchemes) — `openURL`'s completion
    /// handler reports success/failure from the actual open attempt instead.
    private func openBME(_ url: URL) {
        openURL(url) { accepted in
            if accepted {
                UIAccessibility.post(notification: .announcement, argument: "Opening Be My Eyes.")
            } else {
                UIAccessibility.post(notification: .announcement, argument: "Be My Eyes is not installed. Opening its App Store page instead.")
                openURL(Self.bmeAppStoreURL)
            }
        }
    }

    // MARK: - Contribute

    private var contributeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contribute")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                contributeRow("Submit an App", icon: "square.grid.2x2", requiresSignIn: true) { showSubmitApp = true }
                Divider().padding(.leading)
                contributeRow("Submit a Blog Post", icon: "newspaper", requiresSignIn: true) { showSubmitBlog = true }
                Divider().padding(.leading)
                contributeRow("Submit a Bug Report", icon: "ant", requiresSignIn: true) { showSubmitBug = true }
                Divider().padding(.leading)
                contributeRow("Submit a Podcast", icon: "mic", requiresSignIn: true) { showSubmitPodcast = true }
                Divider().padding(.leading)
                contributeRow("Contact AppleVis", icon: "envelope", requiresSignIn: false) { showContact = true }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.bottom, 22)
    }

    // MARK: - Connect

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HubSectionHeader(title: "Connect", subtitle: "Follow AppleVis on social platforms.", accent: .cyan)
            HStack(spacing: 8) {
                ForEach(Self.socialLinks) { link in
                    Button {
                        openURL(link.url)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: link.systemImage)
                                .font(.title3)
                                .accessibilityHidden(true)
                            Text(link.label)
                                .font(.caption).fontWeight(.semibold)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(link.description). Opens in your browser.")
                    .accessibilityHint("Double-tap to open in your browser.")
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }

    private func contributeRow(_ title: String, icon: String, requiresSignIn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(.primary)
                Spacer()
                if requiresSignIn && !auth.isSignedIn {
                    Text("Sign In Required").font(.caption).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}

struct HubCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color, in: RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// Section intro used above each Discover hub grouping — an accent bar plus
/// title/subtitle, matching the old app's SectionIntro. Title is spoken as
/// mixed case (via the explicit label) even though it's displayed uppercase,
/// so VoiceOver doesn't spell out each capital letter.
struct HubSectionHeader: View {
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(accent)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(accent)
                    .accessibilityLabel(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
