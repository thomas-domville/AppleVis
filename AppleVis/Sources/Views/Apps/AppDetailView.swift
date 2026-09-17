import SwiftUI
import UIKit

private enum AppStoreLookupIssue {
    case notFound
    case invalidLink
    case failed

    var title: String {
        switch self {
        case .notFound:
            return "This app may no longer be available in the App Store."
        case .invalidLink:
            return "The App Store link for this entry needs review."
        case .failed:
            return "App Store information is temporarily unavailable."
        }
    }

    var message: String {
        switch self {
        case .notFound:
            return "AppleVis still has this community entry, but the App Store listing could not be found."
        case .invalidLink:
            return "AppleVis could not find a valid App Store app ID in the saved link."
        case .failed:
            return "AppleVis could not check the App Store right now. Try again later."
        }
    }

    var systemImage: String {
        switch self {
        case .notFound, .invalidLink:
            return "exclamationmark.triangle"
        case .failed:
            return "wifi.exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .notFound, .invalidLink:
            return .orange
        case .failed:
            return .secondary
        }
    }
}

struct AppDetailView: View {
    let appId: String
    /// Known when navigated to from an `AppListing` already carrying its
    /// own `.platform` (Home, Discover, search, saved items); `nil` when
    /// only a bare content id is available (deep link, Spotlight,
    /// notification) — `AppEndpoints.detail(id:platform:)` resolves the
    /// content type itself in that case. Reported directly: this is what
    /// makes an Apple TV entry actually openable at all outside the Submit
    /// wizard, previously the only place `node--tv_directory` was ever
    /// touched.
    var platform: AppPlatform? = nil
    /// Set when opened via a card's "Jump to First New Comment" action —
    /// see the same property on ForumTopicDetailView for the full
    /// reasoning; routed the same way through DeepLinkRouter.pendingContentIntent.
    var focusFirstNewCommentOnAppear: Bool = false
    @State private var hasAppliedFirstNewCommentFocus = false
    @State private var detail: AppDetail?
    @State private var appleVisTitle: String?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showReviewCompose = false
    @State private var quotedReview: AppReview?
    @State private var itunesMetadata: ItunesMetadata?
    @State private var appStoreLookupIssue: AppStoreLookupIssue?
    /// True when `itunesMetadata` came from `matchAppleTVEntryToAppStore()`'s
    /// best-effort name match rather than a real App Store link AppleVis
    /// itself stored — drives a visible caveat in `appStoreInfoSection` so
    /// this is never presented as something AppleVis verified.
    @State private var isMatchedNotConfirmed = false
    @State private var developerApps: [ItunesDeveloperApp] = []
    @State private var isLoadingMoreReviews = false
    @State private var hasMoreReviews = true
    // Mirrors ForumTopicDetailView.loadAllRepliesTask — prevents load()'s
    // background drain-all and "Jump to First New Comment"/"Jump to Last
    // Comment" from both starting their own concurrent loadMoreReviews()
    // loop, which raced on reviews.count and duplicated pages.
    @State private var loadAllReviewsTask: Task<Void, Never>?
    @State private var newReviewCount = 0
    @State private var pendingFocusReviewId: String?
    @State private var recommendationSummary: RecommendationSummary?
    @State private var reviewsSummary: String?
    @State private var isSummarizingReviews = false
    @State private var accessibilityConsensus: String?
    @State private var isSummarizingConsensus = false
    @State private var showUpdateAppInfoSheet = false
    @State private var appInfoDiffs: [AppInfoFieldDiff] = []
    @State private var selectedAppInfoFieldIDs: Set<String> = []
    @State private var isUpdatingAppInformation = false
    // App-level moderation — mirrors ForumTopicDetailView's own
    // Edit/Unpublish/Delete, generalized to every content kind via
    // DetailActionsMenu. Previously the App Entry page had no such controls
    // at all, only comment-level moderation.
    @State private var editingAppNode: EditableNode?
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedReviewId: String?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore

