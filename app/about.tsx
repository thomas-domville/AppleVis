import { Clipboard, Dimensions, Image, Linking, Platform, Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import Constants from 'expo-constants';
import * as Device from 'expo-device';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useToast } from '../src/contexts/ToastContext';
import { useAccessibilityPreferences } from '../src/hooks/useAccessibilityPreferences';
import { useDynamicType } from '../src/hooks/useDynamicType';
import { APPLEVIS_SOCIAL_LINKS } from '../src/data/socialLinks';

const APP_VERSION   = Constants.expoConfig?.version   ?? '2026.0.2';
const BUILD_NUMBER  = Constants.expoConfig?.ios?.buildNumber ?? '2';
const IOS_VERSION   = Platform.OS === 'ios' ? String(Platform.Version) : 'N/A';
const DEVICE_NAME   = Device.deviceName ?? 'Unknown device';
const DEVICE_MODEL  = Device.modelName  ?? 'Unknown model';
const DEVICE_TYPE   = Device.deviceType === Device.DeviceType.TABLET ? 'iPad' : 'iPhone';
const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

const BASE = 'https://www.applevis.com';

function InfoRow({ label, value, colors }: {
  label: string; value: string;
  colors: ReturnType<typeof useTheme>['colors'];
}) {
  return (
    <View
      style={{ flexDirection: 'row', justifyContent: 'space-between',
        alignItems: 'center', paddingVertical: 9,
        borderBottomWidth: 0.5, borderBottomColor: colors.border }}
      accessible
      accessibilityLabel={`${label}: ${value}`}
    >
      <Text style={{ fontSize: 15, color: colors.textSecondary }}>{label}</Text>
      <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>{value}</Text>
    </View>
  );
}

function SectionHeader({ label, colors }: { label: string; colors: ReturnType<typeof useTheme>['colors'] }) {
  return (
    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
      textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 24, marginBottom: 8 }}
      accessibilityRole="header">
      {label}
    </Text>
  );
}

