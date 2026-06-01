import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { useTheme } from '../src/contexts/ThemeContext';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { SETTINGS_SECTIONS } from '../src/data/settingsData';

function getGreeting(): string {
  const h = new Date().getHours();
  if (h >= 5  && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 22) return 'Good evening';
  return 'Good night';
}

export default function Settings() {
  const router        = useRouter();
  const auth          = useAuth();
  const { showToast } = useToast();
  const { colors, styles } = useTheme();
  const { save }      = useFocusRestore();

  const [showForm, setShowForm]   = useState(false);
  const [email,    setEmail]      = useState('');
  const [password, setPassword]   = useState('');
  const [signingIn, setSigningIn] = useState(false);
  const emailRef     = useRef<TextInput>(null);
  const signInBtnRef = useRef<View>(null);
  const sectionRefs  = useRef<Map<string, View>>(new Map());

  const restoreToSignInBtn = useCallback(() => {
    setTimeout(() => {
      const handle = signInBtnRef.current ? findNodeHandle(signInBtnRef.current) : null;
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, []);

  useEffect(() => {
    if (!showForm) return;
    const t = setTimeout(() => {
      const node = emailRef.current ? findNodeHandle(emailRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 150);
    return () => clearTimeout(t);
  }, [showForm]);

  async function handleSignIn() {
    if (!email.trim()) { showToast('Please enter your email address.', 'error'); return; }
    if (!password)      { showToast('Please enter your password.', 'error'); return; }
    setSigningIn(true);
    const result = await auth.signIn(email, password);
    setSigningIn(false);
    if (result.ok) {
      showToast(`Welcome back, ${auth.user?.name ?? 'you'}!`, 'success');
      setEmail(''); setPassword(''); setShowForm(false);
    } else {
      showToast(result.error ?? 'Sign in failed.', 'error');
    }
  }

  async function handleSignOut() {
    await auth.signOut();
    showToast('Signed out.', 'success');
  }

  const inputStyle = {
    borderWidth: 1.5, borderColor: colors.inputBorder, borderRadius: 10,
    paddingHorizontal: 14, paddingVertical: 12,
    fontSize: 17, color: colors.text, backgroundColor: colors.inputBackground,
  };

  return (
    <Screen title="Settings" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">

        {/* Account card */}
        {auth.isLoading ? (
          <View style={[styles.card, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 4 }]}>
            <ActivityIndicator color={colors.accent} />
            <Text style={styles.cardMeta}>Checking account…</Text>
          </View>
        ) : auth.isSignedIn ? (
          <View style={[styles.card, { marginBottom: 4 }]}>
            <Text style={[styles.cardMeta, { marginBottom: 2 }]}>{getGreeting()}</Text>
            <Text style={styles.cardTitle}>{auth.user?.name}</Text>
            <Text style={[styles.cardMeta, { marginBottom: 14 }]}>Signed in to AppleVis</Text>
            <Pressable
              onPress={handleSignOut}
              accessible accessibilityRole="button"
              accessibilityLabel="Sign out of AppleVis"
              accessibilityHint="Removes your account session from this device."
              style={{ alignSelf: 'flex-start', backgroundColor: '#FFEAEA',
                borderRadius: 10, paddingHorizontal: 16, paddingVertical: 10 }}
            >
              <Text style={{ color: '#B91C1C', fontWeight: '700', fontSize: 15 }}>Sign Out</Text>
            </Pressable>
          </View>
        ) : !showForm ? (
          <View style={[styles.card, { marginBottom: 4 }]}>
            <Text style={styles.cardTitle}>Sign In</Text>
            <Text style={[styles.cardMeta, { marginBottom: 14 }]}>
              Sign in to post, follow topics, receive notifications, and sync across devices.
            </Text>
            <Pressable
              ref={signInBtnRef}
              onPress={() => setShowForm(true)}
              accessible accessibilityRole="button" accessibilityLabel="Sign in to AppleVis"
              style={{ alignSelf: 'flex-start', backgroundColor: colors.accent,
                borderRadius: 10, paddingHorizontal: 16, paddingVertical: 10 }}
            >
              <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 15 }}>Sign In</Text>
            </Pressable>
          </View>
        ) : (
          <View style={[styles.card, { gap: 16, marginBottom: 4 }]}>
            <Text style={styles.cardTitle} accessibilityRole="header">Sign In</Text>
            <View>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}
                importantForAccessibility="no-hide-descendants">Email</Text>
              <TextInput ref={emailRef} value={email} onChangeText={setEmail}
                autoCapitalize="none" autoCorrect={false} keyboardType="email-address"
                textContentType="emailAddress" returnKeyType="next"
                accessible accessibilityLabel="Email address" style={inputStyle} />
            </View>
            <View>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}
                importantForAccessibility="no-hide-descendants">Password</Text>
              <TextInput value={password} onChangeText={setPassword} secureTextEntry
                textContentType="password" returnKeyType="go" onSubmitEditing={handleSignIn}
                accessible accessibilityLabel="Password" style={inputStyle} />
            </View>
            <View style={{ flexDirection: 'row', gap: 10 }}>
              <Pressable onPress={handleSignIn} disabled={signingIn}
                accessible accessibilityRole="button"
                accessibilityLabel={signingIn ? 'Signing in, please wait' : 'Sign in'}
                accessibilityState={{ disabled: signingIn }}
                style={{ flex: 1, alignItems: 'center',
                  backgroundColor: signingIn ? colors.border : colors.accent,
                  borderRadius: 10, padding: 13 }}>
                {signingIn
                  ? <ActivityIndicator color={colors.accentText} />
                  : <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 15 }}>Sign In</Text>}
              </Pressable>
              <Pressable
                onPress={() => { setShowForm(false); setEmail(''); setPassword(''); restoreToSignInBtn(); }}
                accessible accessibilityRole="button" accessibilityLabel="Cancel sign in"
                style={{ alignItems: 'center', backgroundColor: colors.pill,
                  borderRadius: 10, padding: 13, paddingHorizontal: 18 }}>
                <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 15 }}>Cancel</Text>
              </Pressable>
            </View>
            <Text style={[styles.cardMeta, { textAlign: 'center' }]}>
              Use your applevis.com email and password.
            </Text>
          </View>
        )}

        <Text style={[styles.lede, { marginTop: 8 }]}>
          Every setting includes a full description and example — tap any section to read them.
        </Text>

        {SETTINGS_SECTIONS.map((section) => (
          <Pressable
            key={section.id}
            ref={(el) => {
              if (el) sectionRefs.current.set(section.id, el);
              else sectionRefs.current.delete(section.id);
            }}
            onPress={() => {
              save(sectionRefs.current.get(section.id) ?? null);
              router.push({ pathname: '/settings-detail', params: { sectionId: section.id } });
            }}
            accessible
            accessibilityRole="button"
            accessibilityLabel={`${section.title}. ${section.description}`}
            accessibilityHint="Opens this settings section."
            style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <Ionicons name={section.icon as any} size={22} color={colors.accent} />
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle}>{section.title}</Text>
                <Text style={styles.cardMeta}>{section.description}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} />
            </View>
          </Pressable>
        ))}

        {/* Storage & Cache — separate because it has destructive actions */}
        <Pressable
          onPress={() => router.push('/storage')}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Storage and Cache. Manage downloads, cached content, and data retention."
          accessibilityHint="Opens Storage and Cache settings."
          style={({ pressed }) => [styles.card, { marginTop: 8 }, pressed && { opacity: 0.85 }]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Ionicons name="server-outline" size={22} color={colors.accent} />
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle}>Storage & Cache</Text>
              <Text style={styles.cardMeta}>Manage downloads, cached content, and data retention policy.</Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} />
          </View>
        </Pressable>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
