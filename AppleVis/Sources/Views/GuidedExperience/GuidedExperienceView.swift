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
    @AccessibilityFocusState private var isHeadingFocused: Bool
    @State private var entranceVisible = false
    @State private var showLeaveConfirm = false

    private var step: GuidedExperienceStep { experience.steps[stepIndex] }
    /// Resolved once so TextSegmentation.sentenceGroups chunks the actual
    /// localized text, not the raw English source.
    private var localizedBody: String { String(localized: String.LocalizationValue(step.body)) }
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
                            // `step.chapterTitle`/`.title`/`.body` are all
                            // String values, not string literals — Text(_
                            // content: String) skips catalog lookup entirely,
                            // same bug already fixed elsewhere in this app.
                            // All 28 step titles and bodies already have full
                            // translations sitting in the catalog — they were
                            // just never reachable through these three Text
                            // calls. `.uppercased()` was also mutating the
                            // string itself (breaking the catalog key) rather
                            // than just the display, hence the switch to
                            // .textCase(.uppercase).
                            Text(LocalizedStringKey(step.chapterTitle))
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .accessibilityHidden(true)
                            progressDots
                        }

                        stepIcon

                        VStack(spacing: 10) {
                            Text(LocalizedStringKey(step.title))
                                .font(.title2).fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                                // A chapter with just one step (Welcome,
                                // All Set) always announces "step 1 of 1" —
                                // trivially true and uninformative, unlike
                                // Home/Discover/For You/Profile & Settings
                                // where the count actually helps. Dropped
                                // for those two only. Requested directly.
                                .accessibilityLabel(chapterProgress.total > 1
                                    ? String(localized: "\(step.title). \(step.chapterTitle), step \(chapterProgress.index) of \(chapterProgress.total).")
                                    : String(localized: "\(step.title). \(step.chapterTitle).")
                                )
                                .accessibilityFocused($isHeadingFocused)
                            // Every step.body is one long unbroken block of
                            // prose with no \n\n structure to split on — read
                            // (or Braille-panned) as a single giant element,
                            // the same problem already fixed for forum
                            // topics, blog posts, and podcast show notes via
                            // TextSegmentation.sentenceGroups. More swipes,
                            // but each stop is now a size you can actually
                            // pause on, re-read, or skip past, instead of one
                            // continuous wall of speech. Localizing first,
                            // then chunking — chunking the raw English source
                            // would produce fragments that don't match any
                            // catalog key. Requested directly.
                            VStack(spacing: 12) {
                                ForEach(Array(TextSegmentation.sentenceGroups(localizedBody).enumerated()), id: \.offset) { _, chunk in
                                    Text(chunk)
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
            .navigationTitle(LocalizedStringKey(experience.title))
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
                // Same verbatim-String bug as chapterTitle/title/body above.
                Button(LocalizedStringKey(action.label)) { perform(action) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(secondaryActionHint(action.kind))
            }

            // Same verbatim-String bug as chapterTitle/title/body above —
            // "Continue to Discover" etc. are already fully translated but
            // were never reaching the catalog through this call.
            Button(LocalizedStringKey(step.continueLabel ?? "Continue")) { goToStep(stepIndex + 1) }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .controlSize(.large)

            // Was "Skip Tour", jumping straight to markSkipped — the only
            // way out from any of the 25 non-checkpoint steps, even though
            // most people who leave mid-tour want to come back to it, not
            // reset it. "Pause Tour" already existed as this exact
            // resumable behavior, but only as a secondary action on the 3
            // chapter-checkpoint steps. Now offered from every step via this
            // choice, with the old reset-everything behavior still
            // available for anyone who really is done. Requested directly.
            Button("Leave Tour") { showLeaveConfirm = true }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHint(String(localized: "Choose to pause and resume later, or skip the tour completely."))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .confirmationDialog(
            "Leave the tour?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Pause — Resume Later") { pauseTour() }
            Button("Skip Tour Completely", role: .destructive) { skip() }
            Button("Continue Tour", role: .cancel) {}
        } message: {
            Text("Pausing brings you right back to this exact step whenever you're ready. Skipping resets your progress.")
        }
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
        }
    }

    private var completionActions: some View {
        VStack(spacing: 10) {
            ForEach(experience.completionActions) { action in
                // Same verbatim-String bug as chapterTitle/title/body above.
                if action.kind == .finish {
                    Button(LocalizedStringKey(action.label)) { perform(action) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Button(LocalizedStringKey(action.label)) { perform(action) }
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
        UIAccessibility.post(notification: .announcement, argument: String(localized: "\(experience.title) skipped."))
        dismiss()
    }

    /// Backs "Leave Tour" > "Pause — Resume Later" — the resumable pause
    /// that used to only exist as a secondary action on the 3 chapter
    /// checkpoints (now removed there as redundant) is available from every
    /// step through this single dialog instead.
    private func pauseTour() {
        GuidedExperienceStore.markDismissedForNow(experience.id, stepIndex)
        pauseStore.pauseForExplore(experienceId: experience.id, experienceTitle: experience.title, stepIndex: stepIndex)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Tour paused. Resume anytime from the Resume Tour button."))
        dismiss()
    }

    private func perform(_ action: GuidedExperienceSecondaryAction) {
        switch action.kind {
        case .exploreScreen(let target):
            GuidedExperienceStore.markDismissedForNow(experience.id, stepIndex)
            pauseStore.pauseForExplore(experienceId: experience.id, experienceTitle: experience.title, stepIndex: stepIndex)
            dismiss()
            navigate(to: target)
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
            UIAccessibility.post(notification: .announcement, argument: String(localized: "\(experience.title) restarted."))
            stepIndex = 0
            playEntranceAnimation()
            focusHeadingAfterTransition()
        }
    }
}
