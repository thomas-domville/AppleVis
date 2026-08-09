import SwiftUI

extension View {
    /// Applies a theme's background/card colors to a `List` or `Form` root —
    /// `.scrollContentBackground(.hidden)` removes the default grouped
    /// background so the theme's exact colors show through instead of a
    /// generic system background, which is what made Warm/Sepia/Mouse/
    /// Orchard/Golden Gate/Nebula indistinguishable from plain light/dark
    /// mode aside from accent color.
    ///
    /// Deliberately does NOT also override foreground/text color: an
    /// earlier version applied `.foregroundStyle(colors.text)` here, but
    /// that broke every descendant `.foregroundStyle(.secondary)` call's
    /// contrast (SwiftUI derives `.secondary`'s opacity from whatever
    /// custom primary style is in scope, and the combination rendered
    /// "by <author>" captions nearly invisible against dark theme
    /// backgrounds — confirmed visually on-device on the Nebula theme).
    /// System `.primary`/`.secondary` already track `theme.colorScheme`
    /// (each theme sets `.light` or `.dark`), which keeps every screen
    /// correctly legible; only the background/card hue is theme-specific.
    func themedList(_ colors: ThemeColors) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(colors.background)
            .listRowBackground(colors.card)
    }

    /// The soft-accent capsule chip RN's `styles.ts` calls `pill`/`pillText`
    /// (a pale accent-tinted background with full-accent-color text) — used
    /// for "NEW" badges, license/genre tags, and unselected filter chips.
    /// These previously hardcoded `Color.secondary.opacity(0.15)` or
    /// `Color.accentColor.opacity(0.12))`, which is why every theme's
    /// verified-against-RN `pill`/`pillText` hex pair went completely
    /// unused despite being ported this session.
    func themedPill(_ colors: ThemeColors) -> some View {
        self
            .foregroundStyle(colors.pillText)
            .background(colors.pill, in: Capsule())
    }
}
