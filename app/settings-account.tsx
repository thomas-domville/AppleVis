import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, findNodeHandle, Linking,
  Pressable, ScrollView, Text, TextInput, View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';

const BASE = 'https://www.applevis.com';
const REGISTER_URL = `${BASE}/user/register`;

function SectionHeader({ label, colors }: { label: string; colors: ReturnType<typeof useTheme>['colors'] }) {
  return (
    <Text
      style={{
        fontSize: 13,
        fontWeight: '700',
        color: colors.textSecondary,
        textTransform: 'uppercase',
        letterSpacing: 0,
        marginTop: 20,
        marginBottom: 8,
      }}
      accessibilityRole="header"
    >
      {label}
    </Text>
  );
}

function StatusMessage({ message, type }: { message: string; type: 'success' | 'error' }) {
  const isError = type === 'error';
  return (
    <View
      style={{
        backgroundColor: isError ? '#FEE2E2' : '#ECFDF5',
        borderRadius: 10,
        padding: 14,
        borderWidth: 1,
        borderColor: isError ? '#FCA5A5' : '#86EFAC',
        marginBottom: 14,
        flexDirection: 'row',
        alignItems: 'flex-start',
        gap: 10,
      }}
      accessible
      accessibilityRole="alert"
      accessibilityLabel={message}
    >
      <Ionicons
        name={isError ? 'warning-outline' : 'checkmark-circle-outline'}
        size={20}
        color={isError ? '#B91C1C' : '#047857'}
        accessibilityElementsHidden
      />
      <Text
        style={{ flex: 1, fontSize: 15, color: isError ? '#B91C1C' : '#047857', lineHeight: 21 }}
        accessibilityElementsHidden
      >
        {message}
      </Text>
    </View>
  );
}

