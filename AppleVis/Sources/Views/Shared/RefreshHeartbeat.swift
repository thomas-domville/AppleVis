import SwiftUI
import UIKit

/// While a refresh is still loading, VoiceOver users hear a soft tick and
/// feel a light tap every second, so they know it's still working on a
/// slow connection. It starts only after a second and a half, so a quick
/// refresh just gives the usual sound. After 8 seconds, VoiceOver says
/// "Still refreshing." once. Same idea as Ask the Mouse's patter, with its
/// own quieter sound so you can tell them apart. Follows Confirmation
/// Sounds and Haptics in Settings. Requested directly (2026-10-06).
///
/// The same tick plays while a page is loading (LoadingView), so "tick"
/// always means "waiting on AppleVis" (2026-10-07).
enum RefreshHeartbeat {
    static func during(_ work: () async -> Void) async {
        let ticker = Task { @MainActor in
            await tick(stillWaiting: String(localized: "Still refreshing."))
        }
        await work()
        ticker.cancel()
    }

    /// Ticks until the calling task is cancelled: nothing for the first
    /// second and a half, then a tick and tap every second with VoiceOver
    /// on, and `stillWaiting` spoken once at 8 seconds.
    /// `every`: one second normally; longer for a slow, once-only job such
    /// as downloading a translation language, so it doesn't wear on you.
    @MainActor
    static func tick(stillWaiting: String, every interval: Duration = .seconds(1)) async {
        let started = Date()
        var spoke = false
        try? await Task.sleep(for: .milliseconds(1_500))
        while !Task.isCancelled {
            if UIAccessibility.isVoiceOverRunning {
                SoundPlayer.shared.play(.refreshTick)
                if !spoke, Date().timeIntervalSince(started) >= 8 {
                    UIAccessibility.post(notification: .announcement, argument: stillWaiting)
                    spoke = true
                }
            }
            try? await Task.sleep(for: interval)
        }
    }
}

extension View {
    /// While `isWaiting` (posting, sending, saving), VoiceOver users hear
    /// the same tick and tap as a refresh after the first second and a
    /// half, and `stillWaiting` once at 8 seconds. Stops by itself when the
    /// wait ends or the screen closes (2026-10-07).
    func waitingTick(while isWaiting: Bool, stillWaiting: String, every interval: Duration = .seconds(1)) -> some View {
        task(id: isWaiting) {
            guard isWaiting else { return }
            await RefreshHeartbeat.tick(stillWaiting: stillWaiting, every: interval)
        }
    }
}

/// A long admin job's progress line (scans, Bulk Refresh, bulk delete):
/// the same tick and tap as a refresh each time the count moves on, at most
/// once every second and a half, so a fast batch doesn't turn into a
/// buzz. VoiceOver re-reads these lines itself as they change; the tick
/// tells you it's still moving even between readings. VoiceOver only.
/// Requested directly (2026-10-07).
private struct ProgressTickModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @State private var lastTick = Date.distantPast

    func body(content: Content) -> some View {
        content.onChange(of: value) { _, _ in
            guard UIAccessibility.isVoiceOverRunning, Date().timeIntervalSince(lastTick) >= 1.5 else { return }
            lastTick = Date()
            SoundPlayer.shared.play(.refreshTick)
        }
    }
}

extension View {
    func progressTick<Value: Equatable>(on value: Value) -> some View {
        modifier(ProgressTickModifier(value: value))
    }
}
