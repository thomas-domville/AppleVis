import { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Clipboard, Dimensions, findNodeHandle, Image, Linking,
  Platform, Pressable, ScrollView, Switch, Text, TextInput, View, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import Constants from 'expo-constants';
import * as Device from 'expo-device';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useAuth } from '../src/contexts/AuthContext';
import { useToast } from '../src/contexts/ToastContext';
import type { ToastType } from '../src/contexts/ToastContext';
import { useSavedItems } from '../src/hooks/useSavedItems';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { useDynamicType } from '../src/hooks/useDynamicType';

const APP_VERSION  = Constants.expoConfig?.version ?? '2026.0.1.2';
const BUILD_NUMBER = Constants.expoConfig?.ios?.buildNumber ?? '3';
const IOS_VERSION  = Platform.OS === 'ios' ? String(Platform.Version) : 'N/A';
const DEVICE_NAME  = Device.deviceName  ?? 'Unknown device';
const DEVICE_MODEL = Device.modelName   ?? 'Unknown model';
const DEVICE_TYPE  = Device.deviceType === Device.DeviceType.TABLET ? 'iPad' : 'iPhone';
const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

const BASE = 'https://www.applevis.com';

// ── Shared sub-components ─────────────────────────────────────────────────────

function SectionHeader({ label, colors }: { label: string; colors: ReturnType<typeof useTheme>['colors'] }) {
  return (
    <Text
      style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
        textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 24, marginBottom: 8 }}
      accessibilityRole="header"
    >
      {label}
    </Text>
  );
}

function InfoRow({ label, value, colors }: {
  label: string; value: string;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <View
      style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
        paddingVertical: 9, borderBottomWidth: 0.5, borderBottomColor: colors.border }}
      accessible
      accessibilityLabel={`${label}: ${value}`}
    >
      <Text style={{ fontSize: 15, color: colors.textSecondary }}>{label}</Text>
      <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{value}</Text>
    </View>
  );
}

