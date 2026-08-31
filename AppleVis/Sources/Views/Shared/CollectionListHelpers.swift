import SwiftUI

/// Re-runs `load` both on first appearance (`.task`) and every subsequent
/// appearance (`.onAppear`) — a `.task` alone only (re-)runs on first
/// appearance or a view-identity change, not when returning to a screen
/// that stayed mounted in the background while something changed elsewhere
/// (e.g. saving/following/recommending something from another screen while
/// this one sat in a conditionally-rendered branch). Previously duplicated
/// as three independently-written copies with the same explanatory comment
/// in SavedItemsView, FollowingView, and RecommendedAppsView (FORYOU-05) —
/// consolidated here so a future fix to this pattern doesn't have to be
/// repeated a fourth time. Requested directly.
extension View {
    func loadOnAppearAndTask(_ load: @escaping () async -> Void) -> some View {
        self
            .task { await load() }
            .onAppear { Task { await load() } }
    }
}

/// Shared summary-header row used at the top of each For You list
/// (Saved/Following/Recommended/Downloads) — a caption-styled heading with
/// a VoiceOver custom action announcing more detail than the visible text
/// shows, optionally paired with a second custom action for a bulk
/// destructive action (Unsave All, Remove All Downloads) so it's reachable
/// from the very first element on screen instead of requiring a swipe past
/// every row to reach a button at the bottom. The visible button, where one
/// exists, deliberately stays at the bottom of its list — this only adds a
/// faster VoiceOver path to the same action, it doesn't relocate it.
/// Requested directly.
struct CollectionSummaryHeader: View {
    let text: String
    let summaryActionName: String
    let onSummaryAction: () -> Void
    var bulkActionName: String? = nil
    var onBulkAction: (() -> Void)? = nil

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityAction(named: Text(summaryActionName)) { onSummaryAction() }
            .modifier(OptionalNamedAccessibilityAction(name: bulkActionName, action: onBulkAction))
    }
}

private struct OptionalNamedAccessibilityAction: ViewModifier {
    let name: String?
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let name, let action {
            content.accessibilityAction(named: Text(name)) { action() }
        } else {
            content
        }
    }
}
