import SwiftUI
import UIKit

/// Wraps a computed `[AppInfoFieldDiff]` as a single Identifiable value so
/// AppDetailView can drive its sheet with `.sheet(item:)` instead of
/// `.sheet(isPresented:)` plus a separate sibling `@State` array — the
/// latter is a known SwiftUI race where the sheet's content closure can
/// capture the sibling state's *previous* value instead of what was just
/// assigned in the same action, since presentation and data aren't tied
/// to the same value. Reported directly: Refresh App Details consistently
/// showed nothing at all — not even "Already Matches" rows — because the
/// sheet kept seeing the still-empty initial array.
struct AppInfoRefreshRequest: Identifiable {
    let id = UUID()
    let diffs: [AppInfoFieldDiff]
}

/// One store-owned field `updateAppInformationFromStore()` can refresh from
/// the App Store listing, alongside what AppleVis currently has on file for
/// it. `oldValue`/`newValue` are always plain text (HTML stripped for
/// `description`) purely for comparison and display — the actual PATCH in
/// `AppEndpoints.updateAppInformation` re-reads the raw `ItunesMetadata`
/// fields itself rather than round-tripping through this struct.
struct AppInfoFieldDiff: Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let oldValue: String
    let newValue: String
    /// Devices only: what the entry has now, and what the App Store
    /// suggests (each individually untickable in the sheet). Compared as
    /// sets, so order never counts as a change.
    var currentDevices: [String] = []
    var deviceChoices: [String] = []
    /// Whether the sheet starts with this change switched on.
    var startsSelected = true
    /// A short line under the row, such as a warning.
    var note: String?

    static let iosTestedID = "iosTested"

    /// Compares what the text actually says, not how it's laid out. The
    /// AppleVis side arrives as Drupal's rendered HTML flattened to one
    /// line, the App Store side as plain text full of line breaks — so a
    /// plain string compare flagged the description as different even
    /// right after an editor had copied it over word for word (confirmed
    /// live, 2026-09-23: No Wifi Mini Games' stored description matched
    /// the App Store exactly and still showed as changed). Reported
    /// directly.
    var changed: Bool {
        if id == "devices" { return Set(currentDevices) != Set(deviceChoices) }
        if id == Self.iosTestedID { return !Self.sameVersion(oldValue, newValue) }
        return Self.comparable(oldValue) != Self.comparable(newValue)
    }

    /// Tags stripped, entities decoded, invisible characters dropped, every
    /// run of whitespace (line breaks included) collapsed to one space.
    static func comparable(_ text: String) -> String {
        HTMLText.comparableText(text)
    }

    /// Price is deliberately left out — the App Store lookup only ever
    /// reports a plain free/paid boolean, not AppleVis's finer categories
    /// ("Free with In-App Purchases", "Requires Subscription", etc.), and
    /// there's no permitted way to get that distinction automatically (see
    /// the price brainstorm this replaces). Discussed directly; out of
    /// scope until there's a real way to resolve it.
    /// "26.2" as numbers, or nil for anything else ("27 beta 8", "27..0").
    static func versionParts(_ text: String) -> [Int]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !trimmed.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        return parts.compactMap { Int($0) }
    }

    /// "27" and "27.0" are the same version; anything unreadable differs.
    static func sameVersion(_ a: String, _ b: String) -> Bool {
        guard let x = versionParts(a), let y = versionParts(b) else { return false }
        let count = max(x.count, y.count)
        return (x + Array(repeating: 0, count: count - x.count)) == (y + Array(repeating: 0, count: count - y.count))
    }

    static func isOlder(_ a: String, than b: String) -> Bool {
        guard let x = versionParts(a), let y = versionParts(b) else { return false }
        for index in 0..<max(x.count, y.count) {
            let left = index < x.count ? x[index] : 0, right = index < y.count ? y[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    /// `testedOnThisDevice`: also offer to set the entry's "iOS Version"
    /// (the iOS it was tested on) to this device's iOS. Only Refresh App
    /// Details on an entry's page asks for it; the admin Health Check
    /// doesn't, or every entry tested on another iOS would look outdated.
    /// Requested directly (2026-09-28).
    static func build(detail: AppDetail, metadata: ItunesMetadata, testedOnThisDevice: String? = nil) -> [AppInfoFieldDiff] {
        var diffs: [AppInfoFieldDiff] = []

        let newTitle = metadata.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        diffs.append(AppInfoFieldDiff(
            id: "title", label: String(localized: "Title"), systemImage: "textformat",
            oldValue: detail.name, newValue: newTitle.isEmpty ? detail.name : newTitle
        ))

        let oldDescription = HTMLText.plainText(fromHTML: detail.body)
        let newDescription = metadata.appStoreDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        diffs.append(AppInfoFieldDiff(
            id: "description", label: String(localized: "Description"), systemImage: "text.alignleft",
            oldValue: oldDescription, newValue: newDescription.isEmpty ? oldDescription : newDescription
        ))

        // Mirrors AppEndpoints.updateAppInformation's own platform check —
        // tvOS entries never touch the App Store link or version fields.
        if detail.platform != .tvos {
            // Compared by the app's ID, not letter for letter: Apple's link
            // always ends in "?uo=4" and names a country, so a link that
            // already pointed to the right app looked changed every time,
            // and accepting it swapped a clean link for a messier one. When
            // the app really is different, the suggestion is the neutral
            // link (no country, no tag), which opens each person's own
            // App Store, as Submit an App saves. Requested directly
            // (2026-10-07).
            //
            // The same app's link is also suggested in its neutral form
            // when the one on file names a country or the app, or has the
            // "?uo=4" tag, so the Health Check finds those entries and this
            // sheet fixes them. Only the id is kept. A link that's already
            // neutral still matches. Requested directly (2026-10-08): 11 of
            // the 12 newest entries had a /us/ link and the scan showed none.
            let oldLink = detail.appStoreUrl ?? ""
            let storeLink = metadata.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            let oldId = ItunesAPI.appStoreId(of: oldLink)
            let isSameApp = oldId != nil && oldId == ItunesAPI.appStoreId(of: storeLink)
            let newLink: String
            if isSameApp || (storeLink.isEmpty && oldId != nil) {
                newLink = ItunesAPI.storeNeutralURL(oldLink)
            } else {
                newLink = storeLink.isEmpty ? oldLink : ItunesAPI.storeNeutralURL(storeLink)
            }
            diffs.append(AppInfoFieldDiff(
                id: "link", label: String(localized: "App Store Link"), systemImage: "link",
                oldValue: oldLink, newValue: newLink
            ))

            let oldVersion = detail.reviewedVersion ?? ""
            let newVersion = metadata.version.trimmingCharacters(in: .whitespacesAndNewlines)
            diffs.append(AppInfoFieldDiff(
                id: "version", label: String(localized: "Version"), systemImage: "number",
                oldValue: oldVersion, newValue: newVersion.isEmpty ? oldVersion : newVersion
            ))
        }

        // Supported devices, same as the submit wizard: suggested from the
        // App Store, each one untickable, saved into the site's devices
        // field (still labelled "Tested On" on the website until it's
        // renamed — see AppDetail.siteDevices). Requested directly.
        let choices = detail.refreshedDevices(storeFamilies: metadata.deviceFamilies)
        if !choices.isEmpty {
            let current = detail.siteDevices
            diffs.append(AppInfoFieldDiff(
                id: "devices", label: String(localized: "Supported Devices"), systemImage: "iphone.and.ipad",
                oldValue: ListFormatter.localizedString(byJoining: current),
                newValue: ListFormatter.localizedString(byJoining: choices),
                currentDevices: current, deviceChoices: choices
            ))
        }

        // iPhone and iPad entries only: this device can't tell what an
        // Apple Watch or Mac is running. An older iOS than the one on file
        // is still offered, but starts switched off, so a newer version
        // isn't replaced by accident.
        if detail.platform == .ios, let deviceVersion = testedOnThisDevice, !deviceVersion.isEmpty {
            let onFile = (detail.testedOnIOS ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let older = isOlder(deviceVersion, than: onFile)
            var diff = AppInfoFieldDiff(
                id: iosTestedID, label: String(localized: "iOS Version Tested"), systemImage: "iphone",
                oldValue: onFile, newValue: deviceVersion
            )
            diff.startsSelected = !older
            diff.note = older ? String(localized: "This device has an older iOS than the one on file.") : nil
            diffs.append(diff)
        }

        return diffs
    }
}

/// Replaces what used to be a single confirmationDialog that unconditionally
/// overwrote title/description/link/version regardless of whether any of
/// them had actually changed. Shows only what's different from the App
/// Store listing, lets an editor deselect anything they don't want touched,
/// and lists everything that already matches so it's clear nothing was
/// silently skipped. Requested directly.
struct UpdateAppInfoSheet: View {
    let diffs: [AppInfoFieldDiff]
    @Binding var selectedFieldIDs: Set<String>
    /// Which suggested devices to save, when Supported Devices is included.
    @Binding var selectedDevices: Set<String>
    let isUpdating: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isHeaderFocused: Bool

    private var changedDiffs: [AppInfoFieldDiff] { diffs.filter(\.changed) }
    private var unchangedDiffs: [AppInfoFieldDiff] { diffs.filter { !$0.changed } }
    private var devicesDiff: AppInfoFieldDiff? { changedDiffs.first { $0.id == "devices" } }

    /// Saving "no devices" isn't allowed — the website requires at least one.
    private var canConfirm: Bool {
        !selectedFieldIDs.isEmpty && !(selectedFieldIDs.contains("devices") && selectedDevices.isEmpty)
    }

    var body: some View {
        AppNavigationStack {
            Form {
                Section {
                    WizardStepHeader(
                        title: "Update from App Store", icon: "arrow.triangle.2.circlepath",
                        stepIndex: 1, stepTotal: 1, headerFocus: $isHeaderFocused
                    )
                    Text(changedDiffs.isEmpty
                        ? "Compares this entry against its live App Store listing."
                        : "Compares this entry with its current App Store listing. Choose which changes to accept below."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                if changedDiffs.isEmpty {
                    Section {
                        Text("Everything here already matches the App Store listing. You're all set.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(changedDiffs) { diff in
                            fieldToggleRow(diff)
                        }
                    } header: {
                        Text("Updates to Review")
                    } footer: {
                        Text("Refresh the details that look right. Anything you leave off will stay just as it is.")
                    }
                }

                if let devicesDiff, selectedFieldIDs.contains("devices") {
                    Section {
                        ForEach(devicesDiff.deviceChoices, id: \.self) { device in
                            Toggle(device, isOn: Binding(
                                get: { selectedDevices.contains(device) },
                                set: { isOn in
                                    if isOn { selectedDevices.insert(device) } else { selectedDevices.remove(device) }
                                }
                            ))
                        }
                    } header: {
                        Text("Supported Devices")
                    } footer: {
                        Text(selectedDevices.isEmpty
                            ? "Choose at least one device."
                            : "Suggested from the App Store. Untick any device this app doesn't really support.")
                    }
                }

                if !unchangedDiffs.isEmpty {
                    Section("Already Matches") {
                        ForEach(unchangedDiffs) { diff in
                            noChangeRow(diff)
                        }
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Update from App Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { SoundPlayer.shared.play(.screenClose); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUpdating {
                        ProgressView()
                    } else if !changedDiffs.isEmpty {
                        Button("Update") { onConfirm() }
                            .disabled(!canConfirm)
                    }
                }
            }
            .disabled(isUpdating)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
            // Ticks while the site is being updated (2026-10-07).
            .waitingTick(while: isUpdating, stillWaiting: String(localized: "Still saving."))
        }
    }

    @ViewBuilder
    private func fieldToggleRow(_ diff: AppInfoFieldDiff) -> some View {
        Toggle(isOn: Binding(
            get: { selectedFieldIDs.contains(diff.id) },
            set: { isOn in
                if isOn { selectedFieldIDs.insert(diff.id) } else { selectedFieldIDs.remove(diff.id) }
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Label(diff.label, systemImage: diff.systemImage)
                    .font(.body).fontWeight(.semibold)
                Text("\(truncated(diff.oldValue)) → \(truncated(diff.newValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let note = diff.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(Text(diff.label))
        .accessibilityValue(Text((selectedFieldIDs.contains(diff.id)
            ? String(localized: "On. Was \(truncated(diff.oldValue, limit: 200)), now \(truncated(diff.newValue, limit: 200)).")
            : String(localized: "Off. Was \(truncated(diff.oldValue, limit: 200)), now \(truncated(diff.newValue, limit: 200)).")
        ) + (diff.note.map { " " + $0 } ?? "")))
        .accessibilityHint(String(localized: "Double tap to include or skip this detail."))
    }

    @ViewBuilder
    private func noChangeRow(_ diff: AppInfoFieldDiff) -> some View {
        HStack {
            Label(diff.label, systemImage: diff.systemImage)
            Spacer()
            Text("Already matches")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(diff.label): already matches"))
    }

    private func truncated(_ value: String, limit: Int = 60) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return String(localized: "(empty)") }
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }
}
