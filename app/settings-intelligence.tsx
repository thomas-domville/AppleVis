import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Alert,
  findNodeHandle,
  Linking,
  Pressable,
  ScrollView,
  Switch,
  Text,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Device from 'expo-device';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { usePreferences } from '../src/contexts/PreferencesContext';
import { useToast } from '../src/contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../src/contexts/ContextualTipContext';
import { icloudStorage } from '../src/services/icloudStorage';
import { isAppleIntelligenceAvailable, readAloud, translateContent } from '../src/services/intelligenceService';

type BadgeVariant = 'live' | 'ai' | 'native' | 'off';

const AI_HINT_KEY = 'applevis:ai_hint_dismissed';

const BADGE_COLORS: Record<BadgeVariant, { bg: string; text: string; border: string }> = {
  live:   { bg: '#D1FAE5', text: '#065F46', border: '#A7F3D0' },
  ai:     { bg: '#E0E7FF', text: '#3730A3', border: '#C7D2FE' },
  native: { bg: '#FEF3C7', text: '#92400E', border: '#FDE68A' },
  off:    { bg: '#F3F4F6', text: '#4B5563', border: '#E5E7EB' },
};

function isAICapableDevice(): boolean {
  const id = Device.modelId ?? '';
  if (!id.includes(',')) return false;
  const iPhoneNum = parseInt(id.match(/^iPhone(\d+)/)?.[1] ?? '0', 10);
  const iPadNum = parseInt(id.match(/^iPad(\d+)/)?.[1] ?? '0', 10);
  if (iPhoneNum >= 16 && id !== 'iPhone17,5') return true;
  if (iPadNum >= 16) return true;
  return false;
}

function Badge({ label, variant }: { label: string; variant: BadgeVariant }) {
  const c = BADGE_COLORS[variant];
  return (
    <View
      style={{
        backgroundColor: c.bg,
        borderColor: c.border,
        borderWidth: 1,
        borderRadius: 7,
        paddingHorizontal: 8,
        paddingVertical: 3,
      }}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Text style={{ fontSize: 12, fontWeight: '700', color: c.text }}>{label}</Text>
    </View>
  );
}

function SectionLabel({ children }: { children: string }) {
  const { colors } = useTheme();
  return (
    <Text
      accessibilityRole="header"
      style={{
        fontSize: 13,
        fontWeight: '700',
        color: colors.textSecondary,
        textTransform: 'uppercase',
        letterSpacing: 0,
        marginBottom: 10,
        marginTop: 12,
      }}
    >
      {children}
    </Text>
  );
}

function FeatureCard({
  icon,
  title,
  status,
  badgeVariant,
  description,
  onPress,
  children,
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  status: string;
  badgeVariant: BadgeVariant;
  description: string;
  onPress?: () => void;
  children?: React.ReactNode;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole={onPress ? 'button' : 'summary'}
      accessibilityLabel={`${title}. ${status}. ${description}`}
      accessibilityHint={onPress ? 'Double tap for details' : undefined}
      style={({ pressed }) => [
        styles.card,
        {
          marginBottom: 12,
          borderLeftWidth: 4,
          borderLeftColor: badgeVariant === 'live' ? '#10B981' : badgeVariant === 'ai' ? '#6366F1' : '#F59E0B',
          opacity: pressed && onPress ? 0.82 : 1,
        },
      ]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <View
          style={{
            width: 34,
            height: 34,
            borderRadius: 8,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: colors.inputBackground,
          }}
          accessibilityElementsHidden
        >
          <Ionicons name={icon} size={20} color={colors.accent} accessibilityElementsHidden />
        </View>
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, flex: 1 }}>
          {title}
        </Text>
        <Badge label={status} variant={badgeVariant} />
      </View>
      <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginBottom: children ? 12 : 0 }}>
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
        backgroundColor: colors.appleVisBlue,
        borderRadius: 8,
        paddingHorizontal: 16,
        paddingVertical: 9,
        alignSelf: 'flex-start',
        opacity: pressed ? 0.75 : 1,
      })}
    >
      <Text style={{ color: '#FFFFFF', fontSize: 14, fontWeight: '700' }}>{label}</Text>
    </Pressable>
  );
}

