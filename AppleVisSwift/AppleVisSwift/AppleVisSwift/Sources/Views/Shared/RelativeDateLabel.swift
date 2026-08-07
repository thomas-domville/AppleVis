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
    let noun: String

    var body: some View {
        Text("\(count) \(noun)\(count == 1 ? "" : "s")")
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
