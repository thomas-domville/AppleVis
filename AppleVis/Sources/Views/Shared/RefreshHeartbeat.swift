import UIKit

/// While a refresh is still loading, VoiceOver users hear a soft tick and
/// feel a light tap every second, so they know it's still working on a
/// slow connection. It starts only after a second and a half, so a quick
/// refresh just gives the usual sound. After 8 seconds, VoiceOver says
/// "Still refreshing." once. Same idea as Ask the Mouse's patter, with its
/// own quieter sound so you can tell them apart. Follows Confirmation
/// Sounds and Haptics in Settings. Requested directly (2026-10-06).
enum RefreshHeartbeat {
    static func during(_ work: () async -> Void) async {
        let ticker = Task { @MainActor in
            let started = Date()
            var spoke = false
            try? await Task.sleep(for: .milliseconds(1_500))
            while !Task.isCancelled {
                if UIAccessibility.isVoiceOverRunning {
                    SoundPlayer.shared.play(.refreshTick)
                    if !spoke, Date().timeIntervalSince(started) >= 8 {
                        UIAccessibility.post(notification: .announcement, argument: String(localized: "Still refreshing."))
                        spoke = true
                    }
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        await work()
        ticker.cancel()
    }
}
