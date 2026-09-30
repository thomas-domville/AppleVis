import SwiftUI
import UIKit

/// Keeps a text field to a maximum number of characters. Once you're within
/// `warnWithin` of the limit, VoiceOver says how many are left, once, not
/// on every keystroke. Anything past the limit, typed or pasted, is cut off
/// and `onShortened` says so. Requested directly (2026-09-30).
struct InputLimit: ViewModifier {
    @Binding var text: String
    let maximum: Int
    let warnWithin: Int
    let onShortened: () -> Void

    @State private var warned = false

    func body(content: Content) -> some View {
        content.onChange(of: text) { _, newValue in
            if newValue.count > maximum {
                // Set first, so the shortened text doesn't also announce
                // how many are left over the top of the message.
                warned = true
                text = String(newValue.prefix(maximum))
                onShortened()
                return
            }
            if maximum - newValue.count <= warnWithin {
                guard !warned else { return }
                warned = true
                UIAccessibility.post(notification: .announcement, argument: Self.remaining(maximum - newValue.count))
            } else {
                warned = false
            }
        }
    }

    /// The longest AppleVis website search, in characters. Past this,
    /// hardly anything matches every word, and the request gets long.
    static let searchMaximum = 150

    static var searchShortened: String {
        String(localized: "Searches can be up to 150 characters, so yours was shortened.")
    }

    static func remaining(_ count: Int) -> String {
        String(localized: "\(count) characters left")
    }
}

extension View {
    func inputLimit(_ text: Binding<String>, maximum: Int, warnWithin: Int, onShortened: @escaping () -> Void) -> some View {
        modifier(InputLimit(text: text, maximum: maximum, warnWithin: warnWithin, onShortened: onShortened))
    }
}
