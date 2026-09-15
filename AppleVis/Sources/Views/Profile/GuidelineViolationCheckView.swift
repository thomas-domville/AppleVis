import SwiftUI

/// Scans recently-active forum topics and replies for possible guideline
/// violations — see `GuidelineViolationScanner` for how the scan itself
/// works (forums-only for now, reusing the same cached fetches forum
/// browsing already populates). Deliberately excluded from Help content,
/// the Welcome Tour, and What's New — see `ModeratorToolsView`'s doc
/// comment. Requested directly.
struct GuidelineViolationCheckView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var scanner = GuidelineViolationScanner()
    @State private var range: GuidelineScanRange = .day
    @State private var showLowSeverity = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    /// Medium+High only by default — `GuidelinesChecker` was tuned to be
    /// gentle and advisory for someone's own draft. Run in bulk across
    /// everyone's real, already-posted content, its low-severity rules
    /// (all-caps, excessive punctuation, "me too"-style low-value replies)
    /// would flag a lot of harmless stuff and turn a quick glance into a
    /// wall of noise. Low severity is still there, just tucked behind a
    /// toggle for anyone who wants the fuller picture.
    private var visibleFlags: [GuidelineFlag] {
        showLowSeverity ? scanner.flags : scanner.flags.filter { $0.highestSeverity != .low }
    }

    var body: some View {
        Form {
            Section {
                Text("Scans recent forum topics and replies — Apple-related and not, no Home-style filtering — against AppleVis's posting guidelines. Not a substitute for judgment: a flag means \"worth a look,\" not \"definitely a violation.\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)

                Picker("Time Range", selection: $range) {
                    ForEach(GuidelineScanRange.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint(String(localized: "Choose how far back to scan."))
            }

            if scanner.isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning recent forum activity…")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else if let error = scanner.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Try Again") { Task { await scanner.scan(range: range) } }
                }
            } else {
                Section {
                    HStack {
                        Text("\(scanner.scannedTopicCount) topics scanned")
                        Spacer()
                        Text("\(visibleFlags.count) flagged")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)

                    if scanner.flags.contains(where: { $0.highestSeverity == .low }) {
                        Toggle("Show Low-Severity Items", isOn: $showLowSeverity)
                    }
                }

                if visibleFlags.isEmpty {
                    Section {
                        Text("No flagged content in this range.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(visibleFlags) { flag in
                            NavigationLink {
                                ForumTopicDetailView(topicId: flag.topicId)
                            } label: {
                                GuidelineFlagRow(flag: flag)
                            }
                        }
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Guideline Violation Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await scanner.scan(range: range) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(scanner.isScanning)
                .accessibilityLabel(String(localized: "Rescan"))
            }
        }
        .onChange(of: range) { _, newRange in
            Task { await scanner.scan(range: newRange) }
        }
        .task {
            await retryAccessibilityFocus(into: $isTitleFocused)
            await scanner.scan(range: range)
        }
    }
}

private struct GuidelineFlagRow: View {
    let flag: GuidelineFlag

    private var severityConfig: (color: Color, label: String) {
        switch flag.highestSeverity {
        case .high:   return (Color(red: 0.725, green: 0.110, blue: 0.110), String(localized: "High"))
        case .medium: return (Color(red: 0.706, green: 0.325, blue: 0.035), String(localized: "Medium"))
        case .low:    return (Color(red: 0.020, green: 0.412, blue: 0.631), String(localized: "Low"))
        }
    }

    private var ruleNames: String {
        flag.warnings.map(\.rule).joined(separator: ", ")
    }

    private var kindLabel: String {
        flag.isTopicItself ? String(localized: "Topic") : String(localized: "Reply")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(severityConfig.label)
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(severityConfig.color, in: Capsule())
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                RelativeDateLabel(date: flag.createdAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(flag.topicTitle)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(1)

            Text("\(flag.authorName) — \(ruleNames)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(flag.excerpt)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(severityConfig.label) severity. \(kindLabel) by \(flag.authorName), in \(flag.topicTitle). \(ruleNames). \(flag.excerpt)"))
    }
}
