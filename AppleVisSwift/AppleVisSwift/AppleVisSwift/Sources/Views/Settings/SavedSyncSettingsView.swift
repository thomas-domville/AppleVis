import SwiftUI

struct SavedSyncSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var isSyncing = false
    @State private var lastSyncDate: Date? = nil

    var body: some View {
        Form {
            Section {
                Text("Keep your saved content, reading positions, podcast queue, and settings in sync across all your Apple devices using iCloud.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $preferences.iCloudSync)
                    .accessibilityHint("Master switch for all AppleVis iCloud sync features.")

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
                    .accessibilityLabel("Last synced: \(lastSyncDate.map { $0.formatted() } ?? "never"). Sync Now button.")
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
                        isOn: $preferences.readingPositionSync,
                        icon: "text.book.closed",
                        label: "Reading Position",
                        detail: "Resume reading from the same point on any device."
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
        }
        .navigationTitle("Saved & Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func triggerSync() {
        isSyncing = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            lastSyncDate = Date()
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
