import SwiftUI

/// Shared comments/reviews-section heading used across all content-detail
/// screens (forum topics, apps, podcast episodes, blog posts, resources).
/// Includes a VoiceOver "Thread overview" custom action giving a spoken
/// summary in place of manually reading through every comment, and an
/// optional "Jump to Last Comment" action for screens wired up to scroll
/// (requested directly as an alternative to manually scrolling a long
/// thread) — omit `onJumpToLast` for screens that don't support it yet.
struct CommunityDiscussionHeading: View {
    let count: Int
    let onThreadOverview: () -> Void
    var onJumpToLast: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text("Community Discussion")
                .font(.headline)
            Spacer()
            Text("\(count) comment\(count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Community Discussion, \(count) comment\(count == 1 ? "" : "s")")
        .accessibilityAction(named: Text("Thread overview"), onThreadOverview)
        .modifier(ConditionalNamedAccessibilityAction(name: "Jump to Last Comment", action: onJumpToLast))
    }
}

/// Attaches an `.accessibilityAction` only when `action` is non-nil —
/// distinct from ContentActions.swift's `ConditionalAccessibilityAction`
/// (which is gated by a Bool), this is gated by the closure's presence.
private struct ConditionalNamedAccessibilityAction: ViewModifier {
    let name: String
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.accessibilityAction(named: Text(name), action)
        } else {
            content
        }
    }
}

/// Applies `.accessibilityFocused(_:equals:)` only when a binding is
/// provided — lets ReplyView/CommentRow opt into being a "Jump to Last
/// Comment" landing target without every call site needing to supply one.
/// Not private — shared by ReplyView (ForumTopicDetailView.swift) and
/// CommentRow (ResourceDetailView.swift).
struct OptionalReplyFocus: ViewModifier {
    let binding: AccessibilityFocusState<String?>.Binding?
    let id: String

    func body(content: Content) -> some View {
        if let binding {
            content.accessibilityFocused(binding, equals: id)
        } else {
            content
        }
    }
}
