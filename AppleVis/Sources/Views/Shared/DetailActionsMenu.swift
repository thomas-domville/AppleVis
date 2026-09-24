import SwiftUI
import UIKit

/// Top-right "<Kind> actions" menu for a content detail screen. Duplicates
/// the bottom bar's everyday actions (Save/Follow/Recommend/Comment/Share/
/// Browser) as a second, menu-based path to the same actions, and adds
/// content moderation that previously only existed on the Forum Topic
/// screen: the original submitter (`isOwnContent`) gets Edit + Delete; an
/// admin/editor gets Edit + Unpublish + Delete. Generalizes
/// ForumTopicDetailView's own hand-rolled "Topic actions" Menu to every
/// content kind, since every one of them (App Entry, Episode, Blog Post,
/// Guide, Bug Report) is either user-submitted or editor-managed the same
/// way a forum topic is. Requested directly, to make this consistent
/// everywhere it applies.
///
/// Edit/Unpublish/Delete are deliberately left as caller-supplied closures
/// rather than handled inside this view: every call site already has the
/// full content (title/body) loaded for its own detail screen, so there's
/// no need to duplicate `ContentActionsModifier`'s fetch-then-edit path
/// (built for browse-list rows, which only ever hold a summary). This view
/// only owns the Unpublish/Delete confirmation prompts themselves.
struct DetailActionsMenu: View {
    let id: String
    /// The target's internal Drupal node ID (nid), not its JSON:API UUID —
    /// required by Follow/Recommend's `entity_id` attribute; see
    /// `FlagEndpoints.follow`'s doc comment for why.
    let entityId: Int
    let kind: ContentKind
    let title: String
    let lastActivityAt: Date?
    let url: String?
    var supportsFollow: Bool = true
    /// Empty when there's no reliable author to show (Podcast Episode has
    /// no author identity) — `ReportCommentContext` reads this the same way
    /// `CommentRow` does.
    var authorName: String = ""
    /// A short excerpt of the content's own body, for the report preview —
    /// empty is fine, the wizard just omits that part of the preview.
    var excerpt: String = ""
    /// True when the signed-in user is this content's original submitter.
    /// Always false for kinds with no author identity to compare (Podcast
    /// Episode) — the Edit/Delete section simply never appears for anyone
    /// but an admin, same end result as if this feature didn't exist there.
    var isOwnContent: Bool = false
    var onAddComment: () -> Void
    var onEdit: () -> Void
    var onUnpublish: () async -> Void
    var onDelete: () async -> Void
    /// Kind-specific admin-only extra actions appended after Delete — e.g.
    /// App Entry's "Refresh App Details".
    var adminExtras: AnyView = AnyView(EmptyView())

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var tips: TipStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var isSaved = false
    @State private var isFollowing = false
    @State private var isRecommended = false
    @State private var showBrowser = false
    @State private var showUnpublishConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showReportSheet = false

    private var isAdmin: Bool { auth.user?.isAdmin ?? false }

    /// `subjectKind` matches `menuAccessibilityLabel`'s existing "Episode"
    /// special-case — `ReportCommentContext` wants a lowercase singular
    /// noun ("episode," not "podcast," for a single episode's own page).
    private var reportContext: ReportCommentContext {
        ReportCommentContext(
            subjectKind: (kind == .podcastEpisode ? "Episode" : kind.englishName).lowercased(),
            authorName: authorName,
            commentExcerpt: excerpt,
            commentDate: lastActivityAt ?? Date(),
            contentTitle: title,
            contentURL: url ?? ""
        )
    }

    /// Same shelved-Follow gating as `ContentActionsModifier.canOfferFollow`
    /// — hides starting a new follow, never hides undoing an existing one.
    private var canOfferFollow: Bool {
        supportsFollow && auth.isSignedIn && (isFollowing || (followFeatureEnabled && entityId > 0))
    }

    private var canOfferRecommend: Bool {
        kind == .appListing && auth.isSignedIn && (isRecommended || entityId > 0)
    }

    /// "Podcast" is `ContentKind.podcastEpisode.displayName`, but this menu
    /// lives on a single episode's page, not the show's — "Podcast actions"
    /// would read as ambiguous about which one it means, the same reasoning
    /// `saveActionNoun` already documents for Save. "Episode" avoids it.
    private var menuAccessibilityLabel: String {
        let noun = kind == .podcastEpisode ? String(localized: "Episode") : kind.displayName
        return String(localized: "\(noun) actions")
    }

