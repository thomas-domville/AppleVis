import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import * as SecureStore from 'expo-secure-store';
import { api } from '../services/api';
import { getExpoPushToken } from '../services/notifications';

// ─── Types ────────────────────────────────────────────────────────────────────

export type AuthUser = {
  uid: string;
  uuid?: string;   // JSON:API UUID — used for ownership checks on content
  name: string;
  csrfToken: string;
  logoutToken: string;
};

type AuthContextValue = {
  isSignedIn: boolean;
  user: AuthUser | null;
  /** True while the saved session is being restored on launch. */
  isLoading: boolean;
  signIn: (login: string, password: string) => Promise<{ ok: true; user: AuthUser } | { ok: false; error: string }>;
  signOut: () => Promise<void>;
  deleteAccount: () => Promise<{ ok: boolean; error?: string }>;
};

// ─── Context ──────────────────────────────────────────────────────────────────

const AuthContext = createContext<AuthContextValue>({
  isSignedIn: false,
  user: null,
  isLoading: true,
  signIn: async () => ({ ok: false, error: 'Not ready' }),
  signOut: async () => {},
  deleteAccount: async () => ({ ok: false, error: 'Not ready' }),
});

export function useAuth(): AuthContextValue {
  return useContext(AuthContext);
}

// ─── Storage ──────────────────────────────────────────────────────────────────

const SESSION_KEY = 'applevis:auth:session';
const SIGN_IN_TIMEOUT_MS = 15_000;

async function saveSession(user: AuthUser): Promise<void> {
  await SecureStore.setItemAsync(SESSION_KEY, JSON.stringify(user));
}

async function clearSession(): Promise<void> {
  await SecureStore.deleteItemAsync(SESSION_KEY).catch(() => {});
}

async function loadSession(): Promise<AuthUser | null> {
  try {
    const raw = await SecureStore.getItemAsync(SESSION_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  } catch {
    return null;
  }
}

// ─── Error message helper ─────────────────────────────────────────────────────

export function friendlySignInError(rawError: string, status?: number): string {
  const lower = rawError.toLowerCase();

  if (status === 400 || status === 401 || rawError.includes('400') || rawError.includes('401')) {
    return 'Sign in failed: AppleVis did not accept that username or email and password. Please check both fields and try again.';
  }
  if (status === 403 || rawError.includes('403')) {
    return 'Sign in failed: AppleVis refused the sign-in request. Please close and reopen the app, then try again.';
  }
  if (status === 429 || rawError.includes('429') || lower.includes('rate')) {
    return 'Sign in failed: AppleVis is receiving too many sign-in attempts. Please wait a moment and try again.';
  }
  if ((status && status >= 500) || rawError.includes('500')) {
    return 'Sign in failed: AppleVis returned a server error. Please try again later.';
  }
  if (lower.includes('timed out')) {
    return 'Sign in failed: the request timed out before AppleVis responded.';
  }
  if (lower.includes('network') || lower.includes('fetch') || lower.includes('failed to fetch')) {
    return 'Sign in failed: the app could not reach AppleVis. Check your internet connection and try again.';
  }
  return 'Sign in failed: AppleVis did not complete the sign-in request. Please try again.';
}

async function withSignInTimeout<T>(promise: Promise<T>): Promise<T | { ok: false; error: string }> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<{ ok: false; error: string }>((resolve) => {
    timer = setTimeout(() => resolve({ ok: false, error: 'Request timed out.' }), SIGN_IN_TIMEOUT_MS);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Restore session from encrypted storage on launch
  useEffect(() => {
    loadSession()
      .then((saved) => { if (saved) setUser(saved); })
      .finally(() => setIsLoading(false));
  }, []);

  const signIn = useCallback(
    async (login: string, password: string): Promise<{ ok: true; user: AuthUser } | { ok: false; error: string }> => {
      try {
        const result = await withSignInTimeout(api.account.signIn(login.trim(), password));
        if (!result.ok) {
          const status = 'status' in result ? result.status : undefined;
          return { ok: false, error: friendlySignInError(result.error, status) };
        }
        const { current_user, csrf_token, logout_token } = result.data;
        const newUser: AuthUser = {
          uid: current_user.uid,
          name: current_user.name,
          csrfToken: csrf_token,
          logoutToken: logout_token,
        };
        setUser(newUser);
        saveSession(newUser).catch(() => {});

        // Resolve and persist the JSON:API UUID immediately after login.
        // Best-effort — sign-in succeeds regardless; uuid is used for ownership checks.
        api.account.resolveUuid(csrf_token).then((uuid) => {
          if (uuid) {
            const withUuid: AuthUser = { ...newUser, uuid };
            setUser(withUuid);
            saveSession(withUuid).catch(() => {});
          }
        }).catch(() => {});

        // Register device push token with server so targeted notifications work.
        // Best-effort — sign-in succeeds regardless of token registration outcome.
        getExpoPushToken().then((token) => {
          if (token) api.account.registerPushToken(token, csrf_token).catch(() => {});
        }).catch(() => {});

        return { ok: true, user: newUser };
      } catch {
        return { ok: false, error: 'Sign in failed: the app could not complete sign-in. Please try again.' };
      }
    },
    [],
  );

  const signOut = useCallback(async () => {
    if (user) {
      // Best-effort: clear push token before signing out so server stops targeting this device.
      api.account.removePushToken(user.csrfToken).catch(() => {});
      await api.account.signOut(user.logoutToken).catch(() => {});
    }
    await clearSession();
    setUser(null);
  }, [user]);

  const deleteAccount = useCallback(async (): Promise<{ ok: boolean; error?: string }> => {
    if (!user) return { ok: false, error: 'Not signed in.' };
    const result = await api.account.deleteAccount(user.csrfToken);
    if (!result.ok) return { ok: false, error: result.error };
    await clearSession();
    setUser(null);
    return { ok: true };
  }, [user]);

  return (
    <AuthContext.Provider
      value={{ isSignedIn: user !== null, user, isLoading, signIn, signOut, deleteAccount }}
    >
      {children}
    </AuthContext.Provider>
  );
}
