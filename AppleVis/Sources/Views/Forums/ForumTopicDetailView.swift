import SwiftUI
import UIKit

struct ForumTopicDetailView: View {
    let topicId: String
    /// Set when opened via a card's "Jump to First New Comment" action
    /// (ContentActionsModifier, routed through DeepLinkRouter.pendingContentIntent)
    /// — scrolls/focuses straight to the first new reply once loaded,
    /// instead of landing at the top of the topic like a normal open.
    var focusFirstNewCommentOnAppear: Bool = false
    @State private var hasAppliedFirstNewCommentFocus = false
    /// When "new" started for this visit — kept because the visit stamp is
    /// overwritten as soon as the topic loads, and replies on later pages
    /// (fetched afterwards) need the same marking as the first page.
    @State private var newRepliesSince: Date?
    /// Set when opened from the admin Guideline Violation Check screen for a
    /// flagged reply — scrolls/focuses straight to that specific reply once
    /// loaded, the same way `focusFirstNewCommentOnAppear` does for "first
    /// new," just targeting a caller-known id instead of resolving one by
    /// position. Requested directly.
    var targetCommentId: String? = nil
    @State private var hasAppliedTargetCommentFocus = false
    @State private var detail: ForumTopicDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isFollowing = false
    @State private var isSaved = false
    @State private var showReplyCompose = false
    @State private var quotedReplyTarget: ForumReply?
    @State private var isLoadingMoreReplies = false
    @State private var hasMoreReplies = true
    // load() kicks off loadAllRemainingReplies() in the background as soon
    // as a topic opens; "Jump to First New Comment"/"Jump to Last Comment"
    // also need every page loaded before they can resolve a target, and
    // previously called loadAllRemainingReplies() again themselves whenever
    // that background load hadn't finished yet — two concurrent drain loops
    // both reading replies.count before either had appended, so both fetched
    // the same offset and the second one's results landed as duplicates,
    // breaking ForEach identity and scrollTo(_:). Tracking the in-flight
    // Task here lets every caller await the one drain that's actually
    // running instead of starting a second. Reported directly: "jump to
    // newest/first new comment" not landing on the right reply.
    @State private var loadAllRepliesTask: Task<Void, Never>?
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var tips: TipStore
    @State private var threadSummary: String?
    @State private var isSummarizing = false
    @State private var showBrowser = false
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var focusedReplyId: String?
    @State private var pendingFocusReplyId: String?
    // Topic-level moderation — previously only reachable from a browse-list
    // row's long-press menu (ContentActionsModifier); the detail screen for
    // the topic itself had no Edit/Delete/Unpublish at all.
    @State private var editingTopicNode: EditableNode?
    @Environment(\.dismiss) private var dismiss

