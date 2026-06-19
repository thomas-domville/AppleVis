/**
 * Cached API wrapper
 *
 * Wraps api.ts with two layers:
 *   1. Health guard  — if apiHealth marks a group as down, skip the fetch
 *                      and go straight to the cache.
 *   2. Cache fallback — on any fetch failure mark the group down and serve
 *                       the last cached response. On success, refresh the cache.
 *
 * Additional concerns handled here:
 *   • HTTP 401 → emits session-expiry event so the root layout can sign out.
 *   • Expired cache (per TTL) is not served; a clear "first run" error is shown.
 *   • The `fromCache` flag lets callers show a stale-data banner.
 */

import NetInfo from '@react-native-community/netinfo';
import { api } from './api';
import { apiHealth, type ApiGroup } from './apiHealth';
import { contentCache } from './contentCache';
import { authEvents } from './authEvents';
import type {
  ForumTopic, ForumTopicDetail,
  PodcastEpisode,
  AppListing, AppDetail,
  Resource, ResourceDetail,
  BlogPost, BlogPostDetail,
  PaginatedResult,
} from '../types/content';

// Returns true only when the connection is clearly fast enough to justify
// firing multiple parallel background requests.
async function isConnectionFast(): Promise<boolean> {
  try {
    const state = await NetInfo.fetch();
    if (!state.isConnected) return false;
    if (state.type === 'wifi' || state.type === 'ethernet') return true;
    if (state.type === 'cellular') {
      const gen = (state.details as { cellularGeneration?: string } | null)?.cellularGeneration;
      return gen === '4g' || gen === '5g';
    }
    return false;
  } catch {
    return false;
  }
}

export type CachedResult<T> =
  | { ok: true;  data: T; fromCache: false }
  | { ok: true;  data: T; fromCache: true; cachedAt: number }
  | { ok: false; error: string; status?: number };

type LiveResult<T> = { ok: true; data: T } | { ok: false; error: string; status?: number };

function offlineError(group: ApiGroup): string {
  return `No saved ${group} content yet. Connect to the internet to load content for the first time.`;
}

async function fetchWithCache<T>(
  group: ApiGroup,
  cacheKey: string,
  fetcher: () => Promise<LiveResult<T>>,
): Promise<CachedResult<T>> {

  // Group is already known-down — skip the network and serve from cache.
  if (!apiHealth.isAvailable(group)) {
    const cached = await contentCache.getIfNotExpired<T>(cacheKey);
    if (cached) return { ok: true, data: cached.data, fromCache: true, cachedAt: cached.fetchedAt };
    return { ok: false, error: offlineError(group) };
  }

  // Cache is fresh — serve it immediately without a network round-trip.
  // This makes tab switches and prefetch hits instant.
  const existing = await contentCache.get<T>(cacheKey);
  if (existing && contentCache.freshness(cacheKey, existing) === 'fresh') {
    return { ok: true, data: existing.data, fromCache: false };
  }

  const result = await fetcher();

  // Session expired — sign out and surface the error; don't cache.
  if (!result.ok && result.status === 401) {
    authEvents.emitSessionExpiry();
    return { ok: false, error: 'Session expired. Please sign in again.', status: 401 };
  }

  if (result.ok) {
    await contentCache.set(cacheKey, result.data);
    return { ok: true, data: result.data, fromCache: false };
  }

  // Live call failed — mark group down and try cache.
  apiHealth.markDown(group);
  const cached = await contentCache.getIfNotExpired<T>(cacheKey);
  if (cached) return { ok: true, data: cached.data, fromCache: true, cachedAt: cached.fetchedAt };

  return { ok: false, error: offlineError(group) };
}

export const cachedApi = {

  forums: {
    list(filter: string, page = 0, sinceDate?: string): Promise<CachedResult<PaginatedResult<ForumTopic>>> {
      const key = `forums:list:${filter}:${page}:${sinceDate ?? ''}`;
      return fetchWithCache('forums', key, () => api.forums.list(filter, page, sinceDate));
    },

    topicsById(ids: string[]): Promise<CachedResult<PaginatedResult<ForumTopic>>> {
      // Sort IDs so the cache key is stable regardless of insertion order.
      const key = `forums:topicsById:${[...ids].sort().join(',')}`;
      return fetchWithCache('forums', key, () => api.forums.topicsById(ids));
    },

    topic(id: string): Promise<CachedResult<ForumTopic>> {
      return fetchWithCache('forums', `forums:topic:${id}`, () => api.forums.topic(id));
    },

    topicDetail(id: string): Promise<CachedResult<ForumTopicDetail>> {
      return fetchWithCache('forums', `forums:detail:${id}`, () => api.forums.topicDetail(id));
    },
  },

  podcasts: {
    episodes(page = 0): Promise<CachedResult<PaginatedResult<PodcastEpisode>>> {
      return fetchWithCache('podcasts', `podcasts:episodes:${page}`, () => api.podcasts.episodes(page));
    },

    episode(id: string): Promise<CachedResult<PodcastEpisode>> {
      return fetchWithCache('podcasts', `podcasts:detail:${id}`, () => api.podcasts.episode(id));
    },
  },

  apps: {
    list(page = 0): Promise<CachedResult<PaginatedResult<AppListing>>> {
      return fetchWithCache('apps', `apps:list:${page}`, () => api.apps.list(page));
    },

    updates(page = 0): Promise<CachedResult<PaginatedResult<AppListing>>> {
      return fetchWithCache('apps', `apps:updates:${page}`, () => api.apps.updates(page));
    },

    detail(id: string): Promise<CachedResult<AppDetail>> {
      return fetchWithCache('apps', `apps:detail:${id}`, () => api.apps.detail(id));
    },
  },

  resources: {
    list(page = 0): Promise<CachedResult<PaginatedResult<Resource>>> {
      return fetchWithCache('resources', `resources:list:${page}`, () => api.resources.list(page));
    },

    detail(id: string): Promise<CachedResult<ResourceDetail>> {
      return fetchWithCache('resources', `resources:detail:${id}`, () => api.resources.detail(id));
    },
  },

  blogs: {
    list(page = 0): Promise<CachedResult<PaginatedResult<BlogPost>>> {
      return fetchWithCache('blogs', `blogs:list:${page}`, () => api.blogs.list(page));
    },

    detail(id: string): Promise<CachedResult<BlogPostDetail>> {
      return fetchWithCache('blogs', `blogs:detail:${id}`, () => api.blogs.detail(id));
    },
  },

  // Fire the first page of every content group simultaneously so the cache is
  // warm before the user navigates to each tab. Skipped on slow or no
  // connection — let user navigation drive those fetches instead.
  // Failures are silenced — this is best-effort warming, not a critical load path.
  async prefetchAll(): Promise<void> {
    const fast = await isConnectionFast();
    if (!fast) return;
    await Promise.allSettled([
      cachedApi.forums.list('Recent', 0),
      cachedApi.podcasts.episodes(0),
      cachedApi.apps.list(0),
      cachedApi.resources.list(0),
      cachedApi.blogs.list(0),
    ]);
  },
};
