import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { router } from 'expo-router';
import Constants from 'expo-constants';
import { persistence } from './persistence';
import type { NotificationSound } from '../contexts/PreferencesContext';

// Maps the in-app sound preference key to the .wav filename bundled in the iOS build.
// These filenames must match what is listed under expo-notifications.sounds in app.json.
export const NOTIFICATION_SOUND_FILE: Record<NotificationSound, string> = {
  mouseSqueak:         'Mouse Squeak.wav',
  appleCrunch:         'Apple Crunch.wav',
  goldenRetrieverBark: 'Golden Retriever Bark.wav',
  none:                'default',
};

// ─── Notification data payload ────────────────────────────────────────────────
// Drupal must include these fields in the `data` object of every push payload.
// Until Drupal includes them, taps fall back to opening the relevant tab root.
type NotificationData = {
  topicId?:    string;  // forumReply · mention · newTopic · followedTopic
  episodeId?:  string;  // newEpisode
  appId?:      string;  // appUpdate
  resourceId?: string;  // newResource (guides)
  blogId?:     string;  // newResource (blog posts)
};

// ─── Categories ───────────────────────────────────────────────────────────────

async function registerCategories() {
  await Notifications.setNotificationCategoryAsync('forumReply', [
    { identifier: 'REPLY',     buttonTitle: 'Reply',        options: { opensAppToForeground: true } },
    { identifier: 'MARK_READ', buttonTitle: 'Mark as Read', options: { opensAppToForeground: false } },
  ]);

  await Notifications.setNotificationCategoryAsync('mention', [
    { identifier: 'VIEW_POST', buttonTitle: 'View Post', options: { opensAppToForeground: true } },
    { identifier: 'REPLY',     buttonTitle: 'Reply',     options: { opensAppToForeground: true } },
  ]);

  await Notifications.setNotificationCategoryAsync('newTopic', [
    { identifier: 'OPEN',  buttonTitle: 'Open Topic', options: { opensAppToForeground: true } },
    { identifier: 'LATER', buttonTitle: 'Later',      options: { opensAppToForeground: false } },
  ]);

  await Notifications.setNotificationCategoryAsync('followedTopic', [
    { identifier: 'VIEW_REPLY', buttonTitle: 'View Reply', options: { opensAppToForeground: true } },
    { identifier: 'REPLY',      buttonTitle: 'Reply',      options: { opensAppToForeground: true } },
  ]);

  await Notifications.setNotificationCategoryAsync('newEpisode', [
    { identifier: 'PLAY',     buttonTitle: 'Play',     options: { opensAppToForeground: true } },
    // DOWNLOAD opens the app so the episode screen can queue/start the download.
    { identifier: 'DOWNLOAD', buttonTitle: 'Download', options: { opensAppToForeground: true } },
  ]);

  await Notifications.setNotificationCategoryAsync('appUpdate', [
    { identifier: 'VIEW_APP', buttonTitle: 'View App', options: { opensAppToForeground: true } },
  ]);

  await Notifications.setNotificationCategoryAsync('newResource', [
    { identifier: 'READ',  buttonTitle: 'Read',  options: { opensAppToForeground: true } },
    { identifier: 'LATER', buttonTitle: 'Later', options: { opensAppToForeground: false } },
  ]);

  await Notifications.setNotificationCategoryAsync('announcement', [
    { identifier: 'VIEW', buttonTitle: 'View', options: { opensAppToForeground: true } },
  ]);
}

// ─── Permissions ──────────────────────────────────────────────────────────────

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

// ─── Push token ───────────────────────────────────────────────────────────────
// projectId must be the EAS project UUID from expo.dev → project → Settings → Project ID.
// Add it to app.json: { "expo": { "extra": { "eas": { "projectId": "<UUID>" } } } }
// or run `eas init` to have it added automatically.

const EAS_PROJECT_ID: string | undefined =
  (Constants.expoConfig?.extra as { eas?: { projectId?: string } } | undefined)?.eas?.projectId;

export async function getExpoPushToken(): Promise<string | null> {
  try {
    const { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') return null;
    if (!EAS_PROJECT_ID) {
      if (__DEV__) console.warn('[Notifications] expo.extra.eas.projectId not set in app.json — push tokens unavailable.');
      return null;
    }
    const token = await Notifications.getExpoPushTokenAsync({ projectId: EAS_PROJECT_ID });
    return token.data;
  } catch { return null; }
}

// ─── Tap / action handler ─────────────────────────────────────────────────────

export function handleNotificationResponse(response: Notifications.NotificationResponse) {
  const category = response.notification.request.content.categoryIdentifier;
  const actionId  = response.actionIdentifier;
  const isDefault = actionId === Notifications.DEFAULT_ACTION_IDENTIFIER;
  const data = (response.notification.request.content.data ?? {}) as NotificationData;

  // MARK_READ runs without bringing the app to foreground — persist locally via iCloud.
  // When Drupal includes topicId in the payload this immediately removes the unread indicator.
  if (actionId === 'MARK_READ') {
    if (data.topicId) persistence.markRead(data.topicId).catch(() => {});
    return;
  }

  // LATER: user deferred — no navigation needed.
  if (actionId === 'LATER') return;

  if (
    category === 'forumReply' || category === 'mention' ||
    category === 'newTopic'   || category === 'followedTopic'
  ) {
    const shouldNav = isDefault || actionId === 'VIEW_POST' || actionId === 'OPEN'
                                || actionId === 'VIEW_REPLY' || actionId === 'REPLY';
    if (shouldNav) {
      router.push(data.topicId ? (`/topic/${data.topicId}` as any) : '/(tabs)/forums');
    }
  } else if (category === 'newEpisode') {
    if (isDefault || actionId === 'PLAY' || actionId === 'DOWNLOAD') {
      router.push(data.episodeId ? (`/episode/${data.episodeId}` as any) : '/(tabs)/podcasts');
    }
  } else if (category === 'appUpdate') {
    if (isDefault || actionId === 'VIEW_APP') {
      router.push(data.appId ? (`/app-detail/${data.appId}` as any) : '/(tabs)/apps');
    }
  } else if (category === 'newResource' || category === 'announcement') {
    if (isDefault || actionId === 'READ' || actionId === 'VIEW') {
      if (data.blogId)           router.push(`/blog-detail/${data.blogId}` as any);
      else if (data.resourceId)  router.push(`/resource-detail/${data.resourceId}` as any);
      else                       router.push('/(tabs)/resources');
    }
  }
}

// ─── Setup ────────────────────────────────────────────────────────────────────

export async function setupNotifications() {
  await registerCategories();
}
