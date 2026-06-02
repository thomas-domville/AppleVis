import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useToast } from '../../src/contexts/ToastContext';
import { WizardLayout } from '../../src/components/WizardLayout';

export default function SignInStep() {
  const { colors }       = useTheme();
  const auth             = useAuth();
  const { showToast }    = useToast();
  const [email,    setEmail]    = useState('');
  const [password, setPassword] = useState('');
  const [busy,     setBusy]     = useState(false);
  const emailRef = useRef<TextInput>(null);

  // If already signed in (session restored), auto-advance.
  useEffect(() => {
    if (!auth.isLoading && auth.isSignedIn) {
      router.replace('/onboarding/theme');
    }
  }, [auth.isLoading, auth.isSignedIn]);

  // Focus email field on mount.
  useEffect(() => {
    const t = setTimeout(() => {
      const node = emailRef.current ? findNodeHandle(emailRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 500);
    return () => clearTimeout(t);
  }, []);

  const handleSignIn = useCallback(async () => {
    if (!email.trim()) { showToast('Please enter your email address.', 'error'); return; }
    if (!password)     { showToast('Please enter your password.', 'error'); return; }
    setBusy(true);
    const result = await auth.signIn(email, password);
    setBusy(false);
    if (result.ok) {
      showToast(`Welcome, ${auth.user?.name ?? 'you'}!`, 'success');
      router.push('/onboarding/theme');
    } else {
      showToast(result.error ?? 'Sign in failed. Please try again.', 'error');
    }
  }, [email, password, auth, showToast]);

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
      description="Sign in to post in the forums, follow topics, and receive push notifications. You can also continue as a guest and sign in later from Settings."
      onNext={handleSignIn}
      nextLabel={busy ? 'Signing in…' : 'Sign In'}
      nextDisabled={busy}
    >
      {/* What signing in unlocks */}
      <View style={{ backgroundColor: colors.card, borderRadius: 14, padding: 16, marginBottom: 24, borderWidth: 1, borderColor: colors.border }}>
        <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text, marginBottom: 8 }}>
          With an account you can:
        </Text>
        {[
          'Post and reply in the forums',
          'Follow topics and get notified of replies',
          'Receive push notifications for new episodes, app updates, and mentions',
          'Sync your saved items across devices via iCloud',
        ].map((item) => (
          <Text key={item} accessible accessibilityLabel={item}
            style={{ fontSize: 15, color: colors.textSecondary, marginBottom: 5, lineHeight: 22 }}>
            {'• '}{item}
          </Text>
        ))}
        <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 6 }}>
          {"Don't have an account? Visit applevis.com to register — it's free."}
        </Text>
      </View>

      {/* Email */}
      <View style={{ marginBottom: 14 }}>
        <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
          Email address
        </Text>
        <TextInput
          ref={emailRef}
          value={email}
          onChangeText={setEmail}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="email-address"
          textContentType="emailAddress"
          returnKeyType="next"
          accessible
          accessibilityLabel="Email address"
          accessibilityHint="Enter the email address you use on applevis.com"
          style={inputStyle}
        />
      </View>

      {/* Password */}
      <View style={{ marginBottom: 24 }}>
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
        <View style={{ alignItems: 'center', marginBottom: 16 }}>
          <ActivityIndicator color={colors.accent} />
        </View>
      )}

      {/* Continue without signing in */}
      <Pressable
        onPress={() => router.push('/onboarding/theme')}
        accessible
        accessibilityRole="button"
        accessibilityLabel="Continue without signing in"
        accessibilityHint="You can sign in later from the Settings tab."
        style={{ alignItems: 'center', paddingVertical: 4 }}
      >
        <Text style={{ color: colors.accent, fontSize: 16, fontWeight: '600' }}>
          Continue without signing in
        </Text>
      </Pressable>
    </WizardLayout>
  );
}
