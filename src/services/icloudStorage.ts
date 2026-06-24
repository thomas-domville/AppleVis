/**
 * iCloud Key-Value Storage
 *
 * Uses NSUbiquitousKeyValueStore (via the AppleVisCloudSync native module) when
 * running in a development or production build.  Falls back to AsyncStorage
 * transparently when running in Expo Go, on Android, or when iCloud is not
 * signed in — so everything still works during development.
 *
 * Limit: 1 MB total / 1024 keys.  We only store IDs and small primitives here,
 * never full content bodies, so this is well within the limit.
 */

import { NativeModules } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { sounds } from './sounds';

const Native = NativeModules.AppleVisCloudSync as {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, value: string) => Promise<void>;
  removeItem: (key: string) => Promise<void>;
  getAllKeys: () => Promise<string[]>;
} | undefined;

const isAvailable = !!Native;
let syncCompleteTimer: ReturnType<typeof setTimeout> | null = null;

function scheduleSyncCompleteSound(): void {
  if (!isAvailable) return;
  if (syncCompleteTimer) clearTimeout(syncCompleteTimer);
  syncCompleteTimer = setTimeout(() => {
    syncCompleteTimer = null;
    sounds.syncComplete().catch(() => {});
  }, 750);
}

async function get(key: string): Promise<string | null> {
  try {
    if (isAvailable) return await Native!.getItem(key);
    return await AsyncStorage.getItem(key);
  } catch {
    return null;
  }
}

async function set(key: string, value: string): Promise<void> {
  try {
    if (isAvailable) {
      await Native!.setItem(key, value);
      scheduleSyncCompleteSound();
    } else {
      await AsyncStorage.setItem(key, value);
    }
  } catch {
    // Storage failure is non-fatal
  }
}

async function remove(key: string): Promise<void> {
  try {
    if (isAvailable) {
      await Native!.removeItem(key);
      scheduleSyncCompleteSound();
    } else {
      await AsyncStorage.removeItem(key);
    }
  } catch (_e) { /* non-critical */ }
}

export const icloudStorage = {
  // ── Primitives ────────────────────────────────────────────────────────────

  async getString(key: string, fallback = ''): Promise<string> {
    const v = await get(key);
    return v ?? fallback;
  },

  async setString(key: string, value: string): Promise<void> {
    return set(key, value);
  },

  async getJSON<T>(key: string, fallback: T): Promise<T> {
    try {
      const v = await get(key);
      return v ? (JSON.parse(v) as T) : fallback;
    } catch {
      return fallback;
    }
  },

  async setJSON<T>(key: string, value: T): Promise<void> {
    return set(key, JSON.stringify(value));
  },

  async remove(key: string): Promise<void> {
    return remove(key);
  },

  async getAllKeys(): Promise<string[]> {
    try {
      const keys = isAvailable ? await Native!.getAllKeys() : await AsyncStorage.getAllKeys();
      return Array.from(keys);
    } catch {
      return [];
    }
  },

  // ── Set helpers (stored as JSON arrays, deduplicated) ─────────────────────

  async getSet(key: string): Promise<Set<string>> {
    const arr = await icloudStorage.getJSON<string[]>(key, []);
    return new Set(arr);
  },

  async addToSet(key: string, id: string): Promise<void> {
    const s = await icloudStorage.getSet(key);
    s.add(id);
    return icloudStorage.setJSON(key, Array.from(s));
  },

  async removeFromSet(key: string, id: string): Promise<void> {
    const s = await icloudStorage.getSet(key);
    s.delete(id);
    return icloudStorage.setJSON(key, Array.from(s));
  },

  async isInSet(key: string, id: string): Promise<boolean> {
    const s = await icloudStorage.getSet(key);
    return s.has(id);
  },
};
