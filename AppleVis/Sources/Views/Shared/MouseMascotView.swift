import SwiftUI

// MARK: - Shared drawing style

/// The look both characters share: a big head on a small body, big round
/// eyes with two sparkles, rosy cheeks, soft round shapes, and one dark
/// outline so they read clearly in every theme, light or dark. The aim,
/// requested directly, is "oh, that's so cute" — while staying clearly
/// AppleVis's own characters (no gloves, shorts, or big shoes; no Apple logo).
private enum CharacterStyle {
    static let ink = Color(white: 0.16)
    static let pink = Color(red: 0.97, green: 0.62, blue: 0.71)
    static let blush = Color(red: 0.98, green: 0.55, blue: 0.62)

    static func lineWidth(_ size: CGFloat, _ contrast: ColorSchemeContrast) -> CGFloat {
        max(1.5, size * (contrast == .increased ? 0.032 : 0.02))
    }
}

/// An outlined ellipse placed at a point: the building block of both drawings.
private struct Blob: View {
    let fill: Color
    let width: CGFloat
    let height: CGFloat
    let at: CGPoint
    var line: CGFloat = 0
    var rotation: Double = 0

    var body: some View {
        Ellipse()
            .fill(fill)
            .overlay { if line > 0 { Ellipse().stroke(CharacterStyle.ink, lineWidth: line) } }
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .position(at)
    }
}

/// A big dark eye with two white sparkles; squashes flat to blink.
private struct SparklyEye: View {
    let width: CGFloat
    let height: CGFloat
    let at: CGPoint
    let isBlinking: Bool

    var body: some View {
        ZStack {
            Ellipse().fill(CharacterStyle.ink)
            Circle().fill(.white).frame(width: width * 0.42).offset(x: width * 0.14, y: -height * 0.2)
            Circle().fill(.white).frame(width: width * 0.2).offset(x: -width * 0.16, y: height * 0.2)
        }
        .frame(width: width, height: height)
        .scaleEffect(x: 1, y: isBlinking ? 0.1 : 1)
        .position(at)
    }
}

/// Hidden from VoiceOver unless a description is given.
private struct CharacterAccessibility: ViewModifier {
    let description: String?

    func body(content: Content) -> some View {
        if let description {
            content
                .accessibilityElement()
                .accessibilityLabel(description)
                .accessibilityAddTraits(.isImage)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

/// Characters hide at the largest accessibility text sizes so the words get
/// the room; a description, if any, is still spoken.
private struct HiddenAtLargeText<Content: View>: View {
    let hides: Bool
    let description: String?
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if hides && dynamicTypeSize.isAccessibilitySize {
            if let description {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(description)
                    .accessibilityAddTraits(.isImage)
            }
        } else {
            content()
        }
    }
}

/// An occasional blink, shared by both characters. Off with Reduce Motion.
private func blinkLoop(_ isBlinking: Binding<Bool>) async {
    while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 3200...5200)))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.08)) { isBlinking.wrappedValue = true }
        try? await Task.sleep(for: .milliseconds(130))
        withAnimation(.easeInOut(duration: 0.08)) { isBlinking.wrappedValue = false }
    }
}

/// A happy little hop whenever `trigger` changes — the Setup sound step
/// uses it when a character's own sound is previewed. Off with Reduce Motion.
struct CharacterHop: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .offset(y: lifted ? -8 : 0)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { lifted = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { lifted = false }
                }
            }
    }
}

// MARK: - The Mouse

/// What the Mouse is holding. The full figure holds its prop up in one paw;
/// `.waving` holds nothing and waves instead.
enum MousePose: Hashable {
    case waving        // Welcome Tour: Welcome; Setup welcome
    case reading       // Home, Mouse Recap
    case searching     // Discover
    case bookmarking   // For You, Saved
    case following     // Following
    case recommending  // Recommended
    case listening     // Downloads
    case tinkering     // Profile & Settings
    case celebrating   // All Set
    case asking        // Ask the Mouse
    /// Any prop, by SF Symbol name: Ask the Mouse changes it with each
    /// search step (a book for Help, a newspaper for guides, and so on).
    case holding(String)
    case plain

