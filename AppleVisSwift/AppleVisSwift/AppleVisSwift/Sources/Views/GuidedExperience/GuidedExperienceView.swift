import SwiftUI

/// Step-by-step tour engine — ported from useGuidedExperienceRuntime.ts +
/// app/guided-experience/[experienceId].tsx, condensed into one SwiftUI view
/// since there's currently only one experience ("welcome") to run.
struct GuidedExperienceView: View {
    let experience: GuidedExperience
    var onFinish: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0
    @State private var showExplainMore = false
    @State private var showHelpArticle: HelpArticle?

    private var step: GuidedExperienceStep { experience.steps[stepIndex] }
    private var isFirstStep: Bool { stepIndex == 0 }
    private var isLastStep: Bool { stepIndex == experience.steps.count - 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Step \(stepIndex + 1) of \(experience.steps.count)")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 8)

                    Image(systemName: step.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(step.title)
                            .font(.title2).fontWeight(.bold)
                            .multilineTextAlignment(.center)
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
                            }
                            Button(showExplainMore ? "Show Less" : "Explain More") {
                                withReduceMotionAwareAnimation { showExplainMore.toggle() }
                            }
                            .font(.subheadline)
                        }
                    }

                    if !step.secondaryActions.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(step.secondaryActions) { action in
                                Button(action.label) { perform(action) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    if isLastStep {
                        completionActions
                    }

                    Color.clear.frame(height: 20)
                }
                .padding()
            }
            .navigationTitle(experience.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        GuidedExperienceStore.markSkipped(experience.id)
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isLastStep {
                    navigationControls
                        .padding()
                        .background(.bar)
                }
            }
        }
        .onAppear {
            let progress = GuidedExperienceStore.getProgress(experience.id)
            if progress.dismissed {
                stepIndex = min(progress.lastStepIndex, experience.steps.count - 1)
            }
        }
        .sheet(item: $showHelpArticle) { article in
            NavigationStack { HelpArticleDetailView(article: article) }
        }
    }

    private var navigationControls: some View {
        HStack {
            Button("Back") { goToStep(stepIndex - 1) }
                .disabled(isFirstStep)
            Spacer()
            Button("Next") { goToStep(stepIndex + 1) }
                .buttonStyle(.borderedProminent)
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

    private func goToStep(_ index: Int) {
        let clamped = max(0, min(experience.steps.count - 1, index))
        stepIndex = clamped
        showExplainMore = false
        GuidedExperienceStore.markStep(experience.id, clamped)
    }

    private func perform(_ action: GuidedExperienceSecondaryAction) {
        switch action.kind {
        case .exploreScreen:
            GuidedExperienceStore.markDismissedForNow(experience.id, stepIndex)
            dismiss()
        case .learnMore(let helpArticleId):
            showHelpArticle = HelpContent.find(helpArticleId)
        }
    }

    private func perform(_ action: GuidedExperienceCompletionAction) {
        switch action.kind {
        case .finish:
            GuidedExperienceStore.markCompleted(experience.id)
            dismiss()
            onFinish?()
        case .openHelp:
            GuidedExperienceStore.markCompleted(experience.id)
            dismiss()
            onFinish?()
        case .replay:
            GuidedExperienceStore.restart(experience.id)
            stepIndex = 0
            showExplainMore = false
        }
    }
}
