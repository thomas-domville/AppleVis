import SwiftUI

/// Shown above stale content when the device has no network connection.
struct OfflineBanner: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var hasAnnounced = false

    // Deliberately avoids the word "saved" — this is about locally cached
    // content shown while offline/degraded, unrelated to the user-facing
    // "Saved" (bookmarks) feature, and the overlap was confusing enough
    // that a VoiceOver user asked whether this banner was a bug.
    private var label: String {
        "You're offline. Showing previously loaded content — pull down to refresh once you're back online."
    }

    var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundStyle(preferences.colors.warning)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(preferences.colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                guard !hasAnnounced else { return }
                hasAnnounced = true
                SoundPlayer.shared.play(.offline)
                UIAccessibility.post(notification: .announcement, argument: label)
            }
    }
}
