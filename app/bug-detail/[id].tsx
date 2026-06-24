import { useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Animated,
  Clipboard, findNodeHandle, Linking, Platform,
  Pressable, ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { cachedApi } from '../../src/services/cachedApi';
import { relativeTime } from '../../src/utils/relativeTime';
import { stripHtml } from '../../src/utils/articleHelpers';
import type { BugReportDetail } from '../../src/types/content';

// ─── Constants ────────────────────────────────────────────────────────────────

const BUG_ACCENT = '#f97316';
const TOOLBAR_H  = 76;

const SEVERITY_CONFIG = {
  low:    { label: 'Low Severity',    color: '#16a34a', bg: '#dcfce7' },
  medium: { label: 'Medium Severity', color: '#d97706', bg: '#fef3c7' },
  high:   { label: 'High Severity',   color: '#dc2626', bg: '#fee2e2' },
} as const;

const STATUS_CONFIG = {
  active: { label: 'Active', color: '#f97316', bg: '#fff7ed', icon: 'ellipse'          },
  fixed:  { label: 'Fixed',  color: '#16a34a', bg: '#dcfce7', icon: 'checkmark-circle' },
} as const;

const HOW_OFTEN_LABELS = {
  rarely:    'Rarely',
  sometimes: 'Sometimes',
  always:    'Always',
} as const;

// ─── Paragraph splitting — each paragraph becomes its own accessible node
//     so braille display users can navigate paragraph-by-paragraph.         ────

function splitParagraphs(raw: string): string[] {
  return stripHtml(raw)
    .split('\n\n')
    .map(p => p.replace(/\n/g, ' ').trim())
    .filter(Boolean);
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function SectionDivider({
  label, summary, rightSlot,
}: {
  label: string;
  summary?: string;
  rightSlot?: React.ReactNode;
}) {
  const { colors } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginVertical: 18 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.8 }}
        accessible
        accessibilityRole="header"
        accessibilityLabel={label}
        {...(summary ? {
          accessibilityActions: [{ name: 'summary', label: `${label} summary` }],
          onAccessibilityAction: () => AccessibilityInfo.announceForAccessibility(summary),
        } : {})}
      >
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      {rightSlot}
    </View>
  );
}

