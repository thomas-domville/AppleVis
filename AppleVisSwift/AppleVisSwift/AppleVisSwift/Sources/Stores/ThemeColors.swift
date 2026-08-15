import SwiftUI

extension Color {
    /// Parses a `#RRGGBB` hex string. Used only for theme palette literals
    /// ported verbatim from RN's `src/theme/themes.ts` — everywhere else in
    /// the app should keep using semantic/system colors.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

/// Full per-theme color token set — ported verbatim from RN's `ThemeColors`
/// type and the 13 fixed palettes in `src/theme/themes.ts`. Swift's theme
/// system previously only varied accent color plus a light/dark base,
/// leaving Warm/Sepia/Mouse/Orchard/Golden Gate/Nebula indistinguishable
/// from generic iOS light/dark mode aside from their accent tint.
struct ThemeColors {
    let background: Color
    let card: Color
    let text: Color
    let textSecondary: Color
    let border: Color
    let accent: Color
    let accentText: Color
    let pill: Color
    let pillText: Color
    let inputBackground: Color
    let inputBorder: Color
    let isStatusBarLight: Bool
    // Semantic state tokens (CARD-07) — previously state meaning (warning/
    // error/success/unread) was conveyed by ad hoc Color.red/.orange/
    // .accentColor call sites, independent of the active theme, bypassing
    // per-theme contrast tuning entirely across all 13 palettes, including
    // the two dedicated high-contrast themes. Chosen per-theme so each
    // reads clearly against that theme's own background and, where a
    // theme's own accent is already red/orange (Orchard, Golden Gate),
    // stays visually distinct from that accent rather than colliding with
    // it. `unread` intentionally equals `accent` — matches the existing,
    // already-correct behavior of `NewCountBadge` — giving call sites a
    // semantically named token to reach for instead of `Color.accentColor`
    // when the intent is specifically "marks something new/unread." First
    // pass on all four; still needs the explicit per-theme visual contrast
    // verification pass the audit calls for (especially both high-contrast
    // themes and the darkest themes), not yet done here.
    let warning: Color
    let error: Color
    let success: Color
    let unread: Color

