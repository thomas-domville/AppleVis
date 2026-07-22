import AppIntents

/// Basic Siri/Shortcuts support. Kept intentionally simple — these open the
/// app rather than trying to control playback from outside the process,
/// since `PlayerStore` is a single `@StateObject` owned by the app's root
/// view, not a cross-process-callable singleton; an intent that "plays the
/// latest episode" without opening the app would need a real singleton
/// audio-session owner, which is a bigger architectural change than this
/// pass should make blind.
struct OpenAppleVisIntent: AppIntent {
    static var title: LocalizedStringResource = "Open AppleVis"
    static var description = IntentDescription("Opens AppleVis to the Home tab.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct AppleVisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAppleVisIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open \(.applicationName) app",
            ],
            shortTitle: "Open AppleVis",
            systemImageName: "eye"
        )
    }
}
