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
                    text: String(localized: "When you sign in or contribute, AppleVis handles your account details, optional public profile, posts and comments, reports, and a device push token if you enable notifications.")
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
                    title: String(localized: "No In-App Analytics"),
                    text: String(localized: "The app contains no third-party advertising or analytics SDKs. AppleVis servers still receive the information needed to sign you in, load content, and complete actions you request.")
                )
                InfoCard(
                    icon: "lock.icloud",
                    title: String(localized: "Private iCloud Sync"),
                    text: String(localized: "If you turn on sync, selected saved items, playback information, reading history, and preferences are stored in your private iCloud account. AppleVis does not operate that storage.")
                )
                InfoCard(
                    icon: "cpu",
                    title: String(localized: "On-Device AI"),
                    text: String(localized: "The app's Apple Intelligence features run on your device. Content you choose to publish or send is still submitted to AppleVis servers to complete that request.")
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
