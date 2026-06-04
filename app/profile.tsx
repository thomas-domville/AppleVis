import { Clipboard, Dimensions, Image, Linking, Platform, Pressable, ScrollView, Text, View } from 'react-native';
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

function NavRow({ label, hint, icon, onPress, external = false, colors, styles }: {
  label: string; hint?: string; icon: string; onPress: () => void;
  external?: boolean;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  return (
    <Pressable
      onPress={onPress}
      accessible accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={hint}
      style={({ pressed }) => [styles.cardSmall, {
        flexDirection: 'row', alignItems: 'center', gap: 12,
      }, pressed && { opacity: 0.85 }]}
    >
      <Ionicons name={icon as any} size={20} color={colors.accent} accessibilityElementsHidden />
      <Text style={[styles.body, { flex: 1, marginBottom: 0 }]}>{label}</Text>
      <Ionicons name={external ? 'open-outline' : 'chevron-forward'} size={16}
        color={colors.textSecondary} accessibilityElementsHidden />
    </Pressable>
  );
}

// ── About section — shown for all users ───────────────────────────────────────

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
      {/* Brand card */}
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

      {/* What's New */}
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

      {/* App info */}
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

      {/* Accessibility info */}
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

      {/* Copy support info */}
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

      {/* Legal & Credits */}
      <SectionHeader label="Legal & Credits" colors={colors} />
      <NavRow label="Privacy Policy"       icon="shield-checkmark-outline"
        hint="Opens applevis.com/privacy in Safari." external
        onPress={() => Linking.openURL(`${BASE}/privacy`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />
      <NavRow label="Terms of Use"         icon="document-text-outline"
        hint="Opens applevis.com/terms in Safari." external
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
      <NavRow label="Report a Bug"         icon="bug-outline"
        hint="Opens applevis.com/contact in Safari." external
        onPress={() => Linking.openURL(`${BASE}/contact`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />
      <NavRow label="Send Feedback"        icon="chatbubble-ellipses-outline"
        hint="Opens applevis.com/contact in Safari." external
        onPress={() => Linking.openURL(`${BASE}/contact`).catch(() => showToast('Could not open link.', 'error'))}
        colors={colors} styles={styles} />

      {/* Footer */}
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
  const router        = useRouter();
  const { colors, styles } = useTheme();
  const auth          = useAuth();
  const { showToast } = useToast();

  const savedTopics    = useSavedItems('forumTopic');
  const savedApps      = useSavedItems('appListing');
  const savedResources = useSavedItems('resource');
  const topicCount    = savedTopics.items.length;
  const appCount      = savedApps.items.length;
  const resourceCount = savedResources.items.length;

  async function handleSignOut() {
    await auth.signOut();
    showToast('Signed out.', 'success');
    router.replace('/(tabs)');
  }

  // ── Signed-out view ────────────────────────────────────────────────────────
  if (!auth.isSignedIn || !auth.user) {
    return (
      <Screen title="Profile" showSettings={false}>
        <ScrollView showsVerticalScrollIndicator={false}>
          {/* Not signed in card */}
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 28 }]}
            accessible
            accessibilityLabel="You are not signed in. Sign in to view your profile, saved items, and post history.">
            <Ionicons name="person-circle-outline" size={56} color={colors.textSecondary} accessibilityElementsHidden />
            <Text style={[styles.cardTitle, { marginTop: 12, textAlign: 'center' }]}>Not signed in</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4, marginBottom: 16 }]}>
              Sign in to see your profile, saved items, and post history.
            </Text>
            <Pressable
              onPress={() => router.push('/settings')}
              accessible accessibilityRole="button" accessibilityLabel="Go to Settings to sign in"
              style={{ backgroundColor: colors.accent, borderRadius: 12,
                paddingHorizontal: 24, paddingVertical: 12 }}
            >
              <Text style={{ color: colors.accentText, fontWeight: '700', fontSize: 15 }}>Sign In</Text>
            </Pressable>
          </View>

          {/* About section — always visible */}
          <SectionHeader label="About AppleVis" colors={colors} />
          <AboutSection colors={colors} styles={styles} showToast={showToast} router={router} />

          <View style={{ height: 96 }} />
        </ScrollView>
      </Screen>
    );
  }

  const profileUrl = `${BASE}/users/${encodeURIComponent(auth.user.name)}`;

  // ── Signed-in view ─────────────────────────────────────────────────────────
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

        {/* Saved items */}
        <SectionHeader label="Saved Items" colors={colors} />
        {[
          { label: 'Forum Topics', count: topicCount,    icon: 'chatbubbles-outline', route: '/(tabs)/forums' },
          { label: 'Apps',         count: appCount,      icon: 'apps-outline',        route: '/(tabs)/apps'   },
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

        {/* Account actions */}
        <SectionHeader label="Account" colors={colors} />

        <NavRow
          label="Account Settings on applevis.com"
          hint="Opens your account settings in Safari."
          icon="settings-outline"
          external
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

        {/* Sign out — destructive, styled separately */}
        <Pressable
          onPress={handleSignOut}
          accessible accessibilityRole="button"
          accessibilityLabel="Sign out of AppleVis"
          accessibilityHint="Removes your account session from this device."
          style={({ pressed }) => [styles.cardSmall, {
            flexDirection: 'row', alignItems: 'center', gap: 12,
            backgroundColor: '#FFF0F0', borderColor: '#FCA5A5', borderWidth: 1,
          }, pressed && { opacity: 0.85 }]}
        >
          <Ionicons name="log-out-outline" size={20} color="#B91C1C" accessibilityElementsHidden />
          <View style={{ flex: 1 }}>
            <Text style={[styles.cardTitle, { color: '#B91C1C', marginBottom: 0 }]}>Sign Out</Text>
            <Text style={styles.cardMeta}>Removes your session from this device only.</Text>
          </View>
        </Pressable>

        {/* About AppleVis */}
        <SectionHeader label="About AppleVis" colors={colors} />
        <AboutSection colors={colors} styles={styles} showToast={showToast} router={router} />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
