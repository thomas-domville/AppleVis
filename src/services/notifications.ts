import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { router } from 'expo-router';

async function registerCategories() {
  await Notifications.setNotificationCategoryAsync('forumReply', [
    { identifier: 'REPLY',     buttonTitle: 'Reply',       options: { opensAppToForeground: true } },
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
    { identifier: 'DOWNLOAD', buttonTitle: 'Download', options: { opensAppToForeground: false } },
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

function configureForegroundBehavior() {
  Notifications.setNotificationHandler({
    handleNotification: async (notification) => {
      const category = notification.request.content.categoryIdentifier;
      return {
        shouldShowBanner: true,
        shouldShowList:   true,
        shouldPlaySound:  category !== 'appUpdate' && category !== 'announcement',
        shouldSetBadge:   true,
        priority:         Notifications.AndroidNotificationPriority.HIGH,
      };
    },
  });
}

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

export async function getExpoPushToken(): Promise<string | null> {
  try {
    const { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') return null;
    const token = await Notifications.getExpoPushTokenAsync({ projectId: 'com.applevis.app' });
    return token.data;
  } catch { return null; }
}

export function handleNotificationResponse(response: Notifications.NotificationResponse) {
  const category = response.notification.request.content.categoryIdentifier;
  const actionId = response.actionIdentifier;
  const isDefault = actionId === Notifications.DEFAULT_ACTION_IDENTIFIER;

  if (category === 'forumReply' || category === 'mention' || category === 'newTopic' || category === 'followedTopic') {
    if (isDefault || actionId === 'VIEW_POST' || actionId === 'OPEN' || actionId === 'VIEW_REPLY' || actionId === 'REPLY') {
      router.push('/(tabs)/forums');
    }
  } else if (category === 'newEpisode') {
    if (isDefault || actionId === 'PLAY' || actionId === 'DOWNLOAD') router.push('/(tabs)/podcasts');
  } else if (category === 'appUpdate') {
    router.push('/(tabs)/apps');
  } else if (category === 'newResource' || category === 'announcement') {
    if (isDefault || actionId === 'READ' || actionId === 'VIEW') router.push('/(tabs)/resources');
  }
}

export async function setupNotifications() {
  configureForegroundBehavior();
  await registerCategories();
}
