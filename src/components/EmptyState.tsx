import { Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../contexts/ThemeContext';

type Action = { label: string; onPress: () => void; variant?: 'primary' | 'secondary' };

function ActionButton({ action }: { action: Action }) {
  const { colors } = useTheme();
  const isSecondary = action.variant === 'secondary';
  return (
    <Pressable
      onPress={action.onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={action.label}
      style={{
        marginTop: 10,
        alignSelf: 'stretch',
        alignItems: 'center',
        backgroundColor: isSecondary ? 'transparent' : colors.accent,
        borderWidth: isSecondary ? 1.5 : 0,
        borderColor: colors.border,
        paddingHorizontal: 20,
        paddingVertical: 10,
        borderRadius: 10,
      }}
    >
      <Text style={{ color: isSecondary ? colors.text : '#FFF', fontWeight: '700', fontSize: 15 }}>
        {action.label}
      </Text>
    </Pressable>
  );
}

export function EmptyState({
  icon,
  title,
  subtitle,
  suggestions,
  action,
  primaryAction,
  secondaryAction,
  learnMore,
  accessibilityHint,
}: {
  icon: string;
  title: string;
  subtitle: string;
  /** Short list of next steps, e.g. "Check the spelling." Rendered as visual bullets and folded into the label. */
  suggestions?: string[];
  /** @deprecated use `primaryAction` — kept for existing call sites. */
  action?: Action;
  primaryAction?: Action;
  secondaryAction?: Action;
  /** Optional link to a relevant Help/Academy article — rendered as plain text below any actions. */
  learnMore?: { label: string; onPress: () => void };
  /** Optional VoiceOver hint appended after the label, e.g. "Double tap the button below to browse Discover." */
  accessibilityHint?: string;
}) {
  const { colors, styles } = useTheme();
  const resolvedPrimary = primaryAction ?? action;
  const suggestionText = suggestions?.length ? suggestions.join('. ') : '';

  return (
    <View
      style={[styles.card, { alignItems: 'center', paddingVertical: 36 }]}
      accessible
      accessibilityLabel={[title, subtitle, suggestionText].filter(Boolean).join('. ')}
      accessibilityHint={accessibilityHint}
    >
      <Ionicons
        name={icon as any}
        size={40}
        color={colors.textSecondary}
        accessibilityElementsHidden
        style={{ marginBottom: 12 }}
      />
      <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text,
        marginBottom: 6, textAlign: 'center' }}>
        {title}
      </Text>
      <Text style={{ fontSize: 14, color: colors.textSecondary,
        textAlign: 'center', lineHeight: 20 }}>
        {subtitle}
      </Text>

      {suggestions?.length ? (
        <View style={{ marginTop: 10, alignSelf: 'stretch' }} accessibilityElementsHidden>
          {suggestions.map((s, i) => (
            <Text key={i} style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, textAlign: 'center' }}>
              {'•'} {s}
            </Text>
          ))}
        </View>
      ) : null}

      {resolvedPrimary && <ActionButton action={resolvedPrimary} />}
      {secondaryAction && <ActionButton action={{ ...secondaryAction, variant: 'secondary' }} />}

      {learnMore && (
        <Pressable
          onPress={learnMore.onPress}
          accessible
          accessibilityRole="button"
          accessibilityLabel={learnMore.label}
          style={{ marginTop: 14 }}
        >
          <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 14, textDecorationLine: 'underline' }}>
            {learnMore.label}
          </Text>
        </Pressable>
      )}
    </View>
  );
}
