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
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore

    init(initialSearchQuery: String? = nil) {
        _searchText = State(initialValue: initialSearchQuery ?? "")
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
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
                        SearchResultsView(results: searchResults, isSearching: isSearching)
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
        guard !query.isEmpty else { searchResults = nil; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isSearching = true
            searchResults = try? await APIClient.shared.search.query(query)
            isSearching = false
            SoundPlayer.shared.play(.searchComplete)
            showTranslateSearchPrompt = preferences.searchTranslationEnabled && IntelligenceService.isAvailable
                && IntelligenceService.detectNonEnglish(query)
        }
    }

    private func translateAndResearch() async {
        isTranslatingSearch = true
        defer { isTranslatingSearch = false }
        guard let translated = await IntelligenceService.translateSearchQuery(searchText) else { return }
        showTranslateSearchPrompt = false
        searchText = translated
        isSearching = true
        searchResults = try? await APIClient.shared.search.query(translated)
        isSearching = false
        SoundPlayer.shared.play(.searchComplete)
    }

    // MARK: - Hub grid (shown when not searching)

    private var hubGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                HubCard(title: "Forums", subtitle: "Discussion & help", systemImage: "bubble.left.and.bubble.right", color: .blue) {
                    AnyView(ForumsBrowseView())
                }
                HubCard(title: "Podcasts", subtitle: "Audio content", systemImage: "mic.fill", color: .purple) {
                    AnyView(PodcastBrowseView())
                }
                HubCard(title: "Apps", subtitle: "iOS accessibility apps", systemImage: "square.grid.2x2", color: .green) {
                    AnyView(AppBrowseView())
                }
                HubCard(title: "Guides", subtitle: "Tutorials & resources", systemImage: "book", color: .orange) {
                    AnyView(GuideBrowseView())
                }
                HubCard(title: "Blogs", subtitle: "Articles & news", systemImage: "newspaper", color: .red) {
                    AnyView(BlogBrowseView())
                }
                HubCard(title: "Bug Reports", subtitle: "Known accessibility bugs", systemImage: "ant", color: .brown) {
                    AnyView(BugBrowseView())
                }
            }
            .padding()

            contributeSection
        }
    }

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
