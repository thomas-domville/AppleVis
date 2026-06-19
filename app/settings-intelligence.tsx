import React, { useEffect, useState } from 'react';
import { Alert, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { icloudStorage } from '../src/services/icloudStorage';
import * as Device from 'expo-device';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../src/contexts/ContextualTipContext';
import { readAloud, translateContent, isAppleIntelligenceAvailable } from '../src/services/intelligenceService';

// ─── Local helpers ────────────────────────────────────────────────────────────

type BadgeVariant = 'live' | 'ios' | 'system';

const BADGE_COLORS: Record<BadgeVariant, { bg: string; text: string }> = {
  live:   { bg: '#D1FAE5', text: '#065F46' },
  ios:    { bg: '#E0E7FF', text: '#3730A3' },
  system: { bg: '#FEF3C7', text: '#92400E' },
};

function Badge({ label, variant }: { label: string; variant: BadgeVariant }) {
  const c = BADGE_COLORS[variant];
  return (
    <View style={{ backgroundColor: c.bg, borderRadius: 6, paddingHorizontal: 8, paddingVertical: 2 }}>
      <Text style={{ fontSize: 12, fontWeight: '700', color: c.text }}>{label}</Text>
    </View>
  );
}

function SectionLabel({ children }: { children: string }) {
  const { colors } = useTheme();
  return (
    <Text
      accessibilityRole="header"
      style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
        textTransform: 'uppercase', letterSpacing: 0, marginBottom: 12, marginTop: 8 }}
    >
      {children}
    </Text>
  );
}

function FeatureCard({
  icon, title, badge, badgeVariant = 'ios', description, onPress, children,
}: {
  icon: string;
  title: string;
  badge: string;
  badgeVariant?: BadgeVariant;
  description: string;
  onPress?: () => void;
  children?: React.ReactNode;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole={onPress ? 'button' : 'none'}
      accessibilityLabel={`${title}. ${badge}. ${description}`}
      accessibilityHint={onPress ? 'Double tap for more information' : undefined}
      style={({ pressed }) => [styles.card, { marginBottom: 14, opacity: pressed && onPress ? 0.85 : 1 }]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <Ionicons name={icon as any} size={20} color={colors.accent} accessibilityElementsHidden />
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, flex: 1 }}>{title}</Text>
        <Badge label={badge} variant={badgeVariant} />
      </View>
      <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 21, marginBottom: children ? 12 : 0 }}>
        {description}
      </Text>
      {children}
    </Pressable>
  );
}

function TryButton({ label, onPress }: { label: string; onPress: () => void }) {
  const { colors } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      style={({ pressed }) => ({
        backgroundColor: colors.appleVisBlue, borderRadius: 8,
        paddingHorizontal: 16, paddingVertical: 9, alignSelf: 'flex-start',
        opacity: pressed ? 0.75 : 1,
      })}
    >
      <Text style={{ color: '#FFFFFF', fontSize: 14, fontWeight: '700' }}>{label}</Text>
    </Pressable>
  );
}

function nativeAlert(feature: string, requirement: string) {
  Alert.alert(
    feature,
    `This feature requires ${requirement}.\n\nThe interface is fully wired and will activate automatically once the native module is integrated into the build.`,
    [{ text: 'Got it' }],
  );
}

// ─── Apple Intelligence device / state helpers ────────────────────────────────

const AI_HINT_KEY = 'applevis:ai_hint_dismissed';

// iPhone 15 Pro (A17 Pro) / iPhone 16 series (A18/A18 Pro) / iPad Pro M4 / iPad Air M2 2024+
// Real devices have modelId like "iPhone17,1"; simulator returns "x86_64" or "arm64" (no comma).
function isAICapableDevice(): boolean {
  const id = Device.modelId ?? '';
  if (!id.includes(',')) return false; // simulator / dev build
  const iPhoneNum = parseInt(id.match(/^iPhone(\d+)/)?.[1] ?? '0', 10);
  const iPadNum   = parseInt(id.match(/^iPad(\d+)/)?.[1] ?? '0', 10);
  // iPhone 15 Pro+ (model 16) and iPhone 16 series (model 17), but NOT iPhone 16e (iPhone17,5 = A16)
  if (iPhoneNum >= 16 && id !== 'iPhone17,5') return true;
  // iPad Pro M4 and iPad Air M2 2024 (model series 16+)
  if (iPadNum >= 16) return true;
  return false;
}

