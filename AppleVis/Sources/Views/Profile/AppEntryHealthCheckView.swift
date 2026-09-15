import SwiftUI

/// Scans the iOS App Directory for entries that have been delisted from the
/// App Store, or whose live title no longer matches what AppleVis has on
/// file — see `AppEntryHealthScanner` for how the scan itself works.
/// Deliberately excluded from Help content, the Welcome Tour, and What's
/// New — see `ModeratorToolsView`'s doc comment; the same rule applies to
/// every item under Profile > Admin. Requested directly.
struct AppEntryHealthCheckView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var scanner = AppEntryHealthScanner()
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Checks every iOS App Directory entry against the live App Store — this can take a little while and isn't something to run casually, so it only starts when you tap Start Scan below, not automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)

                if !scanner.isScanning {
                    Button {
                        Task { await scanner.scan() }
                    } label: {
                        Label("Start Scan", systemImage: "play.circle")
                    }
                }
            }

            if scanner.isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Checking the App Directory against the App Store…")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else if let error = scanner.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Try Again") { Task { await scanner.scan() } }
                }
            } else if scanner.scannedAppCount > 0 {
                Section {
                    HStack {
                        Text("\(scanner.scannedAppCount) apps checked")
                        Spacer()
                        Text("\(scanner.flags.count) flagged")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }

                if scanner.flags.isEmpty {
                    Section {
                        Text("Nothing flagged — every entry matches the App Store.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(scanner.flags) { flag in
                            NavigationLink {
                                AppDetailView(appId: flag.appId, platform: .ios)
                            } label: {
                                AppHealthFlagRow(flag: flag)
                            }
                        }
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("App Directory Health Check")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}

private struct AppHealthFlagRow: View {
    let flag: AppHealthFlag

    private var badge: (color: Color, label: String) {
        switch flag.kind {
        case .removed:
            return (Color(red: 0.725, green: 0.110, blue: 0.110), String(localized: "Removed"))
        case .titleChanged:
            return (Color(red: 0.706, green: 0.325, blue: 0.035), String(localized: "Title Changed"))
        }
    }

    private var detail: String {
        switch flag.kind {
        case .removed:
            return String(localized: "No longer found on the App Store.")
        case .titleChanged(let newTitle):
            return String(localized: "App Store now shows: \(newTitle)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(badge.label)
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(badge.color, in: Capsule())
                Spacer()
            }
            Text(flag.appName)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(1)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(badge.label). \(flag.appName). \(detail)"))
    }
}
