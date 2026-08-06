import SwiftUI
import UIKit

struct ForumTopicDetailView: View {
    let topicId: String
    @State private var detail: ForumTopicDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var isFollowing = false
    @State private var isSaved = false
    @State private var showReplyCompose = false
    @State private var quotedReplyTarget: ForumReply?
    @State private var isLoadingMoreReplies = false
    @State private var hasMoreReplies = true
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var threadSummary: String?
    @State private var isSummarizing = false
    @State private var postSummary: String?
    @State private var isSummarizingPost = false
    @State private var showBrowser = false
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedReplyId: String?

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
        .safeAreaInset(edge: .bottom) {
            // Matches the old app's fixed bottom toolbar (Follow, Save,
            // Share, Open in Safari, Add New Comment — confirmed via
            // git show 655e6ca^:app/topic/[id].tsx) — these 5 actions used
            // to be crammed into top-right nav bar icons instead.
            if let detail {
                bottomActionBar(detail)
            }
        }
        .sheet(isPresented: $showReplyCompose) {
            if let d = detail {
                ComposeReplyView(topicId: d.id, topicTitle: d.title) { reply in
                    self.detail?.replies.append(reply)
                }
            }
        }
        .sheet(item: $quotedReplyTarget) { target in
            if let d = detail {
                ComposeReplyView(topicId: d.id, topicTitle: d.title, quotedReply: target) { reply in
                    self.detail?.replies.append(reply)
                }
            }
        }
        .sheet(isPresented: $showBrowser) {
            if let detail, let shareURL = URL(string: detail.url) {
                SafariView(url: shareURL)
            }
        }
        .handoff(title: detail?.title, url: detail?.url)
        .task {
            SoundPlayer.shared.play(.articleOpen)
            await load()
        }
    }

    private func topicContent(_ detail: ForumTopicDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isTitleFocused)
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
                        CommunityDiscussionHeading(
                            count: detail.replyCount,
                            onThreadOverview: { announceThreadOverview(detail) },
                            onJumpToLast: { Task { await jumpToLastReply(proxy: proxy) } }
                        )

                        if preferences.aiSummariesEnabled && IntelligenceService.isAvailable {
                            summarizeSection(detail)
                        }

                        ForEach(Array(detail.replies.enumerated()), id: \.element.id) { index, reply in
                            ReplyView(
                                reply: reply, index: index, total: detail.replies.count,
                                topicAuthorId: detail.authorId, topicTitle: detail.title,
                                onReplyTo: {
                                    guard auth.isSignedIn else {
                                        toast.warning("Sign in to reply to posts.")
                                        return
                                    }
                                    quotedReplyTarget = reply
                                },
                                onDelete: {
                                    self.detail?.replies.removeAll { $0.id == reply.id }
                                }, onEdit: { newBody in
                                    guard let idx = self.detail?.replies.firstIndex(where: { $0.id == reply.id }) else { return }
                                    self.detail?.replies[idx] = ForumReply(
                                        id: reply.id, subject: reply.subject, authorName: reply.authorName,
                                        authorId: reply.authorId, body: newBody, createdAt: reply.createdAt,
                                        loveCount: reply.loveCount, isNew: reply.isNew
                                    )
                                },
                                focusBinding: $focusedReplyId
                            )
                            .id(reply.id)
                            Divider().padding(.leading)
                        }

                        if hasMoreReplies {
                            if isLoadingMoreReplies {
                                ProgressView().frame(maxWidth: .infinity).padding()
                            } else {
                                let remaining = detail.replyCount - detail.replies.count
                                Button(remaining > 0 ? "Load \(remaining) More Replies" : "Load More Replies") {
                                    Task { await loadMoreReplies() }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    /// Split into two independent actions (matching the old app): "Summarize
    /// Post" covers just the original post so a user can get its gist
    /// before deciding to read replies at all, while "Summarize Discussion"
    /// covers only the replies. Previously this was a single "Summarize
    /// Thread" action that always included both together.
    @ViewBuilder
    private func summarizeSection(_ detail: ForumTopicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            summarizePostRow(detail)
            if detail.replies.count >= 5 {
                Divider()
                summarizeDiscussionRow(detail)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func summarizePostRow(_ detail: ForumTopicDetail) -> some View {
        if let postSummary {
            VStack(alignment: .leading, spacing: 4) {
                Label("Post Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                Text(postSummary).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizePost(detail) }
            } label: {
                if isSummarizingPost {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Summarize Post", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizingPost)
            .accessibilityLabel(isSummarizingPost ? "Summarizing post, please wait" : "Summarize Post")
        }
    }

    @ViewBuilder
    private func summarizeDiscussionRow(_ detail: ForumTopicDetail) -> some View {
        if let threadSummary {
            VStack(alignment: .leading, spacing: 4) {
                Label("Discussion Summary", systemImage: "sparkles")
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                Text(threadSummary).font(.subheadline)
            }
        } else {
            Button {
                Task { await summarizeThread(detail) }
            } label: {
                if isSummarizing {
                    HStack(spacing: 8) { ProgressView(); Text("Summarizing…") }
                } else {
                    Label("Summarize Discussion", systemImage: "sparkles")
                }
            }
            .disabled(isSummarizing)
            .accessibilityLabel(isSummarizing ? "Summarizing discussion, please wait" : "Summarize Discussion")
        }
    }

    private func summarizePost(_ detail: ForumTopicDetail) async {
        isSummarizingPost = true
        UIAccessibility.post(notification: .announcement, argument: "Summarizing post. This may take a moment.")
        let input = "Forum topic: \(detail.title)\n\n\(detail.body.strippingHTMLTags().prefix(3000))"
        if let summary = await IntelligenceService.summarize(input) {
            postSummary = summary
        } else {
            toast.error("Couldn't generate a summary for this post. Try again.")
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate a summary for this post.")
        }
        isSummarizingPost = false
    }

    private func summarizeThread(_ detail: ForumTopicDetail) async {
        isSummarizing = true
        // The button dims/disables while loading, but a disabled control on
        // its own gives a VoiceOver user no confirmation the tap actually
        // registered versus just failing to respond — announce explicitly.
        UIAccessibility.post(notification: .announcement, argument: "Summarizing discussion. This may take a moment.")
        if let summary = await IntelligenceService.summarize(summaryInput(for: detail)) {
            threadSummary = summary
        } else {
            // IntelligenceService silently returns nil on any generation
            // failure, so without this the button just reverted to its
            // original state with zero feedback — indistinguishable from
            // the tap not registering at all.
            toast.error("Couldn't generate a summary for this discussion. Try again.")
            UIAccessibility.post(notification: .announcement, argument: "Couldn't generate a summary for this discussion.")
        }
        isSummarizing = false
    }

    /// Replies only, not the post body — matches the old app's separate
    /// "Summarise Discussion" action. Caps total input length before
    /// sending to the on-device model: a long, heavily-discussed thread's
    /// full, untruncated reply bodies can exceed the on-device
    /// FoundationModels context window, which throws a generation error
    /// IntelligenceService swallows. That silently broke this feature on
    /// exactly the threads a summary is most useful for (reported directly,
    /// twice — the exact on-device context limit isn't documented, so this
    /// trades some summary detail for headroom rather than trying to find
    /// the precise ceiling by trial and error).
    private func summaryInput(for detail: ForumTopicDetail) -> String {
        let maxTotalCharacters = 3000
        let maxPerReply = 220
        let maxReplies = 20
        var parts: [String] = []
        var remaining = maxTotalCharacters
        for reply in detail.replies.prefix(maxReplies) {
            guard remaining > 0 else { break }
            let body = reply.body.strippingHTMLTags().prefix(maxPerReply)
            let part = "\(reply.authorName): \(body)"
            parts.append(String(part.prefix(remaining)))
            remaining -= part.count
        }
        return parts.joined(separator: "\n\n")
    }

    /// VoiceOver "Thread overview" custom action on the comments heading —
    /// a spoken summary in place of manually reading through every reply.
    /// No "N new" count: nothing in the app currently tracks per-item last-
    /// visit timestamps (ForumReply.isNew is hardcoded false in Mappers.swift
    /// and never set) — the "New Comment Tracking" feature described in
    /// docs/IMPLEMENTATION_NOTES.md was documented but never built. Saying
    /// "0 new" or silently always omitting it would both be misleading in
    /// different ways, so this only speaks what's actually real right now.
    private func announceThreadOverview(_ detail: ForumTopicDetail) {
        let mostRecent = detail.replies.max { $0.createdAt < $1.createdAt }
        var summary = "Thread has \(detail.replies.count) comment\(detail.replies.count == 1 ? "" : "s")."
        if let mostRecent {
            summary += " Most recent comment by \(mostRecent.authorName), \(mostRecent.createdAt.formatted(.relative(presentation: .named)))."
        }
        summary += " Original post by \(detail.authorName)."
        UIAccessibility.post(notification: .announcement, argument: summary)
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

    private func load() async {
        isLoading = true
        error = nil
        do {
            detail = try await APIClient.shared.forums.topicDetail(id: topicId)
            isFollowing = detail.map { PersistenceStore.shared.isFollowed(id: $0.id) } ?? false
            isSaved = detail.map { PersistenceStore.shared.isSaved(id: $0.id) } ?? false
            PersistenceStore.shared.markTopicSeen(id: topicId)
            // Opening the topic itself should clear its "new" state on Home,
            // not just Home's own explicit "Mark as Read" action — otherwise
            // a topic you've actually read stays flagged as new indefinitely.
            if let detail {
                PersistenceStore.shared.stampItemVisit(
                    id: FeedItem.visitKey(kind: .forumTopic, contentId: detail.id),
                    commentCount: detail.replyCount
                )
            }
            // Was `>= 100` — the page size *requested*, not what the server
            // actually returns. Drupal JSON:API deployments commonly clamp
            // a requested page[limit] down to a lower site-configured max
            // (e.g. 50) regardless of what's asked for, so a topic with
            // hundreds of replies could get back only 50 on the first page —
            // `50 >= 100` is false, permanently hiding "Load More Replies"
            // even though most of the thread was never fetched. Comparing
            // against the topic's own known replyCount (already used for
            // the row's "N replies" label) is correct regardless of
            // whatever page size the server actually enforces.
            hasMoreReplies = (detail?.replies.count ?? 0) < (detail?.replyCount ?? 0)
            // Fetch every remaining page automatically instead of waiting for
            // a "Load More" tap — requested directly: the heading already
            // shows the true total (replyCount), so leaving the rest behind
            // a manual tap just contradicted what the count said was there.
            if hasMoreReplies {
                Task { await loadMoreReplies() }
            }
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
        focusTitleAfterLoad()
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

    /// Loads every remaining page in one go instead of requiring a tap per
    /// page — the server clamps each request to its own max page size
    /// (see the hasMoreReplies fix above), so a thread with hundreds of
    /// replies could otherwise take several manual "Load More" taps to
    /// fully unroll. Reported directly as unwanted friction.
    private func loadMoreReplies() async {
        isLoadingMoreReplies = true
        do {
            while let current = self.detail, current.replies.count < current.replyCount {
                let more = try await APIClient.shared.forums.moreReplies(topicId: current.id, offset: current.replies.count)
                guard !more.isEmpty else { break }
                self.detail?.replies.append(contentsOf: more)
            }
        } catch {
            toast.error("Couldn't load more replies.")
        }
        hasMoreReplies = (self.detail?.replies.count ?? 0) < (self.detail?.replyCount ?? 0)
        isLoadingMoreReplies = false
    }

    /// "Jump to Last Comment" custom action on the Community Discussion
    /// heading — mirrors the existing jump-to-first-new-item pattern
    /// elsewhere in the app (e.g. Home's What's New card), requested
    /// directly as an alternative to manually scrolling through a long
    /// thread. Loads any not-yet-fetched replies first so it always lands
    /// on the true last reply, not just the last of whatever's loaded so far.
    private func jumpToLastReply(proxy: ScrollViewProxy) async {
        if hasMoreReplies { await loadMoreReplies() }
        guard let lastId = self.detail?.replies.last?.id else { return }
        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        // Scrolling the viewport doesn't move VoiceOver's focus on its own —
        // without this, the visual position changes but a VoiceOver user's
        // swipe cursor stays exactly where it was, defeating the point.
        try? await Task.sleep(for: .milliseconds(400))
        focusedReplyId = lastId
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

    private func bottomActionBar(_ detail: ForumTopicDetail) -> some View {
        HStack(spacing: 0) {
            if auth.isSignedIn {
                DetailActionButton(
                    systemImage: isFollowing ? "bell.fill" : "bell",
                    visualLabel: isFollowing ? "Unfollow" : "Follow",
                    accessibilityLabel: isFollowing ? "Unfollow topic" : "Follow topic"
                ) { Task { await toggleFollow() } }
            }

            DetailActionButton(
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                visualLabel: isSaved ? "Unsave" : "Save",
                accessibilityLabel: isSaved ? "Unsave topic" : "Save topic"
            ) { toggleSave() }

            if let shareURL = URL(string: detail.url) {
                ShareLink(item: shareURL, subject: Text(detail.title)) {
                    DetailActionButtonLabel(systemImage: "square.and.arrow.up", visualLabel: "Share")
                }
                .accessibilityLabel("Share topic")

                DetailActionButton(systemImage: "safari", visualLabel: "Browser", accessibilityLabel: "Open topic in browser") {
                    showBrowser = true
                }
            }

            if auth.isSignedIn {
                DetailActionButton(systemImage: "square.and.pencil", visualLabel: "Reply", accessibilityLabel: "Reply to topic") {
                    showReplyCompose = true
                }
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

struct ReplyView: View {
    let reply: ForumReply
    var index: Int = 0
    var total: Int = 1
    var topicAuthorId: String = ""
    var topicTitle: String = ""
    var onReplyTo: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    /// Set by the parent when it supports "Jump to Last Comment" — lets
    /// that action move VoiceOver focus here, not just scroll the viewport.
    var focusBinding: AccessibilityFocusState<String?>.Binding? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private var isOriginalPoster: Bool {
        !topicAuthorId.isEmpty && topicAuthorId == reply.authorId
    }

    private var canDelete: Bool {
        guard let user = auth.user else { return false }
        return user.isAdmin || (!reply.authorId.isEmpty && user.uuid == reply.authorId)
    }

    /// "Comment 2 of 8. Jane Doe, Original Poster. 3 hours ago. Subject: ..."
    /// — mirrors the old app's per-comment header label so VoiceOver users
    /// get the same at-a-glance context and rotor-navigable heading stops.
    private var headerAccessibilityLabel: String {
        var label = "Comment \(index + 1) of \(total). \(reply.authorName)"
        if isOriginalPoster { label += ", Original Poster" }
        label += ". \(reply.createdAt.formatted(.relative(presentation: .named)))."
        if let subject = Self.displaySubject(reply.subject, parentTitle: topicTitle) {
            label += " Subject: \(subject)."
        }
        if reply.isNew { label += " New." }
        return label
    }

    /// Suppresses generic default subjects ("Comment", "Reply", "Review",
    /// "Re", "Add new comment") and subjects that just duplicate the parent
    /// topic title — mirrors the old app's commentSubject.ts. Drupal
    /// defaults a reply's subject to one of these unless the poster changes
    /// it, so without this nearly every reply read "Subject: Comment." aloud
    /// for no reason (the previous version only caught the exact "Re: Title"
    /// and title-duplicate cases, not these generic defaults).
    private static func displaySubject(_ subject: String, parentTitle: String) -> String? {
        func normalize(_ value: String) -> String {
            var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .lowercased()
            if s.hasPrefix("re:") {
                s = String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            return s
        }
        let genericSubjects: Set<String> = ["comment", "reply", "review", "re", "add new comment"]
        let clean = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !clean.isEmpty else { return nil }
        let normalized = normalize(clean)
        guard !normalized.isEmpty, !genericSubjects.contains(normalized) else { return nil }
        guard normalize(parentTitle) != normalized else { return nil }
        return clean
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AuthorProfileButton(name: reply.authorName, authorId: reply.authorId, font: .subheadline.weight(.medium))
                Spacer()
                RelativeDateLabel(date: reply.createdAt)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(headerAccessibilityLabel)
            .accessibilityHint("Actions available: reply, copy, share, and more.")
            .modifier(OptionalReplyFocus(binding: focusBinding, id: reply.id))
            .accessibilityAction(named: Text("Reply to this Comment")) { onReplyTo?() }
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { presentShareSheet() }
            .accessibilityAction(named: Text("Mark as Helpful")) {
                toast.warning("Helpful votes are coming once the Drupal Flags API is confirmed.")
            }
            .accessibilityAction(named: Text("Report Comment")) {
                toast.warning("Reporting is coming once the Drupal Flags API is confirmed.")
            }
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Edit Comment") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Delete Comment") { showDeleteConfirm = true })

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

    private func copyText() {
        UIPasteboard.general.string = reply.body.strippingHTMLTags()
        toast.success("Comment text copied.")
    }

    /// Mirrors the old app's "Share Comment" action — shares the comment as
    /// plain text (author, subject if meaningful, body), not a URL, since
    /// individual replies have no shareable link of their own.
    private func presentShareSheet() {
        let plain = reply.body.strippingHTMLTags()
        let subject = reply.subject.trimmingCharacters(in: .whitespaces)
        var message = "\(reply.authorName) on AppleVis"
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
