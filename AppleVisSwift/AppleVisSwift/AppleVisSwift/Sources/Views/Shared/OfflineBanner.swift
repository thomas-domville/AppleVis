import SwiftUI

/// Shown above stale content when the device has no network connection.
struct OfflineBanner: View {
    @State private var hasAnnounced = false

    private var label: String {
        "Showing saved content. Pull down to refresh when online."
    }

    var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundStyle(Color(red: 0.522, green: 0.267, blue: 0.016))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.0, green: 0.973, blue: 0.882), in: RoundedRectangle(cornerRadius: 10))
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
