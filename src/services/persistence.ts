/**
 * Persistence layer
 *
 * iCloud-synced (via icloudStorage):
 *   saved item IDs, followed topic IDs, read topic IDs, podcast positions,
 *   settings, last visit timestamp (used for "Since Last Visit" filter and
 *   new-episode badge — NOT a scroll position; the feed always opens at top)
 *
 * Device-local only (via AsyncStorage):
 *   downloaded episode file paths (device-specific paths are meaningless on
 *   another device), podcast queue (session data)
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { icloudStorage } from './icloudStorage';
import type { SavedItem, PodcastEpisode, Chapter } from '../types/content';
import type { PlaybackSpeed } from '../hooks/usePodcastPlayer';

export type PlayHistoryEntry = {
  id: string;
  title: string;
  showTitle: string;
  artworkUrl?: string;
  duration: number;
  playedAt: string; // ISO-8601
};

// ── iCloud keys ───────────────────────────────────────────────────────────────
const CK = {
  SAVED_ITEMS:    'applevis:savedItems',
  FOLLOWED_IDS:   'applevis:followedIds',
  READ_IDS:       'applevis:readIds',
  POD_POSITIONS:  'applevis:podcastPositions',
  SETTINGS:       'applevis:settings',
  LAST_VISIT:     'applevis:lastVisit',
};

// ── AsyncStorage keys (device-local) ──────────────────────────────────────────
const LK = {
  DOWNLOADS:     'applevis:downloads',
  EPISODE_META:  'applevis:episodeMeta',
  QUEUE:         'applevis:queue',
  PLAY_HISTORY:  'applevis:playHistory',
  SHOW_SPEEDS:   'applevis:showSpeeds',
  LAST_EPISODE:  'applevis:lastEpisode',
  VOLUME:        'applevis:volume',
  SAVED_META:    'applevis:savedEpisodeMeta',
  TOPIC_SEEN:        'applevis:topicSeen',
  EPISODE_DURATIONS: 'applevis:episodeDurations',
  EPISODE_CHAPTERS:  'applevis:episodeChapters',
  ITEM_VISITS:       'applevis:itemVisits',
};

async function localGet<T>(key: string, fallback: T): Promise<T> {
  try {
    const v = await AsyncStorage.getItem(key);
    return v ? (JSON.parse(v) as T) : fallback;
  } catch { return fallback; }
}

async function localSet<T>(key: string, value: T): Promise<void> {
  try { await AsyncStorage.setItem(key, JSON.stringify(value)); } catch (_e) { /* non-critical */ }
}

