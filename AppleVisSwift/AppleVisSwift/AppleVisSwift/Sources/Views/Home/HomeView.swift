import SwiftUI

/// Narrows the feed already loaded on Home to just what's new since the
/// last visit — distinct from "Customize Home," which controls which
/// content types are fetched in the first place, not which of them show.
enum HomeFeedFilter: String, CaseIterable, Identifiable {
    case all, new
    var id: String { rawValue }
    var label: String { self == .all ? "All" : "New" }
}

/// Where VoiceOver focus should land once Home finishes its initial load —
/// docs/IMPLEMENTATION_NOTES.md: "VoiceOver focus should land on the
/// summary before the first feed card." Falls back to the greeting when
/// there's no What's New card to land on.
enum HomeFocusTarget: Hashable {
    case summary
    case greeting
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
    @ObservedObject private var networkStatus = NetworkStatusStore.shared
    @State private var hasAnnouncedWelcome = false
    @State private var showCustomizeHome = false
    @State private var homeFeedFilter: HomeFeedFilter = .all
    @State private var notificationHistory: [NotificationHistoryItem] = []
    @AccessibilityFocusState private var focusTarget: HomeFocusTarget?
    @Environment(\.scenePhase) private var scenePhase

    /// Items actually shown below the feed picker — narrowed to just what's
    /// new since the last visit when the "New" segment is selected. Distinct
    /// from the "Customize Home" menu, which controls which content TYPES
    /// are fetched at all, not which of the fetched items are shown.
    private var visibleItems: [FeedItem] {
        homeFeedFilter == .new ? vm.newItems : vm.items
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
                    .accessibilityLabel("Customize Home")
                    .accessibilityHint("Choose what content types appear on your Home screen")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profile and Settings")
                }
            }
            .refreshable {
                await vm.load()
                notificationHistory = PersistenceStore.shared.notificationHistory()
                SoundPlayer.shared.play(.refresh)
            }
            .onReceive(keyCommands.refreshRequested) { Task { await vm.load() } }
            .overlay(alignment: .top) { ToastOverlay() }
            .sheet(isPresented: $showCustomizeHome, onDismiss: { Task { await vm.load() } }) {
                CustomizeHomeView()
            }
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
        .onAppear {
            notificationHistory = PersistenceStore.shared.notificationHistory()
        }
        .onChange(of: scenePhase) { old, new in
            if new == .background {
                // Marks "now" as the boundary for the *next* session —
                // doesn't affect what's already on screen this session, so
                // items the user hasn't gotten to yet don't vanish from
                // "New" just because the app briefly backgrounded.
                vm.stampVisitForNextSession()
            } else if new == .active && old == .background {
                vm.refreshSessionBoundary()
                Task { await vm.load() }
            }
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

        // Land VoiceOver focus on the summary (or greeting, if there's no
        // new activity to summarize) instead of leaving it whereever it was
        // before navigation/launch — a short delay because setting focus
        // before the List has actually laid out the new content is a common
        // way for it to silently fail.
        let target: HomeFocusTarget? = !vm.newItems.isEmpty && !vm.isNewActivityDismissed
            ? .summary
            : (auth.user?.name.isEmpty == false ? .greeting : nil)
        if let target {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                focusTarget = target
            }
        }
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
                .accessibilityFocused($focusTarget, equals: .greeting)
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
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Notifications, \(notificationHistory.count) recent")
                    .accessibilityHint("Double-tap to view your recent notifications.")
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

                if !vm.newItems.isEmpty && !vm.isNewActivityDismissed {
                    WhatsNewCard(
                        message: vm.newActivitySummary,
                        onTap: {
                            guard let first = vm.newItems.first else { return }
                            withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                        },
                        onDismiss: { vm.isNewActivityDismissed = true }
                    )
                    .accessibilityFocused($focusTarget, equals: .summary)
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

                if !visibleItems.isEmpty {
                    HStack {
                        Text(homeFeedFilter == .new ? "New Activity" : "Latest Activity")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityAction(named: Text("Feed summary")) {
                                UIAccessibility.post(notification: .announcement, argument: feedSummary)
                            }
                        Spacer()
                        if homeFeedFilter == .new {
                            Button("Mark All Read") {
                                vm.markAllAsRead(visibleItems)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .accessibilityHint("Clears all items from the New view.")
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if vm.hasMore && homeFeedFilter == .all {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .task { await vm.loadMore() }
                } else if !vm.hasMore && homeFeedFilter == .all && !visibleItems.isEmpty {
                    Text("You're all caught up.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
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
            let label = kind.displayName.lowercased()
            return "\(n) \(label)\(n == 1 ? "" : "s")"
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
                        .accessibilityHint("Hides non-Apple forum categories from Home.")
                }
            }
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

// MARK: - Notification history

/// Home's "Notification summary" destination (docs/APPLEVIS_2026_1_MASTER_SPEC.md)
/// — a local read-only log of the last 20 notifications received, since
/// nothing server-side tracks this. Tapping an entry with a recognizable
/// deep-link target routes it the same way a tapped system notification
/// would (DeepLinkRouter.pendingContent); entries without one (e.g. plain
/// announcements) are shown but not tappable.
struct NotificationHistoryView: View {
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
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
                    .accessibilityLabel("\(item.title). \(item.body).")
                    .accessibilityHint(isRoutable ? "Double-tap to open." : "")
                }
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
            case .forumTopic(let t):     ForumTopicRow(topic: t)
            case .podcastEpisode(let e): PodcastEpisodeRow(episode: e)
            case .appListing(let a):     AppListingRow(app: a)
            case .resource(let r):       ResourceRow(resource: r)
            case .blogPost(let b):       BlogPostRow(post: b)
            }
        }
        .unreadIndicator(item.isUnread)
        .overlay(alignment: .topTrailing) {
            // Only shown when the row itself has no reply-count badge of
            // its own to show (newCount == 0) — otherwise a revisited item
            // with fresh replies would show two "new" badges at once.
            if isNew && newCount == 0 {
                Text("NEW")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
                    .accessibilityHidden(true)
                    .padding(6)
            }
        }
        .accessibilityValue(isNew && newCount == 0 ? "New." : "")
        .modifier(ConditionalAccessibilityAction(isActive: newCount > 0 && onMarkRead != nil, name: "Mark as Read") {
            onMarkRead?()
        })
    }
}
