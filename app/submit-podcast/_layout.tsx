import { useRef, useEffect } from 'react';
import { AccessibilityInfo, findNodeHandle, Text, View } from 'react-native';
import { Stack } from 'expo-router';
import { PodcastWizardProvider } from '../../src/contexts/PodcastWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useTheme } from '../../src/contexts/ThemeContext';

function SignInRequired() {
  const { colors } = useTheme();
  const ref = useRef<Text>(null);
  useEffect(() => {
    const id = setTimeout(() => {
      const node = findNodeHandle(ref.current);
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 400);
    return () => clearTimeout(id);
  }, []);
  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 32 }}>
      <Text ref={ref} accessibilityRole="header"
        style={{ fontSize: 22, fontWeight: '800', color: colors.text, textAlign: 'center', marginBottom: 12 }}>
        Sign in required
      </Text>
      <Text style={{ fontSize: 16, color: colors.textSecondary, textAlign: 'center', lineHeight: 24 }}>
        You must be signed in to submit a podcast to AppleVis.
      </Text>
    </View>
  );
}

export default function PodcastWizardLayout() {
  const { isSignedIn, isLoading } = useAuth();
  if (!isLoading && !isSignedIn) return <SignInRequired />;
  return (
    <PodcastWizardProvider>
      <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }} />
    </PodcastWizardProvider>
  );
}
