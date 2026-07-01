import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActivityIndicator, findNodeHandle, Pressable,
  RefreshControl, ScrollView, Share, Text, View,
} from 'react-native';
import { useScrollToTop } from '@react-navigation/native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { relativeTime } from '../../src/utils/relativeTime';
import { Ionicons } from '@expo/vector-icons';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { FilterPicker } from '../../src/components/FilterPicker';
import { AccessibleCard } from '../../src/components/AccessibleCard';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useAlert } from '../../src/contexts/AccessibleAlertContext';
import { confirmDestructiveAction } from '../../src/utils/confirmDestructiveAction';
import { useEpisodeMeta } from '../../src/hooks/useEpisodeMeta';
import { useEpisodeDurations } from '../../src/hooks/useEpisodeDurations';
import { useSavedItems } from '../../src/hooks/useSavedItems';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { useTip, TIP_KEYS, TIPS } from '../../src/contexts/ContextualTipContext';
import { useTheme } from '../../src/contexts/ThemeContext';
import { deleteAllDownloads } from '../../src/services/downloads';
import { persistence } from '../../src/services/persistence';
import { cachedApi } from '../../src/services/cachedApi';
import { api } from '../../src/services/api';
import type { FollowedItem, ForumTopic, PodcastEpisode, SavedItem } from '../../src/types/content';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}h ${m}m` : `${m} min`;
}

function formatTime(seconds: number): string {
  if (seconds <= 0) return '0:00';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
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

function openFollowedItem(router: ReturnType<typeof useRouter>, item: FollowedItem) {
  switch (item.kind) {
    case 'forumTopic':
      router.push({ pathname: '/topic/[id]' as any, params: { id: item.id, title: item.title } });
      break;
    case 'podcastEpisode':
      router.push({ pathname: '/episode/[id]' as any, params: { id: item.id, title: item.title } });
      break;
    case 'appListing':
      router.push({ pathname: '/app-detail/[id]' as any, params: { id: item.id, name: item.title } });
      break;
    case 'resource':
      router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url ?? '' } });
      break;
    case 'blogPost':
      router.push({ pathname: '/blog-detail/[id]' as any, params: { id: item.id, title: item.title, url: item.url ?? '' } });
      break;
  }
}

// ─── Tab constants ────────────────────────────────────────────────────────────

const FOR_YOU_TABS = ['Queue', 'Downloads', 'Saved', 'Following'] as const;
type ForYouTab = typeof FOR_YOU_TABS[number];

type SavedFilter = 'All' | 'Topics' | 'Podcasts' | 'Apps' | 'Guides' | 'Blogs';
const SAVED_FILTERS: SavedFilter[] = ['All', 'Topics', 'Podcasts', 'Apps', 'Guides', 'Blogs'];

// Maps the content-model kind names used in deep-link params (e.g. from Profile's
// saved rows) to the UI-level Saved filter labels used by the picker above.
const SAVED_TYPE_TO_FILTER: Record<string, SavedFilter> = {
  forumTopic: 'Topics',
  podcastEpisode: 'Podcasts',
  appListing: 'Apps',
  resource: 'Guides',
  blogPost: 'Blogs',
};

const KIND_ACCENT_SAVED: Record<SavedItem['kind'], string> = {
  forumTopic:      '#6366f1',
  podcastEpisode:  '#f97316',
  appListing:      '#3b82f6',
  resource:        '#10b981',
  blogPost:        '#8b5cf6',
};

const SECTION_ACCENT: Record<ForYouTab, string> = {
  Queue:     '#f97316',
  Downloads: '#10b981',
  Saved:     '#6366f1',
  Following: '#8b5cf6',
};

// ─── SavedItemCard ────────────────────────────────────────────────────────────

function SavedItemCard({
  item,
  accentColor,
  kindLabel: kLabel,
  kindDisplay,
  onOpen,
  onUnsave,
}: {
  item: SavedItem;
  accentColor: string;
  kindLabel: string;
  kindDisplay: string;
  onOpen: () => void;
  onUnsave: () => void;
}) {
  const { colors, styles } = useTheme();
  return (
    <Pressable
      onPress={onOpen}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`${item.title}. ${kindDisplay}. Saved ${relativeTime(item.savedAt)}.`}
      accessibilityHint="Double tap to open. Hold for options."
      accessibilityActions={[
        { name: 'open',   label: `Open ${kLabel}` },
        { name: 'unsave', label: 'Unsave' },
      ]}
      onAccessibilityAction={({ nativeEvent }) => {
        if (nativeEvent.actionName === 'open')   onOpen();
        if (nativeEvent.actionName === 'unsave') onUnsave();
      }}
      style={({ pressed }) => [
        styles.card,
        { marginBottom: 10, borderLeftWidth: 3, borderLeftColor: accentColor, opacity: pressed ? 0.75 : 1 },
      ]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 4 }}>
        <Text
          style={{ flex: 1, fontSize: 16, fontWeight: '600', color: colors.text, lineHeight: 22 }}
          numberOfLines={2}
        >
          {item.title}
        </Text>
        <Ionicons name="bookmark" size={15} color={accentColor} accessibilityElementsHidden style={{ marginTop: 2 }} />
      </View>
      <Text style={{ fontSize: 11, fontWeight: '700', color: accentColor,
        textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>
        {kindDisplay}
      </Text>
      <Text style={{ fontSize: 13, color: colors.textSecondary }}>
        Saved {relativeTime(item.savedAt)}
      </Text>
    </Pressable>
  );
}

// ─── Queue section ────────────────────────────────────────────────────────────

function QueueSection() {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const player             = usePlayer();
  const { showAlert }      = useAlert();
  const cachedDurations    = useEpisodeDurations();
  const enrich             = (ep: PodcastEpisode): PodcastEpisode =>
    cachedDurations[ep.id] ? { ...ep, duration: cachedDurations[ep.id] } : ep;
  const queue              = player.queue.map(enrich);

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
        transcriptUrl: episode.transcriptUrl ?? '',
        url: episode.url ?? '',
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
            style={[styles.cardSmall, {
              borderWidth: 2, borderColor: colors.accent,
              borderLeftWidth: 4, borderLeftColor: '#f97316',
              marginBottom: 20,
            }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <Ionicons
                name={player.isPlaying ? 'musical-notes' : 'pause'}
                size={20} color='#f97316' accessibilityElementsHidden
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
            {player.duration > 0 && (
              <View accessibilityElementsHidden>
                <View style={{ height: 5, backgroundColor: colors.border, borderRadius: 2.5, marginTop: 10, overflow: 'hidden' }}>
                  <View style={{
                    height: 5, borderRadius: 2.5, backgroundColor: '#f97316',
                    width: `${Math.min(100, (player.position / player.duration) * 100)}%`,
                  }} />
                </View>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 4 }}>
                  <Text style={{ fontSize: 11, color: colors.textSecondary }}>{formatTime(player.position)}</Text>
                  <Text style={{ fontSize: 11, color: colors.textSecondary }}>{formatTime(player.duration)}</Text>
                </View>
              </View>
            )}
          </Pressable>
        </>
      )}

      {/* Up next */}
      {queue.length === 0 ? (
        <EmptyState
          icon="list-outline"
          title="Queue is empty"
          subtitle="Add episodes using the Queue action on any episode card."
          primaryAction={{ label: 'Browse Podcasts', onPress: () => router.push('/podcast-browse' as any) }}
        />
      ) : (
        <>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <Text style={{ fontSize: 13, fontWeight: '700', color: colors.textSecondary,
              textTransform: 'uppercase', letterSpacing: 0.8 }}
              accessibilityRole="header"
              accessibilityActions={[{ name: 'summary', label: 'Queue summary' }]}
              onAccessibilityAction={() => {
                const totalSecs = queue.reduce((s, ep) => s + (ep.duration > 0 ? ep.duration : 0), 0);
                const h = Math.floor(totalSecs / 3600);
                const m = Math.floor((totalSecs % 3600) / 60);
                const durLabel = h > 0
                  ? `${h} hour${h !== 1 ? 's' : ''} ${m} minute${m !== 1 ? 's' : ''}`
                  : `${m} minute${m !== 1 ? 's' : ''}`;
                AccessibilityInfo.announceForAccessibility(
                  `${queue.length} episode${queue.length !== 1 ? 's' : ''} in queue${totalSecs > 0 ? `, about ${durLabel}` : ''}.`
                );
              }}
            >
              Up Next ({queue.length})
            </Text>
            <Pressable
              onPress={() => confirmDestructiveAction(showAlert, {
                title: 'Clear Queue?',
                message: 'This will remove all episodes from your queue. Downloaded episodes will not be deleted.',
                confirmLabel: 'Clear Queue',
                onConfirm: () => {
                  player.clearQueue();
                  AccessibilityInfo.announceForAccessibility('Queue cleared.');
                },
              })}
              accessible accessibilityRole="button" accessibilityLabel="Clear entire queue"
              style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, backgroundColor: colors.pill }}
            >
              <Text style={{ fontSize: 13, fontWeight: '600', color: colors.pillText }}>Clear Queue</Text>
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
                accessibilityRole="button"
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
                style={[styles.cardSmall, { marginBottom: 8, borderLeftWidth: 3, borderLeftColor: '#f97316' }]}
              >
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <View style={{ width: 28, height: 28, borderRadius: 14,
                    backgroundColor: '#f97316', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Text style={{ fontSize: 13, fontWeight: '700', color: '#fff' }}>{index + 1}</Text>
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
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const player             = usePlayer();
  const meta               = useEpisodeMeta();
  const { showToast }      = useToast();
  const { showAlert }      = useAlert();
  const cachedDurations    = useEpisodeDurations();
  const enrich             = (ep: PodcastEpisode): PodcastEpisode =>
    cachedDurations[ep.id] ? { ...ep, duration: cachedDurations[ep.id] } : ep;

  const downloadedEpisodes = Object.values(meta.downloadedMeta)
    .sort((a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime())
    .map(enrich);

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
        primaryAction={{ label: 'Browse Podcasts', onPress: () => router.push('/podcast-browse' as any) }}
      />
    );
  }

  return (
    <>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 12 }}>
        <Text
          style={{ flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8 }}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Downloads summary' }]}
          onAccessibilityAction={() => {
            const total = downloadedEpisodes.reduce((s, ep) => s + (ep.duration > 0 ? ep.duration : 0), 0);
            const h = Math.floor(total / 3600);
            const m = Math.floor((total % 3600) / 60);
            const durLabel = h > 0
              ? `${h} hour${h !== 1 ? 's' : ''} ${m} minute${m !== 1 ? 's' : ''}`
              : `${m} minute${m !== 1 ? 's' : ''}`;
            AccessibilityInfo.announceForAccessibility(
              `${downloadedEpisodes.length} downloaded episode${downloadedEpisodes.length !== 1 ? 's' : ''}${total > 0 ? `, ${durLabel} total` : ''}.`
            );
          }}
        >
          Downloaded Episodes
        </Text>
        <View style={{ paddingHorizontal: 8, paddingVertical: 3, backgroundColor: '#10b98122',
          borderRadius: 10, marginRight: 8 }}>
          <Text style={{ fontSize: 11, fontWeight: '700', color: '#10b981' }} accessibilityElementsHidden>
            {downloadedEpisodes.length}
          </Text>
        </View>
        <Pressable
          onPress={() => confirmDestructiveAction(showAlert, {
            title: 'Remove Downloads?',
            message: `This will delete all ${downloadedEpisodes.length} downloaded episode${downloadedEpisodes.length === 1 ? '' : 's'} from this device. Queue and Saved items will not be affected.`,
            confirmLabel: 'Remove Downloads',
            onConfirm: async () => {
              await deleteAllDownloads();
              meta.reload();
              showToast('All downloads removed.', 'success');
              AccessibilityInfo.announceForAccessibility('All downloads removed.');
            },
          })}
          accessible accessibilityRole="button" accessibilityLabel="Remove all downloads"
          style={{ paddingHorizontal: 12, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}
        >
          <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Remove Downloads</Text>
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
              accessible accessibilityRole="button"
              accessibilityLabel={[
                episode.title, episode.showTitle,
                episode.duration > 0 ? formatDuration(episode.duration) : null,
                'Downloaded',
              ].filter(Boolean).join('. ')}
              accessibilityHint="Double tap to open episode details."
              accessibilityActions={[
                { name: 'play',   label: isCurrent && player.isPlaying ? 'Stop' : 'Play' },
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

function SavedSection({ initialFilter }: { initialFilter?: SavedFilter }) {
  const router             = useRouter();
  const { colors, styles } = useTheme();
  const player             = usePlayer();
  const meta               = useEpisodeMeta();
  const saved              = useSavedItems();
  const { showToast }      = useToast();
  const { showAlert }      = useAlert();
  const cachedDurations    = useEpisodeDurations();
  const enrich             = (ep: PodcastEpisode): PodcastEpisode =>
    cachedDurations[ep.id] ? { ...ep, duration: cachedDurations[ep.id] } : ep;

  const [kindFilter, setKindFilter] = useState<SavedFilter>(initialFilter ?? 'All');
  const sectionCountRef = useRef<Text | null>(null);

  // Reload meta when section comes into focus (covers unsave from other screens)
  useFocusEffect(useCallback(() => { meta.reload(); }, []));

  const filteredItems = saved.items.filter((item) => {
    if (kindFilter === 'All')      return true;
    if (kindFilter === 'Topics')   return item.kind === 'forumTopic';
    if (kindFilter === 'Podcasts') return item.kind === 'podcastEpisode';
    if (kindFilter === 'Apps')     return item.kind === 'appListing';
    if (kindFilter === 'Guides')   return item.kind === 'resource';
    if (kindFilter === 'Blogs')    return item.kind === 'blogPost';
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
      {/* Section heading */}
      <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 12 }}>
        <Text
          style={{ flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8 }}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Saved summary' }]}
          onAccessibilityAction={() => {
            const kindMap: Partial<Record<SavedFilter, SavedItem['kind']>> = {
              Topics: 'forumTopic', Podcasts: 'podcastEpisode',
              Apps: 'appListing', Guides: 'resource', Blogs: 'blogPost',
            };
            const parts = (Object.entries(kindMap) as [string, SavedItem['kind']][])
              .map(([lbl, kind]) => {
                const n = saved.items.filter(i => i.kind === kind).length;
                return n > 0 ? `${n} ${lbl.toLowerCase()}` : null;
              })
              .filter(Boolean);
            AccessibilityInfo.announceForAccessibility(
              saved.items.length === 0
                ? 'No saved items.'
                : `${saved.items.length} saved item${saved.items.length !== 1 ? 's' : ''}: ${parts.join(', ')}.`
            );
          }}
        >
          Saved Items
        </Text>
        <Text
          ref={sectionCountRef}
          style={{ fontSize: 12, color: colors.textSecondary }}
          accessibilityLiveRegion="polite"
          accessible
          accessibilityLabel={
            kindFilter === 'All'
              ? `${filteredItems.length} saved item${filteredItems.length !== 1 ? 's' : ''}`
              : `${filteredItems.length} saved ${kindFilter.toLowerCase()}`
          }
        >
          {kindFilter === 'All'
            ? `${filteredItems.length} item${filteredItems.length !== 1 ? 's' : ''}`
            : `${filteredItems.length} ${kindFilter.toLowerCase()}`}
        </Text>
      </View>

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
              <Text style={{ fontSize: 14, fontWeight: isSelected ? '700' : '600', color: isSelected ? '#FFF' : colors.text }}>
                {f}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>

      {/* Bulk unsave */}
      {filteredItems.length > 0 && (
        <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 12 }}>
          <Pressable
            onPress={() => confirmDestructiveAction(showAlert, {
              title: 'Unsave All?',
              message: `This will remove all ${filteredItems.length} saved ${kindFilter === 'All' ? 'item' : kindFilter.toLowerCase().replace(/s$/, '')}${filteredItems.length === 1 ? '' : 's'} from Saved. This does not delete the original content.`,
              confirmLabel: 'Unsave All',
              onConfirm: async () => {
                for (const item of filteredItems) await saved.unsave(item.id).catch(() => {});
                showToast('Removed saved items.', 'success');
                setTimeout(() => {
                  const handle = findNodeHandle(sectionCountRef.current);
                  if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
                }, 300);
              },
            })}
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
          subtitle={
            kindFilter === 'All'
              ? 'Save topics, episodes, apps, and guides using the Save action on any card.'
              : `You have no saved ${kindFilter.toLowerCase()}. Try a different filter or browse Discover.`
          }
          primaryAction={
            kindFilter !== 'All'
              ? { label: 'Clear Filter', onPress: () => setKindFilter('All') }
              : { label: 'Browse Discover', onPress: () => router.push('/(tabs)/discover' as any) }
          }
          secondaryAction={
            kindFilter !== 'All'
              ? { label: 'Browse Discover', onPress: () => router.push('/(tabs)/discover' as any) }
              : undefined
          }
        />
      )}

      {/* Saved item cards */}
      {filteredItems.map((item) => {
        // ── Podcast episode — rich card with full metadata ──────────────
        if (item.kind === 'podcastEpisode') {
          const episode = meta.savedMeta[item.id] ? enrich(meta.savedMeta[item.id]!) : undefined;
          const isQueued = player.queue.some((q) => q.id === item.id);
          const isDownloaded = item.id in meta.downloaded;
          const isDownloading = meta.downloading.has(item.id);

          if (episode) {
            return (
              <View key={item.id} style={[styles.card, { marginBottom: 10, borderLeftWidth: 3, borderLeftColor: '#f97316' }]}>
                <Pressable
                  onPress={() => router.push({
                    pathname: '/episode/[id]' as any,
                    params: {
                      id: episode.id,
                      title: episode.title,
                      showTitle: episode.showTitle,
                      description: episode.description ?? '',
                      artworkUrl: episode.artworkUrl ?? '',
                      publishedAt: episode.publishedAt ?? '',
                      duration: String(episode.duration),
                      audioUrl: episode.audioUrl ?? '',
                      url: episode.url ?? '',
                    },
                  })}
                  accessible accessibilityRole="button"
                  accessibilityLabel={[
                    episode.title, episode.showTitle,
                    episode.duration > 0 ? formatDuration(episode.duration) : null,
                    'Saved',
                  ].filter(Boolean).join('. ')}
                  accessibilityHint="Double tap to open episode details."
                  accessibilityActions={[
                    { name: 'play',     label: player.episode?.id === item.id && player.isPlaying ? 'Stop' : 'Play' },
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

          // Episode metadata not available — fallback card
          return (
            <SavedItemCard
              key={item.id}
              item={item}
              accentColor="#f97316"
              kindLabel="Episode"
              kindDisplay="Podcast"
              onOpen={() => router.push({ pathname: '/episode/[id]' as any, params: { id: item.id } })}
              onUnsave={() => { saved.unsave(item.id); showToast('Episode unsaved.', 'success'); }}
            />
          );
        }

        // ── Topic ───────────────────────────────────────────────────────
        if (item.kind === 'forumTopic') {
          return (
            <SavedItemCard
              key={item.id}
              item={item}
              accentColor="#6366f1"
              kindLabel="Topic"
              kindDisplay="Forum Topic"
              onOpen={() => router.push({ pathname: '/topic/[id]' as any, params: { id: item.id, title: item.title } })}
              onUnsave={() => { saved.unsave(item.id); showToast('Topic unsaved.', 'success'); }}
            />
          );
        }

        // ── App ─────────────────────────────────────────────────────────
        if (item.kind === 'appListing') {
          return (
            <SavedItemCard
              key={item.id}
              item={item}
              accentColor="#3b82f6"
              kindLabel="App"
              kindDisplay="App Listing"
              onOpen={() => router.push({ pathname: '/app-detail/[id]' as any, params: { id: item.id, name: item.title } })}
              onUnsave={() => { saved.unsave(item.id); showToast('App unsaved.', 'success'); }}
            />
          );
        }

        // ── Guide ────────────────────────────────────────────────────────
        if (item.kind === 'resource') {
          return (
            <SavedItemCard
              key={item.id}
              item={item}
              accentColor="#10b981"
              kindLabel="Guide"
              kindDisplay="Guide"
              onOpen={() => router.push({ pathname: '/resource-detail/[id]' as any, params: { id: item.id } })}
              onUnsave={() => { saved.unsave(item.id); showToast('Guide unsaved.', 'success'); }}
            />
          );
        }

        // ── Blog post ─────────────────────────────────────────────────────
        if (item.kind === 'blogPost') {
          return (
            <SavedItemCard
              key={item.id}
              item={item}
              accentColor="#8b5cf6"
              kindLabel="Blog Post"
              kindDisplay="Blog Post"
              onOpen={() => router.push({ pathname: '/blog-detail/[id]' as any, params: { id: item.id, title: item.title } })}
              onUnsave={() => { saved.unsave(item.id); showToast('Blog post unsaved.', 'success'); }}
            />
          );
        }

        return null;
      })}
    </>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

function FollowingSection() {
  const router              = useRouter();
  const { colors, styles }  = useTheme();
  const { showToast }       = useToast();
  const [items, setItems] = useState<FollowedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);
  const sectionCountRef       = useRef<Text | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const [storedItems, legacyIds] = await Promise.all([
      persistence.getFollowedItems(),
      persistence.getFollowedIds(),
    ]);
    const knownIds = new Set(storedItems.map((item) => item.id));
    const legacyOnlyIds = Array.from(legacyIds).filter((id) => !knownIds.has(id));
    let migratedItems: FollowedItem[] = [];

    if (legacyOnlyIds.length > 0) {
      const result = await cachedApi.forums.topicsById(legacyOnlyIds);
      if (result.ok) {
        migratedItems = result.data.items.map((topic) => ({
          id: topic.id,
          kind: 'forumTopic' as const,
          nodeType: 'node--forum',
          title: topic.title,
          followedAt: new Date().toISOString(),
          lastActivityAt: topic.lastActivityAt,
          url: topic.url,
        }));
        for (const item of migratedItems) await persistence.followItem(item);
      } else {
        setError(result.error);
      }
    }

    setItems([...storedItems, ...migratedItems].sort(
      (a, b) => new Date(b.followedAt).getTime() - new Date(a.followedAt).getTime(),
    ));
    setLoading(false);
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  async function unfollow(item: FollowedItem) {
    await persistence.unfollowItem(item.id);
    setItems((prev) => prev.filter((followed) => followed.id !== item.id));
    const token = await api.account.getSessionToken();
    if (token) await api.follows.unfollow(item.id, token).catch(() => {});
    showToast(`Unfollowed ${kindLabel(item.kind).toLowerCase()}.`, 'success');
    setTimeout(() => {
      const handle = findNodeHandle(sectionCountRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 250);
  }

  if (loading) {
    return (
      <View style={{ alignItems: 'center', paddingVertical: 40 }}>
        <ActivityIndicator size="large" color={colors.appleVisBlue} accessibilityLabel="Loading followed topics" />
      </View>
    );
  }

  return (
    <>
      <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 12 }}>
        <Text
          style={{ flex: 1, fontSize: 13, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8 }}
          accessibilityRole="header"
          accessibilityActions={[{ name: 'summary', label: 'Following summary' }]}
          onAccessibilityAction={() => AccessibilityInfo.announceForAccessibility(
            items.length === 0
              ? 'No followed items.'
              : `${items.length} followed item${items.length !== 1 ? 's' : ''}.`,
          )}
        >
          Followed Items
        </Text>
        <Text
          ref={sectionCountRef}
          style={{ fontSize: 12, color: colors.textSecondary }}
          accessibilityLiveRegion="polite"
          accessible
          accessibilityLabel={`${items.length} followed item${items.length !== 1 ? 's' : ''}`}
        >
          {items.length} item{items.length !== 1 ? 's' : ''}
        </Text>
      </View>

      {error && (
        <View style={[styles.card, { backgroundColor: '#FFF0F0' }]}>
          <Text style={[styles.cardTitle, { color: '#D00' }]}>Could not load followed topics</Text>
          <Text style={styles.cardMeta}>{error}</Text>
          <Pressable
            onPress={load}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Retry loading followed topics"
            style={{ marginTop: 12 }}
          >
            <Text style={{ color: colors.appleVisBlue, fontWeight: '700' }}>Retry</Text>
          </Pressable>
        </View>
      )}

      {!error && items.length === 0 && (
        <EmptyState
          icon="notifications-outline"
          title="Nothing followed yet"
          subtitle="Follow topics, podcast episodes, apps, guides, and blogs to find them here quickly."
          primaryAction={{ label: 'Browse Community', onPress: () => router.push('/forums-browse' as any) }}
        />
      )}

      {items.map((item) => (
        <Pressable
          key={item.id}
          onPress={() => openFollowedItem(router, item)}
          accessible
          accessibilityRole="button"
          accessibilityLabel={[
            item.title,
            kindLabel(item.kind),
            'Following',
          ].filter(Boolean).join('. ')}
          accessibilityHint="Double tap to open. Use actions for more options."
          accessibilityActions={[
            { name: 'open', label: `Open ${kindLabel(item.kind)}` },
            { name: 'unfollow', label: `Unfollow ${kindLabel(item.kind)}` },
          ]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'open') {
              openFollowedItem(router, item);
            }
            if (nativeEvent.actionName === 'unfollow') unfollow(item);
          }}
          style={({ pressed }) => [
            styles.card,
            { marginBottom: 10, borderLeftWidth: 3, borderLeftColor: '#8b5cf6', opacity: pressed ? 0.75 : 1 },
          ]}
        >
          <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 8, marginBottom: 4 }}>
            <Text style={{ flex: 1, fontSize: 16, fontWeight: '600', color: colors.text, lineHeight: 22 }} numberOfLines={2}>
              {item.title}
            </Text>
            <Ionicons name="notifications" size={15} color="#8b5cf6" accessibilityElementsHidden style={{ marginTop: 2 }} />
          </View>
          <Text style={{ fontSize: 11, fontWeight: '700', color: '#8b5cf6',
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4 }}>
            Followed {kindLabel(item.kind)}
          </Text>
          <Text style={{ fontSize: 13, color: colors.textSecondary }}>
            {[
              kindLabel(item.kind),
              item.lastActivityAt ? `Last activity ${relativeTime(item.lastActivityAt)}` : null,
              item.followedAt ? `Followed ${relativeTime(item.followedAt)}` : null,
            ].filter(Boolean).join(' · ')}
          </Text>
          <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>
            <Pressable
              onPress={() => unfollow(item)}
              accessible
              accessibilityRole="button"
              accessibilityLabel={`Unfollow ${kindLabel(item.kind).toLowerCase()}`}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}
            >
              <Ionicons name="notifications-off-outline" size={14} color="#FF3B30" accessibilityElementsHidden />
              <Text style={{ color: '#FF3B30', fontWeight: '600', fontSize: 13 }}>Unfollow</Text>
            </Pressable>
          </View>
        </Pressable>
      ))}
    </>
  );
}

export default function ForYouScreen() {
  const { colors } = useTheme();
  const params = useLocalSearchParams<{ section?: string; savedType?: string }>();
  const [tab, setTab] = useState<ForYouTab>('Queue');
  const [initialSavedFilter, setInitialSavedFilter] = useState<SavedFilter | undefined>(undefined);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const scrollRef = useRef<ScrollView>(null);
  const { showTip } = useTip();
  const skipNextTabAnnounceRef = useRef(false);
  useScrollToTop(scrollRef);

  useFocusEffect(useCallback(() => {
    showTip(TIP_KEYS.tabForYou, TIPS.tabForYou);
    const t = setTimeout(() => scrollRef.current?.flashScrollIndicators(), 350);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []));

  // Deep link from Profile's saved rows (?section=saved&savedType=forumTopic, etc.) —
  // select the Saved section and, if a recognized kind was given, its matching filter.
  useEffect(() => {
    if (params.section !== 'saved') return;
    const mappedFilter = params.savedType ? SAVED_TYPE_TO_FILTER[params.savedType] : undefined;
    skipNextTabAnnounceRef.current = true;
    setTab('Saved');
    setInitialSavedFilter(mappedFilter);
    AccessibilityInfo.announceForAccessibility(
      mappedFilter ? `Saved ${mappedFilter} selected.` : 'Saved items selected.',
    );
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.section, params.savedType]);

  const TAB_ANNOUNCEMENT: Record<ForYouTab, string> = {
    Queue: 'Queue selected.',
    Downloads: 'Downloads selected.',
    Saved: 'Saved items selected.',
    Following: 'Following selected.',
  };

  useEffect(() => {
    if (skipNextTabAnnounceRef.current) {
      skipNextTabAnnounceRef.current = false;
      return;
    }
    AccessibilityInfo.announceForAccessibility(TAB_ANNOUNCEMENT[tab]);
  }, [tab]);

  function handleRefresh() {
    setRefreshing(true);
    setRefreshKey((k) => k + 1);
    setTimeout(() => {
      setRefreshing(false);
      AccessibilityInfo.announceForAccessibility(`${tab} refreshed.`);
    }, 1200);
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
        accessibilityLabel="For You"
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
        {/* Orientation text */}
        <Text
          style={{ fontSize: 13, color: colors.textSecondary, marginBottom: 12, lineHeight: 18 }}
          accessibilityElementsHidden
        >
          Your personal AppleVis hub. Continue listening, manage downloads, revisit saved items, and keep up with content you follow.
        </Text>

        {/* Section switcher */}
        <FilterPicker
          label="Section"
          options={FOR_YOU_TABS}
          value={tab}
          onChange={(v) => setTab(v as ForYouTab)}
        />

        {/* Section accent strip */}
        <View
          style={{ height: 3, borderRadius: 2, backgroundColor: SECTION_ACCENT[tab], marginTop: -4, marginBottom: 12 }}
          accessibilityElementsHidden
        />

        <View key={refreshKey} style={{ marginTop: 0 }}>
          {tab === 'Queue'     && <QueueSection />}
          {tab === 'Downloads' && <DownloadsSection />}
          {/* Only apply the deep-linked filter on first mount — after a manual
              pull-to-refresh remount, fall back to the normal 'All' default
              rather than silently re-snapping back to the linked filter. */}
          {tab === 'Saved'     && <SavedSection initialFilter={refreshKey === 0 ? initialSavedFilter : undefined} />}
          {tab === 'Following' && <FollowingSection />}
        </View>
      </ScrollView>
    </Screen>
  );
}
