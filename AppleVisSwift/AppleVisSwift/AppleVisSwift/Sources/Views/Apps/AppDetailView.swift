import SwiftUI

struct AppDetailView: View {
    let appId: String
    @State private var detail: AppDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showReviewCompose = false
    @State private var itunesMetadata: ItunesMetadata?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroCard(detail).padding()

                if let meta = itunesMetadata {
                    appStoreInfoSection(meta)
                }

                if !detail.body.isEmpty {
                    sectionHeading("About")
                    HTMLTextView(html: detail.body)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }

                if let vo = detail.voiceOverPerformance, !vo.isEmpty {
                    sectionHeading("VoiceOver Performance")
                    Text(vo).padding(.horizontal).padding(.bottom, 8)
                }
                if let bl = detail.buttonLabelling, !bl.isEmpty {
                    sectionHeading("Button Labelling")
                    Text(bl).padding(.horizontal).padding(.bottom, 8)
                }
                if let usability = detail.usabilityNotes, !usability.isEmpty {
                    sectionHeading("Usability Notes")
                    HTMLTextView(html: usability)
                        .padding(.horizontal).padding(.bottom, 8)
                }
                if let acc = detail.accessibilityComments, !acc.isEmpty {
                    sectionHeading("Accessibility Comments")
                    HTMLTextView(html: acc)
                        .padding(.horizontal).padding(.bottom, 8)
                }

                reviewsSection(detail)

                Color.clear.frame(height: 40)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let storeURL = detail.appStoreUrl.flatMap(URL.init) {
                    Link(destination: storeURL) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .accessibilityLabel("Open in App Store")
                }
                if auth.isSignedIn {
                    Button { showReviewCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Write review")
                }
                ContentDetailActions(id: detail.id, kind: .appListing, title: detail.name, lastActivityAt: detail.lastUpdatedAt, url: detail.url)
            }
        }
        .sheet(isPresented: $showReviewCompose) {
            ComposeAppReviewView(appId: detail.id, appName: detail.name) { review in
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
        .accessibilityLabel("\(detail.name) by \(detail.developer), \(detail.platform.displayName), \(detail.price)")
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
        }
        .padding(.bottom, 8)
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
    private func reviewsSection(_ detail: AppDetail) -> some View {
        CommunityDiscussionHeading(count: detail.reviews.count) {
            announceThreadOverview(detail)
        }

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
                    }
                )
                if index < detail.reviews.count - 1 {
                    Divider().padding(.leading)
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
            if let storeUrl = detail?.appStoreUrl, !storeUrl.isEmpty {
                itunesMetadata = await ItunesAPI.fetchMetadata(appStoreUrl: storeUrl)
            }
            if let detail {
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
    }
}

// MARK: - Review row

struct AppReviewRow: View {
    let review: AppReview
    let index: Int
    let total: Int
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil

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
            HStack {
                Text(review.authorName).fontWeight(.medium)
                Spacer()
                RelativeDateLabel(date: review.createdAt)
            }
            .font(.subheadline)

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

            HTMLTextView(html: review.body)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Comment \(index) of \(total) by \(review.authorName). " +
            (review.rating.map { "\($0) out of 5 stars. " } ?? "") +
            (review.subject.isEmpty ? "" : "\(review.subject).")
        )
        .contextMenu {
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
                toast.success("Review updated")
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
            toast.success("Review deleted")
        } catch {
            toast.error("Couldn't delete review.")
        }
    }
}

// MARK: - Compose app review

struct ComposeAppReviewView: View {
    let appId: String
    let appName: String
    let onPosted: (AppReview) -> Void

    @State private var subject = ""
    @State private var reviewText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    // AppleVis's review comment bundle has no rating field on the backend —
    // only a subject and body — so there's no star-rating input here; adding
    // one would silently discard whatever the user picked.
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Reviewing: \(appName)")
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
            toast.success("Review posted")
            onPosted(review)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post review." }
        isSubmitting = false
    }
}
