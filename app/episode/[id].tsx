import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, ActionSheetIOS, Animated, Clipboard, findNodeHandle,
  Image, Linking, Modal, Platform,
  Pressable, ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter, useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { EditContentModal } from '../../src/components/EditContentModal';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { ALERTS } from '../../src/data/alertMessages';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { SPEED_OPTIONS, SLEEP_TIMER_OPTIONS, SLEEP_END_OF_EPISODE } from '../../src/hooks/usePodcastPlayer';
import { downloadEpisode, deleteDownload, getLocalUri } from '../../src/services/downloads';
import { persistence } from '../../src/services/persistence';
import { useEpisodeDurations } from '../../src/hooks/useEpisodeDurations';
import { api } from '../../src/services/api';
import { cachedApi } from '../../src/services/cachedApi';
import { showAirPlayPicker } from '../../src/native/nativeModules';
import { isAppleIntelligenceAvailable, readAloud, summariseText } from '../../src/services/intelligenceService';
import { relativeTime } from '../../src/utils/relativeTime';
import { displayCommentSubject, subjectLabel } from '../../src/utils/commentSubject';
import type { PodcastEpisode, Chapter, ForumReply } from '../../src/types/content';

type EpisodeComment = ForumReply;

// ─── Skip-hold progression ────────────────────────────────────────────────────
const HOLD_SKIP_STEPS = [
  { seconds: 60,  label: '1 minute' },
  { seconds: 180, label: '3 minutes' },
  { seconds: 300, label: '5 minutes' },
  { seconds: 600, label: '10 minutes' },
  { seconds: 900, label: '15 minutes' },
];
const HOLD_INITIAL_DELAY_MS = 700;
const HOLD_STEP_INTERVAL_MS = 800;

// Sleep picker: 0 = Off, -1 = End of Episode, then SLEEP_TIMER_OPTIONS
const SLEEP_MINS = [0, SLEEP_END_OF_EPISODE, ...SLEEP_TIMER_OPTIONS] as const;

type DownloadState = 'idle' | 'downloading' | 'done';

// ─── Helpers ──────────────────────────────────────────────────────────────────
function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function formatTimeSpoken(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  if (m === 0) return `${s} second${s === 1 ? '' : 's'}`;
  if (s === 0) return `${m} minute${m === 1 ? '' : 's'}`;
  return `${m} minute${m === 1 ? '' : 's'} and ${s} second${s === 1 ? '' : 's'}`;
}

function formatDurationLong(seconds: number): string {
  if (seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const parts = [
    h > 0 ? `${h} hour${h === 1 ? '' : 's'}` : null,
    m > 0 ? `${m} minute${m === 1 ? '' : 's'}` : null,
  ].filter(Boolean);
  return parts.length > 0 ? `${parts.join(' and ')} long` : 'less than 1 minute long';
}

function formatRemaining(position: number, duration: number): string {
  const remaining = Math.max(0, duration - position);
  if (remaining <= 0) return '';
  const h = Math.floor(remaining / 3600);
  const m = Math.ceil((remaining % 3600) / 60);
  if (h > 0) return `-${h}h ${m}m`;
  return `-${m} min`;
}

function sleepLabel(mins: number): string {
  if (mins === 0) return 'Off';
  if (mins === SLEEP_END_OF_EPISODE) return 'End of Episode';
  return `${mins} min`;
}

function stripHtmlPlain(html: string): string {
  return html
    .replace(/<\/?(p|div|h[1-6]|li|blockquote)[^>]*>/gi, ' ')
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (_, c) => String.fromCharCode(Number(c)))
    .replace(/\s+/g, ' ')
    .trim();
}

// ─── VTT / SRT transcript parser ─────────────────────────────────────────────
type TranscriptCue = { startSeconds: number; text: string };

function parseTimestamp(ts: string): number {
  const cleaned = ts.trim().replace(',', '.');
  const parts = cleaned.split(':').map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return 0;
}

function parseTranscript(raw: string): TranscriptCue[] {
  const cues: TranscriptCue[] = [];
  const blocks = raw.split(/\n{2,}/);
  for (const block of blocks) {
    const lines = block.trim().split('\n');
    const timingIdx = lines.findIndex(l => l.includes('-->'));
    if (timingIdx === -1) continue;
    const [startStr] = lines[timingIdx].split('-->');
    const text = lines
      .slice(timingIdx + 1)
      .join(' ')
      .replace(/<[^>]+>/g, '')
      .trim();
    if (text) cues.push({ startSeconds: parseTimestamp(startStr), text });
  }
  return cues;
}

// ─── Show Notes ───────────────────────────────────────────────────────────────
type NoteLink = { label: string; url: string; kind: 'app' | 'email' | 'web' };

function parseShowNotes(rawHtml: string): { body: string[]; links: NoteLink[]; transcript: string[] | null } {
  if (!rawHtml.trim()) return { body: [], links: [], transcript: null };

  const txHeadingMatch = rawHtml.match(/#{1,3}\s*Transcri?pt[^\n\r]*/i);
  const splitIdx = txHeadingMatch?.index ?? -1;
  const preHtml  = splitIdx >= 0 ? rawHtml.slice(0, splitIdx) : rawHtml;
  const postHtml = splitIdx >= 0 ? rawHtml.slice(splitIdx + txHeadingMatch![0].length) : null;

  const links: NoteLink[] = [];
  const seen = new Set<string>();

  function addLink(rawLabel: string, url: string) {
    const label = rawLabel.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
    if (!label || !url || seen.has(url)) return;
    seen.add(url);
    if (url.includes('apps.apple.com')) {
      links.push({ label, url, kind: 'app' });
    } else if (url.startsWith('mailto:')) {
      links.push({ label: url.replace('mailto:', ''), url, kind: 'email' });
    } else if (url.startsWith('http')) {
      links.push({ label, url, kind: 'web' });
    }
  }

  const aRegex = /<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let m: RegExpExecArray | null;
  while ((m = aRegex.exec(preHtml)) !== null) addLink(m[2], m[1]);

  function htmlToPlain(html: string): string {
    return html
      .replace(/<\/?(p|div|h[1-6]|li|blockquote)[^>]*>/gi, '\n\n')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (_, c) => String.fromCharCode(Number(c)))
      .replace(/&[a-z]{2,8};/g, ' ')
      .replace(/[ \t]+/g, ' ')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  function splitLines(text: string): string[] {
    return text
      .replace(/#{1,6}\s*/gm, '')
      .replace(/\*\*(.+?)\*\*/g, '$1').replace(/\*(.+?)\*/g, '$1')
      .replace(/^\s*[-*+]\s+/gm, '• ')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .split(/\n/)
      .map(l => l.trim())
      .filter(l => l.length > 0);
  }

  const preText = htmlToPlain(preHtml);

  const mdRegex = /\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g;
  while ((m = mdRegex.exec(preText)) !== null) addLink(m[1], m[2]);

  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
  while ((m = emailRegex.exec(preText)) !== null) {
    if (!seen.has(m[0])) {
      seen.add(m[0]);
      links.push({ label: m[0], url: `mailto:${m[0]}`, kind: 'email' });
    }
  }

  let transcript: string[] | null = null;
  if (postHtml) {
    const txLines = splitLines(htmlToPlain(postHtml));
    transcript = txLines.length > 0 ? txLines : null;
  }

  const body = splitLines(preText);
  return { body, links, transcript };
}

function ShowNotes({
  rawHtml, textSize, expanded, onToggleExpand, onIncreaseText, onDecreaseText,
}: {
  rawHtml: string;
  textSize: number;
  expanded: boolean;
  onToggleExpand: () => void;
  onIncreaseText: () => void;
  onDecreaseText: () => void;
}) {
  const { colors, styles } = useTheme();
  const [transcriptOpen, setTranscriptOpen] = useState(false);
  const { body, links, transcript } = useMemo(() => parseShowNotes(rawHtml), [rawHtml]);

  const COLLAPSE_AT = 4;
  const needsCollapse = body.length > COLLAPSE_AT;
  const visibleBody  = needsCollapse && !expanded ? body.slice(0, COLLAPSE_AT) : body;
  const hiddenCount  = body.length - visibleBody.length;

  if (!body.length && !links.length && !transcript) return null;

  return (
    <>
      {transcript && (
        <Modal
          visible={transcriptOpen}
          animationType="slide"
          presentationStyle="pageSheet"
          onRequestClose={() => setTranscriptOpen(false)}
          accessibilityViewIsModal
        >
          <View style={{ flex: 1, backgroundColor: colors.background }} onAccessibilityEscape={() => setTranscriptOpen(false)}>
            <View style={{
              flexDirection: 'row', alignItems: 'center',
              justifyContent: 'space-between',
              paddingHorizontal: 20, paddingTop: Platform.OS === 'ios' ? 56 : 20,
              paddingBottom: 14,
              borderBottomWidth: 1, borderBottomColor: colors.border,
            }}>
              <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}
                accessibilityRole="header">
                Transcript
              </Text>
              <Pressable
                onPress={() => setTranscriptOpen(false)}
                accessible
                accessibilityRole="button"
                accessibilityLabel="Close transcript"
                hitSlop={12}
                style={{ backgroundColor: colors.pill, borderRadius: 14,
                  paddingHorizontal: 14, paddingVertical: 6 }}
              >
                <Text style={{ fontSize: 14, fontWeight: '600', color: colors.text }}>Done</Text>
              </Pressable>
            </View>
            <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 48 }}>
              {transcript.map((line, i) => (
                <Text key={i} accessible
                  style={{ fontSize: 15, lineHeight: 24, color: colors.text, marginBottom: 10 }}>
                  {line}
                </Text>
              ))}
            </ScrollView>
          </View>
        </Modal>
      )}

      <View style={[styles.card, { marginBottom: 20 }]}>
        {/* Header row: title + A−/A+ controls */}
        <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 8 }}>
          <Text
            style={[styles.cardTitle, { flex: 1 }]}
            accessibilityRole="header"
            accessible
            accessibilityActions={[
              { name: 'increaseText', label: 'Increase text size' },
              { name: 'decreaseText', label: 'Decrease text size' },
            ]}
            onAccessibilityAction={({ nativeEvent }) => {
              if (nativeEvent.actionName === 'increaseText') onIncreaseText();
              if (nativeEvent.actionName === 'decreaseText') onDecreaseText();
            }}
          >
            About this episode
          </Text>
          <View style={{ flexDirection: 'row', gap: 2 }}
            accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
            <Pressable onPress={onDecreaseText}
              style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}>
              <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>A−</Text>
            </Pressable>
            <Pressable onPress={onIncreaseText}
              style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}>
              <Text style={{ fontSize: 18, fontWeight: '700', color: colors.accent }}>A+</Text>
            </Pressable>
          </View>
        </View>

        {visibleBody.map((para, i) => (
          <Text key={i} accessible
            style={{ fontSize: textSize, lineHeight: textSize * 1.6,
              color: colors.textSecondary, marginBottom: 6 }}>
            {para}
          </Text>
        ))}

        {needsCollapse && hiddenCount > 0 && (
          <Pressable
            onPress={onToggleExpand}
            accessible
            accessibilityRole="button"
            accessibilityLabel={
              expanded ? 'Show less' :
              `Show full description — ${hiddenCount} more section${hiddenCount === 1 ? '' : 's'}`
            }
            style={({ pressed }) => ({
              flexDirection: 'row', alignItems: 'center', gap: 6,
              marginTop: 4, paddingVertical: 8, opacity: pressed ? 0.55 : 1,
            })}
          >
            <Ionicons
              name={expanded ? 'chevron-up-outline' : 'chevron-down-outline'}
              size={16} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>
              {expanded ? 'Show less' : `Show full description (${hiddenCount} more)`}
            </Text>
          </Pressable>
        )}

        {links.length > 0 && (
          <View style={{ gap: 10, marginTop: visibleBody.length > 0 ? 10 : 4 }}>
            {links.map((link, i) => (
              <Pressable
                key={i}
                onPress={() => Linking.openURL(link.url).catch(() => {})}
                accessible
                accessibilityRole="link"
                accessibilityLabel={
                  link.kind === 'app'   ? `${link.label} — open in App Store` :
                  link.kind === 'email' ? `Email ${link.label}` :
                  link.label
                }
                style={{ flexDirection: 'row', alignItems: 'center', gap: 12,
                  backgroundColor: colors.inputBackground, borderRadius: 10,
                  paddingHorizontal: 14, paddingVertical: 11 }}
              >
                <Ionicons
                  name={
                    link.kind === 'app'   ? 'logo-apple-appstore' :
                    link.kind === 'email' ? 'mail-outline' : 'link-outline'
                  }
                  size={20} color={colors.accent} accessibilityElementsHidden
                />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                    {link.label}
                  </Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 1 }}>
                    {link.kind === 'app'   ? 'App Store' :
                     link.kind === 'email' ? 'Send email' : 'Open link'}
                  </Text>
                </View>
                <Ionicons name="open-outline" size={16}
                  color={colors.textSecondary} accessibilityElementsHidden />
              </Pressable>
            ))}
          </View>
        )}

        {transcript && (
          <Pressable
            onPress={() => setTranscriptOpen(true)}
            accessible
            accessibilityRole="button"
            accessibilityLabel="See the transcript"
            accessibilityHint="Opens the full episode transcript in a new screen"
            style={{
              flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
              marginTop: 16, paddingTop: 14,
              borderTopWidth: 1, borderTopColor: colors.border,
            }}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <Ionicons name="document-text-outline" size={20}
                color={colors.accent} accessibilityElementsHidden />
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.accent }}>
                See the Transcript
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={18}
              color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>
        )}
      </View>
    </>
  );
}

