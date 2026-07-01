import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, findNodeHandle, Linking, Pressable, Text, TextInput, useColorScheme, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { ALERTS } from '../../src/data/alertMessages';
import { WizardLayout } from '../../src/components/WizardLayout';

const REGISTER_URL = 'https://www.applevis.com/user/register';

export default function SignInStep() {
  const { colors }       = useTheme();
  const colorScheme      = useColorScheme();
  const auth             = useAuth();
  const { showToast }    = useToast();
  const { showAlert }    = useAlert();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [busy,     setBusy]     = useState(false);
  const [signInError, setSignInError] = useState<string | null>(null);
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
    if (!username.trim()) {
      const msg = 'Please enter your AppleVis username or email address.';
      setSignInError(msg);
      showToast(msg, 'error');
      AccessibilityInfo.announceForAccessibility(msg);
      return;
    }
    if (!password) {
      const msg = 'Please enter your AppleVis password.';
      setSignInError(msg);
      showToast(msg, 'error');
      AccessibilityInfo.announceForAccessibility(msg);
      return;
    }
    setSignInError(null);
    setBusy(true);
    try {
      const result = await auth.signIn(username.trim(), password);
      if (result.ok) {
        const msg = `Signed in successfully as ${result.user.name}.`;
        showToast(msg, 'success');
        AccessibilityInfo.announceForAccessibility(msg);
        router.push('/onboarding/theme');
      } else {
        setSignInError(result.error);
        showAlert(ALERTS.auth.signInFailed(result.error));
      }
    } catch (err) {
      const msg = 'Something went wrong in the app. Please try again.';
      setSignInError(msg);
      showAlert(ALERTS.auth.signInFailed(msg));
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
      totalSteps={6}
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
          <View key={item} style={{ flexDirection: 'row', gap: 10, marginBottom: 7, alignItems: 'flex-start' }}
            accessible accessibilityLabel={item}>
            <Ionicons name="checkmark" size={16} color={colors.accent}
              style={{ marginTop: 3 }} accessibilityElementsHidden />
            <Text style={{ flex: 1, fontSize: 15, color: colors.textSecondary, lineHeight: 22 }}>{item}</Text>
          </View>
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
          onChangeText={(t) => { setSignInError(null); setUsername(t); }}
          placeholder="Enter your username or email address"
          placeholderTextColor={colors.textSecondary}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="default"
          textContentType="username"
          returnKeyType="next"
          accessible
          accessibilityLabel="Username or email address"
          accessibilityHint="Enter your AppleVis username or email address. Both are accepted."
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
          onChangeText={(t) => { setSignInError(null); setPassword(t); }}
          secureTextEntry
          autoCapitalize="none"
          autoCorrect={false}
          textContentType="password"
          returnKeyType="go"
          onSubmitEditing={handleSignIn}
          accessible
          accessibilityLabel="Password"
          style={inputStyle}
        />
      </View>

      {/* Inline error — stays visible even when keyboard is up */}
      {signInError && (
        <View
          style={{
            backgroundColor: colorScheme === 'dark' ? 'rgba(185,28,28,0.15)' : '#FEE2E2',
            borderRadius: 10, padding: 14,
            borderWidth: 1,
            borderColor: colorScheme === 'dark' ? 'rgba(185,28,28,0.40)' : '#FCA5A5',
            marginBottom: 14,
            flexDirection: 'row', alignItems: 'flex-start', gap: 10,
          }}
          accessible
          accessibilityRole="alert"
          accessibilityLabel={signInError}
        >
          <Ionicons name="warning" size={18}
            color={colorScheme === 'dark' ? '#FCA5A5' : '#B91C1C'}
            accessibilityElementsHidden />
          <Text style={{ flex: 1, fontSize: 15,
            color: colorScheme === 'dark' ? '#FCA5A5' : '#B91C1C', lineHeight: 21 }}
            accessibilityElementsHidden>
            {signInError}
          </Text>
        </View>
      )}

      {busy && (
        <View style={{ alignItems: 'center', marginBottom: 16 }} accessible accessibilityLabel="Signing in, please wait">
          <ActivityIndicator color={colors.accent} />
          <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 6 }}
            accessibilityElementsHidden>
            Contacting server…
          </Text>
        </View>
      )}

      {/* Skip sign-in and continue to next step */}
      <Pressable
        onPress={() => router.push('/onboarding/theme')}
        accessible
        accessibilityRole="button"
        accessibilityLabel="Next: skip sign in for now"
        accessibilityHint="You can sign in later from the Profile tab."
        style={{ alignItems: 'center', paddingVertical: 10 }}
      >
        <Text style={{ color: colors.accent, fontSize: 16, fontWeight: '600' }}>
          Skip for now — continue to next step →
        </Text>
      </Pressable>
    </WizardLayout>
  );
}
