import { useRef, useEffect } from 'react';
import { AccessibilityInfo, findNodeHandle, Text, View } from 'react-native';
import { Stack, usePathname } from 'expo-router';
import { BlogWizardProvider } from '../../src/contexts/BlogWizardContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useTheme } from '../../src/contexts/ThemeContext';

const STEPS: Record<string, number> = {
  '/submit-blog':          1,
  '/submit-blog/index':    1,
  '/submit-blog/content':  2,
  '/submit-blog/review':   3,
};

function BlogProgress() {
  const { colors } = useTheme();
  const pathname = usePathname();
  const step = STEPS[pathname] ?? 1;
  const total = 3;
  const ref = useRef<View>(null);

  return (
    <View
      ref={ref}
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
      <Text ref={ref} accessibilityRole="header" style={{ fontSize: 22, fontWeight: '800', color: colors.text, textAlign: 'center', marginBottom: 12 }}>
        Sign in required
      </Text>
      <Text style={{ fontSize: 16, color: colors.textSecondary, textAlign: 'center', lineHeight: 24 }}>
        You must be signed in to your AppleVis account to submit a blog post.
      </Text>
    </View>
  );
}

export default function BlogWizardLayout() {
  const { isSignedIn, isLoading } = useAuth();

  if (!isLoading && !isSignedIn) {
    return <SignInRequired />;
  }

  return (
    <BlogWizardProvider>
      <BlogProgress />
      <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }} />
    </BlogWizardProvider>
  );
}
