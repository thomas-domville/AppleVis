import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore
    @State private var systemAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false

    var body: some View {
        Form {
            // iOS permission status
            Section("iOS Permission") {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push Notifications")
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(statusColor)
                        }
                    } icon: {
                        Image(systemName: systemAuthStatus == .authorized ? "bell.fill" : "bell.slash")
                            .foregroundStyle(statusColor)
                    }
                    Spacer()
                    if systemAuthStatus == .notDetermined {
                        Button("Allow") { requestPermission() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else if systemAuthStatus == .denied {
                        Button("Open Settings") { openSettings() }
                            .controlSize(.small)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            // Sound
            Section {
                Picker("Notification Sound", selection: $preferences.notificationSound) {
                    ForEach(NotificationSound.allCases) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .accessibilityHint("Choose the sound played for AppleVis notifications.")

                if let sound = NotificationSound.allCases.first(where: { $0 == preferences.notificationSound }) {
                    Text(sound.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Sound")
            }

            // Category toggles - community (auth required)
            if auth.isSignedIn {
                Section {
                    Toggle("Forum Replies", isOn: $preferences.notifyForumReplies)
                        .accessibilityHint("Get notified when someone replies to your forum topics.")
                    Toggle("Mentions", isOn: $preferences.notifyMentions)
                        .accessibilityHint("Get notified when someone mentions you in a post or comment.")
                    Toggle("Followed Topics", isOn: $preferences.notifyFollowedTopics)
                        .accessibilityHint("Get notified about activity in topics you follow.")
                } header: {
                    Text("My Activity")
                } footer: {
                    Text("These alerts are only available while signed in.")
                }
            }

            Section("Community") {
                Toggle("New Forum Topics", isOn: $preferences.notifyNewTopics)
                    .accessibilityHint("Get notified when new forum discussions are posted.")
                Toggle("New App Listings", isOn: $preferences.notifyAppUpdates)
                    .accessibilityHint("Get notified when new accessible apps are added to the AppleVis App Directory.")
                Toggle("New Podcast Episodes", isOn: $preferences.notifyNewEpisodes)
                    .accessibilityHint("Get notified when new podcast episodes are published.")
                Toggle("New Resources", isOn: $preferences.notifyNewResources)
                    .accessibilityHint("Get notified when new guides, tutorials, and tips are published.")
                Toggle("Announcements", isOn: $preferences.notifyAnnouncements)
                    .accessibilityHint("Get notified about important AppleVis announcements.")
            }

            if !auth.isSignedIn {
                Section {
                    Label {
                        Text("Sign in to enable forum reply and mention notifications.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkPermission() }
    }

    // MARK: - Permission

    private var statusText: String {
        switch systemAuthStatus {
        case .authorized:       return "Allowed"
        case .denied:           return "Blocked — change in iOS Settings"
        case .notDetermined:    return "Not yet requested"
        case .provisional:      return "Provisional (quiet)"
        case .ephemeral:        return "Ephemeral"
        @unknown default:       return "Unknown"
        }
    }

    private var statusColor: Color {
        switch systemAuthStatus {
        case .authorized:   return .green
        case .denied:       return .red
        default:            return .secondary
        }
    }

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthStatus = settings.authorizationStatus
    }

    private func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                await checkPermission()
                _ = granted
            } catch {
                await checkPermission()
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