// ─── Dedicated VTT transcript ─────────────────────────────────────────────────
function VttTranscript({ url, currentPosition }: { url: string; currentPosition: number }) {
  const { colors, styles } = useTheme();
  const [cues, setCues] = useState<TranscriptCue[]>([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const scrollRef = useRef<ScrollView>(null);
  const lastScrolledCueRef = useRef(-1);

  useEffect(() => {
    if (!open || cues.length > 0) return;
    setLoading(true);
    fetch(url)
      .then(r => r.text())
      .then(raw => setCues(parseTranscript(raw)))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [open, url, cues.length]);

  useEffect(() => {
    if (!open || cues.length === 0) return;
    const activeIdx = cues.reduce((best, cue, i) =>
      cue.startSeconds <= currentPosition ? i : best, 0);
    if (activeIdx !== lastScrolledCueRef.current) {
      lastScrolledCueRef.current = activeIdx;
      scrollRef.current?.scrollTo({ y: activeIdx * 44, animated: true });
    }
  }, [open, cues, currentPosition]);

  const activeCueIdx = cues.reduce((best, cue, i) =>
    cue.startSeconds <= currentPosition ? i : best, -1);

  return (
    <View style={[styles.card, { marginBottom: 20 }]}>
      <Pressable
        onPress={() => setOpen(v => !v)}
        accessible
        accessibilityRole="button"
        accessibilityLabel={open ? 'Hide live transcript' : 'Show live transcript'}
        accessibilityHint="Transcript syncs to playback position"
        style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}
      >
        <Text style={[styles.cardTitle]} accessibilityRole="header">Live Transcript</Text>
        <Ionicons name={open ? 'chevron-up' : 'chevron-down'}
          size={18} color={colors.textSecondary} accessibilityElementsHidden />
      </Pressable>

      {open && (
        <ScrollView
          ref={scrollRef}
          style={{ maxHeight: 320, marginTop: 12 }}
          showsVerticalScrollIndicator={false}
          accessibilityLabel="Episode transcript"
        >
          {loading && (
            <Text style={{ color: colors.textSecondary, fontSize: 14 }}>Loading transcript…</Text>
          )}
          {cues.map((cue, i) => {
            const isActive = i === activeCueIdx;
            return (
              <Text
                key={i}
                accessible
                accessibilityLabel={cue.text}
                accessibilityLiveRegion={isActive ? 'polite' : 'none'}
                style={{
                  fontSize: 14,
                  lineHeight: 22,
                  color: isActive ? colors.accent : colors.textSecondary,
                  fontWeight: isActive ? '600' : '400',
                  paddingVertical: 2,
                }}
              >
                {cue.text}
              </Text>
            );
          })}
        </ScrollView>
      )}
    </View>
  );
}

// ─── Bottom toolbar button ────────────────────────────────────────────────────
function ToolbarButton({
  icon, activeIcon, label, a11yLabel, onPress, active, accent, disabled,
}: {
  icon: string; activeIcon?: string; label: string; onPress: () => void;
  a11yLabel?: string; active?: boolean; accent?: boolean; disabled?: boolean;
}) {
  const { colors } = useTheme();
  const resolvedIcon = (active && activeIcon) ? activeIcon : icon;
  const color = disabled
    ? colors.textSecondary
    : accent ? colors.accent
    : active ? colors.accent
    : colors.textSecondary;
  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      accessible
      accessibilityRole="button"
      accessibilityLabel={a11yLabel ?? label.replace(/\n/g, ' ')}
      accessibilityState={{ selected: active, disabled }}
      style={({ pressed }) => ({
        flex: 1, alignItems: 'center', justifyContent: 'center',
        gap: 4, opacity: disabled ? 0.35 : pressed ? 0.55 : 1, paddingVertical: 10,
      })}
    >
      <Ionicons name={resolvedIcon as any} size={23} color={color} accessibilityElementsHidden />
      <Text
        style={{ fontSize: 10, fontWeight: '600', color, textAlign: 'center', lineHeight: 13 }}
        accessibilityElementsHidden
      >
        {label}
      </Text>
    </Pressable>
  );
}

// ─── SectionDivider ───────────────────────────────────────────────────────────
function SectionDivider({ label }: { label: string }) {
  const { colors } = useTheme();
  return (
    <View accessible accessibilityRole="header" accessibilityLabel={label}
      style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 14 }}>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
      <Text style={{ fontSize: 11, fontWeight: '700', color: colors.textSecondary,
        letterSpacing: 1.2, textTransform: 'uppercase' }} accessibilityElementsHidden>
        {label}
      </Text>
      <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} accessibilityElementsHidden />
    </View>
  );
}

