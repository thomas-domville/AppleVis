import SwiftUI
import CoreSpotlight
import Combine
import UserNotifications

@main
struct AppleVisApp: App {
    @UIApplicationDelegateAdaptor(AppleVisAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerStore()
    @StateObject private var preferences = PreferencesStore()
    @StateObject private var toast = ToastStore()
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    @StateObject private var tips = TipStore()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var keyCommands = KeyCommandRouter()
    @StateObject private var guidedExperiencePause = GuidedExperiencePauseStore()

    init() {
        BackgroundDownloadTask.register()
        Self.purgeCacheIfRetentionExpired()
    }

    /// URLCache has no per-entry age API, so "Cache Retention" (Settings →
    /// Storage) is enforced as a periodic full clear: once more time has
    /// passed since the last clear than the retention period, wipe it.
    private static func purgeCacheIfRetentionExpired() {
        let months = UserDefaults.standard.object(forKey: "storage.cacheRetentionMonths") as? Int ?? 6
        guard months > 0 else { return } // "Keep Forever"

        let lastPurgeKey = "storage.lastCachePurge"
        let retentionSeconds = TimeInterval(months) * 30 * 86_400
        let lastPurge = UserDefaults.standard.object(forKey: lastPurgeKey) as? Date ?? .distantPast

        if Date().timeIntervalSince(lastPurge) >= retentionSeconds {
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.set(Date(), forKey: lastPurgeKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isOnboarded {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(auth)
            .environmentObject(player)
            .environmentObject(preferences)
            .environmentObject(toast)
            .environmentObject(deepLinkRouter)
            .environmentObject(tips)
            .environmentObject(networkMonitor)
            .environmentObject(keyCommands)
            .environmentObject(guidedExperiencePause)
            .preferredColorScheme(preferences.colorScheme)
            .tint(preferences.accentColor)
            .overlay { TipOverlay(tips: tips) }
            .overlay { GuidedExperienceResumeBanner(pauseStore: guidedExperiencePause, preferences: preferences, keyCommands: keyCommands) }
            .accessibilityAction(.magicTap) {
                guard player.currentEpisode != nil else { return }
                player.togglePlayPause()
                tips.show(.playerMagicTap)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                deepLinkRouter.handleSpotlight(identifier: identifier)
            }
            .onOpenURL { url in
                if !deepLinkRouter.handleCustomScheme(url) {
                    deepLinkRouter.handleUniversalLink(url)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    BackgroundDownloadTask.scheduleNext()
                    ICloudSyncManager.shared.pushSavedItems()
                    player.pushPlaybackStateToICloud()
                    ICloudSyncManager.shared.pushReadHistory()
                    ICloudSyncManager.shared.pushPlayedEpisodes()
                    ICloudSyncManager.shared.pushSettings()
                } else if newPhase == .active {
                    deepLinkRouter.checkPendingShareExtensionContent()
                    // Matches standard iOS badge behavior (and RN's own
                    // notifBadge description: "tap the app and the badge
                    // clears") — opening the app clears it.
                    UNUserNotificationCenter.current().setBadgeCount(0)
                    PushNotificationManager.resetBadgeCount()
                    // Previously only pulled once at cold launch (`.task`
                    // runs once per view identity) — switching between two
                    // signed-in devices within the same session meant the
                    // other device's saved items/queue/settings changes
                    // never appeared until a full quit and relaunch.
                    ICloudSyncManager.shared.pullAll()
                    // Refreshes `.system`/`.oppositeToSystem`'s notion of the
                    // real device appearance from UIKit directly — see the
                    // doc comment on `PreferencesStore.systemIsDark` for why
                    // this can no longer come from SwiftUI's
                    // `@Environment(\.colorScheme)`.
                    preferences.systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
                }
            }
            .task {
                ICloudSyncManager.shared.player = player
                ICloudSyncManager.shared.pullAll()
                PushNotificationManager.deepLinkRouter = deepLinkRouter
                PushNotificationManager.authStore = auth
                PushNotificationManager.toastStore = toast
                APIClient.authStore = auth
                APIClient.toastStore = toast
            }
            .onChange(of: preferences.notificationSound) { _, _ in
                Task { await PushNotificationManager.syncRegistration() }
            }
            .onChange(of: deepLinkRouter.pendingPodcastAction) { _, action in
                guard let action else { return }
                deepLinkRouter.pendingPodcastAction = nil
                Task { await handlePodcastSiriAction(action) }
            }
        }
        .commands {
            CommandMenu("Go") {
                Button("Home") { keyCommands.selectedTab = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Discover") { keyCommands.selectedTab = 1 }
                    .keyboardShortcut("2", modifiers: .command)
                Button("For You") { keyCommands.selectedTab = 2 }
                    .keyboardShortcut("3", modifiers: .command)
                Divider()
                Button("Refresh") { keyCommands.refreshRequested.send() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Settings") { keyCommands.showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    /// "Resume/Play Latest AppleVis Podcast" Siri intents. Resume reuses
    /// PlayerStore's existing lazily-restored currentEpisode; Play Latest
    /// fetches the newest episode fresh.
    private func handlePodcastSiriAction(_ action: PodcastSiriAction) async {
        switch action {
        case .resume:
            player.play()
        case .playLatest:
            guard let latest = try? await APIClient.shared.podcasts.episodes().items.first else { return }
            await player.load(latest)
        }
    }
}

