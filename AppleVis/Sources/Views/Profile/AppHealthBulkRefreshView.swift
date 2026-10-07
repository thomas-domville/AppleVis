import SwiftUI
import UIKit

/// Refresh App Details for many flagged entries at once. You choose which
/// details may be refreshed and which entries; each entry then changes only
/// the chosen details that really differ from the App Store, and keeps the
/// rest. One entry might get just its title, the next just its description.
/// Admin only, like the rest of the Health Check, so it's left out of Help
/// and What's New. Requested directly (2026-10-02).
struct AppHealthBulkRefreshView: View {
    /// The flagged entries that can be refreshed (not removed ones).
    let flags: [AppHealthFlag]
    /// An entry was refreshed or already matched, so its flag can go.
    let onResolved: (AppHealthFlag) -> Void

    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore

    /// The list as it was when this opened. Entries leave the Health Check
    /// list as they're refreshed, but the counts here stay put.
    @State private var entries: [AppHealthFlag] = []
    @State private var fields: Set<String> = BulkField.defaultIds
    @State private var selectedIds: Set<String> = []
    @State private var confirming = false
    @State private var isRunning = false
    @State private var stopRequested = false
    @State private var current: AppHealthFlag?
    @State private var done = 0
    @State private var results: [BulkResult] = []
    @State private var fatalMessage: String?
    @AccessibilityFocusState private var focus: Focus?

    private enum Focus: Hashable { case intro, progress, summary }