    var prop: String? {
        switch self {
        case .waving, .plain: return nil
        case .reading:        return "newspaper.fill"
        case .searching:      return "magnifyingglass"
        case .bookmarking:    return "bookmark.fill"
        case .following:      return "bell.fill"
        case .recommending:   return "hand.thumbsup.fill"
        case .listening:      return "headphones"
        case .tinkering:      return "wrench.adjustable.fill"
        case .celebrating:    return "party.popper.fill"
        case .asking:         return "questionmark.bubble.fill"
        case .holding(let symbol): return symbol
        }
    }

    /// The Welcome Tour's poses, one per chapter.
    static func forTourChapter(_ chapter: String) -> MousePose {
        switch chapter {
        case "Welcome":            return .waving
        case "Home":               return .reading
        case "Discover":           return .searching
        case "For You":            return .bookmarking
        case "Profile & Settings": return .tinkering
        case "All Set":            return .celebrating
        default:                   return .plain
        }
    }
}

/// The Mouse: narrator of the Welcome Tour ("I'm the Mouse") and namesake of
/// Mouse Recap. Drawn in code, so it scales cleanly and needs no image
/// assets. A standing full figure wherever there's room — waving, or holding
/// the pose's prop up in one paw — and just the face where it's tiny.
/// Requested directly (2026-09-25): cute, full figure, clearly its own mouse
/// (pink ears, a long curly tail, a little scarf; no gloves, shorts, or
/// shoes).
///
/// Accessibility: decorative and hidden from VoiceOver unless
/// `accessibilityDescription` is given; motion only with Reduce Motion off;
/// a thicker outline with Increase Contrast; hidden at the largest text sizes.
struct MouseMascotView: View {
    enum Style { case fullFigure, face }

    let pose: MousePose
    var size: CGFloat = 72
    var style: Style = .fullFigure
    var accessibilityDescription: String? = nil
    var hidesAtAccessibilityTextSizes = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var isBlinking = false
    @State private var propBounce = 0
    @State private var armAngle: Double = 30

    private let fur = Color(red: 0.78, green: 0.72, blue: 0.68)
    private let furDark = Color(red: 0.62, green: 0.55, blue: 0.51)
    private let belly = Color(red: 0.95, green: 0.91, blue: 0.87)
    private var line: CGFloat { CharacterStyle.lineWidth(size, contrast) }

