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
            .accessibilityLabel(String(localized: "Community Discussion, \(count) comment\(count == 1 ? "" : "s")"))
            .accessibilityAction(named: Text("Thread overview"), onThreadOverview)

            if count > 0 {
                Text("\(count) comment\(count == 1 ? "" : "s")")
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

    /// Backs each detail screen's "Replies to Me" rotor. Nothing in the
    /// Drupal comment data links a reply back to the specific comment or
    /// author it's responding to — no parent id, no mentions field — so
    /// this is the only signal available: does `body` open with exactly the
    /// quote format `prefix(authorName:body:)` produces when someone taps
    /// "Reply to this Comment" on one of `authorName`'s own comments. That
    /// means this only catches explicit quote-replies, not a free-text
    /// "@username" mention typed into an ordinary comment — there's no
    /// distinct, detectable feature for that here at all.
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
