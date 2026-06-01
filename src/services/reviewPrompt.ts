import * as StoreReview from 'expo-store-review';
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY   = '@applevis_review_last_prompted';
const COOLDOWN_DAYS = 90;

// In-memory count of meaningful actions performed this session.
let sessionActionCount = 0;

// How many meaningful actions before we consider showing the prompt.
const ACTION_THRESHOLD = 3;

/**
 * Tracks a meaningful user action (e.g. listened to a full podcast episode,
 * saved an item, submitted a forum reply). After enough actions and once the
 * cooldown has elapsed, shows the native App Store review dialog.
 *
 * Apple guidelines:
 *  - Call at a natural pause in the workflow, not during a task
 *  - Never ask more than 3 times per year (the OS enforces this automatically)
 *  - Do not intercept, gate, or explain the prompt — show it directly
 *
 * Good moments to call this:
 *  - After a podcast episode finishes playing
 *  - After the user saves their 5th item
 *  - After posting a forum reply
 */
export async function trackMeaningfulAction(): Promise<void> {
  sessionActionCount++;
  if (sessionActionCount < ACTION_THRESHOLD) return;

  const isAvailable = await StoreReview.isAvailableAsync();
  if (!isAvailable) return;

  const lastPrompted = await AsyncStorage.getItem(STORAGE_KEY);
  if (lastPrompted) {
    const daysSince = (Date.now() - Number(lastPrompted)) / (1000 * 60 * 60 * 24);
    if (daysSince < COOLDOWN_DAYS) return;
  }

  await StoreReview.requestReview();
  await AsyncStorage.setItem(STORAGE_KEY, String(Date.now()));
  sessionActionCount = 0;
}
