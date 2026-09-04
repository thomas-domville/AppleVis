import SwiftUI

struct OpenSourceView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    /// Had no focus management at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isIntroFocused: Bool

    // This app has no third-party Swift Package Manager dependencies — every
    // import (Foundation, SwiftUI, AVFoundation, MediaPlayer, Combine,
    // Security, UserNotifications) is a first-party Apple framework, so
    // there's genuinely nothing else to disclose here.
    private let licences: [OpenSourceLicence] = [
        OpenSourceLicence(
            name: "Swift",
            url: "https://github.com/apple/swift",
            licence: "Apache License 2.0",
            copyright: "Copyright © 2014 Apple Inc. and the Swift project authors."
        ),
    ]

    var body: some View {
        Form {
            Section {
                Text("AppleVis is built entirely on Apple's native frameworks — SwiftUI, AVFoundation, Combine, and the rest of the system SDK. It has no third-party Swift package dependencies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isIntroFocused)
            }

            Section("Licences") {
                ForEach(licences) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(item.licence)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .themedPill(preferences.colors)
                        }
                        Text(item.copyright)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let url = URL(string: item.url) {
                            WebLink(destination: url) {
                                Text("View on GitHub")
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                Text("AppleVis itself is not open source. All app code is copyright AppleVis and its contributors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Open Source Licences")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isIntroFocused) }
    }
}

private struct OpenSourceLicence: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let licence: String
    let copyright: String
}
