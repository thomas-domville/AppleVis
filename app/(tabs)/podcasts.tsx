import { useEffect, useRef } from 'react';
import { ActivityIndicator, Pressable, RefreshControl, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { OfflineBanner } from '../../src/components/OfflineBanner';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { usePodcastList } from '../../src/hooks/usePodcastList';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { readAloud, donateSiriActivity } from '../../src/services/intelligenceService';
import { trackMeaningfulAction } from '../../src/services/reviewPrompt';
import { startPodcastLiveActivity, updatePodcastLiveActivity, endPodcastLiveActivity } from '../../src/native/nativeModules';
import { SPEED_OPTIONS, SLEEP_TIMER_OPTIONS } from '../../src/hooks/usePodcastPlayer';
import { colors, styles } from '../../src/theme/styles';
import type { PodcastEpisode } from '../../src/types/content';

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

export default function Podcasts() {
  const player         = usePlayer();
  const list           = usePodcastList();
  const { showToast }  = useToast();
  const firstEpisodeRef = useRef<View | null>(null);
  useRefreshFeedback(list.refreshing, 'Podcasts', list.loading,
    () => firstEpisodeRef.current);

  useHandoff(
    player.episode
      ? {
          activityType: 'com.applevis.app.playEpisode',
          title: player.episode.title,
          webpageURL: 'https://www.applevis.com/podcast',
          userInfo: { episodeId: player.episode.id },
        }
      : {
          activityType: 'com.applevis.app.viewPodcasts',
          title: 'AppleVis Podcasts',
          webpageURL: 'https://www.applevis.com/podcast',
        },
  );

  // Track episode completion for the App Store review prompt.
  const lastEpisodeId = useRef<string | null>(null);
  useEffect(() => {
    if (!player.episode || player.duration <= 0) return;
    const nearEnd = player.position >= player.duration - 10;
    if (nearEnd && lastEpisodeId.current !== player.episode.id) {
      lastEpisodeId.current = player.episode.id;
      trackMeaningfulAction().catch(() => {});
    }
  }, [player.position, player.duration, player.episode]);

  const isCurrentEpisode = (id: string) => player.episode?.id === id;
  const progress = player.duration > 0 ? player.position / player.duration : 0;
  const durationKnown = player.duration > 0;

  function handleEpisodeAction(episode: PodcastEpisode, actionName: string) {
    if (actionName === 'play') {
      player.loadEpisode(episode, true);
      donateSiriActivity({ type: 'continuePlaying' });
      startPodcastLiveActivity({
        episodeTitle: episode.title,
        showTitle: episode.showTitle,
        isPlaying: true,
        position: 0,
        duration: episode.duration,
      });
    } else if (actionName === 'read_aloud') {
      readAloud([episode.title, episode.showTitle, episode.description].filter(Boolean).join('. '));
    } else if (actionName === 'play_next') {
      player.playNext(episode);
      showToast(`Playing next: ${episode.title}`, 'success');
    } else if (actionName === 'add_to_queue') {
      player.enqueue(episode);
      showToast('Added to queue.', 'success');
    } else if (actionName === 'save') {
      showToast('Save coming soon.', 'warning');
    } else if (actionName === 'download') {
      showToast('Download coming soon.', 'warning');
    }
  }

  return (
    <Screen title="Podcasts" refreshing={list.refreshing}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={list.refreshing}
            onRefresh={list.refresh}
            tintColor={colors.appleVisBlue}
            accessibilityLabel="Pull to refresh podcast episodes"
          />
        }
      >

        {/* — Full Player (visible when an episode is loaded) — */}
        {player.episode && (
          <View style={[styles.card, { marginBottom: 20 }]}>
            <Text style={[styles.cardTitle, { marginBottom: 2 }]} accessibilityRole="header">
              {player.episode.title}
            </Text>
            <Text style={[styles.cardMeta, { marginBottom: 12 }]}>{player.episode.showTitle}</Text>

            {player.currentChapter && (
              <Text style={{ color: colors.appleVisBlue, fontSize: 14, marginBottom: 10 }}>
                Chapter: {player.currentChapter.title}
              </Text>
            )}

            {/* Progress scrubber — only shown once duration is known */}
            {durationKnown ? (
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
                  <View style={{ height: 6, backgroundColor: '#E5E7EB', borderRadius: 3 }}>
                    <View style={{
                      height: 6, backgroundColor: colors.appleVisBlue, borderRadius: 3,
                      width: `${Math.round(progress * 100)}%`,
                    }} />
                  </View>
                </View>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 16 }}>
                  <Text style={{ fontSize: 13, color: colors.secondary }}>{formatTime(player.position)}</Text>
                  <Text style={{ fontSize: 13, color: colors.secondary }}>{formatTime(player.duration)}</Text>
                </View>
              </>
            ) : (
              <View style={{ height: 4, backgroundColor: '#E5E7EB', borderRadius: 3, marginBottom: 16 }}>
                <View style={{
                  height: 4, backgroundColor: colors.appleVisBlue, borderRadius: 3,
                  width: player.isLoading ? '30%' : `${Math.round(progress * 100)}%`,
                }} />
              </View>
            )}

            {/* Transport controls */}
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 28, marginBottom: 20 }}>
              <Pressable onPress={player.skipBack} accessible accessibilityRole="button"
                accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds`} hitSlop={10}>
                <Ionicons name="play-back" size={30} color={colors.text} />
              </Pressable>
              <Pressable
                onPress={player.isPlaying ? player.pause : player.play}
                accessible accessibilityRole="button"
                accessibilityLabel={player.isPlaying ? 'Pause' : 'Play'}
                style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: colors.appleVisBlue, alignItems: 'center', justifyContent: 'center' }}
              >
                <Ionicons
                  name={player.isLoading ? 'hourglass-outline' : player.isPlaying ? 'pause' : 'play'}
                  size={30} color="#FFFFFF"
                />
              </Pressable>
              <Pressable onPress={player.skipForward} accessible accessibilityRole="button"
                accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`} hitSlop={10}>
                <Ionicons name="play-forward" size={30} color={colors.text} />
              </Pressable>
            </View>

            {/* Speed */}
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 8 }}>Speed</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 16 }}>
              <View style={{ flexDirection: 'row', gap: 8 }}>
                {SPEED_OPTIONS.map((s) => (
                  <Pressable key={s} onPress={() => player.setSpeed(s)} accessible accessibilityRole="button"
                    accessibilityLabel={`${s}x speed${player.speed === s ? ', selected' : ''}`}
                    style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999,
                      backgroundColor: player.speed === s ? colors.appleVisBlue : '#E8F1FF' }}>
                    <Text style={{ color: player.speed === s ? '#FFF' : colors.appleVisBlue, fontWeight: '700', fontSize: 14 }}>
                      {s}×
                    </Text>
                  </Pressable>
                ))}
              </View>
            </ScrollView>

            {/* Sleep timer */}
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 8 }}>
              Sleep Timer{player.sleepTimerRemaining != null ? ` — ${formatTime(player.sleepTimerRemaining)} remaining` : ''}
            </Text>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
              {SLEEP_TIMER_OPTIONS.map((mins) => (
                <Pressable key={mins} onPress={() => player.startSleepTimer(mins)} accessible accessibilityRole="button"
                  accessibilityLabel={`Sleep timer ${mins} minutes`}
                  style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: '#E8F1FF' }}>
                  <Text style={{ color: colors.appleVisBlue, fontWeight: '700', fontSize: 14 }}>{mins}m</Text>
                </Pressable>
              ))}
              {player.sleepTimerRemaining != null && (
                <Pressable onPress={player.cancelSleepTimer} accessible accessibilityRole="button"
                  accessibilityLabel="Cancel sleep timer"
                  style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: '#FFEAEA' }}>
                  <Text style={{ color: '#FF3B30', fontWeight: '700', fontSize: 14 }}>Cancel</Text>
                </Pressable>
              )}
            </View>

            {/* Chapters */}
            {player.episode.chapters && player.episode.chapters.length > 0 && (
              <>
                <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 8 }}>Chapters</Text>
                {player.episode.chapters.map((ch) => (
                  <Pressable key={ch.title} onPress={() => player.skipToChapter(ch)} accessible accessibilityRole="button"
                    accessibilityLabel={`Jump to chapter: ${ch.title}, starts at ${formatTime(ch.startTime)}`}
                    style={{ paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border,
                      flexDirection: 'row', justifyContent: 'space-between' }}>
                    <Text style={{ fontSize: 15,
                      color: player.currentChapter?.title === ch.title ? colors.appleVisBlue : colors.text,
                      fontWeight: player.currentChapter?.title === ch.title ? '700' : '400' }}>
                      {ch.title}
                    </Text>
                    <Text style={{ fontSize: 13, color: colors.secondary }}>{formatTime(ch.startTime)}</Text>
                  </Pressable>
                ))}
              </>
            )}
          </View>
        )}

        {/* — Episode List — */}
        <OfflineBanner fromCache={list.fromCache} cachedAt={list.cachedAt} />
        <Text style={[styles.cardTitle, { marginBottom: 12 }]}>Episodes</Text>

        {list.loading && (
          <View style={{ alignItems: 'center', paddingVertical: 32 }}>
            <ActivityIndicator size="large" color={colors.appleVisBlue} />
            <Text style={[styles.lede, { marginTop: 12, textAlign: 'center' }]}>Loading episodes…</Text>
          </View>
        )}

        {!list.loading && list.error && (
          <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
            <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load episodes</Text>
            <Text style={styles.cardMeta}>{list.error}</Text>
            <Pressable onPress={list.refresh} accessible accessibilityRole="button"
              accessibilityLabel="Retry loading episodes" style={{ marginTop: 12 }}>
              <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
            </Pressable>
          </View>
        )}

        {!list.loading && !list.error && list.episodes.length === 0 && (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Text style={styles.cardTitle}>No episodes yet</Text>
          </View>
        )}

        {!list.loading && list.episodes.map((episode, index) => {
          const isCurrent = isCurrentEpisode(episode.id);
          const durationLabel = formatDuration(episode.duration);
          return (
            <View
              key={episode.id}
              accessible
              accessibilityRole="none"
              accessibilityLabel={[
                episode.title,
                episode.showTitle,
                durationLabel,
                isCurrent ? 'Currently loaded.' : null,
              ].filter(Boolean).join('. ')}
              accessibilityActions={[
                { name: 'play',         label: 'Play' },
                { name: 'read_aloud',   label: 'Read description aloud' },
                { name: 'play_next',    label: 'Play next' },
                { name: 'add_to_queue', label: 'Add to queue' },
                { name: 'save',         label: 'Save episode' },
                { name: 'download',     label: 'Download' },
              ]}
              onAccessibilityAction={(e) => handleEpisodeAction(episode, e.nativeEvent.actionName)}
              ref={(el) => { if (index === 0) firstEpisodeRef.current = el; }}
              style={[styles.card, isCurrent && { borderColor: colors.appleVisBlue, borderWidth: 2 }]}
            >
              <Text style={styles.cardTitle}>{episode.title}</Text>
              <Text style={[styles.cardMeta, { marginBottom: 10 }]}>
                {episode.showTitle}{durationLabel ? ` · ${durationLabel}` : ''}
              </Text>
              <View style={{ flexDirection: 'row', gap: 10 }}>
                <Pressable
                  onPress={() => handleEpisodeAction(episode, 'play')}
                  accessible accessibilityRole="button"
                  accessibilityLabel={isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: colors.appleVisBlue, borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8 }}
                >
                  <Ionicons name={isCurrent && player.isPlaying ? 'pause' : 'play'} size={16} color="#FFF" />
                  <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 14 }}>
                    {isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                  </Text>
                </Pressable>
                <Pressable
                  onPress={() => handleEpisodeAction(episode, 'add_to_queue')}
                  accessible accessibilityRole="button" accessibilityLabel="Add to queue"
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                    backgroundColor: '#E8F1FF', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8 }}
                >
                  <Ionicons name="list" size={16} color={colors.appleVisBlue} />
                  <Text style={{ color: colors.appleVisBlue, fontWeight: '700', fontSize: 14 }}>Queue</Text>
                </Pressable>
              </View>
            </View>
          );
        })}

        <LoadMoreButton
          hasMore={list.hasMore}
          isLoadingMore={list.isLoadingMore}
          onPress={list.loadMore}
        />

        <View style={{ height: 160 }} />
      </ScrollView>
    </Screen>
  );
}
