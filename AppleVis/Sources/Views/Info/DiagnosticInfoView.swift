import SwiftUI

/// Device details, accessibility status, and Copy Support Info — previously
/// spilled directly into About as seven-plus flat rows before anyone had
/// asked for them, on top of its own "Accessibility Status" section. Both
/// only really matter when reporting a bug or contacting support, so they
/// live behind one button now, matching the same one-button-to-a-dedicated-
/// screen pattern About already uses for Social Media and Credits.
/// Requested directly.
struct DiagnosticInfoView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isIntroFocused: Bool
    @State private var copiedSupportInfo = false

    private var supportInfo: String {
        DiagnosticInfo.report(
            themeDisplayName: preferences.theme.displayName,
            isConnected: networkMonitor.isConnected,
            dynamicTypeSize: dynamicTypeSize,
            isSignedIn: auth.isSignedIn,
            isEditor: auth.user?.isAdmin ?? false
        )
    }

    /// Combines what used to be three separate rows ("Device," "Model,"
    /// "Type") into one — `DiagnosticInfo.deviceModel` and `.deviceTypeName`
    /// both just return "iPhone" or "iPad" via the same underlying check, so
    /// "Type" was pure redundancy with "Device." The raw hardware
    /// identifier (e.g. "iPhone17,1") is real diagnostic value, worth
    /// keeping for bug triage, but reads as an unexplained, confusing
    /// number floating on its own — it doesn't correspond 1:1 with Apple's
    /// marketing generation numbers (an "iPhone17,1" really is a 16 Pro),
    /// and there's no API to translate it to a marketing name without a
    /// manually-maintained lookup table that goes stale with every new
    /// device. Attaching it as a parenthetical to "Device" keeps the value
    /// without presenting it as a standalone mystery. Requested directly.
    private var deviceSummary: String {
        "\(DiagnosticInfo.deviceModel) (\(DiagnosticInfo.deviceMachineModel))"
    }

    var body: some View {
        Form {
            Section {
                Text("Details about your device and accessibility settings — handy if you're reporting a bug or contacting support. None of this is sent anywhere unless you choose to copy and share it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isIntroFocused)
            }

            Section("Device") {
                InfoRow(label: "Version", value: DiagnosticInfo.appVersion)
                InfoRow(label: "Build", value: DiagnosticInfo.buildNumber)
                InfoRow(label: "Device", value: deviceSummary)
                InfoRow(label: "iOS", value: DiagnosticInfo.iosVersion)
                InfoRow(label: "Screen", value: DiagnosticInfo.screenSize)
            }

            Section("Accessibility Status") {
                AccessibilityStatusRow(label: "VoiceOver", isActive: UIAccessibility.isVoiceOverRunning)
                AccessibilityStatusRow(label: "Switch Control", isActive: UIAccessibility.isSwitchControlRunning)
                AccessibilityStatusRow(label: "Reduced Motion", isActive: UIAccessibility.isReduceMotionEnabled)
                AccessibilityStatusRow(label: "Bold Text", isActive: UIAccessibility.isBoldTextEnabled)
                AccessibilityStatusRow(label: "Reduce Transparency", isActive: UIAccessibility.isReduceTransparencyEnabled)
                AccessibilityStatusRow(label: "Increased Contrast", isActive: UIAccessibility.isDarkerSystemColorsEnabled)
                AccessibilityStatusRow(label: "Grayscale", isActive: UIAccessibility.isGrayscaleEnabled)
                AccessibilityStatusRow(label: "Invert Colors", isActive: UIAccessibility.isInvertColorsEnabled)
                InfoRow(label: "Dynamic Type Scale", value: DiagnosticInfo.dynamicTypeScale(dynamicTypeSize))
            }

            Section {
                Button {
                    UIPasteboard.general.string = supportInfo
                    copiedSupportInfo = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copiedSupportInfo = false
                    }
                } label: {
                    Label(
                        copiedSupportInfo ? "Copied!" : "Copy Support Info",
                        systemImage: copiedSupportInfo ? "checkmark" : "doc.on.clipboard"
                    )
                }
                .accessibilityHint(String(localized: "Copies version, build, iOS, device, theme, and accessibility settings to the clipboard so you can paste them into a support request."))
                .accessibilityAction(named: Text("Read Support Summary")) {
                    UIAccessibility.post(notification: .announcement, argument: supportInfo.replacingOccurrences(of: "\n", with: ". "))
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Diagnostic Info")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isIntroFocused) }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(label): \(value)"))
    }
}

struct AccessibilityStatusRow: View {
    let label: String
    let isActive: Bool
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(isActive ? "On" : "Off")
                .foregroundStyle(isActive ? .green : .secondary)
                .fontWeight(isActive ? .semibold : .regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(label): \(isActive ? "On" : "Off")"))
    }
}
