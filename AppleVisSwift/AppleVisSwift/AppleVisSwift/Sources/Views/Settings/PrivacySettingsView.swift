import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showClearDataConfirmation = false
    @State private var clearDataComplete = false

    var body: some View {
        Form {
            Section {
                Text("AppleVis is built by and for the blindness and low-vision community. Your privacy is not a product. This section explains what we collect, what stays on your device, and gives you control over smart features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy at a Glance") {
                InfoCard(
                    icon: "nosign",
                    title: "No Ad Tracking",
                    text: "We do not use third-party advertising networks or sell your data to advertisers."
                )
                InfoCard(
                    icon: "icloud.slash",
                    title: "Analytics Are Anonymous",
                    text: "Usage analytics are aggregated and never linked to your account or device identity."
                )
                InfoCard(
                    icon: "lock.icloud",
                    title: "iCloud Sync Is End-to-End",
                    text: "Data synced via iCloud uses Apple's end-to-end encryption. AppleVis cannot read it."
                )
                InfoCard(
                    icon: "cpu",
                    title: "On-Device AI",
                    text: "Smart features powered by AI run on your device using Apple Intelligence. Content is not sent to external servers."
                )
                InfoCard(
                    icon: "envelope.badge.shield.half.filled",
                    title: "Notification Privacy",
                    text: "Push notification content is encrypted in transit. Notification payloads are minimal — we don't embed full article text."
                )
            }

            Section("Smart Features") {
                Toggle("Non-English Content Detection", isOn: $preferences.nonEnglishDetectionEnabled)
                    .accessibilityHint("Detects when content is in a language other than English and offers translation.")
                Toggle("Compose Rewrite", isOn: $preferences.composeRewriteEnabled)
                    .accessibilityHint("Offers AI-assisted rewrites when composing forum posts or messages.")
                Toggle("Compose Translation", isOn: $preferences.composeTranslationEnabled)
                    .accessibilityHint("Offers translation of your draft text into other languages.")
                Toggle("Search Translation", isOn: $preferences.searchTranslationEnabled)
                    .accessibilityHint("Translates your search query when results in other languages are found.")
                Toggle("AI Summaries", isOn: $preferences.aiSummariesEnabled)
                    .accessibilityHint("Generates short summaries for long forum threads and articles.")
            }

            Section("iCloud Sync") {
                Toggle("Sync Saved Items", isOn: $preferences.savedItemsSync)
                    .disabled(!preferences.iCloudSync)
                    .accessibilityHint("Sync your saved articles, episodes, and app listings across all your devices.")
                Toggle("Sync Reading Position", isOn: $preferences.readingPositionSync)
                    .disabled(!preferences.iCloudSync)
                    .accessibilityHint("Resume reading from the same position on any device.")
                Toggle("Sync Podcast Position", isOn: $preferences.podcastPositionSync)
                    .disabled(!preferences.iCloudSync)
                    .accessibilityHint("Resume podcast playback from the same point on any device.")
                Toggle("Sync Queue", isOn: $preferences.queueSync)
                    .disabled(!preferences.iCloudSync)
                    .accessibilityHint("Keep your listening queue in sync across all your devices.")
                Toggle("Sync Settings", isOn: $preferences.settingsSync)
                    .disabled(!preferences.iCloudSync)
                    .accessibilityHint("Sync your preferences, theme, and configuration across all your devices.")

                if !preferences.iCloudSync {
                    Label {
                        Text("Enable iCloud Sync in Saved & Sync to control these options.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Data Management") {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Notification Privacy Settings", systemImage: "bell.badge.slash")
                }

                NavigationLink {
                    StorageView()
                } label: {
                    Label("Manage Storage", systemImage: "internaldrive")
                }

                Link(destination: URL(string: "https://www.applevis.com/privacy-policy")!) {
                    Label("Privacy Policy", systemImage: "doc.text")
                }

                Button(role: .destructive) {
                    showClearDataConfirmation = true
                } label: {
                    Label("Clear All Local Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .confirmationDialog(
                    "Clear All Local Data?",
                    isPresented: $showClearDataConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) { clearLocalData() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes all cached content, downloaded episodes, and local settings. Your account and cloud data are not affected.")
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Local Data Cleared", isPresented: $clearDataComplete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All local data has been removed. The app will reload fresh content from the server.")
        }
    }

    private func clearLocalData() {
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        clearDataComplete = true
    }
}

private struct InfoCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
