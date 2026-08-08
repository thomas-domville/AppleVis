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

    static let light = ThemeColors(
        background: Color(hex: "#F5F7FA"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#101828"), textSecondary: Color(hex: "#475467"),
        border: Color(hex: "#D0D5DD"), accent: Color(hex: "#0A84FF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#E8F1FF"), pillText: Color(hex: "#0A84FF"),
        inputBackground: Color(hex: "#FAFAFA"), inputBorder: Color(hex: "#D0D5DD"), isStatusBarLight: false
    )

    static let dark = ThemeColors(
        background: Color(hex: "#1C1C1E"), card: Color(hex: "#2C2C2E"),
        text: Color(hex: "#FFFFFF"), textSecondary: Color(hex: "#AEAEB2"),
        border: Color(hex: "#38383A"), accent: Color(hex: "#0A84FF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#1A3A5C"), pillText: Color(hex: "#4DA6FF"),
        inputBackground: Color(hex: "#1C1C1E"), inputBorder: Color(hex: "#38383A"), isStatusBarLight: true
    )

    static let midnight = ThemeColors(
        background: Color(hex: "#000000"), card: Color(hex: "#111111"),
        text: Color(hex: "#FFFFFF"), textSecondary: Color(hex: "#8E8E93"),
        border: Color(hex: "#222222"), accent: Color(hex: "#0A84FF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#001A3A"), pillText: Color(hex: "#4DA6FF"),
        inputBackground: Color(hex: "#111111"), inputBorder: Color(hex: "#222222"), isStatusBarLight: true
    )

    static let warm = ThemeColors(
        background: Color(hex: "#FFF8F0"), card: Color(hex: "#FFFBF5"),
        text: Color(hex: "#2D1B00"), textSecondary: Color(hex: "#7A5533"),
        border: Color(hex: "#E8D5B7"), accent: Color(hex: "#C17D2B"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FFF0D0"), pillText: Color(hex: "#A86820"),
        inputBackground: Color(hex: "#FFFBF5"), inputBorder: Color(hex: "#E8D5B7"), isStatusBarLight: false
    )

    static let sepia = ThemeColors(
        background: Color(hex: "#F5F0E8"), card: Color(hex: "#FAF6EE"),
        text: Color(hex: "#3B2E1E"), textSecondary: Color(hex: "#7A6650"),
        border: Color(hex: "#D9CCBA"), accent: Color(hex: "#8B6914"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#EDE0CC"), pillText: Color(hex: "#8B6914"),
        inputBackground: Color(hex: "#FAF6EE"), inputBorder: Color(hex: "#D9CCBA"), isStatusBarLight: false
    )

    static let applevisClassic = ThemeColors(
        background: Color(hex: "#EEF4FF"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#0A1A3A"), textSecondary: Color(hex: "#3A5080"),
        border: Color(hex: "#C5D4FF"), accent: Color(hex: "#0A5FFF"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#D8E8FF"), pillText: Color(hex: "#0A5FFF"),
        inputBackground: Color(hex: "#F5F8FF"), inputBorder: Color(hex: "#C5D4FF"), isStatusBarLight: false
    )

    static let mouseLight = ThemeColors(
        background: Color(hex: "#F7F5F0"), card: Color(hex: "#FFFEF9"),
        text: Color(hex: "#2D2A25"), textSecondary: Color(hex: "#6B6256"),
        border: Color(hex: "#E5DDD0"), accent: Color(hex: "#F5A623"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FDF3DF"), pillText: Color(hex: "#C47E0A"),
        inputBackground: Color(hex: "#FFFEF9"), inputBorder: Color(hex: "#E5DDD0"), isStatusBarLight: false
    )

    static let mouseDark = ThemeColors(
        background: Color(hex: "#1E1C18"), card: Color(hex: "#2A2822"),
        text: Color(hex: "#F5F0E8"), textSecondary: Color(hex: "#A89880"),
        border: Color(hex: "#3D3A32"), accent: Color(hex: "#F5A623"), accentText: Color(hex: "#1E1C18"),
        pill: Color(hex: "#3D3218"), pillText: Color(hex: "#F5A623"),
        inputBackground: Color(hex: "#2A2822"), inputBorder: Color(hex: "#3D3A32"), isStatusBarLight: true
    )

    static let orchard = ThemeColors(
        background: Color(hex: "#F2F8F2"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#1A2E1A"), textSecondary: Color(hex: "#4A6741"),
        border: Color(hex: "#C8DEC5"), accent: Color(hex: "#CC3333"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FFE8E8"), pillText: Color(hex: "#CC3333"),
        inputBackground: Color(hex: "#FFFFFF"), inputBorder: Color(hex: "#C8DEC5"), isStatusBarLight: false
    )

    static let goldenGate = ThemeColors(
        background: Color(hex: "#FFF5EE"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#2D1A0A"), textSecondary: Color(hex: "#7A4A28"),
        border: Color(hex: "#FDDBB4"), accent: Color(hex: "#FF6B2B"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#FFE9DA"), pillText: Color(hex: "#C84800"),
        inputBackground: Color(hex: "#FFFFFF"), inputBorder: Color(hex: "#FDDBB4"), isStatusBarLight: false
    )

    static let nebula = ThemeColors(
        background: Color(hex: "#12102A"), card: Color(hex: "#1E1B3A"),
        text: Color(hex: "#E8E0FF"), textSecondary: Color(hex: "#9B8EC4"),
        border: Color(hex: "#2E2A50"), accent: Color(hex: "#A78BFA"), accentText: Color(hex: "#12102A"),
        pill: Color(hex: "#2E2650"), pillText: Color(hex: "#A78BFA"),
        inputBackground: Color(hex: "#1E1B3A"), inputBorder: Color(hex: "#2E2A50"), isStatusBarLight: true
    )

    static let highContrastLight = ThemeColors(
        background: Color(hex: "#FFFFFF"), card: Color(hex: "#FFFFFF"),
        text: Color(hex: "#000000"), textSecondary: Color(hex: "#000000"),
        border: Color(hex: "#000000"), accent: Color(hex: "#0040CC"), accentText: Color(hex: "#FFFFFF"),
        pill: Color(hex: "#0040CC"), pillText: Color(hex: "#FFFFFF"),
        inputBackground: Color(hex: "#FFFFFF"), inputBorder: Color(hex: "#000000"), isStatusBarLight: false
    )

    static let highContrastDark = ThemeColors(
        background: Color(hex: "#000000"), card: Color(hex: "#000000"),
        text: Color(hex: "#FFFFFF"), textSecondary: Color(hex: "#FFFFFF"),
        border: Color(hex: "#FFFFFF"), accent: Color(hex: "#FFFF00"), accentText: Color(hex: "#000000"),
        pill: Color(hex: "#FFFF00"), pillText: Color(hex: "#000000"),
        inputBackground: Color(hex: "#000000"), inputBorder: Color(hex: "#FFFFFF"), isStatusBarLight: true
    )
}
