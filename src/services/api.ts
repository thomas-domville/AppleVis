/**
 * AppleVis API client
 *
 * Content (forums, podcasts, apps, resources) is served via Drupal JSON:API.
 * Authentication uses Drupal's REST Simple Auth module.
 *
 * WORKING NOW  : all content GET endpoints
 * NEEDS FIX    : POST /user/login?_format=json  (500 server error — developer must fix)
 * NEEDS BUILDING: push tokens, flag/save/follow, account sync, account deletion
 */

import type { ForumTopic, PodcastEpisode, AppListing, Resource } from '../types/content';

const BASE = 'https://www.applevis.com';
const JSONAPI = `${BASE}/jsonapi`;

// Drupal stores files at sites/default/files/
function fileUri(drupalUri: string): string {
  // converts "public://podcasts/ep.mp3" → "https://www.applevis.com/sites/default/files/podcasts/ep.mp3"
  return drupalUri.replace('public://', `${BASE}/sites/default/files/`);
}

// ─── Generic fetch helpers ────────────────────────────────────────────────────

type JsonApiResult<T> = { ok: true; data: T } | { ok: false; error: string; status?: number };

async function jsonApi<T>(path: string, options?: RequestInit): Promise<JsonApiResult<T>> {
  try {
    const res = await fetch(`${JSONAPI}${path}`, {
      headers: { Accept: 'application/vnd.api+json', 'Content-Type': 'application/vnd.api+json' },
      ...options,
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
    const json = await res.json() as T;
    return { ok: true, data: json };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Network error' };
  }
}

async function drupalRest<T>(path: string, options?: RequestInit): Promise<JsonApiResult<T>> {
  try {
    const res = await fetch(`${BASE}${path}`, {
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      ...options,
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
    const json = await res.json() as T;
    return { ok: true, data: json };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Network error' };
  }
}

// ─── Response shape helpers ───────────────────────────────────────────────────

type JsonApiNode = { id: string; attributes: Record<string, any>; relationships: Record<string, any> };
type JsonApiCollection = { data: JsonApiNode[]; included?: JsonApiNode[]; links?: Record<string, any> };

function pageParams(page: number, limit = 20): string {
  return `page[limit]=${limit}&page[offset]=${page * limit}`;
}

// ─── Forums ───────────────────────────────────────────────────────────────────

function mapForum(node: JsonApiNode): ForumTopic {
  const a = node.attributes;
  return {
    id: node.id,
    title: a.title ?? '',
    meta: `${a.comment_forum?.comment_count ?? 0} replies · ${new Date(a.changed).toLocaleDateString()}`,
    authorName: '',
    createdAt: a.created ?? '',
    lastActivityAt: a.changed ?? '',
    replyCount: a.comment_forum?.comment_count ?? 0,
    isUnread: false,      // requires user auth — not available anonymously
    isFollowing: false,   // requires user auth
    isSaved: false,       // local persistence handles this
  };
}

// ─── Podcasts ─────────────────────────────────────────────────────────────────

function mapPodcast(node: JsonApiNode, included: JsonApiNode[] = []): PodcastEpisode {
  const a = node.attributes;

  // Find the audio file via the field_podcast relationship
  const fileId = node.relationships?.field_podcast?.data?.id as string | undefined;
  const fileNode = fileId ? included.find((n) => n.id === fileId) : undefined;
  const rawUri = fileNode?.attributes?.uri?.value as string | undefined;
  const audioUrl = rawUri ? fileUri(rawUri) : '';

  return {
    id: node.id,
    title: a.title ?? '',
    showTitle: 'AppleVis Podcast',
    audioUrl,
    duration: 0,          // duration not stored in Drupal — comes from the audio file metadata
    publishedAt: a.created ?? '',
    description: a.body?.value ?? '',
  };
}

// ─── Apps ─────────────────────────────────────────────────────────────────────

function mapApp(node: JsonApiNode): AppListing {
  const a = node.attributes;
  const appStoreUrl = a.field_link2?.uri ?? a.field_link3?.uri ?? '';
  return {
    id: node.id,
    name: a.title ?? '',
    developer: '',
    platform: 'iOS',
    category: '',
    reviewCount: a.comment_node_ios_app_directory?.comment_count ?? 0,
    lastUpdatedAt: a.changed ?? '',
    appStoreUrl,
    summary: a.body?.summary ?? a.body?.value ?? '',
  };
}

// ─── Resources / Guides ──────────────────────────────────────────────────────

function mapResource(node: JsonApiNode): Resource {
  const a = node.attributes;
  return {
    id: node.id,
    title: a.title ?? '',
    kind: 'guide',
    summary: a.body?.summary ?? a.body?.value ?? '',
    updatedAt: a.changed ?? '',
    url: `${BASE}${a.path?.alias ?? `/node/${a.drupal_internal__nid}`}`,
  };
}

// ─── Public API ───────────────────────────────────────────────────────────────

export const api = {

  forums: {
    async list(filter: string, page = 0) {
      // Anonymous: returns all topics sorted by changed date.
      // "Unread" / "Following" / "Since Last Visit" filters require auth — fall back to Recent.
      const sort = '-changed';
      const res = await jsonApi<JsonApiCollection>(
        `/node/forum?sort=${sort}&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: res.data.data.map(mapForum) };
    },

    async topic(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/forum/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapForum(res.data.data) };
    },

    // ── Requires developer to build (returns 404 today) ──
    markRead: (id: string, token: string) =>
      drupalRest<void>(`/node/${id}/flag/read`, {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
      }),

    follow: (id: string, token: string) =>
      drupalRest<void>(`/node/${id}/flag/follow_content`, {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
      }),

    unfollow: (id: string, token: string) =>
      drupalRest<void>(`/node/${id}/flag/follow_content`, {
        method: 'DELETE',
        headers: { 'X-CSRF-Token': token },
      }),
  },

  podcasts: {
    async episodes(page = 0) {
      // include=field_podcast fetches the audio file in the same request
      const res = await jsonApi<JsonApiCollection>(
        `/node/podcast?sort=-created&include=field_podcast&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: res.data.data.map((n) => mapPodcast(n, res.data.included ?? [])),
      };
    },

    async episode(id: string) {
      const res = await jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(
        `/node/podcast/${id}?include=field_podcast`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: mapPodcast(res.data.data, res.data.included ?? []) };
    },

    // ── Requires developer to build ──
    transcript: (id: string) =>
      drupalRest<{ text: string; vttUrl?: string }>(`/api/v1/podcasts/episodes/${id}/transcript`),
  },

  apps: {
    async list(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: res.data.data.map(mapApp) };
    },

    async listing(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/ios_app_directory/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapApp(res.data.data) };
    },

    async updates(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: res.data.data.map(mapApp) };
    },
  },

  resources: {
    async list(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/guides?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: res.data.data.map(mapResource) };
    },

    async item(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/guides/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapResource(res.data.data) };
    },
  },

  // ─── Authentication ──────────────────────────────────────────────────────────
  // STATUS: POST /user/login?_format=json returns 500 — developer must fix this.
  // The session token endpoint works; the login handler has a server-side error.

  account: {
    async getSessionToken(): Promise<string> {
      const res = await fetch(`${BASE}/session/token`);
      return res.ok ? res.text() : '';
    },

    async signIn(email: string, password: string) {
      return drupalRest<{ current_user: { uid: string; name: string }; csrf_token: string; logout_token: string }>(
        `/user/login?_format=json`,
        {
          method: 'POST',
          body: JSON.stringify({ name: email, pass: password }),
        },
      );
    },

    async signOut(logoutToken: string) {
      return drupalRest<void>(`/user/logout?_format=json&token=${encodeURIComponent(logoutToken)}`, {
        method: 'POST',
      });
    },

    // ── Requires developer to build ──
    registerPushToken: (token: string, csrfToken: string) =>
      drupalRest<void>(`/api/v1/account/push-token`, {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ token }),
      }),

    removePushToken: (token: string, csrfToken: string) =>
      drupalRest<void>(`/api/v1/account/push-token`, {
        method: 'DELETE',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ token }),
      }),

    // Required by App Store — developer must build this endpoint
    deleteAccount: (csrfToken: string) =>
      drupalRest<void>(`/api/v1/account`, {
        method: 'DELETE',
        headers: { 'X-CSRF-Token': csrfToken },
      }),

    // Sync saved items / positions — developer must build this endpoint
    sync: (csrfToken: string, payload: Record<string, unknown>) =>
      drupalRest<{ syncedAt: string }>(`/api/v1/account/sync`, {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify(payload),
      }),
  },
};
