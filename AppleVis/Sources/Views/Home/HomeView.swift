import SwiftUI

/// Narrows the feed already loaded on Home to just what's new since the
/// last visit — distinct from "Customize Home," which controls which
/// content types are fetched in the first place, not which of them show.
enum HomeFeedFilter: String, CaseIterable, Identifiable {
    case all, new, mouseRecap
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .new: return "New"
        case .mouseRecap: return "Mouse Recap"
        }
    }
}

/// How far back Mouse Recap looks — a client-side scope over the same
/// always-30-day fetch/cache (`HomeViewModel.mouseRecapMaxDays`), not a
/// separate fetch per window; see `MouseRecapDigest.scoped(toLastDays:)`.
/// Defaults to the narrower 7-day option so a new user isn't handed a
/// month of backlog to skim through on first look.
enum MouseRecapWindow: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    var id: Int { rawValue }
    var label: String { self == .week ? String(localized: "Past Week") : String(localized: "Past Month") }
}

/// Where VoiceOver focus should land once Home finishes its initial load —
/// docs/IMPLEMENTATION_NOTES.md: "VoiceOver focus should land on the
/// summary before the first feed card." Falls back to the greeting when
/// there's no What's New card to land on.
enum HomeFocusTarget: Hashable {
    case summary
    case greeting
    case item(String)
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
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @ObservedObject private var networkStatus = NetworkStatusStore.shared
    @State private var hasAnnouncedWelcome = false
    /// Set by `announceWelcomeIfNeeded()` when there's no new activity to
    /// summarize but there is a last-visited item to resume — read inside
    /// `feedList`'s own `ScrollViewReader`, since `proxy` isn't reachable
    /// from `announceWelcomeIfNeeded()` itself (it's local to that closure).
    @State private var pendingResumeFocusItemId: String?
    @State private var hasCheckedAnniversary = false
    @State private var showAnniversary = false
    @State private var anniversaryYears = 0
    @State private var showCustomizeHome = false
    // @AppStorage, not @State — plain @State reset to .all on every fresh
    // launch (TabView already keeps it alive across tab switches within a
    // session; the actual gap was surviving a full relaunch). Reported
    // directly: selecting "New" and relaunching the app always landed back
    // on "All" instead of remembering the choice.
    @AppStorage("home.feedFilter") private var homeFeedFilter: HomeFeedFilter = .all
    // Shared key with MouseRecapView's own @AppStorage below — both read and
    // write "home.mouseRecapWindow" so picking a window on the full recap
    // screen is reflected back in the compact Home card too, without having
    // to thread the value down as a binding.
    @AppStorage("home.mouseRecapWindow") private var mouseRecapWindow: MouseRecapWindow = .week
    @State private var notificationHistory: [NotificationHistoryItem] = []
    @State private var showComposeTopic = false
    @State private var showSubmitApp = false
    @AccessibilityFocusState private var focusTarget: HomeFocusTarget?
    @Environment(\.scenePhase) private var scenePhase
    /// How long Home's feed can sit unrefreshed before returning to the
    /// foreground triggers a reload — briefly switching to another app and
    /// back (checking a text, glancing at a notification) shouldn't refetch
    /// every time; actually leaving the app for a while should. 5 minutes is
    /// a reasonable starting point, not a value with strong justification
    /// behind it.
    private static let staleThreshold: TimeInterval = 5 * 60

    /// Items actually shown below the feed picker — narrowed to just what's
    /// new since the last visit when the "New" segment is selected. Distinct
    /// from the "Customize Home" menu, which controls which content TYPES
    /// are fetched at all, not which of the fetched items are shown.
    private var visibleItems: [FeedItem] {
        switch homeFeedFilter {
        case .all:
            return vm.items
        case .new:
            return vm.newItems
        case .mouseRecap:
            return []
        }
    }