export default function SettingsAccount() {
  const router = useRouter();
  const auth = useAuth();
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const loginRef = useRef<TextInput>(null);

  useEffect(() => {
    if (auth.isSignedIn) return;
    const timer = setTimeout(() => {
      const handle = findNodeHandle(loginRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 450);
    return () => clearTimeout(timer);
  }, [auth.isSignedIn]);

  const announceStatus = useCallback((message: string, type: 'success' | 'error') => {
    setStatus({ type, message });
    showToast(message, type);
    AccessibilityInfo.announceForAccessibility(message);
  }, [showToast]);

  const handleSignIn = useCallback(async () => {
    if (!login.trim()) {
      announceStatus('Please enter your AppleVis username or email address.', 'error');
      return;
    }
    if (!password) {
      announceStatus('Please enter your AppleVis password.', 'error');
      return;
    }

    setStatus(null);
    setBusy(true);
    try {
      const result = await auth.signIn(login.trim(), password);
      if (result.ok) {
        setLogin('');
        setPassword('');
        announceStatus(`Signed in successfully as ${result.user.name}.`, 'success');
      } else {
        announceStatus(result.error, 'error');
      }
    } catch (err) {
      const message = 'Sign in failed: something went wrong in the app. Please try again.';
      announceStatus(message, 'error');
    } finally {
      setBusy(false);
    }
  }, [announceStatus, auth, login, password]);

  const handleSignOut = useCallback(async () => {
    await auth.signOut();
    announceStatus('Signed out successfully.', 'success');
  }, [announceStatus, auth]);

  const inputStyle = {
    borderWidth: 1.5,
    borderColor: colors.inputBorder,
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 13,
    fontSize: 17,
    color: colors.text,
    backgroundColor: colors.inputBackground,
  };

  return (
    <Screen title="Account" showSettings={false}>
      <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled">
        <View style={[styles.card, {
          marginBottom: 12,
          borderLeftWidth: 4,
          borderLeftColor: colors.accent,
        }]}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View
              style={{
                width: 46,
                height: 46,
                borderRadius: 12,
                backgroundColor: colors.pill,
                alignItems: 'center',
                justifyContent: 'center',
              }}
              accessibilityElementsHidden
            >
              <Ionicons name="person-circle-outline" size={26} color={colors.accent} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle} accessibilityRole="header">
                AppleVis Account
              </Text>
              <Text style={[styles.cardMeta, { lineHeight: 20 }]}>
                Sign in to post, follow topics, receive account notifications, and manage your AppleVis session.
              </Text>
            </View>
          </View>
        </View>

        {status && <StatusMessage message={status.message} type={status.type} />}

        {auth.isSignedIn && auth.user ? (
          <>
            <SectionHeader label="Signed In" colors={colors} />
            <View
              style={[styles.card, { marginBottom: 12 }]}
              accessible
              accessibilityLabel={`Signed in as ${auth.user.name}.`}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                <View
                  style={{
                    width: 44,
                    height: 44,
                    borderRadius: 22,
                    backgroundColor: colors.accent,
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                  accessibilityElementsHidden
                >
                  <Text style={{ fontSize: 20, fontWeight: '700', color: colors.accentText }}>
                    {auth.user.name.charAt(0).toUpperCase()}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>
                    {auth.user.name}
                  </Text>
                  <Text style={styles.cardMeta}>Signed in to AppleVis</Text>
                </View>
              </View>
            </View>

            <SectionHeader label="Account Actions" colors={colors} />
            <Pressable
              onPress={() => Linking.openURL(`${BASE}/user`).catch(() => announceStatus('Could not open AppleVis account settings.', 'error'))}
              accessible
              accessibilityRole="link"
              accessibilityLabel="Account settings on applevis.com"
              accessibilityHint="Opens your AppleVis account settings in Safari."
              style={({ pressed }) => [styles.cardSmall, {
                flexDirection: 'row',
                alignItems: 'center',
                gap: 12,
              }, pressed && { opacity: 0.85 }]}
            >
              <Ionicons name="open-outline" size={20} color={colors.accent} accessibilityElementsHidden />
              <Text style={[styles.body, { flex: 1, marginBottom: 0 }]}>Account Settings on applevis.com</Text>
              <Ionicons name="open-outline" size={16} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>

            <Pressable
              onPress={() => router.push('/delete-account' as any)}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Delete Account"
              accessibilityHint="Permanently deletes your AppleVis account and all associated data."
              style={({ pressed }) => [styles.cardSmall, {
                flexDirection: 'row',
                alignItems: 'center',
                gap: 12,
              }, pressed && { opacity: 0.85 }]}
            >
              <Ionicons name="trash-outline" size={20} color="#B91C1C" accessibilityElementsHidden />
              <Text style={[styles.body, { flex: 1, marginBottom: 0, color: '#B91C1C' }]}>Delete Account</Text>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>

            <Pressable
              onPress={handleSignOut}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Sign Out"
              accessibilityHint="Removes your AppleVis session from this device."
              style={({ pressed }) => [styles.cardSmall, {
                flexDirection: 'row',
                alignItems: 'center',
                gap: 12,
                backgroundColor: '#FFF0F0',
                borderColor: '#FCA5A5',
                borderWidth: 1,
              }, pressed && { opacity: 0.85 }]}
            >
              <Ionicons name="log-out-outline" size={20} color="#B91C1C" accessibilityElementsHidden />
              <Text style={[styles.body, { flex: 1, marginBottom: 0, color: '#B91C1C' }]}>Sign Out</Text>
            </Pressable>
          </>
        ) : (
          <>
          <SectionHeader label="Sign In" colors={colors} />
          <View style={[styles.card, { gap: 16 }]}>
            <View>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
                Username or email
              </Text>
              <TextInput
                ref={loginRef}
                value={login}
                onChangeText={(text) => {
                  setStatus(null);
                  setLogin(text);
                }}
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

            <View>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}>
                Password
              </Text>
              <TextInput
                value={password}
                onChangeText={(text) => {
                  setStatus(null);
                  setPassword(text);
                }}
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

            <Pressable
              onPress={handleSignIn}
              disabled={busy}
              accessible
              accessibilityRole="button"
              accessibilityLabel={busy ? 'Signing in, please wait' : 'Sign In'}
              accessibilityState={{ disabled: busy }}
              style={{
                alignItems: 'center',
                backgroundColor: busy ? colors.border : colors.accent,
                borderRadius: 10,
                padding: 14,
                minHeight: 48,
                justifyContent: 'center',
              }}
            >
              {busy ? (
                <ActivityIndicator color={colors.accentText} accessibilityElementsHidden />
              ) : (
                <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 16 }}>
                  Sign In
                </Text>
              )}
            </Pressable>

            {busy && (
              <Text
                style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center' }}
                accessible
                accessibilityLabel="Contacting the AppleVis server."
              >
                Contacting server...
              </Text>
            )}

            <Pressable
              onPress={() => Linking.openURL(REGISTER_URL).catch(() => announceStatus('Could not open the AppleVis registration page.', 'error'))}
              accessible
              accessibilityRole="link"
              accessibilityLabel="Sign up for a free AppleVis account"
              accessibilityHint="Opens the AppleVis registration page in Safari."
              style={{ alignSelf: 'center', paddingVertical: 8 }}
            >
              <Text style={{ color: colors.accent, fontSize: 15, fontWeight: '600' }}>
                Sign up for free
              </Text>
            </Pressable>
          </View>
          </>
        )}

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
