import { usePathname, useRouter } from 'expo-router';
import { Stack } from 'expo-router/stack';
import { Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '../../src/contexts/AuthContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { WizardProvider } from '../../src/contexts/SubmitWizardContext';

// ─── Progress bar ─────────────────────────────────────────────────────────────

const STEP_LABELS = ['Guidelines', 'Platform', 'Search', 'Confirm', 'Notes'];
const TOTAL = STEP_LABELS.length;

function stepFromPath(pathname: string): number {
  if (pathname.includes('/notes'))    return 5;
  if (pathname.includes('/confirm'))  return 4;
  if (pathname.includes('/search'))   return 3;
  if (pathname.includes('/platform')) return 2;
  return 1;
}

function WizardProgress() {
  const { colors }  = useTheme();
  const pathname    = usePathname();
  const currentStep = stepFromPath(pathname);

  return (
    <View
      style={{ paddingHorizontal: 16, paddingTop: 8, paddingBottom: 10, backgroundColor: colors.background }}
      accessible
      accessibilityRole="progressbar"
      accessibilityLabel={`Step ${currentStep} of ${TOTAL}: ${STEP_LABELS[currentStep - 1]}`}
      accessibilityValue={{ min: 1, max: TOTAL, now: currentStep }}
    >
      <View style={{ flexDirection: 'row', gap: 4 }}>
        {STEP_LABELS.map((label, i) => {
          const n      = i + 1;
          const done   = n < currentStep;
          const active = n === currentStep;
          return (
            <View
              key={label}
              style={{
                flex: 1,
                height: 4,
                borderRadius: 2,
                backgroundColor: done || active ? colors.accent : colors.border,
                opacity: done ? 0.5 : 1,
              }}
              accessibilityElementsHidden
            />
          );
        })}
      </View>
      <Text
        style={{ fontSize: 11, color: colors.textSecondary, marginTop: 5, textAlign: 'center', letterSpacing: 0.3 }}
        accessibilityElementsHidden
      >
        Step {currentStep} of {TOTAL} — {STEP_LABELS[currentStep - 1]}
      </Text>
    </View>
  );
}

// ─── Sign-in gate ─────────────────────────────────────────────────────────────

function SignInRequired() {
  const { colors } = useTheme();
  const router     = useRouter();
  return (
    <View style={{ flex: 1, backgroundColor: colors.background, justifyContent: 'center', alignItems: 'center', padding: 32 }}>
      <Ionicons name="lock-closed-outline" size={48} color={colors.accent} style={{ marginBottom: 20 }} />
      <Text
        style={{ fontSize: 22, fontWeight: '700', color: colors.text, textAlign: 'center', marginBottom: 10 }}
        accessibilityRole="header"
      >
        Sign In Required
      </Text>
      <Text style={{ fontSize: 16, color: colors.textSecondary, textAlign: 'center', lineHeight: 24, marginBottom: 32 }}>
        You need to be signed in to submit an app to the AppleVis directory.
      </Text>
      <Pressable
        onPress={() => router.back()}
        accessible
        accessibilityRole="button"
        accessibilityLabel="Go Back"
        style={({ pressed }) => ({
          backgroundColor: colors.accent,
          paddingHorizontal: 32,
          paddingVertical: 14,
          borderRadius: 14,
          opacity: pressed ? 0.8 : 1,
        })}
      >
        <Text style={{ color: '#fff', fontSize: 17, fontWeight: '700' }}>Go Back</Text>
      </Pressable>
    </View>
  );
}

// ─── Layout ───────────────────────────────────────────────────────────────────

export default function SubmitWizardLayout() {
  const { isSignedIn, isLoading } = useAuth();
  const { colors }                = useTheme();

  if (!isLoading && !isSignedIn) {
    return <SignInRequired />;
  }

  return (
    <WizardProvider>
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        <WizardProgress />
        <Stack
          screenOptions={{
            headerShown: false,
            animation: 'slide_from_right',
            contentStyle: { backgroundColor: colors.background },
          }}
        />
      </View>
    </WizardProvider>
  );
}
