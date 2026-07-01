import { Pressable, Text, View } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '../../src/contexts/AuthContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { WizardProvider } from '../../src/contexts/SubmitWizardContext';

function SignInRequired() {
  const { colors } = useTheme();
  const router     = useRouter();
  return (
    <View style={{ flex: 1, backgroundColor: colors.background, justifyContent: 'center', alignItems: 'center', padding: 32 }}>
      <Ionicons name="lock-closed-outline" size={48} color={colors.accent} style={{ marginBottom: 20 }} />
      <Text style={{ fontSize: 22, fontWeight: '700', color: colors.text, textAlign: 'center', marginBottom: 10 }}
        accessibilityRole="header">
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
          backgroundColor: colors.accent, paddingHorizontal: 32,
          paddingVertical: 14, borderRadius: 14, opacity: pressed ? 0.8 : 1,
        })}
      >
        <Text style={{ color: '#fff', fontSize: 17, fontWeight: '700' }}>Go Back</Text>
      </Pressable>
    </View>
  );
}

export default function SubmitWizardLayout() {
  const { isSignedIn, isLoading } = useAuth();
  const { colors }                = useTheme();
  if (!isLoading && !isSignedIn) return <SignInRequired />;
  return (
    <WizardProvider>
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right', contentStyle: { backgroundColor: colors.background } }} />
      </View>
    </WizardProvider>
  );
}
