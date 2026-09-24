import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore
    @State private var systemAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("What AppleVis can let you know about, and how — whether push notifications are allowed at the iOS level, which sound plays, badge counts, and which kinds of community activity (replies, mentions, new posts) are actually worth a ping.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

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
                        Button {
                            openSettings()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Open Settings")
                                ExternalLinkIndicator()
                            }
                        }
                        .accessibilityHint(String(localized: "Opens the Settings app, outside AppleVis."))
                            .controlSize(.small)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            // Sound
            Section {
                // `sound.displayName` is a String, not a string literal —
                // Text(_ content: String) skips catalog lookup entirely, same
                // bug already fixed for the onboarding sound picker
                // (OnboardingView.swift) and ThemeGroup.label.
                let picker = Picker("Notification Sound", selection: $preferences.notificationSound) {
                    ForEach(NotificationSound.allCases) { sound in
                        Text(LocalizedStringKey(sound.displayName)).tag(sound)
                    }
                }
                .accessibilityHint(String(localized: "Choose the sound played for AppleVis notifications."))
                .onChange(of: preferences.notificationSound) { _, newValue in
                    SoundPlayer.shared.playNotificationPreview(newValue)
                }
                // See GeneralSettingsView's Home Startup Behavior for the
                // full reasoning — a persistent .accessibilityValue() here
                // duplicated what the control already announces natively on
                // plain focus. Swapped for a one-shot announcement fired
                // only right after an adjustment.
                .accessibilityAdjustableAction { direction in
                    guard let idx = NotificationSound.allCases.firstIndex(of: preferences.notificationSound) else { return }
                    switch direction {
                    case .increment:
                        preferences.notificationSound = NotificationSound.allCases[(idx + 1) % NotificationSound.allCases.count]
                    case .decrement:
                        preferences.notificationSound = NotificationSound.allCases[(idx - 1 + NotificationSound.allCases.count) % NotificationSound.allCases.count]
                    @unknown default: break
                    }
                    UIAccessibility.post(notification: .announcement, argument: String(localized: String.LocalizationValue(preferences.notificationSound.displayName)))
                }

                // System Default's own description says "Preview unavailable"
                // — SoundPlayer.playNotificationPreview(.system) deliberately
                // does nothing (iOS has no API to play back a device's actual
                // default alert tone), so offering this action while System
                // Default is selected would silently no-op. Same fix as the
                // onboarding sound picker (OnboardingView.swift). Requested
                // directly.
                if preferences.notificationSound == .system {
                    picker
                } else {
                    // Swiping up/down to change the sound (or opening the picker
                    // and double-tapping an option) also plays a preview via the
                    // onChange below — with VoiceOver's audio ducking, VoiceOver's
                    // own value-changed announcement talks over the clip, making
                    // it hard to actually hear. This action (reachable via the
                    // rotor's Actions category) replays the currently selected
                    // sound on its own, without changing the selection or
                    // triggering that announcement.
                    picker.accessibilityAction(named: Text("Preview")) {
                        SoundPlayer.shared.playNotificationPreview(preferences.notificationSound)
                    }
                }

                if let sound = NotificationSound.allCases.first(where: { $0 == preferences.notificationSound }) {
                    Text(LocalizedStringKey(sound.description))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Badge Count", isOn: $preferences.badgeCountEnabled)
                    .accessibilityHint(String(localized: "Shows a number on the AppleVis icon for unread notifications. Opening the app clears it."))
                    .onChange(of: preferences.badgeCountEnabled) { _, isOn in
                        guard !isOn else { return }
                        UNUserNotificationCenter.current().setBadgeCount(0)
                        PushNotificationManager.resetBadgeCount()
                    }
                Text("Shows a number on the AppleVis icon for unread notifications — opening the app clears it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Sound")
            }

            // Category toggles - community (auth required)
            if auth.isSignedIn {
                Section {
                    // Genuinely auto-follows, not just a push-category
                    // filter — new forum topics and app entries you post get
                    // the same Follow flag a manual tap on Follow would
                    // create, via ComposeTopicView's own follow-on-post
                    // toggle (seeded from this) and SubmitAppView's
                    // followIfEnabled. Only applies going forward: nothing
                    // already posted gets touched, since there's no
                    // subscription record to retroactively create for it.
                    // Clarified directly after being misread as a
                    // stateless "you're the author" check.
                    Toggle("Replies to My Posts", isOn: $preferences.notifyForumReplies)
                        .disabled(pushDenied)
                        .accessibilityHint(String(localized: "Automatically follows new forum topics and app entries you post, so you're notified of replies without following them yourself."))
                    Text("When you post a new forum topic or app entry, it's automatically followed for you — the same as tapping Follow yourself. This only applies going forward; anything you've already posted isn't affected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Mentions shelved (2026-09-23, beta-tester feedback): AppleVis
                    // has no real @mention feature — typing someone's username
                    // doesn't notify them — so this promised something the site
                    // can't deliver. `notifyMentions` and the "mention" push
                    // category are kept for if the website ever adds real
                    // mentions; only the switch is hidden.

                    Toggle("Followed Topics", isOn: $preferences.notifyFollowedTopics)
                        .disabled(pushDenied)
                        .accessibilityHint(String(localized: "Get notified about activity in topics you follow."))
                    Text("Notifies you about new activity in topics you're following.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("My Activity")
                } footer: {
                    Text(pushDenied
                        ? "These alerts are only available while signed in, and won't arrive until push notifications are allowed in iOS Settings above."
                        : "These alerts are only available while signed in.")
                }
            }

            Section {
                Toggle("New Forum Topics", isOn: $preferences.notifyNewTopics)
                    .disabled(pushDenied)
                    .accessibilityHint(String(localized: "Get notified when new forum discussions are posted."))
                Text("Notifies you when a new discussion is posted anywhere on AppleVis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("New App Directory Entries", isOn: $preferences.notifyAppUpdates)
                    .disabled(pushDenied)
                    .accessibilityHint(String(localized: "Get notified when existing apps are updated or new accessible apps are added to the AppleVis App Directory."))
                Text("Notifies you when an app is added to the directory, or an existing listing is updated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("New Podcast Episodes", isOn: $preferences.notifyNewEpisodes)
                    .disabled(pushDenied)
                    .accessibilityHint(String(localized: "Get notified when new podcast episodes are published."))
                Text("Notifies you when a new podcast episode is published.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("New Guides", isOn: $preferences.notifyNewResources)
                    .disabled(pushDenied)
                    .accessibilityHint(String(localized: "Get notified when new guides, tutorials, and tips are published."))
                Text("Notifies you when a new guide, tutorial, or tip is published.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // "Announcements" hidden — AppleVis has no "announcement"
                // content type yet (announcements currently post to Blog/
                // Forum/Newsletter). The preference itself, push routing,
                // and Focus Filter case are all kept intact for a possible
                // future content type, just not offered as a visible
                // toggle until that exists. Reported directly.
                Toggle("New Comments", isOn: $preferences.notifyNewComments)
                    .disabled(pushDenied)
                    .accessibilityHint(String(localized: "Get notified about new comments on any forum topic, podcast episode, app entry, blog post, or guide — not just ones you follow. This can be frequent."))
                Text("Notifies you about new comments anywhere on AppleVis, not just things you follow. This one can get chatty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Community")
            } footer: {
                // These toggles previously stayed fully interactive and
                // appeared "on" regardless of actual system push-permission
                // status, with no way to tell why nothing was arriving
                // (SETTINGS-03) — worst for a screen-reader user, who can't
                // visually cross-reference the system Settings app.
                if pushDenied {
                    Text("Push notifications are blocked in iOS Settings — these won't arrive until allowed above.")
                }
            }

            if !auth.isSignedIn {
                Section {
                    Label {
                        Text("Sign in to get notified about replies to your posts and topics you follow.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.notifyForumReplies = false
                    preferences.notifyMentions = false
                    preferences.notifyNewTopics = false
                    preferences.notifyFollowedTopics = false
                    preferences.notifyNewEpisodes = false
                    preferences.notifyAppUpdates = false
                    preferences.notifyNewResources = false
                    preferences.notifyAnnouncements = false
                    preferences.notifyNewComments = false
                    preferences.notificationSound = .mouseSqueak
                    preferences.badgeCountEnabled = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkPermission() }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }

    // MARK: - Permission

    private var pushDenied: Bool { systemAuthStatus == .denied }

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
            let granted = await PushNotificationManager.requestAuthorizationAndRegister()
            await checkPermission()
            _ = granted
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
