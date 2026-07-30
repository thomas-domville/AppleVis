import SwiftUI
import CoreSpotlight

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
            .preferredColorScheme(preferences.colorScheme)
            .tint(preferences.theme.accentColor)
            .overlay { TipOverlay() }
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
                deepLinkRouter.handleUniversalLink(url)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    BackgroundDownloadTask.scheduleNext()
                    ICloudSyncManager.shared.pushSavedItems()
                    ICloudSyncManager.shared.pushQueue(player.queue)
                    ICloudSyncManager.shared.pushSettings()
                }
            }
            .task {
                ICloudSyncManager.shared.player = player
                ICloudSyncManager.shared.pullAll()
                PushNotificationManager.deepLinkRouter = deepLinkRouter
                PushNotificationManager.authStore = auth
            }
            .onChange(of: preferences.notificationSound) { _, _ in
                Task { await PushNotificationManager.syncRegistration() }
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}
