import SwiftUI

/// Persistent translated-content indicator + toggle for a `SegmentedHTMLView`
/// instance — deliberately no dismiss/close button, unlike the compose-side
/// `TranslatePromptView` this echoes the visual language of for consistency.
/// This one stays for the life of the screen, matching Safari's own
/// translate banner: a reader should always be able to tell they're looking
/// at a machine translation and get back to the original with one tap, not
/// just once when the screen first loads.
struct TranslationBanner: View {
    @Binding var showOriginal: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Translated from English · may not be exact")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(showOriginal ? "Show Translation" : "Show Original") {
                showOriginal.toggle()
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
