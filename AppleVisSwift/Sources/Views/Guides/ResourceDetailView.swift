import SwiftUI

struct ResourceDetailView: View {
    let resourceId: String
    @State private var detail: ResourceDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCompose = false
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        Group {
            if isLoading && detail == nil {
                LoadingView()
            } else if let err = error, detail == nil {
                ErrorView(message: err) { await load() }
            } else if let detail {
                content(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ detail: ResourceDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(detail.kind.displayName, systemImage: detail.kind.systemImage)
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        RelativeDateLabel(date: detail.updatedAt)
                    }
                    Text(detail.title)
                        .font(.title2).fontWeight(.semibold)
                    Text("by \(detail.authorName)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !detail.categories.isEmpty {
                        Text(detail.categories.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Divider()

                HTMLTextView(html: detail.body)
                    .padding(.horizontal)

                Divider()

                // Comments
                commentsSection(detail)

                Color.clear.frame(height: 40)
            }
            .padding(.vertical)
        }
        .toolbar {
            if auth.isSignedIn {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Add comment")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeResourceCommentView(resourceId: detail.id, title: detail.title) { comment in
                self.detail?.comments.append(comment)
            }
        }
    }

    @ViewBuilder
    private func commentsSection(_ detail: ResourceDetail) -> some View {
        HStack {
            Text("\(detail.comments.count) Comment\(detail.comments.count == 1 ? "" : "s")")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .accessibilityAddTraits(.isHeader)

        if detail.comments.isEmpty {
            Text("No comments yet.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal)
        } else {
            ForEach(detail.comments) { comment in
                CommentRow(authorName: comment.authorName, body: comment.body, date: comment.createdAt)
                Divider().padding(.leading)
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            detail = try await APIClient.shared.resources.detail(id: resourceId)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load guide." }
        isLoading = false
    }
}

// MARK: - Generic comment row (shared across resource/blog/podcast)

struct CommentRow: View {
    let authorName: String
    let body: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(authorName).fontWeight(.medium)
                Spacer()
                RelativeDateLabel(date: date)
            }
            .font(.subheadline)
            HTMLTextView(html: body)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Comment by \(authorName), \(date.formatted(.relative(presentation: .named)))")
    }
}

// MARK: - Compose comment

struct ComposeResourceCommentView: View {
    let resourceId: String
    let title: String
    let onPosted: (ResourceComment) -> Void

    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Re: \(title)")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
                TextEditor(text: $commentText).padding()
                if let err = submitError {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; submitError = nil
        do {
            let comment = try await APIClient.shared.resources.submitComment(
                resourceId: resourceId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success("Comment posted")
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
