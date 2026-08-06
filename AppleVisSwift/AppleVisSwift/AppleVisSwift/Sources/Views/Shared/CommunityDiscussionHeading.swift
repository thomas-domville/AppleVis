import SwiftUI

/// Shared comments/reviews-section heading used across all content-detail
/// screens (forum topics, apps, podcast episodes, blog posts, resources).
/// Includes a VoiceOver "Thread overview" custom action giving a spoken
/// summary in place of manually reading through every comment, and an
/// optional "Jump to Last Comment" link for screens wired up to scroll
/// (requested directly as an alternative to manually scrolling a long
/// thread) — omit `onJumpToLast` for screens that don't support it yet.
///
/// "Jump to Last Comment" is a real, visible, separately-focusable row
/// right after the heading — not a hidden `.accessibilityAction` — because
/// a first attempt using a custom action on the heading went undiscovered:
/// VoiceOver only surfaces custom actions through the actions rotor, not
/// as something you swipe past, and this needed to be as easy to find as
/// Home's "Jump to first" unread-topics link.
struct CommunityDiscussionHeading: View {
    let count: Int
    let onThreadOverview: () -> Void
    var onJumpToLast: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Community Discussion")
                    .font(.headline)
                Spacer()
                Text("\(count) comment\(count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Community Discussion, \(count) comment\(count == 1 ? "" : "s")")
            .accessibilityAction(named: Text("Thread overview"), onThreadOverview)

            if let onJumpToLast, count > 1 {
                Button(action: onJumpToLast) {
                    HStack {
                        Text("Jump to Last Comment")
                            .font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.down.to.line")
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Jump to Last Comment")
                .accessibilityHint("Loads any remaining comments and moves to the last one.")
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
