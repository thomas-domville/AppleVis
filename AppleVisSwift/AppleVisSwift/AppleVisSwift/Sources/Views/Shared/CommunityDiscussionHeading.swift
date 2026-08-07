import SwiftUI
import UIKit

/// Every `withAnimation { proxy.scrollTo(...) }` call site in the app ran
/// unconditionally, ignoring Reduce Motion entirely — passing `nil` to
/// `withAnimation` still applies the change, just instantly instead of
/// animated, which is exactly what Reduce Motion asks for.
func withReduceMotionAwareAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .default, body)
}

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
            // Matches RN's SectionDivider (flanking lines around a
            // centered uppercase label) — Swift's version was plain
            // left-aligned text with no divider treatment at all.
            HStack(spacing: 10) {
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                Text("COMMUNITY DISCUSSION")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Community Discussion, \(count) comment\(count == 1 ? "" : "s")")
            .accessibilityAction(named: Text("Thread overview"), onThreadOverview)

            if count > 0 {
                Text("\(count) comment\(count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

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

/// Suppresses generic default comment subjects ("Comment", "Reply",
/// "Review", "Re", "Add new comment") and subjects that just duplicate the
/// parent title — Drupal defaults a comment's subject to one of these
/// unless the poster changes it. Shared by ForumReply (ForumTopicDetailView)
/// and the generic CommentRow (Blog/Guide/Podcast comments) so reading a
/// comment aloud doesn't announce "Subject: Comment." for no reason.
enum CommentSubject {
    static func display(_ subject: String, parentTitle: String) -> String? {
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
}

/// Shared "quote and reply" text builder — every content type's reply flow
/// (Forums' ComposeReplyView originally, now also Guides/Blogs/Podcasts/Apps)
/// prefixes the compose box with the same quoted-excerpt format, so replying
/// to a comment reads the same everywhere.
enum QuotedReply {
    static func prefix(authorName: String, body: String) -> String {
        let plain = body.strippingHTMLTags()
        let excerpt = plain.count > 150 ? String(plain.prefix(150)).trimmingCharacters(in: .whitespaces) + "…" : plain
        return "\(authorName) wrote:\n> \(excerpt)\n\n"
    }
}
