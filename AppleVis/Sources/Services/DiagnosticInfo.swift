import SwiftUI
import UIKit

/// The full diagnostic block appended to a bug report and copied from
/// About > Support — app version/build, device, accessibility settings,
/// theme, locale, and network status. Previously lived only inside
/// `AboutView`; Contact Us's own "Include app and device info" bug-report
/// toggle duplicated just two lines of it (app version and iOS version),
/// so a report through Contact Us carried far less diagnostic value than
/// the same information copied from About — and the toggle's own label
/// promised "device info" it never actually sent. Extracted here so both
/// places stay byte-for-byte identical and any future addition only needs
/// to happen once. Requested directly.
enum DiagnosticInfo {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    static var iosVersion: String {
        UIDevice.current.systemVersion
    }

    static var deviceModel: String {
        UIDevice.current.model
    }

    /// The raw hardware identifier (e.g. "iPhone15,2") — `UIDevice.model`
    /// alone only ever reports the generic "iPhone"/"iPad".
    static var deviceMachineModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    static var screenSize: String {
        guard let bounds = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.screen.bounds })
            .first
        else { return "—" }
        return "\(Int(bounds.width)) x \(Int(bounds.height)) pts"
    }

    static func dynamicTypeScale(_ dynamicTypeSize: DynamicTypeSize) -> String {
        let scale = UIFont.preferredFont(forTextStyle: .body).pointSize / 17.0
        let suffix = dynamicTypeSize.isAccessibilitySize ? " (Accessibility size)" : ""
        return String(format: "%.2fx%@", scale, suffix)
    }

    /// Coarse account status only — never email, username, or UID here.
    /// Knowing whether the reporter was signed in (and, if so, whether they
    /// hold an editorial role) narrows down bugs that are gated on auth or
    /// on Editor-only UI without needing a follow-up email. Requested
    /// directly.
    static func accountStatus(isSignedIn: Bool, isEditor: Bool) -> String {
        guard isSignedIn else { return "Signed Out" }
        return isEditor ? "Signed In (Editor)" : "Signed In (Member)"
    }

    /// Matches RN's fuller diagnostic report (app version/build, iOS
    /// version/device, every accessibility setting, theme, locale, network
    /// state) and its exact structure (labeled header, dashed rule,
    /// blank-line-separated sections, trailing instruction) — not just the
    /// same facts in a denser one-line format.
    static func report(themeDisplayName: String, isConnected: Bool, dynamicTypeSize: DynamicTypeSize, isSignedIn: Bool, isEditor: Bool) -> String {
        """
        AppleVis App Support Information
        --------------------------------
        App Version:       \(appVersion) (Build \(buildNumber))
        iOS Version:       \(iosVersion)
        Device:            \(deviceModel) (\(deviceMachineModel))
        Screen:            \(screenSize)
        Theme:             \(themeDisplayName)
        Locale:            \(Locale.current.identifier)
        Network:           \(isConnected ? "Connected" : "Not Connected")
        Account:           \(accountStatus(isSignedIn: isSignedIn, isEditor: isEditor))
        Apple Intelligence: \(IntelligenceService.diagnosticStatus)

        Accessibility Settings
        VoiceOver:         \(UIAccessibility.isVoiceOverRunning ? "On" : "Off")
        Switch Control:    \(UIAccessibility.isSwitchControlRunning ? "On" : "Off")
        Reduce Motion:     \(UIAccessibility.isReduceMotionEnabled ? "On" : "Off")
        Bold Text:         \(UIAccessibility.isBoldTextEnabled ? "On" : "Off")
        Reduce Transparency: \(UIAccessibility.isReduceTransparencyEnabled ? "On" : "Off")
        Increased Contrast: \(UIAccessibility.isDarkerSystemColorsEnabled ? "On" : "Off")
        Grayscale:         \(UIAccessibility.isGrayscaleEnabled ? "On" : "Off")
        Invert Colors:     \(UIAccessibility.isInvertColorsEnabled ? "On" : "Off")
        Dynamic Type Scale: \(dynamicTypeScale(dynamicTypeSize))

        Please include this information when reporting a bug.
        """
    }
}

// MARK: - Posting problems

/// The short note behind Copy Details for AppleVis, and the Contact form's
/// option to include it. Kept here with the support report because it's
/// written for the AppleVis team, in English, whatever the app's language.
extension DiagnosticInfo {
    nonisolated static func postingProblem(for request: URLRequest, error: Error) -> PostingProblem {
        var status: Int?
        var said: [String] = []
        let kind: String
        switch error as? APIError {
        case .refused(let refusal)?:
            status = refusal.statusCode
            said = refusal.problems.map(\.detail)
            kind = refusal.fromFirewall ? "refused by firewall" : "refused"
        case .server(let code)?: status = code; kind = "server error"
        case .unknown(let code)?: status = code; kind = "unexpected"
        case .forbidden?: status = 403; kind = "forbidden"
        case .unauthorized?: status = 401; kind = "signed out"
        case .notFound?: status = 404; kind = "not found"
        case .rateLimited?: status = 429; kind = "rate limited"
        case .timeout?: kind = "timed out"
        case .network?: kind = "network"
        case .decoding?: kind = "unreadable reply"
        default: kind = String(describing: type(of: error))
        }
        return PostingProblem(
            date: Date(),
            method: request.httpMethod ?? "GET",
            path: request.url?.path ?? "",
            statusCode: status,
            errorKind: kind,
            siteSaid: said
        )
    }

    static func postingProblemReport(_ problem: PostingProblem) -> String {
        let when = problem.date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        var lines = [
            "AppleVis App Posting Problem",
            "----------------------------",
            "When:         \(when) UTC (\(TimeZone.current.identifier))",
            "App Version:  \(DiagnosticInfo.appVersion) (Build \(DiagnosticInfo.buildNumber))",
            "iOS Version:  \(DiagnosticInfo.iosVersion)",
            "Language:     \(Locale.current.identifier)",
            "Request:      \(problem.method) \(problem.path)",
            "Response:     \(problem.statusCode.map { "HTTP \($0)" } ?? "none") (\(problem.errorKind))",
        ]
        if problem.siteSaid.isEmpty {
            lines.append("Site said:    (no reason given)")
        } else {
            lines += problem.siteSaid.map { "Site said:    \($0)" }
        }
        return lines.joined(separator: "\n")
    }
}
