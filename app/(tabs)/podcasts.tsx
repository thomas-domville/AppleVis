import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo, ActionSheetIOS, ActivityIndicator, Animated,
  findNodeHandle, PanResponder, Platform, Pressable,
  RefreshControl, ScrollView, Share, Text, TextInput, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect, useRouter } from 'expo-router';
import { EmptyState } from '../../src/components/EmptyState';
import { Screen } from '../../src/components/Screen';
import { FilterPicker } from '../../src/components/FilterPicker';
import { LoadMoreButton } from '../../src/components/LoadMoreButton';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { usePodcastList } from '../../src/hooks/usePodcastList';
import { useRefreshFeedback } from '../../src/hooks/useRefreshFeedback';
import { useHandoff } from '../../src/hooks/useHandoff';
import { useToast } from '../../src/contexts/ToastContext';
import { usePreferences } from '../../src/contexts/PreferencesContext';
import type { AnnouncementLevel } from '../../src/contexts/PreferencesContext';
import { readAloud, donateSiriActivity } from '../../src/services/intelligenceService';
import { trackMeaningfulAction } from '../../src/services/reviewPrompt';
import { startPodcastLiveActivity, updateCarPlayEpisodes } from '../../src/native/nativeModules';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useEpisodeMeta } from '../../src/hooks/useEpisodeMeta';
import { persistence } from '../../src/services/persistence';
import type { PlayHistoryEntry } from '../../src/services/persistence';
import { deleteAllDownloads } from '../../src/services/downloads';
import type { PodcastEpisode } from '../../src/types/content';

// ─── Filter constants ─────────────────────────────────────────────────────────
const PODCAST_FILTERS = ['Latest', 'In Progress', 'Downloads', 'Saved', 'Queue', 'History'] as const;
type PodcastFilter = typeof PODCAST_FILTERS[number];

// ─── Sort types ───────────────────────────────────────────────────────────────
type SavedSort     = 'newest-saved' | 'oldest-saved' | 'newest-published' | 'oldest-published' | 'title-az' | 'shortest' | 'longest';
type DownloadsSort = 'newest-published' | 'oldest-published' | 'title-az' | 'shortest' | 'longest';

const SAVED_SORT_LABELS: Record<SavedSort, string> = {
  'newest-saved':     'Newest Saved',
  'oldest-saved':     'Oldest Saved',
  'newest-published': 'Newest Published',
  'oldest-published': 'Oldest Published',
  'title-az':         'A–Z',
  'shortest':         'Shortest',
  'longest':          'Longest',
};
const SAVED_SORT_KEYS = Object.keys(SAVED_SORT_LABELS) as SavedSort[];

const DOWNLOADS_SORT_LABELS: Record<DownloadsSort, string> = {
  'newest-published': 'Newest Published',
  'oldest-published': 'Oldest Published',
  'title-az':         'A–Z',
  'shortest':         'Shortest',
  'longest':          'Longest',
};
const DOWNLOADS_SORT_KEYS = Object.keys(DOWNLOADS_SORT_LABELS) as DownloadsSort[];

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

function formatPublishedDate(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return '';
    return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
  } catch { return ''; }
}

function formatRelativeDate(isoStr: string): string {
  try {
    const d = new Date(isoStr);
    const diffMs = Date.now() - d.getTime();
    const diffMin = Math.floor(diffMs / 60_000);
    if (diffMin < 60)  return `${diffMin}m ago`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24)   return `${diffH}h ago`;
    const diffD = Math.floor(diffH / 24);
    if (diffD < 7)    return `${diffD}d ago`;
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  } catch { return ''; }
}

function buildEpisodeLabel(
  episode: PodcastEpisode,
  level: AnnouncementLevel,
  isCurrent: boolean,
  currentPosition: number,
  currentDuration: number,
  savedPositions: Record<string, number>,
  downloaded: Record<string, string>,
  downloading: Set<string>,
  queue: PodcastEpisode[],
  isNew: boolean,
  savedIds: Set<string>,
): string {
  const core: string[] = [];
  if (isNew) core.push('New');
  core.push(episode.title, episode.showTitle);
  const dur = formatDuration(episode.duration);
  if (dur) core.push(dur);

  if (level === 'simple') return core.join('. ');

  if (episode.publishedAt) {
    const date = formatPublishedDate(episode.publishedAt);
    if (date) core.push(`Published ${date}`);
  }

  if (isCurrent && currentDuration > 0 && currentPosition > 30) {
    core.push(`${Math.floor(currentPosition / 60)} of ${Math.floor(currentDuration / 60)} minutes played`);
    core.push('Currently loaded');
  } else {
    const savedPos = savedPositions[episode.id];
    if (savedPos && savedPos > 30 && episode.duration > 0) {
      core.push(`${Math.floor(savedPos / 60)} of ${Math.floor(episode.duration / 60)} minutes played`);
    }
    if (isCurrent) core.push('Currently loaded');
  }

  if (level === 'normal') return core.join('. ');

  const queueIndex = queue.findIndex(q => q.id === episode.id);
  if (queueIndex >= 0) core.push(`In queue, position ${queueIndex + 1}`);
  if (downloading.has(episode.id)) core.push('Downloading');
  else if (episode.id in downloaded) core.push('Downloaded');
  if (savedIds.has(episode.id)) core.push('Saved');
  if (episode.transcriptUrl) core.push('Transcript available');
  if (episode.chapters?.length) {
    const c = episode.chapters.length;
    core.push(`${c} ${c === 1 ? 'chapter' : 'chapters'}`);
  }

  return core.join('. ');
}

