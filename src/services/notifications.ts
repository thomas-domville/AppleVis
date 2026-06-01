import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { router } from 'expo-router';

/**
 * Push notification categories map to notification types the server sends.
 * Each category defines the action buttons shown in the notification banner
 * and on the lock screen.
 */
async function registerCategories() {
  await Notifications.setNotificationCategoryAsync('forumReply', [
    {
      identifier: 'REPLY',
      buttonTitle: 'Reply',
      options: { opensAppToForeground: true },
    },
    {
      identifier: 'MARK_READ',
      buttonTitle: 'Mark as Read',
      options: { opensAppToForeground: false, isDestructive: false },
    },
  ]);

  await Notifications.setNotificationCategoryAsync('mention', [
    {
      identifier: 'VIEW_POST',
      buttonTitle: 'View Post',
      options: { opensAppToForeground: true },
    },
    {
      identifier: 'REPLY',
      buttonTitle: 'Reply',
      options: { opensAppToForeground: true },
    },
  ]);

  await Notifications.setNotificationCategoryAsync('newEpisode', [
    {
      identifier: 'PLAY',
      buttonTitle: 'Play',
      options: { opensAppToForeground: true },
    },
    {
      identifier: 'DOWNLOAD',
      buttonTitle: 'Download',
      options: { opensAppToForeground: false },
    },
  ]);

  await Notifications.setNotificationCategoryAsync('appUpdate', [
    {
      identifier: 'VIEW_APP',
      buttonTitle: 'View App',
      options: { opensAppToForeground: true },
    },
  ]);
}

/**
 * Sets the foreground notification handler. Without this iOS shows nothing
 * when a notification arrives while the app is open.
 */
function configureForegroundBehavior() {
  Notifications.setNotificationHandler({
    handleNotification: async (notification) => {
      const category = notification.request.content.categoryIdentifier;
      return {
        shouldShowBanner: true,
        shouldShowList: true,
        shouldPlaySound: category !== 'appUpdate',
        shouldSetBadge: true,
        priority: Notifications.AndroidNotificationPriority.HIGH,
      };
    },
  });
}

/**
 * Requests user permission for notifications.
 * Should be called at a moment where context is clear (e.g. after sign-in).
 * Returns true if permission was granted.
 */
export async function requestNotificationPermissions(): Promise<boolean> {
  if (Platform.OS !== 'ios' && Platform.OS !== 'android') return false;

  const { status, canAskAgain } = await Notifications.getPermissionsAsync();
  if (status === 'granted') return true;
  if (!canAskAgain) return false;

  const result = await Notifications.requestPermissionsAsync({
    ios: {
      allowAlert: true,
      allowBadge: true,
      allowSound: true,
      allowCriticalAlerts: false,
      provideAppNotificationSettings: true,
    },
  });
  return result.status === 'granted';
}

/**
 * Returns the Expo push token string to register with the applevis.com server.
 * The server uses this to send targeted notifications to this device.
 */
export async function getExpoPushToken(): Promise<string | null> {
  try {
    const { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') return null;
    const token = await Notifications.getExpoPushTokenAsync({
      projectId: 'com.applevis.app',
    });
    return token.data;
  } catch {
    return null;
  }
}

/**
 * Routes a notification tap to the correct screen.
 * Called from the notification response listener in _layout.tsx.
 */
export function handleNotificationResponse(
  response: Notifications.NotificationResponse,
) {
  const data = response.notification.request.content.data as Record<string, string>;
  const actionId = response.actionIdentifier;
  const category = response.notification.request.content.categoryIdentifier;

  if (category === 'forumReply' || category === 'mention') {
    if (actionId === Notifications.DEFAULT_ACTION_IDENTIFIER || actionId === 'VIEW_POST' || actionId === 'REPLY') {
      router.push('/(tabs)/forums');
    }
  } else if (category === 'newEpisode') {
    if (actionId === Notifications.DEFAULT_ACTION_IDENTIFIER || actionId === 'PLAY' || actionId === 'DOWNLOAD') {
      router.push('/(tabs)/podcasts');
    }
  } else if (category === 'appUpdate') {
    router.push('/(tabs)/apps');
  }

  void data;
}

/**
 * Call once at app startup (inside a useEffect in _layout.tsx).
 * Sets up the foreground handler and notification categories.
 */
export async function setupNotifications() {
  configureForegroundBehavior();
  await registerCategories();
}
