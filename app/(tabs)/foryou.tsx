import { useCallback, useRef, useState } from 'react';
import {
  ActivityIndicator, Pressable, RefreshControl, ScrollView, Share, Text, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { useFocusEffect, useRouter } from 'expo-router';
import { relativeTime } from '../../src/utils/relativeTime';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { FilterPicker } from '../../src/components/FilterPicker';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useEpisodeMeta } from '../../src/hooks/useEpisodeMeta';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { deleteAllDownloads } from '../../src/services/downloads';
import type { PodcastEpisode, SavedItem } from '../../src/types/content';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
}

function kindLabel(kind: SavedItem['kind']): string {
  switch (kind) {
    case 'forumTopic':     return 'Topic';
    case 'podcastEpisode': return 'Podcast';
    case 'appListing':     return 'App';
    case 'resource':       return 'Guide';
    case 'blogPost':       return 'Blog';
    default:               return 'Item';
  }
}

// ─── Tab constants ────────────────────────────────────────────────────────────

const FOR_YOU_TABS = ['Queue', 'Downloads', 'Saved'] as const;
type ForYouTab = typeof FOR_YOU_TABS[number];

type SavedFilter = 'All' | 'Topics' | 'Podcasts' | 'Apps' | 'Guides';
const SAVED_FILTERS: SavedFilter[] = ['All', 'Topics', 'Podcasts', 'Apps', 'Guides'];

// ─── Queue section ────────────────────────────────────────────────────────────

function QueueSection() {
  const router          = useRouter();
  const { colors, styles } = useTheme();
  const player          = usePlayer();
  const queue           = player.queue;

  function navigateToEpisode(episode: PodcastEpisode) {
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
    <>
      {/* Now playing */}
      {player.episode && (
        <>
          <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}
            accessibilityRole="header">
            Now Playing
          </Text>
          <Pressable
            onPress={() => navigateToEpisode(player.episode!)}
            accessible accessibilityRole="button"
            accessibilityLabel={`Now playing: ${player.episode.title}. ${player.episode.showTitle}. Double tap to open.`}
            style={[styles.cardSmall, { borderWidth: 2, borderColor: colors.accent, marginBottom: 20 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <Ionicons
                name={player.isPlaying ? 'musical-notes' : 'pause'}
                size={20} color={colors.accent} accessibilityElementsHidden
              />
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 15, fontWeight: '700', color: colors.text }} numberOfLines={2}>
                  {player.episode.title}
                </Text>
                <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                  {player.episode.showTitle}
                  {player.duration > 0
                    ? ` · ${formatDuration(player.duration - player.position)} left`
                    : ''}
                </Text>
              </View>
            </View>
          </Pressable>
        </>
      )}

      {/* Up next */}
      {queue.length === 0 ? (
        <EmptyState
          icon="list-outline"
          title="Queue is empty"
          subtitle="Add episodes using the Queue action on any episode card."
        />
      ) : (
        <>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}
              accessibilityRole="header">
              Up Next ({queue.length})
            </Text>
            <Pressable
              onPress={player.clearQueue}
              accessible accessibilityRole="button" accessibilityLabel="Clear entire queue"
              style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, backgroundColor: colors.pill }}
            >
              <Text style={{ fontSize: 13, fontWeight: '600', color: colors.pillText }}>Clear All</Text>
            </Pressable>
          </View>

          {queue.map((episode, index) => {
            const isFirst = index === 0;
            const isLast  = index === queue.length - 1;
            return (
              <Pressable
                key={episode.id}
                onPress={() => navigateToEpisode(episode)}
                accessible
                accessibilityRole="none"
                accessibilityLabel={[
                  `${index + 1} of ${queue.length}`,
                  episode.title,
                  episode.showTitle,
                  formatDuration(episode.duration),
                ].filter(Boolean).join('. ')}
                accessibilityHint="Double tap to open. Use actions to move or remove."
                accessibilityActions={[
                  { name: 'open',      label: 'Open episode' },
                  ...(!isFirst ? [{ name: 'move_up',   label: 'Move up' }] : []),
                  ...(!isLast  ? [{ name: 'move_down', label: 'Move down' }] : []),
                  { name: 'remove',    label: 'Remove from queue' },
                ]}
                onAccessibilityAction={(e) => {
                  switch (e.nativeEvent.actionName) {
                    case 'open':       navigateToEpisode(episode); break;
                    case 'move_up':    player.moveQueueItemUp(episode.id); break;
                    case 'move_down':  player.moveQueueItemDown(episode.id); break;
                    case 'remove':     player.removeFromQueue(episode.id); break;
                  }
                }}
                style={[styles.cardSmall, { marginBottom: 8 }]}
              >
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <View style={{ width: 28, height: 28, borderRadius: 14,
                    backgroundColor: colors.pill, alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Text style={{ fontSize: 13, fontWeight: '700', color: colors.pillText }}>{index + 1}</Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 15, fontWeight: '600', color: colors.text }} numberOfLines={2}>
                      {episode.title}
                    </Text>
                    <Text style={{ fontSize: 13, color: colors.textSecondary }}>
                      {episode.showTitle}{episode.duration > 0 ? ` · ${formatDuration(episode.duration)}` : ''}
                    </Text>
                  </View>
                  <View style={{ flexDirection: 'column', gap: 4 }} accessibilityElementsHidden>
                    <Pressable onPress={() => player.moveQueueItemUp(episode.id)}
                      hitSlop={8} style={{ opacity: isFirst ? 0.3 : 1 }} disabled={isFirst}>
                      <Ionicons name="chevron-up" size={18} color={colors.textSecondary} />
                    </Pressable>
                    <Pressable onPress={() => player.moveQueueItemDown(episode.id)}
                      hitSlop={8} style={{ opacity: isLast ? 0.3 : 1 }} disabled={isLast}>
                      <Ionicons name="chevron-down" size={18} color={colors.textSecondary} />
                    </Pressable>
                  </View>
                  <Pressable onPress={() => player.removeFromQueue(episode.id)}
                    hitSlop={8} accessibilityElementsHidden>
                    <Ionicons name="close-circle-outline" size={22} color={colors.textSecondary} />
                  </Pressable>
                </View>
              </Pressable>
            );
          })}
        </>
      )}
    </>
  );
}

