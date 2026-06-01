import { Linking, Pressable, Text, View } from 'react-native';
import type { GuidelineWarning } from '../services/guidelinesChecker';

type Props = {
  warning: GuidelineWarning;
  onDismiss: (id: string) => void;
};

const GUIDELINES_URL = 'https://www.applevis.com/help/guidelines';

const SEVERITY_STYLE = {
  high: {
    bg:     '#FFF0F0',
    border: '#FCA5A5',
    text:   '#991B1B',
    btn:    '#B91C1C',
    label:  '⚠️ Guideline reminder',
  },
  medium: {
    bg:     '#FFFBEB',
    border: '#FCD34D',
    text:   '#92400E',
    btn:    '#B45309',
    label:  '📋 Guideline reminder',
  },
  low: {
    bg:     '#F0F9FF',
    border: '#BAE6FD',
    text:   '#0C4A6E',
    btn:    '#0369A1',
    label:  '💡 Friendly tip',
  },
};

/**
 * A soft, non-blocking warning shown while composing a post.
 * The user can dismiss it or open the full guidelines page.
 * The post button is never affected — this is advisory only.
 */
export function GuidelinesReminder({ warning, onDismiss }: Props) {
  const s = SEVERITY_STYLE[warning.severity];

  return (
    <View
      accessible
      accessibilityRole="alert"
      accessibilityLabel={`${s.label}: ${warning.rule}. ${warning.message} Double tap to dismiss.`}
      style={{
        backgroundColor: s.bg,
        borderWidth: 1.5,
        borderColor:  s.border,
        borderRadius: 10,
        padding: 14,
        marginBottom: 12,
        gap: 10,
      }}
    >
      {/* Heading + message */}
      <View importantForAccessibility="no-hide-descendants">
        <Text
          style={{ fontSize: 13, fontWeight: '700', color: s.text, marginBottom: 4 }}
          importantForAccessibility="no"
        >
          {s.label}: {warning.rule}
        </Text>
        <Text style={{ fontSize: 14, lineHeight: 20, color: s.text }}
          importantForAccessibility="no"
        >
          {warning.message}
        </Text>
      </View>

      {/* Action buttons */}
      <View style={{ flexDirection: 'row', gap: 10 }} importantForAccessibility="no-hide-descendants">
        <Pressable
          onPress={() => onDismiss(warning.id)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Got it, dismiss this reminder"
          style={{
            flex: 1,
            alignItems: 'center',
            backgroundColor: s.btn,
            borderRadius: 8,
            paddingVertical: 9,
          }}
        >
          <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 14 }}>Got It</Text>
        </Pressable>

        <Pressable
          onPress={() => Linking.openURL(GUIDELINES_URL)}
          accessible
          accessibilityRole="button"
          accessibilityLabel="View full AppleVis posting guidelines"
          accessibilityHint="Opens the AppleVis guidelines page in your browser."
          style={{
            flex: 1,
            alignItems: 'center',
            backgroundColor: 'transparent',
            borderWidth: 1.5,
            borderColor: s.border,
            borderRadius: 8,
            paddingVertical: 9,
          }}
        >
          <Text style={{ color: s.text, fontWeight: '600', fontSize: 14 }}>View Guidelines</Text>
        </Pressable>
      </View>
    </View>
  );
}
