import Foundation

/// Ported from src/services/guidedExperienceStore.ts.
enum GuidedExperienceStore {
    private static let keyPrefix = "applevis.guidedExperience."
    private static let autoPromptKey = "applevis.welcomeTourAutoPrompt"

    /// Whether the post-onboarding "Take a quick tour?" prompt should still
    /// offer to start the welcome tour automatically — separate from whether
    /// the tour itself has been completed/skipped. Ported from RN's
    /// src/services/tour.ts; defaults true until the user explicitly opts out.
    static var autoPromptEnabled: Bool {
        UserDefaults.standard.object(forKey: autoPromptKey) as? Bool ?? true
    }

    static func disableAutoPrompt() {
        UserDefaults.standard.set(false, forKey: autoPromptKey)
    }

    static func getProgress(_ experienceId: String) -> GuidedExperienceProgress {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + experienceId),
              let progress = try? JSONDecoder().decode(GuidedExperienceProgress.self, from: data) else {
            return GuidedExperienceProgress()
        }
        return progress
    }

    private static func save(_ experienceId: String, _ progress: GuidedExperienceProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: keyPrefix + experienceId)
    }

    static func markStep(_ experienceId: String, _ stepIndex: Int) {
        var progress = getProgress(experienceId)
        progress.lastStepIndex = stepIndex
        save(experienceId, progress)
    }

    static func markCompleted(_ experienceId: String) {
        var progress = getProgress(experienceId)
        progress.completed = true
        progress.dismissed = false
        progress.lastStepIndex = 0
        save(experienceId, progress)
    }

    static func markSkipped(_ experienceId: String) {
        var progress = getProgress(experienceId)
        progress.skipped = true
        save(experienceId, progress)
    }

    /// Called when the user pauses via "Explore This Screen" without finishing or skipping.
    static func markDismissedForNow(_ experienceId: String, _ stepIndex: Int) {
        var progress = getProgress(experienceId)
        progress.dismissed = true
        progress.lastStepIndex = stepIndex
        save(experienceId, progress)
    }

    /// Resets progress so the experience starts from step 0 again (Replay).
    static func restart(_ experienceId: String) {
        var progress = getProgress(experienceId)
        progress.completed = false
        progress.skipped = false
        progress.dismissed = false
        progress.lastStepIndex = 0
        progress.replayCount += 1
        save(experienceId, progress)
    }
}