    var body: some View {
        HiddenAtLargeText(hides: hidesAtAccessibilityTextSizes, description: accessibilityDescription) {
            Group {
                switch style {
                case .fullFigure: fullFigure
                case .face:
                    ZStack {
                        head(center: CGPoint(x: 0.5 * size, y: 0.56 * size), diameter: 0.72 * size)
                        // The face shows its pose's prop as a little badge,
                        // so it can say what the Mouse is doing too.
                        // Requested directly (2026-09-29).
                        if let prop = pose.prop, size >= 28 {
                            Image(systemName: prop)
                                .font(.system(size: 0.24 * size, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 0.4 * size, height: 0.4 * size)
                                .background(Circle().fill(Color(.systemBackground)))
                                .overlay(Circle().stroke(CharacterStyle.ink.opacity(0.35), lineWidth: max(1, line * 0.6)))
                                .symbolEffect(.bounce, value: propBounce)
                                .position(x: 0.84 * size, y: 0.84 * size)
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .modifier(CharacterAccessibility(description: accessibilityDescription))
            .task(id: pose) { await animate() }
        }
    }

    // MARK: Full figure

    private var fullFigure: some View {
        let s = size
        return ZStack {
            // Long, thin tail with a curl, behind everything.
            Tail()
                .stroke(furDark, style: StrokeStyle(lineWidth: max(1.5, s * 0.03), lineCap: .round))
                .frame(width: s, height: s)

            // Feet, body, and belly.
            Blob(fill: CharacterStyle.pink, width: 0.14 * s, height: 0.07 * s, at: CGPoint(x: 0.42 * s, y: 0.95 * s), line: line)
            Blob(fill: CharacterStyle.pink, width: 0.14 * s, height: 0.07 * s, at: CGPoint(x: 0.58 * s, y: 0.95 * s), line: line)
            Blob(fill: fur, width: 0.38 * s, height: 0.34 * s, at: CGPoint(x: 0.5 * s, y: 0.77 * s), line: line)
            Blob(fill: belly, width: 0.22 * s, height: 0.2 * s, at: CGPoint(x: 0.5 * s, y: 0.8 * s))

            // Resting arm, with a little pink paw.
            Blob(fill: fur, width: 0.08 * s, height: 0.18 * s, at: CGPoint(x: 0.33 * s, y: 0.76 * s), line: line, rotation: 18)
            Blob(fill: CharacterStyle.pink, width: 0.08 * s, height: 0.08 * s, at: CGPoint(x: 0.3 * s, y: 0.84 * s), line: line)

            // Raised arm: waves, or holds up the pose's prop.
            raisedArm
                .frame(width: 0.14 * s, height: 0.3 * s)
                .rotationEffect(.degrees(armAngle), anchor: .bottom)
                .position(x: 0.64 * s, y: 0.66 * s - 0.15 * s)

            // A little scarf in the app's accent color: the Mouse's signature.
            Capsule()
                .fill(Color.accentColor)
                .overlay(Capsule().stroke(CharacterStyle.ink, lineWidth: line))
                .frame(width: 0.3 * s, height: 0.07 * s)
                .position(x: 0.5 * s, y: 0.61 * s)

            head(center: CGPoint(x: 0.5 * s, y: 0.35 * s), diameter: 0.5 * s)
        }
    }

    private var raisedArm: some View {
        let s = size
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Capsule()
                    .fill(fur)
                    .overlay(Capsule().stroke(CharacterStyle.ink, lineWidth: line))
                    .frame(width: 0.08 * s, height: 0.2 * s)
            }
            Circle()
                .fill(CharacterStyle.pink)
                .overlay(Circle().stroke(CharacterStyle.ink, lineWidth: line))
                .frame(width: 0.09 * s)
                .offset(y: 0.06 * s)
            if let prop = pose.prop {
                Image(systemName: prop)
                    .font(.system(size: 0.13 * s, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 0.2 * s, height: 0.2 * s)
                    .background(Circle().fill(Color(.systemBackground)))
                    .overlay(Circle().stroke(CharacterStyle.ink.opacity(0.35), lineWidth: max(1, line * 0.6)))
                    .symbolEffect(.bounce, value: propBounce)
                    .offset(y: -0.06 * s)
            }
        }
    }

    // MARK: Head (shared by both styles)

    private func head(center c: CGPoint, diameter d: CGFloat) -> some View {
        ZStack {
            // Big round ears with pink insides, behind the head.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Blob(fill: fur, width: 0.54 * d, height: 0.54 * d,
                     at: CGPoint(x: c.x + side * 0.44 * d, y: c.y - 0.4 * d), line: line)
                Blob(fill: CharacterStyle.pink, width: 0.32 * d, height: 0.32 * d,
                     at: CGPoint(x: c.x + side * 0.44 * d, y: c.y - 0.4 * d))
            }
            Blob(fill: fur, width: d, height: 0.92 * d, at: c, line: line)

            // Rosy cheeks, then big sparkly eyes.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Blob(fill: CharacterStyle.blush.opacity(0.55), width: 0.18 * d, height: 0.1 * d,
                     at: CGPoint(x: c.x + side * 0.32 * d, y: c.y + 0.18 * d))
                SparklyEye(width: 0.17 * d, height: 0.22 * d,
                           at: CGPoint(x: c.x + side * 0.18 * d, y: c.y + 0.02 * d), isBlinking: isBlinking)
            }

            // Short whiskers, a tiny pink nose, and a small smile.
            MouseMuzzle()
                .stroke(CharacterStyle.ink.opacity(0.65), style: StrokeStyle(lineWidth: max(1, line * 0.55), lineCap: .round))
                .frame(width: d, height: d)
                .position(c)
            Blob(fill: CharacterStyle.pink, width: 0.12 * d, height: 0.09 * d,
                 at: CGPoint(x: c.x, y: c.y + 0.17 * d), line: line * 0.7)
        }
    }

    // MARK: Motion

