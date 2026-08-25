import SwiftUI

/// Small floating affordance shown app-wide while a guided experience is
/// paused for "Explore This Screen." Ported from RN's
/// GuidedExperienceResumePrompt.tsx, which mounted once near the root layout.
///
/// Takes `pauseStore` as an explicit @ObservedObject rather than
/// @EnvironmentObject: like TipOverlay, this is mounted via `.overlay { }`
/// directly at the App/Scene level rather than nested as a normal
/// ContentView descendant, and environment-object lookup through that
/// specific path crashes at runtime ("No ObservableObject of type
/// GuidedExperiencePauseStore found") on the iOS 26 SDK this targets.
struct GuidedExperienceResumeBanner: View {
    @ObservedObject var pauseStore: GuidedExperiencePauseStore
    /// Explicit `@ObservedObject` parameter, not `@EnvironmentObject` — this
    /// view is mounted via `.overlay {}` directly on the WindowGroup root
    /// (AppleVisApp.swift), where `@EnvironmentObject` doesn't reliably
    /// resolve on this SDK and crashes at launch. Same reasoning as
    /// `pauseStore` above.
    @ObservedObject var preferences: PreferencesStore
    /// Same reasoning as `pauseStore`/`preferences` — needed to pass down
    /// to the "Resume Tour" sheet below, not read directly by this view's
    /// own body.
    @ObservedObject var keyCommands: KeyCommandRouter
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
                    .accessibilityLabel(String(localized: "Resume Tour: \(paused.experienceTitle)"))
                    .accessibilityHint(String(localized: "Returns to the guided tour where you left off."))

                    Button {
                        pauseStore.clearPaused()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .padding(8)
                    }
                    .accessibilityLabel(String(localized: "Dismiss Tour"))
                    .accessibilityHint(String(localized: "Dismisses this reminder without resuming the tour. You can still replay it later from Profile."))
                }
                .foregroundStyle(preferences.colors.accentText)
                .background(Color.accentColor, in: Capsule())
                .shadow(radius: 10, y: 4)
                .padding(.bottom, 76)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(duration: 0.3), value: pauseStore.paused?.experienceId)
        .sheet(isPresented: $showTour) {
            // GuidedExperienceView itself relies on @EnvironmentObject for
            // all three of these — inherited from wherever it's presented.
            // Presenting it from here (this banner, itself mounted at the
            // same problematic App-root `.overlay {}` position described
            // above) means none of them resolve from the environment on
            // their own; this is the exact same crash, just one call site
            // further down, and previously unfixed here. Reported directly:
            // "Explore This Screen" on the Home step, then "Resume Tour,"
            // crashed every time, including after a fresh relaunch — a
            // fully deterministic environment-object crash, not corrupted
            // saved progress.
            GuidedExperienceView(experience: GuidedExperienceRegistry.welcome)
                .environmentObject(pauseStore)
                .environmentObject(preferences)
                .environmentObject(keyCommands)
        }
    }
}
