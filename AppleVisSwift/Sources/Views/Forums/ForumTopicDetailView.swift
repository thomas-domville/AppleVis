import SwiftUI

struct ForumTopicDetailView: View {
    let topicId: String
    @State private var detail: ForumTopicDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var isFollowing = false
    @State private var showReplyCompose = false
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let error, detail == nil {
                ErrorView(message: error) { await load() }
            } else if let detail {
                topicContent(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if auth.isSignedIn {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Image(systemName: isFollowing ? "bell.fill" : "bell")
                    }
                    .accessibilityLabel(isFollowing ? "Unfollow topic" : "Follow topic")

                    Button { showReplyCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Reply to topic")
                }
            }
        }
        .sheet(isPresented: $showReplyCompose) {
            if let d = detail {
                ComposeReplyView(topicId: d.id, topicTitle: d.title) { reply in
                    self.detail?.replies.append(reply)
                }
            }
        }
        .task { await load() }
    }

    private func topicContent(_ detail: ForumTopicDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    HStack {
                        Text("by \(detail.authorName)")
                        Spacer()
                        RelativeDateLabel(date: detail.createdAt)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Label(detail.category, systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Body
                HTMLTextView(html: detail.body)
                    .padding(.horizontal)

                Divider()

                // Replies
                if !detail.replies.isEmpty {
                    Text("\(detail.replies.count) Repl\(detail.replies.count == 1 ? "y" : "ies")")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(detail.replies) { reply in
                        ReplyView(reply: reply)
                        Divider().padding(.leading)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            detail = try await APIClient.shared.forums.topicDetail(id: topicId)
            isFollowing = detail?.isFollowing ?? false
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load topic." }
        isLoading = false
    }

    private func toggleFollow() async {
        guard let user = auth.user, let d = detail else { return }
        do {
            if isFollowing {
                try await APIClient.shared.forums.unfollow(nodeUuid: d.id, token: user.csrfToken)
                isFollowing = false
                toast.success("Unfollowed topic")
            } else {
                try await APIClient.shared.forums.follow(nodeUuid: d.id, token: user.csrfToken)
                isFollowing = true
                toast.success("Following topic")
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        }
    }
}

struct ReplyView: View {
    let reply: ForumReply

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(reply.authorName).fontWeight(.medium)
                Spacer()
                RelativeDateLabel(date: reply.createdAt)
            }
            .font(.subheadline)
            HTMLTextView(html: reply.body)
            if reply.loveCount > 0 {
                Label("\(reply.loveCount)", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(reply.isNew ? Color.accentColor.opacity(0.05) : .clear)
    }
}