    /// A wave (or a bounce of the prop) when it appears, then an occasional
    /// blink. None of it runs with Reduce Motion on.
    private func animate() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .milliseconds(250))
        if pose == .waving && style == .fullFigure {
            for angle in [55.0, 20, 55, 20, 30] {
                withAnimation(.easeInOut(duration: 0.2)) { armAngle = angle }
                try? await Task.sleep(for: .milliseconds(200))
            }
        } else {
            propBounce += 1
        }
        await blinkLoop($isBlinking)
    }
}

/// Whiskers and a little "w" smile, drawn relative to the head's square.
private struct MouseMuzzle: Shape {
    func path(in rect: CGRect) -> Path {
        let d = rect.width, x = rect.minX, y = rect.minY
        func pt(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: x + px * d, y: y + py * d) }
        var p = Path()
        for (from, to) in [((0.38, 0.66), (0.14, 0.62)), ((0.38, 0.7), (0.15, 0.72)),
                           ((0.62, 0.66), (0.86, 0.62)), ((0.62, 0.7), (0.85, 0.72))] {
            p.move(to: pt(from.0, from.1))
            p.addLine(to: pt(to.0, to.1))
        }
        p.move(to: pt(0.43, 0.73))
        p.addQuadCurve(to: pt(0.5, 0.73), control: pt(0.465, 0.78))
        p.addQuadCurve(to: pt(0.57, 0.73), control: pt(0.535, 0.78))
        return p
    }
}

/// A long, thin tail sweeping out behind the Mouse and curling at the tip.
private struct Tail: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width
        var p = Path()
        p.move(to: CGPoint(x: 0.6 * s, y: 0.86 * s))
        p.addQuadCurve(to: CGPoint(x: 0.88 * s, y: 0.8 * s), control: CGPoint(x: 0.78 * s, y: 0.95 * s))
        p.addQuadCurve(to: CGPoint(x: 0.86 * s, y: 0.6 * s), control: CGPoint(x: 0.98 * s, y: 0.68 * s))
        p.addQuadCurve(to: CGPoint(x: 0.78 * s, y: 0.66 * s), control: CGPoint(x: 0.76 * s, y: 0.58 * s))
        return p
    }
}

// MARK: - Goldie

/// Goldie, the golden retriever: the character behind the Golden Retriever
/// Bark notification sound. Sits on her haunches looking at you, with big
/// floppy ears, a little pink tongue, and a collar with a heart tag — a
/// friendly companion rather than a working guide dog (no harness), since
/// many members use a cane or neither. Requested directly (2026-09-25).
struct GoldieView: View {
    enum Style { case sitting, face }

    var size: CGFloat = 140
    var style: Style = .sitting
    /// Fetch's header: Goldie bringing in the paper.
    var holdingNewspaper = false
    /// Fetch's "all caught up": content, with happy closed eyes.
    var happyEyes = false
    var accessibilityDescription: String? = nil
    var hidesAtAccessibilityTextSizes = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var isBlinking = false
    @State private var tailAngle: Double = 0
    @State private var headTilt: Double = 0

    private let gold = Color(red: 0.93, green: 0.72, blue: 0.40)
    private let goldDark = Color(red: 0.80, green: 0.54, blue: 0.26)
    private let cream = Color(red: 0.99, green: 0.91, blue: 0.75)
    private let collar = Color(red: 0.86, green: 0.27, blue: 0.33)
    private let tag = Color(red: 1.0, green: 0.80, blue: 0.30)
    private var line: CGFloat { CharacterStyle.lineWidth(size, contrast) }

    var body: some View {
        HiddenAtLargeText(hides: hidesAtAccessibilityTextSizes, description: accessibilityDescription) {
            Group {
                switch style {
                case .sitting: sitting
                case .face: head(center: CGPoint(x: 0.5 * size, y: 0.5 * size), width: 0.72 * size)
                }
            }
            .frame(width: size, height: size)
            .modifier(CharacterAccessibility(description: accessibilityDescription))
            .task { await animate() }
        }
    }