    static let light = ThemeColors(
        background: Color(hex: "#F5F7FA"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#101828"), textSecondary: Color(hex: "#475467"),
        border: Color(hex: "#D0D5DD"), accent: Color(hex: "#0A84FF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#E8F1FF"), pillText: Color(hex: "#0A84FF"),
        inputBackground: Color(hex: "#FAFAFA"), inputBorder: Color(hex: "#D0D5DD"), isStatusBarLight: false,
        warning: Color(hex: "#B54708"), error: Color(hex: "#D92D20"), success: Color(hex: "#067647"), unread: Color(hex: "#0A84FF")
    )

    static let dark = ThemeColors(
        background: Color(hex: "#1C1C1E"), card: Color(hex: "#2C2C2E"),
        text: Color(hex: "#FFFFFF"), textSecondary: Color(hex: "#AEAEB2"),
        border: Color(hex: "#38383A"), accent: Color(hex: "#0A84FF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#1A3A5C"), pillText: Color(hex: "#4DA6FF"),
        inputBackground: Color(hex: "#1C1C1E"), inputBorder: Color(hex: "#38383A"), isStatusBarLight: true,
        warning: Color(hex: "#FDB022"), error: Color(hex: "#F97066"), success: Color(hex: "#47CD89"), unread: Color(hex: "#0A84FF")
    )

    static let midnight = ThemeColors(
        background: Color(hex: "#000000"), card: Color(hex: "#111111"),
        text: Color(hex: "#FFFFFF"), textSecondary: Color(hex: "#8E8E93"),
        border: Color(hex: "#222222"), accent: Color(hex: "#0A84FF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#001A3A"), pillText: Color(hex: "#4DA6FF"),
        inputBackground: Color(hex: "#111111"), inputBorder: Color(hex: "#222222"), isStatusBarLight: true,
        warning: Color(hex: "#FFC53D"), error: Color(hex: "#FF6B6B"), success: Color(hex: "#51D88A"), unread: Color(hex: "#0A84FF")
    )

    static let warm = ThemeColors(
        background: Color(hex: "#FFF8F0"), card: Color(hex: "#FFFBF5"),
        text: Color(hex: "#2D1B00"), textSecondary: Color(hex: "#7A5533"),
        border: Color(hex: "#E8D5B7"), accent: Color(hex: "#C17D2B"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FFF0D0"), pillText: Color(hex: "#A86820"),
        inputBackground: Color(hex: "#FFFBF5"), inputBorder: Color(hex: "#E8D5B7"), isStatusBarLight: false,
        warning: Color(hex: "#A15C07"), error: Color(hex: "#C1401F"), success: Color(hex: "#3F7D20"), unread: Color(hex: "#C17D2B")
    )

    static let sepia = ThemeColors(
        background: Color(hex: "#F5F0E8"), card: Color(hex: "#FAF6EE"),
        text: Color(hex: "#3B2E1E"), textSecondary: Color(hex: "#7A6650"),
        border: Color(hex: "#D9CCBA"), accent: Color(hex: "#8B6914"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#EDE0CC"), pillText: Color(hex: "#8B6914"),
        inputBackground: Color(hex: "#FAF6EE"), inputBorder: Color(hex: "#D9CCBA"), isStatusBarLight: false,
        warning: Color(hex: "#8B5A0F"), error: Color(hex: "#A13D2B"), success: Color(hex: "#4A6B1F"), unread: Color(hex: "#8B6914")
    )

    static let applevisClassic = ThemeColors(
        background: Color(hex: "#EEF4FF"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#0A1A3A"), textSecondary: Color(hex: "#3A5080"),
        border: Color(hex: "#C5D4FF"), accent: Color(hex: "#0A5FFF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#D8E8FF"), pillText: Color(hex: "#0A5FFF"),
        inputBackground: Color(hex: "#F5F8FF"), inputBorder: Color(hex: "#C5D4FF"), isStatusBarLight: false,
        warning: Color(hex: "#B54708"), error: Color(hex: "#D92D20"), success: Color(hex: "#067647"), unread: Color(hex: "#0A5FFF")
    )

    static let mouseLight = ThemeColors(
        background: Color(hex: "#F7F5F0"), card: Color(hex: "#FFFEF9"),
        text: Color(hex: "#2D2A25"), textSecondary: Color(hex: "#6B6256"),
        border: Color(hex: "#E5DDD0"), accent: Color(hex: "#F5A623"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FDF3DF"), pillText: Color(hex: "#C47E0A"),
        inputBackground: Color(hex: "#FFFEF9"), inputBorder: Color(hex: "#E5DDD0"), isStatusBarLight: false,
        // warning kept darker/more brown than the theme's own #F5A623 amber
        // accent so an actual warning state stays visually distinct from
        // ordinary interactive accent elements in this specific theme.
        warning: Color(hex: "#8B5A00"), error: Color(hex: "#C0392B"), success: Color(hex: "#2E7D32"), unread: Color(hex: "#F5A623")
    )

    static let mouseDark = ThemeColors(
        background: Color(hex: "#1E1C18"), card: Color(hex: "#2A2822"),
        text: Color(hex: "#F5F0E8"), textSecondary: Color(hex: "#A89880"),
        border: Color(hex: "#3D3A32"), accent: Color(hex: "#F5A623"), accentText: Color(hex: "#1E1C18"),
        pill: Color(hex: "#3D3218"), pillText: Color(hex: "#F5A623"),
        inputBackground: Color(hex: "#2A2822"), inputBorder: Color(hex: "#3D3A32"), isStatusBarLight: true,
        warning: Color(hex: "#FFCA6B"), error: Color(hex: "#E57373"), success: Color(hex: "#81C784"), unread: Color(hex: "#F5A623")
    )

    static let orchard = ThemeColors(
        background: Color(hex: "#F2F8F2"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#1A2E1A"), textSecondary: Color(hex: "#4A6741"),
        border: Color(hex: "#C8DEC5"), accent: Color(hex: "#CC3333"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FFE8E8"), pillText: Color(hex: "#CC3333"),
        inputBackground: Color(hex: "#FFFFFF"), inputBorder: Color(hex: "#C8DEC5"), isStatusBarLight: false,
        // error kept a deeper, more muted red than the theme's own vivid
        // #CC3333 accent (Orchard's own accent is red) so an actual error
        // state stays visually distinct from ordinary interactive elements.
        warning: Color(hex: "#B8860B"), error: Color(hex: "#9B1C1C"), success: Color(hex: "#2D6A2D"), unread: Color(hex: "#CC3333")
    )

    static let goldenGate = ThemeColors(
        background: Color(hex: "#FFF5EE"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#2D1A0A"), textSecondary: Color(hex: "#7A4A28"),
        border: Color(hex: "#FDDBB4"), accent: Color(hex: "#FF6B2B"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FFE9DA"), pillText: Color(hex: "#C84800"),
        inputBackground: Color(hex: "#FFFFFF"), inputBorder: Color(hex: "#FDDBB4"), isStatusBarLight: false,
        // warning kept a muted gold rather than orange, distinct from the
        // theme's own vivid #FF6B2B (Golden Gate Bridge orange) accent.
        warning: Color(hex: "#9C6B0A"), error: Color(hex: "#C0392B"), success: Color(hex: "#2F6B3F"), unread: Color(hex: "#FF6B2B")
    )

    static let nebula = ThemeColors(
        background: Color(hex: "#12102A"), card: Color(hex: "#1E1B3A"),
        text: Color(hex: "#E8E0FF"), textSecondary: Color(hex: "#9B8EC4"),
        border: Color(hex: "#2E2A50"), accent: Color(hex: "#A78BFA"), accentText: Color(hex: "#12102A"),
        pill: Color(hex: "#2E2650"), pillText: Color(hex: "#A78BFA"),
        inputBackground: Color(hex: "#1E1B3A"), inputBorder: Color(hex: "#2E2A50"), isStatusBarLight: true,
        warning: Color(hex: "#FFD166"), error: Color(hex: "#FF8080"), success: Color(hex: "#6EE7B7"), unread: Color(hex: "#A78BFA")
    )

    static let highContrastLight = ThemeColors(
        background: Color(hex: "#FFFFFF"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#000000"), textSecondary: Color(hex: "#000000"),
        border: Color(hex: "#000000"), accent: Color(hex: "#0040CC"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#0040CC"), pillText: Color(hex: "#FFFFFF"),
        inputBackground: Color(hex: "#FFFFFF"), inputBorder: Color(hex: "#000000"), isStatusBarLight: false,
        // Darker/more saturated than a typical warning amber — pure
        // yellow/orange commonly fails contrast against white; needs the
        // explicit high-contrast verification pass called out above.
        warning: Color(hex: "#995C00"), error: Color(hex: "#CC0000"), success: Color(hex: "#006622"), unread: Color(hex: "#0040CC")
    )

    static let highContrastDark = ThemeColors(
        background: Color(hex: "#000000"), card: Color(hex: "#000000"),
        text: Color(hex: "#FFFFFF"), textSecondary: Color(hex: "#FFFFFF"),
        border: Color(hex: "#FFFFFF"), accent: Color(hex: "#FFFF00"), accentText: Color(hex: "#000000"),
        pill: Color(hex: "#FFFF00"), pillText: Color(hex: "#000000"),
        inputBackground: Color(hex: "#000000"), inputBorder: Color(hex: "#FFFFFF"), isStatusBarLight: true,
        // warning kept orange, not yellow, since the theme's own accent is
        // already pure yellow (#FFFF00) — a yellow warning token would be
        // indistinguishable from ordinary interactive accent elements.
        warning: Color(hex: "#FF9900"), error: Color(hex: "#FF3333"), success: Color(hex: "#33FF33"), unread: Color(hex: "#FFFF00")
    )
}
