/**
 * Background fetch service
 *
 * Registers two background tasks:
 *
 *   FEED_REFRESH_TASK  — Checks for new episodes in the feed and stores
 *                        them in AsyncStorage so the user sees fresh
 *                        content even before opening the app.
 *
 *   AUTO_DOWNLOAD_TASK — For each new episode found, triggers a download
 *                        when the user has autoDownload = 'wifiOnly' or
 *                        'always' and the device conditions allow.
 *
 * Both tasks run in the background at system-determined intervals
 * (typically every 15 minutes on iOS when battery and network allow).
 * expo-background-fetch and expo-task-manager handle scheduling; the app
 * just registers the task handlers at startup.
 *
 * Usage: call `registerBackgroundTasks()` once from app/_layout.tsx.
 */

import * as BackgroundFetch from 'expo-background-fetch';
import * as TaskManager from 'expo-task-manager';
import * as Network from '@react-native-community/netinfo';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { downloadEpisode } from './downloads';
import { persistence } from './persistence';

const FEED_REFRESH_TASK  = 'applevis-feed-refresh';
const AUTO_DOWNLOAD_TASK = 'applevis-auto-download';

const PODCAST_FEED_URL =
  'https://www.applevis.com/api/podcasts?page[limit]=10&sort=-publishedAt';

// ── Task definitions ──────────────────────────────────────────────────────────

TaskManager.defineTask(FEED_REFRESH_TASK, async () => {
  try {
    const response = await fetch(PODCAST_FEED_URL, {
      headers: { Accept: 'application/vnd.api+json' },
    });
    if (!response.ok) return BackgroundFetch.BackgroundFetchResult.Failed;

    const json = await response.json();
    const episodes = (json.data ?? []).map((item: any) => ({
      id:          item.id,
      title:       item.attributes?.title ?? '',
      showTitle:   item.attributes?.field_podcast_title ?? '',
      publishedAt: item.attributes?.created ?? '',
      duration:    item.attributes?.field_duration ?? 0,
      audioUrl:    item.attributes?.field_audio_url ?? '',
    }));

    await AsyncStorage.setItem('applevis:backgroundFeedCache', JSON.stringify({
      episodes,
      fetchedAt: Date.now(),
    }));

    return BackgroundFetch.BackgroundFetchResult.NewData;
  } catch {
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});

TaskManager.defineTask(AUTO_DOWNLOAD_TASK, async () => {
  try {
    const autoDownload = await persistence.getSetting<string>(
      '@applevis_podcast_auto_download', 'off');
    if (autoDownload === 'off') return BackgroundFetch.BackgroundFetchResult.NoData;

    const state = await Network.fetch();
    const isWifi = state.type === 'wifi';
    if (autoDownload === 'wifiOnly' && !isWifi) {
      return BackgroundFetch.BackgroundFetchResult.NoData;
    }

    const raw = await AsyncStorage.getItem('applevis:backgroundFeedCache');
    if (!raw) return BackgroundFetch.BackgroundFetchResult.NoData;

    const { episodes } = JSON.parse(raw);
    const existing = await persistence.getDownloadedEpisodes();
    const lastVisitStr = await persistence.getLastVisit();
    const lastVisit = lastVisitStr ? new Date(lastVisitStr) : null;

    let downloaded = 0;
    for (const ep of episodes.slice(0, 3)) {  // cap at 3 per background run
      if (ep.id in existing) continue;
      if (lastVisit && ep.publishedAt && new Date(ep.publishedAt) <= lastVisit) continue;
      await downloadEpisode(ep.id, ep.audioUrl, ep);
      downloaded++;
    }

    return downloaded > 0
      ? BackgroundFetch.BackgroundFetchResult.NewData
      : BackgroundFetch.BackgroundFetchResult.NoData;
  } catch {
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});

// ── Registration ──────────────────────────────────────────────────────────────

export async function registerBackgroundTasks(): Promise<void> {
  await BackgroundFetch.registerTaskAsync(FEED_REFRESH_TASK, {
    minimumInterval: 15 * 60,       // 15 minutes
    stopOnTerminate: false,
    startOnBoot: true,
  }).catch(() => {});

  await BackgroundFetch.registerTaskAsync(AUTO_DOWNLOAD_TASK, {
    minimumInterval: 30 * 60,       // 30 minutes
    stopOnTerminate: false,
    startOnBoot: true,
  }).catch(() => {});
}

export async function unregisterBackgroundTasks(): Promise<void> {
  await BackgroundFetch.unregisterTaskAsync(FEED_REFRESH_TASK).catch(() => {});
  await BackgroundFetch.unregisterTaskAsync(AUTO_DOWNLOAD_TASK).catch(() => {});
}
