import '../src/i18n'; // initialise i18n before any component renders
import { useEffect } from 'react';
import { I18nManager, Platform } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useColorScheme } from 'react-native';
import * as Linking from 'expo-linking';
import * as Notifications from 'expo-notifications';
import { isRTL } from '../src/i18n';
import { apiHealth } from '../src/services/apiHealth';
import { cachedApi } from '../src/services/cachedApi';
import { sounds } from '../src/services/sounds';
import { authEvents } from '../src/services/authEvents';
import { setupNotifications, handleNotificationResponse } from '../src/services/notifications';
import { handleIncomingUrl } from '../src/services/universalLinks';
import { registerBackgroundFetch } from '../src/tasks/backgroundFetch';
import { useKeyboardShortcuts } from '../src/hooks/useKeyboardShortcuts';
import { ToastProvider, useToast } from '../src/contexts/ToastContext';
import { AuthProvider, useAuth } from '../src/contexts/AuthContext';

function AuthExpiryHandler() {
  const auth = useAuth();
  const { showToast } = useToast();

  useEffect(() => {
    authEvents.onSessionExpiry(() => {
      auth.signOut();
      showToast('Your session expired. Please sign in again.', 'warning');
    });
  }, [auth, showToast]);

  return null;
}

function AppServices() {
  useKeyboardShortcuts();

  useEffect(() => {
    // Notifications: set foreground handler + register action categories
    setupNotifications().catch(() => {});

    // Background fetch: silently pre-warm content cache
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      registerBackgroundFetch().catch(() => {});
    }

    // Notification tap handler
    const notifSub = Notifications.addNotificationResponseReceivedListener(
      handleNotificationResponse,
    );

    // Universal Links: handle the URL that launched the app (cold start)
    Linking.getInitialURL().then((url) => {
      if (url) handleIncomingUrl(url);
    });

    // Universal Links: handle URLs while app is already running
    const linkSub = Linking.addEventListener('url', ({ url }) => {
      handleIncomingUrl(url);
    });

    return () => {
      notifSub.remove();
      linkSub.remove();
    };
  }, []);

  return null;
}

export default function RootLayout() {
  const scheme = useColorScheme();

  useEffect(() => {
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      I18nManager.allowRTL(true);
      if (isRTL !== I18nManager.isRTL) I18nManager.forceRTL(isRTL);
    }
    apiHealth.probe();
    cachedApi.prefetchAll();
    sounds.preload();
  }, []);

  return (
    <ToastProvider>
      <AuthProvider>
        <AuthExpiryHandler />
        <AppServices />
        <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
        <Stack screenOptions={{ headerShown: false }} />
      </AuthProvider>
    </ToastProvider>
  );
}
