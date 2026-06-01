import '../src/i18n'; // initialise i18n before any component renders
import { useEffect } from 'react';
import { I18nManager, Platform } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useColorScheme } from 'react-native';
import { isRTL } from '../src/i18n';
import { apiHealth } from '../src/services/apiHealth';
import { cachedApi } from '../src/services/cachedApi';
import { sounds } from '../src/services/sounds';
import { authEvents } from '../src/services/authEvents';
import { ToastProvider, useToast } from '../src/contexts/ToastContext';
import { AuthProvider, useAuth } from '../src/contexts/AuthContext';

// Registers the cross-module auth-expiry handler inside a component that has
// access to both AuthContext and ToastContext.
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

export default function RootLayout() {
  const scheme = useColorScheme();

  useEffect(() => {
    // Apply RTL layout for Arabic and Persian.
    // On iOS, allowRTL must be true (it is by default); forceRTL overrides
    // when the app language differs from the system language.
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
        <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
        <Stack screenOptions={{ headerShown: false }} />
      </AuthProvider>
    </ToastProvider>
  );
}
