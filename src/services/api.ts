import type { ForumTopic, PodcastEpisode, AppListing, Resource } from '../types/content';

// Replace with real AppleVis Drupal API base URL when available
const BASE_URL = 'https://www.applevis.com/api/v1';

export type ApiResult<T> = { ok: true; data: T } | { ok: false; error: string; status?: number };

async function request<T>(path: string, options?: RequestInit): Promise<ApiResult<T>> {
  try {
    const res = await fetch(`${BASE_URL}${path}`, {
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      ...options,
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
    const data = (await res.json()) as T;
    return { ok: true, data };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Network error' };
  }
}

export type PaginatedResult<T> = { items: T[]; total: number; page: number; perPage: number };

export type AccountProfile = {
  userId: string;
  displayName: string;
  email: string;
  joinedAt: string;
  avatarUrl?: string;
};

export type SyncPayload = {
  settings: Record<string, unknown>;
  savedItemIds: string[];
  followedItemIds: string[];
  podcastPositions: Record<string, number>;
  listPositions: Record<string, { itemId: string; offsetHint?: number }>;
  syncedAt: string;
};

export const api = {
  forums: {
    list: (filter: string, page = 0) =>
      request<PaginatedResult<ForumTopic>>(`/forum/topics?filter=${encodeURIComponent(filter)}&page=${page}`),
    topic: (id: string) =>
      request<ForumTopic>(`/forum/topics/${id}`),
    markRead: (id: string) =>
      request<void>(`/forum/topics/${id}/read`, { method: 'POST' }),
    follow: (id: string) =>
      request<void>(`/forum/topics/${id}/follow`, { method: 'POST' }),
    unfollow: (id: string) =>
      request<void>(`/forum/topics/${id}/follow`, { method: 'DELETE' }),
  },

  podcasts: {
    episodes: (page = 0) =>
      request<PaginatedResult<PodcastEpisode>>(`/podcasts/episodes?page=${page}`),
    episode: (id: string) =>
      request<PodcastEpisode>(`/podcasts/episodes/${id}`),
    transcript: (id: string) =>
      request<{ text: string; vttUrl?: string }>(`/podcasts/episodes/${id}/transcript`),
  },

  apps: {
    list: (page = 0) =>
      request<PaginatedResult<AppListing>>(`/apps?page=${page}`),
    listing: (id: string) =>
      request<AppListing>(`/apps/${id}`),
    updates: (page = 0) =>
      request<PaginatedResult<AppListing>>(`/apps/updates?page=${page}`),
  },

  resources: {
    list: (page = 0) =>
      request<PaginatedResult<Resource>>(`/resources?page=${page}`),
    item: (id: string) =>
      request<Resource>(`/resources/${id}`),
  },

  account: {
    signIn: (email: string, password: string) =>
      request<{ token: string; profile: AccountProfile }>(`/auth/login`, {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      }),
    signOut: (token: string) =>
      request<void>(`/auth/logout`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      }),
    profile: (token: string) =>
      request<AccountProfile>(`/account/profile`, {
        headers: { Authorization: `Bearer ${token}` },
      }),
    deleteAccount: (token: string) =>
      request<void>(`/account`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      }),
    sync: (token: string, payload: SyncPayload) =>
      request<{ syncedAt: string }>(`/account/sync`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: JSON.stringify(payload),
      }),
  },
};