    var body: some View {
        Group {
            if isLoading && detail == nil {
                LoadingView()
            } else if let err = error, detail == nil {
                ErrorView(message: err) { await load() }
            } else if let detail {
                appContent(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .handoff(title: detail?.name, url: detail?.url)
        .task {
            SoundPlayer.shared.play(.articleOpen)
            await load()
        }
    }

    @ViewBuilder
    private func appContent(_ detail: AppDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroCard(detail).padding()
                    appStoreAvailabilityNotice(detail)
                    if let recommendationSummary, recommendationSummary.count > 0 {
                        recommendationSummaryCard(recommendationSummary)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    // A second, earlier entry point to the same "Jump to
                    // First New Comment" the Community Discussion heading
                    // offers further down — for someone who just wants to
                    // see what's new without scrolling past About/ratings/
                    // App Store Info/More By to find it. Not a duplicate
                    // feature, just a second door to the same one; the
                    // heading below still has its own copy for anyone who
                    // reaches it via the reviews section directly.
                    newCommentShortcut(proxy: proxy)

                    if !aboutHTML(for: detail).isEmpty {
                        sectionHeading("About")
                        if let sourceNotice = aboutSourceNotice(for: detail) {
                            Text(sourceNotice)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                        }
                        SegmentedHTMLView(html: aboutHTML(for: detail), contentKind: "appListing", contentId: detail.id, field: "about")
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    if let vo = detail.voiceOverPerformance, !vo.isEmpty {
                        RatingGaugeView(label: "VoiceOver Performance", ratingText: vo, options: AppAccessibilityRatings.voiceOverPerformance.map(\.value))
                            .padding(.horizontal).padding(.bottom, 12)
                    }
                    if let bl = detail.buttonLabelling, !bl.isEmpty {
                        RatingGaugeView(label: "Button Labelling", ratingText: bl, options: AppAccessibilityRatings.buttonLabelling.map(\.value))
                            .padding(.horizontal).padding(.bottom, 12)
                    }
                    if let usability = detail.usabilityNotes, !usability.isEmpty {
                        RatingGaugeView(
                            label: "Usability",
                            ratingText: usability,
                            options: detail.platform == .tvos || detail.platform == .watchos
                                ? AppAccessibilityRatings.usabilitySimpleScale
                                : AppAccessibilityRatings.usabilityIOS
                        )
                            .padding(.horizontal).padding(.bottom, 12)
                    }
                    if let acc = detail.accessibilityComments, !acc.isEmpty {
                        sectionHeading("Accessibility Comments")
                        SegmentedHTMLView(html: acc, contentKind: "appListing", contentId: detail.id, field: "accessibilityComments")
                            .padding(.horizontal).padding(.bottom, 8)
                    }

                    if let meta = itunesMetadata {
                        appStoreInfoSection(detail, meta)
                    }

                    if !developerApps.isEmpty {
                        developerAppsSection(detail)
                    }

                    if preferences.aiSummariesEnabled && IntelligenceService.isAvailable && !detail.reviews.isEmpty {
                        aiSummarySection(detail)
                    }

                    reviewsSection(detail, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
            }
            .background(preferences.colors.background)
            // No focus confirmation after posting a review, unlike Forums'
            // well-implemented equivalent (ALL-04) — a VoiceOver user
            // wasn't confirmed their review posted or where it landed.
            .onChange(of: pendingFocusReviewId) { _, newId in
                guard let newId else { return }
                withReduceMotionAwareAnimation { proxy.scrollTo(newId, anchor: .bottom) }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    focusedReviewId = newId
                    pendingFocusReviewId = nil
                }
            }
            .task {
                guard focusFirstNewCommentOnAppear, !hasAppliedFirstNewCommentFocus else { return }
                hasAppliedFirstNewCommentFocus = true
                await jumpToFirstNewReview(proxy: proxy)
            }
            // See ForumTopicDetailView's identical pair for the full
            // reasoning. AppReview has no per-item "isNew" flag (only
            // Forums' ForumReply does), so "New Comments" here is the
            // newest `newReviewCount` reviews by position, not a per-item
            // check — see `newestSuffix(count:)`.
            .accessibilityRotor("New Comments") {
                ForEach(detail.reviews.newestSuffix(count: newReviewCount)) { review in
                    AccessibilityRotorEntry(review.authorName, id: review.id)
                }
            }
            .accessibilityRotor("Replies to Me") {
                ForEach(detail.reviews.filter { review in
                    guard let name = auth.user?.name else { return false }
                    return QuotedReply.isDirectedAt(name, body: review.body)
                }) { review in
                    AccessibilityRotorEntry(review.authorName, id: review.id)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let storeURL = detail.appStoreUrl.flatMap(URL.init) {
                    // Deliberately a plain Link, not WebLink — an
                    // apps.apple.com URL is a Universal Link that iOS hands
                    // straight to the native App Store app when opened
                    // externally; SFSafariViewController doesn't perform
                    // that handoff, so routing this through the in-app
                    // browser preference would trap "Open in App Store"
                    // inside a web page instead of actually opening the App
                    // Store. Downloads/purchases only work via the real
                    // native app. Reported directly. Kept as its own
                    // dedicated icon rather than folded into the actions
                    // menu below — it's this page's primary purpose, not a
                    // secondary action worth an extra tap to reach.
                    Link(destination: storeURL) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .accessibilityLabel(String(localized: "Open in App Store"))
                } else if let macUpdateURL = detail.macUpdateUrl.flatMap(URL.init) {
                    // Only ever reachable for a Mac entry with no App Store
                    // link at all — AppleVis's own fallback reference for
                    // apps not in the Mac App Store. Reported directly.
                    WebLink(destination: macUpdateURL) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .accessibilityLabel(String(localized: "Open on MacUpdate"))
                }
                DetailActionsMenu(
                    id: detail.id, entityId: detail.nid, kind: .appListing, title: detail.name, lastActivityAt: detail.lastUpdatedAt, url: detail.url,
                    authorName: detail.submittedBy, excerpt: .excerpt(from: detail.body),
                    isOwnContent: isOwnAppEntry(detail),
                    onAddComment: { showReviewCompose = true },
                    onEdit: { startEditApp(detail) },
                    onUnpublish: { await unpublishApp(detail) },
                    onDelete: { await deleteApp(detail) },
                    adminExtras: AnyView(refreshAppDetailsMenuItem(detail))
                )
            }
        }
        .sheet(isPresented: $showUpdateAppInfoSheet) {
            UpdateAppInfoSheet(
                diffs: appInfoDiffs,
                selectedFieldIDs: $selectedAppInfoFieldIDs,
                isUpdating: isUpdatingAppInformation,
                onConfirm: { Task { await updateAppInformationFromStore() } }
            )
        }
        .sheet(item: $editingAppNode) { node in
            EditNodeSheet(initialTitle: node.title, initialBody: node.body) { newTitle, newBody in
                try await saveAppEdit(nodeTypeSuffix: node.nodeTypeSuffix, title: newTitle, body: newBody)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(
                id: detail.id, entityId: detail.nid, kind: .appListing, title: detail.name, lastActivityAt: detail.lastUpdatedAt, url: detail.url,
                onAddComment: { showReviewCompose = true }
            )
        }
        .sheet(isPresented: $showReviewCompose) {
            ComposeAppReviewView(appId: detail.id, appName: detail.name, platform: detail.platform) { review in
                self.detail?.reviews.append(review)
                pendingFocusReviewId = review.id
            }
        }
        .sheet(item: $quotedReview) { target in
            ComposeAppReviewView(appId: detail.id, appName: detail.name, quotedReview: target, platform: detail.platform) { review in
                self.detail?.reviews.append(review)
                pendingFocusReviewId = review.id
            }
        }
    }

    private func canUpdateAppInformation(_ detail: AppDetail) -> Bool {
        guard auth.user?.isAdmin == true,
              itunesMetadata != nil,
              !isMatchedNotConfirmed,
              !(detail.appStoreUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        return detail.platform != .tvos
    }

    @ViewBuilder
    private func refreshAppDetailsMenuItem(_ detail: AppDetail) -> some View {
        if canUpdateAppInformation(detail), let itunesMetadata {
            Button {
                appInfoDiffs = AppInfoFieldDiff.build(detail: detail, metadata: itunesMetadata)
                selectedAppInfoFieldIDs = Set(appInfoDiffs.filter(\.changed).map(\.id))
                showUpdateAppInfoSheet = true
            } label: {
                Label(
                    isUpdatingAppInformation ? String(localized: "Refreshing App Details…") : String(localized: "Refresh App Details"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .disabled(isUpdatingAppInformation)
        }
    }

    private func isOwnAppEntry(_ detail: AppDetail) -> Bool {
        guard let user = auth.user else { return false }
        return !detail.submitterUid.isEmpty && user.uuid == detail.submitterUid
    }

    private func appNodeTypeSuffix(for platform: AppPlatform) -> String {
        switch platform {
        case .tvos:    return "tv_directory"
        case .watchos: return "watch_directory"
        case .macos:   return "mac_app_directory"
        case .ios:     return "ios_app_directory"
        }
    }

    private func startEditApp(_ detail: AppDetail) {
        editingAppNode = EditableNode(title: detail.name, body: detail.body, nodeTypeSuffix: appNodeTypeSuffix(for: detail.platform))
    }

    private func saveAppEdit(nodeTypeSuffix: String, title: String, body: String) async throws {
        guard let user = auth.user, let detail else { return }
        try await APIClient.shared.content.editNode(nodeId: detail.id, nodeType: nodeTypeSuffix, title: title, body: body, csrfToken: user.csrfToken)
        toast.success(String(localized: "App Entry updated"))
        await load()
    }

    private func unpublishApp(_ detail: AppDetail) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.unpublishNode(nodeId: detail.id, nodeType: appNodeTypeSuffix(for: detail.platform), csrfToken: user.csrfToken)
            toast.success(String(localized: "App Entry unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish."))
        }
    }

    /// Deletes the app entry the user is currently viewing — unlike
    /// row-level deletion elsewhere, there's no list to prune; the only
    /// sensible next step is leaving the screen, matching
    /// ForumTopicDetailView.deleteTopic()'s identical reasoning.
    private func deleteApp(_ detail: AppDetail) async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteNode(nodeId: detail.id, nodeType: appNodeTypeSuffix(for: detail.platform), csrfToken: user.csrfToken)
            toast.success(String(localized: "App Entry deleted"))
            dismiss()
        } catch {
            toast.error(String(localized: "Couldn't delete."))
        }
    }

    @ViewBuilder
    private func appStoreAvailabilityNotice(_ detail: AppDetail) -> some View {
        if let issue = appStoreLookupIssue,
           !(detail.appStoreUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: issue.systemImage)
                    .font(.title3)
                    .foregroundStyle(issue.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.headline)
                    Text(issue.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(issue.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(issue.title) \(issue.message)"))
        }
    }

    /// Mirrors the "Recommendations" block every app page on the site
    /// already shows (count + "most recently recommended by") — confirmed
    /// live against the Office 365 app page. Fixes the site's own singular/
    /// plural grammar slip ("1 people have recommended") along the way.
    private func recommendationSummaryCard(_ summary: RecommendationSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                summary.count == 1 ? "1 person has recommended this app" : "\(summary.count) people have recommended this app",
                systemImage: "hand.thumbsup.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)

            if let name = summary.mostRecentRecommenderName, let date = summary.mostRecentDate {
                Text("Most recently recommended by \(name), \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func newCommentShortcut(proxy: ScrollViewProxy) -> some View {
        if newReviewCount > 0 {
            Button {
                Task { await jumpToFirstNewReview(proxy: proxy) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line.compact")
                    Text("\(newReviewCount) new comment\(newReviewCount == 1 ? "" : "s") — Jump to First New Comment")
                        .font(.subheadline).fontWeight(.medium)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.accentColor)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tintedBackground(Color.accentColor, opacity: 0.1, cornerRadius: 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityLabel(String(localized: "\(newReviewCount) new comment\(newReviewCount == 1 ? "" : "s")"))
            .accessibilityHint(String(localized: "Double-tap to jump to the first new comment."))
        }
    }

    /// Apple TV directory entries have no stored icon at all (`detail.iconUrl`
    /// is always nil — see `Mappers.tvApp`) unless `matchAppleTVEntryToAppStore()`
    /// finds a confirmed match; falls back to `itunesMetadata`'s artwork in
    /// that case, same as `detail.iconUrl` would already reflect for an iOS
    /// entry via `AppDetail.enriched(with:)`.
    private func iconURL(_ detail: AppDetail) -> URL? {
        detail.iconUrl.flatMap(URL.init) ?? itunesMetadata.flatMap { URL(string: $0.artworkUrl) }
    }

    private func heroCard(_ detail: AppDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                AsyncImage(url: iconURL(detail)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(Image(systemName: "square.grid.2x2").foregroundStyle(.secondary))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

                // Category doubles as the subtitle line under the title —
                // the App Store's own short tagline isn't in the free
                // iTunes API this page already relies on for everything
                // else below, so there's nothing else authentic to put
                // here. Chosen over leaving it blank since it's real data
                // this page never actually surfaced before.
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.name).font(.title3).fontWeight(.bold)
                    if let titleNotice = appStoreTitleNotice(for: detail) {
                        Text(titleNotice).font(.caption).foregroundStyle(.secondary)
                    }
                    if !detail.category.isEmpty {
                        Text(detail.category).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(submittedAndCommentedText(detail))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(detail.name), \(detail.category), \(submittedAndCommentedText(detail))"))
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isTitleFocused)

            // Developer/Platform/Price as their own scannable rows —
            // matches the label-value "spec sheet" style App Store Info
            // already uses below, instead of the three being run together
            // into one dense inline string ("Developer · Platform · Price").
            // Each is now its own swipe stop, individually readable in
            // Braille rather than one long combined line.
            VStack(spacing: 0) {
                if !detail.developer.isEmpty { infoRow("Developer", detail.developer) }
                infoRow("Platform", detail.platform.displayName)
                if !detail.price.isEmpty { infoRow("Price", detail.price) }
                if !supportedDevicesText(detail).isEmpty { infoRow("Devices", supportedDevicesText(detail)) }
            }
            .padding(.horizontal)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            storeActionButton(detail)
        }
    }

    @ViewBuilder
    private func storeActionButton(_ detail: AppDetail) -> some View {
        if let storeURL = detail.appStoreUrl.flatMap(URL.init) {
            // Deliberately a plain Link, not WebLink — see the identical
            // reasoning on the toolbar App Store button above: this needs
            // to always hand off to the native App Store app via Universal
            // Link, which SFSafariViewController won't do.
            Link(destination: storeURL) {
                storeActionLabel(
                    title: "Open in App Store",
                    caption: "Downloads and purchases are handled by Apple.",
                    systemImage: "arrow.up.forward.app"
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Open \(detail.name) in the App Store."))
            .accessibilityHint(String(localized: "Opens the App Store listing. Downloads and purchases are handled by Apple."))
        } else if let macUpdateURL = detail.macUpdateUrl.flatMap(URL.init) {
            WebLink(destination: macUpdateURL) {
                storeActionLabel(
                    title: "Open on MacUpdate",
                    caption: "Downloads and purchases are handled outside AppleVis.",
                    systemImage: "arrow.up.forward.square"
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Open \(detail.name) on MacUpdate."))
            .accessibilityHint(String(localized: "Opens the app listing in your browser. Downloads and purchases are handled outside AppleVis."))
        }
    }

    private func storeActionLabel(title: String, caption: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
    }

    /// iTunes (when available) is the live, authoritative source for
    /// iPhone/iPad/iPod touch/Apple Watch, and — via the supplementary
    /// `confirmAppleTVSupport(for:)` check `load()` runs — Apple TV too.
    /// It still can't confirm native Mac support (a Mac Catalyst build is
    /// the only Mac signal `deviceFamilies` can see; a genuinely separate
    /// native Mac app has its own track id this lookup has no way to find),
    /// so Mac alone still falls back to AppleVis's own submitted
    /// `field_device_used` data. If iTunes metadata isn't available at all
    /// (no App Store link, match, or the lookup failed), falls back to
    /// AppleVis's raw list entirely. Previously also tried to source Apple
    /// TV from `field_device_used` too, but that option was never actually
    /// offered on the live iOS submission form (only iPhone/iPad/Mac are),
    /// so that branch could never fire from real data — removed in favor
    /// of the real, live-confirmed signal above. Reported directly.
    private func supportedDevicesText(_ detail: AppDetail) -> String {
        var families = itunesMetadata?.deviceFamilies ?? []
        guard !families.isEmpty else {
            return detail.supportedDevices.joined(separator: ", ")
        }
        let drupalLower = detail.supportedDevices.map { $0.lowercased() }
        if !families.contains("Mac"), drupalLower.contains(where: { $0.contains("mac") }) {
            families.append("Mac")
        }
        return families.joined(separator: ", ")
    }

    // A submission from 4 months ago and one commented on 3 minutes ago
    // looked identical here — nothing distinguished a stale listing from an
    // actively-discussed one. Reported directly.
    //
    // "Most recent comment" deliberately matches announceThreadOverview's
    // exact wording below rather than the earlier "last reviewed" — every
    // other place on this page (the Community Discussion heading, "Load
    // More Comments," the Thread overview announcement) already calls these
    // "comments," and "reviewed" was the one leftover from AppReview/
    // reviewCount's internal naming. Requested directly, for consistency.
    private func submittedAndCommentedText(_ detail: AppDetail) -> String {
        let submittedDate = detail.createdAt.formatted(.relative(presentation: .named))
        guard detail.reviewCount > 0 else {
            return String(localized: "Submitted \(submittedDate)")
        }
        let commentDate = detail.lastUpdatedAt.formatted(.relative(presentation: .named))
        return String(localized: "Submitted \(submittedDate), most recent comment \(commentDate)")
    }

    /// "Nov 11, 2019 (6 years ago)" — the absolute date plus the same kind
    /// of relative "ago" wording `submittedAndCommentedText` above already
    /// uses elsewhere on this page, so both read consistently.
    private static func releaseDateText(_ date: Date) -> String {
        "\(date.formatted(date: .abbreviated, time: .omitted)) (\(date.formatted(.relative(presentation: .named))))"
    }

    private func appStoreTitleNotice(for detail: AppDetail) -> String? {
        guard let appleVisTitle,
              !appleVisTitle.isEmpty,
              appleVisTitle.localizedCaseInsensitiveCompare(detail.name) != .orderedSame
        else { return nil }
        return "Current App Store title. Originally listed on AppleVis as \(appleVisTitle)."
    }

    private func appStoreInfoSection(_ detail: AppDetail, _ meta: ItunesMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("App Store Info")
            if isMatchedNotConfirmed {
                Text("Matched automatically from the App Store by name — not confirmed by AppleVis.")
                    .font(.caption)
                    .foregroundStyle(preferences.colors.warning)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            VStack(spacing: 0) {
                // Price dropped here — it's already shown once, up in the
                // hero card, and repeating it in both places was pure
                // redundancy (the two prior versions could even read
                // slightly differently, ours vs. the App Store's own).
                if !meta.version.isEmpty {
                    infoRow("Version", meta.version)
                    if let note = versionDifferenceNotice(detail: detail, meta: meta) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                    }
                }
                if let rating = meta.appStoreRating {
                    infoRow("Rating", String(format: "%.1f ★ (%d ratings)", rating, meta.appStoreRatingCount))
                }
                if !meta.minimumOsVersion.isEmpty { infoRow("Requires", "iOS \(meta.minimumOsVersion)+") }
                if !meta.languageCodes.isEmpty { infoRow("Language", meta.languageNames) }
                if !meta.ageRating.isEmpty { infoRow("Age Rating", meta.ageRating) }
                if !meta.fileSizeMb.isEmpty { infoRow("Size", meta.fileSizeMb) }
                // Apple's own `releaseDate`/`currentVersionReleaseDate` —
                // both already came back in every lookup this page already
                // makes, just never parsed or shown before. Placed last in
                // this section, right before "What's New," since a "how
                // long has this been out / how recently was it updated"
                // sense fits naturally right ahead of the actual changelog
                // text. Equal dates just mean the app hasn't been updated
                // since it first launched — expected, not an error.
                // Requested directly.
                if let releaseDate = meta.releaseDate {
                    infoRow("Released", Self.releaseDateText(releaseDate))
                }
                if let updatedDate = meta.currentVersionReleaseDate {
                    infoRow("Last Updated", Self.releaseDateText(updatedDate))
                }
            }
            .padding(.horizontal)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if !meta.releaseNotes.isEmpty {
                sectionHeading("What's New")
                Text(meta.releaseNotes)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if !meta.screenshotUrls.isEmpty {
                sectionHeading("Screenshots")
                ScrollView(.horizontal, showsIndicators: false) {
                    // LazyHStack, not HStack — each screenshot's own
                    // on-device description (below) only runs once it's
                    // actually scrolled into view, not for all of them the
                    // instant the page loads.
                    LazyHStack(spacing: 10) {
                        ForEach(Array(meta.screenshotUrls.enumerated()), id: \.offset) { index, url in
                            ScreenshotThumbnail(urlString: url, index: index, total: meta.screenshotUrls.count)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func aboutHTML(for detail: AppDetail) -> String {
        if let description = itunesMetadata?.appStoreDescription.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return Self.htmlParagraphs(fromPlainText: description)
        }
        return detail.body
    }

    private func aboutSourceNotice(for detail: AppDetail) -> String? {
        if let description = itunesMetadata?.appStoreDescription.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            if !detail.body.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Description from the current App Store listing. The original AppleVis entry may differ."
            }
            return "Description from the current App Store listing."
        }
        return detail.body.isEmpty ? nil : "Description from the AppleVis entry."
    }

    private func versionDifferenceNotice(detail: AppDetail, meta: ItunesMetadata) -> String? {
        guard let reviewed = detail.reviewedVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reviewed.isEmpty,
              !meta.version.isEmpty,
              reviewed.localizedCaseInsensitiveCompare(meta.version) != .orderedSame
        else { return nil }
        return "AppleVis originally tested version \(reviewed). Accessibility may differ in the current App Store version."
    }

    private static func htmlParagraphs(fromPlainText text: String) -> String {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "<p>\($0.htmlEscaped.replacingOccurrences(of: "\n", with: "<br>"))</p>" }
            .joined()
    }

    @ViewBuilder
    private func developerAppsSection(_ detail: AppDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("More by \(detail.developer)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(developerApps) { app in
                        if let url = URL(string: app.appStoreUrl) {
                            // Plain Link, not WebLink — same App Store
                            // Universal Link reasoning as the two buttons
                            // above.
                            Link(destination: url) {
                                VStack(spacing: 6) {
                                    AsyncImage(url: URL(string: app.artworkUrl)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.2))
                                    }
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(app.appName)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 72)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(app.appName)
                            .accessibilityHint(String(localized: "Double-tap to open in the App Store."))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    /// Two independent AI actions, both built from community reviews (not
    /// the app entry's own editorial fields — a prior "Summarize
    /// Accessibility Notes" action that just restated the already-visible
    /// VoiceOver Performance/Button Labelling/Usability/Accessibility
    /// Comments fields was removed as redundant): Consensus distills the
    /// accessibility verdict across reviews into one sentence, Community
    /// Discussion Summary is a general recap of what reviewers said.
    @ViewBuilder
    private func aiSummarySection(_ detail: AppDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            accessibilityConsensusRow(detail)
            Divider()
            reviewsSummaryRow(detail)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedBackground(Color.accentColor, opacity: 0.08, cornerRadius: 10)
        .padding(.horizontal)
    }

    /// RN's "Accessibility Consensus" — instant overview of how well an app
    /// actually works with VoiceOver across all its reviews, without
    /// reading every one. Distinct from "Community Discussion Summary"
    /// (a general recap of what reviewers said), this is framed
    /// specifically around accessibility verdict/consensus.
    @ViewBuilder
    private func accessibilityConsensusRow(_ detail: AppDetail) -> some View {
        if let accessibilityConsensus {
            VStack(alignment: .leading, spacing: 4) {
                Label("Accessibility Consensus", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.accentColor)
                Text(accessibilityConsensus).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizeAccessibilityConsensus(detail) }
            } label: {
                if isSummarizingConsensus {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Accessibility Consensus", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizingConsensus)
            .accessibilityLabel(String(localized: isSummarizingConsensus ? "Summarizing accessibility consensus, please wait" : "Accessibility Consensus"))
            .accessibilityHint(String(localized: "Aggregates comments into one sentence about how well this app works with VoiceOver."))
        }
    }

    @ViewBuilder
    private func reviewsSummaryRow(_ detail: AppDetail) -> some View {
        if let reviewsSummary {
            VStack(alignment: .leading, spacing: 4) {
                Label("Community Discussion Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.accentColor)
                Text(reviewsSummary).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizeReviews(detail) }
            } label: {
                if isSummarizingReviews {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Summarize Community Discussion", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizingReviews)
            .accessibilityLabel(String(localized: isSummarizingReviews ? "Summarizing community discussion, please wait" : "Summarize Community Discussion"))
        }
    }

    /// Both AI summary features previously fed the model a rigid "first 20
    /// reviews" slice — `detail.reviews` is fetched `sort: -created`, so
    /// this was already the 20 *newest* reviews, not oldest (recency was
    /// never actually the gap). The real gap: no filtering by substance, so
    /// a run of quick "Great app!" one-liners in the most recent 20 could
    /// crowd out genuinely useful accessibility feedback sitting just past
    /// that window, before the AI ever saw it. Widens the candidate window
    /// to the newest `candidatePool` reviews, drops ones too short to carry
    /// real signal, then takes the newest `limit` that remain — falling
    /// back to the unfiltered pool if literally everything in it is short,
    /// so a summary is still attempted rather than run on nothing.
    private func substantiveReviews(_ reviews: [AppReview], limit: Int = 20, candidatePool: Int = 50, minLength: Int = 15) -> [AppReview] {
        let pool = Array(reviews.prefix(candidatePool))
        let substantive = pool.filter { $0.body.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines).count >= minLength }
        return Array((substantive.isEmpty ? pool : substantive).prefix(limit))
    }

    private func summarizeAccessibilityConsensus(_ detail: AppDetail) async {
        isSummarizingConsensus = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing accessibility consensus. This may take a moment.")
        let maxTotalCharacters = 3000
        let maxPerReview = 220
        var parts: [String] = []
        var remaining = maxTotalCharacters
        for review in substantiveReviews(detail.reviews) {
            guard remaining > 0 else { break }
            let body = review.body.strippingHTMLTags().prefix(maxPerReview)
            let part = "\(review.authorName): \(body)"
            parts.append(String(part.prefix(remaining)))
            remaining -= part.count
        }
        let input = "App: \(detail.name)\n\n\(parts.joined(separator: "\n\n"))"
        if let consensus = await IntelligenceService.accessibilityConsensus(input) {
            accessibilityConsensus = consensus
        } else {
            toast.error(String(localized: "Couldn't generate an accessibility consensus. Try again."))
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate an accessibility consensus.")
        }
        isSummarizingConsensus = false
    }

    private func summarizeReviews(_ detail: AppDetail) async {
        isSummarizingReviews = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing community discussion. This may take a moment.")
        let maxTotalCharacters = 3000
        let maxPerReview = 220
        var parts: [String] = []
        var remaining = maxTotalCharacters
        for review in substantiveReviews(detail.reviews) {
            guard remaining > 0 else { break }
            let body = review.body.strippingHTMLTags().prefix(maxPerReview)
            let part = "\(review.authorName): \(body)"
            parts.append(String(part.prefix(remaining)))
            remaining -= part.count
        }
        let input = "App: \(detail.name)\n\n\(parts.joined(separator: "\n\n"))"
        if let summary = await IntelligenceService.summarize(input) {
            reviewsSummary = summary
        } else {
            toast.error(String(localized: "Couldn't generate a discussion summary. Try again."))
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate a discussion summary.")
        }
        isSummarizingReviews = false
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func reviewsSection(_ detail: AppDetail, proxy: ScrollViewProxy) -> some View {
        CommunityDiscussionHeading(
            count: detail.reviewCount,
            onThreadOverview: { announceThreadOverview(detail) },
            onJumpToLast: { Task { await jumpToLastReview(proxy: proxy) } },
            newCount: newReviewCount,
            onJumpToFirstNew: { Task { await jumpToFirstNewReview(proxy: proxy) } }
        )

        if detail.reviews.isEmpty {
            Text("No comments yet — be the first!")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 8)
        } else {
            ForEach(Array(detail.reviews.enumerated()), id: \.element.id) { index, review in
                AppReviewRow(
                    review: review, index: index + 1, total: detail.reviews.count,
                    onDelete: {
                        self.detail?.reviews.removeAll { $0.id == review.id }
                    },
                    onEdit: { newText in
                        guard let idx = self.detail?.reviews.firstIndex(where: { $0.id == review.id }) else { return }
                        self.detail?.reviews[idx] = AppReview(
                            id: review.id, subject: review.subject, authorName: review.authorName,
                            authorId: review.authorId, rating: review.rating, body: newText, createdAt: review.createdAt
                        )
                    },
                    onReplyTo: {
                        guard auth.isSignedIn else {
                            toast.warning(String(localized: "Sign in to reply to comments."))
                            return
                        }
                        quotedReview = review
                    },
                    parentTitle: detail.name,
                    parentURL: detail.url,
                    focusBinding: $focusedReviewId
                )
                .id(review.id)
                if index < detail.reviews.count - 1 {
                    Divider().padding(.leading)
                }
            }

            if hasMoreReviews {
                if isLoadingMoreReviews {
                    ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…")).padding()
                } else {
                    let remaining = detail.reviewCount - detail.reviews.count
                    Button(remaining > 0 ? "Load \(remaining) More Comments" : "Load More Comments") {
                        Task { await ensureAllReviewsLoaded() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }

    /// VoiceOver "Thread overview" custom action on the reviews heading —
    /// a spoken summary in place of manually reading through every review.
    private func announceThreadOverview(_ detail: AppDetail) {
        let mostRecent = detail.reviews.max { $0.createdAt < $1.createdAt }
        var summary = "Thread has \(detail.reviews.count) comment\(detail.reviews.count == 1 ? "" : "s")."
        if let mostRecent {
            summary += " Most recent comment by \(mostRecent.authorName), \(mostRecent.createdAt.formatted(.relative(presentation: .named)))."
        }
        summary += " Submitted by \(detail.submittedBy)."
        UIAccessibility.post(notification: .announcement, argument: summary)
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            detail = try await APIClient.shared.apps.detail(id: appId, platform: platform)
            appleVisTitle = detail?.name
            itunesMetadata = nil
            appStoreLookupIssue = nil
            developerApps = []
            isMatchedNotConfirmed = false
            hasMoreReviews = (detail?.reviews.count ?? 0) < (detail?.reviewCount ?? 0)
            if hasMoreReviews {
                Task { await ensureAllReviewsLoaded() }
            }
            // Backgrounded like confirmAppleTVSupport below — supplementary,
            // shouldn't delay the rest of the page.
            if let appId = detail?.id {
                Task { recommendationSummary = try? await APIClient.shared.flags.recommendationSummary(appUuid: appId) }
            }
            if let storeUrl = detail?.appStoreUrl, !storeUrl.isEmpty {
                // Mac apps can be a genuine, separate Mac App Store listing
                // or a Catalyst app sharing its iOS listing — `fetchMacMetadata`
                // tries both (see `ItunesAPI.fetchMacMetadata`). Every
                // other platform's stored link only ever needs the one
                // fixed entity `fetchMetadata`'s default already uses.
                let lookupResult = detail?.platform == .macos
                    ? await ItunesAPI.lookupMacMetadata(appStoreUrl: storeUrl)
                    : await ItunesAPI.lookupMetadata(appStoreUrl: storeUrl)
                switch lookupResult {
                case .found(let meta):
                    itunesMetadata = meta
                case .notFound:
                    appStoreLookupIssue = .notFound
                case .invalidLink:
                    appStoreLookupIssue = .invalidLink
                case .failed:
                    appStoreLookupIssue = .failed
                }
                if let meta = itunesMetadata, let current = detail {
                    detail = current.enriched(with: meta)
                }
                if let artistId = itunesMetadata?.artistId, let appStoreId = itunesMetadata?.appStoreId {
                    developerApps = await ItunesAPI.fetchDeveloperApps(artistId: artistId, excluding: appStoreId)
                }
                // Supplementary, non-blocking: confirms whether this same,
                // already-resolved App Store id also has a real Apple TV
                // build, via a second lookup on the identical id (not a
                // name guess — the id is already fixed) so the Devices row
                // can show "Apple TV" when it's actually true. Backgrounded
                // rather than awaited inline so a slow check can't delay
                // the rest of the page. Reported directly: previously
                // "Apple TV" could only ever come from AppleVis's own
                // submitted device checkboxes, which don't even offer an
                // Apple TV option on the live iOS submission form, so this
                // could never actually fire from real data.
                if let appStoreId = itunesMetadata?.appStoreId {
                    Task { await confirmAppleTVSupport(for: appStoreId) }
                }
            } else if detail?.platform == .tvos {
                // Apple TV directory entries store no App Store link at
                // all — the live submission form never asks for one (see
                // `Mappers.tvApp`). Backgrounded for the same reason as
                // above: this is a multi-step, best-effort lookup, not
                // something the rest of the page should wait on.
                Task { await matchAppleTVEntryToAppStore() }
            }
            if let detail {
                // Captured before stampItemVisit below overwrites it —
                // same fix already applied to Podcasts' equivalent (ALL-01).
                newReviewCount = PersistenceStore.shared.newReplyCount(
                    kind: .appListing, id: detail.id, currentCount: detail.reviewCount
                )
                PersistenceStore.shared.stampItemVisit(
                    id: FeedItem.visitKey(kind: .appListing, contentId: detail.id),
                    commentCount: detail.reviewCount
                )
                // Keeps the website's own "read" state (Drupal core's
                // History module) in sync with what's viewed in the app —
                // signed-out users still rely on the local stamp above only.
                if let csrfToken = auth.user?.csrfToken {
                    Task { await APIClient.shared.history.markRead(nid: detail.nid, csrfToken: csrfToken) }
                }
                SpotlightIndexer.index(AppListing(
                    id: detail.id, name: detail.name, developer: detail.developer, platform: detail.platform,
                    category: detail.category, categoryId: detail.categoryId, reviewCount: detail.reviewCount,
                    lastUpdatedAt: detail.lastUpdatedAt, lastActivityAt: detail.lastUpdatedAt, createdAt: detail.createdAt,
                    submittedBy: detail.submittedBy, submitterUid: detail.submitterUid, appStoreUrl: detail.appStoreUrl,
                    iconUrl: detail.iconUrl, price: detail.price, supportedDevices: detail.supportedDevices,
                    voiceOverPerformance: detail.voiceOverPerformance, summary: detail.body, url: detail.url, isSaved: false
                ))
            }
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load app." }
        isLoading = false
        focusTitleAfterLoad()
    }

    private func confirmAppleTVSupport(for appStoreId: String) async {
        guard await ItunesAPI.fetchTvOSSupport(appStoreId: appStoreId) != nil,
              let current = itunesMetadata
        else { return }
        itunesMetadata = current.addingDeviceFamily("Apple TV")
    }

    /// Apple TV directory entries store no App Store link at all — a
    /// best-effort substitute for the enrichment iOS entries get from
    /// their real, stored link. Searches for an app with this entry's
    /// exact title, and only uses the result if there's exactly one
    /// exact-title match AND that specific candidate is independently
    /// confirmed — via `fetchTvOSSupport`, a real API check on that
    /// candidate's own id, not a guess — to actually have an Apple TV
    /// build. Deliberately never touches `detail` itself: AppleVis's own
    /// curated name/category/price/usability/comments stay exactly as
    /// submitted and reviewed; only supplementary display data (icon,
    /// screenshots, version, size, "More by" apps) comes from this match,
    /// and `isMatchedNotConfirmed` drives a visible caveat in
    /// `appStoreInfoSection` so it's never presented as something AppleVis
    /// itself verified. Discussed and confirmed directly — rejected doing
    /// this via App Store scraping, and rejected a weaker "just take the
    /// top search result" version of this same idea before this two-step
    /// verification (confirmed-real-tvOS-app, not merely name-matched)
    /// was worked out.
    private func matchAppleTVEntryToAppStore() async {
        guard let name = detail?.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let candidates = await ItunesAPI.searchTvOS(name, limit: 10)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactMatches = candidates.filter {
            $0.appName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
        guard exactMatches.count == 1, let match = exactMatches.first,
              let meta = await ItunesAPI.fetchTvOSSupport(appStoreId: match.appStoreId)
        else { return }
        itunesMetadata = meta
        isMatchedNotConfirmed = true
        if let artistId = meta.artistId {
            developerApps = await ItunesAPI.fetchDeveloperApps(artistId: artistId, excluding: meta.appStoreId)
        }
    }

    /// Loads every remaining page in one go instead of requiring a tap per
    /// page — same fix already applied to Forum/Blog/Guide/Podcast comments.
    /// Reviews previously had no pagination at all (not even manual "Load
    /// More"): an app with more than 100 reviews permanently hid the rest.
    private func loadMoreReviews() async {
        isLoadingMoreReviews = true
        do {
            while let current = self.detail, current.reviews.count < current.reviewCount {
                let more = try await APIClient.shared.apps.moreReviews(appId: current.id, offset: current.reviews.count, platform: current.platform)
                guard !more.isEmpty else { break }
                self.detail?.reviews.append(contentsOf: more)
            }
        } catch {
            toast.error(String(localized: "Couldn't load more comments."))
        }
        hasMoreReviews = (self.detail?.reviews.count ?? 0) < (self.detail?.reviewCount ?? 0)
        isLoadingMoreReviews = false
    }

    /// Single-flight wrapper around loadMoreReviews() — see
    /// loadAllReviewsTask's doc comment for why this exists.
    private func ensureAllReviewsLoaded() async {
        if let existing = loadAllReviewsTask {
            await existing.value
            return
        }
        let task = Task { await loadMoreReviews() }
        loadAllReviewsTask = task
        await task.value
        loadAllReviewsTask = nil
    }

    /// Updates AppleVis's store-owned app fields from the confirmed App
    /// Store listing while leaving community accessibility data untouched.
    private func updateAppInformationFromStore() async {
        guard let current = detail,
              let metadata = itunesMetadata,
              let user = auth.user,
              user.isAdmin
        else {
            toast.error(String(localized: "You need to be signed in as an editor to refresh app details."))
            return
        }
        guard !isMatchedNotConfirmed else {
            toast.error(String(localized: "This App Store match is not confirmed, so AppleVis was not updated."))
            return
        }
        guard !selectedAppInfoFieldIDs.isEmpty else { return }

        isUpdatingAppInformation = true
        defer { isUpdatingAppInformation = false }

        do {
            try await APIClient.shared.apps.updateAppInformation(
                detail: current, metadata: metadata, includedFields: selectedAppInfoFieldIDs, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "App details refreshed"))
            showUpdateAppInfoSheet = false
            await load()
        } catch APIError.forbidden {
            toast.error(String(localized: "You don't have permission to refresh this app."))
        } catch APIError.unauthorized {
            toast.error(String(localized: "Please sign in again to refresh this app."))
        } catch {
            toast.error(String(localized: "We couldn't refresh the app details."))
        }
    }

    private func jumpToLastReview(proxy: ScrollViewProxy) async {
        if hasMoreReviews { await ensureAllReviewsLoaded() }
        guard let lastId = self.detail?.reviews.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedReviewId = lastId
    }

    /// "Jump to First New Comment" (ALL-01) — reviews arrive chronologically
    /// oldest-first (matches "Jump to Last" scrolling to `.last`), so the
    /// first of the `newReviewCount` most recently posted reviews sits at
    /// `reviews.count - newReviewCount`.
    private func jumpToFirstNewReview(proxy: ScrollViewProxy) async {
        if hasMoreReviews { await ensureAllReviewsLoaded() }
        let reviews = self.detail?.reviews ?? []
        let targetIndex = reviews.count - newReviewCount
        guard newReviewCount > 0, targetIndex >= 0, targetIndex < reviews.count else { return }
        let targetId = reviews[targetIndex].id
        withReduceMotionAwareAnimation { proxy.scrollTo(targetId, anchor: .top) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedReviewId = targetId
    }

    /// VoiceOver lands on the back button after push navigation by default;
    /// this moves it to the page heading instead, per
    /// docs/IMPLEMENTATION_NOTES.md's "VoiceOver Detail Page Navigation"
    /// guidance. Retries at each delay rather than a single guessed one —
    /// a single attempt could silently go nowhere on a slower device or
    /// slower load. Reported directly.
    private func focusTitleAfterLoad() {
        Task {
            await retryAccessibilityFocus(into: $isTitleFocused)
        }
    }
}

private extension AppDetail {
    func enriched(with meta: ItunesMetadata) -> AppDetail {
        AppDetail(
            id: id,
            nid: nid,
            name: meta.appName.isEmpty ? name : meta.appName,
            developer: meta.developerName.isEmpty ? developer : meta.developerName,
            platform: platform,
            category: meta.category.isEmpty ? category : meta.category,
            categoryId: categoryId,
            reviewCount: reviewCount,
            lastUpdatedAt: lastUpdatedAt,
            createdAt: createdAt,
            submittedBy: submittedBy,
            submitterUid: submitterUid,
            appStoreUrl: meta.appStoreUrl.isEmpty ? appStoreUrl : meta.appStoreUrl,
            iconUrl: meta.artworkUrl.isEmpty ? iconUrl : meta.artworkUrl,
            price: meta.price.isEmpty ? price : meta.price,
            supportedDevices: supportedDevices,
            voiceOverPerformance: voiceOverPerformance,
            buttonLabelling: buttonLabelling,
            usabilityNotes: usabilityNotes,
            body: body,
            reviewedVersion: reviewedVersion,
            testedOnIOS: testedOnIOS,
            accessibilityComments: accessibilityComments,
            url: url,
            reviews: reviews,
            isSaved: isSaved
        )
    }
}

// MARK: - Screenshot thumbnail

/// One screenshot in the horizontal strip — previously just "Screenshot N
/// of M" with no indication of what's actually in the image, which tells a
/// VoiceOver user nothing a sighted person glancing at the same thumbnail
/// doesn't get for free. Reuses the same on-device Vision description
/// (`ImageDescriber`) already used for podcast artwork on the episode
/// detail screen; its own `.task` only fires once this view actually
/// appears, which `LazyHStack` at the call site only does once it's
/// scrolled into view — not eagerly for every screenshot on page load.
private struct ScreenshotThumbnail: View {
    let urlString: String
    let index: Int
    let total: Int
    @State private var description: String?

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.15))
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(description == nil)
        .accessibilityLabel(description.map { String(localized: "Screenshot \(index + 1) of \(total): \($0)") } ?? "")
        .task {
            guard let url = URL(string: urlString) else { return }
            description = await ImageDescriber.describe(imageAt: url)
        }
    }
}

// MARK: - Review row

struct AppReviewRow: View {
    let review: AppReview
    let index: Int
    let total: Int
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    var onReplyTo: (() -> Void)? = nil
    var parentTitle: String = ""
    var parentURL: String = ""
    /// Optional review focus target used after jumping or posting so
    /// VoiceOver focus lands here, not just scrolls the viewport.
    var focusBinding: AccessibilityFocusState<String?>.Binding? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    @State private var showReportSheet = false

    private var reportContext: ReportCommentContext {
        ReportCommentContext(
            authorName: review.authorName,
            commentExcerpt: .excerpt(from: review.body),
            commentDate: review.createdAt,
            contentTitle: parentTitle,
            contentURL: parentURL
        )
    }

    private var canDelete: Bool {
        guard let user = auth.user else { return false }
        return user.isAdmin || (!review.authorId.isEmpty && user.uuid == review.authorId)
    }

    private var displayedSubject: String? {
        CommentSubject.display(review.subject, parentTitle: parentTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // A separate header/body split, not one combined element covering
            // the whole card — matches every other comment type in the app
            // (docs/IMPLEMENTATION_NOTES.md: render an actionable header, then
            // a separate readable body, so VoiceOver output stays short and
            // Braille navigation stays predictable). This previously put the
            // full review body inside the same accessibility label as the
            // header, unlike ForumReply/CommentRow.
            HStack {
                // Author names were inert plain Text everywhere except
                // Forums, despite authorId already being available — a
                // VoiceOver user had no equivalent to a sighted user's
                // "tap the name to see who this is" (APPS-05). Matches
                // Forums' ReplyView, which already puts AuthorProfileButton
                // inside this exact combine+explicit-label header structure.
                AuthorProfileButton(name: review.authorName, authorId: review.authorId, showAvatar: true)
                Spacer()
                RelativeDateLabel(date: review.createdAt)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "Comment \(index) of \(total) by \(review.authorName). ") +
                (review.rating.map { String(localized: "\($0) out of 5 stars. ") } ?? "") +
                (displayedSubject.map { String(localized: "Subject: \($0).") } ?? "")
            )
            .modifier(OptionalReplyFocus(binding: focusBinding, id: review.id))
            .readAloudAction(review.body.strippingHTMLTags())
            // "Comment" throughout, matching Forums/Blogs/Bugs' shared
            // wording (and the rest of this feature, including Edit/Delete
            // below) — app reviews are presented as comments everywhere in
            // the UI now; "review"/"Review" only survives in internal type
            // and property names (AppReview, detail.reviews).
            .modifier(ConditionalAccessibilityAction(isActive: onReplyTo != nil, name: "Reply to this Comment") { onReplyTo?() })
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { presentShareSheet() }
            .accessibilityAction(named: Text("Mark as Helpful")) {
                toast.warning(String(localized: "Helpful votes are coming once the Drupal Flags API is confirmed."))
            }
            .accessibilityAction(named: Text("Report Comment")) {
                showReportSheet = true
            }
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Edit Comment") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Delete Comment") { showDeleteConfirm = true })

            if let displayedSubject {
                Text(displayedSubject).font(.subheadline).fontWeight(.medium)
                    .accessibilityHidden(true)
            }

            if let rating = review.rating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.caption).foregroundStyle(Color.yellow)
                    }
                }
                .accessibilityHidden(true)
            }

            SegmentedHTMLView(html: review.body, contentKind: "review", contentId: review.id, field: "body")
        }
        .padding()
        .contextMenu {
            // Mirrors the accessibility actions above exactly — those used
            // to be VoiceOver-only, which meant a sighted or low-vision
            // user doing an ordinary long-press saw none of them.
            if onReplyTo != nil {
                Button { onReplyTo?() } label: {
                    Label("Reply to this Comment", systemImage: "arrowshape.turn.up.left")
                }
            }
            Button { copyText() } label: {
                Label("Copy Comment Text", systemImage: "doc.on.doc")
            }
            Button { presentShareSheet() } label: {
                Label("Share Comment", systemImage: "square.and.arrow.up")
            }
            Button { toast.warning(String(localized: "Helpful votes are coming once the Drupal Flags API is confirmed.")) } label: {
                Label("Mark as Helpful", systemImage: "hand.thumbsup")
            }
            Button { showReportSheet = true } label: {
                Label("Report Comment", systemImage: "flag")
            }
            if canDelete {
                Button { showEditSheet = true } label: {
                    Label("Edit Comment", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportCommentWizard(context: reportContext)
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(title: "Edit Comment", initialText: review.body) { newText in
                guard let user = auth.user else { return }
                try await APIClient.shared.content.editComment(
                    commentType: "comment_node_ios_app_directory", commentId: review.id, newBody: newText, format: drupalDefaultTextFormat, csrfToken: user.csrfToken
                )
                onEdit?(newText)
                toast.success(String(localized: "Comment updated"))
            }
        }
    }

    private func delete() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteComment(
                commentType: "comment_node_ios_app_directory", commentId: review.id, csrfToken: user.csrfToken
            )
            onDelete?()
            toast.success(String(localized: "Comment deleted"))
        } catch {
            toast.error(String(localized: "Couldn't delete comment."))
        }
    }

    private func copyText() {
        UIPasteboard.general.string = review.body.strippingHTMLTags()
        toast.success(String(localized: "Comment text copied"))
    }

    private func presentShareSheet() {
        let plain = review.body.strippingHTMLTags()
        let subject = review.subject.trimmingCharacters(in: .whitespaces)
        var message = "\(review.authorName) on AppleVis"
        if !subject.isEmpty { message += ":\n\nSubject: \(subject)" }
        message += "\n\n\(plain)"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }
}

// MARK: - Accessibility rating gauge

/// A rating's position within its field's real, fixed vocabulary
/// (`AppAccessibilityRatings`) — index 0 is the best outcome in that
/// field's own list, the last index the worst; the gauge's fill and color
/// are derived from that position, generically, for any of the four rating
/// fields (VoiceOver Performance, Button Labelling, iOS/macOS Usability,
/// Apple TV Usability) rather than one hardcoded scale.
///
/// Previously this assumed every rating was one of four fixed words —
/// "Excellent"/"Good"/"Fair"/"Poor" — a vocabulary that doesn't match a
/// single value either content type actually stores (real values are full
/// sentences, e.g. "VoiceOver reads most page elements." or "The app is
/// totally inaccessible."). Every real rating silently fell back to the
/// "unrecognized value" plain-text branch below, meaning the gauge itself
/// never actually rendered for a real app entry. Reported directly.
struct AppRatingLevel {
    let position: Double // 0.0 (worst) ... 1.0 (best)
    let color: Color

    init?(text: String, options: [String]) {
        guard options.count > 1, let index = options.firstIndex(of: text) else { return nil }
        position = Double(options.count - 1 - index) / Double(options.count - 1)
        color = Self.color(for: position)
    }

    private static func color(for position: Double) -> Color {
        switch position {
        case 0.75...: return Color(red: 0.133, green: 0.773, blue: 0.369)
        case 0.5..<0.75: return Color(red: 0.518, green: 0.800, blue: 0.086)
        case 0.25..<0.5: return Color(red: 0.961, green: 0.620, blue: 0.043)
        default: return Color(red: 0.937, green: 0.267, blue: 0.267)
        }
    }
}

struct RatingGaugeView: View {
    let label: String
    let ratingText: String
    /// The full option list for this field, ordered best (index 0) to
    /// worst — e.g. `AppAccessibilityRatings.voiceOverPerformance.map(\.value)`.
    /// Deliberately excludes "Not applicable for this app" (present on
    /// VoiceOver/Labelling): that's not a point on a good-to-bad scale, so
    /// it's shown as plain text via the "unrecognized value" branch below
    /// rather than forced into a misleading position on the gauge.
    let options: [String]

    var body: some View {
        if let level = AppRatingLevel(text: ratingText, options: options) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 8)
                        Capsule().fill(level.color).frame(width: max(geo.size.width * level.position, 8), height: 8)
                    }
                }
                .frame(height: 8)
                // The rating text itself is already a full, plain-language
                // sentence — unlike the old fictional "Excellent"/"Good"
                // words, it needs no separate paraphrased description
                // underneath, just a color cue tying it to the gauge above.
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(level.color).frame(width: 8, height: 8)
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                    Text(ratingText).font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(label): \(ratingText)"))
        } else {
            // Unrecognized value (or "Not applicable for this app") — shown
            // as plain text rather than silently dropped or forced onto a
            // misleading gauge position.
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased()).font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                Text(ratingText).font(.subheadline)
            }
        }
    }
}

// MARK: - Compose app review

struct ComposeAppReviewView: View {
    let appId: String
    let appName: String
    var quotedReview: AppReview? = nil
    let platform: AppPlatform
    let onPosted: (AppReview) -> Void

    @State private var subject = ""
    @State private var reviewText: String
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    /// Unlike its sibling compose sheets (New Topic, Reply), this one had no
    /// focus management at all — opening it left VoiceOver focus on system
    /// default. Full app-wide focus audit, requested directly.
    @AccessibilityFocusState private var isHeaderFocused: Bool

    init(appId: String, appName: String, quotedReview: AppReview? = nil, platform: AppPlatform, onPosted: @escaping (AppReview) -> Void) {
        self.appId = appId
        self.appName = appName
        self.quotedReview = quotedReview
        self.platform = platform
        self.onPosted = onPosted
        if let quotedReview {
            _reviewText = State(initialValue: QuotedReply.prefix(authorName: quotedReview.authorName, body: quotedReview.body))
        } else {
            _reviewText = State(initialValue: "")
        }
    }

    // AppleVis's review comment bundle has no rating field on the backend —
    // only a subject and body — so there's no star-rating input here; adding
    // one would silently discard whatever the user picked.
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(quotedReview != nil ? "Replying to \(quotedReview!.authorName) — Commenting on: \(appName)" : "Commenting on: \(appName)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal).padding(.top)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isHeaderFocused)
                TextField("Subject (optional)", text: $subject)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                if intelligence.showTranslatePrompt {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: subject, body: reviewText, isTopic: false) {
                                subject = result.subject ?? subject
                                reviewText = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                    .padding(.horizontal)
                }
                if let warning = guidelines.topWarning {
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: subject, body: reviewText, isTopic: false) {
                                    reviewText = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                        .padding(.horizontal)
                }
                TextEditor(text: $reviewText)
                    .padding()
                    .onChange(of: reviewText) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                if let err = submitError {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(reviewText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: subject,
            body: reviewText
        ) {
            submitError = message
            return
        }
        isSubmitting = true; submitError = nil
        do {
            let review = try await APIClient.shared.apps.submitReview(
                appId: appId, subject: subject, body: reviewText, csrfToken: user.csrfToken, platform: platform
            )
            toast.success(String(localized: "Comment posted"))
            onPosted(review)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Couldn't post comment. Try again." }
        isSubmitting = false
    }
}
