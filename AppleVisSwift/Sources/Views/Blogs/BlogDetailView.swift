import SwiftUI

struct BlogDetailView: View {
    let postId: String
    @State private var detail: BlogPostDetail?
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
    private func content(_ detail: BlogPostDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Blog", systemImage: "newspaper")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        RelativeDateLabel(date: detail.publishedAt)
                    }
                    Text(detail.title)
                        .font(.title2).fontWeight(.semibold)
                    Text("by \(detail.authorName)")
                        .font(.subheadline).foregroundStyle(.secondary)
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
            ComposeBlogCommentView(blogId: detail.id, title: detail.title) { comment in
                self.detail?.comments.append(comment)
            }
        }
    }

    @ViewBuilder
    private func commentsSection(_ detail: BlogPostDetail) -> some View {
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
            detail = try await APIClient.shared.blogs.detail(id: postId)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load post." }
        isLoading = false
    }
}

// MARK: - Compose blog comment

struct ComposeBlogCommentView: View {
    let blogId: String
    let title: String
    let onPosted: (BlogComment) -> Void

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
            let comment = try await APIClient.shared.blogs.submitComment(
                blogId: blogId, body: commentText, csrfToken: user.csrfToken
            )
            toast.success("Comment posted")
            onPosted(comment)
            dismiss()
        } catch let e as APIError { submitError = e.localizedDescription
        } catch { submitError = "Failed to post comment." }
        isSubmitting = false
    }
}
