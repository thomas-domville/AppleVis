import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, Clipboard, findNodeHandle,
  Image, Linking, Modal, Platform,
  Pressable, ScrollView, Share, StyleSheet, Text, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { useToast } from '../../src/contexts/ToastContext';
import { useAuth } from '../../src/contexts/AuthContext';
import { SPEED_OPTIONS, SLEEP_TIMER_OPTIONS, SLEEP_END_OF_EPISODE } from '../../src/hooks/usePodcastPlayer';
import { downloadEpisode, deleteDownload, getLocalUri } from '../../src/services/downloads';
import { persistence } from '../../src/services/persistence';
import { showAirPlayPicker } from '../../src/native/nativeModules';
import { isAppleIntelligenceAvailable, readAloud, summariseText } from '../../src/services/intelligenceService';
import { relativeTime } from '../../src/utils/relativeTime';
import type { PodcastEpisode } from '../../src/types/content';

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

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
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

function ShowNotes({ rawHtml }: { rawHtml: string }) {
  const { colors, styles } = useTheme();
  const [transcriptOpen, setTranscriptOpen] = useState(false);
  const { body, links, transcript } = useMemo(() => parseShowNotes(rawHtml), [rawHtml]);

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
          <View style={{ flex: 1, backgroundColor: colors.background }}>
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
                <Text
                  key={i}
                  accessible
                  style={{ fontSize: 15, lineHeight: 24, color: colors.text, marginBottom: 10 }}
                >
                  {line}
                </Text>
              ))}
            </ScrollView>
          </View>
        </Modal>
      )}

      <View style={[styles.card, { marginBottom: 20 }]}>
        <Text style={[styles.cardTitle, { marginBottom: 8 }]} accessibilityRole="header">
          About this episode
        </Text>

        {body.map((para, i) => (
          <Text
            key={i}
            accessible
            style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary, marginBottom: 6 }}
          >
            {para}
          </Text>
        ))}

        {links.length > 0 && (
          <View style={{ gap: 10, marginTop: body.length > 0 ? 10 : 4 }}>
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
  icon, activeIcon, label, onPress, active, accent, disabled,
}: {
  icon: string; activeIcon?: string; label: string; onPress: () => void;
  active?: boolean; accent?: boolean; disabled?: boolean;
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
      accessibilityLabel={label.replace(/\n/g, ' ')}
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

// ─── Main screen ──────────────────────────────────────────────────────────────
const TOOLBAR_H = 58;

export default function EpisodeDetail() {
  const params = useLocalSearchParams<{
    id: string; title: string; showTitle: string;
    description?: string; artworkUrl?: string;
    publishedAt?: string; duration?: string; audioUrl: string;
    transcriptUrl?: string; url?: string;
  }>();

  const router  = useRouter();
  const player  = usePlayer();
  const auth    = useAuth();
  const { colors, styles } = useTheme();
  const { podcastTrimSilence, setPodcastTrimSilence, podcastVoiceBoost, setPodcastVoiceBoost } = usePreferences();
  const { showToast } = useToast();
  const aiAvailable = isAppleIntelligenceAvailable();
  const insets = useSafeAreaInsets();

  const isCurrent     = player.episode?.id === params.id;
  const isQueued      = player.queue.some(e => e.id === params.id);
  const durationSecs  = Number(params.duration ?? 0);
  const progress      = isCurrent && player.duration > 0 ? player.position / player.duration : 0;
  const durationKnown = isCurrent && player.duration > 0;
  const episodeUrl    = params.url || undefined;

  const publishedLabel = params.publishedAt ? relativeTime(params.publishedAt) : null;

  // ── Episode object ───────────────────────────────────────────────────────
  const episode = useMemo<PodcastEpisode>(() => ({
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
  }), [params.id, params.title, params.showTitle, params.description,
      params.artworkUrl, params.publishedAt, durationSecs, params.audioUrl,
      params.transcriptUrl, episodeUrl]);

  // ── Refs ─────────────────────────────────────────────────────────────────
  const scrollRef   = useRef<ScrollView>(null);
  const discussionY = useRef<number>(0);

  // ── Save state ───────────────────────────────────────────────────────────
  const [isSaved, setIsSaved] = useState(false);

  // ── Download state ───────────────────────────────────────────────────────
  const [downloadState, setDownloadState] = useState<DownloadState>('idle');

  // ── AI state ─────────────────────────────────────────────────────────────
  const [aiWorking, setAiWorking] = useState(false);
  const [aiSummary, setAiSummary] = useState<string | null>(null);

  useEffect(() => {
    persistence.getSavedItems()
      .then(items => setIsSaved(items.some(s => s.id === params.id)))
      .catch(() => {});
    getLocalUri(params.id)
      .then(uri => setDownloadState(uri ? 'done' : 'idle'))
      .catch(() => {});
  }, [params.id]);

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
  const chapters = (isCurrent ? player.episode?.chapters : undefined) ?? [];
  const chapterActions = chapters.map(c => ({
    name: `chapter_${c.startTime}`,
    label: `${c.title} — ${formatTime(c.startTime)}`,
  }));

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
      showToast('Sign in to add a new comment.', 'warning');
      return;
    }
    router.push({
      pathname: '/episode/comments/[id]' as any,
      params: {
        id: params.id,
        title: params.title,
        showTitle: params.showTitle,
        url: params.url ?? '',
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

  // ── unused import suppressors ────────────────────────────────────────────
  void ActionSheetIOS;
  void findNodeHandle;

  return (
    <Screen title="Episode" showSettings={false}>
      {/* onMagicTap lets VoiceOver two-finger double tap play/pause anywhere */}
      <View onMagicTap={handlePlayPause} style={{ flex: 1 }}>
        <ScrollView ref={scrollRef} showsVerticalScrollIndicator style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: TOOLBAR_H + 16 }}>

          {/* ── Artwork ──────────────────────────────────────────────────── */}
          <View style={{ alignItems: 'center', marginBottom: 20, marginTop: 8 }}>
            {params.artworkUrl ? (
              <Image
                source={{ uri: params.artworkUrl }}
                style={{ width: 220, height: 220, borderRadius: 16 }}
                resizeMode="cover"
                accessible
                accessibilityRole="image"
                accessibilityLabel={`Podcast artwork. ${params.showTitle}`}
              />
            ) : (
              <Image
                source={require('../../assets/images/podcasts-card.png')}
                style={{ width: 220, height: 220, borderRadius: 16 }}
                resizeMode="cover"
                accessible
                accessibilityRole="image"
                accessibilityLabel="Podcast artwork. White image background with a logo and text in the center bottom area. On the left, there is an abstract symbol made of three angled lines forming a stylized letter A or V. The top and middle segments of the symbol are orange, and the bottom segment is blue. To the right of the symbol, in large blue letters, it says AppleVis. Below AppleVis, in smaller black letters, it says a Be My Eyes company. The word company is underlined with a slanted yellow highlight."
              />
            )}
          </View>

          {/* ── Metadata band — single compound label for braille displays ─ */}
          <View
            accessible
            accessibilityLabel={[
              params.title,
              params.showTitle,
              publishedLabel,
              durationSecs > 0 ? formatDuration(durationSecs) : null,
            ].filter(Boolean).join('. ') + '.'}
            style={{ marginBottom: 24 }}
          >
            <Text accessibilityElementsHidden
              style={{ fontSize: 20, fontWeight: '800', color: colors.text,
                textAlign: 'center', lineHeight: 26 }}>
              {params.title}
            </Text>
            <Text accessibilityElementsHidden
              style={{ fontSize: 15, color: colors.textSecondary, textAlign: 'center', marginTop: 4 }}>
              {params.showTitle}
            </Text>
            {(publishedLabel || durationSecs > 0) && (
              <Text accessibilityElementsHidden
                style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center', marginTop: 4 }}>
                {[publishedLabel, durationSecs > 0 ? formatDuration(durationSecs) : null].filter(Boolean).join(' · ')}
              </Text>
            )}
          </View>

          {/* ── Player card ──────────────────────────────────────────────── */}
          <View style={[styles.card, { marginBottom: 20 }]}>

            {isCurrent && player.error && (
              <View style={{ backgroundColor: '#E5393522', borderRadius: 8, padding: 12, marginBottom: 14 }}>
                <Text style={{ color: '#E53935', fontSize: 14, marginBottom: 8 }}>
                  Playback error: {player.error}
                </Text>
                <Pressable
                  onPress={() => player.loadEpisode(episode)}
                  accessible accessibilityRole="button"
                  accessibilityLabel="Retry playback"
                >
                  <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 14 }}>Retry</Text>
                </Pressable>
              </View>
            )}

            {/* Scrubber */}
            {isCurrent && durationKnown && (
              <>
                <View
                  accessible
                  accessibilityRole="adjustable"
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
                  style={{ marginBottom: 6 }}
                >
                  <View style={{ height: 6, backgroundColor: colors.border, borderRadius: 3 }}>
                    <View style={{ height: 6, backgroundColor: colors.accent, borderRadius: 3,
                      width: `${Math.round(progress * 100)}%` }} />
                  </View>
                </View>

                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 }}>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                    {formatTime(player.position)}
                  </Text>
                  <Text
                    style={{ fontSize: 13, color: colors.textSecondary }}
                    accessible
                    accessibilityLabel={`${formatRemaining(player.position, player.duration)} remaining`}
                  >
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
                  <Text
                    style={{ fontSize: 13, color: colors.accent, textAlign: 'center',
                      fontWeight: '600', marginBottom: 14 }}
                    accessibilityLiveRegion="polite"
                    accessibilityLabel={`Chapter: ${player.currentChapter.title}`}>
                    {player.currentChapter.title}
                  </Text>
                )}
                {!player.currentChapter && <View style={{ marginBottom: 14 }} />}
              </>
            )}

            {/* Transport row */}
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
              gap: 36, marginBottom: 20 }}>

              {isCurrent && (
                <Pressable
                  onPress={() => player.skipBack()}
                  onLongPress={() => handleSkipLongPress('back')}
                  onPressOut={() => handleSkipPressOut('back')}
                  delayLongPress={HOLD_INITIAL_DELAY_MS}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds`}
                  accessibilityHint="Hold to cycle 1, 3, 5, 10, or 15 minutes. Release to jump."
                  hitSlop={12}
                >
                  <Ionicons name="play-back" size={32} color={colors.text} />
                </Pressable>
              )}

              <Pressable
                onPress={handlePlayPause}
                accessible accessibilityRole="button"
                accessibilityLabel={playLabel}
                style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: colors.accent,
                  alignItems: 'center', justifyContent: 'center' }}
              >
                <Ionicons
                  name={isCurrent && player.isLoading ? 'hourglass-outline' :
                        isCurrent && player.isPlaying  ? 'pause' : 'play'}
                  size={32} color="#FFFFFF"
                />
              </Pressable>

              {isCurrent && (
                <Pressable
                  onPress={() => player.skipForward()}
                  onLongPress={() => handleSkipLongPress('forward')}
                  onPressOut={() => handleSkipPressOut('forward')}
                  delayLongPress={HOLD_INITIAL_DELAY_MS}
                  accessible accessibilityRole="button"
                  accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`}
                  accessibilityHint="Hold to cycle 1, 3, 5, 10, or 15 minutes. Release to jump."
                  hitSlop={12}
                >
                  <Ionicons name="play-forward" size={32} color={colors.text} />
                </Pressable>
              )}
            </View>

            {/* Speed row */}
            {isCurrent && (
              <Pressable
                onPress={cycleSpeedForward}
                accessible
                accessibilityRole="adjustable"
                accessibilityLabel="Playback speed"
                accessibilityValue={{ text: `${player.speed}×` }}
                accessibilityHint="Double tap to cycle forward. Swipe up to increase, swipe down to decrease."
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment' && speedIdx < SPEED_OPTIONS.length - 1) {
                    const next = SPEED_OPTIONS[speedIdx + 1];
                    player.setSpeed(next);
                    AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
                  }
                  if (e.nativeEvent.actionName === 'decrement' && speedIdx > 0) {
                    const next = SPEED_OPTIONS[speedIdx - 1];
                    player.setSpeed(next);
                    AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
                  }
                }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                  Playback Speed
                </Text>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                  <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '700' }}>
                    {player.speed}×
                  </Text>
                  <Ionicons name="repeat" size={16} color={colors.textSecondary} accessibilityElementsHidden />
                </View>
              </Pressable>
            )}

            {/* Volume row */}
            {isCurrent && (
              <View
                accessible
                accessibilityRole="adjustable"
                accessibilityLabel="Volume"
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
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}
              >
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
                  <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '700', minWidth: 36,
                    textAlign: 'right' }}>
                    {volumePct}
                  </Text>
                </View>
              </View>
            )}

            {/* Sleep timer */}
            {isCurrent && (
              <View
                accessible
                accessibilityRole="adjustable"
                accessibilityLabel="Sleep timer"
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
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View>
                  <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Sleep Timer</Text>
                  {player.sleepAtEndOfEpisode && (
                    <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                      Stops when this episode finishes
                    </Text>
                  )}
                </View>
                <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '700' }}>
                  {sleepDisplayLabel}
                </Text>
              </View>
            )}

            {/* Trim silence */}
            <Pressable
              onPress={() => {
                const next = !podcastTrimSilence;
                setPodcastTrimSilence(next);
                AccessibilityInfo.announceForAccessibility(`Trim Silence ${next ? 'on' : 'off'}`);
              }}
              accessible
              accessibilityRole="switch"
              accessibilityState={{ checked: podcastTrimSilence }}
              accessibilityLabel="Trim Silence. Skips silent gaps."
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12,
                marginTop: 4, paddingVertical: 12,
                borderTopWidth: 1, borderTopColor: colors.border }}
            >
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Trim Silence</Text>
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  Skips silent gaps in episodes
                </Text>
              </View>
              <View style={{
                width: 44, height: 26, borderRadius: 13,
                backgroundColor: podcastTrimSilence ? colors.accent : colors.border,
                justifyContent: 'center', padding: 2,
              }} accessibilityElementsHidden>
                <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: '#FFFFFF',
                  alignSelf: podcastTrimSilence ? 'flex-end' : 'flex-start' }} />
              </View>
            </Pressable>

            {/* Voice Boost */}
            <Pressable
              onPress={() => {
                const next = !podcastVoiceBoost;
                setPodcastVoiceBoost(next);
                AccessibilityInfo.announceForAccessibility(`Voice Boost ${next ? 'on' : 'off'}`);
              }}
              accessible
              accessibilityRole="switch"
              accessibilityState={{ checked: podcastVoiceBoost }}
              accessibilityLabel="Voice Boost. Enhances speech clarity."
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12,
                paddingVertical: 12,
                borderTopWidth: 1, borderTopColor: colors.border }}
            >
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Voice Boost</Text>
                <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>
                  Enhances speech clarity and normalises volume
                </Text>
              </View>
              <View style={{
                width: 44, height: 26, borderRadius: 13,
                backgroundColor: podcastVoiceBoost ? colors.accent : colors.border,
                justifyContent: 'center', padding: 2,
              }} accessibilityElementsHidden>
                <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: '#FFFFFF',
                  alignSelf: podcastVoiceBoost ? 'flex-end' : 'flex-start' }} />
              </View>
            </Pressable>
          </View>

          {/* ── Play Next / Add to Queue ──────────────────────────────────── */}
          <View style={[styles.card, { marginBottom: 20 }]}>
            <Pressable
              onPress={() => {
                player.playNext(episode);
                showToast('Added — plays after current episode');
                AccessibilityInfo.announceForAccessibility('Added to play next');
              }}
              disabled={isCurrent || isQueued}
              accessible accessibilityRole="button"
              accessibilityLabel={
                isCurrent ? 'Episode is currently playing' :
                isQueued   ? 'Already in queue' :
                'Play next — inserts immediately after the current episode'
              }
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
                if (isQueued) {
                  player.removeFromQueue(params.id);
                  showToast('Removed from queue');
                  AccessibilityInfo.announceForAccessibility('Removed from queue');
                } else {
                  player.enqueue(episode);
                  showToast('Added to end of queue');
                  AccessibilityInfo.announceForAccessibility('Added to queue');
                }
              }}
              disabled={isCurrent}
              accessible accessibilityRole="button"
              accessibilityLabel={
                isCurrent ? 'Episode is currently playing' :
                isQueued   ? 'Remove from queue' :
                'Add to queue'
              }
              style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10 }}
            >
              <Ionicons
                name={isQueued ? 'checkmark-circle' : 'add-circle-outline'}
                size={22}
                color={isCurrent ? colors.textSecondary : colors.accent}
                accessibilityElementsHidden
              />
              <Text style={{ fontSize: 15, fontWeight: '600',
                color: isCurrent ? colors.textSecondary : colors.text }}>
                {isQueued ? 'Remove from Queue' : 'Add to Queue'}
              </Text>
            </Pressable>
          </View>

          {/* ── Queue status ──────────────────────────────────────────────── */}
          <Pressable
            onPress={() => router.push('/queue' as any)}
            accessible accessibilityRole="button"
            accessibilityLabel={`View queue. ${player.queue.length} episode${player.queue.length === 1 ? '' : 's'} up next.`}
            style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 }]}
          >
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

          {/* ── Mark as Played ────────────────────────────────────────────── */}
          <Pressable
            onPress={handleMarkAsPlayed}
            accessible accessibilityRole="button"
            accessibilityLabel="Mark as played — clears playback position so the episode starts fresh"
            style={[styles.cardSmall, { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 }]}
          >
            <Ionicons name="checkmark-done-outline" size={22} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text, flex: 1 }}>Mark as Played</Text>
          </Pressable>

          {/* ── Chapters ─────────────────────────────────────────────────── */}
          {isCurrent && chapters.length > 0 && (
            <View
              style={[styles.card, { marginBottom: 20 }]}
              accessible
              accessibilityLabel={`Chapters. ${chapters.length} chapters. ${player.currentChapter ? `Currently in: ${player.currentChapter.title}.` : ''}`}
              accessibilityActions={chapterActions}
              onAccessibilityAction={({ nativeEvent }) => {
                const chapter = chapters.find(c => `chapter_${c.startTime}` === nativeEvent.actionName);
                if (chapter) {
                  player.skipToChapter(chapter);
                  AccessibilityInfo.announceForAccessibility(`Jumping to ${chapter.title}`);
                }
              }}
            >
              <Text style={[styles.cardTitle, { marginBottom: 12 }]} accessibilityRole="header">
                Chapters
              </Text>
              {chapters.map((chapter) => {
                const isActive = player.currentChapter?.title === chapter.title;
                return (
                  <Pressable
                    key={chapter.startTime}
                    onPress={() => player.skipToChapter(chapter)}
                    accessible accessibilityRole="button"
                    accessibilityLabel={`${chapter.title}. Starts at ${formatTime(chapter.startTime)}${isActive ? '. Currently playing.' : ''}`}
                    style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
                      paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border }}
                  >
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 }}>
                      {isActive && (
                        <Ionicons name="volume-medium" size={14} color={colors.accent} accessibilityElementsHidden />
                      )}
                      <Text style={{ flex: 1, fontSize: 15,
                        fontWeight: isActive ? '700' : '400',
                        color: isActive ? colors.accent : colors.text }}>
                        {chapter.title}
                      </Text>
                    </View>
                    <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                      {formatTime(chapter.startTime)}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          )}

          {/* ── Live transcript ───────────────────────────────────────────── */}
          {transcriptUrl && isCurrent && (
            <VttTranscript url={transcriptUrl} currentPosition={player.position} />
          )}

          {/* ── Show notes ───────────────────────────────────────────────── */}
          {!!params.description && <ShowNotes rawHtml={params.description} />}

          {/* ── Quick nav ────────────────────────────────────────────────── */}
          <View style={{ flexDirection: 'row', gap: 10, marginBottom: 20 }}>
            <Pressable
              onPress={() => scrollRef.current?.scrollTo({ y: discussionY.current, animated: true })}
              accessible accessibilityRole="button"
              accessibilityLabel="Jump to Community Discussion"
              accessibilityHint="Scrolls down to the discussion section"
              style={{ flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
                gap: 8, paddingVertical: 11, borderRadius: 12,
                backgroundColor: colors.inputBackground, borderWidth: 1, borderColor: colors.border }}
            >
              <Ionicons name="chatbubbles-outline" size={16} color={colors.accent} accessibilityElementsHidden />
              <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>Jump to Discussion</Text>
            </Pressable>
          </View>

          {/* ── Apple Intelligence ────────────────────────────────────────── */}
          <View style={[styles.card, { marginBottom: 20, opacity: aiAvailable ? 1 : 0.55 }]}>
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
                paddingVertical: 12,
                opacity: pressed ? 0.65 : 1,
              })}
            >
              <View style={{
                width: 44, height: 44, borderRadius: 22,
                backgroundColor: aiAvailable ? `${colors.accent}18` : colors.inputBackground,
                alignItems: 'center', justifyContent: 'center',
              }}>
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

          {/* ── Community Discussion ──────────────────────────────────────── */}
          <View
            onLayout={(e) => { discussionY.current = e.nativeEvent.layout.y; }}
          >
            <SectionDivider label="Community Discussion" />
            <Pressable
              onPress={() => router.push({
                pathname: '/episode/comments/[id]' as any,
                params: {
                  id: params.id,
                  title: params.title,
                  showTitle: params.showTitle,
                  url: params.url ?? '',
                },
              })}
              accessible accessibilityRole="button"
              accessibilityLabel="Community Discussion. View and join the conversation about this episode. Double tap to open."
              style={({ pressed }) => [styles.card, {
                marginBottom: 20, flexDirection: 'row', alignItems: 'center', gap: 14,
                opacity: pressed ? 0.75 : 1,
              }]}
            >
              <View style={{
                width: 48, height: 48, borderRadius: 24,
                backgroundColor: `${colors.accent}18`,
                alignItems: 'center', justifyContent: 'center',
              }} accessibilityElementsHidden>
                <Ionicons name="chatbubbles-outline" size={24} color={colors.accent} accessibilityElementsHidden />
              </View>
              <View style={{ flex: 1 }} accessibilityElementsHidden>
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.text, marginBottom: 2 }}>
                  Community Discussion
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                  View and join the conversation
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
            </Pressable>
          </View>

          {/* ── Related Episodes ──────────────────────────────────────────── */}
          <SectionDivider label="Related Episodes" />
          <ComingSoonShell
            icon="grid-outline"
            message="Episodes from the same series or covering similar topics will appear here."
          />

          {/* ── Back to Top ───────────────────────────────────────────────── */}
          <Pressable
            onPress={() => scrollRef.current?.scrollTo({ y: 0, animated: true })}
            accessible accessibilityRole="button"
            accessibilityLabel="Back to Top"
            accessibilityHint="Scrolls back to the beginning of this page"
            style={{ alignItems: 'center', paddingVertical: 16 }}
          >
            <Text style={{ fontSize: 14, fontWeight: '600', color: colors.accent }}>Back to Top</Text>
          </Pressable>

        </ScrollView>

        {/* ── Fixed bottom toolbar ──────────────────────────────────────── */}
        <View
          style={{
            flexDirection: 'row',
            height: TOOLBAR_H,
            paddingHorizontal: 4,
            backgroundColor: colors.card,
            borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: colors.border,
            alignItems: 'center',
          }}
          accessibilityRole="toolbar"
          accessibilityLabel="Episode actions"
        >
          <ToolbarButton
            icon="list-outline"
            activeIcon="checkmark-circle"
            label={isQueued ? 'Remove\nfrom Queue' : 'Queue this\nEpisode'}
            active={isQueued}
            disabled={isCurrent}
            onPress={handleQueueToggle}
          />
          <ToolbarButton
            icon="bookmark-outline"
            activeIcon="bookmark"
            label={isSaved ? 'Saved' : 'Save this\nEpisode'}
            active={isSaved}
            onPress={handleSaveToggle}
          />
          <ToolbarButton
            icon="share-outline"
            label={'Share this\nEpisode'}
            onPress={handleShare}
          />
          <ToolbarButton
            icon="safari-outline"
            label={'Open in\nSafari'}
            disabled={!episodeUrl}
            onPress={handleOpenInBrowser}
          />
          <ToolbarButton
            icon="pencil-outline"
            label={'Add New\nComment'}
            onPress={handleAddComment}
            accent
          />
        </View>
      </View>
    </Screen>
  );
}
