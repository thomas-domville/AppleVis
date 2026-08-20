import SwiftUI
import UIKit

struct AppDetailView: View {
    let appId: String
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
    @State private var developerApps: [ItunesDeveloperApp] = []
    @State private var isLoadingMoreReviews = false
    @State private var hasMoreReviews = true
    @State private var newReviewCount = 0
    @State private var pendingFocusReviewId: String?
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
                        SegmentedHTMLView(html: aboutHTML(for: detail))
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

                    if let meta = itunesMetadata {
                        appStoreInfoSection(detail, meta)
                    }

                    if !developerApps.isEmpty {
                        developerAppsSection(detail)
                    }

                    if preferences.aiSummariesEnabled && IntelligenceService.isAvailable {
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
                    Link(destination: storeURL) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .accessibilityLabel(String(localized: "Open in App Store"))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ContentDetailActions(
                id: detail.id, kind: .appListing, title: detail.name, lastActivityAt: detail.lastUpdatedAt, url: detail.url,
                onAddComment: { showReviewCompose = true }
            )
        }
        .sheet(isPresented: $showReviewCompose) {
            ComposeAppReviewView(appId: detail.id, appName: detail.name) { review in
                self.detail?.reviews.append(review)
                pendingFocusReviewId = review.id
            }
        }
        .sheet(item: $quotedReview) { target in
            ComposeAppReviewView(appId: detail.id, appName: detail.name, quotedReview: target) { review in
                self.detail?.reviews.append(review)
                pendingFocusReviewId = review.id
            }
        }
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

    private func heroCard(_ detail: AppDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Text(submittedAndReviewedText(detail))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(detail.name), \(detail.category), \(submittedAndReviewedText(detail))"))
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
        }
    }

    /// iTunes (when available) is the live, authoritative source for
    /// iPhone/iPad/iPod touch/Apple Watch — it can't confirm native Mac or
    /// Apple TV support (see ItunesMetadata.deviceFamilies), so those two
    /// are added from AppleVis's own submitted `field_device_used` data only
    /// when iTunes hasn't already confirmed Mac via a Catalyst build. If
    /// iTunes metadata isn't available at all (no App Store link, or the
    /// lookup failed), falls back to AppleVis's raw list entirely.
    private func supportedDevicesText(_ detail: AppDetail) -> String {
        var families = itunesMetadata?.deviceFamilies ?? []
        guard !families.isEmpty else {
            return detail.supportedDevices.joined(separator: ", ")
        }
        let drupalLower = detail.supportedDevices.map { $0.lowercased() }
        if !families.contains("Mac"), drupalLower.contains(where: { $0.contains("mac") }) {
            families.append("Mac")
        }
        if drupalLower.contains(where: { $0.contains("apple tv") || $0.contains("tvos") }) {
            families.append("Apple TV")
        }
        return families.joined(separator: ", ")
    }

    // A submission from 4 months ago and one reviewed 3 minutes ago looked
    // identical here — nothing distinguished a stale listing from an
    // actively-discussed one. Reported directly.
    private func submittedAndReviewedText(_ detail: AppDetail) -> String {
        let submitted = "Submitted \(detail.createdAt.formatted(.relative(presentation: .named)))"
        guard detail.reviewCount > 0 else { return submitted }
        return "\(submitted), last reviewed \(detail.lastUpdatedAt.formatted(.relative(presentation: .named)))"
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
            appleVisTitle = detail?.name
            hasMoreReviews = (detail?.reviews.count ?? 0) < (detail?.reviewCount ?? 0)
            if hasMoreReviews {
                Task { await loadMoreReviews() }
            }
            if let storeUrl = detail?.appStoreUrl, !storeUrl.isEmpty {
                itunesMetadata = await ItunesAPI.fetchMetadata(appStoreUrl: storeUrl)
                if let meta = itunesMetadata, let current = detail {
                    detail = current.enriched(with: meta)
                }
                if let artistId = itunesMetadata?.artistId, let appStoreId = itunesMetadata?.appStoreId {
                    developerApps = await ItunesAPI.fetchDeveloperApps(artistId: artistId, excluding: appStoreId)
                }
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
            toast.error(String(localized: "Couldn't load more comments."))
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

    /// "Jump to First New Comment" (ALL-01) — reviews arrive chronologically
    /// oldest-first (matches "Jump to Last" scrolling to `.last`), so the
    /// first of the `newReviewCount` most recently posted reviews sits at
    /// `reviews.count - newReviewCount`.
    private func jumpToFirstNewReview(proxy: ScrollViewProxy) async {
        if hasMoreReviews { await loadMoreReviews() }
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
    /// guidance. Delayed slightly since setting focus before the new content
    /// has actually laid out is a common way for it to silently fail.
    private func focusTitleAfterLoad() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isTitleFocused = true
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
            // "Review" throughout, matching the toolbar/sheet/toast wording
            // this whole feature already uses everywhere else — these 5
            // actions previously said "Comment" (likely copied from the
            // shared Forums/Blogs/Bugs comment-row pattern without
            // adapting the wording), contradicting "Edit Review"/"Delete
            // Review" in the exact same menu.
            .modifier(ConditionalAccessibilityAction(isActive: onReplyTo != nil, name: "Reply to this Comment") { onReplyTo?() })
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { presentShareSheet() }
            .accessibilityAction(named: Text("Mark as Helpful")) {
                toast.warning(String(localized: "Helpful votes are coming once the Drupal Flags API is confirmed."))
            }
            .accessibilityAction(named: Text("Report Comment")) {
                toast.warning(String(localized: "Reporting is coming once the Drupal Flags API is confirmed."))
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
                    Label("Edit Comment", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(title: "Edit Comment", initialText: review.body) { newText in
                guard let user = auth.user else { return }
                try await APIClient.shared.content.editComment(
                    commentType: "comment_node_ios_app_directory", commentId: review.id, newBody: newText, format: "basic_html", csrfToken: user.csrfToken
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
        toast.success(String(localized: "Comment text copied."))
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
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()

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
                Text(quotedReview != nil ? "Replying to \(quotedReview!.authorName) — Commenting on: \(appName)" : "Commenting on: \(appName)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal).padding(.top)
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
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: subject,
            body: reviewText,
            detectNonEnglish: ContentSubmissionPolicy.shouldDetectNonEnglish
        ) {
            submitError = message
            return
        }
        isSubmitting = true; submitError = nil
        do {
            let review = try await APIClient.shared.apps.submitReview(
                appId: appId, subject: subject, body: reviewText, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Comment posted"))
            onPosted(review)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
