import SwiftUI
import UIKit

/// A once-a-year celebration sheet for the account's join-date anniversary
/// (see `AccountAnniversary`) — confetti + haptic + sound + a VoiceOver
/// description of the confetti itself, so the "fun" isn't only a visual
/// experience. `.success` stands in for a dedicated celebratory sound until
/// a real one is added to Resources/Sounds.
struct AnniversaryCelebrationView: View {
    let years: Int
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isHeadingFocused: Bool

    private let icon: String
    private let accentColor: Color
    private let heading: String
    private let message: String

    init(years: Int, onDone: @escaping () -> Void) {
        self.years = years
        self.onDone = onDone

        switch years {
        case 1:
            icon = "party.popper.fill"
            accentColor = Color(red: 0.976, green: 0.451, blue: 0.086) // orange
            heading = String(localized: "Happy First Anniversary!")
        case let y where y % 5 == 0:
            icon = "star.circle.fill"
            accentColor = Color(red: 0.961, green: 0.620, blue: 0.043) // amber
            heading = String(localized: "Happy \(y)-Year Anniversary!")
        default:
            icon = "birthday.cake.fill"
            accentColor = Color.accentColor
            heading = String(localized: "Happy Anniversary!")
        }

        let span = String(localized: "\(years) years")
        let templates = [
            String(localized: "\(span) ago today, you joined the AppleVis community. Thanks for being part of it!"),
            String(localized: "It's been \(span) since you joined AppleVis. Here's to many more!"),
            String(localized: "\(span) with AppleVis today. We're glad you're here!"),
        ]
        message = templates.randomElement() ?? templates[0]
    }

    /// Folds the confetti into the same text a VoiceOver user actually
    /// hears — a purely visual flourish would otherwise not exist for them
    /// at all, when the whole point is that everyone gets to feel it.
    private var accessibleDescription: String {
        String(localized: "\(heading) Colorful confetti is falling to celebrate. \(message)")
    }

    private var shareText: String {
        String(localized: "🎉 \(heading) I've been part of the AppleVis community for \(String(localized: "\(years) years"))!")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(accentColor)
                    .frame(width: 108, height: 108)
                    .background(accentColor.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(heading)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibleDescription)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isHeadingFocused)

                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button("Continue") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Spacer()
            }
            .padding(32)

            if !reduceMotion {
                ConfettiView()
            }
        }
        .task {
            SoundPlayer.shared.play(.success)
            UIAccessibility.post(notification: .announcement, argument: accessibleDescription)
            try? await Task.sleep(for: .milliseconds(350))
            isHeadingFocused = true
        }
    }
}

/// A short burst of falling, rotating colored shapes — purely decorative
/// (hidden from VoiceOver; fold its "meaning" into whatever spoken
/// description accompanies the moment it's used for, the way
/// `AnniversaryCelebrationView.accessibleDescription` does) and skipped
/// entirely under Reduce Motion rather than shown as a static freeze-frame.
/// Not private — reused for the Welcome Tour's finale (see
/// `GuidedExperienceView`), and any other one-time celebration moment.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let color: Color
        let xFraction: CGFloat
        let delay: Double
        let duration: Double
        let rotation: Double
        let size: CGFloat
    }

    private static let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    @State private var pieces: [Piece] = []
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.4)
                        .rotationEffect(.degrees(fallen ? piece.rotation : 0))
                        .position(x: piece.xFraction * geo.size.width, y: fallen ? geo.size.height + 40 : -40)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: fallen)
                }
            }
            .onAppear {
                pieces = (0..<36).map { _ in
                    Piece(
                        color: Self.palette.randomElement() ?? .orange,
                        xFraction: .random(in: 0...1),
                        delay: .random(in: 0...0.4),
                        duration: .random(in: 1.8...2.8),
                        rotation: .random(in: 180...720),
                        size: .random(in: 6...12)
                    )
                }
                // A beat after layout, not immediately — starting the
                // animation in the same run loop turn as setting `pieces`
                // is a common way for SwiftUI to miss the transition
                // entirely and just snap to the end state.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fallen = true }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
