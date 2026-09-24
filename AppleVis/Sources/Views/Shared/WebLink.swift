import SwiftUI

/// Drop-in replacement for `Link(destination:label:)` that respects
/// `PreferencesStore.webBrowsingMode` instead of always launching the
/// external browser the way a bare `Link` unconditionally does. Same
/// call shape as `Link` so it's a near-mechanical swap at each call site.
/// Requested directly: keep users in the app by default, but offer a way
/// out for anyone who wants their regular browser's bookmarks, extensions,
/// signed-in sessions, or Reader mode.
///
/// Also says up front that it leaves the app's own screens — a small
/// arrow after the label (`ExternalLinkIndicator`) and a VoiceOver hint
/// matching the Web Links setting. Before this, "Sign up for free" or
/// "Reset Password" gave no warning at all, and landing on a web page
/// unexpectedly is especially disorienting with VoiceOver. Suggested by a
/// beta tester.
struct WebLink<LinkLabel: View>: View {
    let destination: URL
    /// Anything the call site wants said first ("Opens the complete
    /// AppleVis Community Guidelines."), followed by where it opens. A
    /// separate `.accessibilityHint` at the call site would replace the
    /// browser part instead of adding to it.
    var hint: String? = nil
    /// Off where the label already shows an arrow, or is an icon-only
    /// button or a large card, where a second glyph would just be noise —
    /// the VoiceOver hint still applies either way.
    var showsExternalIcon: Bool = true
    @ViewBuilder let label: () -> LinkLabel

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showInAppBrowser = false

    private var browserHint: String {
        switch preferences.webBrowsingMode {
        case .inApp:    return String(localized: "Opens a web page in the app's browser.")
        case .external: return String(localized: "Opens in your web browser, outside the app.")
        }
    }

    var body: some View {
        Button {
            switch preferences.webBrowsingMode {
            case .inApp:    showInAppBrowser = true
            case .external: UIApplication.shared.open(destination)
            }
        } label: {
            if showsExternalIcon {
                HStack(spacing: 4) {
                    label()
                    ExternalLinkIndicator()
                }
            } else {
                label()
            }
        }
        // Matches Link's own accessibility trait so VoiceOver still calls
        // these "link"s, not "button"s, now that they're Button-backed.
        .accessibilityAddTraits(.isLink)
        .accessibilityHint(hint.map { "\($0) \(browserHint)" } ?? browserHint)
        .sheet(isPresented: $showInAppBrowser) {
            SafariView(url: destination)
        }
    }
}

/// The small arrow that marks something as leaving the app's own screens —
/// the same `arrow.up.forward` glyph iOS Settings uses for its own
/// external links. Decorative only: whatever it's attached to carries the
/// real explanation in its VoiceOver hint.
struct ExternalLinkIndicator: View {
    var body: some View {
        Image(systemName: "arrow.up.forward")
            .font(.caption.weight(.semibold))
            .imageScale(.small)
            .accessibilityHidden(true)
    }
}
