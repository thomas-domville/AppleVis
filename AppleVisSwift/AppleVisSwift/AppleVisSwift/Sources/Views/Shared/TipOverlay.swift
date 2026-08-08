import SwiftUI

/// The "AppleVis Tip" popover card, driven by `TipStore.activeTip`.
///
/// Takes `tips` as an explicit @ObservedObject rather than @EnvironmentObject:
/// this is the one view attached via `.overlay { }` directly at the App/Scene
/// level (AppleVisApp.swift) rather than nested as a normal ContentView
/// descendant, and environment-object lookup through that specific path
/// crashes at runtime ("No ObservableObject of type TipStore found") on the
/// iOS 26 SDK this targets — passing it explicitly sidesteps the question
/// entirely.
struct TipOverlay: View {
    @ObservedObject var tips: TipStore

    var body: some View {
        ZStack {
            if let tip = tips.activeTip {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .onTapGesture { tips.dismissActiveTip() }

                TipCard(tip: tip) { tips.dismissActiveTip() }
                    .padding(.horizontal, 28)
                    .transition(UIAccessibility.isReduceMotionEnabled ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(duration: 0.25), value: tips.activeTip?.id)
    }
}

private struct TipCard: View {
    let tip: TipStore.ActiveTip
    let onDismiss: () -> Void
    @AccessibilityFocusState private var isTitleFocused: Bool

    /// RN hardcoded the "AppleVis Tip" badge/button to this exact blue
    /// regardless of the active theme, so the tip keeps a consistent,
    /// recognizable brand identity even under themes with a very different
    /// accent (e.g. red, yellow, orange) — tying it to `Color.accentColor`
    /// made its look shift with every theme.
    private static let brandColor = Color(red: 0.039, green: 0.518, blue: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Self.brandColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: tip.content.icon)
                        .foregroundStyle(Self.brandColor)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text("AppleVis Tip")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .foregroundStyle(Self.brandColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "AppleVis Tip"))

            Text(tip.content.title)
                .font(.title3)
                .fontWeight(.bold)
                .accessibilityLabel("AppleVis Tip. \(tip.content.title). \(tip.content.message)")
                .accessibilityFocused($isTitleFocused)

            Text(tip.content.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Button("Got it", action: onDismiss)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .buttonStyle(.glassProminent)
                .tint(Self.brandColor)
                .accessibilityHint(String(localized: "Dismisses this tip. It will not appear again."))
        }
        .padding(22)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
        .shadow(radius: 24, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDismiss)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            isTitleFocused = true
        }
    }
}
