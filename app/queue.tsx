import { Pressable, ScrollView, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '../src/components/Screen';
import { usePlayer } from '../src/contexts/PlayerContext';
import { useTheme } from '../src/contexts/ThemeContext';

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
}

export default function QueueScreen() {
  const router = useRouter();
  const { colors, styles } = useTheme();
  const player = usePlayer();

  const queue = player.queue;

  function navigateToEpisode(id: string) {
    const episode = queue.find((e) => e.id === id);
    if (!episode) return;
    router.push({
      pathname: '/episode/[id]' as any,
      params: {
        id: episode.id,
        title: episode.title,
        showTitle: episode.showTitle,
        description: episode.description ?? '',
        artworkUrl: episode.artworkUrl ?? '',
        publishedAt: episode.publishedAt ?? '',
        duration: String(episode.duration),
        audioUrl: episode.audioUrl,
      },
    });
  }

  return (
    <Screen title="Queue" showSettings={false}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>

        {/* Now playing */}
        {player.episode && (
          <>
            <Text
              style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}
              accessibilityRole="header"
            >
              Now Playing
            </Text>
            <Pressable
              onPress={() => navigateToEpisode(player.episode!.id)}
              accessible
              accessibilityRole="button"
              accessibilityLabel={`Now playing: ${player.episode.title}. ${player.episode.showTitle}. Double tap to open.`}
              style={[styles.cardSmall, { borderWidth: 2, borderColor: colors.accent, marginBottom: 20 }]}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                <Ionicons
                  name={player.isPlaying ? 'musical-notes' : 'pause'}
                  size={20} color={colors.accent}
                  accessibilityElementsHidden
                />
                <View style={{ flex: 1 }}>
                  <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }} numberOfLines={2}>
                    {player.episode.title}
                  </Text>
                  <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                    {player.episode.showTitle}
                    {player.duration > 0 ? ` · ${formatDuration(player.duration - player.position)} left` : ''}
                  </Text>
                </View>
              </View>
            </Pressable>
          </>
        )}

        {/* Up next */}
        {queue.length === 0 ? (
          <View style={[styles.card, { alignItems: 'center', paddingVertical: 32 }]}>
            <Ionicons name="list-outline" size={40} color={colors.textSecondary} accessibilityElementsHidden />
            <Text style={[styles.cardTitle, { marginTop: 12, textAlign: 'center' }]}>Queue is empty</Text>
            <Text style={[styles.cardMeta, { textAlign: 'center', marginTop: 4 }]}>
              Add episodes using the Queue action on any episode card.
            </Text>
          </View>
        ) : (
          <>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
              <Text
                style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
                  textTransform: 'uppercase', letterSpacing: 0.8 }}
                accessibilityRole="header"
              >
                Up Next ({queue.length})
              </Text>
              <Pressable
                onPress={player.clearQueue}
                accessible accessibilityRole="button"
                accessibilityLabel="Clear entire queue"
                style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, backgroundColor: colors.pill }}
              >
                <Text style={{ fontSize: 13, fontWeight: '600', color: colors.pillText }}>Clear All</Text>
              </Pressable>
            </View>

            {queue.map((episode, index) => {
              const isFirst = index === 0;
              const isLast  = index === queue.length - 1;
              const durationLabel = formatDuration(episode.duration);
              return (
                <Pressable
                  key={episode.id}
                  onPress={() => navigateToEpisode(episode.id)}
                  accessible
                  accessibilityRole="button"
                  accessibilityLabel={[
                    `${index + 1} of ${queue.length}`,
                    episode.title,
                    episode.showTitle,
                    durationLabel,
                  ].filter(Boolean).join('. ')}
                  accessibilityHint="Double tap to open. Use actions to move or remove."
                  accessibilityActions={[
                    { name: 'open',        label: 'Open episode' },
                    ...(!isFirst ? [{ name: 'move_up',   label: 'Move up' }] : []),
                    ...(!isLast  ? [{ name: 'move_down', label: 'Move down' }] : []),
                    { name: 'remove',      label: 'Remove from queue' },
                  ]}
                  onAccessibilityAction={(e) => {
                    const { actionName } = e.nativeEvent;
                    if (actionName === 'open')        navigateToEpisode(episode.id);
                    else if (actionName === 'move_up')    player.moveQueueItemUp(episode.id);
                    else if (actionName === 'move_down')  player.moveQueueItemDown(episode.id);
                    else if (actionName === 'remove')     player.removeFromQueue(episode.id);
                  }}
                  style={[styles.cardSmall, { marginBottom: 8 }]}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                    {/* Position number */}
                    <View style={{
                      width: 28, height: 28, borderRadius: 14,
                      backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                    }}>
                      <Text style={{ fontSize: 13, fontWeight: '700', color: colors.pillText }}>{index + 1}</Text>
                    </View>

                    {/* Episode info */}
                    <View style={{ flex: 1 }}>
                      <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }} numberOfLines={2}>
                        {episode.title}
                      </Text>
                      <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                        {episode.showTitle}{durationLabel ? ` · ${durationLabel}` : ''}
                      </Text>
                    </View>

                    {/* Move up/down buttons */}
                    <View style={{ flexDirection: 'column', gap: 4 }} accessibilityElementsHidden>
                      <Pressable
                        onPress={() => player.moveQueueItemUp(episode.id)}
                        hitSlop={8}
                        style={{ opacity: isFirst ? 0.3 : 1 }}
                        disabled={isFirst}
                      >
                        <Ionicons name="chevron-up" size={18} color={colors.textSecondary} />
                      </Pressable>
                      <Pressable
                        onPress={() => player.moveQueueItemDown(episode.id)}
                        hitSlop={8}
                        style={{ opacity: isLast ? 0.3 : 1 }}
                        disabled={isLast}
                      >
                        <Ionicons name="chevron-down" size={18} color={colors.textSecondary} />
                      </Pressable>
                    </View>

                    {/* Remove button */}
                    <Pressable
                      onPress={() => player.removeFromQueue(episode.id)}
                      hitSlop={8}
                      accessibilityElementsHidden
                    >
                      <Ionicons name="close-circle-outline" size={22} color={colors.textSecondary} />
                    </Pressable>
                  </View>
                </Pressable>
              );
            })}
          </>
        )}
      </ScrollView>
    </Screen>
  );
}
