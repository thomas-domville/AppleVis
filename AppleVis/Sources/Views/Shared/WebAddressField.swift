import SwiftUI

/// Whether typed text could be a web address. Empty counts as fine, since
/// every field using this is optional. "https://" is added when sending
/// (see AppEndpoints' LinkValue), so www.sky.com and sky.com both pass.
/// Catches what the website would refuse after the whole form was filled
/// in: no dot, a space, an email address. A beta tester's submission was
/// refused over a web address (2026-10-08).
enum WebAddress {
    nonisolated static func isPlausible(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        guard !text.contains(where: \.isWhitespace) else { return false }
        let full: String = text.contains("://") ? text : "https://" + String(text.drop(while: { $0 == "/" }))
        guard let components = URLComponents(string: full),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              // An email address reads as a user name plus a site.
              components.user == nil, components.password == nil,
              let host = components.host, !host.contains("@") else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, !labels.contains(where: \.isEmpty),
              let last = labels.last, last.count >= 2, last.allSatisfy(\.isLetter) else { return false }
        return host.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
    }
}

/// An optional web address field that says, as you leave it, when what's
/// typed doesn't look like a web address. The same line stays under the
/// field until it's fixed or cleared.
struct WebAddressField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let hint: String

    @FocusState private var isFocused: Bool
    @State private var hasLeft = false

    static var problem: String {
        String(localized: "That doesn't look like a web address. Try something like www.example.com, or leave it blank.")
    }

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)
            .accessibilityHint(hint)
            .onChange(of: isFocused) { _, focused in
                guard !focused else { return }
                hasLeft = true
                if !WebAddress.isPlausible(text) {
                    UIAccessibility.post(notification: .announcement, argument: Self.problem)
                }
            }
        if hasLeft, !WebAddress.isPlausible(text) {
            Label(Self.problem, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }
}
