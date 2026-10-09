import SwiftUI
import UIKit

/// Every `withAnimation { proxy.scrollTo(...) }` call site in the app ran
/// unconditionally, ignoring Reduce Motion entirely — passing `nil` to
/// `withAnimation` still applies the change, just instantly instead of
/// animated, which is exactly what Reduce Motion asks for.
func withReduceMotionAwareAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .default, body)
}

extension View {
    /// RN's tinted card backgrounds (`Color.accentColor.opacity(0.08)` and
    /// similar) were swapped for a solid background whenever Reduce
    /// Transparency was on — Swift used the same translucent-tint pattern
    /// everywhere but never read the setting. `opacity` here is the tint
    /// strength used in the non-reduced case; the reduced case renders the
    /// same hue at full opacity mixed toward the system background instead
    /// of leaving it see-through.
    func tintedBackground(_ color: Color, opacity: Double, cornerRadius: CGFloat) -> some View {
        Group {
            if UIAccessibility.isReduceTransparencyEnabled {
                self.background(color.opacity(min(opacity * 3, 1)), in: RoundedRectangle(cornerRadius: cornerRadius))
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                self.background(color.opacity(opacity), in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
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
    /// Comments posted since this content was last visited — when set (and
    /// > 0), shows a "Jump to First New Comment" link above "Jump to Last
    /// Comment," so a returning reader can go straight to what they haven't
    /// seen instead of the thread's very end.
    var newCount: Int = 0
    var onJumpToFirstNew: (() -> Void)? = nil

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
            .accessibilityLabel(String(localized: "Community Discussion, \(commentCountPhrase(count))"))
            .accessibilityAction(named: Text("Thread overview"), onThreadOverview)

            if count > 0 {
                Text(commentCountPhrase(count))
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            if let onJumpToFirstNew, newCount > 0 {
                Button(action: onJumpToFirstNew) {
                    HStack {
                        Text("Jump to First New Comment")
                            .font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.down.to.line.compact")
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Jump to First New Comment"))
                .accessibilityHint(String(localized: "Moves to the first comment posted since your last visit."))
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
                .accessibilityLabel(String(localized: "Jump to Last Comment"))
                .accessibilityHint(String(localized: "Loads any remaining comments and moves to the last one."))
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

/// Under Community Discussion when nobody has commented yet: a friendly
/// line and a button to start the conversation. Every detail page shows
/// it, so an empty discussion is never a missing one. Forum topics used to
/// leave the section out entirely. Requested directly (2026-09-30).
struct NoCommentsYet: View {
    let onAddComment: () -> Void
    /// "Be the First to Reply" on forum topics.
    var buttonTitle: String = String(localized: "Be the First to Comment")

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No comments yet. Share your thoughts and start the conversation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                guard auth.isSignedIn else {
                    toast.warning(String(localized: "Sign in to add a new comment."))
                    return
                }
                onAddComment()
            } label: {
                Label(buttonTitle, systemImage: "bubble.left.and.text.bubble.right")
                    .font(.subheadline.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
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
/// The rest of CommentSubject, which makes the subject a comment is
/// posted with, is in Services/CommentSubject.swift (2026-10-09).
extension CommentSubject {
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

/// Replies made before 2026-10-09 outside the Forums. Reply to this Comment
/// used to paste "Name wrote:\n> excerpt" into the reply, because only
/// forum replies could be linked to the comment they answer. The website now
/// has a Reply button on every kind of comment, and the app links replies
/// the same way everywhere (`pid`), so nothing is pasted any more.
enum QuotedReply {
    /// Backs each detail screen's "Replies to Me" rotor, for older replies
    /// only: every screen checks the real reply link (`parentId`) first, and
    /// falls back to this for a reply posted before replies were linked.
    /// Does `body` open with the "Name wrote:" quote the app used to paste
    /// in when someone chose Reply to this Comment on one of `authorName`'s
    /// comments? It never catches a free-text "@username" mention.
    static func isDirectedAt(_ authorName: String, body: String) -> Bool {
        guard !authorName.isEmpty else { return false }
        return body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\(authorName) wrote:")
    }
}

extension Array {
    /// The `n` most-recently-posted items in a comment/reply/review list —
    /// backs each detail screen's "New Comments" rotor everywhere except
    /// Forums, whose `ForumReply` is the only model with a real per-item
    /// `isNew` flag. Every other kind's API only ever gives a count
    /// (`newCommentCount`/`newReviewCount`), so this relies on the same
    /// "arrives chronologically oldest-first" invariant each screen's
    /// `jumpToFirstNew*` function already depends on to find just the
    /// first new one — this is the same math, generalized to the full set.
    /// Always returns a valid (possibly empty) slice, however `n` compares
    /// to `count`.
    func newestSuffix(count n: Int) -> ArraySlice<Element> {
        let clamped = Swift.max(0, Swift.min(n, count))
        return self[(count - clamped)...]
    }
}

/// The spoken overview every detail page announces once its thread loads
/// ("Thread has 12 comments. Most recent comment by Jane, 3 hours ago.
/// Original post by Sam."). Was six copies of plain English string
/// building — one per detail page — so VoiceOver read it in English in
/// every language. One translated copy now; the comment count uses the
/// catalog's plural variations.
enum ThreadOverview {
    static func announce(commentCount: Int, mostRecentAuthor: String?, mostRecentDate: Date?,
                         originalAuthor: String? = nil, submittedBy: String? = nil) {
        var parts = [commentCount == 0
                     ? String(localized: "No comments yet.")
                     : String(localized: "Thread has \(commentCount) comments.")]
        if let mostRecentAuthor, let mostRecentDate {
            let when = mostRecentDate.formatted(.relative(presentation: .named))
            parts.append(String(localized: "Most recent comment by \(mostRecentAuthor), \(when)."))
        }
        if let originalAuthor, !originalAuthor.isEmpty {
            parts.append(String(localized: "Original post by \(originalAuthor)."))
        }
        if let submittedBy, !submittedBy.isEmpty {
            parts.append(String(localized: "Submitted by \(submittedBy)."))
        }
        UIAccessibility.post(notification: .announcement, argument: parts.joined(separator: " "))
    }
}
