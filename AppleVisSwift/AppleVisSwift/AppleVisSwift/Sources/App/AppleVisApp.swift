import SwiftUI
import CoreSpotlight

@main
struct AppleVisApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerStore()
    @StateObject private var preferences = PreferencesStore()
    @StateObject private var toast = ToastStore()
    @StateObject private var deepLinkRouter = DeepLinkRouter()

    init() {
        BackgroundDownloadTask.register()
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
            .preferredColorScheme(preferences.colorScheme)
            .tint(preferences.theme.accentColor)
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
                }
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}