    private var sitting: some View {
        let s = size
        return ZStack {
            // Tail curling up beside her, behind everything; it wags.
            GoldieTail()
                .stroke(goldDark, style: StrokeStyle(lineWidth: 0.07 * s, lineCap: .round))
                .frame(width: s, height: s)
                .rotationEffect(.degrees(tailAngle), anchor: UnitPoint(x: 0.7, y: 0.86))

            // Haunches and back paws, then body and cream chest.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Blob(fill: gold, width: 0.3 * s, height: 0.25 * s, at: CGPoint(x: 0.5 * s + side * 0.22 * s, y: 0.84 * s), line: line)
                Blob(fill: cream, width: 0.14 * s, height: 0.07 * s, at: CGPoint(x: 0.5 * s + side * 0.3 * s, y: 0.95 * s), line: line)
            }
            Blob(fill: gold, width: 0.46 * s, height: 0.5 * s, at: CGPoint(x: 0.5 * s, y: 0.68 * s), line: line)
            Blob(fill: cream, width: 0.26 * s, height: 0.3 * s, at: CGPoint(x: 0.5 * s, y: 0.66 * s))

            // Front legs straight down, with cream paws.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(gold)
                    .overlay(Capsule().stroke(CharacterStyle.ink, lineWidth: line))
                    .frame(width: 0.11 * s, height: 0.28 * s)
                    .position(x: 0.5 * s + side * 0.08 * s, y: 0.8 * s)
                Blob(fill: cream, width: 0.14 * s, height: 0.08 * s, at: CGPoint(x: 0.5 * s + side * 0.08 * s, y: 0.94 * s), line: line)
            }

            // Collar with a little heart tag.
            Capsule()
                .fill(collar)
                .overlay(Capsule().stroke(CharacterStyle.ink, lineWidth: line))
                .frame(width: 0.3 * s, height: 0.05 * s)
                .position(x: 0.5 * s, y: 0.5 * s)
            Image(systemName: "heart.fill")
                .font(.system(size: 0.07 * s))
                .foregroundStyle(tag)
                .position(x: 0.5 * s, y: 0.555 * s)

            head(center: CGPoint(x: 0.5 * s, y: 0.3 * s), width: 0.5 * s)
                .rotationEffect(.degrees(headTilt), anchor: UnitPoint(x: 0.5, y: 0.45))
        }
    }

    private func head(center c: CGPoint, width d: CGFloat) -> some View {
        ZStack {
            Blob(fill: gold, width: d, height: 0.88 * d, at: c, line: line)

            // Soft cream muzzle and rosy cheeks.
            Blob(fill: cream, width: 0.5 * d, height: 0.34 * d, at: CGPoint(x: c.x, y: c.y + 0.22 * d), line: line * 0.7)
            ForEach([-1.0, 1.0], id: \.self) { side in
                Blob(fill: CharacterStyle.blush.opacity(0.5), width: 0.16 * d, height: 0.09 * d,
                     at: CGPoint(x: c.x + side * 0.33 * d, y: c.y + 0.14 * d))
                if happyEyes {
                    HappyEye()
                        .stroke(CharacterStyle.ink, style: StrokeStyle(lineWidth: max(1.5, line * 1.2), lineCap: .round))
                        .frame(width: 0.15 * d, height: 0.08 * d)
                        .position(x: c.x + side * 0.2 * d, y: c.y - 0.04 * d)
                } else {
                    SparklyEye(width: 0.15 * d, height: 0.18 * d,
                               at: CGPoint(x: c.x + side * 0.2 * d, y: c.y - 0.04 * d), isBlinking: isBlinking)
                }
                // Big floppy ears hanging over the sides of her head.
                Blob(fill: goldDark, width: 0.3 * d, height: 0.62 * d,
                     at: CGPoint(x: c.x + side * 0.5 * d, y: c.y + 0.1 * d), line: line, rotation: side * 16)
            }

            if holdingNewspaper {
                // A rolled-up newspaper held across her mouth.
                ZStack {
                    RoundedRectangle(cornerRadius: 0.08 * d)
                        .fill(Color(white: 0.96))
                        .overlay(RoundedRectangle(cornerRadius: 0.08 * d).stroke(CharacterStyle.ink, lineWidth: line))
                    VStack(spacing: 0.04 * d) {
                        Capsule().fill(CharacterStyle.ink.opacity(0.35)).frame(height: max(1, 0.02 * d))
                        Capsule().fill(CharacterStyle.ink.opacity(0.35)).frame(height: max(1, 0.02 * d))
                    }
                    .padding(.horizontal, 0.12 * d)
                }
                .frame(width: 0.95 * d, height: 0.2 * d)
                .rotationEffect(.degrees(-8))
                .position(x: c.x, y: c.y + 0.32 * d)
            } else {
                // Little pink tongue, then the mouth.
                Capsule()
                    .fill(CharacterStyle.pink)
                    .overlay(Capsule().stroke(CharacterStyle.ink, lineWidth: line * 0.7))
                    .frame(width: 0.13 * d, height: 0.16 * d)
                    .position(x: c.x, y: c.y + 0.36 * d)
                GoldieMouth()
                    .stroke(CharacterStyle.ink, style: StrokeStyle(lineWidth: max(1, line * 0.7), lineCap: .round))
                    .frame(width: d, height: d)
                    .position(c)
            }
            // Shiny button nose.
            Blob(fill: CharacterStyle.ink, width: 0.17 * d, height: 0.12 * d, at: CGPoint(x: c.x, y: c.y + 0.12 * d))
            Circle().fill(.white.opacity(0.8)).frame(width: 0.04 * d).position(x: c.x - 0.03 * d, y: c.y + 0.1 * d)
        }
    }

    /// A few tail wags and a curious head tilt when she appears, then an
    /// occasional blink. None of it with Reduce Motion on.
    private func animate() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .milliseconds(350))
        if style == .sitting {
            for angle in [-10.0, 8, -10, 8, 0] {
                withAnimation(.easeInOut(duration: 0.14)) { tailAngle = angle }
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
        withAnimation(.easeInOut(duration: 0.35)) { headTilt = -7 }
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.easeInOut(duration: 0.35)) { headTilt = 0 }
        await blinkLoop($isBlinking)
    }
}

