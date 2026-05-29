import AsyncStorage from '@react-native-async-storage/async-storage';
import type { SavedItem, ListResumeState } from '../types/content';

const K = {
  SAVED_ITEMS: 'applevis:savedItems',
  PODCAST_POSITIONS: 'applevis:podcastPositions',
  LIST_POSITIONS: 'applevis:listPositions',
  FORUM_FILTER: 'applevis:forumFilter',
  SETTINGS: 'applevis:settings',
  LAST_VISIT: 'applevis:lastVisit',
  DOWNLOADED_EPISODES: 'applevis:downloadedEpisodes',
  QUEUE: 'applevis:queue',
};

async function get<T>(key: string, fallback: T): Promise<T> {
  try {
    const raw = await AsyncStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

async function set<T>(key: string, value: T): Promise<void> {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage failure is non-fatal
  }
}

export const persistence = {
  // Saved items
  getSavedItems: () => get<SavedItem[]>(K.SAVED_ITEMS, []),

  async saveItem(item: SavedItem): Promise<SavedItem[]> {
    const existing = await persistence.getSavedItems();
    const updated = existing.some((s) => s.id === item.id) ? existing : [item, ...existing];
    await set(K.SAVED_ITEMS, updated);
    return updated;
  },

  async unsaveItem(id: string): Promise<SavedItem[]> {
    const existing = await persistence.getSavedItems();
    const updated = existing.filter((s) => s.id !== id);
    await set(K.SAVED_ITEMS, updated);
    return updated;
  },

  async isSaved(id: string): Promise<boolean> {
    const items = await persistence.getSavedItems();
    return items.some((s) => s.id === id);
  },

  // Podcast playback positions (episode id → seconds)
  getPodcastPositions: () => get<Record<string, number>>(K.PODCAST_POSITIONS, {}),

  async savePodcastPosition(episodeId: string, positionSeconds: number): Promise<void> {
    const positions = await persistence.getPodcastPositions();
    await set(K.PODCAST_POSITIONS, { ...positions, [episodeId]: positionSeconds });
  },

  async clearPodcastPosition(episodeId: string): Promise<void> {
    const positions = await persistence.getPodcastPositions();
    const { [episodeId]: _, ...rest } = positions;
    await set(K.PODCAST_POSITIONS, rest);
  },

  // List resume positions per tab
  getListPositions: () => get<Record<string, ListResumeState>>(K.LIST_POSITIONS, {}),

  async saveListPosition(state: ListResumeState): Promise<void> {
    const positions = await persistence.getListPositions();
    await set(K.LIST_POSITIONS, { ...positions, [state.tab]: state });
  },

  // Forum filter
  getForumFilter: () => get<string>(K.FORUM_FILTER, 'Recent'),
  setForumFilter: (filter: string) => set(K.FORUM_FILTER, filter),

  // Settings (key-value store)
  getSettings: () => get<Record<string, unknown>>(K.SETTINGS, {}),

  async getSetting<T>(key: string, fallback: T): Promise<T> {
    const settings = await persistence.getSettings();
    return (key in settings ? settings[key] : fallback) as T;
  },

  async setSetting(key: string, value: unknown): Promise<void> {
    const settings = await persistence.getSettings();
    await set(K.SETTINGS, { ...settings, [key]: value });
  },

  // Last visit timestamp
  getLastVisit: () => get<string | null>(K.LAST_VISIT, null),
  setLastVisit: (isoDate: string) => set(K.LAST_VISIT, isoDate),
  stampVisit: () => persistence.setLastVisit(new Date().toISOString()),

  // Downloaded episodes (episode id → local file URI)
  getDownloadedEpisodes: () => get<Record<string, string>>(K.DOWNLOADED_EPISODES, {}),

  async saveDownloadedEpisode(episodeId: string, localUri: string): Promise<void> {
    const downloads = await persistence.getDownloadedEpisodes();
    await set(K.DOWNLOADED_EPISODES, { ...downloads, [episodeId]: localUri });
  },

  async removeDownloadedEpisode(episodeId: string): Promise<void> {
    const downloads = await persistence.getDownloadedEpisodes();
    const { [episodeId]: _, ...rest } = downloads;
    await set(K.DOWNLOADED_EPISODES, rest);
  },

  async isDownloaded(episodeId: string): Promise<boolean> {
    const downloads = await persistence.getDownloadedEpisodes();
    return episodeId in downloads;
  },

  // Playback queue
  getQueue: () => get<string[]>(K.QUEUE, []),
  setQueue: (episodeIds: string[]) => set(K.QUEUE, episodeIds),
};
