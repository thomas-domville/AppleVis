import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable, ScrollView, Text, TextInput, View } from 'react-native';

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour >= 5  && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 22) return 'Good evening';
  return 'Good night';
}
import { useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import { useFocusRestore } from '../src/hooks/useFocusRestore';
import { settingsSections } from '../src/data/settings';
import { useTheme } from '../src/contexts/ThemeContext';

export default function Settings() {
  const { colors, styles } = useTheme();
  const router = useRouter();
  const auth = useAuth();
  const { showToast } = useToast();
  const { save } = useFocusRestore();

  const [showForm, setShowForm]   = useState(false);
  const [email, setEmail]         = useState('');
  const [password, setPassword]   = useState('');
  const [signingIn, setSigningIn] = useState(false);
  const emailRef      = useRef<TextInput>(null);
  const signInBtnRef  = useRef<View>(null);
  const storageRef    = useRef<View>(null);
  const sectionRefs   = useRef<Map<string, View>>(new Map());

  const restoreToSignInBtn = useCallback(() => {
    setTimeout(() => {
      const handle = signInBtnRef.current ? findNodeHandle(signInBtnRef.current) : null;
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, []);

  // Move VoiceOver focus to the email field when the form expands
  useEffect(() => {
    if (!showForm) return;
    const timer = setTimeout(() => {
      const node = emailRef.current ? findNodeHandle(emailRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 150);
    return () => clearTimeout(timer);
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

  return (
    <Screen title="Settings" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic">

        {/* ── Account card ────────────────────────────────────────────── */}
        {auth.isLoading ? (
          <View style={[styles.card, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 4 }]}>
            <ActivityIndicator color={colors.appleVisBlue} />
            <Text style={styles.cardMeta}>Checking account…</Text>
          </View>
        ) : auth.isSignedIn ? (
          /* Signed-in */
          <View style={[styles.card, { marginBottom: 4 }]}>
            <Text style={[styles.cardMeta, { marginBottom: 2 }]}>{getGreeting()}</Text>
            <Text style={styles.cardTitle}>{auth.user?.name}</Text>
            <Text style={[styles.cardMeta, { marginBottom: 14 }]}>Signed in to AppleVis</Text>
            <Pressable
              onPress={handleSignOut}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Sign out of AppleVis"
              accessibilityHint="Removes your account from this device."
              style={{
                alignSelf: 'flex-start',
                backgroundColor: '#FFEAEA',
                borderRadius: 10,
                paddingHorizontal: 16,
                paddingVertical: 10,
              }}
            >
              <Text style={{ color: '#B91C1C', fontWeight: '700', fontSize: 15 }}>Sign Out</Text>
            </Pressable>
          </View>
        ) : !showForm ? (
          /* Signed-out summary */
          <View style={[styles.card, { marginBottom: 4 }]}>
            <Text style={styles.cardTitle}>Sign In</Text>
            <Text style={[styles.cardMeta, { marginBottom: 14 }]}>
              Sign in with your AppleVis account to follow topics, receive push
              notifications, and sync your reading position across devices.
            </Text>
            <Pressable
              ref={signInBtnRef}
              onPress={() => setShowForm(true)}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Sign in to AppleVis"
              style={{
                alignSelf: 'flex-start',
                backgroundColor: colors.appleVisBlue,
                borderRadius: 10,
                paddingHorizontal: 16,
                paddingVertical: 10,
              }}
            >
              <Text style={{ color: '#FFFFFF', fontWeight: '700', fontSize: 15 }}>Sign In</Text>
            </Pressable>
          </View>
        ) : (
          /* Inline sign-in form */
          <View style={[styles.card, { gap: 16, marginBottom: 4 }]}>
            <Text style={styles.cardTitle} accessibilityRole="header">Sign In</Text>

            <View>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}
                importantForAccessibility="no-hide-descendants">
                Email
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
                style={{
                  borderWidth: 1.5, borderColor: colors.border, borderRadius: 10,
                  paddingHorizontal: 14, paddingVertical: 12,
                  fontSize: 17, color: colors.text, backgroundColor: '#FAFAFA',
                }}
              />
            </View>

            <View>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}
                importantForAccessibility="no-hide-descendants">
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
                style={{
                  borderWidth: 1.5, borderColor: colors.border, borderRadius: 10,
                  paddingHorizontal: 14, paddingVertical: 12,
                  fontSize: 17, color: colors.text, backgroundColor: '#FAFAFA',
                }}
              />
            </View>

            <View style={{ flexDirection: 'row', gap: 10 }}>
              <Pressable
                onPress={handleSignIn}
                disabled={signingIn}
                accessible
                accessibilityRole="button"
                accessibilityLabel={signingIn ? 'Signing in, please wait' : 'Sign in'}
                accessibilityState={{ disabled: signingIn }}
                style={{
                  flex: 1, alignItems: 'center',
                  backgroundColor: signingIn ? '#A0C4FF' : colors.appleVisBlue,
                  borderRadius: 10, padding: 13,
                }}
              >
                {signingIn
                  ? <ActivityIndicator color="#FFF" />
                  : <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 15 }}>Sign In</Text>
                }
              </Pressable>

              <Pressable
                onPress={() => { setShowForm(false); setEmail(''); setPassword(''); restoreToSignInBtn(); }}
                accessible
                accessibilityRole="button"
                accessibilityLabel="Cancel sign in"
                style={{
                  alignItems: 'center', backgroundColor: '#F3F4F6',
                  borderRadius: 10, padding: 13, paddingHorizontal: 18,
                }}
              >
                <Text style={{ color: colors.text, fontWeight: '600', fontSize: 15 }}>Cancel</Text>
              </Pressable>
            </View>

            <Text style={[styles.cardMeta, { textAlign: 'center' }]}>
              Use your AppleVis website email and password.
            </Text>
          </View>
        )}

        {/* ── Settings sections ────────────────────────────────────────── */}
        <Text style={styles.lede}>
          Settings are grouped so VoiceOver users do not have to swipe through one long list of switches.
        </Text>

        {settingsSections.map((section) => (
          <Pressable
            key={section.title}
            ref={(el) => {
              if (el) sectionRefs.current.set(section.title, el);
              else sectionRefs.current.delete(section.title);
            }}
            onPress={() => {
              save(sectionRefs.current.get(section.title) ?? null);
              router.push({ pathname: '/settings-detail', params: { title: section.title } });
            }}
            accessible
            accessibilityRole="button"
            accessibilityLabel={`${section.title}. ${section.description}`}
            accessibilityHint="Opens this settings category."
            style={styles.card}
          >
            <Text style={styles.cardTitle}>{section.title}</Text>
            <Text style={styles.cardMeta}>{section.description}</Text>
          </Pressable>
        ))}

        {/* ── Storage & Cache ──────────────────────────────────────────── */}
        <Pressable
          ref={storageRef}
          onPress={() => {
            save(storageRef.current);
            router.push('/storage');
          }}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Storage and Cache. Manage downloads, cached content, and retention policy."
          accessibilityHint="Opens Storage and Cache settings."
          style={[styles.card, { marginTop: 8 }]}
        >
          <Text style={styles.cardTitle}>Storage & Cache</Text>
          <Text style={styles.cardMeta}>Manage downloads, cached content, and retention policy.</Text>
        </Pressable>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
