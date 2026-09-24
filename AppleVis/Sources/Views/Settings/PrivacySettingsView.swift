import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showClearDataConfirmation = false
    @State private var clearDataComplete = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("AppleVis is built by and for the blindness and low-vision community. Your privacy is not a product. This section explains what we collect and what stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Privacy at a Glance") {
                InfoCard(
                    icon: "person.text.rectangle",
                    title: String(localized: "What We Collect"),
                    text: String(localized: "AppleVis collects your email address and username for your account, and a device push token for notifications.")
                )
                InfoCard(
                    icon: "key.icloud",
                    title: String(localized: "Your Session Is Encrypted"),
                    text: String(localized: "Your sign-in session is stored in the iOS Keychain, not in plain app storage.")
                )
                InfoCard(
                    icon: "nosign",
                    title: String(localized: "No Ad Tracking"),
                    text: String(localized: "We do not use third-party advertising networks or sell your data to advertisers.")
                )
                InfoCard(
                    icon: "icloud.slash",
                    title: String(localized: "Analytics Are Anonymous"),
                    text: String(localized: "Usage analytics are aggregated and never linked to your account or device identity.")
                )
                InfoCard(
                    icon: "lock.icloud",
                    title: String(localized: "iCloud Sync Is End-to-End"),
                    text: String(localized: "Data synced via iCloud uses Apple's end-to-end encryption. AppleVis cannot read it.")
                )
                InfoCard(
                    icon: "cpu",
                    title: String(localized: "On-Device AI"),
                    text: String(localized: "Smart features powered by AI run on your device using Apple Intelligence. Content is not sent to external servers.")
                )
                InfoCard(
                    icon: "envelope.badge.shield.half.filled",
                    title: String(localized: "Notification Privacy"),
                    text: String(localized: "Push notification content is encrypted in transit. Notification payloads are minimal — we don't embed full article text.")
                )
            }

            Section("Data Management") {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Label("Notification Privacy Settings", systemImage: "bell.badge.slash")
                        ExternalLinkIndicator()
                    }
                }
                .accessibilityHint(String(localized: "Opens this app's notification settings in the Settings app, outside AppleVis."))

                WebLink(destination: URL(string: "https://www.applevis.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "doc.text")
                }

                Button(role: .destructive) {
                    showClearDataConfirmation = true
                } label: {
                    Label("Clear All Local Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .confirmationDialog(
                    "Clear all local data?",
                    isPresented: $showClearDataConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) { clearLocalData() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes cached content, downloaded episodes, saved items, and locally tracked read/seen status. Your account, cloud data, and app preferences are not affected.")
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Local data cleared", isPresented: $clearDataComplete) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All local data has been removed. The app will reload fresh content from the server.")
        }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }

    /// Previously only cleared URLCache — everything else the confirmation
    /// dialog promised (downloaded episodes, saved items, locally tracked
    /// read/seen state) silently did nothing.
    private func clearLocalData() {
        URLCache.shared.removeAllCachedResponses()
        ContentCache.shared.clearAll()
        DownloadManager.shared.deleteAll()
        PersistenceStore.shared.clearAllLocalData()
        preferences.lastGuestEmail = ""
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
