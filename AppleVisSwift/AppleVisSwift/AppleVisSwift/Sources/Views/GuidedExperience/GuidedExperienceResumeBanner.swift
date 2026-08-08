import SwiftUI

/// Small floating affordance shown app-wide while a guided experience is
/// paused for "Explore This Screen." Ported from RN's
/// GuidedExperienceResumePrompt.tsx, which mounted once near the root layout.
struct GuidedExperienceResumeBanner: View {
    @EnvironmentObject private var pauseStore: GuidedExperiencePauseStore
    @State private var showTour = false

    var body: some View {
        VStack {
            Spacer()
            if let paused = pauseStore.paused {
                HStack(spacing: 2) {
                    Button {
                        showTour = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                            Text("Resume Tour").fontWeight(.bold)
                        }
                        .padding(.leading, 10).padding(.vertical, 4)
                    }
                    .accessibilityLabel("Resume Tour: \(paused.experienceTitle)")
                    .accessibilityHint("Returns to the guided tour where you left off.")

                    Button {
                        pauseStore.clearPaused()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .padding(8)
                    }
                    .accessibilityLabel("Dismiss Resume Tour")
                }
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Capsule())
                .shadow(radius: 10, y: 4)
                .padding(.bottom, 76)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(duration: 0.3), value: pauseStore.paused?.experienceId)
        .sheet(isPresented: $showTour) {
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
        }
    }
}
