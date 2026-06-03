import { useRef } from 'react';
import { AccessibilityInfo, Image, Pressable, ScrollView, Switch, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
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

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

export default function EpisodeDetail() {
  const params = useLocalSearchParams<{
    id: string;
    title: string;
    showTitle: string;
    description?: string;
    artworkUrl?: string;
    publishedAt?: string;
    duration?: string;
    audioUrl: string;
  }>();

  const router  = useRouter();
  const player  = usePlayer();
  const { colors, styles } = useTheme();
  const { podcastTrimSilence, setPodcastTrimSilence } = usePreferences();

  const isCurrent    = player.episode?.id === params.id;
  const durationSecs = Number(params.duration ?? 0);
  const progress     = isCurrent && player.duration > 0 ? player.position / player.duration : 0;
  const durationKnown = isCurrent && player.duration > 0;

  const publishedLabel = params.publishedAt
    ? new Date(params.publishedAt).toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })
    : null;

  const description = params.description ? stripHtml(params.description) : '';

  // ── Long-press skip refs ───────────────────────────────────────────────────
  const holdTimerRef    = useRef<ReturnType<typeof setTimeout> | null>(null);
  const holdIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const holdStepRef     = useRef(-1); // -1 = not in hold mode
  const inLongPressRef  = useRef(false);

  function clearHoldTimers() {
    if (holdTimerRef.current)    { clearTimeout(holdTimerRef.current);    holdTimerRef.current    = null; }
    if (holdIntervalRef.current) { clearInterval(holdIntervalRef.current); holdIntervalRef.current = null; }
  }

  function handleSkipLongPress(direction: 'forward' | 'back') {
    inLongPressRef.current = true;
    holdStepRef.current    = 0;
    AccessibilityInfo.announceForAccessibility(HOLD_SKIP_STEPS[0].label);

    holdIntervalRef.current = setInterval(() => {
      const next = holdStepRef.current + 1;
      if (next >= HOLD_SKIP_STEPS.length) {
        clearInterval(holdIntervalRef.current!);
        holdIntervalRef.current = null;
        return;
      }
      holdStepRef.current = next;
      AccessibilityInfo.announceForAccessibility(HOLD_SKIP_STEPS[next].label);
    }, HOLD_STEP_INTERVAL_MS);
  }

  function handleSkipPressOut(direction: 'forward' | 'back') {
    if (!inLongPressRef.current) return; // quick tap handled by onPress
    clearHoldTimers();
    inLongPressRef.current = false;

    if (holdStepRef.current >= 0) {
      const { seconds } = HOLD_SKIP_STEPS[holdStepRef.current];
      holdStepRef.current = -1;
      if (direction === 'forward') {
        player.seekTo(Math.min(player.duration, player.position + seconds));
      } else {
        player.seekTo(Math.max(0, player.position - seconds));
      }
    }
  }

  // ── Play / load ───────────────────────────────────────────────────────────
  function handlePlayPause() {
    if (!isCurrent) {
      const episode: PodcastEpisode = {
        id:          params.id,
        title:       params.title,
        showTitle:   params.showTitle,
        description: params.description ?? '',
        artworkUrl:  params.artworkUrl || undefined,
        publishedAt: params.publishedAt ?? '',
        duration:    durationSecs,
        audioUrl:    params.audioUrl,
      };
      player.loadEpisode(episode);
    } else if (player.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }

  const playLabel = !isCurrent
    ? 'Play episode'
    : player.isLoading
    ? 'Loading, please wait'
    : player.isPlaying
    ? 'Pause'
    : 'Resume';

  return (
    <Screen title="Episode" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>

        {/* ── Artwork ─────────────────────────────────────────────────────── */}
        <View style={{ alignItems: 'center', marginBottom: 20, marginTop: 8 }}>
          {params.artworkUrl ? (
            <View accessible accessibilityLabel={`Podcast artwork for ${params.showTitle}`}>
              <Image
                source={{ uri: params.artworkUrl }}
                style={{ width: 220, height: 220, borderRadius: 16 }}
                resizeMode="cover"
                accessibilityElementsHidden
              />
            </View>
          ) : (
            <View
              style={{
                width: 220, height: 220, borderRadius: 16,
                backgroundColor: colors.card, borderWidth: 1, borderColor: colors.border,
                alignItems: 'center', justifyContent: 'center',
              }}
              accessible
              accessibilityLabel={`No artwork available for ${params.showTitle}`}
            >
              <Ionicons name="radio-outline" size={64} color={colors.textSecondary} accessibilityElementsHidden />
            </View>
          )}
        </View>

        {/* ── Metadata ────────────────────────────────────────────────────── */}
        <Text
          accessibilityRole="header"
          style={{ fontSize: 20, fontWeight: '800', color: colors.text, textAlign: 'center', marginBottom: 6, lineHeight: 26 }}
        >
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

        {/* ── Player card ─────────────────────────────────────────────────── */}
        <View style={[styles.card, { marginBottom: 20 }]}>

          {/* Progress bar */}
          {isCurrent && durationKnown && (
            <>
              <View
                accessible
                accessibilityRole="adjustable"
                accessibilityLabel={`Playback position. ${formatTime(player.position)} of ${formatTime(player.duration)}.`}
                accessibilityValue={{ min: 0, max: Math.round(player.duration), now: Math.round(player.position) }}
                onAccessibilityAction={(e) => {
                  if (e.nativeEvent.actionName === 'increment') player.seekTo(player.position + 10);
                  if (e.nativeEvent.actionName === 'decrement') player.seekTo(player.position - 10);
                }}
                style={{ marginBottom: 6 }}
              >
                <View style={{ height: 6, backgroundColor: colors.border, borderRadius: 3 }}>
                  <View style={{
                    height: 6, backgroundColor: colors.accent, borderRadius: 3,
                    width: `${Math.round(progress * 100)}%`,
                  }} />
                </View>
              </View>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 20 }}>
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>{formatTime(player.position)}</Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>{formatTime(player.duration)}</Text>
              </View>
            </>
          )}

          {/* Transport row */}
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 36, marginBottom: 20 }}>

            {/* Skip back — long press cycles through hold amounts */}
            {isCurrent && (
              <Pressable
                onPress={() => player.skipBack()}
                onLongPress={() => handleSkipLongPress('back')}
                onPressOut={() => handleSkipPressOut('back')}
                delayLongPress={HOLD_INITIAL_DELAY_MS}
                accessible accessibilityRole="button"
                accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds. Hold to skip further.`}
                accessibilityHint="Hold to cycle through 1, 3, 5, 10, or 15 minutes. Release to jump."
                hitSlop={12}
              >
                <Ionicons name="play-back" size={32} color={colors.text} />
              </Pressable>
            )}

            {/* Play / pause */}
            <Pressable
              onPress={handlePlayPause}
              accessible accessibilityRole="button"
              accessibilityLabel={playLabel}
              style={{
                width: 72, height: 72, borderRadius: 36,
                backgroundColor: colors.accent,
                alignItems: 'center', justifyContent: 'center',
              }}
            >
              <Ionicons
                name={isCurrent && player.isLoading ? 'hourglass-outline' : isCurrent && player.isPlaying ? 'pause' : 'play'}
                size={32} color="#FFFFFF"
              />
            </Pressable>

            {/* Skip forward — long press cycles through hold amounts */}
            {isCurrent && (
              <Pressable
                onPress={() => player.skipForward()}
                onLongPress={() => handleSkipLongPress('forward')}
                onPressOut={() => handleSkipPressOut('forward')}
                delayLongPress={HOLD_INITIAL_DELAY_MS}
                accessible accessibilityRole="button"
                accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds. Hold to skip further.`}
                accessibilityHint="Hold to cycle through 1, 3, 5, 10, or 15 minutes. Release to jump."
                hitSlop={12}
              >
                <Ionicons name="play-forward" size={32} color={colors.text} />
              </Pressable>
            )}
          </View>

          {/* Speed picker */}
          {isCurrent && (
            <>
              <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, marginBottom: 8, textAlign: 'center' }}>
                Playback Speed
              </Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center', marginBottom: 16 }}>
                {SPEED_OPTIONS.map((s) => (
                  <Pressable
                    key={s}
                    onPress={() => player.setSpeed(s)}
                    accessible accessibilityRole="none"
                    accessibilityState={{ selected: player.speed === s }}
                    accessibilityLabel={`${s}×${player.speed === s ? ', selected' : ''}`}
                    style={{
                      paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999,
                      backgroundColor: player.speed === s ? colors.accent : colors.pill,
                    }}
                  >
                    <Text style={{ fontSize: 13, fontWeight: '600', color: player.speed === s ? colors.accentText : colors.pillText }}>
                      {s}×
                    </Text>
                  </Pressable>
                ))}
              </View>
            </>
          )}

          {/* Sleep timer */}
          {isCurrent && (
            <>
              <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary, marginBottom: 8, textAlign: 'center' }}>
                {player.sleepTimerRemaining !== null
                  ? `Sleep Timer — ${Math.ceil(player.sleepTimerRemaining / 60)} min left`
                  : 'Sleep Timer'}
              </Text>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center', marginBottom: 8 }}>
                {player.sleepTimerRemaining !== null && (
                  <Pressable
                    onPress={player.cancelSleepTimer}
                    accessible accessibilityRole="button" accessibilityLabel="Cancel sleep timer"
                    style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999, backgroundColor: colors.accent }}
                  >
                    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.accentText }}>Cancel</Text>
                  </Pressable>
                )}
                {SLEEP_TIMER_OPTIONS.map((mins) => (
                  <Pressable
                    key={mins}
                    onPress={() => player.startSleepTimer(mins)}
                    accessible accessibilityRole="button"
                    accessibilityLabel={`Set sleep timer to ${mins} minutes`}
                    style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999, backgroundColor: colors.pill }}
                  >
                    <Text style={{ fontSize: 13, fontWeight: '600', color: colors.pillText }}>{mins} min</Text>
                  </Pressable>
                ))}
              </View>
            </>
          )}

          {/* Trim silence toggle */}
          <View
            style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 8, paddingTop: 12, borderTopWidth: 1, borderTopColor: colors.border }}
            accessible
            accessibilityLabel={`Trim Silence. Skips silent gaps in episodes. ${podcastTrimSilence ? 'On' : 'Off'}.`}
            accessibilityRole="switch"
            accessibilityState={{ checked: podcastTrimSilence }}
          >
            <View style={{ flex: 1 }}>
              <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }}>Trim Silence</Text>
              <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 2 }}>Skips silent gaps in episodes</Text>
            </View>
            <Switch
              value={podcastTrimSilence}
              onValueChange={setPodcastTrimSilence}
              trackColor={{ false: colors.border, true: colors.accent }}
              thumbColor="#FFFFFF"
              accessibilityElementsHidden
            />
          </View>
        </View>

        {/* ── Queue button ────────────────────────────────────────────────── */}
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
              {player.queue.length === 0
                ? 'Nothing queued up next'
                : `${player.queue.length} episode${player.queue.length === 1 ? '' : 's'} up next`}
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} accessibilityElementsHidden />
        </Pressable>

        {/* ── Chapters ────────────────────────────────────────────────────── */}
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
                  style={{
                    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
                    paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border,
                  }}
                >
                  <Text style={{ flex: 1, fontSize: 15, fontWeight: isActive ? '700' : '400', color: isActive ? colors.accent : colors.text }}>
                    {chapter.title}
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>{formatTime(chapter.startTime)}</Text>
                </Pressable>
              );
            })}
          </View>
        )}

        {/* ── Description ─────────────────────────────────────────────────── */}
        {description.length > 0 && (
          <View style={[styles.card, { marginBottom: 20 }]}>
            <Text style={[styles.cardTitle, { marginBottom: 8 }]} accessibilityRole="header">
              About this episode
            </Text>
            <Text style={{ fontSize: 15, lineHeight: 22, color: colors.textSecondary }}>
              {description}
            </Text>
          </View>
        )}

      </ScrollView>
    </Screen>
  );
}
