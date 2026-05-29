import { Pressable, ScrollView, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../../src/components/Screen';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { SPEED_OPTIONS, SLEEP_TIMER_OPTIONS } from '../../src/hooks/usePodcastPlayer';
import { colors, styles } from '../../src/theme/styles';
import type { PodcastEpisode } from '../../src/types/content';

// Sample data until the real API is wired in
const SAMPLE_EPISODES: PodcastEpisode[] = [
  {
    id: 'ep-001',
    title: 'AppleVis Podcast: What\'s new in accessibility in iOS 26',
    showTitle: 'AppleVis Podcast',
    audioUrl: 'https://www.applevis.com/podcast/episodes/ep001.mp3',
    duration: 42 * 60,
    publishedAt: '2026-05-20',
    description: 'The team discusses the biggest accessibility improvements in iOS 26.',
    chapters: [
      { title: 'Introduction', startTime: 0 },
      { title: 'VoiceOver improvements', startTime: 120 },
      { title: 'Display Accommodations', startTime: 600 },
      { title: 'New Braille support', startTime: 1200 },
      { title: 'Community highlights', startTime: 2100 },
    ],
  },
  {
    id: 'ep-002',
    title: 'AppleVis Extra: App demos and community tips',
    showTitle: 'AppleVis Extra',
    audioUrl: 'https://www.applevis.com/podcast/episodes/ep002.mp3',
    duration: 28 * 60,
    publishedAt: '2026-05-15',
    description: 'Live app demos and VoiceOver tips from the AppleVis community.',
  },
];

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
}

