import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../contexts/ThemeContext';
import type { GuidedExperienceStep } from '../../guidedExperience/types';

type Props = {
  step: GuidedExperienceStep;
  stepIndex: number;
  totalSteps: number;
  headingRef: React.RefObject<Text | null>;
};

/**
 * Renders a single step's icon, title, and short text. VoiceOver focus lands on
 * the title only — the body is available to read but never auto-announced.
 * "Explain More" reveals explainMoreText in place without navigating away.
 */
export function GuidedExperienceStepCard({ step, stepIndex, totalSteps, headingRef }: Props) {
  const { colors } = useTheme();
  const [explained, setExplained] = useState(false);

  return (
    <View style={{ alignItems: 'center', marginBottom: 20 }}>
      {step.icon && (
        <View style={{
          width: 72, height: 72, borderRadius: 20,
          backgroundColor: colors.accent + '18',
          alignItems: 'center', justifyContent: 'center', marginBottom: 18,
        }} accessibilityElementsHidden>
          <Ionicons name={step.icon} size={34} color={colors.accent} />
        </View>
      )}
      <Text
        ref={headingRef}
        accessibilityRole="header"
        accessible
        accessibilityLabel={step.voiceOverAnnouncement ?? `${step.title}. Step ${stepIndex + 1} of ${totalSteps}.`}
        style={{ fontSize: 26, fontWeight: '800', color: colors.text, marginBottom: 10, textAlign: 'center' }}
      >
        {step.title}
      </Text>
      <Text style={{ fontSize: 16, lineHeight: 24, color: colors.textSecondary, textAlign: 'center' }}>
        {step.shortText}
      </Text>

      {step.explainMoreText && (
        explained ? (
          <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary, textAlign: 'center', marginTop: 12 }}>
            {step.explainMoreText}
          </Text>
        ) : (
          <Pressable
            onPress={() => setExplained(true)}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Explain More"
            style={({ pressed }) => ({ marginTop: 14, opacity: pressed ? 0.7 : 1 })}
          >
            <Text style={{ color: colors.accent, fontSize: 15, fontWeight: '600' }}>Explain More</Text>
          </Pressable>
        )
      )}
    </View>
  );
}