    /// O(1) lookup used by feedList to mark rows new — built once per body
    /// evaluation rather than having every row call `vm.newItems.contains`.
    private var newItemIds: Set<String> {
        Set(vm.newItems.map(\.id))
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
                    Button {
                        showCustomizeHome = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(String(localized: "Customize Home"))
                    .accessibilityHint(String(localized: "Choose what content types appear on your Home screen"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // New Topic and New App Entry are immediate, user-
                        // authored content (same as everything else Home
                        // shows) — unlike Blog/Podcast/Bug submissions,
                        // which go through editorial review before
                        // publishing under AppleVis, not the user, so those
                        // stay exclusively in Discover's Contribute section
                        // rather than living here too. Reuses the same
                        // ComposeTopicView/SubmitAppView Forums and Discover
                        // already have — this is just a second, faster way
                        // in from the tab a user actually lands on.
                        //
                        // Shown to everyone, signed in or not — matches
                        // Discover's Contribute section, which shows its
                        // Submit rows to every user with a "Sign In
                        // Required" label rather than hiding them, and
                        // lets the destination screen prompt for sign-in
                        // instead. A hidden button here would mean a
                        // signed-out (and especially a VoiceOver) user has
                        // no way to discover this exists at all. Both
                        // ComposeTopicView and SubmitAppView already show
                        // their own sign-in prompt when opened signed-out.
                        Menu {
                            Button {
                                showComposeTopic = true
                            } label: {
                                Label("New Topic", systemImage: "text.bubble")
                            }
                            Button {
                                showSubmitApp = true
                            } label: {
                                Label("New App Entry", systemImage: "square.grid.2x2")
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .accessibilityLabel(String(localized: "Add"))
                        .accessibilityHint(auth.isSignedIn
                            ? String(localized: "Create a new forum topic or app entry")
                            : String(localized: "Sign in required to create a new forum topic or app entry"))
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle")
                        }
                        .accessibilityLabel(String(localized: "Profile and Settings"))
                        .accessibilityHint(String(localized: "Sign in, manage your account, and access app settings."))
                    }
                }
            }
            .refreshable {
                // announceWelcomeIfNeeded() only ever fires once per
                // session (see hasAnnouncedWelcome), so a manual
                // pull-to-refresh otherwise gets nothing but a non-speech
                // chime — a VoiceOver user has no way to tell the refresh
                // even happened, let alone whether it found anything.
                // Reported directly: users couldn't tell a refresh that
                // found nothing new from one that silently failed.
                let previousLoadedAt = vm.lastLoadedAt
                await vm.load()
                await vm.loadMouseRecap(force: true)
                notificationHistory = PersistenceStore.shared.notificationHistory()
                SoundPlayer.shared.play(.refresh)

                // lastLoadedAt only advances on a genuinely successful
                // load (see HomeViewModel.load()), so an unchanged value
                // here means the refresh failed outright — the
                // OfflineBanner/SourceErrorBanner already covers that
                // case, and announcing "no new activity" over a failure
                // would be actively misleading.
                guard vm.lastLoadedAt != previousLoadedAt else { return }

                // Deliberately not gated on homeStartupBehavior == .quiet
                // like announceWelcomeIfNeeded() — that preference is
                // about suppressing the unsolicited on-launch greeting,
                // not about withholding feedback from an action the user
                // just explicitly took.
                if !vm.newItems.isEmpty && !vm.isNewActivityDismissed {
                    UIAccessibility.post(notification: .announcement, argument: vm.newActivitySummary)
                    // Welcome Summary being off hides the card this would
                    // otherwise focus (see feedList below) — the spoken
                    // announcement above still always fires for an
                    // explicit user action like this, only the focus
                    // target changes to something that actually exists.
                    let focusAfterRefresh: HomeFocusTarget = preferences.welcomeSummaryEnabled ? .summary : .greeting
                    Task { await retryAccessibilityFocus(focusAfterRefresh, into: $focusTarget) }
                } else {
                    UIAccessibility.post(notification: .announcement, argument: String(localized: "No new activity since your last visit."))
                }
            }
            .onReceive(keyCommands.refreshRequested) { Task { await vm.load() } }
            // Returning to the foreground while on some other tab
            // deliberately does nothing here — refreshing a list the user
            // isn't even looking at isn't worth the data/battery cost, and
            // they'll get a normal load next time they actually switch to
            // Home. Reported directly: nothing refreshed Home at all before
            // this, no matter how long the app sat backgrounded.
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, keyCommands.selectedTab == 0 else { return }
                let isStale = vm.lastLoadedAt.map { Date().timeIntervalSince($0) > Self.staleThreshold } ?? true
                guard isStale else { return }
                Task { await vm.load() }
            }
            .overlay(alignment: .top) { ToastOverlay() }
            .sheet(isPresented: $showCustomizeHome, onDismiss: {
                Task {
                    await vm.load()
                    await vm.loadMouseRecap(force: true)
                }
            }) {
                CustomizeHomeView()
            }
            .sheet(isPresented: $showComposeTopic, onDismiss: { Task { await vm.load() } }) {
                ComposeTopicView()
            }
            .sheet(isPresented: $showSubmitApp, onDismiss: { Task { await vm.load() } }) {
                SubmitAppView()
            }
            .sheet(isPresented: $showAnniversary) {
                AnniversaryCelebrationView(years: anniversaryYears) {
                    showAnniversary = false
                }
            }
            .onChange(of: vm.isLoading) { _, isLoading in
                guard !isLoading else { return }
                announceWelcomeIfNeeded()
                Task { await checkAnniversary() }
            }
            .onChange(of: deepLinkRouter.pendingSpeakWhatsNew) { _, shouldSpeak in
                guard shouldSpeak else { return }
                deepLinkRouter.pendingSpeakWhatsNew = false
                Task { await speakWhatsNewForSiri() }
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
            .navigationDestination(for: Resource.self) { resource in
                ResourceDetailView(resourceId: resource.id)
            }
            .navigationDestination(for: BlogPost.self) { post in
                BlogDetailView(postId: post.id)
            }
        }
        .task {
            await vm.load()
            await vm.loadMouseRecap()
        }
        .onAppear {
            notificationHistory = PersistenceStore.shared.notificationHistory()
        }
    }

    // MARK: - Welcome

    private func announceWelcomeIfNeeded() {
        guard !hasAnnouncedWelcome, preferences.homeStartupBehavior != .quiet else { return }
        hasAnnouncedWelcome = true

        SoundPlayer.shared.play(.welcome)

        let baseText = vm.isReturningVisit
            ? "Welcome back to AppleVis. Returning to where you left off."
            : "Welcome to AppleVis. Home is ready."

        if preferences.homeStartupBehavior == .detailed && !vm.newActivitySummary.isEmpty {
            // IntelligenceService.generateDigest existed but was never
            // called anywhere — "Detailed" mode just concatenated the raw
            // newActivitySummary string instead of the friendlier
            // AI-generated digest it was built for. Falls back to the raw
            // summary (the previous behavior) if AI is unavailable or fails,
            // so this can't regress into silence the way other Intelligence
            // call sites did.
            let rawSummary = vm.newActivitySummary
            Task {
                let digest = await IntelligenceService.generateDigest(rawSummary)
                UIAccessibility.post(notification: .announcement, argument: "\(baseText) \(digest ?? rawSummary).")
            }
        } else {
            UIAccessibility.post(notification: .announcement, argument: baseText)
        }

        // Land VoiceOver focus on the summary (or, failing that, the last
        // item you actually visited, so you can pick up where you left off
        // instead of always restarting at the greeting) rather than leaving
        // it wherever it was before navigation/launch — a short delay
        // because setting focus before the List has actually laid out the
        // new content is a common way for it to silently fail. The greeting
        // card now always renders (signed-in or not — see
        // `greetingHeadline`), so this no longer needs a signed-out special
        // case that fell through to no focus move at all. Requested
        // directly.
        if !vm.newItems.isEmpty && !vm.isNewActivityDismissed && preferences.welcomeSummaryEnabled {
            Task { await retryAccessibilityFocus(.summary, into: $focusTarget) }
        } else if let lastId = vm.lastVisitedItemId, homeFeedFilter == .all {
            // Needs an actual scroll, not just a focus request — the row may
            // not be laid out (or even instantiated, in a lazy List) yet.
            // Handled by feedList's own ScrollViewReader, which has `proxy`
            // in scope; this method doesn't.
            pendingResumeFocusItemId = lastId
        } else {
            Task { await retryAccessibilityFocus(.greeting, into: $focusTarget) }
        }
    }

    /// Answers the "What's New on AppleVis" Siri shortcut, once Home has
    /// actually finished loading — a cold launch triggered by Siri lands
    /// here before `vm.load()` has necessarily finished, so this can't just
    /// read `newActivitySummary` immediately the way `announceWelcomeIfNeeded`
    /// does (that one is only ever called from `.onChange(of: vm.isLoading)`
    /// once loading is already known to be done). Not gated on Home Startup
    /// Behavior/Welcome Summary — those govern *unprompted* speech on
    /// opening Home; this is a direct answer to something the user asked
    /// Siri for, so it always speaks.
    private func speakWhatsNewForSiri() async {
        var waited = 0
        while vm.isLoading, waited < 4000 {
            try? await Task.sleep(for: .milliseconds(200))
            waited += 200
        }
        guard !vm.newActivitySummary.isEmpty else {
            UIAccessibility.post(notification: .announcement, argument: "You're all caught up — nothing new since your last visit.")
            return
        }
        let rawSummary = vm.newActivitySummary
        let digest = await IntelligenceService.generateDigest(rawSummary)
        UIAccessibility.post(notification: .announcement, argument: digest ?? rawSummary)
    }