// ─── Downloads section ────────────────────────────────────────────────────────

function DownloadsSection() {
  const router          = useRouter();
  const { colors, styles } = useTheme();
  const player          = usePlayer();
  const meta            = useEpisodeMeta();
  const { showToast }   = useToast();

  const downloadedEpisodes = Object.values(meta.downloadedMeta).sort(
    (a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime(),
  );

  function navigateToEpisode(episode: PodcastEpisode) {
    router.push({
      pathname: '/episode/[id]' as any,
      params: {
        id: episode.id, title: episode.title,
        showTitle: episode.showTitle, description: episode.description ?? '',
        artworkUrl: episode.artworkUrl ?? '', publishedAt: episode.publishedAt ?? '',
        duration: String(episode.duration), audioUrl: episode.audioUrl,
      },
    });
  }

  function playEpisode(episode: PodcastEpisode) {
    player.loadEpisode(episode, true);
  }

  if (downloadedEpisodes.length === 0) {
    return (
      <EmptyState
        icon="cloud-download-outline"
        title="No downloaded episodes"
        subtitle="Download any episode to listen offline — no internet needed."
      />
    );
  }

  return (
    <>
      <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 12 }}>
        <Pressable
          onPress={async () => { await deleteAllDownloads(); meta.reload(); showToast('All downloads removed.', 'success'); }}
          accessible accessibilityRole="button" accessibilityLabel="Remove all downloads"
          style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}
        >
          <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Remove All</Text>
        </Pressable>
      </View>

      {downloadedEpisodes.map((episode) => {
        const isCurrent    = player.episode?.id === episode.id;
        const isQueued     = player.queue.some((q) => q.id === episode.id);
        const isSaved      = meta.savedIds.has(episode.id);
        const isDownloading = meta.downloading.has(episode.id);

        return (
          <View key={episode.id} style={[styles.card, { marginBottom: 10 }]}>
            <Pressable
              onPress={() => navigateToEpisode(episode)}
              accessible accessibilityRole="none"
              accessibilityLabel={[
                episode.title, episode.showTitle,
                episode.duration > 0 ? formatDuration(episode.duration) : null,
                'Downloaded',
              ].filter(Boolean).join('. ')}
              accessibilityHint="Double tap to open episode details."
              accessibilityActions={[
                { name: 'play',   label: isCurrent && player.isPlaying ? 'Pause' : 'Play' },
                { name: 'queue',  label: isQueued ? 'Remove from queue' : 'Add to queue' },
                { name: 'save',   label: isSaved ? 'Unsave' : 'Save' },
                { name: 'remove', label: 'Remove download' },
              ]}
              onAccessibilityAction={({ nativeEvent }) => {
                switch (nativeEvent.actionName) {
                  case 'play':   playEpisode(episode); break;
                  case 'queue':
                    if (isQueued) { player.removeFromQueue(episode.id); showToast('Removed from queue.', 'success'); }
                    else { player.enqueue(episode); showToast('Added to queue.', 'success'); }
                    break;
                  case 'save':
                    if (isSaved) meta.unsaveEpisode(episode.id).then(() => showToast('Episode unsaved.', 'success'));
                    else meta.saveEpisode(episode).then(() => showToast('Episode saved.', 'success'));
                    break;
                  case 'remove': meta.removeDownload(episode.id); showToast('Download removed.', 'success'); break;
                }
              }}
            >
              <Text style={[styles.cardTitle, { marginBottom: 2 }]}>{episode.title}</Text>
              <Text style={[styles.cardMeta, { marginBottom: 10 }]}>
                {episode.showTitle}
                {episode.duration > 0 ? ` · ${formatDuration(episode.duration)}` : ''}
                {episode.publishedAt ? ` · ${relativeTime(episode.publishedAt)}` : ''}
              </Text>
            </Pressable>

            <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
              <Pressable onPress={() => playEpisode(episode)}
                accessible accessibilityRole="button"
                accessibilityLabel={isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.accent, borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8, flex: 1 }}>
                <Ionicons name={isCurrent && player.isPlaying ? 'pause' : 'play'} size={14} color="#FFF" accessibilityElementsHidden />
                <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 13 }}>
                  {isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                </Text>
              </Pressable>

              <Pressable
                onPress={() => { if (isQueued) { player.removeFromQueue(episode.id); showToast('Removed from queue.', 'success'); } else { player.enqueue(episode); showToast('Added to queue.', 'success'); } }}
                accessible accessibilityRole="button"
                accessibilityLabel={isQueued ? 'Remove from queue' : 'Add to queue'}
                style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: isQueued ? colors.accent + '22' : colors.pill,
                  borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                <Ionicons name={isQueued ? 'remove-circle-outline' : 'add-circle-outline'} size={14} color={colors.accent} accessibilityElementsHidden />
                <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 13 }}>
                  {isQueued ? 'In Queue' : 'Queue'}
                </Text>
              </Pressable>

              <Pressable
                onPress={() => { meta.removeDownload(episode.id); showToast('Download removed.', 'success'); }}
                accessible accessibilityRole="button" accessibilityLabel="Remove download"
                style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                  backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                <Ionicons name="trash-outline" size={14} color="#FF3B30" accessibilityElementsHidden />
                <Text style={{ color: '#FF3B30', fontWeight: '600', fontSize: 13 }}>Remove</Text>
              </Pressable>
            </View>
          </View>
        );
      })}
    </>
  );
}

