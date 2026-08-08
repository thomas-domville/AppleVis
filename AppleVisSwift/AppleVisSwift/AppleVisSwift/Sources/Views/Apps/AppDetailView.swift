import SwiftUI
import UIKit

struct AppDetailView: View {
    let appId: String
    @State private var detail: AppDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showReviewCompose = false
    @State private var quotedReview: AppReview?
    @State private var itunesMetadata: ItunesMetadata?
    @State private var developerApps: [ItunesDeveloperApp] = []
    @State private var isLoadingMoreReviews = false
    @State private var hasMoreReviews = true
    @State private var accessibilitySummary: String?
    @State private var isSummarizingAccessibility = false
    @State private var reviewsSummary: String?
    @State private var isSummarizingReviews = false
    @State private var accessibilityConsensus: String?
    @State private var isSummarizingConsensus = false
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

                    if let meta = itunesMetadata {
                        appStoreInfoSection(meta)
                    }

                    if !developerApps.isEmpty {
                        developerAppsSection(detail)
                    }

                    if !detail.body.isEmpty {
                        sectionHeading("About")
                        SegmentedHTMLView(html: detail.body)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    if let vo = detail.voiceOverPerformance, !vo.isEmpty {
                        RatingGaugeView(label: "VoiceOver Performance", ratingText: vo, category: .voiceOver)
                            .padding(.horizontal).padding(.bottom, 12)
                    }
                    if let bl = detail.buttonLabelling, !bl.isEmpty {
                        RatingGaugeView(label: "Button Labelling", ratingText: bl, category: .buttonLabeling)
                            .padding(.horizontal).padding(.bottom, 12)
                    }
                    if let usability = detail.usabilityNotes, !usability.isEmpty {
                        RatingGaugeView(label: "Usability", ratingText: usability, category: .usability)
                            .padding(.horizontal).padding(.bottom, 12)
                    }
                    if let acc = detail.accessibilityComments, !acc.isEmpty {
                        sectionHeading("Accessibility Comments")
                        SegmentedHTMLView(html: acc)
                            .padding(.horizontal).padding(.bottom, 8)
                    }

                    if preferences.aiSummariesEnabled && IntelligenceService.isAvailable {
                        aiSummarySection(detail)
                    }

                    reviewsSection(detail, proxy: proxy)

                    Color.clear.frame(height: 40)
                }
            }
            .background(preferences.colors.background)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let storeURL = detail.appStoreUrl.flatMap(URL.init) {
                    Link(destination: storeURL) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .accessibilityLabel(String(localized: "Open in App Store"))
                }
                if auth.isSignedIn {
                    Button { showReviewCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(String(localized: "Write review"))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(id: detail.id, kind: .appListing, title: detail.name, lastActivityAt: detail.lastUpdatedAt, url: detail.url)
        }
        .sheet(isPresented: $showReviewCompose) {
            ComposeAppReviewView(appId: detail.id, appName: detail.name) { review in
                self.detail?.reviews.append(review)
            }
        }
        .sheet(item: $quotedReview) { target in
            ComposeAppReviewView(appId: detail.id, appName: detail.name, quotedReview: target) { review in
                self.detail?.reviews.append(review)
            }
        }
    }

    private func heroCard(_ detail: AppDetail) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: detail.iconUrl.flatMap(URL.init)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(Image(systemName: "square.grid.2x2").foregroundStyle(.secondary))
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.name).font(.title3).fontWeight(.bold)
                Text(detail.developer).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label(detail.platform.displayName, systemImage: "iphone")
                    if !detail.price.isEmpty {
                        Text("·")
                        Text(detail.price)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(detail.name) by \(detail.developer), \(detail.platform.displayName), \(detail.price)"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($isTitleFocused)
    }

    private func appStoreInfoSection(_ meta: ItunesMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("App Store Info")
            VStack(spacing: 0) {
                if !meta.version.isEmpty { infoRow("Version", meta.version) }
                if !meta.price.isEmpty { infoRow("Price", meta.price) }
                if let rating = meta.appStoreRating {
                    infoRow("Rating", String(format: "%.1f ★ (%d ratings)", rating, meta.appStoreRatingCount))
                }
                if !meta.fileSizeMb.isEmpty { infoRow("Size", meta.fileSizeMb) }
                if !meta.minimumOsVersion.isEmpty { infoRow("Requires", "iOS \(meta.minimumOsVersion)+") }
                if !meta.ageRating.isEmpty { infoRow("Age Rating", meta.ageRating) }
            }
            .padding(.horizontal)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if !meta.releaseNotes.isEmpty {
                Text("What's New")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal).padding(.top, 8)
                Text(meta.releaseNotes)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if !meta.screenshotUrls.isEmpty {
                Text("Screenshots")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal).padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(meta.screenshotUrls.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.15))
                            }
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel(String(localized: "Screenshot \(index + 1) of \(meta.screenshotUrls.count)"))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func developerAppsSection(_ detail: AppDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("More by \(detail.developer)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(developerApps) { app in
                        if let url = URL(string: app.appStoreUrl) {
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

    /// Two independent AI actions, matching the old app: one digests the
    /// accessibility fields (VoiceOver Performance/Button Labelling/
    /// Usability/Accessibility Comments) into a plain-language blurb, the
    /// other digests the community reviews — previously AppDetailView had
    /// no Apple Intelligence integration at all despite it being built into
    /// Forums, Discover, and every compose screen elsewhere in the app.
    @ViewBuilder
    private func aiSummarySection(_ detail: AppDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            accessibilitySummaryRow(detail)
            if !detail.reviews.isEmpty {
                Divider()
                accessibilityConsensusRow(detail)
                Divider()
                reviewsSummaryRow(detail)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedBackground(Color.accentColor, opacity: 0.08, cornerRadius: 10)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func accessibilitySummaryRow(_ detail: AppDetail) -> some View {
        if let accessibilitySummary {
            VStack(alignment: .leading, spacing: 4) {
                Label("Accessibility Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold).foregroundStyle(Color.accentColor)
                Text(accessibilitySummary).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizeAccessibility(detail) }
            } label: {
                if isSummarizingAccessibility {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Summarize Accessibility Notes", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizingAccessibility)
            .accessibilityLabel(String(localized: isSummarizingAccessibility ? "Summarizing accessibility notes, please wait" : "Summarize Accessibility Notes"))
        }
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
            .accessibilityHint(String(localized: "Aggregates reviews into one sentence about how well this app works with VoiceOver."))
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

    private func summarizeAccessibility(_ detail: AppDetail) async {
        isSummarizingAccessibility = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing accessibility notes. This may take a moment.")
        var parts: [String] = []
        if let vo = detail.voiceOverPerformance, !vo.isEmpty { parts.append("VoiceOver Performance: \(vo)") }
        if let bl = detail.buttonLabelling, !bl.isEmpty { parts.append("Button Labelling: \(bl)") }
        if let usability = detail.usabilityNotes, !usability.isEmpty { parts.append("Usability: \(usability)") }
        if let acc = detail.accessibilityComments, !acc.isEmpty { parts.append(acc.strippingHTMLTags().prefix(2000).description) }
        let input = "App: \(detail.name)\n\n\(parts.joined(separator: "\n"))"
        if let summary = await IntelligenceService.summarize(input) {
            accessibilitySummary = summary
        } else {
            toast.error(String(localized: "Couldn't generate an accessibility summary. Try again."))
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate an accessibility summary.")
        }
        isSummarizingAccessibility = false
    }

    private func summarizeAccessibilityConsensus(_ detail: AppDetail) async {
        isSummarizingConsensus = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing accessibility consensus. This may take a moment.")
        let maxTotalCharacters = 3000
        let maxPerReview = 220
        var parts: [String] = []
        var remaining = maxTotalCharacters
        for review in detail.reviews.prefix(20) {
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
        for review in detail.reviews.prefix(20) {
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
            onJumpToLast: { Task { await jumpToLastReview(proxy: proxy) } }
        )

        if detail.reviews.isEmpty {
            Text("No reviews yet — be the first!")
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
                            toast.warning(String(localized: "Sign in to reply to reviews."))
                            return
                        }
                        quotedReview = review
                    },
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
                    Button(remaining > 0 ? "Load \(remaining) More Reviews" : "Load More Reviews") {
                        Task { await loadMoreReviews() }
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
            detail = try await APIClient.shared.apps.detail(id: appId)
            hasMoreReviews = (detail?.reviews.count ?? 0) < (detail?.reviewCount ?? 0)
            if hasMoreReviews {
                Task { await loadMoreReviews() }
            }
            if let storeUrl = detail?.appStoreUrl, !storeUrl.isEmpty {
                itunesMetadata = await ItunesAPI.fetchMetadata(appStoreUrl: storeUrl)
                if let artistId = itunesMetadata?.artistId, let appStoreId = itunesMetadata?.appStoreId {
                    developerApps = await ItunesAPI.fetchDeveloperApps(artistId: artistId, excluding: appStoreId)
                }
            }
            if let detail {
                PersistenceStore.shared.stampItemVisit(
                    id: FeedItem.visitKey(kind: .appListing, contentId: detail.id),
                    commentCount: detail.reviewCount
                )
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

    /// Loads every remaining page in one go instead of requiring a tap per
    /// page — same fix already applied to Forum/Blog/Guide/Podcast comments.
    /// Reviews previously had no pagination at all (not even manual "Load
    /// More"): an app with more than 100 reviews permanently hid the rest.
    private func loadMoreReviews() async {
        isLoadingMoreReviews = true
        do {
            while let current = self.detail, current.reviews.count < current.reviewCount {
                let more = try await APIClient.shared.apps.moreReviews(appId: current.id, offset: current.reviews.count)
                guard !more.isEmpty else { break }
                self.detail?.reviews.append(contentsOf: more)
            }
        } catch {
            toast.error(String(localized: "Couldn't load more reviews."))
        }
        hasMoreReviews = (self.detail?.reviews.count ?? 0) < (self.detail?.reviewCount ?? 0)
        isLoadingMoreReviews = false
    }

    /// "Jump to Last Comment" link on the Community Discussion heading —
    /// loads any not-yet-fetched reviews first so it always lands on the
    /// true last one, then moves VoiceOver focus there.
    private func jumpToLastReview(proxy: ScrollViewProxy) async {
        if hasMoreReviews { await loadMoreReviews() }
        guard let lastId = self.detail?.reviews.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        try? await Task.sleep(for: .milliseconds(400))
        focusedReviewId = lastId
    }

    /// VoiceOver lands on the back button after push navigation by default;
    /// this moves it to the page heading instead, per
    /// docs/IMPLEMENTATION_NOTES.md's "VoiceOver Detail Page Navigation"
    /// guidance. Delayed slightly since setting focus before the new content
    /// has actually laid out is a common way for it to silently fail.
    private func focusTitleAfterLoad() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isTitleFocused = true
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
    /// Set by the parent when it supports "Jump to Last Comment" — lets
    /// that action move VoiceOver focus here, not just scroll the viewport.
    var focusBinding: AccessibilityFocusState<String?>.Binding? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private var canDelete: Bool {
        guard let user = auth.user else { return false }
        return user.isAdmin || (!review.authorId.isEmpty && user.uuid == review.authorId)
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
                AuthorAvatarView(name: review.authorName, diameter: 28)
                Text(review.authorName).fontWeight(.medium)
                Spacer()
                RelativeDateLabel(date: review.createdAt)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "Comment \(index) of \(total) by \(review.authorName). ") +
                (review.rating.map { String(localized: "\($0) out of 5 stars. ") } ?? "") +
                (review.subject.isEmpty ? "" : String(localized: "\(review.subject)."))
            )
            .modifier(OptionalReplyFocus(binding: focusBinding, id: review.id))
            .readAloudAction(review.body.strippingHTMLTags())
            .modifier(ConditionalAccessibilityAction(isActive: onReplyTo != nil, name: "Reply to this Comment") { onReplyTo?() })
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { presentShareSheet() }
            .accessibilityAction(named: Text("Mark as Helpful")) {
                toast.warning(String(localized: "Helpful votes are coming once the Drupal Flags API is confirmed."))
            }
            .accessibilityAction(named: Text("Report Comment")) {
                toast.warning(String(localized: "Reporting is coming once the Drupal Flags API is confirmed."))
            }
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Edit Review") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Delete Review") { showDeleteConfirm = true })

            if !review.subject.isEmpty {
                Text(review.subject).font(.subheadline).fontWeight(.medium)
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

            SegmentedHTMLView(html: review.body)
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
            Button { toast.warning(String(localized: "Reporting is coming once the Drupal Flags API is confirmed.")) } label: {
                Label("Report Comment", systemImage: "flag")
            }
            if canDelete {
                Button { showEditSheet = true } label: {
                    Label("Edit Review", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Review", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this review?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(title: "Edit Review", initialText: review.body) { newText in
                guard let user = auth.user else { return }
                try await APIClient.shared.content.editComment(
                    commentType: "comment_node_ios_app_directory", commentId: review.id, newBody: newText, format: "basic_html", csrfToken: user.csrfToken
                )
                onEdit?(newText)
                toast.success(String(localized: "Review updated"))
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
            toast.success(String(localized: "Review deleted"))
        } catch {
            toast.error(String(localized: "Couldn't delete review."))
        }
    }

    private func copyText() {
        UIPasteboard.general.string = review.body.strippingHTMLTags()
        toast.success(String(localized: "Copied to clipboard."))
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

/// AppleVis's VoiceOver Performance/Button Labelling/Usability fields are a
/// fixed four-word vocabulary (Excellent/Good/Fair/Poor), not free text —
/// confirmed by the old app's own accessibility-label construction, which
/// runs each of these three fields through the same rating lookup. Swift
/// previously rendered them as plain text (or, for Usability, as if it were
/// an HTML free-text field), losing both the quick-scan visual gauge and
/// the friendlier plain-language description sighted/low-vision users get
/// from the old app.
enum AppRatingLevel {
    case excellent, good, fair, poor

    init?(text: String) {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "excellent": self = .excellent
        case "good": self = .good
        case "fair": self = .fair
        case "poor": self = .poor
        default: return nil
        }
    }

    var value: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.75
        case .fair: return 0.5
        case .poor: return 0.25
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(red: 0.133, green: 0.773, blue: 0.369)
        case .good: return Color(red: 0.518, green: 0.800, blue: 0.086)
        case .fair: return Color(red: 0.961, green: 0.620, blue: 0.043)
        case .poor: return Color(red: 0.937, green: 0.267, blue: 0.267)
        }
    }

    enum Category { case voiceOver, buttonLabeling, usability }

    func description(for category: Category) -> String {
        switch (self, category) {
        case (.excellent, .voiceOver):      return "Works flawlessly with VoiceOver. No workarounds needed."
        case (.excellent, .buttonLabeling): return "All interactive elements are clearly and accurately labeled."
        case (.excellent, .usability):      return "Smooth, intuitive experience for screen reader users."
        case (.good, .voiceOver):           return "Works well with VoiceOver. Minor issues or inconsistencies."
        case (.good, .buttonLabeling):      return "Most elements are labeled. Occasional unlabeled buttons."
        case (.good, .usability):           return "Generally usable with minor friction points."
        case (.fair, .voiceOver):           return "Partially accessible. Some features may require workarounds."
        case (.fair, .buttonLabeling):      return "Many interactive elements have poor or missing labels."
        case (.fair, .usability):           return "Usable but requires significant effort or workarounds."
        case (.poor, .voiceOver):           return "Significant accessibility barriers. Most features are difficult or impossible to use with VoiceOver."
        case (.poor, .buttonLabeling):      return "Most interactive elements are unlabeled or incorrectly labeled."
        case (.poor, .usability):           return "Very difficult or unusable for screen reader users."
        }
    }
}

struct RatingGaugeView: View {
    let label: String
    let ratingText: String
    let category: AppRatingLevel.Category

    var body: some View {
        if let level = AppRatingLevel(text: ratingText) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label.uppercased())
                        .font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                    Spacer()
                    Text(ratingText)
                        .font(.caption).fontWeight(.heavy).foregroundStyle(level.color)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .tintedBackground(level.color, opacity: 0.15, cornerRadius: 6)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 8)
                        Capsule().fill(level.color).frame(width: geo.size.width * level.value, height: 8)
                    }
                }
                .frame(height: 8)
                Text(level.description(for: category))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(label): \(ratingText). \(level.description(for: category))"))
        } else {
            // Unexpected value outside the known vocabulary — show as plain
            // text rather than silently dropping it.
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
    let onPosted: (AppReview) -> Void

    @State private var subject = ""
    @State private var reviewText: String
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    init(appId: String, appName: String, quotedReview: AppReview? = nil, onPosted: @escaping (AppReview) -> Void) {
        self.appId = appId
        self.appName = appName
        self.quotedReview = quotedReview
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
                Text(quotedReview != nil ? "Replying to \(quotedReview!.authorName) — Reviewing: \(appName)" : "Reviewing: \(appName)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal).padding(.top)
                TextField("Subject (optional)", text: $subject)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                TextEditor(text: $reviewText)
                    .padding()
                if let err = submitError {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Write Review")
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
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; submitError = nil
        do {
            let review = try await APIClient.shared.apps.submitReview(
                appId: appId, subject: subject, body: reviewText, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Review posted"))
            onPosted(review)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post review." }
        isSubmitting = false
    }
}
