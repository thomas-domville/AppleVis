import * as BackgroundFetch from 'expo-background-fetch';
import * as TaskManager from 'expo-task-manager';
import { cachedApi } from '../services/cachedApi';

export const BACKGROUND_FETCH_TASK = 'applevis-background-fetch';

/**
 * The background task definition. Must be defined at module scope (not inside
 * a component) so TaskManager can find it after a cold wake from the OS.
 *
 * iOS calls this task at its discretion when the device has network and power.
 * The actual interval depends on the app's usage patterns — iOS learns from
 * how often the user opens the app and pre-fetches content before each launch.
 *
 * What it does: refreshes all cached API endpoints (forums, apps, resources,
 * podcasts) so content is ready immediately when the user opens the app.
 */
TaskManager.defineTask(BACKGROUND_FETCH_TASK, async () => {
  try {
    await cachedApi.prefetchAll();
    return BackgroundFetch.BackgroundFetchResult.NewData;
  } catch {
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});

/**
 * Registers the background fetch task.
 * Call once from _layout.tsx useEffect.
 *
 * minimumInterval: 900 seconds (15 min). iOS ignores this on older devices
 * or when battery-saving is active, but it sets the floor.
 *
 * stopOnTerminate: false — iOS can wake the app even after the user swipes it away.
 * startOnBoot: true — registers the task after device restart (iOS only advisory).
 */
export async function registerBackgroundFetch(): Promise<void> {
  const status = await BackgroundFetch.getStatusAsync();

  if (
    status === BackgroundFetch.BackgroundFetchStatus.Restricted ||
    status === BackgroundFetch.BackgroundFetchStatus.Denied
  ) {
    return;
  }

  const isRegistered = await TaskManager.isTaskRegisteredAsync(BACKGROUND_FETCH_TASK);
  if (isRegistered) return;

  await BackgroundFetch.registerTaskAsync(BACKGROUND_FETCH_TASK, {
    minimumInterval: 60 * 15,
    stopOnTerminate: false,
    startOnBoot: true,
  });
}
