import { Linking, Pressable, Text, View } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';
import type { GuidelineWarning } from '../services/guidelinesChecker';

type Props = {
  warning: GuidelineWarning;
  onDismiss: (id: string) => void;
};

const GUIDELINES_URL = 'https://www.applevis.com/help/guidelines';

export function GuidelinesReminder({ warning, onDismiss }: Props) {
  const { colors, isDark } = useTheme();

  const config = {
    high:   { bg: '#FFF0F0', border: '#FCA5A5', text: '#991B1B', btn: '#B91C1C', label: 'Guideline reminder' },
    medium: { bg: '#FFFBEB', border: '#FCD34D', text: '#92400E', btn: '#B45309', label: 'Guideline reminder' },
    low:    { bg: '#F0F9FF', border: '#BAE6FD', text: '#0C4A6E', btn: '#0369A1', label: 'Friendly tip' },
  }[warning.severity];

  return (
    <View
      accessible
      accessibilityRole="alert"
      accessibilityLabel={`${config.label}: ${warning.rule}. ${warning.message} Double tap Got It to dismiss.`}
      style={{
        backgroundColor: isDark ? '#2C2C2E' : config.bg,
        borderWidth: 1.5, borderColor: config.border,
        borderRadius: 10, padding: 14, marginBottom: 12, gap: 10,
      }}
    >
      <View importantForAccessibility="no-hide-descendants">
        <Text style={{ fontSize: 13, fontWeight: '700', color: config.text, marginBottom: 4 }}
          importantForAccessibility="no">
          {config.label}: {warning.rule}
        </Text>
        <Text style={{ fontSize: 14, lineHeight: 20, color: colors.text }}
          importantForAccessibility="no">
          {warning.message}
        </Text>
      </View>

      <View style={{ flexDirection: 'row', gap: 10 }} importantForAccessibility="no-hide-descendants">
        <Pressable
          onPress={() => onDismiss(warning.id)}
          accessible accessibilityRole="button" accessibilityLabel="Got it, dismiss this reminder"
          style={{ flex: 1, alignItems: 'center', backgroundColor: config.btn,
            borderRadius: 8, paddingVertical: 9 }}
        >
          <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 14 }}>Got It</Text>
        </Pressable>
        <Pressable
          onPress={() => Linking.openURL(GUIDELINES_URL)}
          accessible accessibilityRole="button"
          accessibilityLabel="View full AppleVis posting guidelines"
          accessibilityHint="Opens the AppleVis guidelines page in Safari."
          style={{ flex: 1, alignItems: 'center', backgroundColor: 'transparent',
            borderWidth: 1.5, borderColor: config.border, borderRadius: 8, paddingVertical: 9 }}
        >
          <Text style={{ color: config.text, fontWeight: '600', fontSize: 14 }}>View Guidelines</Text>
        </Pressable>
      </View>
    </View>
  );
}
