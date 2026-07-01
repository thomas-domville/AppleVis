import { View } from 'react-native';
import { useTheme } from '../../contexts/ThemeContext';

export function GuidedExperienceProgress({ stepIndex, totalSteps }: { stepIndex: number; totalSteps: number }) {
  const { colors } = useTheme();
  return (
    <View
      style={{ flexDirection: 'row', justifyContent: 'center', gap: 8, marginBottom: 28 }}
      accessible
      accessibilityLabel={`Step ${stepIndex + 1} of ${totalSteps}`}
    >
      {Array.from({ length: totalSteps }).map((_, i) => (
        <View
          key={i}
          style={{
            width: i === stepIndex ? 22 : 8, height: 8, borderRadius: 4,
            backgroundColor: i === stepIndex ? colors.accent : colors.border,
          }}
        />
      ))}
    </View>
  );
}
