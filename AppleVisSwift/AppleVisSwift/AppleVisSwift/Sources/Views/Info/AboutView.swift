import SwiftUI

struct AboutView: View {
    @State private var copiedSupportInfo = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
    private var iosVersion: String {
        UIDevice.current.systemVersion
    }
    private var deviceModel: String {
        UIDevice.current.model
    }

    private var supportInfo: String {
        """
        AppleVis \(appVersion) (\(buildNumber))
        iOS \(iosVersion) · \(deviceModel)
        """
    }

    var body: some View {
        Form {
            Section("App Information") {
                NavigationLink { WhatsNewView() } label: {
                    Label("What's New", systemImage: "sparkles")
                }
                .accessibilityLabel("What's New in AppleVis")
                InfoRow(label: "Version", value: appVersion)
                InfoRow(label: "Build",   value: buildNumber)
                InfoRow(label: "iOS",     value: iosVersion)
                InfoRow(label: "Device",  value: deviceModel)
            }

            Section("Accessibility Status") {
                AccessibilityStatusRow(label: "VoiceOver",          isActive: UIAccessibility.isVoiceOverRunning)
                AccessibilityStatusRow(label: "Switch Control",      isActive: UIAccessibility.isSwitchControlRunning)
                AccessibilityStatusRow(label: "Reduced Motion",      isActive: UIAccessibility.isReduceMotionEnabled)
                AccessibilityStatusRow(label: "Bold Text",           isActive: UIAccessibility.isBoldTextEnabled)
                AccessibilityStatusRow(label: "Reduce Transparency", isActive: UIAccessibility.isReduceTransparencyEnabled)
                AccessibilityStatusRow(label: "Increased Contrast",  isActive: UIAccessibility.isDarkerSystemColorsEnabled)
                AccessibilityStatusRow(label: "Grayscale",           isActive: UIAccessibility.isGrayscaleEnabled)
                AccessibilityStatusRow(label: "Invert Colors",       isActive: UIAccessibility.isInvertColorsEnabled)
            }

            Section("Support") {
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
                .accessibilityHint("Copies version, build, iOS, and device details to the clipboard so you can paste them into a support request.")
            }

            Section("Find Us") {
                Link(destination: URL(string: "https://twitter.com/applevis")!) {
                    Label("@AppleVis on X / Twitter", systemImage: "link")
                }
                .accessibilityLabel("X Twitter, @AppleVis")

                Link(destination: URL(string: "https://www.applevis.com")!) {
                    Label("applevis.com", systemImage: "globe")
                }
                .accessibilityLabel("applevis.com website")
            }

            Section("Legal") {
                NavigationLink { CreditsView() } label: {
                    Label("Credits", systemImage: "person.2")
                }
                NavigationLink { OpenSourceView() } label: {
                    Label("Open Source Licences", systemImage: "doc.text")
                }
                Link(destination: URL(string: "https://www.applevis.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: URL(string: "https://www.applevis.com/terms")!) {
                    Label("Terms of Use", systemImage: "doc.plaintext")
                }
            }
        }
        .navigationTitle("About AppleVis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct AccessibilityStatusRow: View {
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
        .accessibilityLabel("\(label): \(isActive ? "On" : "Off")")
    }
}