function ToggleRow({
  icon,
  title,
  description,
  value,
  onValueChange,
  status = 'Live Today',
}: {
  icon: React.ComponentProps<typeof Ionicons>['name'];
  title: string;
  description: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  status?: string;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={() => onValueChange(!value)}
      accessible
      accessibilityRole="switch"
      accessibilityState={{ checked: value }}
      accessibilityLabel={`${title}, ${value ? 'on' : 'off'}`}
      accessibilityHint={description}
      style={({ pressed }) => [
        styles.card,
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: 12,
          marginBottom: 10,
          borderLeftWidth: 4,
          borderLeftColor: value ? colors.accent : colors.border,
          opacity: pressed ? 0.82 : 1,
        },
      ]}
    >
      <View
        style={{
          width: 36,
          height: 36,
          borderRadius: 9,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: colors.inputBackground,
        }}
        accessibilityElementsHidden
      >
        <Ionicons name={icon} size={20} color={value ? colors.accent : colors.textSecondary} accessibilityElementsHidden />
      </View>
      <View style={{ flex: 1 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4, flexWrap: 'wrap' }}>
          <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text }}>{title}</Text>
          <Badge label={status} variant="live" />
        </View>
        <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
          {description}
        </Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
        trackColor={{ false: colors.border, true: colors.appleVisBlue }}
        thumbColor="#FFFFFF"
      />
    </Pressable>
  );
}

function openAppleIntelligenceSettings() {
  Linking.openURL('App-prefs:INTELLIGENCE').catch(() =>
    Linking.openURL('App-prefs:root=INTELLIGENCE').catch(() => {}),
  );
}

function nativeAlert(feature: string, requirement: string) {
  Alert.alert(
    feature,
    `This feature requires ${requirement}.\n\nThe app interface is ready. It will activate when the native iOS module is included in the build.`,
    [{ text: 'Got it' }],
  );
}

