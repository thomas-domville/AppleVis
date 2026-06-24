import { Stack, usePathname } from 'expo-router';
import { View } from 'react-native';
import { ContactWizardProvider } from '../../src/contexts/ContactWizardContext';
import { useTheme } from '../../src/contexts/ThemeContext';

const STEPS: Record<string, number> = {
  '/contact':         1,
  '/contact/index':   1,
  '/contact/compose': 2,
  '/contact/review':  3,
};

function ContactProgress() {
  const { colors } = useTheme();
  const pathname   = usePathname();
  const step       = STEPS[pathname] ?? 1;
  const total      = 3;

  return (
    <View
      style={{ flexDirection: 'row', gap: 6, paddingHorizontal: 20, paddingVertical: 10 }}
      accessible
      accessibilityRole="progressbar"
      accessibilityLabel={`Step ${step} of ${total}`}
      accessibilityValue={{ min: 1, max: total, now: step }}
    >
      {Array.from({ length: total }, (_, i) => (
        <View
          key={i}
          style={{
            flex: 1, height: 4, borderRadius: 2,
            backgroundColor: i < step ? colors.accent : colors.border,
          }}
          accessible={false}
        />
      ))}
    </View>
  );
}

export default function ContactLayout() {
  return (
    <ContactWizardProvider>
      <ContactProgress />
      <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }} />
    </ContactWizardProvider>
  );
}
