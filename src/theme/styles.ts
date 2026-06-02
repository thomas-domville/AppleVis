import { StyleSheet } from 'react-native';
import type { ThemeColors } from './themes';
import type { CardDensity } from '../contexts/PreferencesContext';

export function createStyles(colors: ThemeColors, density: CardDensity = 'comfortable') {
  const cardPad   = density === 'compact' ? 12 : 18;
  const cardPadSm = density === 'compact' ?  9 : 16;
  return StyleSheet.create({
    screen:    { flex: 1, backgroundColor: colors.background },
    content:   { flex: 1, paddingHorizontal: 18, paddingTop: 18 },
    title:     { fontSize: 34, fontWeight: '800', color: colors.text, marginBottom: 6 },
    lede:      { fontSize: 17, lineHeight: 24, color: colors.textSecondary, marginBottom: 16 },
    card:      { backgroundColor: colors.card, borderRadius: 20, padding: cardPad,   marginBottom: density === 'compact' ? 8 : 12, borderColor: colors.border, borderWidth: StyleSheet.hairlineWidth },
    cardSmall: { backgroundColor: colors.card, borderRadius: 14, padding: cardPadSm, marginBottom: density === 'compact' ? 6 : 10, borderColor: colors.border, borderWidth: StyleSheet.hairlineWidth },
    cardTitle: { fontSize: density === 'compact' ? 17 : 20, fontWeight: '700', color: colors.text, marginBottom: 4 },
    cardMeta:  { fontSize: 15, lineHeight: 21, color: colors.textSecondary },
    body:      { fontSize: 17, lineHeight: 24, color: colors.text },
    pillRow:   { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 },
    pill:      { paddingHorizontal: 14, paddingVertical: 10, borderRadius: 999, backgroundColor: colors.pill },
    pillText:  { color: colors.pillText, fontWeight: '700' },
  });
}

// ─── Legacy static exports ────────────────────────────────────────────────────
// Retained for components that have not yet migrated to useTheme().
// Gradually replace `import { colors, styles }` with `const { colors, styles } = useTheme()`.

import { THEMES } from './themes';

export const colors = THEMES.light.colors;
export const styles = createStyles(colors);