function AIHintCard({ onDismiss }: { onDismiss: () => void }) {
  const { colors, styles } = useTheme();
  const deviceName = Device.modelName ?? 'your device';
  return (
    <View
      accessible
      accessibilityLabel={`Apple Intelligence is available on ${deviceName} but appears to be turned off. Double tap Open Settings to enable it.`}
      style={[styles.card, {
        borderLeftWidth: 4, borderLeftColor: '#F59E0B', marginBottom: 16,
      }]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10, marginBottom: 8 }}>
        <Ionicons name="sparkles-outline" size={20} color="#F59E0B" accessibilityElementsHidden />
        <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text, flex: 1 }}>
          Apple Intelligence is available on your device
        </Text>
      </View>
      <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginBottom: 12 }}>
        {`Your ${deviceName} supports Apple Intelligence, but it appears to be turned off. Enable it in iOS Settings to unlock AI-powered summaries, text simplification, and accessibility insights in AppleVis.`}
      </Text>
      <View style={{ flexDirection: 'row', gap: 10, alignItems: 'center' }}>
        <Pressable
          onPress={() =>
            Linking.openURL('App-prefs:INTELLIGENCE').catch(() =>
              Linking.openURL('App-prefs:root=INTELLIGENCE').catch(() => {}),
            )
          }
          accessible
          accessibilityRole="button"
          accessibilityLabel="Open Apple Intelligence settings"
          accessibilityHint="Opens iOS Settings, Apple Intelligence and Siri"
          style={({ pressed }) => ({
            backgroundColor: '#F59E0B', borderRadius: 8,
            paddingHorizontal: 16, paddingVertical: 9, opacity: pressed ? 0.75 : 1,
          })}
        >
          <Text style={{ color: '#FFFFFF', fontSize: 14, fontWeight: '700' }}>Open Settings</Text>
        </Pressable>
        <Pressable
          onPress={onDismiss}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Dismiss this hint"
          style={({ pressed }) => ({
            borderRadius: 8, paddingHorizontal: 16, paddingVertical: 9,
            opacity: pressed ? 0.75 : 1,
          })}
        >
          <Text style={{ fontSize: 14, fontWeight: '600', color: colors.textSecondary }}>Not Now</Text>
        </Pressable>
      </View>
    </View>
  );
}

