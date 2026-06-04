import { useCallback, useMemo, useRef, useState } from 'react';
import { AccessibilityInfo, Image, Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Screen } from '../../src/components/Screen';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import { SPEED_OPTIONS, SLEEP_TIMER_OPTIONS } from '../../src/hooks/usePodcastPlayer';
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

// Sleep picker options: 0 = Off, then SLEEP_TIMER_OPTIONS
const SLEEP_MINS = [0, ...SLEEP_TIMER_OPTIONS] as const;

// ─── Helpers ──────────────────────────────────────────────────────────────────
function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
}

// ─── Show Notes ───────────────────────────────────────────────────────────────
type NoteLink = { label: string; url: string; kind: 'app' | 'email' | 'web' };

function parseShowNotes(rawHtml: string): { body: string; links: NoteLink[]; transcript: string | null } {
  if (!rawHtml.trim()) return { body: '', links: [], transcript: null };

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

  // Extract HTML anchor tags before stripping
  const aRegex = /<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let m: RegExpExecArray | null;
  while ((m = aRegex.exec(rawHtml)) !== null) addLink(m[2], m[1]);

  // Strip HTML and decode common entities
  let text = rawHtml
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (_, c) => String.fromCharCode(Number(c)))
    .replace(/&[a-z]{2,8};/g, ' ').replace(/\s+/g, ' ').trim();

  // Find bare markdown links [label](url)
  const mdRegex = /\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g;
  while ((m = mdRegex.exec(text)) !== null) addLink(m[1], m[2]);

  // Find bare email addresses
  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
  while ((m = emailRegex.exec(text)) !== null) {
    if (!seen.has(m[0])) {
      seen.add(m[0]);
      links.push({ label: m[0], url: `mailto:${m[0]}`, kind: 'email' });
    }
  }

  // Extract ### Transcript section
  let transcript: string | null = null;
  const txMatch = text.match(/#{1,3}\s*Transcri?pt[^\n]*[\n\r]+([\s\S]*)/i);
  if (txMatch) {
    transcript = txMatch[1]
      .replace(/#{1,6}\s*/gm, '')
      .replace(/\*\*(.+?)\*\*/g, '$1').replace(/\*(.+?)\*/g, '$1')
      .replace(/^\s*[-*+]\s+/gm, '• ')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/\s+/g, ' ').trim();
    text = text.slice(0, txMatch.index).trim();
  }

  // Clean markdown from body
  const body = text
    .replace(/\*\*(.+?)\*\*/g, '$1').replace(/\*(.+?)\*/g, '$1')
    .replace(/#{1,6}\s*/g, '')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/^\s*[-*+]\s+/gm, '• ')
    .replace(/\n{3,}/g, '\n\n').replace(/\s{2,}/g, ' ').trim();

  return { body, links, transcript };
}

function ShowNotes({ rawHtml }: { rawHtml: string }) {
  const { colors, styles } = useTheme();
  const [showTranscript, setShowTranscript] = useState(false);
  const { body, links, transcript } = useMemo(() => parseShowNotes(rawHtml), [rawHtml]);

  if (!body && !links.length && !transcript) return null;

  return (
    <View style={[styles.card, { marginBottom: 20 }]}>
      <Text style={[styles.cardTitle, { marginBottom: 8 }]} accessibilityRole="header">
        About this episode
      </Text>

      {body.length > 0 && (
        <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary,
          marginBottom: links.length > 0 ? 14 : 0 }}>
          {body}
        </Text>
      )}

      {links.length > 0 && (
        <View style={{ gap: 10, marginTop: body.length > 0 ? 0 : 4 }}>
          {links.map((link, i) => (
            <Pressable
              key={i}
              onPress={() => Linking.openURL(link.url).catch(() => {})}
              accessible
              accessibilityRole="link"
              accessibilityLabel={
                link.kind === 'app'   ? `${link.label}, App Store` :
                link.kind === 'email' ? `Email ${link.label}` :
                link.label
              }
              style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}
            >
              <Ionicons
                name={link.kind === 'app' ? 'logo-apple-appstore' :
                      link.kind === 'email' ? 'mail-outline' : 'link-outline'}
                size={16} color={colors.accent} accessibilityElementsHidden
              />
              <Text style={{ fontSize: 15, color: colors.accent,
                textDecorationLine: 'underline', flex: 1 }}>
                {link.label}
              </Text>
            </Pressable>
          ))}
        </View>
      )}

      {transcript && (
        <>
          <Pressable
            onPress={() => setShowTranscript(v => !v)}
            accessible
            accessibilityRole="button"
            accessibilityLabel={showTranscript ? 'Hide transcript' : 'View transcript'}
            accessibilityHint={showTranscript ? 'Collapses the episode transcript' : 'Expands the full episode transcript'}
            style={{
              flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
              marginTop: 16, paddingTop: 14,
              borderTopWidth: 1, borderTopColor: colors.border,
            }}
          >
            <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }}>Transcript</Text>
            <Ionicons name={showTranscript ? 'chevron-up' : 'chevron-down'}
              size={18} color={colors.textSecondary} accessibilityElementsHidden />
          </Pressable>

          {showTranscript && (
            <Text style={{ fontSize: 14, lineHeight: 21, color: colors.textSecondary, marginTop: 12 }}>
              {transcript}
            </Text>
          )}
        </>
      )}
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────
export default function EpisodeDetail() {
  const params = useLocalSearchParams<{
    id: string; title: string; showTitle: string;
    description?: string; artworkUrl?: string;
    publishedAt?: string; duration?: string; audioUrl: string;
  }>();

  const router  = useRouter();
  const player  = usePlayer();
  const { colors, styles } = useTheme();
  const { podcastTrimSilence, setPodcastTrimSilence } = usePreferences();

  const isCurrent     = player.episode?.id === params.id;
  const durationSecs  = Number(params.duration ?? 0);
  const progress      = isCurrent && player.duration > 0 ? player.position / player.duration : 0;
  const durationKnown = isCurrent && player.duration > 0;

  const publishedLabel = params.publishedAt
    ? new Date(params.publishedAt).toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })
    : null;

  // Sleep timer local picker state (0 = Off, 1..5 = SLEEP_TIMER_OPTIONS)
  const [sleepIdx, setSleepIdx] = useState(() => {
    if (!player.sleepTimerRemaining) return 0;
    const remainMins = Math.ceil(player.sleepTimerRemaining / 60);
    const i = SLEEP_TIMER_OPTIONS.findIndex(m => m >= remainMins);
    return i >= 0 ? i + 1 : SLEEP_TIMER_OPTIONS.length;
  });

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
    if (!isCurrent) {
      const episode: PodcastEpisode = {
        id: params.id, title: params.title, showTitle: params.showTitle,
        description: params.description ?? '', artworkUrl: params.artworkUrl || undefined,
        publishedAt: params.publishedAt ?? '', duration: durationSecs, audioUrl: params.audioUrl,
      };
      player.loadEpisode(episode);
    } else if (player.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }, [isCurrent, player, params, durationSecs]);

  const playLabel = !isCurrent ? 'Play episode'
    : player.isLoading ? 'Loading, please wait'
    : player.isPlaying ? 'Pause' : 'Resume';

  // ── Speed adjustable helpers ─────────────────────────────────────────────
  const speedIdx = SPEED_OPTIONS.indexOf(player.speed);

  // ── Sleep adjustable helpers ─────────────────────────────────────────────
  const sleepDisplayLabel = player.sleepTimerRemaining !== null
    ? `${Math.ceil(player.sleepTimerRemaining / 60)} min remaining`
    : 'Off';

  function applySleepIdx(idx: number) {
    setSleepIdx(idx);
    const mins = SLEEP_MINS[idx];
    if (mins === 0) player.cancelSleepTimer();
    else            player.startSleepTimer(mins);
  }

  return (
    <Screen title="Episode" showSettings={false}>
      {/* onMagicTap on this View intercepts VoiceOver two-finger double tap anywhere on screen */}
      <View onMagicTap={handlePlayPause} style={{ flex: 1 }}>
        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>

          {/* ── Artwork ──────────────────────────────────────────────────── */}
          <View style={{ alignItems: 'center', marginBottom: 20, marginTop: 8 }}
            accessible accessibilityLabel={`Podcast artwork for ${params.showTitle}`}>
            {params.artworkUrl ? (
              <Image
                source={{ uri: params.artworkUrl }}
                style={{ width: 220, height: 220, borderRadius: 16 }}
                resizeMode="cover"
                accessibilityElementsHidden
              />
            ) : (
              <Image
                source={require('../../assets/images/podcasts-card.png')}
                style={{ width: 220, height: 220, borderRadius: 16 }}
                resizeMode="cover"
                accessibilityElementsHidden
              />
            )}
          </View>

          {/* ── Metadata ─────────────────────────────────────────────────── */}
          <Text accessibilityRole="header"
            style={{ fontSize: 20, fontWeight: '800', color: colors.text,
              textAlign: 'center', marginBottom: 6, lineHeight: 26 }}>
            {params.title}
          </Text>
          <Text style={{ fontSize: 15, color: colors.textSecondary, textAlign: 'center', marginBottom: 2 }}>
            {params.showTitle}
          </Text>
          {(publishedLabel || durationSecs > 0) && (
            <Text style={{ fontSize: 13, color: colors.textSecondary, textAlign: 'center', marginBottom: 24 }}>
              {[publishedLabel, durationSecs > 0 ? formatDuration(durationSecs) : null].filter(Boolean).join(' · ')}
            </Text>
          )}

          {/* ── Player card ──────────────────────────────────────────────── */}
          <View style={[styles.card, { marginBottom: 20 }]}>

            {/* Progress bar — 1-minute steps for VoiceOver adjustable */}
            {isCurrent && durationKnown && (
              <>
                <View
                  accessible
                  accessibilityRole="adjustable"
                  accessibilityLabel={`Playback position. ${formatTime(player.position)} of ${formatTime(player.duration)}.`}
                  accessibilityValue={{ min: 0, max: Math.round(player.duration), now: Math.round(player.position) }}
                  accessibilityHint="Swipe up or down to move one minute at a time"
                  onAccessibilityAction={(e) => {
                    const newPos = e.nativeEvent.actionName === 'increment'
                      ? Math.min(player.duration, player.position + 60)
                      : Math.max(0, player.position - 60);
                    player.seekTo(newPos);
                    AccessibilityInfo.announceForAccessibility(formatTime(newPos));
                  }}
                  style={{ marginBottom: 6 }}
                >
                  <View style={{ height: 6, backgroundColor: colors.border, borderRadius: 3 }}>
                    <View style={{ height: 6, backgroundColor: colors.accent, borderRadius: 3,
                      width: `${Math.round(progress * 100)}%` }} />
                  </View>
                </View>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 }}>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>{formatTime(player.position)}</Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>{formatTime(player.duration)}</Text>
                </View>
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
                  accessibilityHint="Hold to cycle through 1, 3, 5, 10, or 15 minutes. Release to jump."
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
                  accessibilityHint="Hold to cycle through 1, 3, 5, 10, or 15 minutes. Release to jump."
                  hitSlop={12}
                >
                  <Ionicons name="play-forward" size={32} color={colors.text} />
                </Pressable>
              )}
            </View>

            {/* Speed — single adjustable element, swipe up = faster */}
            {isCurrent && (
              <View
                accessible
                accessibilityRole="adjustable"
                accessibilityLabel={`Playback speed, ${player.speed}×`}
                accessibilityValue={{ text: `${player.speed}×` }}
                accessibilityHint="Swipe up to increase speed, swipe down to decrease"
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment' && speedIdx < SPEED_OPTIONS.length - 1)
                    player.setSpeed(SPEED_OPTIONS[speedIdx + 1]);
                  if (e.nativeEvent.actionName === 'decrement' && speedIdx > 0)
                    player.setSpeed(SPEED_OPTIONS[speedIdx - 1]);
                }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                  Playback Speed
                </Text>
                <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '700' }}>
                  {player.speed}×
                </Text>
              </View>
            )}

            {/* Sleep timer — single adjustable element, swipe up = longer */}
            {isCurrent && (
              <View
                accessible
                accessibilityRole="adjustable"
                accessibilityLabel={`Sleep timer, ${sleepDisplayLabel}`}
                accessibilityValue={{ text: sleepDisplayLabel }}
                accessibilityHint="Swipe up to increase sleep timer, swipe down to decrease or turn off"
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment')
                    applySleepIdx(Math.min(SLEEP_MINS.length - 1, sleepIdx + 1));
                  if (e.nativeEvent.actionName === 'decrement')
                    applySleepIdx(Math.max(0, sleepIdx - 1));
                }}
                style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
                  paddingVertical: 12, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>
                  Sleep Timer
                </Text>
                <Text style={{ fontSize: 15, color: colors.accent, fontWeight: '700' }}>
                  {sleepDisplayLabel}
                </Text>
              </View>
            )}

            {/* Trim silence — Pressable so VoiceOver double-tap toggles it */}
            <Pressable
              onPress={() => setPodcastTrimSilence(!podcastTrimSilence)}
              accessible
              accessibilityRole="switch"
              accessibilityState={{ checked: podcastTrimSilence }}
              accessibilityLabel={`Trim Silence. Skips silent gaps in episodes. ${podcastTrimSilence ? 'On' : 'Off'}.`}
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
                <View style={{
                  width: 22, height: 22, borderRadius: 11, backgroundColor: '#FFFFFF',
                  alignSelf: podcastTrimSilence ? 'flex-end' : 'flex-start',
                }} />
              </View>
            </Pressable>
          </View>

          {/* ── Queue button ──────────────────────────────────────────────── */}
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

          {/* ── Chapters ─────────────────────────────────────────────────── */}
          {isCurrent && player.episode?.chapters && player.episode.chapters.length > 0 && (
            <View style={[styles.card, { marginBottom: 20 }]}>
              <Text style={[styles.cardTitle, { marginBottom: 12 }]} accessibilityRole="header">Chapters</Text>
              {player.episode.chapters.map((chapter) => {
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
                    <Text style={{ flex: 1, fontSize: 15,
                      fontWeight: isActive ? '700' : '400',
                      color: isActive ? colors.accent : colors.text }}>
                      {chapter.title}
                    </Text>
                    <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                      {formatTime(chapter.startTime)}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          )}

          {/* ── Show notes ───────────────────────────────────────────────── */}
          {!!params.description && (
            <ShowNotes rawHtml={params.description} />
          )}

        </ScrollView>
      </View>
    </Screen>
  );
}
