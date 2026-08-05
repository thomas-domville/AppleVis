import SwiftUI

/// Shared comments/reviews-section heading used across all content-detail
/// screens (forum topics, apps, podcast episodes, blog posts, resources).
/// Includes a VoiceOver "Thread overview" custom action giving a spoken
/// summary in place of manually reading through every comment.
struct CommunityDiscussionHeading: View {
    let count: Int
    let onThreadOverview: () -> Void

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
    }
}