    var body: some View {
        Form {
            if isRunning {
                progressSection
            } else if !results.isEmpty {
                summarySection
            } else {
                Section {
                    Text("Choose which details may be updated and which entries. Each entry only changes the details you've chosen that differ from the App Store, and keeps everything else.")
                        .accessibilityFocused($focus, equals: .intro)
                }
                fieldsSection
                entriesSection
                Section {
                    Button {
                        confirming = true
                    } label: {
                        Label(String(localized: "Update Entries (\(selectedFlags.count))"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(selectedFlags.isEmpty || fields.isEmpty)
                }
            }
            if !results.isEmpty {
                resultsSection
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Update in Bulk")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isRunning)
        .navigationBarBackButtonHidden(isRunning)
        .confirmationDialog(String(localized: "Update the chosen entries (\(selectedFlags.count))?"), isPresented: $confirming, titleVisibility: .visible) {
            Button(String(localized: "Update Entries (\(selectedFlags.count))")) {
                Task { await run() }
            }
        } message: {
            Text("Only the details you've chosen that differ from the App Store will change on AppleVis.")
        }
        .onAppear {
            guard entries.isEmpty else { return }
            entries = flags
            // Minor title differences are often on purpose, so they start
            // unticked.
            selectedIds = Set(flags.filter { $0.kind.group != .minorTitleDifference }.map(\.id))
        }
        .task { await retryAccessibilityFocus(.intro, into: $focus) }
    }

    private var selectedFlags: [AppHealthFlag] { entries.filter { selectedIds.contains($0.id) } }

    // MARK: Choosing

    private var fieldsSection: some View {
        Section {
            ForEach(BulkField.all) { field in
                Toggle(isOn: Binding(
                    get: { fields.contains(field.id) },
                    set: { if $0 { fields.insert(field.id) } else { fields.remove(field.id) } }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.label)
                        if let note = field.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Details to Update")
        } footer: {
            Text("A detail that already matches the App Store is left as it is.")
        }
    }

    private var entriesSection: some View {
        Section {
            Button(String(localized: "Select All")) { selectedIds = Set(entries.map(\.id)) }
            Button(String(localized: "Select None")) { selectedIds = [] }
            ForEach(entries) { flag in
                Toggle(isOn: Binding(
                    get: { selectedIds.contains(flag.id) },
                    set: { if $0 { selectedIds.insert(flag.id) } else { selectedIds.remove(flag.id) } }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flag.appName)
                        Text(AppEntryHealthCheckView.groupName(flag.kind.group))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "Entries (\(selectedFlags.count) of \(entries.count))"))
        }
    }

    // MARK: Running

    private var progressSection: some View {
        Section {
            HStack {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text(stopRequested
                         ? String(localized: "Stopping after this entry…")
                         : String(localized: "Updating \(min(done + 1, selectedFlags.count)) of \(selectedFlags.count)"))
                    if let current {
                        Text(current.appName)
                            .font(.footnote)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityFocused($focus, equals: .progress)
            .progressTick(on: done)
            Button(role: .destructive) {
                stopRequested = true
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .disabled(stopRequested)
            .accessibilityHint(String(localized: "Stops after the entry being updated now."))
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                if let fatalMessage {
                    Text(fatalMessage)
                        .fontWeight(.semibold)
                }
                Text(summaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($focus, equals: .summary)
        }
    }

    private var summaryText: String {
        let updated = results.filter { if case .updated = $0.outcome { return true }; return false }.count
        let matched = results.filter { if case .alreadyMatched = $0.outcome { return true }; return false }.count
        let failed = results.filter {
            switch $0.outcome {
            case .failed, .notAllowed: return true
            default: return false
            }
        }.count
        var parts = [String(localized: "Updated: \(updated)."), String(localized: "Already matched: \(matched).")]
        if failed > 0 { parts.append(String(localized: "Couldn't update: \(failed).")) }
        let skipped = selectedFlags.count - results.count
        if skipped > 0 { parts.append(String(localized: "Not started: \(skipped).")) }
        return parts.joined(separator: " ")
    }

    private var resultsSection: some View {
        Section("Results") {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.flag.appName)
                    Text(result.outcome.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func run() async {
        guard let user = auth.user else { return }
        let queue = selectedFlags
        results = []
        done = 0
        stopRequested = false
        fatalMessage = nil
        isRunning = true
        await retryAccessibilityFocus(.progress, into: $focus)
        for flag in queue {
            if stopRequested { break }
            current = flag
            let outcome = await Self.refresh(flag, fields: fields, csrfToken: user.csrfToken)
            results.append(BulkResult(flag: flag, outcome: outcome))
            done += 1
            switch outcome {
            case .updated, .alreadyMatched:
                onResolved(flag)
            case .failed:
                break
            case .notAllowed(let message):
                // No point going on: the rest would fail the same way.
                fatalMessage = message
                stopRequested = true
            }
            // Gentle on the site and the App Store.
            try? await Task.sleep(for: .milliseconds(300))
        }
        current = nil
        isRunning = false
        SoundPlayer.shared.play(.success)
        if preferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        await retryAccessibilityFocus(.summary, into: $focus)
    }

    /// One entry: loads it and its App Store listing live, works out which
    /// of the chosen details really differ, and saves only those.
    private static func refresh(_ flag: AppHealthFlag, fields: Set<String>, csrfToken: String) async -> BulkOutcome {
        guard let detail = try? await APIClient.shared.apps.detail(id: flag.appId, platform: .ios, forceRefresh: true) else {
            return .failed(String(localized: "Couldn't load the app entry."))
        }
        guard let storeUrl = detail.appStoreUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !storeUrl.isEmpty,
              case .found(let metadata) = await ItunesAPI.lookupMetadata(appStoreUrl: storeUrl, english: true) else {
            return .failed(String(localized: "Couldn't load the App Store details."))
        }
        let deviceIOS = UIDevice.current.systemVersion
        let diffs = AppInfoFieldDiff.build(detail: detail, metadata: metadata,
                                           testedOnThisDevice: fields.contains(AppInfoFieldDiff.iosTestedID) ? deviceIOS : nil)
        // Chosen, different, and (for the iOS version) not older than
        // what's on file.
        let chosen = diffs.filter { fields.contains($0.id) && $0.changed && $0.startsSelected }
        guard !chosen.isEmpty else { return .alreadyMatched }
        let devices = chosen.first { $0.id == "devices" }?.deviceChoices ?? []
        do {
            try await APIClient.shared.apps.updateAppInformation(
                detail: detail, metadata: metadata, includedFields: Set(chosen.map(\.id)),
                devices: ["iPhone", "iPad", "Mac"].filter(devices.contains),
                testedOnIOS: deviceIOS, csrfToken: csrfToken
            )
            return .updated(chosen.map(\.label))
        } catch APIError.forbidden {
            return .notAllowed(String(localized: "You don't have permission to update app entries."))
        } catch APIError.unauthorized {
            return .notAllowed(String(localized: "Please sign in again to update app entries."))
        } catch {
            return .failed(String(localized: "AppleVis didn't accept the change."))
        }
    }
}

/// A detail that can be refreshed in bulk, with the same ids as Refresh
/// App Details.
private struct BulkField: Identifiable {
    let id: String
    let label: String
    var note: String? = nil

    static var all: [BulkField] {
        [
            BulkField(id: "title", label: String(localized: "Title")),
            BulkField(id: "description", label: String(localized: "Description")),
            BulkField(id: "version", label: String(localized: "Version")),
            BulkField(id: "devices", label: String(localized: "Supported Devices")),
            // Off to start: the App Store's address carries tracking bits,
            // so it nearly always looks different.
            BulkField(id: "link", label: String(localized: "App Store Link")),
            BulkField(id: AppInfoFieldDiff.iosTestedID, label: String(localized: "iOS Version Tested"),
                      note: String(localized: "Sets it to this device's iOS \(UIDevice.current.systemVersion), only where that's newer than the one on file.")),
        ]
    }

    static let defaultIds: Set<String> = ["title", "description", "version", "devices"]
}

private enum BulkOutcome {
    case updated([String])
    case alreadyMatched
    case failed(String)
    case notAllowed(String)

    var description: String {
        switch self {
        case .updated(let labels):
            return String(localized: "Updated: \(ListFormatter.localizedString(byJoining: labels)).")
        case .alreadyMatched:
            return String(localized: "Already matched the App Store. Nothing changed.")
        case .failed(let reason), .notAllowed(let reason):
            return String(localized: "Not updated. \(reason)")
        }
    }
}

private struct BulkResult: Identifiable {
    let id = UUID()
    let flag: AppHealthFlag
    let outcome: BulkOutcome
}
