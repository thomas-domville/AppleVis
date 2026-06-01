import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import * as SecureStore from 'expo-secure-store';
import { api } from '../services/api';

// ─── Types ────────────────────────────────────────────────────────────────────

export type AuthUser = {
  uid: string;
  name: string;
  csrfToken: string;
  logoutToken: string;
};

type AuthContextValue = {
  isSignedIn: boolean;
  user: AuthUser | null;
  /** True while the saved session is being restored on launch. */
  isLoading: boolean;
  signIn: (email: string, password: string) => Promise<{ ok: boolean; error?: string }>;
  signOut: () => Promise<void>;
};

// ─── Context ──────────────────────────────────────────────────────────────────

const AuthContext = createContext<AuthContextValue>({
  isSignedIn: false,
  user: null,
  isLoading: true,
  signIn: async () => ({ ok: false, error: 'Not ready' }),
  signOut: async () => {},
});

export function useAuth(): AuthContextValue {
  return useContext(AuthContext);
}

// ─── Storage ──────────────────────────────────────────────────────────────────

const SESSION_KEY = 'applevis:auth:session';

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

export function friendlySignInError(rawError: string): string {
  if (rawError.includes('500')) {
    return 'Sign in is temporarily unavailable — the server needs a fix from your developer. Try again later.';
  }
  if (rawError.includes('400') || rawError.includes('403')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (rawError.toLowerCase().includes('network') || rawError.toLowerCase().includes('fetch')) {
    return 'Could not reach the server. Check your internet connection and try again.';
  }
  return 'Sign in failed. Please try again later.';
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
    async (email: string, password: string): Promise<{ ok: boolean; error?: string }> => {
      const result = await api.account.signIn(email.trim(), password);
      if (!result.ok) {
        return { ok: false, error: friendlySignInError(result.error) };
      }
      const { current_user, csrf_token, logout_token } = result.data;
      const newUser: AuthUser = {
        uid: current_user.uid,
        name: current_user.name,
        csrfToken: csrf_token,
        logoutToken: logout_token,
      };
      await saveSession(newUser);
      setUser(newUser);
      return { ok: true };
    },
    [],
  );

  const signOut = useCallback(async () => {
    if (user) {
      // Best-effort server logout — don't block on failure
      await api.account.signOut(user.logoutToken).catch(() => {});
    }
    await clearSession();
    setUser(null);
  }, [user]);

  return (
    <AuthContext.Provider
      value={{ isSignedIn: user !== null, user, isLoading, signIn, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}
