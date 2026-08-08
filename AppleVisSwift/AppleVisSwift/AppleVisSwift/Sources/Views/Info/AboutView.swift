import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @State private var copiedSupportInfo = false
    @State private var contactType: ContactView.ContactType?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    private var deviceMachineModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
    private var screenSize: String {
        guard let bounds = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.screen.bounds })
            .first
        else { return "—" }
        return "\(Int(bounds.width)) x \(Int(bounds.height)) pts"
    }
    private var dynamicTypeScale: String {
        let scale = UIFont.preferredFont(forTextStyle: .body).pointSize / 17.0
        let suffix = dynamicTypeSize.isAccessibilitySize ? " (Accessibility size)" : ""
        return String(format: "%.2fx%@", scale, suffix)
    }

    /// Matches RN's fuller diagnostic report (app version/build, iOS
    /// version/device, every accessibility setting, theme, locale, network
    /// state) — Swift's previously only included version/build/iOS/device,
    /// missing everything that actually helps diagnose an accessibility
    /// bug report.
    /// Matches RN's `buildSupportInfo()` structure exactly (labeled header,
    /// dashed rule, blank-line-separated sections, trailing instruction) —
    /// not just the same facts in a denser one-line format.
    private var supportInfo: String {
        """
        AppleVis App Support Information
        --------------------------------
        App Version:       \(appVersion) (Build \(buildNumber))
        iOS Version:       \(iosVersion)
        Device:            \(deviceModel) (\(deviceMachineModel))
        Device Type:       \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")
        Screen:            \(screenSize)
        Theme:             \(preferences.theme.displayName)
        Locale:            \(Locale.current.identifier)
        Network:           \(networkMonitor.isConnected ? "Connected" : "Not Connected")

        Accessibility Settings
        VoiceOver:         \(UIAccessibility.isVoiceOverRunning ? "On" : "Off")
        Switch Control:    \(UIAccessibility.isSwitchControlRunning ? "On" : "Off")
        Reduce Motion:     \(UIAccessibility.isReduceMotionEnabled ? "On" : "Off")
        Bold Text:         \(UIAccessibility.isBoldTextEnabled ? "On" : "Off")
        Reduce Transparency: \(UIAccessibility.isReduceTransparencyEnabled ? "On" : "Off")
        Increased Contrast: \(UIAccessibility.isDarkerSystemColorsEnabled ? "On" : "Off")
        Grayscale:         \(UIAccessibility.isGrayscaleEnabled ? "On" : "Off")
        Invert Colors:     \(UIAccessibility.isInvertColorsEnabled ? "On" : "Off")
        Dynamic Type Scale: \(dynamicTypeScale)

        Please include this information when reporting a bug.
        """
    }

    var body: some View {
        Form {
            Section("App Information") {
                NavigationLink { WhatsNewView() } label: {
                    Label("What's New", systemImage: "sparkles")
                }
                .accessibilityLabel(String(localized: "What's New in AppleVis"))
                InfoRow(label: "Version", value: appVersion)
                InfoRow(label: "Build",   value: buildNumber)
                InfoRow(label: "iOS",     value: iosVersion)
                InfoRow(label: "Device",  value: deviceModel)
                InfoRow(label: "Model",   value: deviceMachineModel)
                InfoRow(label: "Type",    value: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")
                InfoRow(label: "Screen",  value: screenSize)
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
                InfoRow(label: "Dynamic Type Scale", value: dynamicTypeScale)
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
                .accessibilityHint(String(localized: "Copies version, build, iOS, device, theme, and accessibility settings to the clipboard so you can paste them into a support request."))
                .accessibilityAction(named: Text("Read Support Summary")) {
                    UIAccessibility.post(notification: .announcement, argument: supportInfo.replacingOccurrences(of: "\n", with: ". "))
                }
            }

            Section("Connect With Us") {
                Link(destination: URL(string: "https://x.com/AppleVis")!) {
                    Label("Follow AppleVis on X", systemImage: "at")
                }
                .accessibilityLabel(String(localized: "Follow AppleVis on X"))
                .accessibilityHint(String(localized: "Opens in Safari."))

                Link(destination: URL(string: "https://www.facebook.com/AppleVis")!) {
                    Label("Follow AppleVis on Facebook", systemImage: "f.circle")
                }
                .accessibilityLabel(String(localized: "Follow AppleVis on Facebook"))
                .accessibilityHint(String(localized: "Opens in Safari."))

                Link(destination: URL(string: "https://mastodon.online/@AppleVis")!) {
                    Label("Follow AppleVis on Mastodon", systemImage: "network")
                }
                .accessibilityLabel(String(localized: "Follow AppleVis on Mastodon"))
                .accessibilityHint(String(localized: "Opens in Safari."))

                Link(destination: URL(string: "https://www.applevis.com")!) {
                    Label("applevis.com", systemImage: "globe")
                }
                .accessibilityLabel(String(localized: "applevis.com website"))
            }

            Section("Legal & Credits") {
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
                Button {
                    contactType = .bug
                } label: {
                    Label("Report a Bug", systemImage: "ladybug")
                }
                .accessibilityHint(String(localized: "Opens the in-app contact form."))
                Button {
                    contactType = .feedback
                } label: {
                    Label("Send Feedback", systemImage: "ellipsis.bubble")
                }
                .accessibilityHint(String(localized: "Opens the in-app contact form."))
            }

            Section {
                Text("© 2026 AppleVis\napplevis.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(String(localized: "Copyright 2026 AppleVis. All rights reserved."))
            }
            .listRowBackground(Color.clear)
        }
        .themedList(preferences.colors)
        .navigationTitle("About AppleVis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $contactType) { type in
            ContactView(initialType: type)
        }
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