export default function Podcasts() {
  const player = usePlayer();

  const isCurrentEpisode = (id: string) => player.episode?.id === id;
  const progress = player.duration > 0 ? player.position / player.duration : 0;

  return (
    <Screen title="Podcasts">
      <ScrollView showsVerticalScrollIndicator={false}>

        {/* — Full Player (visible when an episode is loaded) — */}
        {player.episode && (
          <View style={[styles.card, { marginBottom: 20 }]}>
            {/* Title + show */}
            <Text
              style={[styles.cardTitle, { marginBottom: 2 }]}
              accessibilityRole="header"
            >
              {player.episode.title}
            </Text>
            <Text style={[styles.cardMeta, { marginBottom: 12 }]}>
              {player.episode.showTitle}
            </Text>

            {/* Chapter */}
            {player.currentChapter && (
              <Text style={{ color: colors.appleVisBlue, fontSize: 14, marginBottom: 10 }}>
                Chapter: {player.currentChapter.title}
              </Text>
            )}

            {/* Progress scrubber */}
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
                <View
                  style={{
                    height: 6,
                    backgroundColor: colors.appleVisBlue,
                    borderRadius: 3,
                    width: `${Math.round(progress * 100)}%`,
                  }}
                />
              </View>
            </View>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 16 }}>
              <Text style={{ fontSize: 13, color: colors.secondary }}>{formatTime(player.position)}</Text>
              <Text style={{ fontSize: 13, color: colors.secondary }}>{formatTime(player.duration)}</Text>
            </View>

            {/* Transport controls */}
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 28, marginBottom: 20 }}>
              <Pressable
                onPress={player.skipBack}
                accessible
                accessibilityRole="button"
                accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds`}
                hitSlop={10}
              >
                <Ionicons name="play-back" size={30} color={colors.text} />
              </Pressable>

              <Pressable
                onPress={player.isPlaying ? player.pause : player.play}
                accessible
                accessibilityRole="button"
                accessibilityLabel={player.isPlaying ? 'Pause' : 'Play'}
                style={{
                  width: 64,
                  height: 64,
                  borderRadius: 32,
                  backgroundColor: colors.appleVisBlue,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Ionicons
                  name={player.isLoading ? 'hourglass-outline' : player.isPlaying ? 'pause' : 'play'}
                  size={30}
                  color="#FFFFFF"
                />
              </Pressable>

              <Pressable
                onPress={player.skipForward}
                accessible
                accessibilityRole="button"
                accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`}
                hitSlop={10}
              >
                <Ionicons name="play-forward" size={30} color={colors.text} />
              </Pressable>
            </View>

            {/* Speed control */}
            <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 8 }}>
              Speed
            </Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 16 }}>
              <View style={{ flexDirection: 'row', gap: 8 }}>
                {SPEED_OPTIONS.map((s) => (
                  <Pressable
                    key={s}
                    onPress={() => player.setSpeed(s)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={`${s}x speed${player.speed === s ? ', selected' : ''}`}
                    style={{
                      paddingHorizontal: 14,
                      paddingVertical: 8,
                      borderRadius: 999,
                      backgroundColor: player.speed === s ? colors.appleVisBlue : '#E8F1FF',
                    }}
                  >
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
                <Pressable
                  key={mins}
                  onPress={() => player.startSleepTimer(mins)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={`Sleep timer ${mins} minutes`}
                  style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: '#E8F1FF' }}
                >
                  <Text style={{ color: colors.appleVisBlue, fontWeight: '700', fontSize: 14 }}>{mins}m</Text>
                </Pressable>
              ))}
              {player.sleepTimerRemaining != null && (
                <Pressable
                  onPress={player.cancelSleepTimer}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel="Cancel sleep timer"
                  style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: '#FFEAEA' }}
                >
                  <Text style={{ color: '#FF3B30', fontWeight: '700', fontSize: 14 }}>Cancel</Text>
                </Pressable>
              )}
            </View>

            {/* Chapters list */}
            {player.episode.chapters && player.episode.chapters.length > 0 && (
              <>
                <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text, marginBottom: 8 }}>Chapters</Text>
                {player.episode.chapters.map((ch) => (
                  <Pressable
                    key={ch.title}
                    onPress={() => player.skipToChapter(ch)}
                    accessible
                    accessibilityRole="button"
                    accessibilityLabel={`Jump to chapter: ${ch.title}, starts at ${formatTime(ch.startTime)}`}
                    style={{
                      paddingVertical: 10,
                      borderBottomWidth: 1,
                      borderBottomColor: colors.border,
                      flexDirection: 'row',
                      justifyContent: 'space-between',
                    }}
                  >
                    <Text
                      style={{
                        fontSize: 15,
                        color: player.currentChapter?.title === ch.title ? colors.appleVisBlue : colors.text,
                        fontWeight: player.currentChapter?.title === ch.title ? '700' : '400',
                      }}
                    >
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
        <Text style={[styles.cardTitle, { marginBottom: 12 }]}>Episodes</Text>
        {SAMPLE_EPISODES.map((episode) => {
          const isCurrent = isCurrentEpisode(episode.id);
          return (
            <View
              key={episode.id}
              accessible
              accessibilityRole="none"
              accessibilityLabel={`${episode.title}. ${episode.showTitle}. ${formatDuration(episode.duration)}.${isCurrent ? ' Currently loaded.' : ''}`}
              accessibilityActions={[
                { name: 'play', label: 'Play' },
                { name: 'play_next', label: 'Play next' },
                { name: 'add_to_queue', label: 'Add to queue' },
                { name: 'save', label: 'Save episode' },
                { name: 'download', label: 'Download' },
              ]}
              onAccessibilityAction={(e) => {
                const name = e.nativeEvent.actionName;
                if (name === 'play') player.loadEpisode(episode, true);
                else if (name === 'play_next') player.playNext(episode);
                else if (name === 'add_to_queue') player.enqueue(episode);
              }}
              style={[
                styles.card,
                isCurrent && { borderColor: colors.appleVisBlue, borderWidth: 2 },
              ]}
            >
              <Text style={styles.cardTitle}>{episode.title}</Text>
              <Text style={[styles.cardMeta, { marginBottom: 10 }]}>
                {episode.showTitle} · {formatDuration(episode.duration)}
              </Text>
              <View style={{ flexDirection: 'row', gap: 10 }}>
                <Pressable
                  onPress={() => player.loadEpisode(episode, true)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                  style={{
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 6,
                    backgroundColor: colors.appleVisBlue,
                    borderRadius: 8,
                    paddingHorizontal: 14,
                    paddingVertical: 8,
                  }}
                >
                  <Ionicons name={isCurrent && player.isPlaying ? 'pause' : 'play'} size={16} color="#FFF" />
                  <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 14 }}>
                    {isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                  </Text>
                </Pressable>
                <Pressable
                  onPress={() => player.enqueue(episode)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel="Add to queue"
                  style={{
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 6,
                    backgroundColor: '#E8F1FF',
                    borderRadius: 8,
                    paddingHorizontal: 14,
                    paddingVertical: 8,
                  }}
                >
                  <Ionicons name="list" size={16} color={colors.appleVisBlue} />
                  <Text style={{ color: colors.appleVisBlue, fontWeight: '700', fontSize: 14 }}>Queue</Text>
                </Pressable>
              </View>
            </View>
          );
        })}

        <View style={{ height: 160 }} />
      </ScrollView>
    </Screen>
  );
}
