import SwiftUI

/// Admin/editor-only hub for moderator-facing tools — currently just the
/// Guideline Violation Check, with room to add more over time without
/// reorganizing anything. Deliberately excluded from Help content, the
/// Welcome Tour, and What's New: this is internal team tooling, not a
/// user-facing feature, and gating on `auth.user?.isAdmin` already means
/// almost nobody would ever see a mention of it anyway. Requested directly.
struct ModeratorToolsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Tools for reviewing recent activity against AppleVis's posting guidelines.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }
            Section {
                NavigationLink {
                    GuidelineViolationCheckView()
                } label: {
                    Label("Guideline Violation Check", systemImage: "text.magnifyingglass")
                }
                .accessibilityHint(String(localized: "Scans recent activity across the site for possible guideline violations."))
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Moderator Tools")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
