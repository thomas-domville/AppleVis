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
        String(localized: "You're offline. Showing previously loaded content — pull down to refresh once you're back online.")
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

/// Shown inside a compose/wizard screen when there's no network connection —
/// distinct copy from `OfflineBanner`, which talks about stale cached
/// content and pull-to-refresh, neither of which applies while writing a
/// message that hasn't been sent yet.
struct OfflineComposeNotice: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var hasAnnounced = false

    private var label: String {
        String(localized: "You're offline right now, but don't lose your train of thought — keep writing. You'll just need to be back on Wi-Fi or cellular before this can be sent.")
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