function ToolbarButton({
  icon, activeIcon, label, a11yLabel, onPress, active, accent,
}: {
  icon: string; activeIcon?: string; label: string; a11yLabel?: string;
  onPress: () => void; active?: boolean; accent?: boolean;
}) {
  const { colors } = useTheme();
  const resolvedIcon = active && activeIcon ? activeIcon : icon;
  const color = accent ? BUG_ACCENT : active ? colors.accent : colors.textSecondary;
  return (
    <Pressable
      onPress={onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={a11yLabel ?? label.replace(/\n/g, ' ')}
      accessibilityState={{ selected: active }}
      style={({ pressed }) => ({
        flex: 1, alignItems: 'center', justifyContent: 'center',
        gap: 4, opacity: pressed ? 0.55 : 1, paddingVertical: 10,
      })}
    >
      <Ionicons name={resolvedIcon as any} size={23} color={color} accessibilityElementsHidden />
      <Text style={{ fontSize: 12, fontWeight: '600', color, textAlign: 'center', lineHeight: 15 }}
        accessibilityElementsHidden>
        {label}
      </Text>
    </Pressable>
  );
}

function MetaRow({ icon, label, value }: { icon: string; label: string; value: string }) {
  const { colors } = useTheme();
  return (
    <View
      style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10, paddingVertical: 10 }}
      accessible
      accessibilityLabel={`${label}: ${value}`}
    >
      <Ionicons name={icon as any} size={16} color={BUG_ACCENT} style={{ marginTop: 1 }}
        accessibilityElementsHidden />
      <View style={{ flex: 1 }}>
        <Text style={{ fontSize: 11, fontWeight: '600', color: colors.textSecondary,
          textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 2 }}
          accessibilityElementsHidden>
          {label}
        </Text>
        <Text style={{ fontSize: 15, color: colors.text, lineHeight: 21 }}
          accessibilityElementsHidden>
          {value}
        </Text>
      </View>
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function BugDetailScreen() {
  const params   = useLocalSearchParams<{ id: string; platform: string; title: string; url: string }>();
  const { colors, styles } = useTheme();
  const { showToast }      = useToast();
  const { reduceTransparency, reduceMotion, screenReaderEnabled } = useAccessibilityPreferences();
  const { isSaved: checkSaved, save: doSave, unsave: doUnsave } = useSavedItems();

  const platform = (params.platform === 'macos' ? 'macos' : 'ios') as 'ios' | 'macos';
  const id       = params.id ?? '';
  const url      = params.url ?? 'https://www.applevis.com/bugs';

  const [bug,      setBug]      = useState<BugReportDetail | null>(null);
  const [loading,  setLoading]  = useState(true);
  const [error,    setError]    = useState<string | null>(null);
  const [textSize, setTextSize] = useState(16);

  const scrollRef       = useRef<ScrollView>(null);
  const heroRef         = useRef<Text>(null);
  const hasInitialFocus = useRef(false);

  const progressAnim = useRef(new Animated.Value(0)).current;
  const heroAnim     = useRef(new Animated.Value(0)).current;
  const contentAnim  = useRef(new Animated.Value(0)).current;
  const pulseAnim    = useRef(new Animated.Value(1)).current;

  useHandoff({
    activityType: 'com.applevis.app.bug',
    title: bug?.title ?? params.title ?? 'Bug Report — AppleVis',
    webpageURL: url,
  });

  useEffect(() => {
    cachedApi.bugs.detail(platform, id).then((res) => {
      if (res.ok) setBug(res.data);
      else setError(res.error);
      setLoading(false);
    });
  }, [platform, id]);

  // Entrance animations — skipped when reduce-motion or screen reader is on.
  useEffect(() => {
    if (!bug) return;
    if (reduceMotion || screenReaderEnabled) {
      heroAnim.setValue(1);
      contentAnim.setValue(1);
      return;
    }
    Animated.parallel([
      Animated.timing(heroAnim,    { toValue: 1, duration: 380, useNativeDriver: true }),
      Animated.timing(contentAnim, { toValue: 1, duration: 450, delay: 180, useNativeDriver: true }),
    ]).start();
  }, [!!bug]);

  // Pulse on the Active status dot — gives sighted users a live "open" signal.
  useEffect(() => {
    if (!bug || bug.status !== 'active' || reduceMotion) {
      pulseAnim.setValue(1);
      return;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, { toValue: 0.3, duration: 900, useNativeDriver: true }),
        Animated.timing(pulseAnim, { toValue: 1,   duration: 900, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [!!bug, reduceMotion]);

  // VoiceOver: focus the title heading after load (first swipe lands here).
  useEffect(() => {
    if (!bug || hasInitialFocus.current) return;
    hasInitialFocus.current = true;
    setTimeout(() => {
      const handle = findNodeHandle(heroRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 250);
  }, [!!bug]);

  const isSaved = checkSaved(id);

  function handleSave() {
    Haptics.selectionAsync();
    if (isSaved) {
      doUnsave(id);
      AccessibilityInfo.announceForAccessibility('Removed from Saved.');
    } else {
      doSave({ id, kind: 'resource', title: bug?.title ?? '', savedAt: new Date().toISOString() });
      AccessibilityInfo.announceForAccessibility('Saved.');
    }
  }

  function handleShare() {
    Haptics.selectionAsync();
    Share.share({ title: bug?.title ?? 'Bug Report', url }).catch(() => {});
  }

  function handleOpenWeb() {
    Haptics.selectionAsync();
    Linking.openURL(url).catch(() => showToast('Could not open the bug report.', 'error'));
  }

  function handleFeedback() {
    Haptics.selectionAsync();
    Linking.openURL('https://feedbackassistant.apple.com/')
      .catch(() => showToast('Could not open Feedback Assistant.', 'error'));
  }

  function handleCopyLink() {
    Haptics.selectionAsync();
    Clipboard.setString(url);
    AccessibilityInfo.announceForAccessibility('Link copied.');
  }

  // Long-press on the hero card — same ActionSheetIOS scheme as home feed.
  function handleLongPressHero() {
    if (!bug) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const heroActions = [
      { label: isSaved ? 'Remove from Saved' : 'Save this Bug Report', fn: handleSave },
      { label: 'Share this Bug Report',                                  fn: handleShare },
      { label: 'Copy Link',                                              fn: handleCopyLink },
      { label: 'Open on AppleVis',                                       fn: handleOpenWeb },
      { label: 'Report to Apple',                                        fn: handleFeedback },
    ];
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { title: bug.title, options: ['Cancel', ...heroActions.map(a => a.label)], cancelButtonIndex: 0 },
        (i) => { if (i > 0) heroActions[i - 1].fn(); },
      );
    } else {
      handleShare();
    }
  }

  function handleScroll(e: any) {
    const { contentOffset, contentSize, layoutMeasurement } = e.nativeEvent;
    const scrollable = contentSize.height - layoutMeasurement.height;
    if (scrollable > 0) progressAnim.setValue(contentOffset.y / scrollable);
  }

  // ── Loading ──────────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <Screen title="Bug Report" showBack>
        <View
          style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}
          accessible
          accessibilityLabel="Loading bug report, please wait"
          accessibilityLiveRegion="polite"
        >
          <ActivityIndicator size="large" color={BUG_ACCENT} />
          <Text style={[styles.lede, { marginTop: 16, textAlign: 'center' }]}>
            Loading bug report…
          </Text>
        </View>
      </Screen>
    );
  }

  if (error || !bug) {
    return (
      <Screen title="Bug Report" showBack>
        <View style={{ flex: 1, padding: 16 }}>
          <View style={[styles.card, { borderColor: '#dc2626', borderWidth: 1 }]}>
            <Text style={[styles.cardTitle, { color: '#dc2626', marginBottom: 8 }]}>
              Could not load bug report
            </Text>
            <Text style={styles.cardMeta}>{error ?? 'Unknown error'}</Text>
            <Pressable
              onPress={handleOpenWeb}
              accessible accessibilityRole="link"
              accessibilityLabel="Open bug report on AppleVis website"
              style={{ marginTop: 14 }}
            >
              <Text style={{ color: BUG_ACCENT, fontWeight: '700' }}>Open on AppleVis</Text>
            </Pressable>
          </View>
        </View>
      </Screen>
    );
  }

  const sev    = SEVERITY_CONFIG[bug.severity];
  const status = STATUS_CONFIG[bug.status];

  const bodyParas  = bug.body             ? splitParagraphs(bug.body)             : [];
  const stepsParas = bug.stepsToReproduce ? splitParagraphs(bug.stepsToReproduce) : [];
  const wkParas    = bug.workaround && bug.workaround.toLowerCase() !== 'none'
                       ? splitParagraphs(bug.workaround) : [];

  const heroA11yLabel = [
    bug.title,
    `Platform: ${platform === 'ios' ? 'iOS and iPadOS' : 'macOS'}`,
    `Status: ${status.label}`,
    `Severity: ${sev.label}`,
    `Reported ${relativeTime(bug.createdAt)}`,
    bug.firstSeen ? `First seen in ${bug.firstSeen}` : null,
    bug.fixedIn   ? `Fixed in ${bug.fixedIn}` : null,
  ].filter(Boolean).join('. ');

  // A−/A+ visual slot shown in the Description section divider row.
  const textSizeControls = (
    <View
      style={{ flexDirection: 'row', gap: 2 }}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Pressable onPress={() => setTextSize(s => Math.max(13, s - 1))}
        style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}>
        <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>A−</Text>
      </Pressable>
      <Pressable onPress={() => setTextSize(s => Math.min(22, s + 1))}
        style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}>
        <Text style={{ fontSize: 18, fontWeight: '700', color: colors.accent }}>A+</Text>
      </Pressable>
    </View>
  );

  return (
    <Screen title="Bug Report" showBack>

      {/* ── Reading progress bar — purely visual, hidden from VoiceOver/braille */}
      <View
        style={{ height: 5, backgroundColor: colors.border }}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      >
        <Animated.View
          style={{
            height: 5,
            backgroundColor: BUG_ACCENT,
            width: progressAnim.interpolate({
              inputRange: [0, 1], outputRange: ['0%', '100%'], extrapolate: 'clamp',
            }),
          }}
        />
      </View>

      {/* ── Fixed bottom toolbar ─────────────────────────────────────────────── */}
      <View
        accessibilityRole="toolbar"
        accessibilityLabel="Bug report actions"
        style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 10,
          flexDirection: 'row',
          backgroundColor: reduceTransparency ? colors.card : colors.card + 'F0',
          borderTopWidth: 1, borderTopColor: colors.border,
          paddingBottom: 28, paddingTop: 4,
        }}
      >
        <ToolbarButton
          icon="bookmark-outline"
          activeIcon="bookmark"
          label={isSaved ? 'Saved\nBug Report' : 'Save this\nBug Report'}
          a11yLabel={isSaved ? 'Saved Bug Report' : 'Save this Bug Report'}
          active={isSaved}
          onPress={handleSave}
        />
        <ToolbarButton
          icon="share-outline"
          label={'Share this\nBug Report'}
          a11yLabel="Share this Bug Report"
          onPress={handleShare}
        />
        <ToolbarButton
          icon="bug-outline"
          label={'Report\nto Apple'}
          a11yLabel="Report to Apple"
          onPress={handleFeedback}
          accent
        />
        <ToolbarButton
          icon="safari-outline"
          label={'Open in\nSafari'}
          a11yLabel="Open Bug Report in Safari"
          onPress={handleOpenWeb}
        />
      </View>

      <ScrollView
        ref={scrollRef}
        showsVerticalScrollIndicator
        onScroll={handleScroll}
        scrollEventThrottle={16}
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 16, paddingBottom: TOOLBAR_H + 16 }}
      >

        {/* ── Hero card ──────────────────────────────────────────────────────── */}
        <Animated.View
          style={{
            opacity: heroAnim,
            transform: [{ translateY: heroAnim.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) }],
          }}
        >
          {/* Outer Pressable: catches long-press for sighted users */}
          <Pressable onLongPress={handleLongPressHero} delayLongPress={400} accessible={false}>
            <View style={[styles.card, {
              marginBottom: 12, overflow: 'hidden', padding: 0,
              borderLeftWidth: 4, borderLeftColor: BUG_ACCENT,
            }]}>
              {/* Accent tint — hidden when Reduce Transparency is on */}
              {!reduceTransparency && (
                <View
                  style={{ ...StyleSheet.absoluteFillObject, backgroundColor: BUG_ACCENT, opacity: 0.06 }}
                  accessibilityElementsHidden
                  importantForAccessibility="no-hide-descendants"
                />
              )}

              <View style={{ padding: 16 }}>
                {/* Badges — visual only; all metadata is in heroA11yLabel below */}
                <View
                  style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}
                  accessibilityElementsHidden
                  importantForAccessibility="no-hide-descendants"
                >
                  {/* Platform */}
                  <View style={{
                    backgroundColor: reduceTransparency ? colors.inputBackground : BUG_ACCENT + '18',
                    borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5,
                  }}>
                    <Text style={{ fontSize: 12, fontWeight: '700', color: BUG_ACCENT }}>
                      {bug.platform === 'ios' ? 'iOS / iPadOS' : 'macOS'}
                    </Text>
                  </View>

                  {/* Status — Active dot pulses to signal an open issue */}
                  <View style={{
                    flexDirection: 'row', alignItems: 'center', gap: 5,
                    backgroundColor: reduceTransparency ? colors.inputBackground : status.bg,
                    borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5,
                  }}>
                    {bug.status === 'active' ? (
                      <Animated.View style={{ opacity: pulseAnim }}>
                        <Ionicons name="ellipse" size={8} color={status.color} />
                      </Animated.View>
                    ) : (
                      <Ionicons name="checkmark-circle" size={12} color={status.color} />
                    )}
                    <Text style={{ fontSize: 12, fontWeight: '700', color: status.color }}>
                      {status.label}
                    </Text>
                  </View>

                  {/* Severity */}
                  <View style={{
                    backgroundColor: reduceTransparency ? colors.inputBackground : sev.bg,
                    borderRadius: 8, paddingHorizontal: 10, paddingVertical: 5,
                  }}>
                    <Text style={{ fontSize: 12, fontWeight: '700', color: sev.color }}>
                      {sev.label}
                    </Text>
                  </View>
                </View>

                {/* Title — VoiceOver auto-focuses here (first swipe after load).
                    accessibilityActions provide the VoiceOver/switch-access rotor. */}
                <Text
                  ref={heroRef}
                  accessible
                  accessibilityRole="header"
                  accessibilityLabel={heroA11yLabel}
                  accessibilityHint="Hold for options."
                  accessibilityActions={[
                    { name: 'save',         label: isSaved ? 'Remove from Saved' : 'Save this Bug Report' },
                    { name: 'share',        label: 'Share this Bug Report'   },
                    { name: 'copy',         label: 'Copy Link'               },
                    { name: 'web',          label: 'Open on AppleVis'        },
                    { name: 'feedback',     label: 'Report to Apple'         },
                    { name: 'increaseText', label: 'Increase text size'      },
                    { name: 'decreaseText', label: 'Decrease text size'      },
                  ]}
                  onAccessibilityAction={({ nativeEvent }) => {
                    switch (nativeEvent.actionName) {
                      case 'save':         handleSave();                                         break;
                      case 'share':        handleShare();                                        break;
                      case 'copy':         handleCopyLink();                                     break;
                      case 'web':          handleOpenWeb();                                      break;
                      case 'feedback':     handleFeedback();                                     break;
                      case 'increaseText': setTextSize(s => Math.min(22, s + 1));               break;
                      case 'decreaseText': setTextSize(s => Math.max(13, s - 1));               break;
                    }
                  }}
                  style={{ fontSize: 20, fontWeight: '800', color: colors.text, lineHeight: 28 }}
                >
                  {bug.title}
                </Text>

                {/* Timestamps */}
                <Text
                  style={{ fontSize: 12, color: colors.textSecondary, marginTop: 10 }}
                  accessible
                  accessibilityLabel={`Reported ${relativeTime(bug.createdAt)}. Last updated ${relativeTime(bug.changedAt)}.`}
                >
                  Reported {relativeTime(bug.createdAt)} · Updated {relativeTime(bug.changedAt)}
                </Text>
              </View>
            </View>
          </Pressable>
        </Animated.View>

        {/* ── Body content ─────────────────────────────────────────────────────── */}
        <Animated.View
          style={{
            opacity: contentAnim,
            transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }],
          }}
        >

          {/* ── Description ────────────────────────────────────────────────────── */}
          {bodyParas.length > 0 && (
            <>
              <SectionDivider
                label="Description"
                summary={`${bodyParas.length} paragraph${bodyParas.length !== 1 ? 's' : ''}.`}
                rightSlot={textSizeControls}
              />
              {/* Each paragraph is its own accessible node for braille navigation. */}
              {bodyParas.map((para, i) => (
                <Text
                  key={i}
                  style={{ fontSize: textSize, color: colors.text, lineHeight: textSize * 1.7, marginBottom: 12 }}
                  accessible
                  accessibilityLabel={para}
                >
                  {para}
                </Text>
              ))}
            </>
          )}

          {/* ── Steps to Reproduce ─────────────────────────────────────────────── */}
          {stepsParas.length > 0 && (
            <>
              <SectionDivider
                label="Steps to Reproduce"
                summary={`${stepsParas.length} step${stepsParas.length !== 1 ? 's' : ''} to reproduce.`}
              />
              {stepsParas.map((step, i) => (
                <Text
                  key={i}
                  style={{ fontSize: textSize, color: colors.text, lineHeight: textSize * 1.7, marginBottom: 10 }}
                  accessible
                  accessibilityLabel={`Step ${i + 1}: ${step}`}
                >
                  {step}
                </Text>
              ))}
            </>
          )}

          {/* ── Workaround ─────────────────────────────────────────────────────── */}
          {wkParas.length > 0 && (
            <>
              <SectionDivider label="Workaround" />
              {wkParas.map((para, i) => (
                <Text
                  key={i}
                  style={{ fontSize: textSize, color: colors.text, lineHeight: textSize * 1.7, marginBottom: 12 }}
                  accessible
                  accessibilityLabel={para}
                >
                  {para}
                </Text>
              ))}
            </>
          )}

          {/* ── Bug Details meta card ───────────────────────────────────────────── */}
          <SectionDivider label="Bug Details" />
          <View style={[styles.card, { gap: 0 }]}>
            {bug.firstSeen ? (
              <>
                <MetaRow icon="alert-circle-outline"    label="First Seen In" value={bug.firstSeen} />
                <View style={{ height: 1, backgroundColor: colors.border, marginLeft: 26 }} accessibilityElementsHidden />
              </>
            ) : null}

            {bug.fixedIn ? (
              <>
                <MetaRow icon="checkmark-circle-outline" label="Fixed In"     value={bug.fixedIn} />
                <View style={{ height: 1, backgroundColor: colors.border, marginLeft: 26 }} accessibilityElementsHidden />
              </>
            ) : null}

            {bug.device ? (
              <>
                <MetaRow icon="phone-portrait-outline"  label="Device"        value={bug.device} />
                <View style={{ height: 1, backgroundColor: colors.border, marginLeft: 26 }} accessibilityElementsHidden />
              </>
            ) : null}

            {bug.howOften ? (
              <>
                <MetaRow icon="repeat-outline"          label="How Often"     value={HOW_OFTEN_LABELS[bug.howOften]} />
                <View style={{ height: 1, backgroundColor: colors.border, marginLeft: 26 }} accessibilityElementsHidden />
              </>
            ) : null}

            {bug.feedbackId ? (
              <Pressable
                onPress={() => {
                  Haptics.selectionAsync();
                  Linking.openURL('https://feedbackassistant.apple.com/')
                    .catch(() => showToast('Could not open Feedback Assistant.', 'error'));
                }}
                accessible
                accessibilityRole="link"
                accessibilityLabel={`Apple Feedback ID: ${bug.feedbackId}. Double tap to open Feedback Assistant.`}
              >
                <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10, paddingVertical: 10 }}>
                  <Ionicons name="logo-apple" size={16} color={BUG_ACCENT} style={{ marginTop: 1 }}
                    accessibilityElementsHidden />
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 11, fontWeight: '600', color: colors.textSecondary,
                      textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 2 }}
                      accessibilityElementsHidden>
                      Apple Feedback ID
                    </Text>
                    <Text style={{ fontSize: 15, color: BUG_ACCENT, fontWeight: '600' }}
                      accessibilityElementsHidden>
                      {bug.feedbackId}
                    </Text>
                  </View>
                  <Ionicons name="open-outline" size={14} color={BUG_ACCENT} style={{ marginTop: 3 }}
                    accessibilityElementsHidden />
                </View>
              </Pressable>
            ) : null}
          </View>

          {/* ── Help Fix This Bug CTA ───────────────────────────────────────────── */}
          {bug.status === 'active' && (
            <>
              <SectionDivider label="Help Fix This Bug" />
              <Pressable
                onPress={() => {
                  Haptics.selectionAsync();
                  Linking.openURL('https://feedbackassistant.apple.com/')
                    .catch(() => showToast('Could not open Feedback Assistant.', 'error'));
                }}
                accessible
                accessibilityRole="link"
                accessibilityLabel="Report this bug to Apple via Feedback Assistant. Opens in your browser."
                style={({ pressed }) => [
                  styles.card,
                  {
                    flexDirection: 'row', alignItems: 'center', gap: 12,
                    borderWidth: 1.5, borderColor: BUG_ACCENT, borderStyle: 'dashed',
                    backgroundColor: 'transparent', opacity: pressed ? 0.7 : 1,
                  },
                ]}
              >
                <Ionicons name="logo-apple" size={24} color={BUG_ACCENT} accessibilityElementsHidden />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 15, fontWeight: '600', color: BUG_ACCENT }}>
                    Report to Apple
                  </Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                    File a report in Feedback Assistant to help get this fixed.
                  </Text>
                </View>
                <Ionicons name="open-outline" size={15} color={BUG_ACCENT} accessibilityElementsHidden />
              </Pressable>
            </>
          )}

        </Animated.View>
      </ScrollView>
    </Screen>
  );
}
