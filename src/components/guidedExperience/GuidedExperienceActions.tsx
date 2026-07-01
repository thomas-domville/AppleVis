import { Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../contexts/ThemeContext';
import type { GuidedExperienceSecondaryAction } from '../../guidedExperience/types';

type Props = {
  primaryLabel: string;
  onPrimary: () => void;
  showBack: boolean;
  onBack: () => void;
  secondaryActions?: GuidedExperienceSecondaryAction[];
  onExploreScreen: (route: string) => void;
  onLearnMore: (helpArticleId: string) => void;
  showSkip: boolean;
  onSkip: () => void;
};

export function GuidedExperienceActions({
  primaryLabel, onPrimary, showBack, onBack, secondaryActions, onExploreScreen, onLearnMore, showSkip, onSkip,
}: Props) {
  const { colors } = useTheme();
  const navSecondary = (secondaryActions ?? []).filter((a) => a.kind === 'exploreScreen' || a.kind === 'learnMore');

  return (
    <View>
      {showBack && (
        <Pressable
          onPress={onBack}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Back"
          style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', marginBottom: 8, opacity: pressed ? 0.6 : 1 })}
        >
          <Ionicons name="chevron-back" size={20} color={colors.accent} accessibilityElementsHidden />
          <Text style={{ color: colors.accent, fontSize: 16 }} accessibilityElementsHidden>Back</Text>
        </Pressable>
      )}

      {navSecondary.map((action, i) => (
        <Pressable
          key={i}
          onPress={() => {
            if (action.kind === 'exploreScreen' && action.route) onExploreScreen(action.route);
            if (action.kind === 'learnMore' && action.helpArticleId) onLearnMore(action.helpArticleId);
          }}
          accessible
          accessibilityRole="button"
          accessibilityLabel={action.label}
          style={({ pressed }) => ({
            alignItems: 'center', borderRadius: 12, borderWidth: 1.5, borderColor: colors.border,
            paddingVertical: 13, marginBottom: 10, opacity: pressed ? 0.7 : 1,
          })}
        >
          <Text style={{ color: colors.text, fontSize: 16, fontWeight: '600' }}>{action.label}</Text>
        </Pressable>
      ))}

      <Pressable
        onPress={onPrimary}
        accessible
        accessibilityRole="button"
        accessibilityLabel={primaryLabel}
        style={{
          backgroundColor: colors.accent, borderRadius: 14, paddingVertical: 16,
          alignItems: 'center', marginTop: 2,
        }}
      >
        <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 17 }}>{primaryLabel}</Text>
      </Pressable>

      {showSkip && (
        <Pressable
          onPress={onSkip}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Skip Tour"
          accessibilityHint="Exits the tour. You can replay it any time from Profile."
          style={{ alignItems: 'center', paddingVertical: 12 }}
        >
          <Text style={{ color: colors.textSecondary, fontSize: 15 }}>Skip Tour</Text>
        </Pressable>
      )}
    </View>
  );
}