function AIUnsupportedNote() {
  const { colors, styles } = useTheme();
  return (
    <View
      accessible
      accessibilityLabel="Hardware note: the Apple Intelligence features below require iPhone 15 Pro, iPhone 16 series, iPad Pro M4, or iPad Air M2 2024 or later."
      style={[styles.card, { marginBottom: 16, flexDirection: 'row', gap: 10, alignItems: 'flex-start', opacity: 0.8 }]}
    >
      <Ionicons name="information-circle-outline" size={18} color={colors.textSecondary} accessibilityElementsHidden />
      <Text style={{ fontSize: 13, color: colors.textSecondary, lineHeight: 19, flex: 1 }}>
        The Apple Intelligence features below require an iPhone 15 Pro, iPhone 16 series, iPad Pro (M4), or iPad Air (M2 2024) or later, running iOS 18.2+. They are not available on this device.
      </Text>
    </View>
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

export default function IntelligenceSettings() {
  const { colors, styles }    = useTheme();
  const { showToast }         = useToast();
  const { showTip }           = useTip();
  const {
    nonEnglishDetectionEnabled,
    setNonEnglishDetectionEnabled,
  } = usePreferences();

  const [hintDismissed, setHintDismissed] = useState(true); // default true avoids flash on mount

  useEffect(() => {
    icloudStorage.getString(AI_HINT_KEY, '').then((v) => {
      setHintDismissed(v === 'true');
    });
    const t = setTimeout(() => showTip(TIP_KEYS.settingsIntelligence, TIPS.settingsIntelligence), 1200);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function dismissHint() {
    await icloudStorage.setString(AI_HINT_KEY, 'true');
    setHintDismissed(true);
  }

  const aiCapable   = isAICapableDevice();
  const aiAvailable = isAppleIntelligenceAvailable();
  const showHint    = aiCapable && !aiAvailable && !hintDismissed;
  const showUnsupportedNote = !aiCapable && (Device.modelId ?? '').includes(','); // real device only

  return (
    <Screen title="Intelligence & Siri" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>

        <Text style={styles.lede}>
          AppleVis uses on-device AI and system integrations to help you browse faster,
          listen hands-free, and get accessibility insights — without sending your
          content to a server.
        </Text>

        {showHint && <AIHintCard onDismiss={dismissHint} />}
        {showUnsupportedNote && <AIUnsupportedNote />}

        {/* ── Available Now ─────────────────────────────────────────────── */}
        <SectionLabel>Available Now</SectionLabel>

        <FeatureCard
          icon="volume-high-outline"
          title="Read Aloud"
          badge="Live"
          badgeVariant="live"
          description="Reads the title and description of any content card aloud using your device's text-to-speech voice. Works without VoiceOver and without internet. Available on every forum topic, app, resource, and podcast episode via the VoiceOver actions rotor."
        >
          <TryButton
            label="Try Read Aloud"
            onPress={() => {
              readAloud('Welcome to AppleVis — the premier community for blind, DeafBlind, and low vision Apple users.');
              showToast('Speaking…', 'success');
            }}
          />
        </FeatureCard>

        <FeatureCard
          icon="language-outline"
          title="Translate"
          badge="Live"
          badgeVariant="live"
          description="When you type a reply or comment in a language other than English, a banner appears offering to open Google Translate with your text pre-filled. AppleVis requires all posts to be in English — this helps non-English speakers contribute."
        >
          <TryButton
            label="Try Translate"
            onPress={() => translateContent(
              'Welcome to AppleVis — the premier community for blind, DeafBlind, and low vision Apple users.',
            )}
          />
        </FeatureCard>

        {/* Non-English Detection toggle */}
        <Pressable
          onPress={() => setNonEnglishDetectionEnabled(!nonEnglishDetectionEnabled)}
          accessible
          accessibilityRole="switch"
          accessibilityState={{ checked: nonEnglishDetectionEnabled }}
          accessibilityLabel="Non-English Text Detection. When you type or paste non-English text in the search bar or compose screen, a banner appears offering to translate it before you search or post."
          style={({ pressed }) => [
            styles.card,
            { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 14,
              opacity: pressed ? 0.85 : 1 },
          ]}
        >
          <Ionicons name="text-outline" size={20} color={colors.accent} accessibilityElementsHidden />
          <View style={{ flex: 1 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>
                Non-English Detection
              </Text>
              <Badge label="Live" variant="live" />
            </View>
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
              Shows a translate banner when non-English text is detected in search or compose.
            </Text>
          </View>
          <Switch
            value={nonEnglishDetectionEnabled}
            onValueChange={setNonEnglishDetectionEnabled}
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
            trackColor={{ false: colors.border, true: colors.appleVisBlue }}
            thumbColor="#FFFFFF"
          />
        </Pressable>

        {/* ── Apple Intelligence · iOS 18.2+ ────────────────────────────── */}
        <SectionLabel>Apple Intelligence  ·  iOS 18.2+</SectionLabel>

        <FeatureCard
          icon="document-text-outline"
          title="Summarise"
          badge="iOS 18.2+"
          description="Condenses long forum threads and resource articles to 2–3 sentences using Apple's on-device Foundation Models. Never leaves your device. Requires Apple Intelligence to be enabled in iOS Settings."
          onPress={() => nativeAlert('Summarise', 'iOS 18.2+ with Apple Intelligence enabled in Settings → Apple Intelligence & Siri')}
        />

        <FeatureCard
          icon="sparkles-outline"
          title="Simplify"
          badge="iOS 18.2+"
          description="Rewrites technical accessibility content in plain, simple language using Foundation Models. Useful for complex developer discussions and spec-heavy articles."
          onPress={() => nativeAlert('Simplify', 'iOS 18.2+ with Apple Intelligence enabled in Settings → Apple Intelligence & Siri')}
        />

        <FeatureCard
          icon="people-outline"
          title="Accessibility Consensus"
          badge="iOS 18.2+"
          description='Aggregates multiple app reviews into a single clear statement — "Most reviewers say this app works well with VoiceOver, though some note issues with the settings screen."'
          onPress={() => nativeAlert('Accessibility Consensus', 'iOS 18.2+ with Apple Intelligence enabled in Settings → Apple Intelligence & Siri')}
        />

        {/* ── Siri Voice Commands ───────────────────────────────────────── */}
        <SectionLabel>Siri Voice Commands</SectionLabel>

        <FeatureCard
          icon="mic-outline"
          title='Say "Open AppleVis Forums"'
          badge="App Intents"
          badgeVariant="system"
          description='Ask Siri to open the Forums, show unread topics, open saved items, or search for apps — all by voice. Works on Lock Screen, with AirPods, and via Hey Siri.'
          onPress={() => nativeAlert('Siri Voice Commands', 'the Siri App Intents native module')}
        />

        <FeatureCard
          icon="mic-outline"
          title='Say "Play the Latest AppleVis Podcast"'
          badge="App Intents"
          badgeVariant="system"
          description="Ask Siri to play the most recent episode hands-free, even with the phone in your pocket. Also supports continue, pause, and skip commands."
          onPress={() => nativeAlert('Siri Podcast Command', 'the Siri App Intents native module')}
        />

        {/* ── System Integrations ───────────────────────────────────────── */}
        <SectionLabel>System Integrations</SectionLabel>

        <FeatureCard
          icon="phone-portrait-outline"
          title="Live Activities & Dynamic Island"
          badge="ActivityKit"
          badgeVariant="system"
          description="While a podcast is playing, a Live Activity shows the episode title, progress bar, and playback controls on your Lock Screen and in the Dynamic Island on iPhone 14 Pro and later."
          onPress={() => nativeAlert('Live Activities', 'the ActivityKit native module')}
        />

        <FeatureCard
          icon="grid-outline"
          title="Home Screen Widgets"
          badge="WidgetKit"
          badgeVariant="system"
          description="Add AppleVis widgets to your Home Screen or Lock Screen showing unread topic count, the latest podcast episode, or your personalised activity digest. Tap a widget to open directly to that content."
          onPress={() => nativeAlert('Home Screen Widgets', 'the WidgetKit native module')}
        />

        <FeatureCard
          icon="search-outline"
          title="Spotlight Search"
          badge="CoreSpotlight"
          badgeVariant="system"
          description="Forum topics, podcast episodes, and app listings appear in iOS system Search (swipe down from the Home Screen) so you can find AppleVis content without opening the app."
          onPress={() => nativeAlert('Spotlight Search', 'the CoreSpotlight native module')}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