// ─── Swipeable episode card ───────────────────────────────────────────────────
function SwipeableEpisodeCard({
  episode, isCurrent, isPlaying, isNew, progress,
  isQueued, isDownloaded, isDownloading, isSaved,
  accessibilityLabel,
  onPress, onPlay, onQueue, onDownload, onSave, onRef,
  colors, styles,
}: {
  episode: PodcastEpisode;
  isCurrent: boolean;
  isPlaying: boolean;
  isNew: boolean;
  progress?: number;
  isQueued: boolean;
  isDownloaded: boolean;
  isDownloading: boolean;
  isSaved: boolean;
  accessibilityLabel: string;
  onPress: () => void;
  onPlay: () => void;
  onQueue: () => void;
  onDownload: () => void;
  onSave: () => void;
  onRef?: (el: View | null) => void;
  colors: ReturnType<typeof useTheme>['colors'];
  styles: ReturnType<typeof useTheme>['styles'];
}) {
  const translateX = useRef(new Animated.Value(0)).current;
  const swipeRef   = useRef(0);
  const THRESHOLD  = 72;

  const panResponder = useRef(PanResponder.create({
    onMoveShouldSetPanResponder: (_, gs) =>
      Math.abs(gs.dx) > 8 && Math.abs(gs.dx) > Math.abs(gs.dy),
    onPanResponderMove: (_, gs) => {
      swipeRef.current = gs.dx;
      // Clamp: right swipe = queue action, left swipe = download action
      const clamped = Math.max(-THRESHOLD * 1.2, Math.min(THRESHOLD * 1.2, gs.dx));
      translateX.setValue(clamped);
    },
    onPanResponderRelease: (_, gs) => {
      const dx = gs.dx;
      Animated.spring(translateX, { toValue: 0, useNativeDriver: true }).start();
      if (dx > THRESHOLD) {
        onQueue();
      } else if (dx < -THRESHOLD) {
        onDownload();
      }
    },
    onPanResponderTerminate: () => {
      Animated.spring(translateX, { toValue: 0, useNativeDriver: true }).start();
    },
  })).current;

  const publishedLabel = episode.publishedAt ? formatPublishedDate(episode.publishedAt) : null;
  const dur = formatDuration(episode.duration);

  return (
    <View style={{ position: 'relative', marginBottom: 0 }}>
      {/* Hint labels behind the card */}
      <View style={{ position: 'absolute', top: 0, bottom: 0, left: 0, right: 0,
        flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
        paddingHorizontal: 20 }} accessibilityElementsHidden>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <Ionicons name={isQueued ? 'remove-circle-outline' : 'add-circle-outline'} size={20} color={colors.accent} />
          <Text style={{ color: colors.accent, fontWeight: '700', fontSize: 13 }}>
            {isQueued ? 'Remove from Queue' : 'Add to Queue'}
          </Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <Text style={{ color: colors.accent, fontWeight: '700', fontSize: 13 }}>
            {isDownloading ? 'Downloading…' : isDownloaded ? 'Delete Download' : 'Download'}
          </Text>
          <Ionicons
            name={isDownloaded ? 'trash-outline' : 'arrow-down-circle-outline'}
            size={20} color={colors.accent} />
        </View>
      </View>

      <Animated.View style={{ transform: [{ translateX }] }} {...panResponder.panHandlers}>
        <Pressable
          onPress={onPress}
          accessible
          accessibilityRole="none"
          accessibilityLabel={accessibilityLabel}
          accessibilityHint={[
            'Double tap to open episode details.',
            isQueued ? 'Swipe right to remove from queue.' : 'Swipe right to add to queue.',
            isDownloading ? 'Download in progress.' : isDownloaded ? 'Swipe left to delete download.' : 'Swipe left to download.',
          ].join(' ')}
          accessibilityActions={[
            { name: 'play',     label: isCurrent && isPlaying ? 'Pause' : 'Play' },
            { name: 'queue',    label: isQueued ? 'Remove from queue' : 'Add to queue' },
            { name: 'download', label: isDownloading ? 'Downloading…' : isDownloaded ? 'Delete download' : 'Download' },
            { name: 'save',     label: isSaved ? 'Unsave' : 'Save' },
          ]}
          onAccessibilityAction={({ nativeEvent }) => {
            if (nativeEvent.actionName === 'play')     onPlay();
            if (nativeEvent.actionName === 'queue')    onQueue();
            if (nativeEvent.actionName === 'download') onDownload();
            if (nativeEvent.actionName === 'save')     onSave();
          }}
          ref={onRef}
          style={[styles.card, isCurrent && { borderColor: colors.accent, borderWidth: 2 }]}
        >
          {/* New badge */}
          {isNew && (
            <View style={{ alignSelf: 'flex-start', backgroundColor: colors.accent,
              borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2, marginBottom: 6 }}
              accessibilityElementsHidden>
              <Text style={{ color: '#FFF', fontSize: 11, fontWeight: '700', letterSpacing: 0.5 }}>NEW</Text>
            </View>
          )}

          <Text style={styles.cardTitle}>{episode.title}</Text>
          <Text style={[styles.cardMeta, { marginBottom: progress !== undefined ? 8 : 10 }]}>
            {episode.showTitle}{dur ? ` · ${dur}` : ''}
            {publishedLabel ? `  ·  ${publishedLabel}` : ''}
          </Text>

          {progress !== undefined && progress > 0 && (
            <View style={{ height: 3, backgroundColor: colors.border, borderRadius: 2, marginBottom: 10 }}>
              <View style={{ height: 3, backgroundColor: colors.accent, borderRadius: 2,
                width: `${Math.round(Math.min(progress, 1) * 100)}%` }} />
            </View>
          )}

          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Pressable
              onPress={onPlay}
              accessible accessibilityRole="button"
              accessibilityLabel={isCurrent && isPlaying ? 'Pause' : 'Play'}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: colors.accent, borderRadius: 8,
                paddingHorizontal: 12, paddingVertical: 8 }}
            >
              <Ionicons name={isCurrent && isPlaying ? 'pause' : 'play'} size={14} color="#FFF" accessibilityElementsHidden />
              <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 13 }}>
                {isCurrent && isPlaying ? 'Pause' : 'Play'}
              </Text>
            </Pressable>
            <Pressable
              onPress={onQueue}
              accessible
              accessibilityRole="button"
              accessibilityLabel={isQueued ? 'Remove from queue' : 'Add to queue'}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: isQueued ? colors.accent + '22' : colors.pill,
                borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}
            >
              <Ionicons
                name={isQueued ? 'remove-circle-outline' : 'add-circle-outline'}
                size={14}
                color={colors.accent}
                accessibilityElementsHidden
              />
              <Text style={{ color: colors.accent, fontWeight: '700', fontSize: 13 }}>
                {isQueued ? 'Remove from Queue' : 'Add to Queue'}
              </Text>
            </Pressable>
            <Pressable
              onPress={onSave}
              accessible
              accessibilityRole="button"
              accessibilityLabel={isSaved ? 'Unsave episode' : 'Save episode'}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                backgroundColor: isSaved ? colors.accent + '22' : colors.pill,
                borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}
            >
              <Ionicons
                name={isSaved ? 'bookmark' : 'bookmark-outline'}
                size={14}
                color={colors.accent}
                accessibilityElementsHidden
              />
              <Text style={{ color: colors.accent, fontWeight: '700', fontSize: 13 }}>
                {isSaved ? 'Unsave' : 'Save'}
              </Text>
            </Pressable>
          </View>
        </Pressable>
      </Animated.View>
    </View>
  );
}