/// A content, closed eye: a gentle upward curve, like "^".
private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return p
    }
}

private struct GoldieMouth: Shape {
    func path(in rect: CGRect) -> Path {
        let d = rect.width, x = rect.minX, y = rect.minY
        func pt(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: x + px * d, y: y + py * d) }
        var p = Path()
        p.move(to: pt(0.5, 0.62))
        p.addLine(to: pt(0.5, 0.7))
        p.move(to: pt(0.4, 0.7))
        p.addQuadCurve(to: pt(0.5, 0.7), control: pt(0.45, 0.76))
        p.addQuadCurve(to: pt(0.6, 0.7), control: pt(0.55, 0.76))
        return p
    }
}

private struct GoldieTail: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width
        var p = Path()
        p.move(to: CGPoint(x: 0.7 * s, y: 0.86 * s))
        p.addQuadCurve(to: CGPoint(x: 0.94 * s, y: 0.64 * s), control: CGPoint(x: 0.95 * s, y: 0.88 * s))
        return p
    }
}

// MARK: - Setup welcome

/// The first thing a new member sees: Goldie sitting and looking at you,
/// with the little Mouse standing by her front paws, waving up. Decorative;
/// Setup describes it once, right after its heading.
struct WelcomeFriendsView: View {
    var height: CGFloat = 150

    var body: some View {
        HiddenAtLargeText(hides: true, description: nil) {
            ZStack(alignment: .bottom) {
                GoldieView(size: height, hidesAtAccessibilityTextSizes: false)
                    .offset(x: -0.18 * height)
                MouseMascotView(pose: .waving, size: 0.55 * height, hidesAtAccessibilityTextSizes: false)
                    .offset(x: 0.36 * height, y: 0.02 * height)
            }
            .frame(width: 1.3 * height, height: height)
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            WelcomeFriendsView()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                ForEach([MousePose.waving, .reading, .searching, .bookmarking, .following,
                         .recommending, .listening, .tinkering, .celebrating, .plain], id: \.self) { pose in
                    MouseMascotView(pose: pose, size: 96)
                }
                MouseMascotView(pose: .plain, size: 96, style: .face)
                GoldieView(size: 96)
                GoldieView(size: 96, style: .face)
            }
        }
        .padding()
    }
}