    /// Once per session, same as the welcome announcement above — and
    /// gated on the same "quiet" preference, since a full celebratory sheet
    /// is an even bigger interruption than a spoken announcement for anyone
    /// who's opted out of proactive Home greetings.
    private func checkAnniversary() async {
        guard !hasCheckedAnniversary, preferences.homeStartupBehavior != .quiet, let user = auth.user else { return }
        hasCheckedAnniversary = true
        guard let years = await AccountAnniversary.checkAndConsume(for: user) else { return }
        anniversaryYears = years
        showAnniversary = true
    }

    /// Signed-in users get their name; signed-out visitors previously got
    /// nothing at all here (the card just didn't render) — now they get the
    /// same warm two-line treatment, distinguishing a first-ever visit from
    /// a returning one via `vm.isReturningVisit` (the same device-level
    /// "has Home ever loaded before" flag the spoken welcome announcement
    /// below already uses) instead of leaving the space blank.
    private var greetingHeadline: String {
        let name = auth.user?.name ?? ""
        if !name.isEmpty { return name }
        return vm.isReturningVisit ? "Welcome back" : "Welcome to AppleVis"
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Greeting.text()),")
                // CARD-11: fixed-point sizes didn't respond to the
                // system Dynamic Type setting at all — a user who'd
                // turned on a larger text size everywhere else in
                // iOS still got this card frozen at 20pt/26pt.
                .font(.title3.weight(.light))
            Text(greetingHeadline)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Greeting.accentColor())
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(Greeting.text()), \(greetingHeadline)."))
        .accessibilityFocused($focusTarget, equals: .greeting)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
    }

    /// Forum topics new since the last Home visit — approximates the old
    /// app's per-topic "unread" tracking (ForumTopic.isUnread is hardcoded
    /// false server-side and never set; there's no real per-topic read
    /// tracking anywhere in the app), using the same last-visit comparison
    /// that already works for the What's New card.
    /// True when at least one of Home's active sources is currently being
    /// served from cache because its live fetch is failing (see
    /// NetworkStatusStore/CachedFetch.swift) — shown with the same
    /// OfflineBanner a true connectivity loss uses, since "pull to refresh
    /// when things are working again" is the right guidance either way.
    private var isAnySourceDegraded: Bool {
        var groups: Set<ContentGroup> = []
        if preferences.showForums { groups.insert(.forums) }
        if preferences.showPodcasts { groups.insert(.podcasts) }
        if preferences.showApps { groups.insert(.apps) }
        if preferences.showGuides { groups.insert(.resources) }
        if preferences.showBlogs { groups.insert(.blogs) }
        return !groups.isDisjoint(with: networkStatus.degradedGroups)
    }

    // MARK: - Feed list

    private var feedList: some View {
        ScrollViewReader { proxy in
            List {
                greetingCard

                if !notificationHistory.isEmpty {
                    NavigationLink(destination: NotificationHistoryView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                            Text("Notifications")
                                .font(.subheadline).fontWeight(.semibold)
                            Spacer()
                            Text("\(notificationHistory.count)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel(String(localized: "Notifications, \(notificationHistory.count) recent"))
                    .accessibilityHint(String(localized: "Double-tap to view your recent notifications."))
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if (!networkMonitor.isConnected || isAnySourceDegraded) && !vm.items.isEmpty {
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

                // Previously always shown whenever there was new activity,
                // with no way to turn it off — welcomeSummaryEnabled was
                // declared as a real setting and wired up in Settings, but
                // nothing anywhere actually read it. Reported directly.
                // Home Startup Behavior (spoken welcome) and this (visual
                // summary card) are deliberately independent: you can want
                // one without the other.
                if !vm.newItems.isEmpty && !vm.isNewActivityDismissed && preferences.welcomeSummaryEnabled {
                    WhatsNewCard(
                        message: vm.newActivitySummary,
                        onTap: {
                            guard let first = vm.newItems.first else { return }
                            withReduceMotionAwareAnimation { proxy.scrollTo(first.id, anchor: .top) }
                            // Scrolling the viewport doesn't move VoiceOver's
                            // focus on its own — without this, double-tapping
                            // moved the card visually but left a VoiceOver
                            // user's swipe cursor exactly where it was,
                            // making the action look like it did nothing.
                            //
                            // Reported directly: a single fixed delay looked
                            // like it silently "forgot" where the user left
                            // off on a slower device — see
                            // retryAccessibilityFocus's doc comment (CARD-12).
                            Task {
                                await retryAccessibilityFocus(.item(first.id), into: $focusTarget, delaysMs: [150, 350, 600, 900])
                            }
                        },
                        onDismiss: { vm.isNewActivityDismissed = true }
                    )
                    .accessibilityFocused($focusTarget, equals: .summary)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Picker("Home Feed", selection: $homeFeedFilter) {
                    ForEach(HomeFeedFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                // Explicit value — without it, swiping up/down only played
                // the "value changed" tone with no spoken filter name. Same
                // fix as PlayerView's playback-speed control (PODCAST-06).
                // Reported directly.
                .accessibilityValue(Text(homeFeedFilter.label))
                // Same swipe-up/down addition as the App Directory/For You
                // pickers — moves to the next/previous segment in place.
                .accessibilityAdjustableAction { direction in
                    guard let idx = HomeFeedFilter.allCases.firstIndex(of: homeFeedFilter) else { return }
                    switch direction {
                    case .increment:
                        homeFeedFilter = HomeFeedFilter.allCases[(idx + 1) % HomeFeedFilter.allCases.count]
                    case .decrement:
                        homeFeedFilter = HomeFeedFilter.allCases[(idx - 1 + HomeFeedFilter.allCases.count) % HomeFeedFilter.allCases.count]
                    @unknown default: break
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .onChange(of: homeFeedFilter) { _, filter in
                    SoundPlayer.shared.play(.pickerTick)
                    let announcement: String
                    switch filter {
                    case .all:
                        announcement = "Showing all Home activity."
                    case .new:
                        announcement = "\(vm.newItems.count) new activity item\(vm.newItems.count == 1 ? "" : "s")."
                    case .mouseRecap:
                        announcement = "Showing Mouse Recap."
                    }
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }

                if homeFeedFilter == .mouseRecap {
                    MouseRecapHomeContent(vm: vm, window: $mouseRecapWindow)
                } else if homeFeedFilter == .new && visibleItems.isEmpty {
                    Text("No new activity since your last visit.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }

                if !visibleItems.isEmpty {
                    HStack {
                        Text(homeFeedFilter == .new ? "New Activity" : "Latest Activity")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .accessibilityAddTraits(.isHeader)
                            // .textCase(.uppercase) only transforms the visual
                            // glyphs — on some iOS/VoiceOver versions an
                            // all-caps-rendered string gets spelled out
                            // letter-by-letter instead of read as a word.
                            // An explicit label bypasses the transformed text.
                            .accessibilityLabel(homeFeedFilter == .new ? "New Activity" : "Latest Activity")
                            .accessibilityAction(named: Text("Feed summary")) {
                                UIAccessibility.post(notification: .announcement, argument: feedSummary)
                            }
                        Spacer()
                        if homeFeedFilter == .new {
                            Button("Mark All Read") {
                                vm.markAllAsRead(visibleItems)
                            }
                            .font(.caption.weight(.bold))
                            .accessibilityLabel(String(localized: "Mark all new activity as read"))
                            .accessibilityHint(String(localized: "Clears all items from the New view."))
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                ForEach(visibleItems) { item in
                    FeedRow(item: item, newCount: vm.newReplyCount(for: item), isNew: newItemIds.contains(item.id)) {
                        vm.markAsRead(item)
                    }
                    .id(item.id)
                    .accessibilityFocused($focusTarget, equals: .item(item.id))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if vm.hasMore && homeFeedFilter == .all {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .task { await vm.loadMore() }
                } else if !vm.hasMore && homeFeedFilter == .all && !visibleItems.isEmpty {
                    Text("You've reached the end.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .themedList(preferences.colors)
            // "New Items" mirrors the per-screen "New Comments" rotors on
            // detail pages — reuses the same vm.newItems already driving
            // the New/All picker and the "N new activity items" banner, so
            // it's just a different way to move through the same set.
            .accessibilityRotor("New Items") {
                // Previously just the bare title — gave no way to tell a
                // brand-new item from one with a handful of new replies
                // without leaving the rotor to check. Mirrors the same
                // newCount-vs-isNew split each card's own label already
                // uses. Reported directly.
                ForEach(vm.newItems) { item in
                    let newCount = vm.newReplyCount(for: item)
                    let label = newCount > 0
                        ? "\(item.title), \(newCount) new comment\(newCount == 1 ? "" : "s")"
                        : "\(item.title), new"
                    AccessibilityRotorEntry(label, id: item.id)
                }
            }
            // Home is the one place in the app that genuinely interleaves
            // every content kind into a single flat list with no section
            // headers to jump via the built-in Headings rotor (unlike
            // Search Results, which is already grouped) — these five let
            // someone narrow to just one kind for this scan without
            // permanently hiding the others via Customize Home. Scoped to
            // `visibleItems`, not the full feed, so a rotor built while
            // the New filter is active only offers what's actually
            // on screen.
            .accessibilityRotor("Forum Topics") { kindRotorContent(.forumTopic) }
            .accessibilityRotor("Podcast Episodes") { kindRotorContent(.podcastEpisode) }
            .accessibilityRotor("App Entries") { kindRotorContent(.appListing) }
            .accessibilityRotor("Guides") { kindRotorContent(.resource) }
            .accessibilityRotor("Blog Posts") { kindRotorContent(.blogPost) }
            // "Pick up where you left off" — set by announceWelcomeIfNeeded()
            // when there's no new activity to summarize but there is a
            // last-visited item. That method can't reach `proxy` itself (it's
            // local to this closure), so it hands off via this state var
            // instead. Same scroll-then-retry-focus combo as WhatsNewCard's
            // onTap just above, and the same reasoning: scrolling alone
            // doesn't move VoiceOver's cursor, and a single fixed delay isn't
            // reliable before the target row has actually laid out.
            .onChange(of: pendingResumeFocusItemId) { _, id in
                guard let id else { return }
                pendingResumeFocusItemId = nil
                withReduceMotionAwareAnimation { proxy.scrollTo(id, anchor: .top) }
                Task {
                    await retryAccessibilityFocus(.item(id), into: $focusTarget, delaysMs: [150, 350, 600, 900])
                }
            }
        }
    }

    @AccessibilityRotorContentBuilder
    private func kindRotorContent(_ kind: ContentKind) -> some AccessibilityRotorContent {
        ForEach(visibleItems.filter { $0.kind == kind }) { item in
            AccessibilityRotorEntry(item.title, id: item.id)
        }
    }

    /// Backs the "Feed summary" custom accessibility action on the section
    /// heading — lets a VoiceOver user hear a breakdown by content type on
    /// demand instead of having to swipe through every row to gauge it.
    private var feedSummary: String {
        guard !visibleItems.isEmpty else { return "Feed is empty." }
        var counts: [ContentKind: Int] = [:]
        for item in visibleItems { counts[item.kind, default: 0] += 1 }
        let parts = [ContentKind.forumTopic, .podcastEpisode, .appListing, .resource, .blogPost].compactMap { kind -> String? in
            guard let n = counts[kind], n > 0 else { return nil }
            return "\(n) \(kind.displayNamePlural(n))"
        }
        return "\(visibleItems.count) item\(visibleItems.count == 1 ? "" : "s"): \(parts.joined(separator: ", "))."
    }
}

// MARK: - Customize Home

/// A real screen instead of a Menu with Toggle rows — Menu+Toggle has a
/// known VoiceOver quirk on this SDK where double-tapping a Toggle inside a
/// Menu dismisses the whole menu (a sighted tap keeps it open), so a
/// VoiceOver user could never toggle more than one content type per visit
/// without reopening it each time. This also fixes the "reloads once per
/// toggle" issue: Home now only reloads once, when this sheet is dismissed,
/// via HomeView's `.sheet(isPresented:onDismiss:)`.
struct CustomizeHomeView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Content Types") {
                    Toggle("Forums", isOn: $preferences.showForums)
                    Toggle("Podcasts", isOn: $preferences.showPodcasts)
                    Toggle("Apps", isOn: $preferences.showApps)
                    Toggle("Guides", isOn: $preferences.showGuides)
                    Toggle("Blogs", isOn: $preferences.showBlogs)
                }
                Section("Forums") {
                    Toggle("Apple Topics Only", isOn: $preferences.appleOnlyForums)
                        .accessibilityHint(String(localized: "Hides non-Apple forum categories from Home."))
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Customize Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mouse Recap

private struct MouseRecapHomeContent: View {
    @ObservedObject var vm: HomeViewModel
    @Binding var window: MouseRecapWindow
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var aiBlurbs: [String: String] = [:]
    @State private var aiWindow: MouseRecapWindow?

    var body: some View {
        Group {
            if vm.isLoadingMouseRecap && vm.mouseRecap == nil {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Building Mouse Recap...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowSeparator(.hidden)
            } else if let error = vm.mouseRecapError, vm.mouseRecap == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mouse Recap", systemImage: "sparkles")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(preferences.colors.warning)
                    Button("Retry Now") {
                        Task { await vm.loadMouseRecap(force: true) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .listRowSeparator(.hidden)
            } else if let digest = vm.mouseRecap?.scoped(toLastDays: window.rawValue) {
                newsletterContent(digest)

                if !vm.failedMouseRecapSourceNames.isEmpty {
                    Section {
                        SourceErrorBanner(failedSources: vm.failedMouseRecapSourceNames) {
                            Task { await vm.loadMouseRecap(force: true) }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            } else {
                Text("Pull to refresh your recap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func newsletterContent(_ digest: MouseRecapDigest) -> some View {
        let limits = MouseRecapDigest.limits(for: window.label)
        let apps = Array(digest.apps.prefix(limits.apps))
        let podcasts = Array(digest.podcasts.prefix(limits.podcasts))
        let blogs = Array(digest.standardBlogs.prefix(limits.blogs))
        let resources = Array(digest.resources.prefix(limits.resources))
        let forums = Array(digest.forums.prefix(limits.forums))

        Section {
            Picker("Recap Window", selection: $window) {
                ForEach(MouseRecapWindow.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(String(localized: "Recap window"))
            .accessibilityHint(String(localized: "Choose how far back Mouse Recap looks."))
            // Explicit value — without it, swiping up/down only played the
            // "value changed" tone with no spoken window name. Same fix as
            // PlayerView's playback-speed control (PODCAST-06). Reported directly.
            .accessibilityValue(Text(window.label))
            // Same swipe-up/down addition as the other pickers in this
            // session's pass — moves between Past Week/Past Month in place.
            .accessibilityAdjustableAction { direction in
                guard let idx = MouseRecapWindow.allCases.firstIndex(of: window) else { return }
                switch direction {
                case .increment:
                    window = MouseRecapWindow.allCases[(idx + 1) % MouseRecapWindow.allCases.count]
                case .decrement:
                    window = MouseRecapWindow.allCases[(idx - 1 + MouseRecapWindow.allCases.count) % MouseRecapWindow.allCases.count]
                @unknown default: break
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Mouse Recap")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text(window.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(digest.dateRangeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .listRowSeparator(.hidden)
        .task(id: "\(window.rawValue)-\(digest.generatedAt.timeIntervalSince1970)") {
            await generateAIBlurbs(for: digest)
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("From the Mouse", systemImage: "sparkles")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(digest.newsletterIntro(for: window.label))
                    .font(.body)
                if digest.isEmpty {
                    Text(window == .week ? "Pull to refresh later, or try Past Month for a wider look." : "Pull to refresh later for a fresh look.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .newsletterPanel(accent: Color.accentColor, colors: preferences.colors)

            ShareLink(item: digest.shareText(for: window.label, aiBlurbs: aiBlurbs), subject: Text("Mouse Recap")) {
                Label("Share Mouse Recap", systemImage: "square.and.arrow.up")
            }
        }
        .listRowSeparator(.hidden)

        if let spotlight = digest.appPickSpotlight {
            Section {
                TranslatedMouseRecapTitle(kind: "blogPost", id: spotlight.id, title: spotlight.title) { resolvedTitle, wasTranslated in
                    newsletterCard(
                        title: resolvedTitle,
                        kicker: "AnonyMouse's App Pick of the Month",
                        details: digest.blogDetails(spotlight),
                        body: aiBlurbs[spotlight.id] ?? digest.newsletterBody(for: spotlight),
                        accent: ContentKind.blogPost.accentColor,
                        wasTranslated: wasTranslated
                    ) {
                        NavigationLink(value: spotlight) {
                            Label("Read Spotlight", systemImage: "arrow.right.circle")
                        }
                    }
                }
            } header: {
                Label("Spotlight Feature", systemImage: "star.fill")
                    .accessibilityAddTraits(.isHeader)
            }
            .listRowSeparator(.hidden)
        }

        newsletterSection(
            title: String(localized: "New Accessible Apps"),
            systemImage: "square.grid.2x2",
            intro: digest.appSectionIntro(periodName: window.label),
            kicker: String(localized: "New on the App Scene"),
            limitedMessage: limitedMessage(total: digest.apps.count, shown: apps.count, noun: "app"),
            items: apps
        ) { app in
            TranslatedMouseRecapTitle(kind: "appListing", id: app.id, title: app.name) { resolvedTitle, wasTranslated in
                newsletterCard(
                    title: resolvedTitle,
                    kicker: String(localized: "New on the App Scene"),
                    hideKickerFromAccessibility: true,
                    details: digest.appDetails(app),
                    body: aiBlurbs[app.id] ?? digest.newsletterBody(for: app),
                    accent: ContentKind.appListing.accentColor,
                    wasTranslated: wasTranslated
                ) {
                    NavigationLink(value: app) {
                        Label("Read App Entry", systemImage: "arrow.right.circle")
                    }
                }
            }
        }

        newsletterSection(
            title: digest.podcastSectionTitle(periodName: window.label),
            systemImage: "mic",
            intro: digest.podcastSectionIntro(periodName: window.label),
            kicker: String(localized: "Podcast Episode"),
            limitedMessage: limitedMessage(total: digest.podcasts.count, shown: podcasts.count, noun: "episode"),
            items: podcasts
        ) { episode in
            TranslatedMouseRecapTitle(kind: "podcastEpisode", id: episode.id, title: episode.title) { resolvedTitle, wasTranslated in
                ResolvedPodcastDuration(episode: episode) { durationText in
                    newsletterCard(
                        title: resolvedTitle,
                        kicker: String(localized: "Podcast Episode"),
                        hideKickerFromAccessibility: true,
                        details: digest.podcastDetails(episode) + (durationText.map { [$0] } ?? []),
                        body: aiBlurbs[episode.id] ?? digest.newsletterBody(for: episode),
                        accent: ContentKind.podcastEpisode.accentColor,
                        wasTranslated: wasTranslated
                    ) {
                        NavigationLink(value: episode) {
                            Label("Listen to Episode", systemImage: "play.circle")
                        }
                    }
                }
            }
        }

        newsletterSection(
            title: String(localized: "From the AppleVis Blog"),
            systemImage: "newspaper",
            intro: digest.blogSectionIntro(periodName: window.label),
            kicker: String(localized: "Blog Post"),
            limitedMessage: limitedMessage(total: digest.standardBlogs.count, shown: blogs.count, noun: "post"),
            items: blogs
        ) { post in
            TranslatedMouseRecapTitle(kind: "blogPost", id: post.id, title: post.title) { resolvedTitle, wasTranslated in
                ResolvedBlogReadingTime(post: post) { readingTimeText in
                    newsletterCard(
                        title: resolvedTitle,
                        kicker: String(localized: "Blog Post"),
                        hideKickerFromAccessibility: true,
                        details: digest.blogDetails(post) + (readingTimeText.map { [$0] } ?? []),
                        body: aiBlurbs[post.id] ?? digest.newsletterBody(for: post),
                        accent: ContentKind.blogPost.accentColor,
                        wasTranslated: wasTranslated
                    ) {
                        NavigationLink(value: post) {
                            Label("Read Blog Post", systemImage: "arrow.right.circle")
                        }
                    }
                }
            }
        }

        newsletterSection(
            title: String(localized: "How-To Corner"),
            systemImage: "book",
            intro: digest.resourceSectionIntro(periodName: window.label),
            limitedMessage: limitedMessage(total: digest.resources.count, shown: resources.count, noun: "guide or tutorial"),
            items: resources
        ) { resource in
            TranslatedMouseRecapTitle(kind: "resource", id: resource.id, title: resource.title) { resolvedTitle, wasTranslated in
                newsletterCard(
                    title: resolvedTitle,
                    kicker: resource.kind.displayName,
                    details: digest.resourceDetails(resource),
                    body: aiBlurbs[resource.id] ?? digest.newsletterBody(for: resource),
                    accent: ContentKind.resource.accentColor,
                    wasTranslated: wasTranslated
                ) {
                    NavigationLink(value: resource) {
                        Label("Read Guide", systemImage: "arrow.right.circle")
                    }
                }
            }
        }

        newsletterSection(
            title: String(localized: "Community Voices"),
            systemImage: "bubble.left.and.bubble.right",
            intro: digest.forumSectionIntro(periodName: window.label),
            kicker: String(localized: "Popular Discussion"),
            limitedMessage: limitedMessage(total: digest.forums.count, shown: forums.count, noun: "discussion"),
            items: forums
        ) { topic in
            TranslatedMouseRecapTitle(kind: "forumTopic", id: topic.id, title: topic.title) { resolvedTitle, wasTranslated in
                newsletterCard(
                    title: resolvedTitle,
                    kicker: String(localized: "Popular Discussion"),
                    hideKickerFromAccessibility: true,
                    details: digest.forumDetails(topic),
                    body: aiBlurbs[topic.id] ?? digest.newsletterBody(for: topic),
                    accent: ContentKind.forumTopic.accentColor,
                    wasTranslated: wasTranslated
                ) {
                    NavigationLink(value: topic) {
                        Label("Open Discussion", systemImage: "arrow.right.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func newsletterSection<Item: Identifiable, Row: View>(
        title: String,
        systemImage: String,
        intro: String,
        // Only for sections where every card shares the same kicker (e.g.
        // "New on the App Scene" on every app) — announced once here instead
        // of on every card. Left nil for How-To Corner, where the kicker is
        // resource.kind.displayName and genuinely differs per item, so it
        // still needs to be heard on each card. Requested directly: with 3
        // new apps this week, "New on the App Scene" was heard 3 times in a
        // row instead of once for the whole group.
        kicker: String? = nil,
        limitedMessage: String?,
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !items.isEmpty {
            Section {
                Text(intro)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(kicker.map { String(localized: "\($0). \(intro)") } ?? intro)
                ForEach(items) { item in
                    row(item)
                }
                if let limitedMessage {
                    Text(limitedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(title, systemImage: systemImage)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func newsletterCard<Action: View>(
        title: String,
        kicker: String,
        // True for the sections whose kicker is now announced once at the
        // section level instead (see newsletterSection's `kicker` param) —
        // kept visible on screen for sighted users scanning cards at a
        // glance, just no longer read by VoiceOver on every single card.
        hideKickerFromAccessibility: Bool = false,
        details: [String],
        body: String,
        accent: Color,
        wasTranslated: Bool = false,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kicker)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .accessibilityHidden(hideKickerFromAccessibility)
            HStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(wasTranslated ? String(localized: "Translated: \(title)") : title)
                if wasTranslated { TranslatedTitleBadge() }
            }
            if !details.isEmpty {
                FlowTextBadges(details: details, accent: accent)
            }
            Text(body)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            action()
                .font(.subheadline.weight(.semibold))
        }
        .newsletterPanel(accent: accent, colors: preferences.colors)
        .accessibilityElement(children: .contain)
    }

    private func limitedMessage(total: Int, shown: Int, noun: String) -> String? {
        guard total > shown else { return nil }
        let plural = noun == "guide or tutorial" ? "guides and tutorials" : "\(noun)s"
        return "Showing the most relevant \(shown) \(shown == 1 ? noun : plural) from this period."
    }

    private func generateAIBlurbs(for digest: MouseRecapDigest) async {
        guard preferences.aiSummariesEnabled, IntelligenceService.isAvailable, aiWindow != window else { return }
        aiWindow = window
        let limits = MouseRecapDigest.limits(for: window.label)
        var candidates: [(id: String, title: String, kind: String, source: String)] = []
        if let spotlight = digest.appPickSpotlight {
            candidates.append((spotlight.id, spotlight.title, "spotlight feature", digest.newsletterBody(for: spotlight)))
        }
        candidates += digest.apps.prefix(limits.apps).map { ($0.id, $0.name, "app entry", digest.newsletterBody(for: $0)) }
        candidates += digest.podcasts.prefix(limits.podcasts).map { ($0.id, $0.title, "podcast episode", digest.newsletterBody(for: $0)) }
        candidates += digest.standardBlogs.prefix(limits.blogs).map { ($0.id, $0.title, "blog post", digest.newsletterBody(for: $0)) }
        candidates += digest.resources.prefix(limits.resources).map { ($0.id, $0.title, "guide or tutorial", digest.newsletterBody(for: $0)) }
        candidates += digest.forums.prefix(limits.forums).map { ($0.id, $0.title, "forum discussion", digest.newsletterBody(for: $0)) }

        for candidate in candidates.prefix(16) where aiBlurbs[candidate.id] == nil {
            if let blurb = await IntelligenceService.newsletterBlurb(title: candidate.title, kind: candidate.kind, sourceText: candidate.source) {
                aiBlurbs[candidate.id] = blurb
            }
        }
    }

    @ViewBuilder
    private func recapSection<Item: Identifiable, Row: View>(
        _ title: String,
        systemImage: String,
        description: String,
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !items.isEmpty {
            Section {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(items) { item in
                    row(item)
                }
            } header: {
                Label(title, systemImage: systemImage)
            }
        }
    }
}

private struct FlowTextBadges: View {
    let details: [String]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(details, id: \.self) { detail in
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func newsletterPanel(accent: Color, colors: ThemeColors) -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .padding(.leading, 2)
    }
}

private struct MouseRecapCard: View {
    let digest: MouseRecapDigest?
    let isLoading: Bool
    let error: String?
    let failedSources: [String]
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Mouse Recap")
                    .font(.subheadline.weight(.semibold))
                if isLoading && digest == nil {
                    Text("Building your recap...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(preferences.colors.warning)
                } else if let digest {
                    Text(digest.countSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !failedSources.isEmpty {
                        Text("Some sources could not be loaded.")
                            .font(.caption)
                            .foregroundStyle(preferences.colors.warning)
                    }
                } else {
                    Text("A shareable summary of accessible apps, podcasts, discussions, guides, and blog posts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(preferences.colors.card, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isLoading && digest == nil { return "Mouse Recap. Building your recap." }
        if let error { return "Mouse Recap. \(error)" }
        if let digest { return "Mouse Recap. \(digest.countSummary)" }
        return "Mouse Recap. Recent activity summary."
    }
}

private struct MouseRecapView: View {
    @ObservedObject var vm: HomeViewModel
    @EnvironmentObject private var preferences: PreferencesStore
    // Same UserDefaults key as HomeView's own @AppStorage — picking a window
    // here is reflected back into the compact Home card automatically, with
    // no binding to thread through.
    @AppStorage("home.mouseRecapWindow") private var window: MouseRecapWindow = .week

    var body: some View {
        Group {
            if vm.isLoadingMouseRecap && vm.mouseRecap == nil {
                LoadingView(message: "Building Mouse Recap...")
            } else if let error = vm.mouseRecapError, vm.mouseRecap == nil {
                ErrorView(message: error) { await vm.loadMouseRecap(force: true) }
            } else if let digest = vm.mouseRecap?.scoped(toLastDays: window.rawValue) {
                List {
                    Section {
                        Picker("Recap Window", selection: $window) {
                            ForEach(MouseRecapWindow.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(String(localized: "Recap window"))
                        .accessibilityHint(String(localized: "Choose how far back Mouse Recap looks."))
                        // Explicit value — without it, swiping up/down only
                        // played the "value changed" tone with no spoken
                        // window name. Same fix as PlayerView's playback-
                        // speed control (PODCAST-06). Reported directly.
                        .accessibilityValue(Text(window.label))
                        // Same swipe-up/down addition as the other pickers
                        // in this session's pass — moves between Past
                        // Week/Past Month in place.
                        .accessibilityAdjustableAction { direction in
                            guard let idx = MouseRecapWindow.allCases.firstIndex(of: window) else { return }
                            switch direction {
                            case .increment:
                                window = MouseRecapWindow.allCases[(idx + 1) % MouseRecapWindow.allCases.count]
                            case .decrement:
                                window = MouseRecapWindow.allCases[(idx - 1 + MouseRecapWindow.allCases.count) % MouseRecapWindow.allCases.count]
                            @unknown default: break
                            }
                        }
                    }
                    .listRowSeparator(.hidden)

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(digest.dateRangeText)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(digest.newsletterIntro(for: window.label))
                                .font(.body)
                            if digest.isEmpty {
                                Text(window == .week ? "Pull to refresh later, or try Past Month for a wider look." : "Pull to refresh later for a fresh look.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    } header: {
                        Text("In This Recap")
                    }

                    if !vm.failedMouseRecapSourceNames.isEmpty {
                        Section {
                            SourceErrorBanner(failedSources: vm.failedMouseRecapSourceNames) {
                                Task { await vm.loadMouseRecap(force: true) }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }

                    recapSection(
                        "New Accessible Apps",
                        systemImage: "square.grid.2x2",
                        description: "A quick look at the newest additions to the AppleVis App Directory.",
                        items: digest.apps
                    ) { app in
                        NavigationLink(value: app) {
                            TranslatedMouseRecapTitle(kind: "appListing", id: app.id, title: app.name) { resolvedTitle, wasTranslated in
                                MouseRecapItemRow(title: resolvedTitle, subtitle: app.developer, date: app.createdAt, wasTranslated: wasTranslated)
                            }
                        }
                    }
                    recapSection(
                        "Podcast Episodes",
                        systemImage: "mic",
                        description: "Recent audio walkthroughs, conversations, and practical tips.",
                        items: digest.podcasts
                    ) { episode in
                        NavigationLink(value: episode) {
                            TranslatedMouseRecapTitle(kind: "podcastEpisode", id: episode.id, title: episode.title) { resolvedTitle, wasTranslated in
                                MouseRecapItemRow(title: resolvedTitle, subtitle: episode.showTitle, date: episode.publishedAt, wasTranslated: wasTranslated)
                            }
                        }
                    }
                    recapSection(
                        "Popular Discussions",
                        systemImage: "bubble.left.and.bubble.right",
                        description: "Community conversations that have been drawing replies.",
                        items: digest.forums
                    ) { topic in
                        NavigationLink(value: topic) {
                            TranslatedMouseRecapTitle(kind: "forumTopic", id: topic.id, title: topic.title) { resolvedTitle, wasTranslated in
                                MouseRecapItemRow(
                                    title: resolvedTitle,
                                    subtitle: "\(topic.replyCount) repl\(topic.replyCount == 1 ? "y" : "ies")",
                                    date: topic.lastActivityAt,
                                    wasTranslated: wasTranslated
                                )
                            }
                        }
                    }
                    recapSection(
                        "Guides and Tutorials",
                        systemImage: "book",
                        description: "Hands-on help and explainers from the AppleVis community.",
                        items: digest.resources
                    ) { resource in
                        NavigationLink(value: resource) {
                            TranslatedMouseRecapTitle(kind: "resource", id: resource.id, title: resource.title) { resolvedTitle, wasTranslated in
                                MouseRecapItemRow(title: resolvedTitle, subtitle: resource.kind.displayName, date: resource.updatedAt, wasTranslated: wasTranslated)
                            }
                        }
                    }
                    recapSection(
                        "Blog Posts",
                        systemImage: "newspaper",
                        description: "News, updates, and editorial coverage from AppleVis.",
                        items: digest.blogs
                    ) { post in
                        NavigationLink(value: post) {
                            TranslatedMouseRecapTitle(kind: "blogPost", id: post.id, title: post.title) { resolvedTitle, wasTranslated in
                                MouseRecapItemRow(title: resolvedTitle, subtitle: post.authorName, date: post.publishedAt, wasTranslated: wasTranslated)
                            }
                        }
                    }
                }
                .themedList(preferences.colors)
                .refreshable { await vm.loadMouseRecap(force: true) }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: digest.shareText(for: window.label), subject: Text("Mouse Recap")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(String(localized: "Share Mouse Recap"))
                    }
                }
            } else {
                EmptyStateView(
                    title: "Mouse Recap",
                    message: "Pull to refresh your recap.",
                    systemImage: "sparkles"
                )
            }
        }
        .navigationTitle("Mouse Recap")
        .task { await vm.loadMouseRecap() }
    }

    @ViewBuilder
    private func recapSection<Item: Identifiable, Row: View>(
        _ title: String,
        systemImage: String,
        description: String,
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !items.isEmpty {
            Section {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(items) { item in
                    row(item)
                }
            } header: {
                Label(title, systemImage: systemImage)
            }
        }
    }
}

private struct MouseRecapItemRow: View {
    let title: String
    let subtitle: String
    let date: Date
    var wasTranslated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel(wasTranslated ? String(localized: "Translated: \(title)") : title)
                if wasTranslated { TranslatedTitleBadge() }
            }
            HStack(spacing: 6) {
                Text(subtitle)
                Text("-")
                    .accessibilityHidden(true)
                RelativeDateLabel(date: date)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Resolves a Mouse Recap card's title translation once per (kind, id,
/// title, language) combination and hands the result to its content closure
/// — `newsletterCard`/`MouseRecapItemRow` are plain helper functions/struct
/// properties, not owners of per-item state, so a small wrapper view carries
/// the `@State` that per-row `.task(id:)` resolution needs (same reasoning
/// as the equivalent wrappers added to `RowViews.swift`'s row structs).
private struct TranslatedMouseRecapTitle<Content: View>: View {
    let kind: String
    let id: String
    let title: String
    @ViewBuilder let content: (_ resolvedTitle: String, _ wasTranslated: Bool) -> Content

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var translatedTitle: String?

    var body: some View {
        content(translatedTitle ?? title, translatedTitle != nil)
            .task(id: ContentTranslation.taskId(title: title, targetLanguage: preferences.effectiveContentLanguage)) {
                translatedTitle = await ContentTranslation.resolvedTitle(
                    kind: kind, id: id, originalTitle: title, targetLanguage: preferences.effectiveContentLanguage
                )
            }
    }
}

/// Requested directly: episode length is a nice-to-have alongside the show
/// name and date already in `podcastDetails`. `episode.duration` is almost
/// always 0 (Drupal never fills it in), so this leans on the same
/// cache-then-probe pattern `PodcastEpisodeRow` already uses elsewhere —
/// instant if the episode's been seen before, silent (no chip) if a live
/// probe can't resolve one.
private struct ResolvedPodcastDuration<Content: View>: View {
    let episode: PodcastEpisode
    @ViewBuilder let content: (_ durationText: String?) -> Content

    @State private var resolvedDuration: TimeInterval?

    var body: some View {
        content(durationText)
            .task(id: episode.id) {
                await resolveDurationIfNeeded()
            }
    }

    private var durationText: String? {
        guard let resolvedDuration, resolvedDuration > 0 else { return nil }
        return PodcastDuration.abbreviated(resolvedDuration)
    }

    private func resolveDurationIfNeeded() async {
        if let existing = episode.duration, existing > 0 {
            resolvedDuration = existing
            return
        }
        if let cached = PersistenceStore.shared.cachedAudioMetadata(episodeId: episode.id)?.duration, cached > 0 {
            resolvedDuration = cached
            return
        }
        guard let probed = await PodcastAudioMetadataProbe.resolveDuration(audioUrl: episode.audioUrl) else { return }
        PersistenceStore.shared.cacheProbedDuration(episodeId: episode.id, duration: probed)
        resolvedDuration = probed
    }
}

/// Requested directly, alongside podcast length. The list-level `BlogPost`
/// only carries `summary`, not the full article text, so a real reading
/// time needs the same detail fetch the blog post's own screen already
/// makes (and caches) — this just borrows that cache instead of adding a
/// new one.
private struct ResolvedBlogReadingTime<Content: View>: View {
    let post: BlogPost
    @ViewBuilder let content: (_ readingTimeText: String?) -> Content

    @State private var readingTimeText: String?

    var body: some View {
        content(readingTimeText)
            .task(id: post.id) {
                guard let detail = try? await APIClient.shared.blogs.detail(id: post.id) else { return }
                readingTimeText = ReadingTime.text(forHTMLBody: detail.body)
            }
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
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(preferences.colors.warning)
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
        .background(preferences.colors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Some sources could not be loaded: \(failedSources.joined(separator: ", "))."))
        // .combine merges the nested "Retry Now" Button into this single
        // element, which can leave it unreachable as its own VoiceOver
        // stop — an explicit action guarantees it's still triggerable.
        .accessibilityAction(named: Text("Retry Now"), onRetry)
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
            .accessibilityLabel(String(localized: "What's New. \(message)"))
            .accessibilityHint(String(localized: "Double-tap to jump to where you left off in the feed."))

            Button("Dismiss", action: onDismiss)
                .font(.caption).fontWeight(.semibold)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Dismiss welcome summary"))
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

// MARK: - Notification history

/// Home's "Notification summary" destination (docs/APPLEVIS_2026_1_MASTER_SPEC.md)
/// — a local read-only log of the last 20 notifications received, since
/// nothing server-side tracks this. Tapping an entry with a recognizable
/// deep-link target routes it the same way a tapped system notification
/// would (DeepLinkRouter.pendingContent); entries without one (e.g. plain
/// announcements) are shown but not tappable.
struct NotificationHistoryView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var items: [NotificationHistoryItem] = []

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(title: "No Notifications Yet", message: "Notifications you receive will appear here.", systemImage: "bell")
            } else {
                List(items) { item in
                    let isRoutable = item.kind != nil && item.contentId != nil
                    Button {
                        guard let kind = item.kind, let contentId = item.contentId else { return }
                        deepLinkRouter.pendingContent = (kind: kind, id: contentId)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline).fontWeight(.semibold)
                            Text(item.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            RelativeDateLabel(date: item.receivedAt)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isRoutable)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "\(item.title). \(item.body)."))
                    .accessibilityHint(isRoutable ? "Double-tap to open." : "")
                }
                .themedList(preferences.colors)
            }
        }
        .navigationTitle("Notifications")
        .onAppear { items = PersistenceStore.shared.notificationHistory() }
    }
}

// MARK: - Feed row

struct FeedRow: View {
    let item: FeedItem
    /// Replies/comments added since this item was last marked read — the
    /// "Mark as Read" action only appears when there's actually something
    /// new to dismiss, matching the old app's behavior.
    var newCount: Int = 0
    /// Whether Home considers this item new since the last visit at all —
    /// distinct from `newCount`, which only counts *additional* replies on
    /// something already seen before. An item that's never been opened has
    /// no comment-count baseline to diff against, so newCount is 0 for it
    /// even though it's clearly new; this flag covers that case so brand-
    /// new items still get a visible "NEW" marker on their card.
    var isNew: Bool = false
    var onMarkRead: (() -> Void)? = nil

    var body: some View {
        Group {
            switch item {
            case .forumTopic(let t):     ForumTopicRow(topic: t, isNew: isNew)
            case .podcastEpisode(let e): PodcastEpisodeRow(episode: e, isNew: isNew)
            case .appListing(let a):     AppListingRow(app: a, isNew: isNew)
            case .resource(let r):       ResourceRow(resource: r, isNew: isNew)
            case .blogPost(let b):       BlogPostRow(post: b, isNew: isNew)
            }
        }
        .unreadIndicator(item.isUnread)
        .accessibilityValue(isNew && newCount == 0 ? "New." : "")
        // A brand-new, never-visited item has no prior comment-count
        // baseline to diff against, so `newCount` (a *reply-delta*, not a
        // newness flag) is 0 for it even though `isNew` is true — the old
        // `newCount > 0`-only gate meant a "NEW" card had no way to be
        // marked read at all until it happened to also pick up a reply.
        // Reported directly: a card marked New offered no Mark as Read action.
        .modifier(ConditionalAccessibilityAction(isActive: (isNew || newCount > 0) && onMarkRead != nil, name: "Mark as Read") {
            onMarkRead?()
        })
    }
}
