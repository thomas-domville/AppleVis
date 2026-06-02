import '../src/i18n';
import { useEffect, useState } from 'react';
import { I18nManager, Platform } from 'react-native';
import { Stack, router } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
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
import { onboarding } from '../src/services/onboarding';
import { useKeyboardShortcuts } from '../src/hooks/useKeyboardShortcuts';
import { ThemeProvider, useTheme } from '../src/contexts/ThemeContext';
import { PreferencesProvider } from '../src/contexts/PreferencesContext';
import { ToastProvider, useToast } from '../src/contexts/ToastContext';
import { AuthProvider, useAuth } from '../src/contexts/AuthContext';

// Keep splash visible until onboarding check + initial data load finishes.
SplashScreen.preventAutoHideAsync().catch(() => {});

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
    setupNotifications().catch(() => {});
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      registerBackgroundFetch().catch(() => {});
    }

    const notifSub = Notifications.addNotificationResponseReceivedListener(handleNotificationResponse);

    Linking.getInitialURL().then((url) => { if (url) handleIncomingUrl(url); });
    const linkSub = Linking.addEventListener('url', ({ url }) => handleIncomingUrl(url));

    return () => { notifSub.remove(); linkSub.remove(); };
  }, []);

  return null;
}

function OnboardingGate({ children }: { children: React.ReactNode }) {
  const [redirectTo, setRedirectTo] = useState<string | null>(null);

  useEffect(() => {
    onboarding.isComplete()
      .then((done) => { if (!done) setRedirectTo('/onboarding'); })
      .catch(() => {})
      .finally(() => { SplashScreen.hideAsync().catch(() => {}); });
  }, []);

  // Navigate only after children (Stack) have mounted and rendered.
  useEffect(() => {
    if (redirectTo) router.replace(redirectTo as any);
  }, [redirectTo]);

  return <>{children}</>;
}

function ThemedStatusBar() {
  const { isDark } = useTheme();
  return <StatusBar style={isDark ? 'light' : 'dark'} />;
}

export default function RootLayout() {
  useEffect(() => {
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      I18nManager.allowRTL(true);
      if (isRTL !== I18nManager.isRTL) I18nManager.forceRTL(isRTL);
    }
    apiHealth.probe();
    cachedApi.prefetchAll();
    sounds.preload();
    // Fallback: ensure splash is hidden even if OnboardingGate's finally doesn't fire.
    const t = setTimeout(() => SplashScreen.hideAsync().catch(() => {}), 3000);
    return () => clearTimeout(t);
  }, []);

  return (
    <ThemeProvider>
      <PreferencesProvider>
        <ToastProvider>
          <AuthProvider>
            <AuthExpiryHandler />
            <AppServices />
            <ThemedStatusBar />
            <OnboardingGate>
              <Stack screenOptions={{ headerShown: false }} />
            </OnboardingGate>
          </AuthProvider>
        </ToastProvider>
      </PreferencesProvider>
    </ThemeProvider>
  );
}