export default function About() {
  const router        = useRouter();
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const a11y          = useAccessibilityPreferences();
  const dynType       = useDynamicType();

  function buildSupportInfo(): string {
    return [
      'AppleVis App Support Information',
      '--------------------------------',
      `App Version:       ${APP_VERSION} (Build ${BUILD_NUMBER})`,
      `iOS Version:       ${IOS_VERSION}`,
      `Device:            ${DEVICE_NAME} (${DEVICE_MODEL})`,
      `Device Type:       ${DEVICE_TYPE}`,
      `Screen:            ${Math.round(SCREEN_W)} x ${Math.round(SCREEN_H)} pts`,
      '',
      'Accessibility Settings',
      `VoiceOver:         ${a11y.screenReaderEnabled ? 'On' : 'Off'}`,
      `Reduce Motion:     ${a11y.reduceMotion       ? 'On' : 'Off'}`,
      `Bold Text:         ${a11y.boldText            ? 'On' : 'Off'}`,
      `Invert Colors:     ${a11y.invertColors        ? 'On' : 'Off'}`,
      `Reduce Transparency: ${a11y.reduceTransparency ? 'On' : 'Off'}`,
      `Dynamic Type Scale: ${dynType.scale.toFixed(2)}x${dynType.isAccessibilitySize ? ' (Accessibility size)' : ''}`,
      '',
      'Please include this information when reporting a bug.',
    ].join('\n');
  }

  function handleCopySupportInfo() {
    Clipboard.setString(buildSupportInfo());
    showToast('Support information copied to clipboard.', 'success');
  }

  return (
    <Screen title="About AppleVis" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        {/* Brand card */}
        <View style={[styles.card, { alignItems: 'center', paddingVertical: 28 }]}
          accessible
          accessibilityLabel={`AppleVis — a Be My Eyes company. Version ${APP_VERSION}, Build ${BUILD_NUMBER}. The premier community for blind, DeafBlind, and low vision Apple users.`}>
          <View style={{ backgroundColor: colors.card, borderRadius: 12,
            paddingHorizontal: 16, paddingVertical: 12, marginBottom: 16 }}
            accessibilityElementsHidden>
            <Image
              source={require('../assets/images/applevis-logo.png')}
              style={{ width: 200, height: 57 }}
              resizeMode="contain"
              accessibilityIgnoresInvertColors
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
          <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} />
        </Pressable>

        {/* App info */}
        <SectionHeader label="App Information" colors={colors} />
        <View style={styles.card}>
          <InfoRow label="Version"      value={APP_VERSION}    colors={colors} />
          <InfoRow label="Build"        value={BUILD_NUMBER}   colors={colors} />
          <InfoRow label="iOS"          value={IOS_VERSION}    colors={colors} />
          <InfoRow label="Device"       value={DEVICE_NAME}    colors={colors} />
          <InfoRow label="Model"        value={DEVICE_MODEL}   colors={colors} />
          <InfoRow label="Type"         value={DEVICE_TYPE}    colors={colors} />
          <InfoRow label="Screen"
            value={`${Math.round(SCREEN_W)} x ${Math.round(SCREEN_H)} pts`}
            colors={colors} />
        </View>

        {/* Accessibility info */}
        <SectionHeader label="Active Accessibility Settings" colors={colors} />
        <View style={styles.card}>
          <InfoRow label="VoiceOver"           value={a11y.screenReaderEnabled  ? 'On' : 'Off'} colors={colors} />
          <InfoRow label="Reduce Motion"       value={a11y.reduceMotion         ? 'On' : 'Off'} colors={colors} />
          <InfoRow label="Bold Text"           value={a11y.boldText             ? 'On' : 'Off'} colors={colors} />
          <InfoRow label="Invert Colors"       value={a11y.invertColors         ? 'On' : 'Off'} colors={colors} />
          <InfoRow label="Reduce Transparency" value={a11y.reduceTransparency   ? 'On' : 'Off'} colors={colors} />
          <InfoRow label="Dynamic Type Scale"
            value={`${dynType.scale.toFixed(2)}x${dynType.isAccessibilitySize ? ' (Accessibility)' : ''}`}
            colors={colors} />
        </View>

        {/* Copy support info */}
        <Pressable
          onPress={handleCopySupportInfo}
          accessible accessibilityRole="button"
          accessibilityLabel="Copy support information to clipboard"
          accessibilityHint="Copies app version, iOS version, device info, and active accessibility settings. Paste this when reporting a bug."
          style={({ pressed }) => [styles.card, {
            flexDirection: 'row', alignItems: 'center', gap: 12,
            borderColor: colors.accent, borderWidth: 1.5,
          }, pressed && { opacity: 0.85 }]}
        >
          <Ionicons name="copy-outline" size={22} color={colors.accent} />
          <View style={{ flex: 1 }}>
            <Text style={[styles.cardTitle, { color: colors.accent, marginBottom: 1 }]}>
              Copy Support Information
            </Text>
            <Text style={styles.cardMeta}>
              Copies version, iOS, device, and accessibility info to your clipboard.
              Include this when reporting a bug or contacting support.
            </Text>
          </View>
        </Pressable>

        {/* Connect */}
        <SectionHeader label="Connect With Us" colors={colors} />
        {APPLEVIS_SOCIAL_LINKS.map((link) => (
          <Pressable
            key={link.id}
            onPress={() => Linking.openURL(link.url).catch(() => showToast('Could not open link.', 'error'))}
            accessible
            accessibilityRole="link"
            accessibilityLabel={link.description}
            accessibilityHint="Opens in Safari."
            style={({ pressed }) => [styles.cardSmall, {
              flexDirection: 'row', alignItems: 'center', gap: 12,
            }, pressed && { opacity: 0.85 }]}
          >
            <Ionicons name={link.icon as any} size={20} color={colors.accent} />
            <View style={{ flex: 1 }}>
              <Text style={[styles.body, { marginBottom: 0 }]}>{link.label}</Text>
              <Text style={[styles.cardMeta, { marginTop: 1 }]}>{link.url.replace('https://', '')}</Text>
            </View>
            <Ionicons name="open-outline" size={16} color={colors.textSecondary} />
          </Pressable>
        ))}

        {/* Links */}
        <SectionHeader label="Legal & Credits" colors={colors} />
        {[
          { label: 'Privacy Policy',         hint: 'Opens applevis.com/privacy in Safari.',              url: `${BASE}/privacy`,         icon: 'shield-checkmark-outline' },
          { label: 'Terms of Use',           hint: 'Opens applevis.com/terms in Safari.',                url: `${BASE}/terms`,           icon: 'document-text-outline' },
          { label: 'Open Source Licences',   hint: 'Opens a list of open source libraries used in the app.', url: null,                 icon: 'code-slash-outline',    route: '/open-source' },
          { label: 'Credits',                hint: 'The people and contributors behind AppleVis.',        url: null,                      icon: 'people-outline',        route: '/credits' },
          { label: 'Report a Bug',           hint: 'Opens applevis.com/contact in Safari.',               url: `${BASE}/contact`,         icon: 'bug-outline' },
          { label: 'Send Feedback',          hint: 'Opens applevis.com/contact in Safari.',               url: `${BASE}/contact`,         icon: 'chatbubble-ellipses-outline' },
        ].map(({ label, hint, url, icon, route }) => (
          <Pressable
            key={label}
            onPress={() => {
              if (url) Linking.openURL(url).catch(() => showToast('Could not open link.', 'error'));
              else if (route) router.push(route as any);
            }}
            accessible accessibilityRole="button"
            accessibilityLabel={label}
            accessibilityHint={hint}
            style={({ pressed }) => [styles.cardSmall, {
              flexDirection: 'row', alignItems: 'center', gap: 12,
            }, pressed && { opacity: 0.85 }]}
          >
            <Ionicons name={icon as any} size={20} color={colors.accent} />
            <Text style={[styles.body, { flex: 1, marginBottom: 0 }]}>{label}</Text>
            <Ionicons name={url ? 'open-outline' : 'chevron-forward'} size={16} color={colors.textSecondary} />
          </Pressable>
        ))}

        {/* Footer */}
        <Text style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center',
          marginTop: 24, lineHeight: 20 }}
          accessible accessibilityLabel="Copyright 2026 AppleVis. All rights reserved.">
          © 2026 AppleVis{'\n'}
          applevis.com
        </Text>

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