    var body: some View {
        Menu {
            Button {
                toggleSave()
            } label: {
                Label(isSaved ? "Unsave \(kind.saveActionNoun)" : "Save \(kind.saveActionNoun)", systemImage: isSaved ? "bookmark.slash" : "bookmark")
            }
            if canOfferFollow {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Label(isFollowing ? "Unfollow \(kind.displayName)" : "Follow \(kind.displayName)", systemImage: isFollowing ? "bell.slash" : "bell")
                }
            }
            if canOfferRecommend {
                Button {
                    Task { await toggleRecommend() }
                } label: {
                    Label(isRecommended ? "I No Longer Recommend This App" : "Recommend This App", systemImage: isRecommended ? "hand.thumbsdown" : "hand.thumbsup")
                }
            }
            Button {
                addComment()
            } label: {
                Label("Add Comment", systemImage: "bubble.left")
            }
            if let url, let shareURL = URL(string: url) {
                ShareLink(item: shareURL, subject: Text(title)) {
                    Label("Share \(kind.displayName)", systemImage: "square.and.arrow.up")
                }
                Button {
                    openInBrowser(shareURL)
                } label: {
                    Label("Open \(kind.displayName) in Browser", systemImage: "safari")
                }
            }
            // Reporting a comment already existed everywhere comments show
            // up (CommentRow/ReplyView/AppReviewRow) — the primary content
            // itself (a forum topic's original post, an app/blog/guide/bug/
            // episode entry) had no equivalent, so anything objectionable
            // about the content itself, rather than a reply to it, had no
            // in-app path to flag. Requested directly.
            Button {
                showReportSheet = true
            } label: {
                Label("Report \(kind.displayName)", systemImage: "flag")
            }
            // Owner-only actions gated on !isAdmin: an owner who is also an
            // admin already gets the superset admin section below (which
            // also adds Unpublish) — otherwise they'd see two
            // indistinguishable "Edit"/"Delete" entries, the same duplicate
            // class of bug ContentActionsModifier's own isOwnTopic gating
            // was written to avoid.
            if isOwnContent && !isAdmin {
                Section {
                    Button { onEdit() } label: { Label("Edit \(kind.displayName)", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete \(kind.displayName)", systemImage: "trash") }
                }
            }
            if isAdmin {
                Section {
                    Button { onEdit() } label: { Label("Edit \(kind.displayName)", systemImage: "pencil") }
                    Button { showUnpublishConfirm = true } label: { Label("Unpublish \(kind.displayName)", systemImage: "eye.slash") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete \(kind.displayName)", systemImage: "trash") }
                    adminExtras
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(menuAccessibilityLabel)
        .sheet(isPresented: $showBrowser) {
            if let url, let shareURL = URL(string: url) {
                SafariView(url: shareURL)
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportCommentWizard(context: reportContext)
        }
        .confirmationDialog(
            "Unpublish this \(kind.displayName.lowercased())?", isPresented: $showUnpublishConfirm, titleVisibility: .visible
        ) {
            Button("Unpublish", role: .destructive) { Task { await onUnpublish() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This hides it from public view.")
        }
        .confirmationDialog(
            "Delete this \(kind.displayName.lowercased())?", isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await onDelete() } }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            isSaved = PersistenceStore.shared.isSaved(id: id)
            isFollowing = PersistenceStore.shared.isFollowed(id: id) || FollowStore.shared.isFollowed(id)
            if let user = auth.user {
                Task {
                    await FollowStore.shared.loadIfNeeded(for: user)
                    isFollowing = isFollowing || FollowStore.shared.isFollowed(id)
                }
            }
            if kind == .appListing {
                isRecommended = RecommendationStore.shared.isRecommended(id)
                if let user = auth.user {
                    Task {
                        await RecommendationStore.shared.loadIfNeeded(for: user)
                        isRecommended = RecommendationStore.shared.isRecommended(id)
                    }
                }
            }
        }
    }

    private func addComment() {
        guard auth.isSignedIn else {
            toast.warning(String(localized: "Sign in to add a new comment."))
            return
        }
        onAddComment()
    }

    /// Matches WebLink's own in-app-vs-external branching so this respects
    /// the same preference instead of always forcing the in-app SafariView.
    private func openInBrowser(_ shareURL: URL) {
        switch preferences.webBrowsingMode {
        case .inApp:    showBrowser = true
        case .external: UIApplication.shared.open(shareURL)
        }
    }

    private func toggleSave() {
        if isSaved {
            PersistenceStore.shared.unsave(id: id)
            isSaved = false
            toast.success(String(localized: "Removed from Saved"))
        } else {
            PersistenceStore.shared.save(SavedItem(id: id, kind: kind, title: title, savedAt: Date(), lastActivityAt: lastActivityAt))
            isSaved = true
            toast.success(String(localized: "Saved"))
            SoundPlayer.shared.play(.bookmarkSaved)
        }
    }

    private func toggleFollow() async {
        guard let user = auth.user else { return }
        do {
            if isFollowing {
                try await APIClient.shared.flags.unfollow(nodeUuid: id, token: user.csrfToken)
                PersistenceStore.shared.markUnfollowed(id: id)
                FollowStore.shared.markNotFollowed(id)
                isFollowing = false
                toast.success(String(localized: "Unfollowed"))
            } else {
                try await APIClient.shared.flags.follow(nodeUuid: id, nodeType: kind.nodeType, entityId: entityId, token: user.csrfToken)
                PersistenceStore.shared.markFollowed(FollowedItem(
                    id: id, kind: kind, nodeType: kind.nodeType, title: title,
                    followedAt: Date(), lastActivityAt: lastActivityAt, url: url ?? ""
                ))
                FollowStore.shared.markFollowed(id)
                isFollowing = true
                toast.success(String(localized: "Following"))
                if kind == .forumTopic { tips.show(.followTopicNotifications) }
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't update follow status."))
        }
    }

    private func toggleRecommend() async {
        guard let user = auth.user else { return }
        do {
            if isRecommended {
                try await APIClient.shared.flags.unrecommend(nodeUuid: id, token: user.csrfToken)
                RecommendationStore.shared.markNotRecommended(id)
                isRecommended = false
                toast.success(String(localized: "Removed from Recommendations"))
            } else {
                try await APIClient.shared.flags.recommend(nodeUuid: id, nodeType: kind.nodeType, entityId: entityId, token: user.csrfToken)
                RecommendationStore.shared.markRecommended(id)
                isRecommended = true
                toast.success(String(localized: "You recommended this app!"))
                SoundPlayer.shared.play(.bookmarkSaved)
            }
        } catch let e as APIError {
            toast.error(e.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't update your recommendation."))
        }
    }
}
