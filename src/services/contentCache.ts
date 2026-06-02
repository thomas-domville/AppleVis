import AsyncStorage from '@react-native-async-storage/async-storage';

const PREFIX = 'applevis:cache:';

// How long before cached data is considered stale (shown with a banner)
// and how long before it is considered expired (not served at all).
const STALE_MS: Record<string, number> = {
  'forums:':    30 * 60 * 1000,         // 30 min
  'podcasts:':   6 * 60 * 60 * 1000,    // 6 hr
  'apps:':       6 * 60 * 60 * 1000,    // 6 hr
  'resources:':  6 * 60 * 60 * 1000,    // 6 hr
};
const EXPIRE_MS: Record<string, number> = {
  'forums:':    7  * 24 * 60 * 60 * 1000,  // 7 days
  'podcasts:':  30 * 24 * 60 * 60 * 1000,  // 30 days
  'apps:':      30 * 24 * 60 * 60 * 1000,
  'resources:': 30 * 24 * 60 * 60 * 1000,
};

function getTTL(key: string): { staleMs: number; expireMs: number } {
  for (const [prefix, staleMs] of Object.entries(STALE_MS)) {
    if (key.startsWith(prefix)) {
      return { staleMs, expireMs: EXPIRE_MS[prefix] ?? 30 * 24 * 60 * 60 * 1000 };
    }
  }
  return { staleMs: 60 * 60 * 1000, expireMs: 7 * 24 * 60 * 60 * 1000 };
}

export type CacheEntry<T> = {
  data: T;
  fetchedAt: number; // Unix ms
};

export type CacheFreshness = 'fresh' | 'stale' | 'expired';

export const contentCache = {
  async get<T>(key: string): Promise<CacheEntry<T> | null> {
    try {
      const raw = await AsyncStorage.getItem(PREFIX + key);
      if (!raw) return null;
      return JSON.parse(raw) as CacheEntry<T>;
    } catch {
      return null;
    }
  },

  async set<T>(key: string, data: T): Promise<void> {
    try {
      const entry: CacheEntry<T> = { data, fetchedAt: Date.now() };
      await AsyncStorage.setItem(PREFIX + key, JSON.stringify(entry));
    } catch (_e) { /* non-critical */ }
  },

  // Returns 'fresh', 'stale', or 'expired' for a given entry and cache key.
  freshness(key: string, entry: CacheEntry<unknown>): CacheFreshness {
    const age = Date.now() - entry.fetchedAt;
    const { staleMs, expireMs } = getTTL(key);
    if (age > expireMs) return 'expired';
    if (age > staleMs)  return 'stale';
    return 'fresh';
  },

  // Returns the entry only if it is not expired. Stale entries are still returned.
  async getIfNotExpired<T>(key: string): Promise<CacheEntry<T> | null> {
    const entry = await contentCache.get<T>(key);
    if (!entry) return null;
    if (contentCache.freshness(key, entry) === 'expired') return null;
    return entry;
  },

  // Remove all cache entries whose keys start with the given prefix,
  // or every cache entry when called with no argument.
  async clear(keyPrefix?: string): Promise<void> {
    try {
      const allKeys = await AsyncStorage.getAllKeys();
      const target = PREFIX + (keyPrefix ?? '');
      const toRemove = allKeys.filter((k) => k.startsWith(target));
      if (toRemove.length > 0) await AsyncStorage.multiRemove(toRemove);
    } catch (_e) { /* non-critical */ }
  },

  // Returns the total number of cached entries (for display in Settings).
  async count(): Promise<number> {
    try {
      const allKeys = await AsyncStorage.getAllKeys();
      return allKeys.filter((k) => k.startsWith(PREFIX)).length;
    } catch {
      return 0;
    }
  },

  // Returns the estimated byte size of all cached entries (UTF-16 string length ≈ bytes).
  async getByteSize(): Promise<number> {
    try {
      const allKeys = await AsyncStorage.getAllKeys();
      const cacheKeys = allKeys.filter((k) => k.startsWith(PREFIX));
      if (cacheKeys.length === 0) return 0;
      const pairs = await AsyncStorage.multiGet(cacheKeys);
      return pairs.reduce((total, [, value]) => total + (value?.length ?? 0), 0);
    } catch {
      return 0;
    }
  },

  // Removes all cache entries whose fetchedAt timestamp is older than maxAgeMs.
  async purgeOlderThan(maxAgeMs: number): Promise<void> {
    try {
      const allKeys = await AsyncStorage.getAllKeys();
      const cacheKeys = allKeys.filter((k) => k.startsWith(PREFIX));
      if (cacheKeys.length === 0) return;
      const pairs = await AsyncStorage.multiGet(cacheKeys);
      const now = Date.now();
      const toRemove: string[] = [];
      for (const [key, value] of pairs) {
        if (!value) continue;
        try {
          const entry = JSON.parse(value) as CacheEntry<unknown>;
          if (now - entry.fetchedAt > maxAgeMs) toRemove.push(key);
        } catch (_e) { /* non-critical */ }
      }
      if (toRemove.length > 0) await AsyncStorage.multiRemove(toRemove);
    } catch (_e) { /* non-critical */ }
  },
};
