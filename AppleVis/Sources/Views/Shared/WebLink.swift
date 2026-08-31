import SwiftUI

/// Drop-in replacement for `Link(destination:label:)` that respects
/// `PreferencesStore.webBrowsingMode` instead of always launching the
/// external browser the way a bare `Link` unconditionally does. Same
/// call shape as `Link` so it's a near-mechanical swap at each call site.
/// Requested directly: keep users in the app by default, but offer a way
/// out for anyone who wants their regular browser's bookmarks, extensions,
/// signed-in sessions, or Reader mode.
struct WebLink<LinkLabel: View>: View {
    let destination: URL
    @ViewBuilder let label: () -> LinkLabel

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showInAppBrowser = false

    var body: some View {
        Button {
            switch preferences.webBrowsingMode {
            case .inApp:    showInAppBrowser = true
            case .external: UIApplication.shared.open(destination)
            }
        } label: {
            label()
        }
        // Matches Link's own accessibility trait so VoiceOver still calls
        // these "link"s, not "button"s, now that they're Button-backed.
        .accessibilityAddTraits(.isLink)
        .sheet(isPresented: $showInAppBrowser) {
            SafariView(url: destination)
        }
    }
}
