import SwiftUI

/// A post to open at its first new comment, pushed onto the navigation
/// stack the row is in.
struct FirstNewCommentTarget: Hashable {
    let kind: ContentKind
    let id: String
}

/// Offered to rows by the stack around them. "Jump to First New Comment"
/// used to open the post in a sheet over the whole app (the route
/// notifications and links use), because the shared row actions couldn't
/// reach the stack they were in. So it looked different from a normal open,
/// with "Close detail" where "Home, Back" should be, and anything opened
/// from it stacked inside the sheet. Reported directly (2026-10-05).
struct OpenAtFirstNewCommentAction {
    let open: (FirstNewCommentTarget) -> Void

    func callAsFunction(kind: ContentKind, id: String) {
        open(FirstNewCommentTarget(kind: kind, id: id))
    }
}

private struct OpenAtFirstNewCommentKey: EnvironmentKey {
    static let defaultValue: OpenAtFirstNewCommentAction? = nil
}

extension EnvironmentValues {
    var openAtFirstNewComment: OpenAtFirstNewCommentAction? {
        get { self[OpenAtFirstNewCommentKey.self] }
        set { self[OpenAtFirstNewCommentKey.self] = newValue }
    }
}

/// `NavigationStack` with its own path, so rows inside it can open a post at
/// its first new comment on this stack. The nearest stack always wins: a row
/// in a sheet opens the post inside that sheet, never behind it.
struct AppNavigationStack<Root: View>: View {
    @State private var path = NavigationPath()
    private let root: Root

    init(@ViewBuilder root: () -> Root) {
        self.root = root()
    }

    var body: some View {
        let path = $path
        NavigationStack(path: path) {
            root.firstNewCommentDestination()
        }
        .environment(\.openAtFirstNewComment, OpenAtFirstNewCommentAction { path.wrappedValue.append($0) })
    }
}

extension View {
    /// For a stack that manages its own path (Discover, Ask the Mouse):
    /// pairs with setting `openAtFirstNewComment` on the stack.
    func firstNewCommentDestination() -> some View {
        navigationDestination(for: FirstNewCommentTarget.self) { target in
            ContentDetailDestination(kind: target.kind, id: target.id, focusFirstNewComment: true)
        }
    }
}

/// The detail screen for any kind of post. Shared by the stacks above and
/// by ContentView's sheet for notifications, Spotlight, and links.
struct ContentDetailDestination: View {
    let kind: ContentKind
    let id: String
    var focusFirstNewComment = false

    var body: some View {
        switch kind {
        case .forumTopic:
            ForumTopicDetailView(topicId: id, focusFirstNewCommentOnAppear: focusFirstNewComment)
        case .podcastEpisode:
            EpisodeDetailView(episodeId: id, focusFirstNewCommentOnAppear: focusFirstNewComment)
        case .appListing:
            AppDetailView(appId: id, focusFirstNewCommentOnAppear: focusFirstNewComment)
        case .resource:
            ResourceDetailView(resourceId: id, focusFirstNewCommentOnAppear: focusFirstNewComment)
        case .blogPost:
            BlogDetailView(postId: id, focusFirstNewCommentOnAppear: focusFirstNewComment)
        case .bugReport:
            BugDetailView(bugId: id, focusFirstNewCommentOnAppear: focusFirstNewComment)
        }
    }
}
