import Foundation
import Combine

/// Tracks at most one "paused mid-tour" guided experience at a time, so the
/// Resume Tour banner can be shown from anywhere in the app while the user
/// explores a screen the tour pointed them at. Ported from RN's
/// GuidedExperienceContext.tsx — Swift previously had the underlying
/// dismissed/lastStepIndex progress persisted but nothing surfaced it.
@MainActor
final class GuidedExperiencePauseStore: ObservableObject {
    struct Paused {
        let experienceId: String
        let experienceTitle: String
        let stepIndex: Int
    }

    @Published private(set) var paused: Paused?

    /// Restores the Resume Tour banner on launch if the app was closed while
    /// a guided experience was paused for Explore This Screen — the in-memory
    /// `paused` above doesn't survive a restart, but the persisted
    /// dismissed/lastStepIndex progress does.
    init() {
        let experience = GuidedExperienceRegistry.welcome
        let progress = GuidedExperienceStore.getProgress(experience.id)
        if progress.dismissed, !progress.completed, !progress.skipped {
            paused = Paused(experienceId: experience.id, experienceTitle: experience.title, stepIndex: progress.lastStepIndex)
        }
    }

    func pauseForExplore(experienceId: String, experienceTitle: String, stepIndex: Int) {
        paused = Paused(experienceId: experienceId, experienceTitle: experienceTitle, stepIndex: stepIndex)
    }

    func clearPaused() {
        paused = nil
    }
}
