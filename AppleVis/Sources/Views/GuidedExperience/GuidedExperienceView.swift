import SwiftUI

/// Step-by-step tour engine — ported from useGuidedExperienceRuntime.ts +
/// app/guided-experience/[experienceId].tsx, condensed into one SwiftUI view
/// since there's currently only one experience ("welcome") to run.
struct GuidedExperienceView: View {
    let experience: GuidedExperience
    var onFinish: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var keyCommands: KeyCommandRouter
    @EnvironmentObject private var pauseStore: GuidedExperiencePauseStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var stepIndex = 0
    @State private var showExplainMore = false
    @State private var showHelpArticle: HelpArticle?
    @AccessibilityFocusState private var isHeadingFocused: Bool
    @AccessibilityFocusState private var isExplainMoreFocused: Bool
    @State private var entranceVisible = false

    private var step: GuidedExperienceStep { experience.steps[stepIndex] }
    private var isFirstStep: Bool { stepIndex == 0 }
    private var isLastStep: Bool { stepIndex == experience.steps.count - 1 }

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
                        progressDots

                        Image(systemName: step.icon)
                            .font(.system(size: 34))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 72, height: 72)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityHidden(true)

                        VStack(spacing: 10) {
                            Text(step.title)
                                .font(.title2).fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityLabel(String(localized: "\(step.title). Step \(stepIndex + 1) of \(experience.steps.count)."))
                                .accessibilityFocused($isHeadingFocused)
                            Text(step.shortText)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)

                        if let explainMore = step.explainMoreText {
                            VStack(spacing: 8) {
                                if showExplainMore {
                                    Text(explainMore)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 24)
                                        .transition(.opacity)
                                        .accessibilityFocused($isExplainMoreFocused)
                                }
                                Button(showExplainMore ? "Show Less" : "Explain More") {
                                    withReduceMotionAwareAnimation { showExplainMore.toggle() }
                                    // Only on expand — VoiceOver otherwise stays on
                                    // this button and just re-announces its own
                                    // updated label ("Show Less"), never actually
                                    // reaching the explanation text it revealed.
                                    // Collapsing back has no equivalent problem:
                                    // staying on the button is exactly right there.
                                    // Reported directly.
                                    if showExplainMore {
                                        Task { await retryAccessibilityFocus(into: $isExplainMoreFocused) }
                                    }
                                }
                                .font(.subheadline)
                            }
                        }

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

    // MARK: - Progress

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<experience.steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == stepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == stepIndex ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Step \(stepIndex + 1) of \(experience.steps.count)"))
    }

    // MARK: - Per-step actions (secondary + primary + skip)

    private var stepActions: some View {
        VStack(spacing: 10) {
            ForEach(step.secondaryActions) { action in
                Button(action.label) { perform(action) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }

            Button("Continue") { goToStep(stepIndex + 1) }
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
        showExplainMore = false
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
        }
    }

    private func navigate(to target: GuidedExperienceScreenTarget) {
        switch target {
        case .home: keyCommands.selectedTab = 0
        case .discover: keyCommands.selectedTab = 1
        case .forYou: keyCommands.selectedTab = 2
        case .profile, .settings: keyCommands.showSettings = true
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
            showExplainMore = false
            playEntranceAnimation()
            focusHeadingAfterTransition()
        }
    }
}
