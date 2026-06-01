import { Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';

export function WritingToolsTip() {
  const { colors } = useTheme();

  return (
    <View
      accessible
      accessibilityRole="text"
      accessibilityLabel="Apple Intelligence tip: select any text you type to proofread, rewrite, shorten, or translate it using Writing Tools."
      style={{
        flexDirection: 'row', alignItems: 'flex-start', gap: 8,
        backgroundColor: colors.pill, borderRadius: 10,
        paddingHorizontal: 14, paddingVertical: 10, marginBottom: 12,
        borderWidth: 1, borderColor: colors.border,
      }}
    >
      <Text style={{ fontSize: 16, color: colors.accent }} accessibilityElementsHidden>✦</Text>
      <Text style={{ flex: 1, fontSize: 14, lineHeight: 20, color: colors.text }}>
        <Text style={{ fontWeight: '700', color: colors.accent }}>Apple Intelligence: </Text>
        select text you type to proofread, rewrite, or translate using Writing Tools.
      </Text>
    </View>
  );
}
