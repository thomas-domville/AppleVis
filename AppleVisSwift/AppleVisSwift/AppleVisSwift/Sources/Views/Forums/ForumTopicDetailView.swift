import SwiftUI

struct ForumTopicDetailView: View {
    let topicId: String
    @State private var detail: ForumTopicDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var isFollowing = false
    @State private var isSaved = false
    @State private var showReplyCompose = false
    @State private var isLoadingMoreReplies = false
    @State private var hasMoreReplies = true
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var threadSummary: String?
    @State private var isSummarizing = false

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

                Button { toggleSave() } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Unsave" : "Save")

                if let detail, let shareURL = URL(string: detail.url) {
                    ShareLink(item: shareURL, subject: Text(detail.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
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
        .handoff(title: detail?.title, url: detail?.url)
        .task {
            SoundPlayer.shared.play(.articleOpen)
            await load()
        }
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
                        AuthorProfileButton(name: "by \(detail.authorName)", authorId: detail.authorId)
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

                    if preferences.aiSummariesEnabled && IntelligenceService.isAvailable && detail.replies.count >= 5 {
                        summarizeSection(detail)
                    }

                    ForEach(detail.replies) { reply in
                        ReplyView(reply: reply, onDelete: {
                            self.detail?.replies.removeAll { $0.id == reply.id }
                        }, onEdit: { newBody in
                            guard let idx = self.detail?.replies.firstIndex(where: { $0.id == reply.id }) else { return }
                            self.detail?.replies[idx] = ForumReply(
                                id: reply.id, subject: reply.subject, authorName: reply.authorName,
                                authorId: reply.authorId, body: newBody, createdAt: reply.createdAt,
                                loveCount: reply.loveCount, isNew: reply.isNew
                            )
                        })
                        Divider().padding(.leading)
                    }

                    if hasMoreReplies {
                        if isLoadingMoreReplies {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        } else {
                            Button("Load More Replies") { Task { await loadMoreReplies() } }
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func summarizeSection(_ detail: ForumTopicDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let threadSummary {
                Label("AI Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                Text(threadSummary)
                    .font(.subheadline)
            } else {
                Button {
                    Task { await summarizeThread(detail) }
                } label: {
                    if isSummarizing {
                        ProgressView()
                    } else {
                        Label("Summarize Thread", systemImage: "sparkles")
                    }
                }
                .disabled(isSummarizing)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private func summarizeThread(_ detail: ForumTopicDetail) async {
        isSummarizing = true
        let text = ([detail.body.strippingHTMLTags()] + detail.replies.prefix(30).map { "\($0.authorName): \($0.body.strippingHTMLTags())" }).joined(separator: "\n\n")
        threadSummary = await IntelligenceService.summarize(text)
        isSummarizing = false
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            detail = try await APIClient.shared.forums.topicDetail(id: topicId)
            isFollowing = detail.map { PersistenceStore.shared.isFollowed(id: $0.id) } ?? false
            isSaved = detail.map { PersistenceStore.shared.isSaved(id: $0.id) } ?? false
            PersistenceStore.shared.markTopicSeen(id: topicId)
            hasMoreReplies = (detail?.replies.count ?? 0) >= 100
            if let detail {
                SpotlightIndexer.index(ForumTopic(
                    id: detail.id, title: detail.title, authorName: detail.authorName, authorId: detail.authorId,
                    createdAt: detail.createdAt, lastActivityAt: detail.lastActivityAt, replyCount: detail.replyCount,
                    category: detail.category, categoryId: detail.categoryId, url: detail.url,
                    isUnread: false, isFollowing: isFollowing, isSaved: isSaved
                ))
            }
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
                PersistenceStore.shared.markUnfollowed(id: d.id)
                toast.success("Unfollowed topic")
            } else {
                try await APIClient.shared.forums.follow(nodeUuid: d.id, token: user.csrfToken)
                isFollowing = true
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: d.id, kind: .forumTopic, nodeType: "node--forum",
                    title: d.title, followedAt: Date(), lastActivityAt: d.lastActivityAt, url: d.url
                ))
                toast.success("Following topic")
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(isFollowing ? "Failed to unfollow topic." : "Failed to follow topic.")
        }
    }

    private func loadMoreReplies() async {
        guard let detail else { return }
        isLoadingMoreReplies = true
        do {
            let more = try await APIClient.shared.forums.moreReplies(topicId: detail.id, offset: detail.replies.count)
            self.detail?.replies.append(contentsOf: more)
            hasMoreReplies = more.count >= 100
        } catch {
            toast.error("Couldn't load more replies.")
        }
        isLoadingMoreReplies = false
    }

    private func toggleSave() {
        guard let detail else { return }
        if isSaved {
            PersistenceStore.shared.unsave(id: detail.id)
            isSaved = false
            toast.success("Removed from Saved")
        } else {
            PersistenceStore.shared.save(SavedItem(
                id: detail.id, kind: .forumTopic, title: detail.title,
                savedAt: Date(), lastActivityAt: detail.lastActivityAt
            ))
            isSaved = true
            toast.success("Saved")
        }
    }
}

struct ReplyView: View {
    let reply: ForumReply
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private var canDelete: Bool {
        guard let user = auth.user else { return false }
        return user.isAdmin || (!reply.authorId.isEmpty && user.uuid == reply.authorId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AuthorProfileButton(name: reply.authorName, authorId: reply.authorId, font: .subheadline.weight(.medium))
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
        .contextMenu {
            if canDelete {
                Button { showEditSheet = true } label: {
                    Label("Edit Reply", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Reply", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this reply?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(title: "Edit Reply", initialText: reply.body) { newText in
                guard let user = auth.user else { return }
                try await APIClient.shared.content.editComment(
                    commentType: "comment_forum", commentId: reply.id, newBody: newText, format: "basic_html", csrfToken: user.csrfToken
                )
                onEdit?(newText)
                toast.success("Reply updated")
            }
        }
    }

    private func delete() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteComment(commentType: "comment_forum", commentId: reply.id, csrfToken: user.csrfToken)
            onDelete?()
            toast.success("Reply deleted")
        } catch {
            toast.error("Couldn't delete reply.")
        }
    }
}