// ─── ComingSoonShell ──────────────────────────────────────────────────────────
function EpisodeCommentCard({
  comment, index, total, episodeTitle, onReply, hasLoved, loveCount, onLove,
}: {
  comment: EpisodeComment;
  index: number;
  total: number;
  episodeTitle: string;
  onReply: () => void;
  hasLoved: boolean;
  loveCount: number;
  onLove: () => void;
}) {
  const { colors, styles } = useTheme();
  const { showToast } = useToast();
  const timeStr = relativeTime(comment.createdAt);
  const commentSubject = displayCommentSubject(comment.subject, episodeTitle);

  const headerLabel = [
    `Comment ${index + 1} of ${total}.`,
    subjectLabel(comment.subject, episodeTitle),
    comment.authorName + '.',
    timeStr + '.',
    comment.isNew ? 'New.' : '',
    'Hold for options.',
  ].filter(Boolean).join(' ');

  function shareComment() {
    Share.share({
      message: [
        commentSubject ? `Subject: ${commentSubject}` : null,
        comment.body,
      ].filter(Boolean).join('\n\n'),
    }).catch(() => {});
  }

  function copyComment() {
    Clipboard.setString(comment.body);
    showToast('Comment text copied.');
    AccessibilityInfo.announceForAccessibility('Comment text copied');
  }

  function showActions() {
    if (Platform.OS !== 'ios') return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    ActionSheetIOS.showActionSheetWithOptions(
      {
        title: `Comment by ${comment.authorName}`,
        options: ['Cancel', 'Reply to this Comment', 'Copy Comment Text', 'Share Comment', 'Report Comment'],
        cancelButtonIndex: 0,
        destructiveButtonIndex: 4,
      },
      (idx) => {
        if (idx === 1) onReply();
        if (idx === 2) copyComment();
        if (idx === 3) shareComment();
        if (idx === 4) {
          showToast('Report sent. Thank you.');
          AccessibilityInfo.announceForAccessibility('Report sent');
        }
      },
    );
  }

  return (
    <View style={[styles.card, { marginBottom: 12, padding: 0 }, comment.isNew && { borderLeftWidth: 4, borderLeftColor: colors.accent }]}>
      <Pressable
        onLongPress={showActions}
        delayLongPress={400}
        accessible
        accessibilityRole="header"
        accessibilityLabel={headerLabel}
        accessibilityActions={[
          { name: 'reply',  label: 'Reply to this Comment' },
          { name: 'copy',   label: 'Copy Comment Text' },
          { name: 'share',  label: 'Share Comment' },
          { name: 'report', label: 'Report Comment' },
        ]}
        onAccessibilityAction={({ nativeEvent }) => {
          if (nativeEvent.actionName === 'reply') onReply();
          if (nativeEvent.actionName === 'copy') copyComment();
          if (nativeEvent.actionName === 'share') shareComment();
          if (nativeEvent.actionName === 'report') {
            showToast('Report sent. Thank you.');
            AccessibilityInfo.announceForAccessibility('Report sent');
          }
        }}
        style={({ pressed }) => ({
          padding: 14,
          paddingBottom: 8,
          opacity: pressed ? 0.85 : 1,
        })}
      >
        <View
          style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}>
            <View style={{
              width: 32, height: 32, borderRadius: 16,
              backgroundColor: `${colors.accent}22`,
              alignItems: 'center', justifyContent: 'center',
            }}>
              <Text style={{ fontSize: 13, fontWeight: '700', color: colors.accent }}>
                {comment.authorName.slice(0, 1).toUpperCase()}
              </Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 14, fontWeight: '600', color: colors.text }}>
                {comment.authorName}
              </Text>
              {!!commentSubject && (
                <Text style={{ fontSize: 13, color: colors.text, marginTop: 2 }} numberOfLines={2}>
                  {commentSubject}
                </Text>
              )}
            </View>
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            {comment.isNew && (
              <View style={{ paddingHorizontal: 8, paddingVertical: 2,
                backgroundColor: `${colors.accent}22`, borderRadius: 8 }}>
                <Text style={{ fontSize: 11, fontWeight: '700', color: colors.accent }}>NEW</Text>
              </View>
            )}
            <Text style={{ fontSize: 12, color: colors.textSecondary }}>{timeStr}</Text>
          </View>
        </View>
      </Pressable>

      <View style={{ paddingHorizontal: 14, paddingBottom: 8 }}>
        <Text
          accessible
          accessibilityRole="text"
          accessibilityLabel={comment.body}
          style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}
        >
          {comment.body}
        </Text>
      </View>

      {/* Love footer */}
      <View style={{
        flexDirection: 'row', alignItems: 'center',
        paddingHorizontal: 14, paddingBottom: 12, paddingTop: 6,
        borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.border,
      }}>
        <Pressable
          onPress={onLove}
          accessible
          accessibilityRole="button"
          accessibilityLabel={
            hasLoved
              ? `Remove love${loveCount > 0 ? `. ${loveCount} ${loveCount === 1 ? 'person' : 'people'} loved this` : ''}`
              : `Love this comment${loveCount > 0 ? `. ${loveCount} ${loveCount === 1 ? 'person' : 'people'} loved this` : ''}`
          }
          style={({ pressed }) => ({
            flexDirection: 'row', alignItems: 'center', gap: 5, opacity: pressed ? 0.6 : 1,
          })}
        >
          <Ionicons
            name={hasLoved ? 'heart' : 'heart-outline'}
            size={18}
            color={hasLoved ? '#E53935' : colors.textSecondary}
            accessibilityElementsHidden
          />
          {loveCount > 0 && (
            <Text style={{ fontSize: 13, fontWeight: '600',
              color: hasLoved ? '#E53935' : colors.textSecondary }}
              accessibilityElementsHidden>
              {loveCount}
            </Text>
          )}
          <Text style={{ fontSize: 13, color: hasLoved ? '#E53935' : colors.textSecondary }}
            accessibilityElementsHidden>
            {hasLoved ? 'Loved' : 'Love'}
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

function ComingSoonShell({ icon, message }: { icon: string; message: string }) {
  const { colors } = useTheme();
  return (
    <View accessible accessibilityRole="text"
      accessibilityLabel={`${message} Coming soon.`}
      style={{
        backgroundColor: colors.inputBackground,
        borderRadius: 14, padding: 20, marginBottom: 20,
        alignItems: 'center', opacity: 0.7,
      }}>
      <Ionicons name={icon as any} size={36} color={colors.textSecondary}
        style={{ marginBottom: 10 }} accessibilityElementsHidden />
      <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center', lineHeight: 20 }}
        accessibilityElementsHidden>
        {message}
      </Text>
      <View style={{
        marginTop: 12, paddingHorizontal: 10, paddingVertical: 4,
        backgroundColor: colors.accent, borderRadius: 8,
      }} accessibilityElementsHidden>
        <Text style={{ fontSize: 11, fontWeight: '700', color: '#FFF', letterSpacing: 1 }}>
          COMING SOON
        </Text>
      </View>
    </View>
  );
}

// ─── Now Playing animated waveform ───────────────────────────────────────────

function NowPlayingIndicator({ isPlaying, color }: { isPlaying: boolean; color: string }) {
  const bar1 = useRef(new Animated.Value(0.3)).current;
  const bar2 = useRef(new Animated.Value(0.6)).current;
  const bar3 = useRef(new Animated.Value(0.45)).current;
  const bars = [bar1, bar2, bar3];

  useEffect(() => {
    if (!isPlaying) {
      bars.forEach(b => b.setValue(0.3));
      return;
    }
    const handles = bars.map((bar, i) => {
      const loop = Animated.loop(Animated.sequence([
        Animated.timing(bar, { toValue: 1,    duration: 350 + i * 80, useNativeDriver: true }),
        Animated.timing(bar, { toValue: 0.15, duration: 350 + i * 80, useNativeDriver: true }),
      ]));
      const t = setTimeout(() => loop.start(), i * 120);
      return { loop, t };
    });
    return () => { handles.forEach(({ loop, t }) => { clearTimeout(t); loop.stop(); }); };
  }, [isPlaying]);

  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 2, height: 14 }}
      accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      {bars.map((bar, i) => (
        <Animated.View key={i} style={{
          width: 3, height: 14, borderRadius: 1.5,
          backgroundColor: color, transform: [{ scaleY: bar }],
        }} />
      ))}
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────
const TOOLBAR_H = 58;