    private var isOwnTopic: Bool {
        guard let detail, let user = auth.user else { return false }
        return !detail.authorId.isEmpty && user.uuid == detail.authorId
    }

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
            // Share, Open in Safari, Add Comment — confirmed via
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
                    self.detail?.replyCount += 1
                    pendingFocusReplyId = reply.id
                }
            }
        }
        .sheet(item: $quotedReplyTarget) { target in
            if let d = detail {
                ComposeReplyView(topicId: d.id, topicTitle: d.title, quotedReply: target) { reply in
                    self.detail?.replies.append(reply)
                    self.detail?.replyCount += 1
                    pendingFocusReplyId = reply.id
                }
            }
        }
        .sheet(isPresented: $showBrowser) {
            if let detail, let shareURL = URL(string: detail.url) {
                SafariView(url: shareURL)
            }
        }
        .handoff(title: detail?.title, url: detail?.url)
        .toolbar {
            if let detail {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DetailActionsMenu(
                        id: detail.id, entityId: detail.nid, kind: .forumTopic, title: detail.title, lastActivityAt: detail.lastActivityAt, url: detail.url,
                        authorName: detail.authorName, excerpt: .excerpt(from: detail.body),
                        isOwnContent: isOwnTopic,
                        onAddComment: { showReplyCompose = true },
                        onEdit: { startEditTopic() },
                        onUnpublish: { await unpublishTopic() },
                        onDelete: { await deleteTopic() }
                    )
                }
            }
        }
        .sheet(item: $editingTopicNode) { node in
            EditNodeSheet(initialTitle: node.title, initialBody: node.body, nodeTypeSuffix: node.nodeTypeSuffix) { newTitle, newBody in
                try await saveTopicEdit(title: newTitle, body: newBody, format: node.format)
            }
        }
        .task {
            SoundPlayer.shared.play(.articleOpen)
            await load()
        }
    }

    private func startEditTopic() {
        guard let detail else { return }
        editingTopicNode = EditableNode(title: detail.title, body: detail.rawBody, format: detail.bodyFormat, nodeTypeSuffix: "forum")
    }

    private func saveTopicEdit(title: String, body: String, format: String) async throws {
        guard let user = auth.user, let detail else { return }
        try await APIClient.shared.content.editNode(nodeId: detail.id, nodeType: "forum", title: title, body: body, format: format, csrfToken: user.csrfToken)
        self.detail?.title = title
        // Not `detail.body` (rendered HTML) — that would show literal
        // Markdown/plain-text source on screen until the next real reload,
        // since there's no client-side renderer to turn raw text back into
        // the HTML SegmentedHTMLView expects. `rawBody` is kept in sync so
        // reopening Edit immediately after shows what was just saved.
        self.detail?.rawBody = body
        self.detail?.bodyFormat = format
        toast.success(String(localized: "Topic updated"))
    }

    private func unpublishTopic() async {
        guard let user = auth.user, let detail else { return }
        do {
            try await APIClient.shared.content.unpublishNode(nodeId: detail.id, nodeType: "forum", csrfToken: user.csrfToken)
            toast.success(String(localized: "Topic unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish."))
        }
    }

    /// Deletes the topic the user is currently reading — unlike row-level
    /// deletion elsewhere, there's no list to prune; the only sensible next
    /// step is leaving the screen.
    private func deleteTopic() async {
        guard let user = auth.user, let detail else { return }
        do {
            try await APIClient.shared.content.deleteNode(nodeId: detail.id, nodeType: "forum", csrfToken: user.csrfToken)
            toast.success(String(localized: "Topic deleted"))
            dismiss()
        } catch {
            toast.error(String(localized: "Couldn't delete."))
        }
    }

    /// Matches WebLink's own in-app-vs-external branching so the "Browser"
    /// bottom-bar action respects the same preference instead of always
    /// forcing the in-app SafariView sheet.
    private func openInBrowser() {
        guard let detail, let shareURL = URL(string: detail.url) else { return }
        switch preferences.webBrowsingMode {
        case .inApp:    showBrowser = true
        case .external: UIApplication.shared.open(shareURL)
        }
    }

    private func topicContent(_ detail: ForumTopicDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($isTitleFocused)
                        HStack {
                            AuthorProfileButton(name: String(localized: "by \(detail.authorName)"), authorId: detail.authorId)
                            Spacer()
                            // A months-old topic with a comment three minutes
                            // ago looked identical to one nobody's touched
                            // since it was posted — only the original post
                            // date showed anywhere near the top. Combined
                            // into one line/one VoiceOver stop rather than a
                            // separate swipe, per direct feedback.
                            Text(postAndActivityDateText(detail))
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
                    SegmentedHTMLView(html: detail.body, contentKind: "forumTopic", contentId: detail.id, field: "body")
                        .padding(.horizontal)

                    Divider()

                    // Replies
                    if !detail.replies.isEmpty {
                        CommunityDiscussionHeading(
                            count: detail.replyCount,
                            onThreadOverview: { announceThreadOverview(detail) },
                            onJumpToLast: { Task { await jumpToLastReply(proxy: proxy) } },
                            newCount: newReplyCountForHeading,
                            onJumpToFirstNew: { Task { await jumpToFirstNewReply(proxy: proxy) } }
                        )
                        .onAppear { tips.show(.forumRotorActions) }

                        if preferences.aiSummariesEnabled && IntelligenceService.isAvailable {
                            summarizeSection(detail)
                        }

                        ForEach(Array(detail.replies.enumerated()), id: \.element.id) { index, reply in
                            // The parent is always on this same topic — Drupal's
                            // `pid` only ever points within the same commented
                            // entity — so this is a plain lookup in the page
                            // already on screen, never a second fetch.
                            let parentReply = reply.parentId.flatMap { pid in detail.replies.first(where: { $0.id == pid }) }
                            ReplyView(
                                reply: reply, index: index, total: detail.replies.count,
                                topicAuthorId: detail.authorId, topicTitle: detail.title, topicURL: detail.url,
                                parentAuthorName: parentReply?.authorName,
                                onReplyTo: {
                                    guard auth.isSignedIn else {
                                        toast.warning(String(localized: "Sign in to reply to posts."))
                                        return
                                    }
                                    quotedReplyTarget = reply
                                },
                                onJumpToParent: parentReply.map { parent in { pendingFocusReplyId = parent.id } },
                                onDelete: { removeReplyLocally(reply, announcement: String(localized: "Reply deleted.")) },
                                onEdit: { newBody in
                                    guard let idx = self.detail?.replies.firstIndex(where: { $0.id == reply.id }) else { return }
                                    self.detail?.replies[idx] = ForumReply(
                                        id: reply.id, subject: reply.subject, authorName: reply.authorName,
                                        authorId: reply.authorId, body: newBody, createdAt: reply.createdAt,
                                        loveCount: reply.loveCount, isNew: reply.isNew, parentId: reply.parentId
                                    )
                                },
                                onUnpublish: { removeReplyLocally(reply, announcement: String(localized: "Comment unpublished.")) },
                                focusBinding: $focusedReplyId
                            )
                            .id(reply.id)
                            Divider().padding(.leading)
                        }

                        if hasMoreReplies {
                            if isLoadingMoreReplies {
                                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(String(localized: "Loading more…")).padding()
                            } else {
                                let remaining = detail.replyCount - detail.replies.count
                                Button(remaining > 0 ? "Load \(remaining) More Replies" : "Load More Replies") {
                                    Task { await loadMoreRepliesPage() }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(preferences.colors.background)
            // A freshly-posted reply already has the AccessibilityFocusState
            // plumbing (`focusBinding` above) and the same delayed-set
            // pattern `jumpToLastReply` uses just above — it just never got
            // wired at the point a reply is actually submitted, silently
            // leaving VoiceOver focus wherever it was on the compose sheet.
            .onChange(of: pendingFocusReplyId) { _, newId in
                guard let newId else { return }
                withReduceMotionAwareAnimation { proxy.scrollTo(newId, anchor: .bottom) }
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    focusedReplyId = newId
                    pendingFocusReplyId = nil
                }
            }
            // Guarded on hasApplied rather than just the intent flag —
            // topicContent(_:) re-renders on every reply-list mutation
            // (posting a reply, deleting one), and this should only ever
            // fire once, right after the initial load this screen was
            // opened for.
            // Keyed on isLoading so this waits for load() to finish: the
            // page can appear before the new-comment count is known (App
            // Store enrichment, Follow state), and jumping then found
            // nothing new and gave up — leaving VoiceOver on the title.
            // Reported directly.
            .task(id: isLoading) {
                guard !isLoading, focusFirstNewCommentOnAppear, !hasAppliedFirstNewCommentFocus else { return }
                hasAppliedFirstNewCommentFocus = true
                // Nothing to land on after all — load() skipped the title
                // for this, so put focus there instead of nowhere.
                if !(await jumpToFirstNewReply(proxy: proxy)), hasNewReplies { focusTitleAfterLoad() }
            }
            .task {
                guard let targetCommentId, !hasAppliedTargetCommentFocus else { return }
                hasAppliedTargetCommentFocus = true
                if hasMoreReplies { await ensureAllRepliesLoaded() }
                pendingFocusReplyId = targetCommentId
            }
            // Two custom VoiceOver rotor categories — turn two fingers to
            // reach "New Comments"/"Replies to Me" alongside the built-in
            // Headings/Links options, then swipe with one finger to move
            // only between entries in whichever one is selected. Unlike
            // "Jump to First New Comment" (a one-shot landing spot), the
            // rotor stays in that filtered set across swipes — the natural
            // next step when there's more than one new reply to get through.
            .accessibilityRotor("New Comments") {
                ForEach(detail.replies.filter(\.isNew)) { reply in
                    AccessibilityRotorEntry(reply.authorName, id: reply.id)
                }
            }
            // "Replies to Me" only means anything once signed in — auth.user
            // is nil otherwise, and both match checks below already return
            // false without one, but the rotor shouldn't advertise a
            // category that can never have entries for a signed-out reader.
            // Checks the real `pid` relationship first (reliable — matches
            // by account id, not display name) and falls back to the old
            // text-quote heuristic for replies posted before the site
            // exposed `pid` at all, which never set it.
            .accessibilityRotor("Replies to Me") {
                ForEach(detail.replies.filter { reply in
                    guard let user = auth.user else { return false }
                    if let parentId = reply.parentId,
                       let parent = detail.replies.first(where: { $0.id == parentId }) {
                        return parent.authorId == user.uuid
                    }
                    return QuotedReply.isDirectedAt(user.name, body: reply.body)
                }) { reply in
                    AccessibilityRotorEntry(reply.authorName, id: reply.id)
                }
            }
        }
    }

    @ViewBuilder
    private func summarizeSection(_ detail: ForumTopicDetail) -> some View {
        if detail.replies.count >= 5 {
            VStack(alignment: .leading, spacing: 12) {
                summarizeDiscussionRow(detail)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
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
            .accessibilityLabel(String(localized: isSummarizing ? "Summarizing discussion, please wait" : "Summarize Discussion"))
        }
    }

    private func postAndActivityDateText(_ detail: ForumTopicDetail) -> String {
        let posted = detail.createdAt.formatted(.relative(presentation: .named))
        guard detail.replyCount > 0 else { return posted }
        return "\(posted), last comment \(detail.lastActivityAt.formatted(.relative(presentation: .named)))"
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
            toast.error(String(localized: "Couldn't generate a summary for this discussion. Try again."))
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
        ThreadOverview.announce(
            commentCount: detail.replies.count,
            mostRecentAuthor: mostRecent?.authorName,
            mostRecentDate: mostRecent?.createdAt,
            originalAuthor: detail.authorName
        )
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

    private func load() async {
        isLoading = true
        error = nil
        do {
            var fetched = try await APIClient.shared.forums.topicDetail(id: topicId)
            // ForumReply.isNew was hardcoded false in Mappers.swift and never
            // set anywhere — wire it to the same per-item visit-stamp
            // mechanism Home already uses for its own "N new" counts.
            // Captured before stampItemVisit below overwrites it with "now".
            // Marked before `detail` is assigned, so the page never shows
            // (or jumps) with every reply still unmarked. Falls back to when
            // Home first saw the topic, like Home's own counts do — without
            // that, a topic Home said had "3 new comments" showed none as
            // new once opened, and Jump to First New Comment found nothing.
            // Reported directly.
            newRepliesSince = PersistenceStore.shared.newActivityCutoff(kind: .forumTopic, id: fetched.id)
            fetched.replies = markingNew(fetched.replies)
            detail = fetched
            isFollowing = detail.map { PersistenceStore.shared.isFollowed(id: $0.id) || FollowStore.shared.isFollowed($0.id) } ?? false
            isSaved = detail.map { PersistenceStore.shared.isSaved(id: $0.id) } ?? false
            if let user = auth.user, let topicUuid = detail?.id {
                await FollowStore.shared.loadIfNeeded(for: user)
                isFollowing = isFollowing || FollowStore.shared.isFollowed(topicUuid)
            }
            PersistenceStore.shared.markTopicSeen(id: topicId)
            PersistenceStore.shared.lastViewedForumTopicId = topicId
            // Opening the topic itself should clear its "new" state on Home,
            // not just Home's own explicit "Mark as Read" action — otherwise
            // a topic you've actually read stays flagged as new indefinitely.
            if let detail {
                PersistenceStore.shared.stampItemVisit(
                    id: FeedItem.visitKey(kind: .forumTopic, contentId: detail.id),
                    commentCount: detail.replyCount
                )
                // Keeps the website's own "read" state (Drupal core's
                // History module) in sync with what's viewed in the app —
                // signed-out users still rely on the local stamp above only.
                if let csrfToken = auth.user?.csrfToken {
                    Task { await APIClient.shared.history.markRead(nid: detail.nid, csrfToken: csrfToken) }
                }
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
                Task { await ensureAllRepliesLoaded() }
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
        } catch { self.error = String(localized: "Couldn't load topic.") }
        isLoading = false
        // Opened via "Jump to First New Comment": that comment gets focus
        // instead. Title focus used to run regardless, and its retries could
        // pull focus straight back to the title. Reported directly.
        if !(focusFirstNewCommentOnAppear && hasNewReplies) { focusTitleAfterLoad() }
    }

    private func toggleFollow() async {
        guard let user = auth.user, let d = detail else { return }
        do {
            if isFollowing {
                try await APIClient.shared.forums.unfollow(nodeUuid: d.id, token: user.csrfToken)
                isFollowing = false
                PersistenceStore.shared.markUnfollowed(id: d.id)
                FollowStore.shared.markNotFollowed(d.id)
                toast.success(String(localized: "Unfollowed topic"))
            } else {
                try await APIClient.shared.forums.follow(nodeUuid: d.id, entityId: d.nid, token: user.csrfToken)
                isFollowing = true
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: d.id, kind: .forumTopic, nodeType: "node--forum",
                    title: d.title, followedAt: Date(), lastActivityAt: d.lastActivityAt, url: d.url
                ))
                FollowStore.shared.markFollowed(d.id)
                toast.success(String(localized: "Following topic"))
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: isFollowing ? "Couldn't unfollow topic. Try again." : "Couldn't follow topic. Try again."))
        }
    }

    /// Loads every remaining page in one go instead of requiring a tap per
    /// page — the server clamps each request to its own max page size
    /// (see the hasMoreReplies fix above), so a thread with hundreds of
    /// replies could otherwise take several manual "Load More" taps to
    /// fully unroll. Reported directly as unwanted friction.
    /// Fetches exactly one page of replies — the manual "Load More Replies"
    /// button uses this. Previously the button called the fetch-everything
    /// loop below, so a single tap on a 100+ reply thread could trigger
    /// dozens of round trips and construct the entire remaining list at
    /// once (FORUM-05). Tapping again fetches the next page.
    private func loadMoreRepliesPage() async {
        guard let current = self.detail, current.replies.count < current.replyCount else {
            hasMoreReplies = false
            return
        }
        isLoadingMoreReplies = true
        do {
            let more = try await APIClient.shared.forums.moreReplies(topicId: current.id, offset: current.replies.count)
            if more.isEmpty {
                hasMoreReplies = false
            } else {
                self.detail?.replies.append(contentsOf: markingNew(more))
            }
        } catch {
            toast.error(String(localized: "Couldn't load more replies."))
        }
        hasMoreReplies = (self.detail?.replies.count ?? 0) < (self.detail?.replyCount ?? 0)
        isLoadingMoreReplies = false
    }

    /// Fetches every remaining page in one go — used only by "Jump to Last
    /// Comment" (`jumpToLastReply`), which genuinely needs the true last
    /// reply regardless of how many pages remain.
    private func loadAllRemainingReplies() async {
        isLoadingMoreReplies = true
        do {
            while let current = self.detail, current.replies.count < current.replyCount {
                let more = try await APIClient.shared.forums.moreReplies(topicId: current.id, offset: current.replies.count)
                guard !more.isEmpty else { break }
                self.detail?.replies.append(contentsOf: markingNew(more))
            }
        } catch {
            toast.error(String(localized: "Couldn't load more replies."))
        }
        hasMoreReplies = (self.detail?.replies.count ?? 0) < (self.detail?.replyCount ?? 0)
        isLoadingMoreReplies = false
    }

    /// Single-flight wrapper around loadAllRemainingReplies() — see
    /// loadAllRepliesTask's doc comment for why this exists.
    private func ensureAllRepliesLoaded() async {
        if let existing = loadAllRepliesTask {
            await existing.value
            return
        }
        let task = Task { await loadAllRemainingReplies() }
        loadAllRepliesTask = task
        await task.value
        loadAllRepliesTask = nil
    }

    /// "Jump to Last Comment" custom action on the Community Discussion
    /// heading — mirrors the existing jump-to-first-new-item pattern
    /// elsewhere in the app (e.g. Home's What's New card), requested
    /// directly as an alternative to manually scrolling through a long
    /// thread. Loads any not-yet-fetched replies first so it always lands
    /// on the true last reply, not just the last of whatever's loaded so far.
    /// Focuses a stable neighbor after a reply is deleted (FORUM-11) —
    /// mirrors the existing post-reply focus pattern (`pendingFocusReplyId`),
    /// but without its scroll-to-bottom animation, since the neighbor is
    /// typically already visible right where the deleted reply was. Falls
    /// back to the topic title if the deleted reply had no neighbors (it
    /// was the only one left).
    private func focusAfterReplyRemoval(neighborId: String?, announcement: String) {
        UIAccessibility.post(notification: .announcement, argument: announcement)
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if let neighborId {
                focusedReplyId = neighborId
            } else {
                isTitleFocused = true
            }
        }
    }

    /// Shared by both Delete and admin Unpublish — either way, the comment
    /// no longer belongs in the currently-loaded list, and the neighbor-
    /// focus logic (next reply first, falling back to the topic title) is
    /// identical regardless of which action removed it.
    private func removeReplyLocally(_ reply: ForumReply, announcement: String) {
        let replies = self.detail?.replies ?? []
        guard let idx = replies.firstIndex(where: { $0.id == reply.id }) else { return }
        let neighborId: String? = idx + 1 < replies.count ? replies[idx + 1].id
            : (idx > 0 ? replies[idx - 1].id : nil)
        self.detail?.replies.remove(at: idx)
        self.detail?.replyCount = max(0, (self.detail?.replyCount ?? 1) - 1)
        focusAfterReplyRemoval(neighborId: neighborId, announcement: announcement)
    }

    /// "Community Discussion - N comments - N new" — the app's own
    /// documented convention (docs/IMPLEMENTATION_NOTES.md) that
    /// `CommunityDiscussionHeading` never actually surfaced anywhere
    /// (ALL-01). Reuses the per-reply `isNew` flag already wired up above,
    /// which is more precise than a raw count-delta since it survives a
    /// reply being deleted and a different one added in the same visit.
    private var newReplyCountForHeading: Int {
        detail?.replies.filter(\.isNew).count ?? 0
    }

    private var hasNewReplies: Bool { newReplyCountForHeading > 0 }

    private func markingNew(_ replies: [ForumReply]) -> [ForumReply] {
        guard let since = newRepliesSince else { return replies }
        return replies.map { reply in
            var reply = reply
            reply.isNew = reply.createdAt > since
            return reply
        }
    }

    /// "Jump to First New Comment" — mirrors jumpToLastReply, landing on
    /// the earliest reply posted since the previous visit instead of the
    /// thread's very end.
    @discardableResult
    private func jumpToFirstNewReply(proxy: ScrollViewProxy) async -> Bool {
        if hasMoreReplies { await ensureAllRepliesLoaded() }
        guard let firstNew = detail?.replies.first(where: { $0.isNew }) else { return false }
        withReduceMotionAwareAnimation { proxy.scrollTo(firstNew.id, anchor: .top) }
        // Retried like the title focus — one assignment after a guessed
        // delay could miss a row that wasn't laid out yet.
        await retryAccessibilityFocus(firstNew.id, into: $focusedReplyId)
        return true
    }

    private func jumpToLastReply(proxy: ScrollViewProxy) async {
        if hasMoreReplies { await ensureAllRepliesLoaded() }
        guard let lastId = self.detail?.replies.last?.id else { return }
        withReduceMotionAwareAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
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
            toast.success(String(localized: "Removed from Saved"))
        } else {
            PersistenceStore.shared.save(SavedItem(
                id: detail.id, kind: .forumTopic, title: detail.title,
                savedAt: Date(), lastActivityAt: detail.lastActivityAt
            ))
            isSaved = true
            toast.success(String(localized: "Saved"))
        }
    }

    /// Both Follow and Reply used to be hidden entirely until signed in —
    /// invisible to a VoiceOver user with no way to discover either exists,
    /// and inconsistent with Home's Add menu and the other five detail
    /// screens' Comment/Review buttons, which now show always and gate on
    /// tap instead. `toggleFollow()`'s own `guard let user = auth.user`
    /// previously made a signed-out Follow tap possible in theory (had the
    /// button ever been reachable) a silent no-op with zero feedback.
    private func requestFollowToggle() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to follow this topic."))
            return
        }
        Task { await toggleFollow() }
    }

    private func requestReply() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to add a comment."))
            return
        }
        showReplyCompose = true
    }

    private func bottomActionBar(_ detail: ForumTopicDetail) -> some View {
        // Order matches ContentDetailActions' canonical order: Save,
        // Follow, Share, Browser, then Comment last — previously Follow
        // sat before Save here, the one detail screen with its own bespoke
        // bar rather than the shared component, and no one had reconciled
        // the two orderings.
        HStack(spacing: 0) {
            DetailActionButton(
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                visualLabel: isSaved ? "Unsave" : "Save",
                accessibilityLabel: isSaved ? "Unsave Topic" : "Save Topic"
            ) { toggleSave() }

            // Follow is shelved (see ContentActions.swift's
            // `followFeatureEnabled`) — hides starting a new follow, but
            // never hides undoing one someone already has.
            if followFeatureEnabled || isFollowing {
                DetailActionButton(
                    systemImage: isFollowing ? "bell.fill" : "bell",
                    visualLabel: isFollowing ? "Unfollow" : "Follow",
                    accessibilityLabel: isFollowing ? "Unfollow Topic" : "Follow Topic"
                ) { requestFollowToggle() }
            }

            if let shareURL = URL(string: detail.url) {
                ShareLink(item: shareURL, subject: Text(detail.title)) {
                    DetailActionButtonLabel(systemImage: "square.and.arrow.up", visualLabel: "Share")
                }
                .accessibilityLabel(String(localized: "Share topic"))

                DetailActionButton(systemImage: "safari", visualLabel: "Browser", accessibilityLabel: "Open topic in browser") {
                    openInBrowser()
                }
            }

            DetailActionButton(systemImage: "bubble.left", visualLabel: "Comment", accessibilityLabel: "Add Comment") {
                requestReply()
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
    var topicURL: String = ""
    /// Set only when `reply.parentId` resolved to a comment actually present
    /// in the currently-loaded list — matches the site's own new "In reply
    /// to [Title] by [Author]" citation (confirmed live 2026-09-15: it's
    /// theme-rendered from the real `pid` relationship, not typed into the
    /// comment body — see `ForumReply.parentId`'s doc comment).
    var parentAuthorName: String? = nil
    var onReplyTo: (() -> Void)? = nil
    /// Scrolls to and focuses the parent comment this one is replying to —
    /// nil (hiding the citation's tap/action entirely) if the parent isn't
    /// in the currently-loaded page yet, e.g. still behind "Load More
    /// Replies".
    var onJumpToParent: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    /// Fired after an admin unpublish succeeds — like `onDelete`, lets the
    /// parent remove the now-hidden comment from the loaded list.
    var onUnpublish: (() -> Void)? = nil
    /// Set by the parent when it supports "Jump to Last Comment" — lets
    /// that action move VoiceOver focus here, not just scroll the viewport.
    var focusBinding: AccessibilityFocusState<String?>.Binding? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showDeleteConfirm = false
    @State private var showUnpublishConfirm = false
    @State private var showEditSheet = false
    @State private var showReportSheet = false

    private var reportContext: ReportCommentContext {
        ReportCommentContext(
            authorName: reply.authorName,
            commentExcerpt: .excerpt(from: reply.body),
            commentDate: reply.createdAt,
            contentTitle: topicTitle,
            contentURL: topicURL
        )
    }

    private var isOriginalPoster: Bool {
        !topicAuthorId.isEmpty && topicAuthorId == reply.authorId
    }

    private var isAdmin: Bool { auth.user?.isAdmin ?? false }

    private var isOwnComment: Bool {
        guard let user = auth.user else { return false }
        return !reply.authorId.isEmpty && user.uuid == reply.authorId
    }

    /// Edit/Delete: author of the comment, or an admin. Unpublish is
    /// admin-only, kept separate — mirrors the topic-level split between
    /// owner actions and admin moderation actions.
    private var canDelete: Bool { isAdmin || isOwnComment }

    /// "Comment 2 of 8. Jane Doe, Original Poster. 3 hours ago. Subject: ..."
    /// — mirrors the old app's per-comment header label so VoiceOver users
    /// get the same at-a-glance context and rotor-navigable heading stops.
    private var headerAccessibilityLabel: String {
        // Built from translated pieces — was plain English string building,
        // so VoiceOver read every comment header in English in every
        // language.
        var label = String(localized: "Comment \(index + 1) of \(total). \(reply.authorName)")
        if isOriginalPoster { label += String(localized: ", Original Poster") }
        label += ". \(reply.createdAt.formatted(.relative(presentation: .named)))."
        if let subject = CommentSubject.display(reply.subject, parentTitle: topicTitle) {
            label += " " + String(localized: "Subject: \(subject).")
        }
        if let parentAuthorName {
            label += " " + String(localized: "Reply to \(parentAuthorName)'s comment.")
        }
        if reply.isNew { label += " " + String(localized: "New.") }
        return label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Matches the site's own new "In reply to [Title] by [Author]"
            // citation — a separate, tappable stop rather than folded into
            // the header row, so a VoiceOver user can act on it (jump to the
            // parent) without it lengthening every reply's main heading.
            // Hidden entirely (not just inert) when the parent isn't loaded
            // yet, rather than showing a citation that goes nowhere.
            if let parentAuthorName, let onJumpToParent {
                Button(action: onJumpToParent) {
                    Label(String(localized: "Replying to \(parentAuthorName)"), systemImage: "arrowshape.turn.up.left")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHint(String(localized: "Jumps to the comment this one replies to."))
            }
            HStack {
                AuthorProfileButton(name: reply.authorName, authorId: reply.authorId, font: .subheadline.weight(.medium), showAvatar: true)
                Spacer()
                RelativeDateLabel(date: reply.createdAt)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(headerAccessibilityLabel)
            .accessibilityHint(String(localized: "Actions available: reply, copy, share, and more."))
            .modifier(OptionalReplyFocus(binding: focusBinding, id: reply.id))
            .readAloudAction(reply.body.strippingHTMLTags())
            .accessibilityAction(named: Text("Reply to this Comment")) { onReplyTo?() }
            .accessibilityAction(named: Text("Copy Comment Text")) { copyText() }
            .accessibilityAction(named: Text("Share Comment")) { presentShareSheet() }
            // "Mark as Helpful" removed for now — it only ever showed a
            // "coming once the Drupal Flags API is confirmed" toast, no
            // real functionality yet. Revisit once that backend work is
            // done. Requested directly.
            .accessibilityAction(named: Text("Report Comment")) {
                showReportSheet = true
            }
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Edit Comment") { showEditSheet = true })
            .modifier(ConditionalAccessibilityAction(isActive: isAdmin, name: "Unpublish Comment") { showUnpublishConfirm = true })
            .modifier(ConditionalAccessibilityAction(isActive: canDelete, name: "Delete Comment") { showDeleteConfirm = true })

            SegmentedHTMLView(html: reply.body, contentKind: "forumReply", contentId: reply.id, field: "body")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(reply.isNew ? Color.accentColor.opacity(0.05) : .clear)
        .sheet(isPresented: $showReportSheet) {
            ReportCommentWizard(context: reportContext)
        }
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
            Button { showReportSheet = true } label: {
                Label("Report Comment", systemImage: "flag")
            }
            // "Comment" throughout, matching the rest of this screen (the
            // header label, Reply/Copy/Share/Report actions above,
            // and the "Comment text copied" toast) — this pair previously
            // said "Reply" here despite VoiceOver already calling the exact
            // same actions "Edit Comment"/"Delete Comment".
            if canDelete {
                Button { showEditSheet = true } label: {
                    Label("Edit Comment", systemImage: "pencil")
                }
            }
            if isAdmin {
                Button { showUnpublishConfirm = true } label: {
                    Label("Unpublish Comment", systemImage: "eye.slash")
                }
            }
            if canDelete {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Unpublish this comment?", isPresented: $showUnpublishConfirm, titleVisibility: .visible) {
            Button("Unpublish", role: .destructive) { Task { await unpublish() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This hides it from public view.")
        }
        .confirmationDialog("Delete this comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            EditContentSheet(title: String(localized: "Edit Comment"), initialText: reply.rawBody) { newText in
                guard let user = auth.user else { return }
                try await APIClient.shared.content.editComment(
                    commentType: "comment_forum", commentId: reply.id, newBody: newText, format: reply.bodyFormat, csrfToken: user.csrfToken
                )
                onEdit?(newText)
                toast.success(String(localized: "Comment updated"))
            }
        }
    }

    private func copyText() {
        UIPasteboard.general.string = reply.body.strippingHTMLTags()
        toast.success(String(localized: "Comment text copied"))
    }

    /// Mirrors the old app's "Share Comment" action — shares the comment as
    /// plain text (author, subject if meaningful, body), not a URL, since
    /// individual replies have no shareable link of their own.
    private func presentShareSheet() {
        let plain = reply.body.strippingHTMLTags()
        let subject = reply.subject.trimmingCharacters(in: .whitespaces)
        var message = String(localized: "\(reply.authorName) on AppleVis")
        if !subject.isEmpty { message += String(localized: ":\n\nSubject: \(subject)") }
        message += "\n\n\(plain)"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }

    private func unpublish() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.unpublishComment(commentType: "comment_forum", commentId: reply.id, csrfToken: user.csrfToken)
            onUnpublish?()
            toast.success(String(localized: "Comment unpublished"))
        } catch {
            toast.error(String(localized: "Couldn't unpublish comment."))
        }
    }

    private func delete() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteComment(commentType: "comment_forum", commentId: reply.id, csrfToken: user.csrfToken)
            onDelete?()
            toast.success(String(localized: "Reply deleted"))
        } catch {
            toast.error(String(localized: "Couldn't delete reply."))
        }
    }
}
