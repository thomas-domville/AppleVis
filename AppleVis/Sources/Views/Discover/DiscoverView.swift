import SwiftUI

private enum DiscoverHubDestination: Hashable {
    case apps
    case forums
    case blogs
    case guides
    case podcasts
    case bugTracker
    case rssFeeds

    var focusID: AnyHashable {
        switch self {
        case .apps: return AnyHashable("apps")
        case .forums: return AnyHashable("forums")
        case .blogs: return AnyHashable("blogs")
        case .guides: return AnyHashable("guides")
        case .podcasts: return AnyHashable("podcasts")
        case .bugTracker: return AnyHashable("bugTracker")
        case .rssFeeds: return AnyHashable("rssFeeds")
        }
    }
}

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
    @State private var lastAnnouncedMessage: String?
    @FocusState private var isSearchFieldFocused: Bool
    @AccessibilityFocusState private var focusTarget: AnyHashable?
    private static let titleFocusID = AnyHashable("discover.title")
    // Tracks whether the stack is sitting at the hub grid or has something
    // pushed (Podcasts, Apps, etc.) — a TabView never tears down a hidden
    // tab's content, so switching away mid-navigation and back doesn't pop
    // anything on its own. Without checking this, returning to the Discover
    // tab while still deep in a section forced focus onto the hub's own
    // title below, overriding whichever section's own restoreFocus was
    // trying to put focus back where it belonged. Reported directly.
    @State private var navigationPath = NavigationPath()
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @Environment(\.openURL) private var openURL

    private static let bmeAppStoreURL = URL(string: "https://apps.apple.com/us/app/be-my-eyes/id905177575")!

    init(initialSearchQuery: String? = nil) {
        _searchText = State(initialValue: initialSearchQuery ?? "")
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    NavigationLink(destination: ProfileView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("profile")) }
                        }
                    ) {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityFocused($focusTarget, equals: AnyHashable("profile"))
                    .accessibilityLabel(String(localized: "Profile and Settings"))
                    .accessibilityHint(String(localized: "Sign in, manage your account, and access app settings."))
                }
            }
            .searchable(text: $searchText, prompt: "Search AppleVis")
            .applySearchFocus($isSearchFieldFocused)
            .onChange(of: searchText) { _, newValue in runSearch(newValue) }
            .task {
                // .onChange doesn't fire for a prefilled initial value (e.g.
                // opened via the "Search AppleVis" Siri intent) — kick it off
                // manually in that case.
                if !searchText.isEmpty, searchResults == nil { runSearch(searchText) }
                // "Auto-Focus Search Field" (Settings > General) was
                // declared and shown in Settings but never actually
                // consumed anywhere — this was the only missing piece. Only
                // applies when landing here with no query already driving
                // focus/results (e.g. the Siri "Search AppleVis" intent),
                // since that path already has an obvious next action.
                if preferences.searchAutoFocusEnabled, searchText.isEmpty {
                    isSearchFieldFocused = true
                }
            }
            // TabView keeps every tab's content alive, so unlike a pushed
            // screen this view's own .task only ever runs once — switching
            // back to this tab later doesn't recreate it. Watching
            // selectedTab directly is what actually catches "the user just
            // switched to Discover," matching the announcement
            // ContentView.swift already posts on the same change, so a
            // VoiceOver user's cursor lands somewhere real instead of
            // wherever it happened to be on the previous tab. Skipped
            // while actively searching so it doesn't yank focus away
            // from typed results.
            .onChange(of: keyCommands.selectedTab) { _, newTab in
                guard newTab == 1 else {
                    // .searchFocused is a two-way binding into .searchable's
                    // own "was search active" state restoration — leaving
                    // this still true while switching away means returning
                    // to Discover later can silently re-raise the keyboard
                    // with nothing here having asked for it, even with
                    // auto-focus off. Reported directly.
                    isSearchFieldFocused = false
                    return
                }
                guard searchText.trimmingCharacters(in: .whitespaces).count < 2 else { return }
                // Only force focus to the hub title when the stack is
                // actually showing the hub — forcing it while a section is
                // still pushed underneath (switched away to another tab and
                // back without popping) yanked focus to an element that
                // wasn't even what the user was looking at, clobbering that
                // section's own restoreFocus in the process. Reported directly.
                guard navigationPath.isEmpty else { return }
                Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: Self.titleFocusID) }
            }
            .navigationDestination(for: DiscoverHubDestination.self) { destination in
                hubDestination(for: destination)
            }
            .navigationDestination(for: ForumTopic.self) { topic in
                ForumTopicDetailView(topicId: topic.id)
            }
            .navigationDestination(for: PodcastEpisode.self) { episode in
                EpisodeDetailView(episodeId: episode.id)
            }
            .navigationDestination(for: AppListing.self) { app in
                AppDetailView(appId: app.id, platform: app.platform)
            }
            // AppBrowseView (pushed above, like every other hub card, via
            // the old-style NavigationLink(destination:) in HubCard) used
            // to declare this on itself instead. A navigationDestination(for:)
            // living on a screen that was itself reached that way doesn't
            // reliably wire up on the first push — the tap silently did
            // nothing, and only the back button revealed AppCategoryView
            // had actually been pushed underneath. Every other section
            // registers its destinations up here for the same reason.
            // Reported directly: double-tapping a category (e.g. "Books")
            // in the App Directory appeared to do nothing.
            .navigationDestination(for: AppCategoryDestination.self) { dest in
                AppCategoryView(destination: dest)
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

    @ViewBuilder
    private func hubDestination(for destination: DiscoverHubDestination) -> some View {
        switch destination {
        case .apps:
            AppBrowseView()
                .onDisappear { restoreFocus(to: destination.focusID) }
        case .forums:
            ForumsBrowseView(showsPersonalFilters: false)
                .onDisappear { restoreFocus(to: destination.focusID) }
        case .blogs:
            BlogBrowseView()
                .onDisappear { restoreFocus(to: destination.focusID) }
        case .guides:
            GuideBrowseView()
                .onDisappear { restoreFocus(to: destination.focusID) }
        case .podcasts:
            PodcastBrowseView()
                .onDisappear { restoreFocus(to: destination.focusID) }
        case .bugTracker:
            BugBrowseView()
                .onDisappear { restoreFocus(to: destination.focusID) }
        case .rssFeeds:
            RSSFeedsView()
                .onDisappear { restoreFocus(to: destination.focusID) }
        }
    }

    private func restoreFocus(to focusID: AnyHashable) {
        Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: focusID) }
    }

    private func runSearch(_ query: String) {
        searchTask?.cancel()
        // Matches the old RN app's minimum: below 2 characters is too broad
        // to be a useful title-CONTAINS search and just wastes a request.
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else {
            searchResults = nil
            isSearching = false
            return
        }
        // Set synchronously, before the debounce Task even starts — this
        // previously only flipped true after the 400ms Task.sleep, so
        // during that window SearchResultsView rendered either a
        // fabricated "No Results" (nothing had actually been searched yet)
        // or stale results from the previous query with no loading cue
        // (SEARCH-01/SEARCH-08).
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            searchResults = try? await APIClient.shared.search.query(query)
            isSearching = false
            announceSearchResults()
            // Previously gated on IntelligenceService.isAvailable alone —
            // that's the narrow, Apple Intelligence hardware-gated path
            // (newer iPhones + iOS 26 only), so a non-English query on any
            // other device silently found nothing with no explanation why.
            // detectNonEnglish itself has no hardware gate; the prompt now
            // also offers to translate via the broader-reach Translation
            // framework when FoundationModels isn't available. See
            // translateAndResearch() for which path actually runs.
            showTranslateSearchPrompt = preferences.searchTranslationEnabled && IntelligenceService.detectNonEnglish(query)
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
            ? String(localized: "No results")
            : "\(total) result\(total == 1 ? "" : "s") found in \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")."
        if !results.failedCategories.isEmpty {
            message += " Some results may be missing: \(results.failedCategories.joined(separator: ", "))."
        }
        // Previously posted on every debounce settle even when byte-for-byte
        // identical to the last announcement (e.g. typing then deleting a
        // character) — an interrupting, redundant re-announcement (SEARCH-02).
        guard message != lastAnnouncedMessage else { return }
        lastAnnouncedMessage = message
        UIAccessibility.post(notification: .announcement, argument: message)

        if lastAnnouncedResultCount != total {
            SoundPlayer.shared.play(.searchComplete)
            lastAnnouncedResultCount = total
        }
    }

    private func translateAndResearch() async {
        isTranslatingSearch = true
        defer { isTranslatingSearch = false }
        // Tries the existing FoundationModels path first where the device
        // supports it (LLM-quality, handles idiomatic phrasing well), and
        // falls back to Apple's Translation framework — which reaches every
        // device back to iOS 17.4, not just newer Apple Intelligence
        // hardware — so non-English search actually works for everyone,
        // not just people with the newest iPhones.
        let translated: String?
        if IntelligenceService.isAvailable {
            translated = await IntelligenceService.translateSearchQuery(searchText)
        } else {
            translated = await TranslationCoordinator.shared.translateToEnglish(searchText)
        }
        guard let translated else {
            toast.error(String(localized: "Couldn't translate this search. Try again."))
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
                // Matches the setup wizard/Welcome Tour convention of a
                // heading announcing the screen name — the tab-switch focus
                // move introduced earlier landed on the first hub section
                // instead, which never actually says "Discover." Invisible
                // to sighted users so it doesn't duplicate the nav bar
                // title visually. Reported directly.
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityElement()
                    .accessibilityLabel("Discover")
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusTarget, equals: Self.titleFocusID)

                hubSection(title: "App Directory", subtitle: "Browse accessible apps by platform and category.", accent: .green) {
                    HubCard(title: "Apps", subtitle: "Apps by platform and category", systemImage: "square.grid.2x2", color: .green, destination: .apps, focusTarget: $focusTarget)
                }
                hubSection(title: "Community", subtitle: "Find discussions and recent posts from AppleVis members.", accent: .blue) {
                    HubCard(title: "Forums", subtitle: "Discussion & help", systemImage: "bubble.left.and.bubble.right", color: .blue, destination: .forums, focusTarget: $focusTarget)
                    HubCard(title: "Blogs", subtitle: "Articles & news", systemImage: "newspaper", color: .red, destination: .blogs, focusTarget: $focusTarget)
                }
                hubSection(title: "Learn", subtitle: "Explore guides, podcast episodes, and practical accessibility resources.", accent: .orange) {
                    HubCard(title: "Guides", subtitle: "Tutorials & resources", systemImage: "book", color: .orange, destination: .guides, focusTarget: $focusTarget)
                    HubCard(title: "Podcasts", subtitle: "Audio content", systemImage: "mic.fill", color: .purple, destination: .podcasts, focusTarget: $focusTarget)
                }
                hubSection(title: "Bug Tracker", subtitle: "Browse active accessibility bugs reported by the AppleVis community.", accent: .brown) {
                    // Card previously said "Bug Reports" — a real button,
                    // just under a different name than the section heading
                    // right above it ("Bug Tracker") and everywhere else in
                    // the app (Help, What's New, the Community Bug
                    // Program), which read as if the button itself were
                    // missing. Reported directly.
                    HubCard(title: "Bug Tracker", subtitle: "Known accessibility bugs", systemImage: "ant", color: .brown, destination: .bugTracker, focusTarget: $focusTarget)
                }
                hubSection(title: "Stay Updated", subtitle: "Subscribe to AppleVis updates or follow us on social media.", accent: .cyan) {
                    HubCard(title: "RSS Feeds", subtitle: "Copy or share feed links", systemImage: "dot.radiowaves.left.and.right", color: .cyan, destination: .rssFeeds, focusTarget: $focusTarget)
                    socialFollowLinks
                }

                friendsOfAppleVisSection
                contributeSection
            }
            .padding(.top, 12)
        }
        .background(preferences.colors.background)
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

    // MARK: - Friends of AppleVis

    private var friendsOfAppleVisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HubSectionHeader(
                title: "Friends of AppleVis",
                subtitle: "Trusted organizations and services connected with the AppleVis community.",
                accent: .teal
            )
            VStack(spacing: 0) {
                friendHeader(
                    "Be My Eyes",
                    subtitle: "Free visual assistance from volunteers, AI, and accessible services.",
                    icon: "eye"
                )
                Divider().padding(.leading)
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

    private func friendHeader(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.teal)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        // Was "\(title), Friend of AppleVis. \(subtitle)" — the section
        // header directly above already says "Friends of AppleVis", so this
        // row repeated it right back a swipe later for no reason, and
        // inconsistently with its own sibling rows (Call a Volunteer/Be My
        // AI/Service Directory), which just say "Title. Subtitle." Reported
        // directly.
        .accessibilityLabel(String(localized: "\(title). \(subtitle)"))
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
        .accessibilityLabel(String(localized: "\(title). \(subtitle)."))
        .accessibilityHint(String(localized: "Opens the Be My Eyes app."))
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

    private var socialFollowLinks: some View {
        ForEach(AppleVisSocial.platforms) { platform in
            // WebLink, not a raw openURL Button: these links honor the Web
            // Links preference instead of always forcing the external browser.
            WebLink(destination: platform.url) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: platform.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 10))

                    Text("Follow on \(platform.name)")
                        .font(.headline)
                    Text("Open AppleVis on \(platform.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Follow AppleVis on \(platform.name)"))
            .accessibilityHint(String(localized: "Double-tap to open."))
        }
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
                    .accessibilityHidden(true)
            }
            .padding()
        }
    }
}

extension View {
    /// `.searchFocused` requires iOS 18; below that, the "Auto-Focus Search
    /// Field" preference simply has no effect instead of failing to build.
    @ViewBuilder
    func applySearchFocus(_ binding: FocusState<Bool>.Binding) -> some View {
        if #available(iOS 18.0, *) {
            self.searchFocused(binding)
        } else {
            self
        }
    }
}

private struct HubCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let destination: DiscoverHubDestination
    let focusTarget: AccessibilityFocusState<AnyHashable?>.Binding

    var body: some View {
        NavigationLink(value: destination) {
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
        .accessibilityFocused(focusTarget, equals: destination.focusID)
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
                    .accessibilityAddTraits(.isHeader)
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