export const persistence = {

  // ── Saved items (iCloud) ──────────────────────────────────────────────────

  getSavedItems: () => icloudStorage.getJSON<SavedItem[]>(CK.SAVED_ITEMS, []),

  async saveItem(item: SavedItem): Promise<SavedItem[]> {
    const existing = await persistence.getSavedItems();
    const updated = existing.some((s) => s.id === item.id) ? existing : [item, ...existing];
    await icloudStorage.setJSON(CK.SAVED_ITEMS, updated);
    return updated;
  },

  async unsaveItem(id: string): Promise<SavedItem[]> {
    const existing = await persistence.getSavedItems();
    const updated = existing.filter((s) => s.id !== id);
    await icloudStorage.setJSON(CK.SAVED_ITEMS, updated);
    return updated;
  },

  isSaved: (id: string) => icloudStorage.isInSet(CK.SAVED_ITEMS + ':ids', id),

  // ── Followed topic IDs (iCloud) ───────────────────────────────────────────

  getFollowedIds: () => icloudStorage.getSet(CK.FOLLOWED_IDS),

  followTopic: (id: string) => icloudStorage.addToSet(CK.FOLLOWED_IDS, id),

  unfollowTopic: (id: string) => icloudStorage.removeFromSet(CK.FOLLOWED_IDS, id),

  isFollowing: (id: string) => icloudStorage.isInSet(CK.FOLLOWED_IDS, id),

  // ── Read topic IDs (iCloud) ───────────────────────────────────────────────
  // Any topic the user has opened is considered read.

  getReadIds: () => icloudStorage.getSet(CK.READ_IDS),

  markRead: (id: string) => icloudStorage.addToSet(CK.READ_IDS, id),

  isRead: (id: string) => icloudStorage.isInSet(CK.READ_IDS, id),

  // ── Podcast playback positions (iCloud) ───────────────────────────────────

  getPodcastPositions: () =>
    icloudStorage.getJSON<Record<string, number>>(CK.POD_POSITIONS, {}),

  async savePodcastPosition(episodeId: string, positionSeconds: number): Promise<void> {
    const positions = await persistence.getPodcastPositions();
    await icloudStorage.setJSON(CK.POD_POSITIONS, { ...positions, [episodeId]: positionSeconds });
  },

  async clearPodcastPosition(episodeId: string): Promise<void> {
    const positions = await persistence.getPodcastPositions();
    const { [episodeId]: _, ...rest } = positions;
    await icloudStorage.setJSON(CK.POD_POSITIONS, rest);
  },

  // ── Last visit timestamp (iCloud) ─────────────────────────────────────────
  // Stored as an ISO-8601 string. Used for "Since Last Visit" forum filter.
  // Updated whenever the app goes to background.

  getLastVisit: () => icloudStorage.getString(CK.LAST_VISIT),

  stampVisit(): Promise<void> {
    return icloudStorage.setString(CK.LAST_VISIT, new Date().toISOString());
  },

  // ── Settings (iCloud) ─────────────────────────────────────────────────────

  getSettings: () => icloudStorage.getJSON<Record<string, unknown>>(CK.SETTINGS, {}),

  async getSetting<T>(key: string, fallback: T): Promise<T> {
    const settings = await persistence.getSettings();
    return (key in settings ? settings[key] : fallback) as T;
  },

  async setSetting(key: string, value: unknown): Promise<void> {
    const settings = await persistence.getSettings();
    await icloudStorage.setJSON(CK.SETTINGS, { ...settings, [key]: value });
  },

  // ── Downloaded episodes (device-local) ────────────────────────────────────

  getDownloadedEpisodes: () => localGet<Record<string, string>>(LK.DOWNLOADS, {}),

  async saveDownloadedEpisode(episodeId: string, localUri: string): Promise<void> {
    const downloads = await persistence.getDownloadedEpisodes();
    await localSet(LK.DOWNLOADS, { ...downloads, [episodeId]: localUri });
  },

  async removeDownloadedEpisode(episodeId: string): Promise<void> {
    const downloads = await persistence.getDownloadedEpisodes();
    const { [episodeId]: _, ...rest } = downloads;
    await localSet(LK.DOWNLOADS, rest);
    await persistence.removeDownloadedEpisodeMeta(episodeId);
  },

  // ── Saved episode metadata (device-local) ────────────────────────────────
  // Stores full PodcastEpisode objects so the Saved view can display
  // title, duration, etc. even for episodes no longer in the API feed.

  getSavedEpisodeMeta: () => localGet<Record<string, PodcastEpisode>>(LK.SAVED_META, {}),

  async saveSavedEpisodeMeta(episode: PodcastEpisode): Promise<void> {
    const meta = await persistence.getSavedEpisodeMeta();
    await localSet(LK.SAVED_META, { ...meta, [episode.id]: episode });
  },

  async removeSavedEpisodeMeta(episodeId: string): Promise<void> {
    const meta = await persistence.getSavedEpisodeMeta();
    const { [episodeId]: _, ...rest } = meta;
    await localSet(LK.SAVED_META, rest);
  },

  // ── Downloaded episode metadata (device-local) ───────────────────────────
  // Stores the full PodcastEpisode object so the Downloads view can display
  // title, duration, etc. even for episodes no longer in the API feed.

  getDownloadedEpisodesMeta: () =>
    localGet<Record<string, PodcastEpisode>>(LK.EPISODE_META, {}),

  async saveDownloadedEpisodeMeta(episode: PodcastEpisode): Promise<void> {
    const meta = await persistence.getDownloadedEpisodesMeta();
    await localSet(LK.EPISODE_META, { ...meta, [episode.id]: episode });
  },

  async removeDownloadedEpisodeMeta(episodeId: string): Promise<void> {
    const meta = await persistence.getDownloadedEpisodesMeta();
    const { [episodeId]: _, ...rest } = meta;
    await localSet(LK.EPISODE_META, rest);
  },

  isDownloaded: async (episodeId: string): Promise<boolean> => {
    const downloads = await persistence.getDownloadedEpisodes();
    return episodeId in downloads;
  },

  // ── Podcast queue (device-local) ─────────────────────────────────────────

  getQueue: () => localGet<PodcastEpisode[]>(LK.QUEUE, []),
  setQueue: (queue: PodcastEpisode[]) => localSet(LK.QUEUE, queue),

  // ── Last played episode (device-local) ────────────────────────────────────
  // Restored on launch so the mini-player reappears at the saved position.
  // Cleared when the user explicitly stops/dismisses the player.

  getLastEpisode: () => localGet<PodcastEpisode | null>(LK.LAST_EPISODE, null),
  setLastEpisode: (ep: PodcastEpisode | null) => localSet(LK.LAST_EPISODE, ep),

  // ── In-app volume (device-local) ─────────────────────────────────────────

  getVolume: () => localGet<number>(LK.VOLUME, 1.0),
  setVolume: (v: number) => localSet(LK.VOLUME, v),

  // ── Play history (device-local, capped at 100 entries) ───────────────────
  // Stores the most recent 100 completed episodes, newest first.

  getPlayHistory: () => localGet<PlayHistoryEntry[]>(LK.PLAY_HISTORY, []),

  async addToPlayHistory(episode: PodcastEpisode): Promise<void> {
    const existing = await persistence.getPlayHistory();
    const entry: PlayHistoryEntry = {
      id:         episode.id,
      title:      episode.title,
      showTitle:  episode.showTitle,
      artworkUrl: episode.artworkUrl,
      duration:   episode.duration,
      playedAt:   new Date().toISOString(),
    };
    // Remove any existing entry for the same episode, then prepend and cap at 100.
    const updated = [entry, ...existing.filter(e => e.id !== episode.id)].slice(0, 100);
    await localSet(LK.PLAY_HISTORY, updated);
  },

  async clearPlayHistory(): Promise<void> {
    await localSet(LK.PLAY_HISTORY, []);
  },

  // ── Episode durations (device-local) ─────────────────────────────────────
  // Stores real durations extracted from expo-av, keyed by episode ID.
  // Used to display duration in episode list cards before the episode is played.

  getEpisodeDurations: () => localGet<Record<string, number>>(LK.EPISODE_DURATIONS, {}),

  async saveEpisodeDuration(episodeId: string, seconds: number): Promise<void> {
    const map = await localGet<Record<string, number>>(LK.EPISODE_DURATIONS, {});
    await localSet(LK.EPISODE_DURATIONS, { ...map, [episodeId]: seconds });
  },

  // ── Episode chapters (device-local) ──────────────────────────────────────
  // Stores chapters parsed from MP3 ID3 CHAP frames, keyed by episode ID.
  // null means "not yet parsed"; [] means "parsed but no chapters found".

  async getEpisodeChapters(episodeId: string): Promise<Chapter[] | null> {
    const map = await localGet<Record<string, Chapter[]>>(LK.EPISODE_CHAPTERS, {});
    return episodeId in map ? map[episodeId] : null;
  },

  async saveEpisodeChapters(episodeId: string, chapters: Chapter[]): Promise<void> {
    const map = await localGet<Record<string, Chapter[]>>(LK.EPISODE_CHAPTERS, {});
    await localSet(LK.EPISODE_CHAPTERS, { ...map, [episodeId]: chapters });
  },

  // ── Per-topic last-seen timestamp (device-local) ─────────────────────────
  // Stores the ISO timestamp when the user last opened each forum topic.
  // Used to mark replies added since the last visit as "new".

  async getTopicLastSeen(topicId: string): Promise<string | null> {
    const map = await localGet<Record<string, string>>(LK.TOPIC_SEEN, {});
    return map[topicId] ?? null;
  },

  async stampTopicSeen(topicId: string): Promise<void> {
    const map = await localGet<Record<string, string>>(LK.TOPIC_SEEN, {});
    await localSet(LK.TOPIC_SEEN, { ...map, [topicId]: new Date().toISOString() });
  },

  // ── Per-item visit tracking (all content types) ───────────────────────────
  // Stores last-visited timestamp + comment count for topics, apps, blogs,
  // resources and episode comment pages. Used to:
  //   • Mark comments added since last visit as "new" on detail pages
  //   • Show "X new" comment counts on home tab feed cards

  async getItemVisit(id: string): Promise<{ seenAt: string; commentCount: number } | null> {
    const map = await localGet<Record<string, { seenAt: string; commentCount: number }>>(LK.ITEM_VISITS, {});
    return map[id] ?? null;
  },

  async stampItemVisit(id: string, commentCount: number): Promise<void> {
    const map = await localGet<Record<string, { seenAt: string; commentCount: number }>>(LK.ITEM_VISITS, {});
    await localSet(LK.ITEM_VISITS, { ...map, [id]: { seenAt: new Date().toISOString(), commentCount } });
  },

  async getAllItemVisits(): Promise<Record<string, { seenAt: string; commentCount: number }>> {
    return localGet<Record<string, { seenAt: string; commentCount: number }>>(LK.ITEM_VISITS, {});
  },

  // ── Per-show playback speed (device-local) ────────────────────────────────
  // Records the last-used speed per show title so Apple Podcasts–style per-show
  // speed memory works. Keyed by showTitle; syncing these across devices is not
  // worth the iCloud write-rate cost.

  getShowSpeeds: () => localGet<Record<string, PlaybackSpeed>>(LK.SHOW_SPEEDS, {}),

  async saveShowSpeed(showTitle: string, speed: PlaybackSpeed): Promise<void> {
    const existing = await persistence.getShowSpeeds();
    await localSet(LK.SHOW_SPEEDS, { ...existing, [showTitle]: speed });
  },

  async getShowSpeed(showTitle: string): Promise<PlaybackSpeed | null> {
    const speeds = await persistence.getShowSpeeds();
    return speeds[showTitle] ?? null;
  },
};
