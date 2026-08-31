import SwiftUI

struct SavedSyncSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var isSyncing = false
    @State private var lastSyncDate: Date? = UserDefaults.standard.object(forKey: ICloudSyncManager.lastSyncDateKey) as? Date
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Keep your saved content, followed topics, podcast queue, listening progress, read history, and settings in sync across all your Apple devices using iCloud.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $preferences.iCloudSync)
                    .accessibilityHint(String(localized: "Master switch for all AppleVis iCloud sync features."))
                Text("The master switch for everything below — turn it off and none of your data syncs across devices, no matter how the individual toggles are set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if preferences.iCloudSync {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last Synced")
                                .font(.subheadline)
                            Text(lastSyncDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            triggerSync()
                        } label: {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sync Now")
                            }
                        }
                        .disabled(isSyncing)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Last synced: \(lastSyncDate.map { $0.formatted() } ?? "never"). Sync Now button."))
                }
            }

            if preferences.iCloudSync {
                Section("What Gets Synced") {
                    SyncToggleRow(
                        isOn: $preferences.savedItemsSync,
                        icon: "bookmark",
                        label: "Saved Items",
                        detail: "Articles, episodes, and apps you've bookmarked."
                    )

                    SyncToggleRow(
                        isOn: $preferences.followedItemsSync,
                        icon: "bell",
                        label: "Following",
                        detail: "Topics and content you follow stay the same on all devices."
                    )

                    SyncToggleRow(
                        isOn: $preferences.podcastPositionSync,
                        icon: "headphones",
                        label: "Podcast Position",
                        detail: "Continue listening from where you left off on any device."
                    )

                    SyncToggleRow(
                        isOn: $preferences.queueSync,
                        icon: "list.number",
                        label: "Podcast Queue",
                        detail: "Your listening queue stays the same on all devices."
                    )

                    SyncToggleRow(
                        isOn: $preferences.readHistorySync,
                        icon: "clock.arrow.circlepath",
                        label: "Read History",
                        detail: "Seen topics, new-comment tracking, and visit history can follow you across devices when history is enabled."
                    )

                    SyncToggleRow(
                        isOn: $preferences.settingsSync,
                        icon: "gearshape",
                        label: "Settings & Preferences",
                        detail: "Theme, accessibility settings, and app preferences."
                    )
                }

                Section {
                    Label {
                        Text("All synced data is protected by Apple's end-to-end iCloud encryption.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.icloud")
                            .foregroundStyle(.green)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Section {
                    Label {
                        Text("iCloud Sync is off. Your saved items and settings are only stored locally on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "icloud.slash")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                ResetToDefaultsButton {
                    preferences.iCloudSync = true
                    preferences.savedItemsSync = true
                    preferences.followedItemsSync = true
                    preferences.podcastPositionSync = true
                    preferences.queueSync = true
                    preferences.readHistorySync = true
                    preferences.settingsSync = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Saved & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }

    private func triggerSync() {
        isSyncing = true
        Task {
            ICloudSyncManager.shared.pushSavedItems()
            ICloudSyncManager.shared.player?.pushPlaybackStateToICloud()
            ICloudSyncManager.shared.pushReadHistory()
            ICloudSyncManager.shared.pushPlayedEpisodes()
            ICloudSyncManager.shared.pushSettings()
            ICloudSyncManager.shared.pullAll()
            // Each push/pull above now stamps this itself (see
            // `ICloudSyncManager.touchLastSyncDate`) — re-read rather than
            // stamping "now" locally, so this stays the one shared value
            // that also reflects sync triggered elsewhere in the app
            // (saving an item, backgrounding, an external iCloud change).
            lastSyncDate = UserDefaults.standard.object(forKey: ICloudSyncManager.lastSyncDateKey) as? Date
            isSyncing = false
        }
    }
}

private struct SyncToggleRow: View {
    @Binding var isOn: Bool
    let icon: String
    let label: String
    let detail: String

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityHint(detail)
    }
}