export default function EpisodeDetail() {
  const params = useLocalSearchParams<{
    id: string; title: string; showTitle: string;
    description?: string; artworkUrl?: string;
    publishedAt?: string; duration?: string; audioUrl: string;
    transcriptUrl?: string; url?: string; authorName?: string;
  }>();

  const router  = useRouter();
  const player  = usePlayer();
  const auth    = useAuth();
  const { colors, styles } = useTheme();
  const {
    podcastTrimSilence,
    setPodcastTrimSilence,
    podcastVoiceBoost,
    setPodcastVoiceBoost,
    aiSummariesEnabled,
  } = usePreferences();
  const { showToast } = useToast();
  const { showAlert } = useAlert();
  const { showTip }   = useTip();
  const aiAvailable = aiSummariesEnabled && isAppleIntelligenceAvailable();
  const insets = useSafeAreaInsets();
  const { screenReaderEnabled, reduceMotion, reduceTransparency } = useAccessibilityPreferences();

  const cachedDurations = useEpisodeDurations();
  const isCurrent       = player.episode?.id === params.id;
  const isQueued        = player.queue.some(e => e.id === params.id);
  const paramDuration   = Number(params.duration ?? 0);
  // Prefer real duration from player (when playing) > cached from prior play > route param.
  const durationSecs    = isCurrent && player.duration > 0
    ? player.duration
    : (cachedDurations[params.id ?? ''] ?? paramDuration);
  const progress        = isCurrent && player.duration > 0 ? player.position / player.duration : 0;
  const durationKnown   = isCurrent && player.duration > 0;
  const episodeUrl    = params.url || undefined;

  const publishedLabel = params.publishedAt ? relativeTime(params.publishedAt) : null;

  // ── Episode object ───────────────────────────────────────────────────────
  // fetchedData fills in missing fields when navigating with only an id (deep links, saved items).
  const [fetchedData, setFetchedData] = useState<PodcastEpisode | null>(null);

  useEffect(() => {
    if (!params.id) return;
    cachedApi.podcasts.episode(params.id).then((res) => {
      if (res.ok) setFetchedData(res.data);
    }).catch(() => {});
  }, [params.id]);

  const episode = useMemo<PodcastEpisode>(() => fetchedData ?? {
    id: params.id,
    title: params.title,
    showTitle: params.showTitle,
    description: params.description ?? '',
    artworkUrl: params.artworkUrl || undefined,
    publishedAt: params.publishedAt ?? '',
    duration: durationSecs,
    audioUrl: params.audioUrl,
    transcriptUrl: params.transcriptUrl || undefined,
    url: episodeUrl,
    authorName: params.authorName || undefined,
  }, [fetchedData, params.id, params.title, params.showTitle, params.description,
      params.artworkUrl, params.publishedAt, durationSecs, params.audioUrl,
      params.transcriptUrl, episodeUrl, params.authorName]);

  // ── Refs ─────────────────────────────────────────────────────────────────
  const scrollRef           = useRef<ScrollView>(null);
  const titleRef            = useRef<Text>(null);
  const discussionY         = useRef<number>(0);
  const hasInitialFocusRef  = useRef(false);
  const heroAnim            = useRef(new Animated.Value(0)).current;
  const contentAnim         = useRef(new Animated.Value(0)).current;
  const progressAnim        = useRef(new Animated.Value(0)).current;

  // ── Notes display state ──────────────────────────────────────────────────
  const [notesTextSize, setNotesTextSize] = useState(15);
  const [notesExpanded, setNotesExpanded] = useState(false);

  // ── Cached chapters (available before pressing play) ─────────────────────
  const [cachedChapters, setCachedChapters] = useState<Chapter[]>([]);

  // ── Save state ───────────────────────────────────────────────────────────
  const [isSaved, setIsSaved] = useState(false);

  // ── Download state ───────────────────────────────────────────────────────
  const [downloadState, setDownloadState] = useState<DownloadState>('idle');

  // ── Admin edit state ────────────────────────────────────────────────────
  const [editingNode, setEditingNode] = useState(false);

  // ── AI state ─────────────────────────────────────────────────────────────
  const [aiWorking, setAiWorking] = useState(false);
  const [aiSummary, setAiSummary] = useState<string | null>(null);
  const [comments, setComments] = useState<EpisodeComment[]>([]);
  const [lovedCommentIds, setLovedCommentIds] = useState<Set<string>>(new Set());
  const [commentsLoading, setCommentsLoading] = useState(true);
  const [commentsError, setCommentsError] = useState<string | null>(null);
  const [discussionAiWorking, setDiscussionAiWorking] = useState(false);
  const [discussionSummary, setDiscussionSummary] = useState<string | null>(null);
  const firstNewCommentRef = useRef<View | null>(null);
  const commentOffsets = useRef<Record<string, number>>({});

  useEffect(() => {
    persistence.getSavedItems()
      .then(items => setIsSaved(items.some(s => s.id === params.id)))
      .catch(() => {});
    getLocalUri(params.id)
      .then(uri => setDownloadState(uri ? 'done' : 'idle'))
      .catch(() => {});
  }, [params.id]);

  // Load cached chapters so chapter list is available before pressing play.
  useEffect(() => {
    persistence.getEpisodeChapters(params.id).then(cached => {
      if (cached && cached.length > 0) setCachedChapters(cached);
    }).catch(() => {});
  }, [params.id]);

  useEffect(() => {
    if (reduceMotion || screenReaderEnabled) {
      heroAnim.setValue(1);
      contentAnim.setValue(1);
      return;
    }
    Animated.parallel([
      Animated.timing(heroAnim,    { toValue: 1, duration: 380, useNativeDriver: true }),
      Animated.timing(contentAnim, { toValue: 1, duration: 450, delay: 180, useNativeDriver: true }),
    ]).start();
  }, []);

  useEffect(() => {
    if (hasInitialFocusRef.current) return;
    hasInitialFocusRef.current = true;
    setTimeout(() => {
      const handle = findNodeHandle(titleRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 200);
  }, []);

  const loadComments = useCallback(() => {
    if (!params.id) return;
    setCommentsLoading(true);
    setCommentsError(null);
    Promise.all([
      api.podcasts.comments(params.id),
      persistence.getItemVisit(params.id),
    ]).then(([res, visit]) => {
      setCommentsLoading(false);
      if (res.ok) {
        const seenAt = visit?.seenAt ?? null;
        const marked = seenAt
          ? res.data.map(c => ({ ...c, isNew: c.createdAt > seenAt }))
          : res.data;
        setComments(marked);
        persistence.stampItemVisit(params.id, res.data.length).catch(() => {});
      } else {
        setCommentsError(res.error);
      }
    }).catch((err: unknown) => {
      setCommentsLoading(false);
      setCommentsError(err instanceof Error ? err.message : 'Unexpected error');
    });
  }, [params.id]);

  useFocusEffect(useCallback(() => {
    loadComments();
  }, [loadComments]));

  const firstNewComment = comments.find(c => c.isNew) ?? null;
  const newCommentCount = comments.filter(c => c.isNew).length;
  const mostRecentComment = comments.length > 0 ? comments[comments.length - 1] : null;

  function handleJumpToNewComment(firstNewId: string) {
    const offset = commentOffsets.current[firstNewId] ?? 0;
    const y = Math.max(0, discussionY.current + offset - 20);
    scrollRef.current?.scrollTo({ y, animated: true });
    setTimeout(() => {
      const handle = findNodeHandle(firstNewCommentRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 400);
  }

  function handleReplyToComment(comment: EpisodeComment) {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('reply to comments'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    const quote = comment.body.length > 150
      ? comment.body.slice(0, 150).trimEnd() + '...'
      : comment.body;
    router.push({
      pathname: '/compose' as any,
      params: {
        episodeId: params.id,
        episodeTitle: params.title,
        replyToAuthor: comment.authorName,
        replyToQuote: quote,
      },
    });
  }

  // ── Love a comment ───────────────────────────────────────────────────────
  async function handleLoveComment(comment: EpisodeComment) {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('love this comment'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    const wasLoved = lovedCommentIds.has(comment.id);
    setLovedCommentIds(prev => {
      const next = new Set(prev);
      wasLoved ? next.delete(comment.id) : next.add(comment.id);
      return next;
    });
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    AccessibilityInfo.announceForAccessibility(wasLoved ? 'Removed love' : 'Loved');
    try {
      const token = await api.account.getSessionToken();
      const result = wasLoved
        ? await api.podcasts.unloveComment(comment.id, token)
        : await api.podcasts.loveComment(comment.id, token);
      if (!result.ok) throw new Error(result.error);
    } catch {
      setLovedCommentIds(prev => {
        const next = new Set(prev);
        wasLoved ? next.add(comment.id) : next.delete(comment.id);
        return next;
      });
      showToast('Could not save reaction. Try again.', 'error');
    }
  }

  // ── Sleep timer ──────────────────────────────────────────────────────────
  const [sleepIdx, setSleepIdx] = useState(() => {
    if (player.sleepAtEndOfEpisode) return 1;
    if (!player.sleepTimerRemaining) return 0;
    const remainMins = Math.ceil(player.sleepTimerRemaining / 60);
    const i = SLEEP_TIMER_OPTIONS.findIndex(m => m >= remainMins);
    return i >= 0 ? i + 2 : SLEEP_TIMER_OPTIONS.length + 1;
  });

  const sleepDisplayLabel = player.sleepAtEndOfEpisode
    ? 'End of Episode'
    : player.sleepTimerRemaining !== null
      ? `${Math.ceil(player.sleepTimerRemaining / 60)} min remaining`
      : 'Off';

  // ── Long-press skip refs ─────────────────────────────────────────────────
  const holdIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const holdStepRef     = useRef(-1);
  const inLongPressRef  = useRef(false);

  function clearHoldTimers() {
    if (holdIntervalRef.current) { clearInterval(holdIntervalRef.current); holdIntervalRef.current = null; }
  }

  function handleSkipLongPress(_direction: 'forward' | 'back') {
    inLongPressRef.current = true;
    holdStepRef.current    = 0;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    AccessibilityInfo.announceForAccessibility(HOLD_SKIP_STEPS[0].label);

    holdIntervalRef.current = setInterval(() => {
      const next = holdStepRef.current + 1;
      if (next >= HOLD_SKIP_STEPS.length) {
        clearInterval(holdIntervalRef.current!);
        holdIntervalRef.current = null;
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
        return;
      }
      holdStepRef.current = next;
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      AccessibilityInfo.announceForAccessibility(HOLD_SKIP_STEPS[next].label);
    }, HOLD_STEP_INTERVAL_MS);
  }

  function handleSkipPressOut(direction: 'forward' | 'back') {
    if (!inLongPressRef.current) return;
    clearHoldTimers();
    inLongPressRef.current = false;
    if (holdStepRef.current >= 0) {
      const { seconds } = HOLD_SKIP_STEPS[holdStepRef.current];
      holdStepRef.current = -1;
      if (direction === 'forward') player.seekTo(Math.min(player.duration, player.position + seconds));
      else                         player.seekTo(Math.max(0, player.position - seconds));
    }
  }

  // ── Play / load ──────────────────────────────────────────────────────────
  const handlePlayPause = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!isCurrent) {
      player.loadEpisode(episode);
    } else if (player.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }, [isCurrent, player, episode]);

  const playLabel = !isCurrent ? 'Play episode'
    : player.isLoading ? 'Loading, please wait'
    : player.isPlaying ? 'Pause' : 'Resume';

  // ── Speed ────────────────────────────────────────────────────────────────
  const speedIdx = SPEED_OPTIONS.indexOf(player.speed);

  function cycleSpeedForward() {
    const next = SPEED_OPTIONS[(speedIdx + 1) % SPEED_OPTIONS.length];
    player.setSpeed(next);
    Haptics.selectionAsync();
    AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
  }

  // ── Sleep ────────────────────────────────────────────────────────────────
  function applySleepIdx(idx: number) {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setSleepIdx(idx);
    const mins = SLEEP_MINS[idx];
    if (mins === 0) player.cancelSleepTimer();
    else            player.startSleepTimer(mins);
  }

  // ── Volume ───────────────────────────────────────────────────────────────
  const volumeSteps = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
  const volumeIdx = volumeSteps.reduce((best, v, i) =>
    Math.abs(v - player.volume) < Math.abs(volumeSteps[best] - player.volume) ? i : best, 10);
  const volumePct = `${Math.round(player.volume * 100)}%`;

  function setVolumeIdx(idx: number) {
    const clamped = Math.max(0, Math.min(volumeSteps.length - 1, idx));
    player.setVolume(volumeSteps[clamped]);
  }

  // ── Chapter accessibility actions ────────────────────────────────────────
  const chapters = (isCurrent ? player.episode?.chapters : undefined) ?? cachedChapters;

  function chapterProgress(chapter: Chapter): number {
    if (!isCurrent || player.duration <= 0) return 0;
    const idx = chapters.indexOf(chapter);
    const end = idx < chapters.length - 1 ? chapters[idx + 1].startTime : player.duration;
    const dur = end - chapter.startTime;
    if (dur <= 0) return 0;
    return Math.max(0, Math.min(1, (Math.min(end, player.position) - chapter.startTime) / dur));
  }

  const chapterActions = chapters.map(c => ({
    name: `chapter_${c.startTime}`,
    label: `${c.title} — ${formatTime(c.startTime)}`,
  }));

  // Show chapter tip the first time chapters appear for any episode.
  useEffect(() => {
    if (chapters.length > 0) {
      const t = setTimeout(() => showTip(TIP_KEYS.episodeChapters, TIPS.episodeChapters), 1200);
      return () => clearTimeout(t);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chapters.length]);

  // ── Save toggle ──────────────────────────────────────────────────────────
  async function handleSaveToggle() {
    if (isSaved) {
      await persistence.unsaveItem(params.id);
      await persistence.removeSavedEpisodeMeta(params.id);
      setIsSaved(false);
      showToast('Episode unsaved');
      AccessibilityInfo.announceForAccessibility('Episode unsaved');
    } else {
      await persistence.saveItem({
        id: params.id,
        kind: 'podcastEpisode',
        title: params.title,
        savedAt: new Date().toISOString(),
      });
      await persistence.saveSavedEpisodeMeta(episode);
      setIsSaved(true);
      showToast('Episode saved');
      AccessibilityInfo.announceForAccessibility('Episode saved');
    }
  }

  // ── Download toggle ──────────────────────────────────────────────────────
  async function handleDownloadToggle() {
    if (downloadState === 'done') {
      await deleteDownload(params.id);
      setDownloadState('idle');
      showToast('Download removed');
      AccessibilityInfo.announceForAccessibility('Download removed');
    } else if (downloadState === 'idle') {
      setDownloadState('downloading');
      showToast('Downloading episode…');
      AccessibilityInfo.announceForAccessibility('Downloading episode');
      const result = await downloadEpisode(params.id, params.audioUrl, episode);
      if (result.ok) {
        setDownloadState('done');
        showToast('Download complete');
        AccessibilityInfo.announceForAccessibility('Download complete');
      } else {
        setDownloadState('idle');
        showToast(`Download failed: ${result.error ?? 'Unknown error'}`, 'error');
        AccessibilityInfo.announceForAccessibility('Download failed');
      }
    }
  }

  // ── Admin node options ───────────────────────────────────────────────────
  function handleNodeOptions() {
    if (!episode || !auth.user?.csrfToken) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { title: episode.title, options: ['Cancel', 'Edit Episode', 'Unpublish Episode', 'Delete Episode'],
          cancelButtonIndex: 0, destructiveButtonIndex: 3 },
        (index) => {
          if (index === 1) setEditingNode(true);
          if (index === 2) handleAdminUnpublish();
          if (index === 3) handleAdminDelete();
        },
      );
    } else {
      setEditingNode(true);
    }
  }

  function handleAdminDelete() {
    if (!episode || !auth.user?.csrfToken) return;
    const token = auth.user.csrfToken;
    showAlert({
      title: 'Delete Episode',
      message: `Permanently delete "${episode.title}"? This cannot be undone.`,
      confirmLabel: 'Delete', cancelLabel: 'Cancel', type: 'error',
      onConfirm: async () => {
        const res = await api.content.deleteNode(episode.id, 'podcast', token);
        if (res.ok) { showToast('Episode deleted.', 'success'); router.back(); }
        else showToast('Could not delete. Please try again.', 'error');
      },
    });
  }

  function handleAdminUnpublish() {
    if (!episode || !auth.user?.csrfToken) return;
    const token = auth.user.csrfToken;
    showAlert({
      title: 'Unpublish Episode',
      message: `"${episode.title}" will be hidden from all users but not deleted.`,
      confirmLabel: 'Unpublish', cancelLabel: 'Cancel', type: 'warning',
      onConfirm: async () => {
        const res = await api.content.unpublishNode(episode.id, 'podcast', token);
        if (res.ok) { showToast('Episode unpublished.', 'success'); router.back(); }
        else showToast('Could not unpublish. Please try again.', 'error');
      },
    });
  }

  // ── Share ────────────────────────────────────────────────────────────────
  function handleShare() {
    const url = episodeUrl ?? 'https://www.applevis.com/podcasts';
    Share.share({ title: params.title, message: `${params.title} — ${params.showTitle}\n${url}` }).catch(() => {});
  }

  // ── Copy link ────────────────────────────────────────────────────────────
  function handleCopyLink() {
    const url = episodeUrl ?? 'https://www.applevis.com/podcasts';
    Clipboard.setString(url);
    showToast('Link copied to clipboard');
    AccessibilityInfo.announceForAccessibility('Link copied to clipboard');
  }

  // ── Open in browser ──────────────────────────────────────────────────────
  function handleOpenInBrowser() {
    const url = episodeUrl ?? 'https://www.applevis.com/podcasts';
    Linking.openURL(url).catch(() => showToast('Could not open Safari.', 'error'));
  }

  // ── Queue toggle (toolbar) ───────────────────────────────────────────────
  function handleQueueToggle() {
    if (isCurrent) return;
    if (isQueued) {
      player.removeFromQueue(params.id);
      showToast('Removed from queue');
      AccessibilityInfo.announceForAccessibility('Removed from queue');
    } else {
      player.enqueue(episode);
      showToast('Added to end of queue');
      AccessibilityInfo.announceForAccessibility('Added to queue');
    }
  }

  // ── Add new comment (toolbar) ────────────────────────────────────────────
  function handleAddComment() {
    if (!auth.isSignedIn) {
      showAlert({ ...ALERTS.auth.signInRequired('post a comment'), onConfirm: () => router.push('/settings-account' as any) });
      return;
    }
    router.push({
      pathname: '/compose' as any,
      params: {
        episodeId: params.id,
        episodeTitle: params.title,
      },
    });
  }

  // ── Mark as played ───────────────────────────────────────────────────────
  async function handleMarkAsPlayed() {
    await persistence.clearPodcastPosition(params.id);
    if (isCurrent) {
      await player.stop();
      await persistence.clearPodcastPosition(params.id);
    }
    showToast('Marked as played');
    AccessibilityInfo.announceForAccessibility('Marked as played');
  }

  // ── AI: Summarise show notes ─────────────────────────────────────────────
  async function handleAiSummarise() {
    if (!params.description || aiWorking) return;
    if (aiSummary) {
      setAiSummary(null);
      return;
    }
    setAiWorking(true);
    try {
      const plain = stripHtmlPlain(params.description ?? '');
      const result = await summariseText(plain);
      if (result) {
        setAiSummary(result);
      } else {
        showToast('Could not summarise — try again', 'error');
      }
    } catch {
      showToast('Could not summarise — try again', 'error');
    } finally {
      setAiWorking(false);
    }
  }

  async function handleSummariseDiscussion() {
    if (comments.length === 0 || discussionAiWorking) return;
    if (discussionSummary) {
      setDiscussionSummary(null);
      return;
    }
    setDiscussionAiWorking(true);
    try {
      const discussionText = comments.map((c, i) =>
        `Comment ${i + 1} by ${c.authorName}: ${c.body}`,
      ).join('\n\n');
      const result = await summariseText(`Podcast episode discussion: ${params.title}\n\n${discussionText}`);
      if (result) setDiscussionSummary(result);
      else showToast('Could not summarise. Try again.', 'error');
    } catch {
      showToast('Could not summarise. Try again.', 'error');
    } finally {
      setDiscussionAiWorking(false);
    }
  }

  // ── Transcript URL ───────────────────────────────────────────────────────
  const transcriptUrl = params.transcriptUrl ?? player.episode?.transcriptUrl ?? undefined;

  // ── Download pill label helpers ──────────────────────────────────────────
  const downloadLabel =
    downloadState === 'done'        ? 'Downloaded' :
    downloadState === 'downloading' ? 'Saving…'    : 'Download';
  const downloadIcon =
    downloadState === 'done'        ? 'checkmark-circle' :
    downloadState === 'downloading' ? 'cloud-download-outline' :
    'arrow-down-circle-outline';

  void ActionSheetIOS;

  return (
    <Screen title="Episode" showSettings={false} titleAccessible={false}>
      {/* VoiceOver magic tap lets a two-finger double tap play or pause anywhere. */}
      <View onAccessibilityTap={handlePlayPause} style={{ flex: 1 }}>
        {/* Reading progress bar — purely visual, hidden from VoiceOver/braille */}
        <View
          style={{ height: 5, backgroundColor: colors.border }}
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          <Animated.View
            style={{
              height: 5,
              backgroundColor: colors.accent,
              width: progressAnim.interpolate({
                inputRange: [0, 1],
                outputRange: ['0%', '100%'],
                extrapolate: 'clamp',
              }),
            }}
          />
        </View>
        <ScrollView
          ref={scrollRef}
          showsVerticalScrollIndicator
          style={{ flex: 1 }}
          contentContainerStyle={{ paddingBottom: TOOLBAR_H + 16 }}
          onScroll={(e) => {
            const { contentOffset, contentSize, layoutMeasurement } = e.nativeEvent;
            const total = contentSize.height - layoutMeasurement.height;
            if (total > 0) progressAnim.setValue(Math.min(1, Math.max(0, contentOffset.y / total)));
          }}
          scrollEventThrottle={16}
        >

          {/* ── 1 + 2. Hero section (blurred backdrop + artwork + title + metadata) */}
          <Animated.View style={{
            opacity: heroAnim,
            transform: [{ translateY: heroAnim.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) }],
          }}>
            <View style={{ position: 'relative', overflow: 'hidden' }}>
              {/* Blurred backdrop — decorative */}
              {params.artworkUrl && !reduceTransparency && (
                <View
                  style={{ position: 'absolute', top: -20, left: 0, right: 0, bottom: -20 }}
                  accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
                >
                  <Image source={{ uri: params.artworkUrl }}
                    style={{ width: '100%', height: '100%', opacity: 0.22 }}
                    blurRadius={60} resizeMode="cover"
                    accessibilityIgnoresInvertColors />
                  <View style={{ ...StyleSheet.absoluteFillObject, backgroundColor: colors.background, opacity: 0.60 }} />
                </View>
              )}
              {/* Artwork with shadow */}
              <View style={{ alignItems: 'center', paddingTop: 8, paddingBottom: 16 }}>
                {params.artworkUrl ? (
                  <View style={{
                    width: 220, height: 220, borderRadius: 16,
                    shadowColor: '#000', shadowOpacity: 0.25, shadowRadius: 14,
                    shadowOffset: { width: 0, height: 8 },
                  }}>
                    <Image source={{ uri: params.artworkUrl }}
                      style={{ width: 220, height: 220, borderRadius: 16 }}
                      resizeMode="cover" accessible accessibilityRole="image"
                      accessibilityLabel={`Podcast artwork. ${params.showTitle}`}
                      accessibilityIgnoresInvertColors />
                  </View>
                ) : (
                  <Image source={require('../../assets/images/podcasts-card.png')}
                    style={{ width: 220, height: 220, borderRadius: 16 }}
                    resizeMode="cover" accessible accessibilityRole="image"
                    accessibilityIgnoresInvertColors
                    accessibilityLabel="AppleVis logo on a white background. To the left is a stylized zigzag A shape made of two angular lines, one in blue and one in gold. To the right is the word AppleVis in bold blue text. Beneath AppleVis, in smaller black text, is the tagline a Be My Eyes company, with a gold underline beneath the words Be My Eyes." />
                )}
              </View>
              {/* Episode title — standalone accessible header, VoiceOver/braille focuses here */}
              <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 8, flexWrap: 'wrap', paddingHorizontal: 16, marginBottom: 4 }}>
                <Text ref={titleRef} accessible accessibilityRole="header"
                  accessibilityLabel={params.title + (isCurrent && player.isPlaying ? '. Now playing.' : '.')}
                  style={{ fontSize: 20, fontWeight: '800', color: colors.text,
                    textAlign: 'center', lineHeight: 26, flexShrink: 1 }}>
                  {params.title}
                </Text>
                {isCurrent && <NowPlayingIndicator isPlaying={player.isPlaying} color={colors.accent} />}
                {auth.user?.isAdmin && episode && (
                  <Pressable
                    onPress={handleNodeOptions}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel="Episode options"
                    accessibilityHint="Edit, unpublish, or delete this episode"
                    style={({ pressed }) => ({ padding: 6, opacity: pressed ? 0.55 : 1 })}
                  >
                    <Ionicons name="ellipsis-horizontal" size={20} color={colors.textSecondary}
                      accessibilityElementsHidden />
                  </Pressable>
                )}
              </View>
              {/* Show title + pills — combined accessible element (swipe 2) */}
              <View
                accessible
                accessibilityLabel={[
                  params.showTitle,
                  episode.authorName ? `Submitted by ${episode.authorName}` : null,
                  publishedLabel ? `Posted ${publishedLabel}` : null,
                  mostRecentComment ? `Last comment ${relativeTime(mostRecentComment.createdAt)}` : null,
                  durationSecs > 0 ? `Duration is ${formatDurationLong(durationSecs)}` : null,
                  chapters.length > 0 ? `${chapters.length} chapter${chapters.length === 1 ? '' : 's'}` : null,
                  downloadState === 'done' ? 'Downloaded' : null,
                  isCurrent && player.currentChapter ? `Currently in chapter: ${player.currentChapter.title}` : null,
                ].filter(Boolean).join('. ') + '.'}
                style={{ marginBottom: 24 }}
              >
                <Text accessibilityElementsHidden
                  style={{ fontSize: 15, color: colors.textSecondary, textAlign: 'center', marginTop: 4 }}>
                  {params.showTitle}
                </Text>
                {!!episode.authorName && (
                  <Text accessibilityElementsHidden
                    style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center', marginTop: 2 }}>
                    Submitted by {episode.authorName}
                  </Text>
                )}
                <Text accessibilityElementsHidden
                  style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center', marginTop: 4 }}>
                  {[
                    publishedLabel ? `Posted ${publishedLabel}` : null,
                    mostRecentComment ? `Last comment ${relativeTime(mostRecentComment.createdAt)}` : null,
                  ].filter(Boolean).join(' · ')}
                </Text>
                {durationSecs > 0 && (
                  <Text
                    accessible
                    accessibilityLabel={`Duration is ${formatDurationLong(durationSecs)}.`}
                    style={{ fontSize: 14, color: colors.text, textAlign: 'center', marginTop: 8, fontWeight: '600' }}
                  >
                    Duration is {formatDurationLong(durationSecs)}.
                  </Text>
                )}
                <ScrollView horizontal showsHorizontalScrollIndicator={false}
                  contentContainerStyle={{ flexDirection: 'row', gap: 8,
                    paddingHorizontal: 16, marginTop: 10, justifyContent: 'center' }}
                  accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
                  {publishedLabel && (
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                      backgroundColor: colors.pill, borderRadius: 20, paddingHorizontal: 12, paddingVertical: 5 }}>
                      <Ionicons name="calendar-outline" size={13} color={colors.textSecondary} />
                      <Text style={{ fontSize: 12, fontWeight: '600', color: colors.textSecondary }}>
                        {publishedLabel}
                      </Text>
                    </View>
                  )}
                  {chapters.length > 0 && (
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                      backgroundColor: colors.pill, borderRadius: 20, paddingHorizontal: 12, paddingVertical: 5 }}>
                      <Ionicons name="list-outline" size={13} color={colors.textSecondary} />
                      <Text style={{ fontSize: 12, fontWeight: '600', color: colors.textSecondary }}>
                        {chapters.length} chapter{chapters.length === 1 ? '' : 's'}
                      </Text>
                    </View>
                  )}
                  {downloadState === 'done' && (
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                      backgroundColor: colors.pill, borderRadius: 20, paddingHorizontal: 12, paddingVertical: 5 }}>
                      <Ionicons name="checkmark-circle" size={13} color={colors.accent} />
                      <Text style={{ fontSize: 12, fontWeight: '600', color: colors.accent }}>Downloaded</Text>
                    </View>
                  )}
                </ScrollView>
              </View>
            </View>
          </Animated.View>

          {/* ── Animated content area ── */}
          <Animated.View style={{
            opacity: contentAnim,
            transform: [{ translateY: contentAnim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }) }],
          }}>

          {/* ── 3. Player card ───────────────────────────────────────────── */}
          <View style={[styles.card, { marginBottom: 20 }]}>
            {isCurrent && player.error && (
              <View style={{ backgroundColor: '#E5393522', borderRadius: 8, padding: 12, marginBottom: 14 }}>
                <Text style={{ color: '#E53935', fontSize: 14, marginBottom: 8 }}>
                  Playback error: {player.error}
                </Text>
                <Pressable onPress={() => player.loadEpisode(episode)}
                  accessible accessibilityRole="button" accessibilityLabel="Retry playback">
                  <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 14 }}>Retry</Text>
                </Pressable>
              </View>
            )}

            {/* Scrubber */}
            {isCurrent && durationKnown && (
              <>
                <View accessible accessibilityRole="adjustable"
                  accessibilityLabel={`Playback position. ${formatTimeSpoken(player.position)} of ${formatTimeSpoken(player.duration)}.`}
                  accessibilityValue={{ min: 0, max: Math.round(player.duration), now: Math.round(player.position) }}
                  accessibilityHint="Swipe up or down to move one minute at a time"
                  onAccessibilityAction={(e) => {
                    const newPos = e.nativeEvent.actionName === 'increment'
                      ? Math.min(player.duration, player.position + 60)
                      : Math.max(0, player.position - 60);
                    player.seekTo(newPos);
                    AccessibilityInfo.announceForAccessibility(formatTimeSpoken(newPos));
                  }}
                  style={{ marginBottom: 6 }}>
                  <View style={{ height: 6, backgroundColor: colors.border, borderRadius: 3 }}>
                    <View style={{ height: 6, backgroundColor: colors.accent, borderRadius: 3,
                      width: `${Math.round(progress * 100)}%` }} />
                  </View>
                </View>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 }}>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                    {formatTime(player.position)}
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }} accessible
                    accessibilityLabel={`${formatRemaining(player.position, player.duration)} remaining`}>
                    {formatRemaining(player.position, player.duration)}
                  </Text>
                </View>
                {player.isBuffering && (
                  <Text style={{ fontSize: 12, color: colors.textSecondary, textAlign: 'center', marginBottom: 6 }}
                    accessibilityLiveRegion="polite">
                    Buffering…
                  </Text>
                )}
                {player.currentChapter && (
                  <Text style={{ fontSize: 13, color: colors.accent, textAlign: 'center',
                    fontWeight: '600', marginBottom: 14 }}
                    accessibilityLiveRegion="polite"
                    accessibilityLabel={`Chapter: ${player.currentChapter.title}`}>
                    {player.currentChapter.title}
                  </Text>
                )}
                {!player.currentChapter && <View style={{ marginBottom: 14 }} />}
              </>
            )}

            {/* Transport row — play button has ref for initial VoiceOver focus */}
            <View style={{ flexDirection: 'row', alignItems: 'center',
              justifyContent: 'center', gap: 36, marginBottom: 20 }}>
              {isCurrent && (
                <Pressable onPress={() => player.skipBack()}
                  onLongPress={() => handleSkipLongPress('back')}
                  onPressOut={() => handleSkipPressOut('back')}
                  delayLongPress={HOLD_INITIAL_DELAY_MS}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds`}
                  accessibilityHint="Hold to cycle 1, 3, 5, 10, or 15 minutes. Release to jump."
                  hitSlop={12}>
                  <Ionicons name="play-back" size={32} color={colors.text} />
                </Pressable>
              )}
              <Pressable onPress={handlePlayPause}
                accessible accessibilityRole="button" accessibilityLabel={playLabel}
                style={{ width: 72, height: 72, borderRadius: 36,
                  backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center' }}>
                <Ionicons
                  name={isCurrent && player.isLoading ? 'hourglass-outline' :
                        isCurrent && player.isPlaying  ? 'pause' : 'play'}
                  size={32} color="#FFFFFF" />
              </Pressable>
              {isCurrent && (
                <Pressable onPress={() => player.skipForward()}
                  onLongPress={() => handleSkipLongPress('forward')}
                  onPressOut={() => handleSkipPressOut('forward')}
                  delayLongPress={HOLD_INITIAL_DELAY_MS}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`}
                  accessibilityHint="Hold to cycle 1, 3, 5, 10, or 15 minutes. Release to jump."
                  hitSlop={12}>
                  <Ionicons name="play-forward" size={32} color={colors.text} />
                </Pressable>
              )}
            </View>

            {/* Speed */}
            {isCurrent && (
              <Pressable onPress={cycleSpeedForward} accessible accessibilityRole="adjustable"
                accessibilityLabel="Playback speed" accessibilityValue={{ text: `${player.speed}×` }}
                accessibilityHint="Double tap to cycle forward. Swipe up to increase, swipe down to decrease."
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment' && speedIdx < SPEED_OPTIONS.length - 1) {
                    const next = SPEED_OPTIONS[speedIdx + 1]; player.setSpeed(next);
                    AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
                  }
                  if (e.nativeEvent.actionName === 'decrement' && speedIdx > 0) {
                    const next = SPEED_OPTIONS[speedIdx - 1]; player.setSpeed(next);
                    AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
                  }
                }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Playback Speed</Text>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                  <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '700' }}>{player.speed}×</Text>
                  <Ionicons name="repeat" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                </View>
              </Pressable>
            )}

            {/* Volume */}
            {isCurrent && (
              <View accessible accessibilityRole="adjustable" accessibilityLabel="Volume"
                accessibilityValue={{ text: volumePct, min: 0, max: 100, now: Math.round(player.volume * 100) }}
                accessibilityHint="Swipe up to increase, swipe down to decrease"
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment') {
                    const newIdx = Math.min(volumeSteps.length - 1, volumeIdx + 1);
                    setVolumeIdx(newIdx);
                    AccessibilityInfo.announceForAccessibility(`Volume ${Math.round(volumeSteps[newIdx] * 100)}%`);
                  }
                  if (e.nativeEvent.actionName === 'decrement') {
                    const newIdx = Math.max(0, volumeIdx - 1);
                    setVolumeIdx(newIdx);
                    AccessibilityInfo.announceForAccessibility(`Volume ${Math.round(volumeSteps[newIdx] * 100)}%`);
                  }
                }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Volume</Text>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <Pressable onPress={() => setVolumeIdx(volumeIdx - 1)} accessible={false} hitSlop={8}>
                    <Ionicons name="volume-low-outline" size={20} color={colors.textSecondary} />
                  </Pressable>
                  <View style={{ width: 80, height: 4, backgroundColor: colors.border, borderRadius: 2 }}>
                    <View style={{ height: 4, backgroundColor: colors.accent, borderRadius: 2,
                      width: `${Math.round(player.volume * 100)}%` }} />
                  </View>
                  <Pressable onPress={() => setVolumeIdx(volumeIdx + 1)} accessible={false} hitSlop={8}>
                    <Ionicons name="volume-high-outline" size={20} color={colors.textSecondary} />
                  </Pressable>
                  <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '700',
                    minWidth: 36, textAlign: 'right' }}>{volumePct}</Text>
                </View>
              </View>
            )}

            {/* Sleep timer */}
            {isCurrent && (
              <View accessible accessibilityRole="adjustable" accessibilityLabel="Sleep timer"
                accessibilityValue={{ text: sleepDisplayLabel }}
                accessibilityHint="Swipe up to increase, swipe down to decrease or turn off. 'End of Episode' stops after the current episode finishes."
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment') {
                    const newIdx = Math.min(SLEEP_MINS.length - 1, sleepIdx + 1);
                    applySleepIdx(newIdx);
                    AccessibilityInfo.announceForAccessibility(`Sleep timer: ${sleepLabel(SLEEP_MINS[newIdx])}`);
                  }
                  if (e.nativeEvent.actionName === 'decrement') {
                    const newIdx = Math.max(0, sleepIdx - 1);
                    applySleepIdx(newIdx);
                    AccessibilityInfo.announceForAccessibility(`Sleep timer: ${sleepLabel(SLEEP_MINS[newIdx])}`);
                  }
                }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}>
                <View>
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Sleep Timer</Text>
                  {player.sleepAtEndOfEpisode && (
                    <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                      Stops when this episode finishes
                    </Text>
                  )}
                </View>
                <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '700' }}>{sleepDisplayLabel}</Text>
              </View>
            )}

            {/* Trim silence */}
            <Pressable onPress={() => { const n = !podcastTrimSilence; setPodcastTrimSilence(n); AccessibilityInfo.announceForAccessibility(`Trim Silence ${n ? 'on' : 'off'}`); }}
              accessible accessibilityRole="switch" accessibilityState={{ checked: podcastTrimSilence }}
              accessibilityLabel="Trim Silence. Skips silent gaps."
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 4,
                paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Trim Silence</Text>
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>Skips silent gaps in episodes</Text>
              </View>
              <View style={{ width: 44, height: 26, borderRadius: 13,
                backgroundColor: podcastTrimSilence ? colors.accent : colors.border,
                justifyContent: 'center', padding: 2 }} accessibilityElementsHidden>
                <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: '#FFFFFF',
                  alignSelf: podcastTrimSilence ? 'flex-end' : 'flex-start' }} />
              </View>
            </Pressable>

            {/* Voice Boost */}
            <Pressable onPress={() => { const n = !podcastVoiceBoost; setPodcastVoiceBoost(n); AccessibilityInfo.announceForAccessibility(`Voice Boost ${n ? 'on' : 'off'}`); }}
              accessible accessibilityRole="switch" accessibilityState={{ checked: podcastVoiceBoost }}
              accessibilityLabel="Voice Boost. Enhances speech clarity."
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12,
                paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Voice Boost</Text>
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  Enhances speech clarity and normalises volume
                </Text>
              </View>
              <View style={{ width: 44, height: 26, borderRadius: 13,
                backgroundColor: podcastVoiceBoost ? colors.accent : colors.border,
                justifyContent: 'center', padding: 2 }} accessibilityElementsHidden>
                <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: '#FFFFFF',
                  alignSelf: podcastVoiceBoost ? 'flex-end' : 'flex-start' }} />
              </View>
            </Pressable>
          </View>

          {/* ── 4. Chapters (shown whenever chapters are known) ───────────── */}
          {chapters.length > 0 && (
            <View
              style={[styles.card, { marginBottom: 20 }]}
              accessible
              accessibilityLabel={`Chapters. ${chapters.length} chapters.${isCurrent && player.currentChapter ? ` Currently in: ${player.currentChapter.title}.` : ''}`}
              accessibilityActions={chapterActions}
              onAccessibilityAction={({ nativeEvent }) => {
                const chapter = chapters.find(c => `chapter_${c.startTime}` === nativeEvent.actionName);
                if (chapter && isCurrent) {
                  player.skipToChapter(chapter);
                  AccessibilityInfo.announceForAccessibility(`Jumping to ${chapter.title}`);
                }
              }}
            >
              <Text style={[styles.cardTitle, { marginBottom: 12 }]} accessibilityRole="header">
                Chapters
              </Text>
              {chapters.map((chapter) => {
                const isActive = isCurrent && player.currentChapter?.title === chapter.title;
                const prog = chapterProgress(chapter);
                return (
                  <Pressable
                    key={chapter.startTime}
                    onPress={() => {
                      if (isCurrent) {
                        player.skipToChapter(chapter);
                        AccessibilityInfo.announceForAccessibility(`Jumping to ${chapter.title}`);
                      } else {
                        player.loadEpisode(episode);
                      }
                    }}
                    accessible accessibilityRole="button"
                    accessibilityLabel={
                      `${chapter.title}. Starts at ${formatTime(chapter.startTime)}` +
                      (isActive ? '. Currently playing.' : '') +
                      (!isCurrent ? '. Double tap to play episode.' : '')
                    }
                    style={{ paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border }}
                  >
                    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}>
                        {isActive && <Ionicons name="volume-medium" size={14} color={colors.accent} accessibilityElementsHidden />}
                        <Text style={{ flex: 1, fontSize: 15, fontWeight: isActive ? '700' : '400',
                          color: isActive ? colors.accent : colors.text }}>
                          {chapter.title}
                        </Text>
                      </View>
                      <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                        {formatTime(chapter.startTime)}
                      </Text>
                    </View>
                    {isCurrent && prog > 0 && (
                      <View style={{ height: 2, backgroundColor: colors.border, borderRadius: 1, marginTop: 6 }}>
                        <View style={{ height: 2, backgroundColor: colors.accent, borderRadius: 1,
                          width: `${Math.round(prog * 100)}%` }} />
                      </View>
                    )}
                  </Pressable>
                );
              })}
            </View>
          )}

          {/* ── 5. Live transcript ───────────────────────────────────────── */}
          {transcriptUrl && isCurrent && (
            <VttTranscript url={transcriptUrl} currentPosition={player.position} />
          )}

          {/* ── 6. Read Show Notes aloud pill + Show Notes ───────────────── */}
          {!!params.description && (
            <>
              {!screenReaderEnabled && (
                <Pressable
                  onPress={() => readAloud(stripHtmlPlain(params.description ?? ''))}
                  accessible accessibilityRole="button"
                  accessibilityLabel="Read show notes aloud"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    alignSelf: 'flex-start', backgroundColor: colors.pill, borderRadius: 10,
                    paddingHorizontal: 14, paddingVertical: 10, marginBottom: 10 }}
                >
                  <Ionicons name="volume-medium-outline" size={16} color={colors.pillText} accessibilityElementsHidden />
                  <Text style={{ fontSize: 14, fontWeight: '600', color: colors.pillText }}>
                    Read Show Notes
                  </Text>
                </Pressable>
              )}
              <View>
                <ShowNotes
                  rawHtml={params.description}
                  textSize={notesTextSize}
                  expanded={notesExpanded}
                  onToggleExpand={() => setNotesExpanded(v => !v)}
                  onIncreaseText={() => setNotesTextSize(s => Math.min(22, s + 1))}
                  onDecreaseText={() => setNotesTextSize(s => Math.max(13, s - 1))}
                />
              </View>
            </>
          )}

          {/* ── 7. Apple Intelligence ────────────────────────────────────── */}
          {aiAvailable && (
          <View style={[styles.card, { marginBottom: 20 }]}>
            <SectionDivider label="Apple Intelligence" />
            <Pressable
              onPress={handleAiSummarise}
              disabled={!aiAvailable || !params.description || aiWorking}
              accessible accessibilityRole="button"
              accessibilityLabel={aiSummary ? 'Summarise Show Notes. Tap to hide summary.' : 'Summarise Show Notes'}
              accessibilityHint={
                !aiAvailable ? 'Requires iPhone 16 or later with Apple Intelligence enabled in Settings' :
                !params.description ? 'No show notes available to summarise' :
                aiWorking ? 'Summarising, please wait' : undefined
              }
              style={({ pressed }) => ({
                flexDirection: 'row', alignItems: 'center', gap: 14,
                paddingVertical: 12, opacity: pressed ? 0.65 : 1,
              })}
            >
              <View style={{ width: 44, height: 44, borderRadius: 22,
                backgroundColor: aiAvailable ? `${colors.accent}18` : colors.inputBackground,
                alignItems: 'center', justifyContent: 'center' }}>
                <Ionicons name={aiWorking ? 'hourglass-outline' : 'sparkles'}
                  size={22} color={aiAvailable ? colors.accent : colors.textSecondary}
                  accessibilityElementsHidden />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                  {aiWorking ? 'Summarising…' : 'Summarise Show Notes'}
                </Text>
                {!aiAvailable && (
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                    Requires iPhone 16 with Apple Intelligence enabled
                  </Text>
                )}
              </View>
              <Ionicons name={aiSummary ? 'chevron-up' : 'chevron-down'}
                size={18} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>
            {aiSummary && (
              <View style={{ marginTop: 4, paddingTop: 14, borderTopWidth: 1, borderTopColor: colors.border }}>
                <Text accessible style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
                  {aiSummary}
                </Text>
              </View>
            )}
          </View>
          )}{/* end aiAvailable */}

          {/* ── 8. Play Next / Add to Queue ─────────────────────────────── */}
          <View style={[styles.card, { marginBottom: 20 }]}>
            <Pressable
              onPress={() => { player.playNext(episode); showToast('Added — plays after current episode'); AccessibilityInfo.announceForAccessibility('Added to play next'); }}
              disabled={isCurrent || isQueued}
              accessible accessibilityRole="button"
              accessibilityLabel={isCurrent ? 'Episode is currently playing' : isQueued ? 'Already in queue' : 'Play next — inserts immediately after the current episode'}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10 }}
            >
              <Ionicons name="play-skip-forward-outline" size={22}
                color={isCurrent || isQueued ? colors.textSecondary : colors.accent} accessibilityElementsHidden />
              <Text style={{ fontSize: 15, fontWeight: '600',
                color: isCurrent || isQueued ? colors.textSecondary : colors.text }}>Play Next</Text>
            </Pressable>
            <View style={{ height: 1, backgroundColor: colors.border }} />
            <Pressable
              onPress={() => {
                if (isQueued) { player.removeFromQueue(params.id); showToast('Removed from queue'); AccessibilityInfo.announceForAccessibility('Removed from queue'); }
                else { player.enqueue(episode); showToast('Added to end of queue'); AccessibilityInfo.announceForAccessibility('Added to queue'); }
              }}
              disabled={isCurrent}
              accessible accessibilityRole="button"
              accessibilityLabel={isCurrent ? 'Episode is currently playing' : isQueued ? 'Remove from queue' : 'Add to queue'}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10 }}
            >
              <Ionicons name={isQueued ? 'checkmark-circle' : 'add-circle-outline'} size={22}
                color={isCurrent ? colors.textSecondary : colors.accent} accessibilityElementsHidden />
              <Text style={{ fontSize: 15, fontWeight: '600', color: isCurrent ? colors.textSecondary : colors.text }}>
                {isQueued ? 'Remove from Queue' : 'Add to Queue'}
              </Text>
            </Pressable>
          </View>

          {/* ── 10. Queue status ─────────────────────────────────────────── */}
          <Pressable onPress={() => router.push('/queue' as any)}
            accessible accessibilityRole="button"
            accessibilityLabel={`View queue. ${player.queue.length} episode${player.queue.length === 1 ? '' : 's'} up next.`}
            style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 }]}>
            <Ionicons name="list" size={22} color={colors.accent} accessibilityElementsHidden />
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Queue</Text>
              <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                {player.queue.length === 0 ? 'Nothing queued up next'
                  : `${player.queue.length} episode${player.queue.length === 1 ? '' : 's'} up next`}
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>

          {/* ── 11. Mark as Played ───────────────────────────────────────── */}
          <Pressable onPress={handleMarkAsPlayed}
            accessible accessibilityRole="button"
            accessibilityLabel="Mark as played — clears playback position so the episode starts fresh"
            style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 }]}>
            <Ionicons name="checkmark-done-outline" size={22} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, flex: 1 }}>Mark as Played</Text>
          </Pressable>

          {/* ── 12. Community Discussion ─────────────────────────────────── */}
          <View onLayout={(e) => { discussionY.current = e.nativeEvent.layout.y; }}>
            <SectionDivider label={
              commentsLoading ? 'Community Discussion' :
              commentsError ? 'Community Discussion' :
              comments.length > 0
                ? `Community Discussion - ${comments.length} comment${comments.length === 1 ? '' : 's'}` +
                  (newCommentCount > 0 ? ` - ${newCommentCount} new` : '')
              : 'Community Discussion'
            } />

            <Pressable
              onPress={handleAddComment}
              accessible
              accessibilityRole="button"
              accessibilityLabel={auth.isSignedIn ? 'Post a comment' : 'Sign in to post a comment'}
              style={({ pressed }) => [styles.cardSmall, {
                flexDirection: 'row', alignItems: 'center', gap: 12,
                marginBottom: 12,
                opacity: pressed ? 0.75 : 1,
              }]}
            >
              <Ionicons name="create-outline" size={22} color={colors.accent} accessibilityElementsHidden />
              <View style={{ flex: 1 }} accessibilityElementsHidden>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                  {auth.isSignedIn ? 'Post a Comment' : 'Sign In to Comment'}
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 2 }}>
                  Share your thoughts about this episode
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>

            {firstNewComment && (
              <Pressable
                onPress={() => handleJumpToNewComment(firstNewComment.id)}
                accessible
                accessibilityRole="button"
                accessibilityLabel={`Jump to first new comment. ${newCommentCount} new since your last visit.`}
                style={[styles.card, {
                  flexDirection: 'row', alignItems: 'center', gap: 10,
                  marginBottom: 12, paddingVertical: 12,
                }]}
              >
                <Ionicons name="flag-outline" size={18} color={colors.accent} accessibilityElementsHidden />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 14, fontWeight: '700', color: colors.accent }}>
                    Jump to First New Comment
                  </Text>
                  <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                    {newCommentCount} new since your last visit
                  </Text>
                </View>
                <Ionicons name="arrow-down-outline" size={16} color={colors.accent} accessibilityElementsHidden />
              </Pressable>
            )}

            {aiAvailable && comments.length > 0 && (
              <View style={[styles.card, { marginBottom: 12 }]}>
                <Pressable
                  onPress={handleSummariseDiscussion}
                  disabled={discussionAiWorking}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={discussionSummary ? 'Summarise Discussion. Tap to hide summary.' : 'Summarise Discussion'}
                  accessibilityHint={discussionAiWorking ? 'Summarising, please wait' : undefined}
                  style={({ pressed }) => ({
                    flexDirection: 'row', alignItems: 'center', gap: 12,
                    paddingVertical: 4, opacity: pressed || discussionAiWorking ? 0.65 : 1,
                  })}
                >
                  <Ionicons name={discussionAiWorking ? 'hourglass-outline' : 'sparkles'}
                    size={22} color={colors.accent} accessibilityElementsHidden />
                  <Text style={{ flex: 1, fontSize: 15, fontWeight: '600', color: colors.text }}>
                    {discussionAiWorking ? 'Summarising...' : 'Summarise Discussion'}
                  </Text>
                  <Ionicons name={discussionSummary ? 'chevron-up' : 'chevron-down'}
                    size={18} color={colors.textSecondary} accessibilityElementsHidden />
                </Pressable>
                {discussionSummary && (
                  <Text accessible style={{ marginTop: 12, paddingTop: 12, borderTopWidth: 1, borderTopColor: colors.border,
                    fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
                    {discussionSummary}
                  </Text>
                )}
              </View>
            )}

            {commentsLoading ? (
              <View style={{ alignItems: 'center', paddingVertical: 24 }}>
                <ActivityIndicator size="large" color={colors.accent} />
                <Text style={{ fontSize: 14, color: colors.textSecondary, marginTop: 10 }}>
                  Loading comments...
                </Text>
              </View>
            ) : commentsError ? (
              <View style={[styles.card, { borderColor: '#FCA5A5', borderWidth: 1, alignItems: 'center', paddingVertical: 20 }]}>
                <Ionicons name="alert-circle-outline" size={28} color="#B91C1C" accessibilityElementsHidden />
                <Text style={{ fontSize: 14, color: '#B91C1C', fontWeight: '600', marginTop: 8 }}>
                  Could not load comments
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary, marginTop: 4, textAlign: 'center' }}>
                  {commentsError}
                </Text>
              </View>
            ) : comments.length > 0 ? (
              comments.map((comment, i) => {
                const isFirstNew = comment.isNew && comment.id === firstNewComment?.id;
                return (
                  <View
                    key={comment.id}
                    ref={isFirstNew ? (v) => { firstNewCommentRef.current = v; } : undefined}
                    onLayout={(e) => { commentOffsets.current[comment.id] = e.nativeEvent.layout.y; }}
                  >
                    <EpisodeCommentCard
                      comment={comment}
                      index={i}
                      total={comments.length}
                      episodeTitle={params.title}
                      onReply={() => handleReplyToComment(comment)}
                      hasLoved={lovedCommentIds.has(comment.id)}
                      loveCount={(comment.loveCount ?? 0) + (lovedCommentIds.has(comment.id) ? 1 : 0)}
                      onLove={() => handleLoveComment(comment)}
                    />
                  </View>
                );
              })
            ) : (
              <View style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}
                accessible accessibilityLabel="No comments yet. Be the first to share your thoughts.">
                <Ionicons name="chatbubbles-outline" size={32} color={colors.textSecondary}
                  style={{ marginBottom: 8 }} accessibilityElementsHidden />
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, marginBottom: 6 }}
                  accessibilityElementsHidden>
                  No comments yet
                </Text>
                <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}
                  accessibilityElementsHidden>
                  Be the first to share your thoughts about this episode.
                </Text>
              </View>
            )}
          </View>

          {/* ── 13. Back to Top ──────────────────────────────────────────── */}
          <Pressable
            onPress={() => scrollRef.current?.scrollTo({ y: 0, animated: true })}
            accessible accessibilityRole="button"
            accessibilityLabel="Back to Top"
            accessibilityHint="Scrolls back to the beginning of this page"
            style={{ alignItems: 'center', paddingVertical: 16 }}
          >
            <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>Back to Top</Text>
          </Pressable>

          </Animated.View>{/* end contentAnim */}

        </ScrollView>

        {/* ── Fixed bottom toolbar ──────────────────────────────────────── */}
        <View
          style={{ flexDirection: 'row', height: TOOLBAR_H, paddingHorizontal: 4,
            backgroundColor: colors.card, borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: colors.border, alignItems: 'center' }}
          accessibilityRole="toolbar" accessibilityLabel="Episode actions"
        >
          <ToolbarButton icon="list-outline" activeIcon="checkmark-circle"
            label={isQueued ? 'Remove\nfrom Queue' : 'Queue this\nEpisode'}
            active={isQueued} disabled={isCurrent} onPress={handleQueueToggle} />
          <ToolbarButton icon="bookmark-outline" activeIcon="bookmark"
            label={isSaved ? 'Saved' : 'Save this\nEpisode'}
            active={isSaved} onPress={handleSaveToggle} />
          <ToolbarButton icon="share-outline" label={'Share this\nEpisode'} a11yLabel="Share this Episode" onPress={handleShare} />
          <ToolbarButton icon="radio-outline" label={'AirPlay'} onPress={() => showAirPlayPicker()} />
          <ToolbarButton icon="pencil-outline" label={'Add New\nComment'} onPress={handleAddComment} accent />
        </View>
      </View>

      {/* Admin Edit Episode Modal */}
      {editingNode && episode && auth.user?.csrfToken && (
        <EditContentModal
          visible={editingNode}
          onClose={() => setEditingNode(false)}
          onSaved={(newBody, newTitle) => {
            setFetchedData(e => e ? { ...e, description: newBody, title: newTitle ?? e.title } : e);
            showToast('Episode updated.', 'success');
          }}
          nodeId={episode.id}
          nodeType="podcast"
          initialTitle={episode.title}
          csrfToken={auth.user.csrfToken}
          initialBody={episode.description}
          label="Episode"
        />
      )}
    </Screen>
  );
}