export default function IntelligenceSettings() {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const { showTip } = useTip();
  const headingRef = useRef<Text>(null);
  const {
    nonEnglishDetectionEnabled,
    setNonEnglishDetectionEnabled,
    composeRewriteEnabled,
    setComposeRewriteEnabled,
    composeTranslationEnabled,
    setComposeTranslationEnabled,
    searchTranslationEnabled,
    setSearchTranslationEnabled,
    aiSummariesEnabled,
    setAiSummariesEnabled,
  } = usePreferences();

  const [hintDismissed, setHintDismissed] = useState(true);
  const aiCapable = isAICapableDevice();
  const aiAvailable = isAppleIntelligenceAvailable();
  const deviceName = Device.modelName ?? 'This device';
  const isRealDevice = (Device.modelId ?? '').includes(',');
  const enabledCount = [
    nonEnglishDetectionEnabled,
    composeRewriteEnabled,
    composeTranslationEnabled,
    searchTranslationEnabled,
    aiSummariesEnabled,
  ].filter(Boolean).length;

  const status = aiAvailable
    ? 'Available and enabled'
    : aiCapable
      ? 'Supported, but not enabled'
      : isRealDevice
        ? 'Not available on this device'
        : 'Not available in this development build';

  const summary = useMemo(() => (
    `${enabledCount} of 5 smart feature controls are on. Apple Intelligence is ${status}. ` +
    'Read Aloud, Google Translate handoff, and non-English detection work today. ' +
    'Friendly rewrite, draft translation, search translation, summaries, simplification, and consensus require Apple Intelligence. ' +
    'Siri, Spotlight, widgets, and Live Activities require native iOS modules.'
  ), [enabledCount, status]);

  useEffect(() => {
    icloudStorage.getString(AI_HINT_KEY, '').then((v) => setHintDismissed(v === 'true'));
    const focusTimer = setTimeout(() => {
      const handle = findNodeHandle(headingRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 350);
    const tipTimer = setTimeout(() => showTip(TIP_KEYS.settingsIntelligence, TIPS.settingsIntelligence), 1200);
    return () => {
      clearTimeout(focusTimer);
      clearTimeout(tipTimer);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function dismissHint() {
    await icloudStorage.setString(AI_HINT_KEY, 'true');
    setHintDismissed(true);
  }

  const showHint = aiCapable && !aiAvailable && !hintDismissed;

  return (
    <Screen title="Intelligence & Siri" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text
          ref={headingRef}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Read Intelligence Summary' }]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'summary') {
              AccessibilityInfo.announceForAccessibility(`Intelligence and Siri settings. ${summary}`);
            }
          }}
          style={{ fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: 8 }}
        >
          Smart Features
        </Text>

        <Text style={styles.lede}>
          Control AppleVis features that help with reading, writing, translation, summaries,
          Siri, and iOS integrations.
        </Text>

        <View
          accessible
          accessibilityRole="summary"
          accessibilityLabel={`Apple Intelligence status. ${status}. ${summary}`}
          style={[
            styles.card,
            {
              marginBottom: 14,
              borderLeftWidth: 4,
              borderLeftColor: aiAvailable ? '#10B981' : aiCapable ? '#F59E0B' : colors.border,
            },
          ]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
            <Ionicons
              name={aiAvailable ? 'sparkles' : 'sparkles-outline'}
              size={22}
              color={aiAvailable ? '#10B981' : aiCapable ? '#F59E0B' : colors.textSecondary}
              accessibilityElementsHidden
            />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 17, fontWeight: '800', color: colors.text }}>
                Apple Intelligence
              </Text>
              <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 2 }}>
                {status}
              </Text>
            </View>
            <Badge label={aiAvailable ? 'Ready' : aiCapable ? 'Enable' : 'Unavailable'} variant={aiAvailable ? 'live' : aiCapable ? 'native' : 'off'} />
          </View>
          <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20 }}>
            {deviceName}. Apple Intelligence features run on device when available. Features that use
            Google Translate open Google Translate with your text prefilled.
          </Text>
          {aiCapable && !aiAvailable && (
            <Pressable
              onPress={openAppleIntelligenceSettings}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Open Apple Intelligence settings"
              accessibilityHint="Opens iOS Settings, Apple Intelligence and Siri"
              style={({ pressed }) => ({
                marginTop: 12,
                backgroundColor: '#F59E0B',
                borderRadius: 8,
                paddingHorizontal: 14,
                paddingVertical: 9,
                alignSelf: 'flex-start',
                opacity: pressed ? 0.75 : 1,
              })}
            >
              <Text style={{ color: '#FFFFFF', fontSize: 14, fontWeight: '700' }}>Open Settings</Text>
            </Pressable>
          )}
        </View>

        {showHint && (
          <View style={[styles.card, { borderLeftWidth: 4, borderLeftColor: '#F59E0B', marginBottom: 14 }]}>
            <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, marginBottom: 6 }}>
              Apple Intelligence can be enabled
            </Text>
            <Text style={{ fontSize: 14, color: colors.textSecondary, lineHeight: 20, marginBottom: 10 }}>
              Turn it on in iOS Settings to use summaries, rewrite, in-app translation, simplification, and consensus.
            </Text>
            <Pressable
              onPress={dismissHint}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Dismiss Apple Intelligence hint"
              style={({ pressed }) => ({ alignSelf: 'flex-start', opacity: pressed ? 0.7 : 1 })}
            >
              <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>Not Now</Text>
            </Pressable>
          </View>
        )}

        <SectionLabel>Controls</SectionLabel>

        <ToggleRow
          icon="language-outline"
          title="Non-English Detection"
          description="Shows translate options when search or compose text appears to be non-English."
          value={nonEnglishDetectionEnabled}
          onValueChange={setNonEnglishDetectionEnabled}
        />

        <ToggleRow
          icon="create-outline"
          title="Friendly Rewrite"
          description="Offers a rewrite button before posting comments, replies, and topics."
          value={composeRewriteEnabled}
          onValueChange={setComposeRewriteEnabled}
          status="Requires AI"
        />

        <ToggleRow
          icon="text-outline"
          title="Draft Translation"
          description="Offers Translate to English before posting when a draft appears to be non-English."
          value={composeTranslationEnabled}
          onValueChange={setComposeTranslationEnabled}
          status="Requires AI"
        />

        <ToggleRow
          icon="search-outline"
          title="Search Translation"
          description="Offers to translate a non-English Discover search query into English before searching."
          value={searchTranslationEnabled}
          onValueChange={setSearchTranslationEnabled}
          status="Requires AI"
        />

        <ToggleRow
          icon="document-text-outline"
          title="AI Summaries"
          description="Shows Apple Intelligence summary and simplify actions when supported by this device."
          value={aiSummariesEnabled}
          onValueChange={setAiSummariesEnabled}
          status="Requires AI"
        />

        <SectionLabel>Live Today</SectionLabel>

        <FeatureCard
          icon="volume-high-outline"
          title="Read Aloud"
          status="Live Today"
          badgeVariant="live"
          description="Reads titles, previews, comments, and articles with the device speech voice. This works without VoiceOver and without Apple Intelligence."
        >
          <TryButton
            label="Try Read Aloud"
            onPress={() => {
              readAloud('Welcome to AppleVis, the community for blind, DeafBlind, and low vision Apple users.');
              showToast('Speaking...', 'success');
            }}
          />
        </FeatureCard>

        <FeatureCard
          icon="language-outline"
          title="Google Translate Handoff"
          status="Live Today"
          badgeVariant="live"
          description="Opens Google Translate with text prefilled and English selected as the target language."
        >
          <TryButton
            label="Try Translate"
            onPress={() => translateContent('Welcome to AppleVis, the community for blind, DeafBlind, and low vision Apple users.')}
          />
        </FeatureCard>

        <SectionLabel>Requires Apple Intelligence</SectionLabel>

        <FeatureCard
          icon="create-outline"
          title="Friendly Rewrite"
          status="Requires AI"
          badgeVariant="ai"
          description="Rewrites comments, replies, and topics so they are clear, personable, and respectful while preserving the author's meaning."
          onPress={() => nativeAlert('Friendly Rewrite', 'Apple Intelligence Foundation Models')}
        />

        <FeatureCard
          icon="text-outline"
          title="Translate Draft to English"
          status="Requires AI"
          badgeVariant="ai"
          description="Translates a non-English topic, reply, or comment into natural English before posting."
          onPress={() => nativeAlert('Translate Draft to English', 'Apple Intelligence Foundation Models')}
        />

        <FeatureCard
          icon="search-outline"
          title="Translate Search Query"
          status="Requires AI"
          badgeVariant="ai"
          description="Translates a non-English Discover search query into English, then searches with the translated text."
          onPress={() => nativeAlert('Translate Search Query', 'Apple Intelligence Foundation Models')}
        />

        <FeatureCard
          icon="document-text-outline"
          title="Summarise"
          status="Requires AI"
          badgeVariant="ai"
          description="Condenses long posts, app notes, podcast show notes, and discussions into a short summary."
          onPress={() => nativeAlert('Summarise', 'Apple Intelligence enabled in iOS Settings')}
        />

        <FeatureCard
          icon="sparkles-outline"
          title="Simplify"
          status="Requires AI"
          badgeVariant="ai"
          description="Rewrites technical accessibility content in plainer language for quicker reading."
          onPress={() => nativeAlert('Simplify', 'Apple Intelligence enabled in iOS Settings')}
        />

        <FeatureCard
          icon="people-outline"
          title="Accessibility Consensus"
          status="Requires AI"
          badgeVariant="ai"
          description="Combines multiple app reviews into one short accessibility consensus statement."
          onPress={() => nativeAlert('Accessibility Consensus', 'Apple Intelligence enabled in iOS Settings')}
        />

        <SectionLabel>Native iOS Modules Needed</SectionLabel>

        <FeatureCard
          icon="mic-outline"
          title="Siri Voice Commands"
          status="Native Module"
          badgeVariant="native"
          description='Supports phrases such as "Open AppleVis Forums," "Show unread topics," and "Play the latest AppleVis podcast."'
          onPress={() => nativeAlert('Siri Voice Commands', 'the Siri App Intents native module')}
        />

        <FeatureCard
          icon="phone-portrait-outline"
          title="Live Activities"
          status="Native Module"
          badgeVariant="native"
          description="Shows podcast playback progress and controls on the Lock Screen and Dynamic Island."
          onPress={() => nativeAlert('Live Activities', 'the ActivityKit native module')}
        />

        <FeatureCard
          icon="grid-outline"
          title="Widgets"
          status="Native Module"
          badgeVariant="native"
          description="Shows unread counts, latest podcast episodes, or saved content on the Home Screen or Lock Screen."
          onPress={() => nativeAlert('Widgets', 'the WidgetKit native module')}
        />

        <FeatureCard
          icon="search-outline"
          title="Spotlight Search"
          status="Native Module"
          badgeVariant="native"
          description="Indexes AppleVis topics, apps, podcasts, and resources so they appear in iOS system Search."
          onPress={() => nativeAlert('Spotlight Search', 'the CoreSpotlight native module')}
        />

        <View style={{ height: 96 }} />
      </ScrollView>
    </Screen>
  );
}
