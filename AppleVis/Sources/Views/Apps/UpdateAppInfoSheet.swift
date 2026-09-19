import SwiftUI

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

    var changed: Bool {
        oldValue.trimmingCharacters(in: .whitespacesAndNewlines) != newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Price is deliberately left out — the App Store lookup only ever
    /// reports a plain free/paid boolean, not AppleVis's finer categories
    /// ("Free with In-App Purchases", "Requires Subscription", etc.), and
    /// there's no permitted way to get that distinction automatically (see
    /// the price brainstorm this replaces). Discussed directly; out of
    /// scope until there's a real way to resolve it.
    static func build(detail: AppDetail, metadata: ItunesMetadata) -> [AppInfoFieldDiff] {
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
            let oldLink = detail.appStoreUrl ?? ""
            let newLink = metadata.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            diffs.append(AppInfoFieldDiff(
                id: "link", label: String(localized: "App Store Link"), systemImage: "link",
                oldValue: oldLink, newValue: newLink.isEmpty ? oldLink : newLink
            ))

            let oldVersion = detail.reviewedVersion ?? ""
            let newVersion = metadata.version.trimmingCharacters(in: .whitespacesAndNewlines)
            diffs.append(AppInfoFieldDiff(
                id: "version", label: String(localized: "Version"), systemImage: "number",
                oldValue: oldVersion, newValue: newVersion.isEmpty ? oldVersion : newVersion
            ))
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
    let isUpdating: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isHeaderFocused: Bool

    private var changedDiffs: [AppInfoFieldDiff] { diffs.filter(\.changed) }
    private var unchangedDiffs: [AppInfoFieldDiff] { diffs.filter { !$0.changed } }

    var body: some View {
        NavigationStack {
            Form {
                if changedDiffs.isEmpty {
                    Section {
                        Text("Everything here already matches the App Store listing. You're all set.")
                            .foregroundStyle(.secondary)
                            .accessibilityFocused($isHeaderFocused)
                    }
                } else {
                    Section {
                        ForEach(changedDiffs) { diff in
                            fieldToggleRow(diff)
                        }
                    } header: {
                        Text("Updates to Review").accessibilityFocused($isHeaderFocused)
                    } footer: {
                        Text("Refresh the details that look right. Anything you leave off will stay just as it is.")
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
            .navigationTitle("Refresh App Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { SoundPlayer.shared.play(.screenClose); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUpdating {
                        ProgressView()
                    } else if !changedDiffs.isEmpty {
                        Button("Refresh") { onConfirm() }
                            .disabled(selectedFieldIDs.isEmpty)
                    }
                }
            }
            .disabled(isUpdating)
            .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
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
            }
        }
        .accessibilityLabel(Text(diff.label))
        .accessibilityValue(Text(selectedFieldIDs.contains(diff.id)
            ? String(localized: "On. Was \(truncated(diff.oldValue, limit: 200)), now \(truncated(diff.newValue, limit: 200)).")
            : String(localized: "Off. Was \(truncated(diff.oldValue, limit: 200)), now \(truncated(diff.newValue, limit: 200)).")
        ))
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
