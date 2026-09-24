import SwiftUI

// MARK: - Community Picks (Discover → App Directory)

/// Apps the AppleVis community recommends, grouped per app. Three pickers at
/// the top — Show (Latest / Most Recommended), Period, and Platform — each a
/// menu picker that also moves with a VoiceOver swipe up or down, like the
/// App Directory's platform picker. Rows mirror the Home app rows, with the
/// same actions (Save, Follow, Recommend, Share, Open in App Store).
struct CommunityPicksView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var sort: CommunityPicksSort = .latest
    @State private var period: CommunityPicksPeriod = CommunityPicksSort.latest.defaultPeriod
    @State private var platform: AppPlatform? = nil
    @State private var picks: [CommunityPick] = []
    @State private var page = 0
    @State private var canLoadMore = false
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    /// The server endpoint doesn't exist yet (404) — see CommunityPicksEndpoints.
    @State private var isUnavailable = false
    @State private var loadTask: Task<Void, Never>?
    /// Coming back from an app page re-runs `.task`; don't reset the list
    /// (and VoiceOver's place in it) when that happens.
    @State private var hasLoaded = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    private static let platformOptions: [AppPlatform?] = [nil] + AppPlatform.allCases.map { Optional($0) }

    var body: some View {
        List {
            Section {
                // Screen title for VoiceOver focus, matching Discover's own
                // hidden heading; the navigation bar already shows it visually.
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Community Picks"))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                Text("Apps AppleVis members recommend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                sortPicker
                periodPicker
                platformPicker
            }

            content
        }
        .listStyle(.plain)
        // Lets the zero-size VoiceOver title row above take no visible space.
        .environment(\.defaultMinListRowHeight, 0)
        .themedList(preferences.colors)
        .navigationTitle("Community Picks")
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            reload()
        }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
        .refreshable {
            await load(reset: true)
            SoundPlayer.shared.play(.refresh)
        }
        .onChange(of: sort) { _, newSort in
            // Switching views jumps to that view's own sensible period;
            // reload() runs once from the period change, or here if the
            // period was already the default.
            if period != newSort.defaultPeriod {
                period = newSort.defaultPeriod
            } else {
                reload()
            }
        }
        .onChange(of: period) { _, _ in reload() }
        .onChange(of: platform) { _, _ in reload() }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if isLoading && picks.isEmpty {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("Loading"))
            }
            .listRowSeparator(.hidden)
        } else if isUnavailable {
            stateRow(
                EmptyStateView(
                    title: String(localized: "Community Picks Is Almost Ready"),
                    message: String(localized: "This list needs a small update to the AppleVis website. It will fill in by itself once that's done, so check back soon."),
                    systemImage: "hand.thumbsup"
                )
            )
        } else if let errorMessage, picks.isEmpty {
            stateRow(ErrorView(message: errorMessage) { await load(reset: true) })
        } else if picks.isEmpty {
            stateRow(
                EmptyStateView(
                    title: String(localized: "No Picks Yet"),
                    message: period == .allTime
                        ? String(localized: "No apps have been recommended yet.")
                        : String(localized: "No apps were recommended in this period. Try a longer period."),
                    systemImage: "hand.thumbsup"
                )
            )
        } else {
            Section {
                ForEach(Array(picks.enumerated()), id: \.element.id) { index, pick in
                    CommunityPickRow(pick: pick, rank: sort == .most ? index + 1 : nil, sort: sort, period: period)
                        .onAppear {
                            if pick.id == picks.last?.id { Task { await loadMore() } }
                        }
                }
                if isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("Loading more"))
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    private func stateRow(_ view: some View) -> some View {
        Section {
            view
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Pickers

    /// `.menu` rather than `.segmented` for the same reason as the App
    /// Directory's platform picker: segmented reads as unrelated buttons.
    /// Every picker carries an explicit accessibilityValue, or VoiceOver
    /// only plays the "value changed" tone when swiping.
    private var sortPicker: some View {
        Picker("Show", selection: $sort) {
            ForEach(CommunityPicksSort.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
        .accessibilityValue(Text(sort.displayName))
        .accessibilityHint(Text("Swipe up or down to switch between the latest and the most recommended apps."))
        .accessibilityAdjustableAction { direction in
            sort = Self.step(sort, in: CommunityPicksSort.allCases, direction)
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(CommunityPicksPeriod.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
        .accessibilityValue(Text(period.displayName))
        .accessibilityHint(Text("Swipe up or down to choose how far back to count recommendations."))
        .accessibilityAdjustableAction { direction in
            period = Self.step(period, in: CommunityPicksPeriod.allCases, direction)
        }
    }

    private var platformPicker: some View {
        Picker("Platform", selection: $platform) {
            ForEach(Self.platformOptions, id: \.self) { option in
                Text(Self.platformName(option)).tag(option)
            }
        }
        .pickerStyle(.menu)
        .accessibilityValue(Text(Self.platformName(platform)))
        .accessibilityHint(Text("Swipe up or down to choose a platform."))
        .accessibilityAdjustableAction { direction in
            platform = Self.step(platform, in: Self.platformOptions, direction)
        }
    }

    private static func platformName(_ platform: AppPlatform?) -> String {
        platform?.displayName ?? String(localized: "All Platforms")
    }

    /// Wraps around at either end, like the App Directory's platform picker.
    private static func step<T: Equatable>(_ current: T, in options: [T], _ direction: AccessibilityAdjustmentDirection) -> T {
        guard let index = options.firstIndex(of: current) else { return current }
        switch direction {
        case .increment: return options[(index + 1) % options.count]
        case .decrement: return options[(index - 1 + options.count) % options.count]
        @unknown default: return current
        }
    }

    // MARK: - Loading

    /// Cancels any in-flight load so quick picker swipes don't let an older
    /// response land on top of a newer one.
    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await load(reset: true) }
    }

    private func load(reset: Bool) async {
        if reset {
            page = 0
            canLoadMore = false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.communityPicks.list(sort: sort, period: period, platform: platform, page: 0)
            guard !Task.isCancelled else { return }
            picks = result
            canLoadMore = result.count >= CommunityPicksEndpoints.pageSize
            errorMessage = nil
            isUnavailable = false
        } catch APIError.notFound {
            guard !Task.isCancelled else { return }
            picks = []
            isUnavailable = true
        } catch {
            guard !Task.isCancelled else { return }
            isUnavailable = false
            errorMessage = String(localized: "Couldn't load Community Picks. Try again.")
        }
    }

    private func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let next = page + 1
        guard let result = try? await APIClient.shared.communityPicks.list(sort: sort, period: period, platform: platform, page: next) else { return }
        let known = Set(picks.map(\.id))
        picks += result.filter { !known.contains($0.id) }
        page = next
        canLoadMore = result.count >= CommunityPicksEndpoints.pageSize
    }
}

// MARK: - Row

/// Mirrors AppListingRow (same accent bar, navigation, and actions), but
/// its details are about recommendations instead of comments.
struct CommunityPickRow: View {
    let pick: CommunityPick
    /// Shown on Most Recommended only.
    let rank: Int?
    let sort: CommunityPicksSort
    let period: CommunityPicksPeriod
    @EnvironmentObject private var preferences: PreferencesStore
    @ObservedObject private var recommendations = RecommendationStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var rankSize: CGFloat = 32
    @State private var translatedTitle: String?

    private var app: AppListing { pick.app }
    private var isRecommendedByMe: Bool { recommendations.isRecommended(app.id) }

    var body: some View {
        NavigationLink(value: app) {
            HStack(alignment: .top, spacing: 12) {
                if let rank {
                    Text("\(rank)")
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: rankSize, minHeight: rankSize)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(translatedTitle ?? app.name)
                            .font(.body)
                        if translatedTitle != nil { TranslatedTitleBadge() }
                    }
                    Text(countLine)
                        .font(.subheadline)
                    HStack(spacing: 6) {
                        Text(detailLine)
                        Spacer()
                        if isRecommendedByMe {
                            Image(systemName: "hand.thumbsup.fill")
                                .symbolEffect(.bounce, value: reduceMotion ? false : isRecommendedByMe)
                                .accessibilityHidden(true)
                        }
                        if app.isSaved {
                            Image(systemName: "bookmark.fill").font(.caption2).accessibilityHidden(true)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(ContentKind.appListing.accentColor).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowLabel)
        .readAloudAction(rowLabel)
        .modifier(ConditionalAccessibilityAction(isActive: appStoreURL != nil, name: "Open in App Store") {
            guard let appStoreURL else { return }
            UIApplication.shared.open(appStoreURL)
        })
        .contentActions(
            id: app.id, entityId: app.nid ?? 0, kind: .appListing, title: app.name,
            lastActivityAt: app.lastActivityAt, url: app.url, currentCommentCount: app.reviewCount
        ) {
            // Hidden: the explicit accessibility action above already
            // offers this to VoiceOver. See AppListingRow.
            if let appStoreURL {
                Link(destination: appStoreURL) {
                    Label("Open in App Store", systemImage: "arrow.up.forward.app")
                }
                .accessibilityHidden(true)
            }
        }
        .cardDensityPadding()
        .task(id: ContentTranslation.taskId(title: app.name, targetLanguage: preferences.effectiveContentLanguage)) {
            translatedTitle = await ContentTranslation.resolvedTitle(
                kind: "appListing", id: app.id, originalTitle: app.name, targetLanguage: preferences.effectiveContentLanguage
            )
        }
    }

    private var appStoreURL: URL? {
        app.appStoreUrl.flatMap(URL.init)
    }

    /// "12 recommendations in the past 3 months", plus the all-time total
    /// when a shorter period hides part of it: "75 in all".
    private var countLine: String {
        let inPeriod = period.countPhrase(pick.periodCount)
        guard period != .allTime, pick.totalCount > pick.periodCount else { return inPeriod }
        let total = String(localized: "\(pick.totalCount) in all")
        return "\(inPeriod), \(total)"
    }

    private var lastRecommendedPhrase: String? {
        pick.lastRecommendedAt.map { date in
            let relative = date.formatted(.relative(presentation: .named))
            return String(localized: "Last recommended \(relative)")
        }
    }

    private var detailLine: String {
        var parts = [app.platform.displayName]
        if !app.category.isEmpty { parts.append(app.category) }
        if let lastRecommendedPhrase { parts.append(lastRecommendedPhrase) }
        return parts.joined(separator: " · ")
    }

    private var rowLabel: String {
        let title = ContentTranslation.accessibilityTitle(original: app.name, translated: translatedTitle)
        var parts: [String] = []
        if let rank {
            parts.append(String(localized: "Number \(rank), \(title)"))
        } else {
            parts.append(title)
        }
        parts.append(app.category.isEmpty
            ? String(localized: "\(app.platform.displayName) app entry")
            : String(localized: "\(app.category) app entry, \(app.platform.displayName)"))
        parts.append(countLine)
        if let lastRecommendedPhrase { parts.append(lastRecommendedPhrase) }
        if isRecommendedByMe { parts.append(String(localized: "You recommend this app")) }
        if app.isSaved { parts.append(String(localized: "Saved")) }
        return parts.joined(separator: ". ")
    }
}
