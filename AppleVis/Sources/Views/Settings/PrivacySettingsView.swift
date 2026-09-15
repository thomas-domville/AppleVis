import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showClearDataConfirmation = false
    @State private var clearDataComplete = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("AppleVis is built by and for the blindness and low-vision community. Your privacy is not a product. This section explains what we collect, what stays on your device, and gives you control over smart features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Privacy at a Glance") {
                InfoCard(
                    icon: "person.text.rectangle",
                    title: "What We Collect",
                    text: "AppleVis collects your email address and username for your account, and a device push token for notifications."
                )
                InfoCard(
                    icon: "key.icloud",
                    title: "Your Session Is Encrypted",
                    text: "Your sign-in session is stored in the iOS Keychain, not in plain app storage."
                )
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
                Text("Non-English detection, compose rewrite/translation, search translation, and AI summaries all run on-device via Apple Intelligence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    IntelligenceSettingsView()
                } label: {
                    Label("Manage Smart Features", systemImage: "cpu")
                }
            }

            Section("iCloud Sync") {
                Text("Saved items, followed content, podcast position, queue, and settings can sync across your devices via iCloud. Each of these can be turned on or off individually in Settings > Saved and Sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    SavedSyncSettingsView()
                } label: {
                    Label("Manage iCloud Sync", systemImage: "icloud")
                }
            }

            Section("What's New Indicators") {
                Toggle("Show What's New on Home", isOn: $preferences.showNewActivityIndicators)
                    .accessibilityHint(String(localized: "When on, Home shows a New view, a quick summary, and small badges for content with new activity since your last visit."))

                Text("Reading history is always tracked on-device — this only controls whether Home actually shows what's new because of it. Turning it off doesn't erase anything; it just keeps Home quieter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Language Filtering") {
                Toggle("Filter Profanity", isOn: $preferences.filterProfanity)
                    .accessibilityHint(String(localized: "When on, milder language is shown masked, like s star star star, instead of spelled out."))

                Text("AppleVis blocks strong or explicit language from every post and comment, always — this setting doesn't change that. It only controls whether milder language, which the site otherwise allows, is shown masked or spelled out. We keep this on by default to help AppleVis stay welcoming, and to stay within Apple's guidelines for our age rating.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let article = HelpContent.find("community-language-filter") {
                    NavigationLink {
                        HelpArticleDetailView(article: article)
                    } label: {
                        Label("Learn More About Language Filtering", systemImage: "info.circle")
                    }
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