function NavRow({ label, hint, icon, onPress, external = false, destructive = false, colors, styles }: {
  label: string; hint?: string; icon: string; onPress: () => void;
  external?: boolean; destructive?: boolean;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const color = destructive ? '#B91C1C' : colors.accent;
  return (
    <Pressable
      onPress={onPress}
      accessible accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={hint}
      style={({ pressed }) => [
        styles.cardSmall,
        { flexDirection: 'row', alignItems: 'center', gap: 12 },
        destructive && { backgroundColor: '#FFF0F0', borderColor: '#FCA5A5', borderWidth: 1 },
        pressed && { opacity: 0.85 },
      ]}
    >
      <Ionicons name={icon as any} size={20} color={color} accessibilityElementsHidden />
      <Text style={[styles.body, { flex: 1, marginBottom: 0, color: destructive ? '#B91C1C' : colors.text }]}>
        {label}
      </Text>
      <Ionicons name={external ? 'open-outline' : 'chevron-forward'} size={16}
        color={colors.textSecondary} accessibilityElementsHidden />
    </Pressable>
  );
}

// ── About section ─────────────────────────────────────────────────────────────

function AboutSection({ colors, styles, showToast, router }: {
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
  showToast: (msg: string, kind?: ToastType) => void;
  router: ReturnType<typeof useRouter>;
}) {
  const a11y    = useAccessibilityPreferences();
  const dynType = useDynamicType();

  function buildSupportInfo(): string {
    return [
      'AppleVis App Support Information',
      '--------------------------------',
      `App Version:         ${APP_VERSION} (Build ${BUILD_NUMBER})`,
      `iOS Version:         ${IOS_VERSION}`,
      `Device:              ${DEVICE_NAME} (${DEVICE_MODEL})`,
      `Device Type:         ${DEVICE_TYPE}`,
      `Screen:              ${Math.round(SCREEN_W)} x ${Math.round(SCREEN_H)} pts`,
      '',
      'Accessibility Settings',
      `VoiceOver:           ${a11y.screenReaderEnabled  ? 'On' : 'Off'}`,
      `Reduce Motion:       ${a11y.reduceMotion         ? 'On' : 'Off'}`,
      `Bold Text:           ${a11y.boldText             ? 'On' : 'Off'}`,
      `Invert Colors:       ${a11y.invertColors         ? 'On' : 'Off'}`,
      `Reduce Transparency: ${a11y.reduceTransparency   ? 'On' : 'Off'}`,
      `Dynamic Type Scale:  ${dynType.scale.toFixed(2)}x${dynType.isAccessibilitySize ? ' (Accessibility size)' : ''}`,
      '',
      'Please include this information when reporting a bug.',
    ].join('\n');
  }

  return (
    <>
      <View
        style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}
        accessible
        accessibilityLabel={`AppleVis — a Be My Eyes company. Version ${APP_VERSION}, Build ${BUILD_NUMBER}.`}
      >
        <View style={{ backgroundColor: '#ffffff', borderRadius: 12,
          paddingHorizontal: 16, paddingVertical: 12, marginBottom: 12 }}
          accessibilityElementsHidden>
          <Image
            source={require('../assets/images/applevis-logo.png')}
            style={{ width: 180, height: 52 }}
            resizeMode="contain"
          />
        </View>
        <Text style={{ fontSize: 15, color: colors.textSecondary, marginBottom: 2 }}>
          Version {APP_VERSION} (Build {BUILD_NUMBER})
        </Text>
        <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center', lineHeight: 20 }}>
          The premier community for blind, DeafBlind, and{'\n'}low vision Apple users.
        </Text>
      </View>

      <Pressable
        onPress={() => router.push('/whats-new' as any)}
        accessible accessibilityRole="button"
        accessibilityLabel="What's New in this version"
        accessibilityHint={`Shows a summary of features and changes in version ${APP_VERSION}.`}
        style={({ pressed }) => [styles.card, { flexDirection: 'row', alignItems: 'center',
          gap: 12, marginBottom: 8 }, pressed && { opacity: 0.85 }]}
      >
        <View style={{ width: 40, height: 40, borderRadius: 10,
          backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center' }}
          accessibilityElementsHidden>
          <Ionicons name="sparkles" size={20} color={colors.accentText} />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={[styles.cardTitle, { marginBottom: 1 }]}>{"What's New"}</Text>
          <Text style={styles.cardMeta}>See what changed in version {APP_VERSION}</Text>
        </View>
        <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
      </Pressable>

      <SectionHeader label="App Information" colors={colors} />
      <View style={styles.card}>
        <InfoRow label="Version" value={APP_VERSION}  colors={colors} />
        <InfoRow label="Build"   value={BUILD_NUMBER} colors={colors} />
        <InfoRow label="iOS"     value={IOS_VERSION}  colors={colors} />
        <InfoRow label="Device"  value={DEVICE_NAME}  colors={colors} />
        <InfoRow label="Model"   value={DEVICE_MODEL} colors={colors} />
        <InfoRow label="Type"    value={DEVICE_TYPE}  colors={colors} />
        <InfoRow label="Screen"
          value={`${Math.round(SCREEN_W)} × ${Math.round(SCREEN_H)} pts`}
          colors={colors} />
      </View>

      <SectionHeader label="Active Accessibility Settings" colors={colors} />
      <View style={styles.card}>
        <InfoRow label="VoiceOver"           value={a11y.screenReaderEnabled ? 'On' : 'Off'} colors={colors} />
        <InfoRow label="Reduce Motion"       value={a11y.reduceMotion        ? 'On' : 'Off'} colors={colors} />
        <InfoRow label="Bold Text"           value={a11y.boldText            ? 'On' : 'Off'} colors={colors} />
        <InfoRow label="Invert Colors"       value={a11y.invertColors        ? 'On' : 'Off'} colors={colors} />
        <InfoRow label="Reduce Transparency" value={a11y.reduceTransparency  ? 'On' : 'Off'} colors={colors} />
        <InfoRow label="Dynamic Type"
          value={`${dynType.scale.toFixed(2)}×${dynType.isAccessibilitySize ? ' (Accessibility)' : ''}`}
          colors={colors} />
      </View>

      <Pressable
        onPress={() => { Clipboard.setString(buildSupportInfo()); showToast('Support information copied.', 'success'); }}
        accessible accessibilityRole="button"
        accessibilityLabel="Copy support information to clipboard"
        accessibilityHint="Copies app version, iOS version, device info, and active accessibility settings. Paste this when reporting a bug."
        style={({ pressed }) => [styles.card, {
          flexDirection: 'row', alignItems: 'center', gap: 12,
          borderColor: colors.accent, borderWidth: 1.5,
        }, pressed && { opacity: 0.85 }]}
      >
        <Ionicons name="copy-outline" size={22} color={colors.accent} accessibilityElementsHidden />
        <View style={{ flex: 1 }}>
          <Text style={[styles.cardTitle, { color: colors.accent, marginBottom: 1 }]}>
            Copy Support Information
          </Text>
          <Text style={styles.cardMeta}>
            Copies version, iOS, device, and accessibility info. Include when reporting a bug.
          </Text>
        </View>
      </Pressable>

      <SectionHeader label="Legal & Credits" colors={colors} />
      <NavRow label="Privacy Policy"       icon="shield-checkmark-outline" external
        hint="Opens applevis.com/privacy in Safari."
        onPress={() => Linking.openURL(`${BASE}/privacy`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />
      <NavRow label="Terms of Use"         icon="document-text-outline" external
        hint="Opens applevis.com/terms in Safari."
        onPress={() => Linking.openURL(`${BASE}/terms`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />
      <NavRow label="Open Source Licences" icon="code-slash-outline"
        hint="Lists open source libraries used in the app."
        onPress={() => router.push('/open-source' as any)}
        colors={colors} styles={styles} />
      <NavRow label="Credits"              icon="people-outline"
        hint="The people and contributors behind AppleVis."
        onPress={() => router.push('/credits' as any)}
        colors={colors} styles={styles} />
      <NavRow label="Report a Bug"         icon="bug-outline" external
        hint="Opens applevis.com/contact in Safari."
        onPress={() => Linking.openURL(`${BASE}/contact`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />
      <NavRow label="Send Feedback"        icon="chatbubble-ellipses-outline" external
        hint="Opens applevis.com/contact in Safari."
        onPress={() => Linking.openURL(`${BASE}/contact`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />

      <Text
        style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center',
          marginTop: 24, lineHeight: 20 }}
        accessible
        accessibilityLabel="Copyright 2026 AppleVis. All rights reserved."
      >
        © 2026 AppleVis{'\n'}applevis.com
      </Text>
    </>
  );
}

// ── Main screen ───────────────────────────────────────────────────────────────

export default function Profile() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const auth               = useAuth();
  const { showToast }      = useToast();

  // Sign-in form state (used in signed-out view)
  const [showForm,   setShowForm]   = useState(false);
  const [email,      setEmail]      = useState('');
  const [password,   setPassword]   = useState('');
  const [signingIn,  setSigningIn]  = useState(false);
  const emailRef       = useRef<TextInput>(null);
  const signInBtnRef   = useRef<View>(null);

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

  const savedTopics    = useSavedItems('forumTopic');
  const savedApps      = useSavedItems('appListing');
  const savedResources = useSavedItems('resource');
  const topicCount    = savedTopics.items.length;
  const appCount      = savedApps.items.length;
  const resourceCount = savedResources.items.length;

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
    router.replace('/(tabs)');
  }

  const inputStyle = {
    borderWidth: 1.5, borderColor: colors.inputBorder, borderRadius: 10,
    paddingHorizontal: 14, paddingVertical: 12,
    fontSize: 17, color: colors.text, backgroundColor: colors.inputBackground,
  };

  // ── Signed-out view ──────────────────────────────────────────────────────────
  if (!auth.isSignedIn || !auth.user) {
    return (
      <Screen title="Profile" showSettings={false}>
        <ScrollView showsVerticalScrollIndicator={false}>

          {/* Not signed in / sign-in form */}
          {!showForm ? (
            <View style={[styles.card, { marginBottom: 4 }]}>
              <Text style={styles.cardTitle}>Sign In</Text>
              <Text style={[styles.cardMeta, { marginBottom: 14 }]}>
                Sign in to post, follow topics, receive notifications, and sync across devices.
              </Text>
              <View style={{ flexDirection: 'row', gap: 10 }}>
                <Pressable
                  ref={signInBtnRef}
                  onPress={() => setShowForm(true)}
                  accessible accessibilityRole="button" accessibilityLabel="Sign in to AppleVis"
                  style={{ alignSelf: 'flex-start', backgroundColor: colors.accent,
                    borderRadius: 10, paddingHorizontal: 16, paddingVertical: 10 }}
                >
                  <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 15 }}>Sign In</Text>
                </Pressable>
                <Pressable
                  onPress={() => router.push('/settings' as any)}
                  accessible accessibilityRole="button" accessibilityLabel="Open Settings"
                  style={{ backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 16, paddingVertical: 10 }}
                >
                  <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 15 }}>Settings</Text>
                </Pressable>
              </View>
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

          <SectionHeader label="Contribute to AppleVis" colors={colors} />
          <NavRow
            label="Submit a Podcast"
            hint="Opens the podcast submission form in Safari. Nominate an accessible podcast for the AppleVis directory."
            icon="mic-outline" external
            onPress={() => Linking.openURL('https://www.applevis.com/podcasts/upload').catch(() => showToast('Could not open link.', 'error'))}
            colors={colors} styles={styles}
          />
          <NavRow
            label="Submit a Blog Post"
            hint="Opens the blog submission form in Safari. Share your expertise with the AppleVis community."
            icon="create-outline" external
            onPress={() => Linking.openURL('https://www.applevis.com/form/blog-submission').catch(() => showToast('Could not open link.', 'error'))}
            colors={colors} styles={styles}
          />
          <NavRow
            label="Submit an App"
            hint="Found an accessible iOS app? Add it to the AppleVis directory with your accessibility notes."
            icon="phone-portrait-outline"
            onPress={() => router.push('/submit-app')}
            colors={colors} styles={styles}
          />

          <SectionHeader label="About AppleVis" colors={colors} />
          <AboutSection colors={colors} styles={styles} showToast={showToast} router={router} />

          <View style={{ height: 96 }} />
        </ScrollView>
      </Screen>
    );
  }

  const profileUrl = `${BASE}/users/${encodeURIComponent(auth.user.name)}`;

  // ── Signed-in view ───────────────────────────────────────────────────────────
  return (
    <Screen title="Profile" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {/* Identity card */}
        <View style={[styles.card, { marginBottom: 8 }]}
          accessible
          accessibilityLabel={`Signed in as ${auth.user.name}. AppleVis community member.`}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 14 }}>
            <View style={{ width: 52, height: 52, borderRadius: 26,
              backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center' }}
              accessibilityElementsHidden>
              <Text style={{ fontSize: 22, fontWeight: '700', color: colors.accentText }}>
                {auth.user.name.charAt(0).toUpperCase()}
              </Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 20, fontWeight: '700', color: colors.text }}>{auth.user.name}</Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary }}>AppleVis community member</Text>
            </View>
          </View>
          <Pressable
            onPress={() => Linking.openURL(profileUrl)}
            accessible accessibilityRole="button"
            accessibilityLabel="View full profile on applevis.com"
            accessibilityHint="Opens your AppleVis profile page in Safari."
            style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
              backgroundColor: colors.pill, borderRadius: 8,
              paddingHorizontal: 12, paddingVertical: 8, alignSelf: 'flex-start' }}
          >
            <Ionicons name="open-outline" size={14} color={colors.pillText} accessibilityElementsHidden />
            <Text style={{ color: colors.pillText, fontWeight: '600', fontSize: 13 }}>View on applevis.com</Text>
          </Pressable>
        </View>

        {/* Settings entry point */}
        <Pressable
          onPress={() => router.push('/settings' as any)}
          accessible accessibilityRole="button"
          accessibilityLabel="Settings"
          accessibilityHint="Opens Appearance, Accessibility, Notifications, Podcasts, and all other app settings."
          style={({ pressed }) => [styles.card, { flexDirection: 'row', alignItems: 'center',
            gap: 12, marginBottom: 8 }, pressed && { opacity: 0.85 }]}
        >
          <View style={{ width: 40, height: 40, borderRadius: 10,
            backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center' }}
            accessibilityElementsHidden>
            <Ionicons name="settings-outline" size={20} color={colors.accent} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.cardTitle}>Settings</Text>
            <Text style={styles.cardMeta}>Appearance, Accessibility, Notifications, Podcasts, and more</Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        {/* Saved items */}
        <SectionHeader label="Saved Items" colors={colors} />
        {[
          { label: 'Forum Topics', count: topicCount,    icon: 'chatbubbles-outline', route: '/(tabs)/forums'    },
          { label: 'Apps',         count: appCount,      icon: 'apps-outline',        route: '/(tabs)/apps'      },
          { label: 'Resources',    count: resourceCount, icon: 'library-outline',     route: '/(tabs)/resources' },
        ].map(({ label, count, icon, route }) => (
          <Pressable
            key={label}
            onPress={() => router.push(route as any)}
            accessible accessibilityRole="button"
            accessibilityLabel={`${label}: ${count} saved. Tap to view.`}
            style={({ pressed }) => [styles.card, { marginBottom: 8 }, pressed && { opacity: 0.85 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <Ionicons name={icon as any} size={22} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }}>
                <Text style={styles.cardTitle}>{label}</Text>
                <Text style={styles.cardMeta}>{count} saved</Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} accessibilityElementsHidden />
            </View>
          </Pressable>
        ))}

        {/* Contribute */}
        <SectionHeader label="Contribute to AppleVis" colors={colors} />
        <NavRow
          label="Submit a Podcast"
          hint="Opens the podcast submission form in Safari. Nominate an accessible podcast for the AppleVis directory."
          icon="mic-outline" external
          onPress={() => Linking.openURL('https://www.applevis.com/podcasts/upload').catch(() => showToast('Could not open link.', 'error'))}
          colors={colors} styles={styles}
        />
        <NavRow
          label="Submit a Blog Post"
          hint="Opens the blog submission form in Safari. Share your expertise with the AppleVis community."
          icon="create-outline" external
          onPress={() => Linking.openURL('https://www.applevis.com/form/blog-submission').catch(() => showToast('Could not open link.', 'error'))}
          colors={colors} styles={styles}
        />
        <NavRow
          label="Submit an App"
          hint="Found an accessible iOS app? Add it to the AppleVis directory with your accessibility notes."
          icon="phone-portrait-outline"
          onPress={() => router.push('/submit-app')}
          colors={colors} styles={styles}
        />

        {/* Account */}
        <SectionHeader label="Account" colors={colors} />
        <NavRow
          label="Account Settings on applevis.com"
          hint="Opens your account settings in Safari."
          icon="settings-outline" external
          onPress={() => Linking.openURL(`${BASE}/user`).catch(() => showToast('Could not open link.', 'error'))}
          colors={colors} styles={styles}
        />
        <NavRow
          label="Delete Account"
          hint="Permanently deletes your AppleVis account and all associated data."
          icon="trash-outline"
          onPress={() => router.push('/delete-account' as any)}
          colors={colors} styles={styles}
        />
        <NavRow
          label="Sign Out"
          hint="Removes your account session from this device only."
          icon="log-out-outline"
          destructive
          onPress={handleSignOut}
          colors={colors} styles={styles}
        />

        {/* About */}
        <SectionHeader label="About AppleVis" colors={colors} />
        <AboutSection colors={colors} styles={styles} showToast={showToast} router={router} />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