// ─── Main component ───────────────────────────────────────────────────────────
export default function Podcasts() {
  const router                   = useRouter();
  const { colors, styles, isDark } = useTheme();
  const { screenReaderEnabled }  = useAccessibilityPreferences();
  const player                   = usePlayer();
  const list                     = usePodcastList();
  const meta                     = useEpisodeMeta();
  const { showToast }            = useToast();
  const { announcementLevel, podcastAutoDelete } = usePreferences();

  const [filter, setFilter]           = useState<PodcastFilter>('Latest');
  const [searchQuery, setSearchQuery] = useState('');
  const [lastVisit, setLastVisit]     = useState<Date | null>(null);
  const [history, setHistory]         = useState<PlayHistoryEntry[]>([]);
  const [savedSort,     setSavedSort]     = useState<SavedSort>('newest-saved');
  const [downloadsSort, setDownloadsSort] = useState<DownloadsSort>('newest-published');

  const firstEpisodeRef     = useRef<View | null>(null);
  const episodeItemRefs     = useRef<Record<string, View | null>>({});
  const lastTappedEpisodeId = useRef<string | null>(null);
  const lastEpisodeId       = useRef<string | null>(null);

  // ── Load lastVisit + history on mount; run auto-delete ────────────────────
  useEffect(() => {
    persistence.getLastVisit().then(iso => {
      if (iso) setLastVisit(new Date(iso));
    }).catch(() => {});

    persistence.getPlayHistory().then(setHistory).catch(() => {});

    // Auto-delete: remove downloads for completed episodes per user preference.
    if (podcastAutoDelete !== 'off') {
      const cutoffDays = podcastAutoDelete === '1day' ? 1 : 7;
      const cutoff = Date.now() - cutoffDays * 86_400_000;
      persistence.getPlayHistory().then(async (hist) => {
        for (const entry of hist) {
          if (new Date(entry.playedAt).getTime() < cutoff) {
            await meta.removeDownload(entry.id).catch(() => {});
          }
        }
      }).catch(() => {});
    }
  }, [podcastAutoDelete]);

  // ── Load persisted sort preferences from iCloud ──────────────────────────
  useEffect(() => {
    Promise.all([
      persistence.getSetting<SavedSort>('savedSort', 'newest-saved'),
      persistence.getSetting<DownloadsSort>('downloadsSort', 'newest-published'),
    ]).then(([ss, ds]) => {
      setSavedSort(ss);
      setDownloadsSort(ds);
    }).catch(() => {});
  }, []);

  // ── Refresh history when tab comes into focus ─────────────────────────────
  useFocusEffect(useCallback(() => {
    persistence.getPlayHistory().then(setHistory).catch(() => {});

    const id = lastTappedEpisodeId.current;
    if (!id) return;
    const el = episodeItemRefs.current[id];
    if (!el) return;
    const handle = findNodeHandle(el);
    if (handle) setTimeout(() => AccessibilityInfo.setAccessibilityFocus(handle), 400);
  }, []));

  useRefreshFeedback(list.refreshing, 'Podcasts', list.loading, () => firstEpisodeRef.current);

  useHandoff(
    player.episode
      ? { activityType: 'com.applevis.app.playEpisode', title: player.episode.title,
          webpageURL: 'https://www.applevis.com/podcast', userInfo: { episodeId: player.episode.id } }
      : { activityType: 'com.applevis.app.viewPodcasts', title: 'AppleVis Podcasts',
          webpageURL: 'https://www.applevis.com/podcast' },
  );

  useEffect(() => {
    if (!player.episode || player.duration <= 0) return;
    const nearEnd = player.position >= player.duration - 10;
    if (nearEnd && lastEpisodeId.current !== player.episode.id) {
      lastEpisodeId.current = player.episode.id;
      trackMeaningfulAction().catch(() => {});
    }
  }, [player.position, player.duration, player.episode]);

  // ── Derived state ─────────────────────────────────────────────────────────
  const isCurrentEpisode = useCallback((id: string) => player.episode?.id === id, [player.episode]);
  const playerProgress   = player.duration > 0 ? player.position / player.duration : 0;

  // Push feed to CarPlay list template after every load/refresh.
  useEffect(() => {
    if (!list.episodes.length) return;
    updateCarPlayEpisodes(list.episodes.slice(0, 100).map(ep => ({
      id:           ep.id,
      title:        ep.title,
      showTitle:    ep.showTitle,
      duration:     ep.duration,
      isDownloaded: !!meta.downloadedMeta[ep.id],
    })));
  }, [list.episodes, meta.downloadedMeta]);

  // Merged known episodes map (downloaded metadata + live feed)
  const allKnownEpisodes = useMemo<Record<string, PodcastEpisode>>(() => {
    const map: Record<string, PodcastEpisode> = { ...meta.downloadedMeta };
    list.episodes.forEach(ep => { map[ep.id] = ep; });
    return map;
  }, [meta.downloadedMeta, list.episodes]);

  const filteredLatest = useMemo(() => {
    if (!searchQuery.trim()) return list.episodes;
    const q = searchQuery.toLowerCase();
    return list.episodes.filter(ep =>
      ep.title.toLowerCase().includes(q) ||
      ep.showTitle.toLowerCase().includes(q));
  }, [list.episodes, searchQuery]);

  const inProgressEpisodes = useMemo(() =>
    Object.values(allKnownEpisodes).filter(ep => {
      const pos = meta.positions[ep.id] ?? 0;
      if (pos < 30) return false;
      if (ep.duration > 0 && pos >= ep.duration - 30) return false;
      return true;
    }).sort((a, b) => (meta.positions[b.id] ?? 0) - (meta.positions[a.id] ?? 0)),
  [allKnownEpisodes, meta.positions]);

  const downloadedEpisodes = useMemo(() => {
    const episodes = Object.values(allKnownEpisodes).filter(ep => ep.id in meta.downloaded);
    return [...episodes].sort((a, b) => {
      switch (downloadsSort) {
        case 'oldest-published':
          return new Date(a.publishedAt ?? 0).getTime() - new Date(b.publishedAt ?? 0).getTime();
        case 'title-az':
          return a.title.localeCompare(b.title);
        case 'shortest':
          return a.duration - b.duration;
        case 'longest':
          return b.duration - a.duration;
        default: // newest-published
          return new Date(b.publishedAt ?? 0).getTime() - new Date(a.publishedAt ?? 0).getTime();
      }
    });
  }, [allKnownEpisodes, meta.downloaded, downloadsSort]);

  const savedEpisodes = useMemo(() => {
    const seen = new Set<string>();
    const items: PodcastEpisode[] = [];
    Object.values(meta.savedMeta).forEach(ep => {
      if (meta.savedIds.has(ep.id)) { items.push(ep); seen.add(ep.id); }
    });
    list.episodes.forEach(ep => {
      if (meta.savedIds.has(ep.id) && !seen.has(ep.id)) items.push(ep);
    });
    const savedAtMap = new Map(meta.savedItems.map(s => [s.id, s.savedAt]));
    return [...items].sort((a, b) => {
      switch (savedSort) {
        case 'oldest-saved': {
          const aT = new Date(savedAtMap.get(a.id) ?? 0).getTime();
          const bT = new Date(savedAtMap.get(b.id) ?? 0).getTime();
          return aT - bT;
        }
        case 'newest-published':
          return new Date(b.publishedAt ?? 0).getTime() - new Date(a.publishedAt ?? 0).getTime();
        case 'oldest-published':
          return new Date(a.publishedAt ?? 0).getTime() - new Date(b.publishedAt ?? 0).getTime();
        case 'title-az':
          return a.title.localeCompare(b.title);
        case 'shortest':
          return a.duration - b.duration;
        case 'longest':
          return b.duration - a.duration;
        default: { // newest-saved
          const aT = new Date(savedAtMap.get(a.id) ?? 0).getTime();
          const bT = new Date(savedAtMap.get(b.id) ?? 0).getTime();
          return bT - aT;
        }
      }
    });
  }, [meta.savedIds, meta.savedMeta, meta.savedItems, list.episodes, savedSort]);

  // Is an episode "new" (published since last visit)?
  const isNewEpisode = useCallback((ep: PodcastEpisode): boolean => {
    if (!lastVisit || !ep.publishedAt) return false;
    return new Date(ep.publishedAt) > lastVisit;
  }, [lastVisit]);

  // ── Handlers ──────────────────────────────────────────────────────────────
  function navigateToEpisode(episode: PodcastEpisode) {
    lastTappedEpisodeId.current = episode.id;
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

  function playEpisode(episode: PodcastEpisode) {
    if (isCurrentEpisode(episode.id)) {
      player.isPlaying ? player.pause() : player.play();
      return;
    }
    player.loadEpisode(episode, true);
    donateSiriActivity({ type: 'continuePlaying' });
    startPodcastLiveActivity({
      episodeTitle: episode.title,
      showTitle: episode.showTitle,
      episodeId: String(episode.id),
      isPlaying: true,
      position: 0,
      duration: episode.duration,
    });
  }

  function handleDownload(episode: PodcastEpisode) {
    if (meta.downloading.has(episode.id)) {
      showToast('Download already in progress.', 'warning');
    } else if (episode.id in meta.downloaded) {
      meta.removeDownload(episode.id);
      showToast('Download removed.', 'success');
    } else {
      showToast('Downloading…', 'success');
      meta.startDownload(episode).then(result => {
        if (!result.ok) showToast('Download failed.', 'error');
        else showToast('Download complete.', 'success');
      });
    }
  }

  function handleSave(episode: PodcastEpisode) {
    if (meta.savedIds.has(episode.id)) {
      meta.unsaveEpisode(episode.id);
      showToast('Episode unsaved.', 'success');
    } else {
      meta.saveEpisode(episode);
      showToast('Episode saved.', 'success');
    }
  }

  function handleShare(episode: PodcastEpisode) {
    Share.share({
      title: episode.title,
      message: `${episode.title} — ${episode.showTitle}\n\nhttps://www.applevis.com/podcast`,
    }).catch(() => {});
  }

  function handleMarkPlayed(episode: PodcastEpisode) {
    const pos = episode.duration > 0 ? episode.duration : 9999;
    persistence.addToPlayHistory(episode)
      .then(() => persistence.savePodcastPosition(episode.id, pos))
      .then(() => meta.reload())
      .then(() => persistence.getPlayHistory())
      .then(setHistory)
      .catch(() => {});
    showToast('Marked as played.', 'success');
  }

  function showSavedSortSheet() {
    if (Platform.OS !== 'ios') return;
    const labels = SAVED_SORT_KEYS.map(k => k === savedSort ? `✓ ${SAVED_SORT_LABELS[k]}` : SAVED_SORT_LABELS[k]);
    ActionSheetIOS.showActionSheetWithOptions(
      { title: 'Sort Saved Episodes', options: [...labels, 'Cancel'], cancelButtonIndex: SAVED_SORT_KEYS.length, userInterfaceStyle: isDark ? 'dark' : 'light' },
      (index) => {
        if (index < SAVED_SORT_KEYS.length) {
          const next = SAVED_SORT_KEYS[index];
          setSavedSort(next);
          persistence.setSetting('savedSort', next).catch(() => {});
        }
      },
    );
  }

  function showDownloadsSortSheet() {
    if (Platform.OS !== 'ios') return;
    const labels = DOWNLOADS_SORT_KEYS.map(k => k === downloadsSort ? `✓ ${DOWNLOADS_SORT_LABELS[k]}` : DOWNLOADS_SORT_LABELS[k]);
    ActionSheetIOS.showActionSheetWithOptions(
      { title: 'Sort Downloads', options: [...labels, 'Cancel'], cancelButtonIndex: DOWNLOADS_SORT_KEYS.length, userInterfaceStyle: isDark ? 'dark' : 'light' },
      (index) => {
        if (index < DOWNLOADS_SORT_KEYS.length) {
          const next = DOWNLOADS_SORT_KEYS[index];
          setDownloadsSort(next);
          persistence.setSetting('downloadsSort', next).catch(() => {});
        }
      },
    );
  }

  function episodeLabel(episode: PodcastEpisode) {
    const isCurrent = isCurrentEpisode(episode.id);
    return buildEpisodeLabel(
      episode, announcementLevel, isCurrent,
      isCurrent ? player.position : 0,
      isCurrent ? player.duration : 0,
      meta.positions, meta.downloaded, meta.downloading, player.queue,
      isNewEpisode(episode), meta.savedIds,
    );
  }


  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Screen title="Podcasts" showBack={false}>
      <ScrollView
        refreshControl={
          <RefreshControl refreshing={list.refreshing} onRefresh={list.refresh}
            accessibilityLabel="Refreshing podcasts" />
        }
        contentContainerStyle={{ padding: 16, paddingBottom: 40 }}
        accessibilityLabel="Podcasts"
      >
{/* ── Now Playing mini-card ─────────────────────────────────────── */}
        {player.episode && (
          <Pressable
            onPress={() => navigateToEpisode(player.episode!)}
            accessible
            accessibilityRole="none"
            accessibilityLabel={[
              'Now playing',
              player.episode.title,
              player.episode.showTitle,
              player.duration > 0
                ? `${formatTime(player.position)} of ${formatTime(player.duration)}`
                : null,
              player.isPlaying ? 'Playing' : 'Paused',
              player.queue.length > 0
                ? `${player.queue.length} episode${player.queue.length === 1 ? '' : 's'} queued`
                : null,
            ].filter(Boolean).join('. ')}
            accessibilityHint="Double tap to open full player"
            style={[styles.card, { borderColor: colors.accent, borderWidth: 2 }]}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <Ionicons name="musical-notes" size={14} color={colors.accent} accessibilityElementsHidden />
              <Text style={{ fontSize: 11, fontWeight: '700', color: colors.accent,
                textTransform: 'uppercase', letterSpacing: 0.5 }}>Now Playing</Text>
              {player.queue.length > 0 && (
                <Text style={{ fontSize: 11, color: colors.textSecondary, marginLeft: 'auto' }}>
                  +{player.queue.length} queued
                </Text>
              )}
            </View>
            <Text style={styles.cardTitle} numberOfLines={2}>{player.episode.title}</Text>
            <Text style={styles.cardMeta}>{player.episode.showTitle}</Text>

            {player.duration > 0 && (
              <View style={{ height: 3, backgroundColor: colors.border, borderRadius: 2, marginTop: 6, marginBottom: 4 }}>
                <View style={{ height: 3, backgroundColor: colors.accent, borderRadius: 2,
                  width: `${Math.round(playerProgress * 100)}%` }} />
              </View>
            )}

            <View style={{ flexDirection: 'row', alignItems: 'center',
              justifyContent: 'space-between', marginTop: 4 }}>
              <Text style={{ fontSize: 12, color: colors.textSecondary }}>
                {player.duration > 0
                  ? `${formatTime(player.position)} / ${formatTime(player.duration)}`
                  : player.isBuffering ? 'Buffering…' : ''}
              </Text>
              <View style={{ flexDirection: 'row', gap: 16, alignItems: 'center' }}>
                <Pressable onPress={() => player.skipBack()} accessible accessibilityRole="button"
                  accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds`} hitSlop={8}>
                  <Ionicons name="play-back" size={22} color={colors.text} />
                </Pressable>
                <Pressable onPress={player.isPlaying ? player.pause : player.play}
                  accessible accessibilityRole="button"
                  accessibilityLabel={player.isPlaying ? 'Pause' : 'Play'} hitSlop={8}>
                  <Ionicons name={player.isPlaying ? 'pause-circle' : 'play-circle'}
                    size={36} color={colors.accent} />
                </Pressable>
                <Pressable onPress={() => player.skipForward()} accessible accessibilityRole="button"
                  accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`} hitSlop={8}>
                  <Ionicons name="play-forward" size={22} color={colors.text} />
                </Pressable>
              </View>
            </View>
          </Pressable>
        )}

        {/* ── Search bar ───────────────────────────────────────────────── */}
        <View style={{ flexDirection: 'row', alignItems: 'center',
          backgroundColor: colors.inputBackground, borderRadius: 10, borderWidth: 1,
          borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 10 }}>
          <Ionicons name="search" size={16} color={colors.textSecondary} style={{ marginRight: 6 }}
            accessibilityElementsHidden />
          <TextInput
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholder="Search episodes…"
            placeholderTextColor={colors.textSecondary}
            style={{ flex: 1, fontSize: 15, color: colors.text }}
            accessible
            accessibilityLabel="Search episodes"
            accessibilityHint="Type to filter episodes by title or show name"
            returnKeyType="search"
            clearButtonMode="while-editing"
          />
        </View>

        {/* ── View filter picker ────────────────────────────────────────── */}
        <FilterPicker
          label="View"
          options={PODCAST_FILTERS}
          value={filter}
          onChange={setFilter}
        />

        {/* ── Latest ───────────────────────────────────────────────────── */}
        {filter === 'Latest' && (
          <>
            {list.loading && !list.refreshing && (
              <ActivityIndicator size="large" color={colors.accent}
                accessibilityLabel="Loading podcasts" style={{ marginVertical: 24 }} />
            )}

            {!list.loading && list.error && (
              <View style={[styles.card, { alignItems: 'center', paddingVertical: 24 }]}>
                <Text style={{ color: '#FF3B30', textAlign: 'center', marginBottom: 12 }}>{list.error}</Text>
                <Pressable onPress={list.refresh} accessible accessibilityRole="button"
                  accessibilityLabel="Retry loading podcasts"
                  style={{ backgroundColor: colors.accent, borderRadius: 8,
                    paddingHorizontal: 20, paddingVertical: 10 }}>
                  <Text style={{ color: '#FFF', fontWeight: '700' }}>Retry</Text>
                </Pressable>
              </View>
            )}

            {filteredLatest.length === 0 && !list.loading && !list.error && searchQuery.trim() && (
              <EmptyState icon="search-outline" title="No results"
                subtitle={`No episodes match "${searchQuery}". Try a different search.`}
                />
            )}

            {filteredLatest.map((episode, index) => {
              const isCurrent   = isCurrentEpisode(episode.id);
              const epProgress  = isCurrent && player.duration > 0
                ? player.position / player.duration : undefined;
              const epIsQueued  = player.queue.some(q => q.id === episode.id);
              return (
                <SwipeableEpisodeCard
                  key={episode.id}
                  episode={episode}
                  isCurrent={isCurrent}
                  isPlaying={isCurrent && player.isPlaying}
                  isNew={isNewEpisode(episode)}
                  progress={epProgress}
                  isQueued={epIsQueued}
                  isDownloaded={episode.id in meta.downloaded}
                  isDownloading={meta.downloading.has(episode.id)}
                  isSaved={meta.savedIds.has(episode.id)}
                  accessibilityLabel={episodeLabel(episode)}
                  onPress={() => navigateToEpisode(episode)}
                  onPlay={() => playEpisode(episode)}
                  onQueue={() => {
                    if (epIsQueued) {
                      player.removeFromQueue(episode.id);
                      showToast('Removed from queue.', 'success');
                    } else {
                      player.enqueue(episode);
                      showToast('Added to queue.', 'success');
                    }
                  }}
                  onDownload={() => handleDownload(episode)}
                  onSave={() => handleSave(episode)}
                  onRef={el => {
                    episodeItemRefs.current[episode.id] = el;
                    if (index === 0) firstEpisodeRef.current = el;
                  }}
                  colors={colors}
                  styles={styles}
                />
              );
            })}

            <LoadMoreButton
              hasMore={list.hasMore}
              isLoadingMore={list.isLoadingMore}
              onPress={list.loadMore}
            />
          </>
        )}

        {/* ── In Progress ──────────────────────────────────────────────── */}
        {filter === 'In Progress' && (
          inProgressEpisodes.length === 0
            ? <EmptyState icon="time-outline" title="No episodes in progress"
                subtitle="Episodes you've started will appear here." />
            : inProgressEpisodes.map(episode => {
                const isCurrent = isCurrentEpisode(episode.id);
                const pos       = isCurrent ? player.position : (meta.positions[episode.id] ?? 0);
                const dur       = isCurrent && player.duration > 0 ? player.duration : episode.duration;
                const prog      = dur > 0 ? pos / dur : 0;
                return (
                  <SwipeableEpisodeCard
                    key={episode.id}
                    episode={episode}
                    isCurrent={isCurrent}
                    isPlaying={isCurrent && player.isPlaying}
                    isNew={false}
                    progress={prog}
                    isQueued={player.queue.some(q => q.id === episode.id)}
                    isDownloaded={episode.id in meta.downloaded}
                    isDownloading={meta.downloading.has(episode.id)}
                    isSaved={meta.savedIds.has(episode.id)}
                    accessibilityLabel={episodeLabel(episode)}
                    onPress={() => navigateToEpisode(episode)}
                    onPlay={() => playEpisode(episode)}
                    onQueue={() => {
                      const queued = player.queue.some(q => q.id === episode.id);
                      if (queued) {
                        player.removeFromQueue(episode.id);
                        showToast('Removed from queue.', 'success');
                      } else {
                        player.enqueue(episode);
                        showToast('Added to queue.', 'success');
                      }
                    }}
                    onDownload={() => handleDownload(episode)}
                    onSave={() => handleSave(episode)}
                    colors={colors}
                    styles={styles}
                  />
                );
              })
        )}

        {/* ── Downloads ────────────────────────────────────────────────── */}
        {filter === 'Downloads' && (
          downloadedEpisodes.length === 0
            ? <EmptyState icon="cloud-download-outline" title="No downloaded episodes"
                subtitle="Download episodes to listen offline." />
            : <>
                {/* Toolbar */}
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 }}>
                  <Pressable
                    onPress={showDownloadsSortSheet}
                    accessible accessibilityRole="button"
                    accessibilityLabel={`Sort: ${DOWNLOADS_SORT_LABELS[downloadsSort]}. Activate to change sort order.`}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Ionicons name="funnel-outline" size={13} color={colors.accent} accessibilityElementsHidden />
                    <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }}>{DOWNLOADS_SORT_LABELS[downloadsSort]}</Text>
                    <Ionicons name="chevron-down" size={12} color={colors.accent} accessibilityElementsHidden />
                  </Pressable>
                  <View style={{ flex: 1 }} accessibilityElementsHidden />
                  <Pressable
                    onPress={async () => { await deleteAllDownloads(); meta.reload(); showToast('All downloads removed.', 'success'); }}
                    accessible accessibilityRole="button" accessibilityLabel="Remove all downloads"
                    style={{ paddingHorizontal: 10, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Remove All</Text>
                  </Pressable>
                </View>

                {downloadedEpisodes.map(episode => {
                  const isCurrent = isCurrentEpisode(episode.id);
                  const isQueued  = player.queue.some(q => q.id === episode.id);
                  const isSaved   = meta.savedIds.has(episode.id);
                  return (
                    <View key={episode.id} style={styles.card}>
                      <Pressable
                        onPress={() => navigateToEpisode(episode)}
                        accessible accessibilityRole="none"
                        accessibilityLabel={[episodeLabel(episode), 'Downloaded'].join('. ')}
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
                            case 'queue':  isQueued ? (player.removeFromQueue(episode.id), showToast('Removed from queue.', 'success')) : (player.enqueue(episode), showToast('Added to queue.', 'success')); break;
                            case 'save':   handleSave(episode); break;
                            case 'remove': meta.removeDownload(episode.id); showToast('Download removed.', 'success'); break;
                          }
                        }}
                      >
                        <Text style={styles.cardTitle}>{episode.title}</Text>
                        <Text style={[styles.cardMeta, { marginBottom: 10 }]}>
                          {episode.showTitle}
                          {episode.duration > 0 ? ` · ${formatDuration(episode.duration)}` : ''}
                          {episode.publishedAt ? `  ·  ${formatPublishedDate(episode.publishedAt)}` : ''}
                        </Text>
                      </Pressable>
                      <View style={{ flexDirection: 'row', gap: 8, marginTop: 2 }}>
                        <Pressable onPress={() => playEpisode(episode)}
                          accessible accessibilityRole="button"
                          accessibilityLabel={isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: colors.accent, borderRadius: 8,
                            paddingHorizontal: 14, paddingVertical: 8, flex: 1 }}>
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
                        <Pressable onPress={() => handleSave(episode)}
                          accessible accessibilityRole="button"
                          accessibilityLabel={isSaved ? 'Unsave episode' : 'Save episode'}
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: isSaved ? colors.accent + '22' : colors.pill,
                            borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                          <Ionicons name={isSaved ? 'bookmark' : 'bookmark-outline'} size={14} color={colors.accent} accessibilityElementsHidden />
                          <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 13 }}>
                            {isSaved ? 'Saved' : 'Save'}
                          </Text>
                        </Pressable>
                        <Pressable onPress={() => { meta.removeDownload(episode.id); showToast('Download removed.', 'success'); }}
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
        )}

        {/* ── Saved ────────────────────────────────────────────────────── */}
        {filter === 'Saved' && (
          savedEpisodes.length === 0
            ? <EmptyState icon="bookmark-outline" title="No saved episodes"
                subtitle="Bookmark episodes you want to come back to. Tap Save on any episode card or in the episode detail screen."
                />
            : <>
                {/* Toolbar */}
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
                  <Pressable
                    onPress={showSavedSortSheet}
                    accessible accessibilityRole="button"
                    accessibilityLabel={`Sort: ${SAVED_SORT_LABELS[savedSort]}. Activate to change sort order.`}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 4,
                      backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Ionicons name="funnel-outline" size={13} color={colors.accent} accessibilityElementsHidden />
                    <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }}>{SAVED_SORT_LABELS[savedSort]}</Text>
                    <Ionicons name="chevron-down" size={12} color={colors.accent} accessibilityElementsHidden />
                  </Pressable>
                  <View style={{ flex: 1 }} accessibilityElementsHidden />
                  <Pressable
                    onPress={() => {
                      const toAdd = savedEpisodes.filter(ep => !player.queue.some(q => q.id === ep.id));
                      toAdd.forEach(ep => player.enqueue(ep));
                      showToast(toAdd.length > 0 ? `Added ${toAdd.length} episode${toAdd.length === 1 ? '' : 's'} to queue.` : 'All already in queue.', 'success');
                    }}
                    accessible accessibilityRole="button" accessibilityLabel="Queue all saved episodes"
                    style={{ paddingHorizontal: 10, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }}>Queue All</Text>
                  </Pressable>
                  <Pressable
                    onPress={() => {
                      const toDownload = savedEpisodes.filter(ep => !(ep.id in meta.downloaded) && !meta.downloading.has(ep.id));
                      toDownload.forEach(ep => meta.startDownload(ep).catch(() => {}));
                      showToast(toDownload.length > 0 ? `Downloading ${toDownload.length} episode${toDownload.length === 1 ? '' : 's'}.` : 'All already downloaded.', 'success');
                    }}
                    accessible accessibilityRole="button" accessibilityLabel="Download all saved episodes"
                    style={{ paddingHorizontal: 10, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: colors.accent, fontWeight: '600' }}>Download All</Text>
                  </Pressable>
                  <Pressable
                    onPress={async () => {
                      for (const ep of savedEpisodes) await meta.unsaveEpisode(ep.id).catch(() => {});
                      showToast('All saved episodes removed.', 'success');
                    }}
                    accessible accessibilityRole="button" accessibilityLabel="Unsave all saved episodes"
                    style={{ paddingHorizontal: 10, paddingVertical: 6, backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Unsave All</Text>
                  </Pressable>
                </View>

                {savedEpisodes.map(episode => {
                  const isCurrent    = isCurrentEpisode(episode.id);
                  const isQueued     = player.queue.some(q => q.id === episode.id);
                  const isDownloaded = episode.id in meta.downloaded;
                  const isDownloading = meta.downloading.has(episode.id);
                  return (
                    <View key={episode.id} style={styles.card}>
                      <Pressable
                        onPress={() => navigateToEpisode(episode)}
                        accessible accessibilityRole="none"
                        accessibilityLabel={[episodeLabel(episode), 'Saved'].join('. ')}
                        accessibilityHint="Double tap to open episode details."
                        accessibilityActions={[
                          { name: 'play',       label: isCurrent && player.isPlaying ? 'Pause' : 'Play' },
                          { name: 'queue',      label: isQueued ? 'Remove from queue' : 'Add to queue' },
                          { name: 'download',   label: isDownloading ? 'Downloading…' : isDownloaded ? 'Delete download' : 'Download' },
                          { name: 'share',      label: 'Share episode' },
                          { name: 'markPlayed', label: 'Mark as played' },
                          { name: 'unsave',     label: 'Unsave episode' },
                        ]}
                        onAccessibilityAction={({ nativeEvent }) => {
                          switch (nativeEvent.actionName) {
                            case 'play':       playEpisode(episode); break;
                            case 'queue':      isQueued ? (player.removeFromQueue(episode.id), showToast('Removed from queue.', 'success')) : (player.enqueue(episode), showToast('Added to queue.', 'success')); break;
                            case 'download':   handleDownload(episode); break;
                            case 'share':      handleShare(episode); break;
                            case 'markPlayed': handleMarkPlayed(episode); break;
                            case 'unsave':     meta.unsaveEpisode(episode.id).then(() => showToast('Episode unsaved.', 'success')); break;
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
                          {episode.publishedAt ? `  ·  ${formatPublishedDate(episode.publishedAt)}` : ''}
                        </Text>
                      </Pressable>

                      {/* Row 1: Play · Queue · Unsave */}
                      <View style={{ flexDirection: 'row', gap: 8, marginTop: 2, marginBottom: 8 }}>
                        <Pressable onPress={() => playEpisode(episode)}
                          accessible accessibilityRole="button"
                          accessibilityLabel={isCurrent && player.isPlaying ? 'Pause' : 'Play'}
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: colors.accent, borderRadius: 8,
                            paddingHorizontal: 14, paddingVertical: 8, flex: 1 }}>
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
                        <Pressable onPress={() => meta.unsaveEpisode(episode.id).then(() => showToast('Episode unsaved.', 'success'))}
                          accessible accessibilityRole="button" accessibilityLabel="Unsave episode"
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                          <Ionicons name="bookmark-outline" size={14} color="#FF3B30" accessibilityElementsHidden />
                          <Text style={{ color: '#FF3B30', fontWeight: '600', fontSize: 13 }}>Unsave</Text>
                        </Pressable>
                      </View>

                      {/* Row 2: Download · Share · Mark Played */}
                      <View style={{ flexDirection: 'row', gap: 8 }}>
                        <Pressable onPress={() => handleDownload(episode)}
                          accessible accessibilityRole="button"
                          accessibilityLabel={isDownloading ? 'Downloading' : isDownloaded ? 'Remove download' : 'Download'}
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                          <Ionicons
                            name={isDownloading ? 'cloud-download-outline' : isDownloaded ? 'trash-outline' : 'arrow-down-circle-outline'}
                            size={14} color={isDownloaded ? '#FF3B30' : colors.accent} accessibilityElementsHidden />
                          <Text style={{ color: isDownloaded ? '#FF3B30' : colors.accent, fontWeight: '600', fontSize: 13 }}>
                            {isDownloading ? 'Downloading…' : isDownloaded ? 'Remove' : 'Download'}
                          </Text>
                        </Pressable>
                        <Pressable onPress={() => handleShare(episode)}
                          accessible accessibilityRole="button" accessibilityLabel="Share episode"
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                          <Ionicons name="share-outline" size={14} color={colors.accent} accessibilityElementsHidden />
                          <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 13 }}>Share</Text>
                        </Pressable>
                        <Pressable onPress={() => handleMarkPlayed(episode)}
                          accessible accessibilityRole="button" accessibilityLabel="Mark as played"
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 5,
                            backgroundColor: colors.pill, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 }}>
                          <Ionicons name="checkmark-circle-outline" size={14} color={colors.accent} accessibilityElementsHidden />
                          <Text style={{ color: colors.accent, fontWeight: '600', fontSize: 13 }}>Mark Played</Text>
                        </Pressable>
                      </View>
                    </View>
                  );
                })}
              </>
        )}

        {/* ── Queue ────────────────────────────────────────────────────── */}
        {filter === 'Queue' && (
          player.queue.length === 0
            ? <EmptyState icon="list-outline" title="Your queue is empty"
                subtitle="Add episodes to your queue from the list or episode details."
                />
            : <>
                <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 12 }}>
                  <Pressable onPress={() => { player.clearQueue(); showToast('Queue cleared.', 'success'); }}
                    accessible accessibilityRole="button" accessibilityLabel="Clear queue"
                    style={{ paddingHorizontal: 12, paddingVertical: 6,
                      backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Clear Queue</Text>
                  </Pressable>
                </View>

                {player.queue.map((episode, index) => {
                  const isCurrent  = isCurrentEpisode(episode.id);
                  const isFirst    = index === 0;
                  const isLast     = index === player.queue.length - 1;
                  const queueTotal = player.queue.length;
                  return (
                    <Pressable
                      key={episode.id}
                      onPress={() => navigateToEpisode(episode)}
                      accessible
                      accessibilityRole="none"
                      accessibilityLabel={[
                        `Queue position ${index + 1} of ${queueTotal}`,
                        episode.title,
                        episode.showTitle,
                        formatDuration(episode.duration),
                        isCurrent ? 'Currently loaded' : null,
                      ].filter(Boolean).join('. ')}
                      accessibilityHint="Double tap to open episode details."
                      accessibilityActions={[
                        { name: 'play',     label: isCurrent && player.isPlaying ? 'Pause' : 'Play now' },
                        ...(!isFirst  ? [{ name: 'moveUp',   label: 'Move up in queue' }]   : []),
                        ...(!isLast   ? [{ name: 'moveDown', label: 'Move down in queue' }] : []),
                        { name: 'remove',   label: 'Remove from queue' },
                      ]}
                      onAccessibilityAction={({ nativeEvent }) => {
                        switch (nativeEvent.actionName) {
                          case 'play':
                            playEpisode(episode);
                            navigateToEpisode(episode);
                            break;
                          case 'moveUp':
                            player.moveQueueItemUp(episode.id);
                            AccessibilityInfo.announceForAccessibility(
                              `Moved to position ${index} of ${queueTotal}.`);
                            break;
                          case 'moveDown':
                            player.moveQueueItemDown(episode.id);
                            AccessibilityInfo.announceForAccessibility(
                              `Moved to position ${index + 2} of ${queueTotal}.`);
                            break;
                          case 'remove':
                            player.removeFromQueue(episode.id);
                            showToast('Removed from queue.', 'success');
                            break;
                        }
                      }}
                      style={[styles.card, isCurrent && { borderColor: colors.accent, borderWidth: 2 }]}
                    >
                      {/* Visual layout — sighted users; hidden from VoiceOver by the accessible parent */}
                      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}
                        accessibilityElementsHidden>
                        <Text style={{ fontSize: 18, fontWeight: '700', color: colors.textSecondary,
                          minWidth: 28, paddingTop: 2 }}>{index + 1}</Text>
                        <View style={{ flex: 1 }}>
                          <Text style={styles.cardTitle}>{episode.title}</Text>
                          <Text style={styles.cardMeta}>
                            {episode.showTitle}
                            {episode.duration > 0 ? ` · ${formatDuration(episode.duration)}` : ''}
                          </Text>
                        </View>
                      </View>

                      <View style={{ flexDirection: 'row', gap: 8, marginTop: 12 }}
                        accessibilityElementsHidden>
                        <Pressable onPress={() => { playEpisode(episode); navigateToEpisode(episode); }}
                          accessible={false}
                          style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
                            backgroundColor: colors.accent, borderRadius: 8,
                            paddingHorizontal: 12, paddingVertical: 8, flex: 1 }}>
                          <Ionicons name={isCurrent && player.isPlaying ? 'pause' : 'play'} size={15} color="#FFF" />
                          <Text style={{ color: '#FFF', fontWeight: '700', fontSize: 13 }}>
                            {isCurrent && player.isPlaying ? 'Pause' : 'Play Now'}
                          </Text>
                        </Pressable>
                        <Pressable onPress={() => player.moveQueueItemUp(episode.id)}
                          accessible={false}
                          disabled={isFirst}
                          style={{ backgroundColor: colors.pill, borderRadius: 8,
                            paddingHorizontal: 12, paddingVertical: 8, opacity: isFirst ? 0.4 : 1 }}>
                          <Ionicons name="chevron-up" size={18} color={colors.text} />
                        </Pressable>
                        <Pressable onPress={() => player.moveQueueItemDown(episode.id)}
                          accessible={false}
                          disabled={isLast}
                          style={{ backgroundColor: colors.pill, borderRadius: 8,
                            paddingHorizontal: 12, paddingVertical: 8, opacity: isLast ? 0.4 : 1 }}>
                          <Ionicons name="chevron-down" size={18} color={colors.text} />
                        </Pressable>
                        <Pressable onPress={() => { player.removeFromQueue(episode.id);
                            showToast('Removed from queue.', 'success'); }}
                          accessible={false}
                          style={{ backgroundColor: colors.pill, borderRadius: 8,
                            paddingHorizontal: 12, paddingVertical: 8 }}>
                          <Ionicons name="close" size={18} color="#FF3B30" />
                        </Pressable>
                      </View>
                    </Pressable>
                  );
                })}
              </>
        )}

        {/* ── History ──────────────────────────────────────────────────── */}
        {filter === 'History' && (
          history.length === 0
            ? <EmptyState icon="time-outline" title="No play history"
                subtitle="Episodes you finish will appear here."
                />
            : <>
                <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginBottom: 12 }}>
                  <Pressable
                    onPress={async () => {
                      await persistence.clearPlayHistory();
                      setHistory([]);
                      showToast('History cleared.', 'success');
                    }}
                    accessible accessibilityRole="button" accessibilityLabel="Clear play history"
                    style={{ paddingHorizontal: 12, paddingVertical: 6,
                      backgroundColor: colors.pill, borderRadius: 8 }}>
                    <Text style={{ fontSize: 13, color: '#FF3B30', fontWeight: '600' }}>Clear History</Text>
                  </Pressable>
                </View>

                {history.map(entry => {
                  const episodeInFeed = allKnownEpisodes[entry.id];
                  return (
                    <Pressable
                      key={`${entry.id}-${entry.playedAt}`}
                      onPress={() => {
                        if (episodeInFeed) {
                          navigateToEpisode(episodeInFeed);
                        } else {
                          showToast('Episode no longer in feed.', 'warning');
                        }
                      }}
                      accessible accessibilityRole="none"
                      accessibilityLabel={[
                        entry.title, entry.showTitle,
                        formatDuration(entry.duration),
                        `Played ${formatRelativeDate(entry.playedAt)}`,
                      ].join('. ')}
                      accessibilityHint={episodeInFeed ? 'Double tap to open episode' : 'Episode no longer available'}
                      style={styles.card}
                    >
                      <View style={{ flexDirection: 'row', alignItems: 'flex-start',
                        justifyContent: 'space-between' }}>
                        <View style={{ flex: 1, marginRight: 8 }}>
                          <Text style={styles.cardTitle}>{entry.title}</Text>
                          <Text style={styles.cardMeta}>
                            {entry.showTitle}
                            {entry.duration > 0 ? ` · ${formatDuration(entry.duration)}` : ''}
                          </Text>
                        </View>
                        <View style={{ alignItems: 'flex-end' }}>
                          <Ionicons name="checkmark-circle" size={18} color={colors.accent}
                            accessibilityElementsHidden />
                          <Text style={{ fontSize: 12, color: colors.textSecondary, marginTop: 4 }}>
                            {formatRelativeDate(entry.playedAt)}
                          </Text>
                        </View>
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
