import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, findNodeHandle, Linking, Pressable, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { WizardLayout } from '../../src/components/WizardLayout';

const REGISTER_URL = 'https://www.applevis.com/user/register';

export default function SignInStep() {
  const { colors }       = useTheme();
  const auth             = useAuth();
  const { showToast }    = useToast();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [busy,     setBusy]     = useState(false);
  const usernameRef = useRef<TextInput>(null);

  // If already signed in (session restored), auto-advance.
  useEffect(() => {
    if (!auth.isLoading && auth.isSignedIn) {
      router.replace('/onboarding/theme');
    }
  }, [auth.isLoading, auth.isSignedIn]);

  // Focus username field on mount.
  useEffect(() => {
    const t = setTimeout(() => {
      const node = usernameRef.current ? findNodeHandle(usernameRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 500);
    return () => clearTimeout(t);
  }, []);

  const handleSignIn = useCallback(async () => {
    if (!username.trim()) { showToast('Please enter your username or email address.', 'error'); return; }
    if (!password)        { showToast('Please enter your password.', 'error'); return; }
    setBusy(true);
    try {
      const result = await auth.signIn(username.trim(), password);
      if (result.ok) {
        showToast(`Welcome, ${auth.user?.name ?? 'back'}!`, 'success');
        router.push('/onboarding/theme');
      } else {
        showToast(result.error ?? 'Sign in failed. Please try again.', 'error');
      }
    } catch {
      showToast('Something went wrong. Please check your connection and try again.', 'error');
    } finally {
      setBusy(false);
    }
  }, [username, password, auth, showToast]);

  const inputStyle = {
    borderWidth: 1.5, borderColor: colors.inputBorder, borderRadius: 12,
    paddingHorizontal: 14, paddingVertical: 13,
    fontSize: 17, color: colors.text, backgroundColor: colors.inputBackground,
  };

  return (
    <WizardLayout
      step={2}
      totalSteps={5}
      title="Sign in to your account"
      description="Sign in to post in the forums, follow topics, and receive push notifications."
      onNext={handleSignIn}
      nextLabel={busy ? 'Signing in…' : 'Sign In'}
      nextDisabled={busy}
    >
      {/* Benefits */}
      <View style={{ backgroundColor: colors.card, borderRadius: 14, padding: 16, marginBottom: 24, borderWidth: 1, borderColor: colors.border }}>
        <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text, marginBottom: 8 }}>
          With a free AppleVis account you can:
        </Text>
        {[
          'Post and reply in the forums',
          'Follow topics and get notified of replies',
          'Receive push notifications for new episodes, new app entries, and mentions',
          'Sync your saved items across devices via iCloud',
        ].map((item) => (
          <Text key={item} accessible accessibilityLabel={item}
            style={{ fontSize: 15, color: colors.textSecondary, marginBottom: 5, lineHeight: 22 }}>
            {'• '}{item}
          </Text>
        ))}

        {/* Sign up link */}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginTop: 10, gap: 4 }}>
          <Text style={{ fontSize: 14, color: colors.textSecondary }}>
            {"Don't have an account?"}
          </Text>
          <Pressable
            onPress={() => Linking.openURL(REGISTER_URL)}
            accessible
            accessibilityRole="link"
            accessibilityLabel="Sign up for a free AppleVis account"
            accessibilityHint="Opens the AppleVis registration page in your browser"
          >
            <Text style={{ fontSize: 14, color: colors.accent, fontWeight: '600' }}>
              Sign up for free
            </Text>
          </Pressable>
        </View>
      </View>

      {/* Username or email */}
      <View style={{ marginBottom: 14 }}>
        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
          Username or email
        </Text>
        <TextInput
          ref={usernameRef}
          value={username}
          onChangeText={setUsername}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="default"
          textContentType="username"
          returnKeyType="next"
          accessible
          accessibilityLabel="Username or email"
          accessibilityHint="Enter your AppleVis username or email address"
          style={inputStyle}
        />
      </View>

      {/* Password */}
      <View style={{ marginBottom: 20 }}>
        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
          Password
        </Text>
        <TextInput
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          textContentType="password"
          returnKeyType="go"
          onSubmitEditing={handleSignIn}
          accessible
          accessibilityLabel="Password"
          style={inputStyle}
        />
      </View>

      {busy && (
        <View style={{ alignItems: 'center', marginBottom: 16 }} accessible accessibilityLabel="Signing in, please wait">
          <ActivityIndicator color={colors.accent} />
        </View>
      )}

      {/* Skip sign-in and continue to next step */}
      <Pressable
        onPress={() => router.push('/onboarding/theme')}
        accessible
        accessibilityRole="button"
        accessibilityLabel="Next: skip sign in for now"
        accessibilityHint="You can sign in later from the Settings tab."
        style={{ alignItems: 'center', paddingVertical: 10 }}
      >
        <Text style={{ color: colors.accent, fontSize: 16, fontWeight: '600' }}>
          Skip for now — continue to next step →
        </Text>
      </Pressable>
    </WizardLayout>
  );
}
