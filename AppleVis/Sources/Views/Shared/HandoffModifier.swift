import SwiftUI

/// Handoff support — continues browsing on another of the user's devices via
/// Safari (the app has no macOS/iPadOS-distinct target to hand off into
/// directly, so `webpageURL` is the practical continuation point).
private struct HandoffModifier: ViewModifier {
    let title: String?
    let url: String?

    func body(content: Content) -> some View {
        content.userActivity("com.applevis.viewing") { activity in
            guard let title, let url, let webURL = URL(string: url) else { return }
            activity.title = title
            activity.webpageURL = webURL
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = false
        }
    }
}

extension View {
    /// Enables Handoff to Safari for the content currently on screen.
    /// Pass `nil` while content is still loading.
    func handoff(title: String?, url: String?) -> some View {
        modifier(HandoffModifier(title: title, url: url))
    }
}
