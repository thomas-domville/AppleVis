import SwiftUI

struct AppDetailView: View {
    let appId: String
    @State private var detail: AppDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showReviewCompose = false
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
        .task { await load() }
    }

    @ViewBuilder
    private func appContent(_ detail: AppDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroCard(detail).padding()

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
        HStack {
            Text("Community Discussion")
                .font(.headline)
            Spacer()
            Text("\(detail.reviews.count) comment\(detail.reviews.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Community Discussion, \(detail.reviews.count) comments")

        if detail.reviews.isEmpty {
            Text("No reviews yet — be the first!")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 8)
        } else {
            ForEach(Array(detail.reviews.enumerated()), id: \.element.id) { index, review in
                AppReviewRow(review: review, index: index + 1, total: detail.reviews.count)
                if index < detail.reviews.count - 1 {
                    Divider().padding(.leading)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            detail = try await APIClient.shared.apps.detail(id: appId)
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
    }
}

// MARK: - Compose app review

struct ComposeAppReviewView: View {
    let appId: String
    let appName: String
    let onPosted: (AppReview) -> Void

    @State private var reviewText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Reviewing: \(appName)")
                    .font(.subheadline).foregroundStyle(.secondary)
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
                appId: appId, body: reviewText, csrfToken: user.csrfToken
            )
            toast.success("Review posted")
            onPosted(review)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post review." }
        isSubmitting = false
    }
}
