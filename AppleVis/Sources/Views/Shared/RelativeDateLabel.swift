import SwiftUI

struct RelativeDateLabel: View {
    let date: Date

    var body: some View {
        Text(date, format: .relative(presentation: .named))
            .foregroundStyle(.secondary)
            .font(.caption)
    }
}

struct ActivityCountLabel: View {
    let count: Int
    /// Only ever "comment" at every call site. Kept for source
    /// compatibility; the text itself now comes from `commentCountPhrase`,
    /// which is translated with real plural forms — this used to append an
    /// English "s" to an untranslated noun on every card.
    let noun: String

    var body: some View {
        Text(commentCountPhrase(count))
            .foregroundStyle(.secondary)
            .font(.caption)
    }
}

extension View {
    /// Purely decorative — every place this is used also states "new"/
    /// "unread" in words elsewhere (the row's own accessibility label), so
    /// this dot would otherwise reach VoiceOver as an unlabeled element.
    func unreadIndicator(_ isUnread: Bool) -> some View {
        overlay(alignment: .topLeading) {
            if isUnread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .offset(x: -4, y: -4)
                    .accessibilityHidden(true)
            }
        }
    }
}
