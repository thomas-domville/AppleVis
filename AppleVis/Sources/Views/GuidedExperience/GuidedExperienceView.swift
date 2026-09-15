import SwiftUI

/// Step-by-step tour engine — ported from useGuidedExperienceRuntime.ts +
/// app/guided-experience/[experienceId].tsx, condensed into one SwiftUI view
/// since there's currently only one experience ("welcome") to run.
struct GuidedExperienceView: View {
    let experience: GuidedExperience
    var onFinish: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @EnvironmentObject private var pauseStore: GuidedExperiencePauseStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var stepIndex = 0
    @State private var showHelpArticle: HelpArticle?
    @AccessibilityFocusState private var isHeadingFocused: Bool
    @State private var entranceVisible = false

    private var step: GuidedExperienceStep { experience.steps[stepIndex] }
    private var isFirstStep: Bool { stepIndex == 0 }
    private var isLastStep: Bool { stepIndex == experience.steps.count - 1 }
    /// Every chapter-closing checkpoint sets a custom `continueLabel`
    /// ("Continue to Discover" etc.) — reusing that as the "is this a
    /// milestone step" signal instead of a second boolean that could drift
    /// out of sync with it.
    private var isCheckpoint: Bool { step.continueLabel != nil }

    /// This step's position within its own chapter, not the whole
    /// experience — e.g. "3 of 8" for Home's third step, regardless of how
    /// many steps came before it in Welcome/Discover/etc. Chapters are
    /// contiguous runs of matching `chapterTitle`, so a single forward scan
    /// finds both the current step's index within its run and the run's
    /// total length.
    private var chapterProgress: (index: Int, total: Int) {
        let title = step.chapterTitle
        var start = stepIndex
        while start > 0, experience.steps[start - 1].chapterTitle == title { start -= 1 }
        var end = stepIndex
        while end < experience.steps.count - 1, experience.steps[end + 1].chapterTitle == title { end += 1 }
        return (stepIndex - start + 1, end - start + 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !isFirstStep {
                        Button {
                            goToStep(stepIndex - 1)
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                        .padding(.bottom, 4)
                    }

                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(step.chapterTitle.uppercased())
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            progressDots
                        }

                        stepIcon

                        VStack(spacing: 10) {
                            Text(step.title)
                                .font(.title2).fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityLabel(String(
                                    localized: "\(step.title). \(step.chapterTitle), step \(chapterProgress.index) of \(chapterProgress.total)."
                                ))
                                .accessibilityFocused($isHeadingFocused)
                            Text(step.body)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)

                        if isLastStep {
                            completionActions
                        } else {
                            stepActions
                        }

                        Color.clear.frame(height: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(entranceVisible ? 1 : 0)
                    .offset(y: entranceVisible ? 0 : 10)
                }
                .padding()
            }
            .background(preferences.colors.background)
            .navigationTitle(experience.title)
            .navigationBarTitleDisplayMode(.inline)
            // Reserved for the tour's true finale, not every chapter
            // checkpoint — three confetti bursts back to back (one per
            // checkpoint) would cheapen it fast. ConfettiView already
            // hides itself from VoiceOver and disables hit testing on its
            // own; `reduceMotion` here is still needed since, unlike the
            // symbol effect above, it's hand-built rather than a system
            // effect that backs off automatically.
            .overlay {
                if isLastStep && !reduceMotion {
                    ConfettiView()
                }
            }
        }
        .onAppear {
            let progress = GuidedExperienceStore.getProgress(experience.id)
            if progress.dismissed {
                // Matches goToStep's own clamp below — nothing currently
                // persists a negative lastStepIndex, but this was the one
                // place in the file reading a saved index back without the
                // same floor, and `experience.steps[stepIndex]` has no
                // bounds check of its own.
                stepIndex = max(0, min(progress.lastStepIndex, experience.steps.count - 1))
            }
            playEntranceAnimation()
            focusHeadingAfterTransition()
        }
        .sheet(item: $showHelpArticle) { article in
            NavigationStack { HelpArticleDetailView(article: article) }
        }
    }

    // MARK: - Icon

    /// The `.symbolEffect` is only attached for checkpoint steps — applying
    /// it unconditionally would replay a bounce on every plain content step
    /// too, which is exactly the "flourish on every step" busyness worth
    /// avoiding. System symbol effects respect Reduce Motion on their own.
    @ViewBuilder private var stepIcon: some View {
        let base = Image(systemName: step.icon)
            .font(.system(size: 34))
            .foregroundStyle(Color.accentColor)
            .frame(width: 72, height: 72)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityHidden(true)
        if isCheckpoint {
            base.symbolEffect(.bounce, value: stepIndex)
        } else {
            base
        }
    }

    // MARK: - Progress

    /// Dots for the current chapter only (e.g. Home's own 8), not the whole
    /// experience — the entire point of chaptering the tour was to stop
    /// "Step 11 of 28" from being the number anyone sees.
    private var progressDots: some View {
        let progress = chapterProgress
        return HStack(spacing: 8) {
            ForEach(1...progress.total, id: \.self) { i in
                Capsule()
                    .fill(i == progress.index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == progress.index ? 22 : 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Per-step actions (secondary + primary + skip)

    private var stepActions: some View {
        VStack(spacing: 10) {
            ForEach(step.secondaryActions) { action in
                Button(action.label) { perform(action) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(secondaryActionHint(action.kind))
            }

            Button(step.continueLabel ?? String(localized: "Continue")) { goToStep(stepIndex + 1) }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .controlSize(.large)

            Button("Skip Tour") { skip() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHint(String(localized: "Exits the tour. You can replay it any time from Profile."))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    /// Neither action navigates away from what the button's own label
    /// already says plainly — this hint exists purely to answer the
    /// question a beta tester's confusion raised: "if I leave, can I get
    /// back?" Told upfront, before tapping, not left to be discovered (or
    /// not) afterward.
    private func secondaryActionHint(_ kind: GuidedExperienceSecondaryActionKind) -> String {
        switch kind {
        case .exploreScreen:
            return String(localized: "Leaves the tour to show you this screen for real. A Resume Tour button brings you right back to this exact step.")
        case .pauseHere:
            return String(localized: "Stops the tour here for now. A Resume Tour button brings you right back to this exact step whenever you're ready.")
        case .learnMore:
            return String(localized: "Opens the full Help article in a new screen.")
        }
    }

    private var completionActions: some View {
        VStack(spacing: 10) {
            ForEach(experience.completionActions) { action in
                if action.kind == .finish {
                    Button(action.label) { perform(action) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Button(action.label) { perform(action) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Navigation

    private func goToStep(_ index: Int) {
        let clamped = max(0, min(experience.steps.count - 1, index))
        SoundPlayer.shared.play(.pickerTick)
        stepIndex = clamped
        GuidedExperienceStore.markStep(experience.id, clamped)
        playEntranceAnimation()
        focusHeadingAfterTransition()
    }

    /// Fade + slight upward translate on step change, matching RN's
    /// entrance animation — skipped entirely (final state applied instantly)
    /// under Reduce Motion.
    private func playEntranceAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            entranceVisible = true
            return
        }
        entranceVisible = false
        withAnimation(.easeOut(duration: 0.3)) {
            entranceVisible = true
        }
    }

    /// Was a single guessed 350ms delay — see SubmitAppView's identical fix
    /// (same pattern, independently copy-pasted here too) for the full
    /// reasoning. Step 1's own initial focus already worked correctly here
    /// (called from `.onAppear` above) — only the retry logic itself needed
    /// fixing. Full app-wide focus audit, requested directly.
    private func focusHeadingAfterTransition() {
        Task { await retryAccessibilityFocus(into: $isHeadingFocused) }
    }

    private func skip() {
        GuidedExperienceStore.markSkipped(experience.id)
        pauseStore.clearPaused()
        UIAccessibility.post(notification: .announcement, argument: "\(experience.title) skipped.")
        dismiss()
    }

    private func perform(_ action: GuidedExperienceSecondaryAction) {
        switch action.kind {
        case .exploreScreen(let target):
            GuidedExperienceStore.markDismissedForNow(experience.id, stepIndex)
            pauseStore.pauseForExplore(experienceId: experience.id, experienceTitle: experience.title, stepIndex: stepIndex)
            dismiss()
            navigate(to: target)
        case .learnMore(let helpArticleId):
            showHelpArticle = HelpContent.find(helpArticleId)
        case .pauseHere:
            GuidedExperienceStore.markDismissedForNow(experience.id, stepIndex)
            pauseStore.pauseForExplore(experienceId: experience.id, experienceTitle: experience.title, stepIndex: stepIndex)
            UIAccessibility.post(notification: .announcement, argument: "Tour paused. Resume anytime from the Resume Tour button.")
            dismiss()
        }
    }

    private func navigate(to target: GuidedExperienceScreenTarget) {
        switch target {
        case .home: keyCommands.selectedTab = 0
        case .discover: keyCommands.selectedTab = 1
        case .forYou: keyCommands.selectedTab = 2
        case .profile: keyCommands.showSettings = true
        }
    }

    private func perform(_ action: GuidedExperienceCompletionAction) {
        switch action.kind {
        case .finish:
            GuidedExperienceStore.markCompleted(experience.id)
            pauseStore.clearPaused()
            dismiss()
            onFinish?()
        case .openHelp:
            GuidedExperienceStore.markCompleted(experience.id)
            pauseStore.clearPaused()
            dismiss()
            onFinish?()
        case .replay:
            GuidedExperienceStore.restart(experience.id)
            UIAccessibility.post(notification: .announcement, argument: "\(experience.title) restarted.")
            stepIndex = 0
            playEntranceAnimation()
            focusHeadingAfterTransition()
        }
    }
}
