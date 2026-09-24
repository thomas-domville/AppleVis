import SwiftUI

struct StorageView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var downloadedMB: Double = 0
    @State private var cachedMB: Double = 0
    @State private var showClearDownloads = false
    @State private var showClearCache = false
    @State private var showClearAll = false
    @AppStorage("storage.cacheRetentionMonths") private var cacheRetentionMonths: Int = 6
    @AccessibilityFocusState private var isTitleFocused: Bool

    private let retentionOptions: [(label: String, months: Int)] = [
        ("3 Months", 3), ("6 Months", 6), ("12 Months", 12), (String(localized: "Keep Forever"), 0)
    ]

    private var totalMB: Double { downloadedMB + cachedMB }

    var body: some View {
        Form {
            Section {
                Text("How much space AppleVis is using on this device, how long cached content sticks around before it clears itself, and a few buttons for clearing things out sooner if you'd rather not wait.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Usage") {
                Text("Shows how much space AppleVis is using on this device, split between downloaded episodes and cached content.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StorageRow(label: String(localized: "Downloaded Episodes"), value: downloadedMB, color: .blue)
                StorageRow(label: String(localized: "Cached Content"), value: cachedMB, color: .green)
                Divider()
                    .accessibilityHidden(true)
                StorageRow(label: String(localized: "Total"), value: totalMB, color: .primary, bold: true)
            }

            Section("Cache Retention") {
                Picker("Keep Cache For", selection: $cacheRetentionMonths) {
                    ForEach(retentionOptions, id: \.months) { opt in
                        Text(opt.label).tag(opt.months)
                    }
                }
                .accessibilityHint(String(localized: "Cached articles and metadata older than this will be automatically removed."))
                // See GeneralSettingsView's Home Startup Behavior for the
                // full reasoning — a persistent .accessibilityValue() here
                // duplicated what the control already announces natively on
                // plain focus. Swapped for a one-shot announcement fired
                // only right after an adjustment.
                .accessibilityAdjustableAction { direction in
                    guard let idx = retentionOptions.firstIndex(where: { $0.months == cacheRetentionMonths }) else { return }
                    switch direction {
                    case .increment:
                        cacheRetentionMonths = retentionOptions[(idx + 1) % retentionOptions.count].months
                    case .decrement:
                        cacheRetentionMonths = retentionOptions[(idx - 1 + retentionOptions.count) % retentionOptions.count].months
                    @unknown default: break
                    }
                    UIAccessibility.post(notification: .announcement, argument: retentionOptions.first { $0.months == cacheRetentionMonths }?.label ?? "")
                }

                Text("Cached content lets you re-open articles without waiting for a network request. Older content is cleared automatically based on this setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Clear Data") {
                Button(role: .destructive) {
                    showClearDownloads = true
                } label: {
                    Label("Clear Downloaded Episodes", systemImage: "trash")
                }
                .confirmationDialog(
                    "Clear downloads?",
                    isPresented: $showClearDownloads,
                    titleVisibility: .visible
                ) {
                    Button("Clear Downloads", role: .destructive) { clearDownloads() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All downloaded episodes will be deleted. You can re-download them at any time while connected to the internet.")
                }

                Button(role: .destructive) {
                    showClearCache = true
                } label: {
                    Label("Clear Cached Content", systemImage: "internaldrive.badge.minus")
                }
                .confirmationDialog(
                    "Clear cache?",
                    isPresented: $showClearCache,
                    titleVisibility: .visible
                ) {
                    Button("Clear Cache", role: .destructive) { clearCache() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Cached articles and metadata will be removed. Content will reload from the server on next view.")
                }

                Button(role: .destructive) {
                    showClearAll = true
                } label: {
                    Label("Clear All Storage", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
                .confirmationDialog(
                    "Clear all storage?",
                    isPresented: $showClearAll,
                    titleVisibility: .visible
                ) {
                    Button("Clear Everything", role: .destructive) { clearAll() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All downloaded episodes and cached content will be removed. Your account and synced data are not affected.")
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Storage & Cache")
        .navigationBarTitleDisplayMode(.inline)
        .task { await calculateUsage() }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }

    private func calculateUsage() async {
        let cacheDisk = URLCache.shared.currentDiskUsage + Int(ContentCache.shared.totalSizeBytes)
        cachedMB = Double(cacheDisk) / 1_000_000
        downloadedMB = Double(DownloadManager.shared.totalSizeBytes) / 1_000_000
    }

    private func clearDownloads() {
        DownloadManager.shared.deleteAll()
        downloadedMB = 0
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        ContentCache.shared.clearAll()
        UserDefaults.standard.set(Date(), forKey: "storage.lastCachePurge")
        cachedMB = 0
    }

    private func clearAll() {
        clearDownloads()
        clearCache()
    }
}

private struct StorageRow: View {
    let label: String
    let value: Double
    let color: Color
    var bold: Bool = false

    private var displayText: String {
        value < 1 ? "< 1 MB" : String(localized: "\(Int(value)) MB")
    }

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(bold ? .semibold : .regular)
                // Was `color == .primary ? .primary : .primary` — always
                // rendered plain primary regardless of the color passed in,
                // silently dropping the blue/green category coding every
                // call site actually specifies. Reported directly.
                .foregroundStyle(color)
            Spacer()
            Text(displayText)
                .foregroundStyle(bold ? .primary : .secondary)
                .fontWeight(bold ? .semibold : .regular)
                .monospacedDigit()
        }
        // Two Texts with no grouping meant VoiceOver read both of them
        // individually (label, then value) *and* the explicit label below —
        // effectively hearing the row twice per swipe. Reported directly.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(label): \(displayText)"))
    }
}