// ─── Saved section ────────────────────────────────────────────────────────────

function SavedSection() {
  const router          = useRouter();
  const { colors, styles } = useTheme();
  const player          = usePlayer();
  const meta            = useEpisodeMeta();
  const saved           = useSavedItems();
  const { showToast }   = useToast();

  const [kindFilter, setKindFilter] = useState<SavedFilter>('All');

  // Reload meta when section comes into focus (covers unsave from other screens)
  useFocusEffect(useCallback(() => { meta.reload(); }, []));

  const filteredItems = saved.items.filter((item) => {
    if (kindFilter === 'All')      return true;
    if (kindFilter === 'Topics')   return item.kind === 'forumTopic';
    if (kindFilter === 'Podcasts') return item.kind === 'podcastEpisode';
    if (kindFilter === 'Apps')     return item.kind === 'appListing';
    if (kindFilter === 'Guides')   return item.kind === 'resource';
    return true;
  });

  if (saved.loading) {
    return (
      <View style={{ alignItems: 'center', paddingVertical: 40 }}>
        <ActivityIndicator size="large" color={colors.appleVisBlue} accessibilityLabel="Loading saved items" />
      </View>
    );
  }

  return (
    <>
      {/* Kind filter chips */}
      <ScrollView
        horizontal showsHorizontalScrollIndicator={false}
        contentContainerStyle={{ gap: 8, paddingBottom: 14 }}
        accessibilityRole="tablist"
        accessibilityLabel="Filter saved items by type"
      >
        {SAVED_FILTERS.map((f) => {
          const isSelected = kindFilter === f;
          return (
            <Pressable
              key={f}
              onPress={() => setKindFilter(f)}
              accessible accessibilityRole="tab"
              accessibilityLabel={f}
              accessibilityState={{ selected: isSelected }}
              style={{
                paddingHorizontal: 14, paddingVertical: 7,
                borderRadius: 20, borderWidth: isSelected ? 0 : 1,
                borderColor: colors.border,
                backgroundColor: isSelected ? colors.accent : colors.inputBackground,
              }}
            >
              <Text style={{ fontSize: 14, fontWeight: '600', color: isSelected ? '#FFF' : colors.text }}>
                {f}
              </Text>
            </Pressable>
          );
        })}

        {/* Blogs — disabled chip */}
        <View
          style={{
            paddingHorizontal: 14, paddingVertical: 7, borderRadius: 20,
            borderWidth: 1, borderColor: colors.border,
            backgroundColor: colors.inputBackground, opacity: 0.45,
          }}
          accessible
          accessibilityLabel="Blogs, coming soon, unavailable"
          accessibilityState={{ disabled: true }}
        >
          <Text style={{ fontSize: 14, fontWeight: '600', color: colors.textSecondary }}>Blogs</Text>
        </View>
      </ScrollView>

      {/* Bulk unsave */}
      {filteredItems.length > 0 && (
        <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 12 }}>
          <Pressable
            onPress={async () => {
              for (const item of filteredItems) await saved.unsave(item.id).catch(() => {});
              showToast('Removed saved items.', 'success');
            }}
            accessible accessibilityRole="button"
            accessibilityLabel={`Unsave all ${kindFilter === 'All' ? '' : kindFilter.toLowerCase() + ' '}items`}
            style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}
          >
            <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Unsave All</Text>
          </Pressable>
        </View>
      )}

      {/* Empty state */}
      {filteredItems.length === 0 && (
        <EmptyState
          icon="bookmark-outline"
          title={kindFilter === 'All' ? 'Nothing saved yet' : `No saved ${kindFilter.toLowerCase()}`}
          subtitle="Save topics, episodes, apps, and guides using the Save action on any card."
        />
      )}

      {/* Saved item cards */}
      {filteredItems.map((item) => {
        // ── Podcast episode — rich card with full metadata ──────────────
        if (item.kind === 'podcastEpisode') {
          const episode = meta.savedMeta[item.id];
          const isQueued = player.queue.some((q) => q.id === item.id);
          const isDownloaded = item.id in meta.downloaded;
          const isDownloading = meta.downloading.has(item.id);

          if (episode) {
            return (
              <View key={item.id} style={[styles.card, { marginBottom: 10 }]}>
                <Pressable
                  onPress={() => router.push({ pathname: '/episode/[id]' as any, params: { id: item.id } })}
                  accessible accessibilityRole="none"
                  accessibilityLabel={[
                    episode.title, episode.showTitle,
                    episode.duration > 0 ? formatDuration(episode.duration) : null,
                    'Saved',
                  ].filter(Boolean).join('. ')}
                  accessibilityHint="Double tap to open episode details."
                  accessibilityActions={[
                    { name: 'play',     label: player.episode?.id === item.id && player.isPlaying ? 'Pause' : 'Play' },
                    { name: 'queue',    label: isQueued ? 'Remove from queue' : 'Add to queue' },
                    { name: 'download', label: isDownloading ? 'Downloading…' : isDownloaded ? 'Remove download' : 'Download' },
                    { name: 'unsave',   label: 'Unsave episode' },
                  ]}
                  onAccessibilityAction={({ nativeEvent }) => {
                    switch (nativeEvent.actionName) {
                      case 'play':
                        if (player.episode?.id === item.id && player.isPlaying) player.pause();
                        else { player.loadEpisode(episode, true); }
                        break;
                      case 'queue':
                        if (isQueued) { player.removeFromQueue(item.id); showToast('Removed from queue.', 'success'); }
                        else { player.enqueue(episode); showToast('Added to queue.', 'success'); }
                        break;
                      case 'unsave':
                        meta.unsaveEpisode(item.id).then(() => showToast('Episode unsaved.', 'success'));
                        break;
                    }
                  }}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 4 }}>
                    <Text style={[styles.cardTitle, { flex: 1, marginRight: 8 }]}>{episode.title}</Text>
                    <Ionicons name="bookmark" size={16} color={colors.accent}
                      accessibilityElementsHidden style={{ marginTop: 2 }} />
                  </View>
                  <Text style={[styles.cardMeta, { marginBottom: 10 }]}>
                    {episode.showTitle}
                    {episode.duration > 0 ? ` · ${formatDuration(episode.duration)}` : ''}
                    {episode.publishedAt ? ` · ${relativeTime(episode.publishedAt)}` : ''}
                  </Text>
                </Pressable>

                <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
                  <Pressable
                    onPress={() => {
                      if (player.episode?.id === item.id && player.isPlaying) player.pause();
                      else { player.loadEpisode(episode, true); }
                    }}
                    accessible accessibilityRole="button"
                    accessibilityLabel={player.episode?.id === item.id && player.isPlaying ? 'Pause' : 'Play'}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                      backgroundColor: colors.accent, borderRadius: 8,
                      paddingHorizontal: 14, paddingVertical: 8, flex: 1 }}>
                    <Ionicons name={player.episode?.id === item.id && player.isPlaying ? 'pause' : 'play'} size={14} color="#FFF" accessibilityElementsHidden />
                    <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 13 }}>
                      {player.episode?.id === item.id && player.isPlaying ? 'Pause' : 'Play'}
                    </Text>
                  </Pressable>

                  <Pressable
                    onPress={() => { if (isQueued) { player.removeFromQueue(item.id); showToast('Removed from queue.', 'success'); } else { player.enqueue(episode); showToast('Added to queue.', 'success'); } }}
                    accessible accessibilityRole="button"
                    accessibilityLabel={isQueued ? 'Remove from queue' : 'Add to queue'}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                      backgroundColor: isQueued ? colors.accent + '22' : colors.pill,
                      borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                    <Ionicons name={isQueued ? 'remove-circle-outline' : 'add-circle-outline'} size={14} color={colors.accent} accessibilityElementsHidden />
                    <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 13 }}>
                      {isQueued ? 'In Queue' : 'Queue'}
                    </Text>
                  </Pressable>

                  <Pressable
                    onPress={() => meta.unsaveEpisode(item.id).then(() => showToast('Episode unsaved.', 'success'))}
                    accessible accessibilityRole="button" accessibilityLabel="Unsave episode"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                    <Ionicons name="bookmark-outline" size={14} color="#FF3B30" accessibilityElementsHidden />
                    <Text style={{ color: '#FF3B30', fontWeight: '600', fontSize: 13 }}>Unsave</Text>
                  </Pressable>

                  <Pressable
                    onPress={() => Share.share({ title: episode.title, message: `${episode.title} — https://www.applevis.com/podcast` }).catch(() => {})}
                    accessible accessibilityRole="button" accessibilityLabel="Share episode"
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                    <Ionicons name="share-outline" size={14} color={colors.accent} accessibilityElementsHidden />
                    <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 13 }}>Share</Text>
                  </Pressable>
                </View>
              </View>
            );
          }

          // Episode metadata not available — fallback simple card
          return (
            <AccessibleCard
              key={item.id}
              title={item.title}
              meta={`Podcast · Saved ${relativeTime(item.savedAt)}`}
              actions={['Open Episode', 'Unsave']}
              onAction={(action) => {
                if (action === 'Open Episode') router.push({ pathname: '/episode/[id]' as any, params: { id: item.id } });
                else if (action === 'Unsave') { saved.unsave(item.id); showToast('Episode unsaved.', 'success'); }
              }}
            />
          );
        }

        // ── Topic ───────────────────────────────────────────────────────
        if (item.kind === 'forumTopic') {
          return (
            <AccessibleCard
              key={item.id}
              title={item.title}
              meta={`Topic · Saved ${relativeTime(item.savedAt)}`}
              actions={['Open Topic', 'Unsave']}
              onAction={(action) => {
                if (action === 'Open Topic') router.push({ pathname: '/topic/[id]' as any, params: { id: item.id, title: item.title } });
                else if (action === 'Unsave') { saved.unsave(item.id); showToast('Topic unsaved.', 'success'); }
              }}
            />
          );
        }

        // ── App ─────────────────────────────────────────────────────────
        if (item.kind === 'appListing') {
          return (
            <AccessibleCard
              key={item.id}
              title={item.title}
              meta={`App · Saved ${relativeTime(item.savedAt)}`}
              actions={['Open App Page', 'Unsave']}
              onAction={(action) => {
                if (action === 'Open App Page') router.push({ pathname: '/app-detail/[id]' as any, params: { id: item.id, name: item.title } });
                else if (action === 'Unsave') { saved.unsave(item.id); showToast('App unsaved.', 'success'); }
              }}
            />
          );
        }

        // ── Guide ────────────────────────────────────────────────────────
        if (item.kind === 'resource') {
          return (
            <AccessibleCard
              key={item.id}
              title={item.title}
              meta={`Guide · Saved ${relativeTime(item.savedAt)}`}
              actions={['Open Guide', 'Unsave']}
              onAction={(action) => {
                if (action === 'Open Guide') router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id } });
                else if (action === 'Unsave') { saved.unsave(item.id); showToast('Guide unsaved.', 'success'); }
              }}
            />
          );
        }

        return null;
      })}
    </>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function ForYouScreen() {
  const [tab, setTab] = useState<ForYouTab>('Queue');
  const [refreshing, setRefreshing] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const scrollRef = useRef<ScrollView>(null);
  useScrollToTop(scrollRef);

  useFocusEffect(useCallback(() => {
    const t = setTimeout(() => scrollRef.current?.flashScrollIndicators(), 350);
    return () => clearTimeout(t);
  }, []));

  function handleRefresh() {
    setRefreshing(true);
    setRefreshKey((k) => k + 1);
    setTimeout(() => setRefreshing(false), 1200);
  }

  useHandoff({
    activityType: 'com.applevis.app.forYou',
    title: 'For You — AppleVis',
    webpageURL: 'https://www.applevis.com',
  });

  return (
    <Screen title="For You" showBack={false}>
      <ScrollView
        ref={scrollRef}
        contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
        showsVerticalScrollIndicator
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            accessibilityLabel="Pull to refresh For You"
          />
        }
      >
        {/* Section switcher */}
        <FilterPicker
          label="Section"
          options={FOR_YOU_TABS}
          value={tab}
          onChange={(v) => setTab(v as ForYouTab)}
        />

        <View key={refreshKey} style={{ marginTop: 16 }}>
          {tab === 'Queue'     && <QueueSection />}
          {tab === 'Downloads' && <DownloadsSection />}
          {tab === 'Saved'     && <SavedSection />}
        </View>
      </ScrollView>
    </Screen>
  );
}
