/**
 * AppleVis API client
 *
 * Content (forums, podcasts, apps, resources) is served via Drupal JSON:API.
 * Authentication uses Drupal's REST Simple Auth module.
 *
 * WORKING NOW  : all content GET endpoints, POST /user/login?_format=json
 * NEEDS BUILDING: push tokens, flag/save/follow, account sync, account deletion
 */

import type { ForumTopic, ForumReply, ForumTopicDetail, AppListing, AppDetail, AppReview, Resource, ResourceDetail, PodcastEpisode, PaginatedResult } from '../types/content';

const BASE             = 'https://www.applevis.com';
const JSONAPI          = `${BASE}/jsonapi`;
const FETCH_TIMEOUT_MS = 10_000;
const APP_UA           = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026';
const COMMON_HEADERS   = {
  'User-Agent':      APP_UA,
  'Accept-Language': 'en-US,en;q=0.9',
  'Origin':          BASE,
  'Referer':         `${BASE}/`,
};

function fileUri(drupalUri: string): string {
  return drupalUri.replace('public://', `${BASE}/sites/default/files/`);
}

// ─── Generic fetch helpers ────────────────────────────────────────────────────

type JsonApiResult<T> = { ok: true; data: T } | { ok: false; error: string; status?: number };

async function jsonApi<T>(path: string, options?: RequestInit): Promise<JsonApiResult<T>> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(`${JSONAPI}${path}`, {
      headers: { ...COMMON_HEADERS, Accept: 'application/vnd.api+json', 'Content-Type': 'application/vnd.api+json' },
      ...options,
      signal: ctrl.signal,
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
    const json = await res.json() as T;
    return { ok: true, data: json };
  } catch (err) {
    if (err instanceof Error && err.name === 'AbortError') {
      return { ok: false, error: 'Request timed out.' };
    }
    return { ok: false, error: err instanceof Error ? err.message : 'Network error' };
  } finally {
    clearTimeout(timer);
  }
}

async function drupalRest<T>(path: string, options?: RequestInit): Promise<JsonApiResult<T>> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(`${BASE}${path}`, {
      headers: { ...COMMON_HEADERS, Accept: 'application/json', 'Content-Type': 'application/json', 'Referer': `${BASE}/user/login` },
      ...options,
      signal: ctrl.signal,
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
    const json = await res.json() as T;
    return { ok: true, data: json };
  } catch (err) {
    if (err instanceof Error && err.name === 'AbortError') {
      return { ok: false, error: 'Request timed out.' };
    }
    return { ok: false, error: err instanceof Error ? err.message : 'Network error' };
  } finally {
    clearTimeout(timer);
  }
}

// ─── Response shape helpers ───────────────────────────────────────────────────

type JsonApiNode = { id: string; attributes: Record<string, any>; relationships: Record<string, any> };
type JsonApiCollection = { data: JsonApiNode[]; included?: JsonApiNode[]; links?: Record<string, any> };

function pageParams(page: number, limit = 20): string {
  return `page[limit]=${limit}&page[offset]=${page * limit}`;
}

function hasNextPage(collection: JsonApiCollection): boolean {
  // Drupal JSON:API includes a `links.next` object when another page exists.
  return !!collection.links?.next;
}

// ─── Forums ───────────────────────────────────────────────────────────────────

function mapForum(node: JsonApiNode, included: JsonApiNode[] = []): ForumTopic {
  const a = node.attributes;
  const uidId = (node.relationships?.uid?.data as { id?: string } | undefined)?.id;
  const userNode = uidId ? included.find((n) => n.id === uidId) : undefined;
  const authorName = String(
    userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? '',
  );
  return {
    id: node.id,
    title: a.title ?? '',
    meta: `${a.comment_forum?.comment_count ?? 0} replies · ${new Date(a.changed).toLocaleDateString()}`,
    authorName,
    createdAt: a.created ?? '',
    lastActivityAt: a.changed ?? '',
    replyCount: a.comment_forum?.comment_count ?? 0,
    isUnread: false,
    isFollowing: false,
    isSaved: false,
  };
}

// ─── Podcasts ─────────────────────────────────────────────────────────────────

function mapPodcast(node: JsonApiNode, included: JsonApiNode[] = []): PodcastEpisode {
  const a = node.attributes;
  const fileId  = node.relationships?.field_podcast?.data?.id as string | undefined;
  const fileNode = fileId ? included.find((n) => n.id === fileId) : undefined;
  const rawUri  = fileNode?.attributes?.uri?.value as string | undefined;
  return {
    id: node.id,
    title: a.title ?? '',
    showTitle: 'AppleVis Podcast',
    audioUrl: rawUri ? fileUri(rawUri) : '',
    duration: 0,
    publishedAt: a.created ?? '',
    description: a.body?.value ?? '',
  };
}

// ─── Apps ─────────────────────────────────────────────────────────────────────

function mapApp(node: JsonApiNode): AppListing {
  const a = node.attributes;
  return {
    id: node.id,
    name: a.title ?? '',
    developer: '',
    platform: 'iOS',
    category: '',
    reviewCount: a.comment_node_ios_app_directory?.comment_count ?? 0,
    lastUpdatedAt: a.changed ?? '',
    appStoreUrl: a.field_link2?.uri ?? a.field_link3?.uri ?? '',
    summary: a.body?.summary ?? a.body?.value ?? '',
  };
}

// ─── Forum replies / comments ────────────────────────────────────────────────

function mapComment(node: JsonApiNode): ForumReply {
  const a = node.attributes;
  return {
    id: node.id,
    authorName: (a.name as string | undefined) ?? 'Community Member',
    authorId: (node.relationships?.uid?.data as { id: string } | undefined)?.id ?? '',
    body: (a.comment_body?.processed ?? a.comment_body?.value ?? '') as string,
    createdAt: (a.created ?? '') as string,
  };
}

// ─── App reviews ─────────────────────────────────────────────────────────────

function mapAppReview(node: JsonApiNode): AppReview {
  const a = node.attributes;
  return {
    id: node.id,
    authorName: (a.name as string | undefined) ?? 'Community Member',
    body: (a.comment_body?.processed ?? a.comment_body?.value ?? '') as string,
    createdAt: (a.created ?? '') as string,
    appVersion: (a.field_app_version ?? undefined) as string | undefined,
    platform: (a.field_platform ?? undefined) as string | undefined,
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
    async list(filter: string, page = 0, sinceDate?: string) {
      const sort = filter === 'New' ? '-created' : '-changed';
      let path = `/node/forum?sort=${sort}&${pageParams(page)}&include=uid`;
      if (sinceDate) {
        const encoded = encodeURIComponent(sinceDate);
        path +=
          `&filter[since][condition][path]=changed` +
          `&filter[since][condition][operator]=%3E` +
          `&filter[since][condition][value]=${encoded}`;
      }
      const res = await jsonApi<JsonApiCollection>(path);
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map((n) => mapForum(n, res.data.included ?? [])), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<ForumTopic>,
      };
    },

    // Fetch a batch of topics by their UUIDs in a single request.
    // Used by the "Following" filter to avoid N individual calls.
    // Capped at 50 IDs to keep URL length manageable.
    async topicsById(ids: string[]) {
      if (ids.length === 0) return { ok: true as const, data: { items: [], hasMore: false } satisfies PaginatedResult<ForumTopic> };
      const capped = ids.slice(0, 50);
      const valueParams = capped
        .map((id, i) => `filter[ids][condition][value][${i}]=${encodeURIComponent(id)}`)
        .join('&');
      const path =
        `/node/forum` +
        `?filter[ids][condition][path]=id` +
        `&filter[ids][condition][operator]=IN` +
        `&${valueParams}` +
        `&page[limit]=${capped.length}` +
        `&include=uid`;
      const res = await jsonApi<JsonApiCollection>(path);
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map((n) => mapForum(n, res.data.included ?? [])), hasMore: false } satisfies PaginatedResult<ForumTopic>,
      };
    },

    async topic(id: string) {
      const res = await jsonApi<JsonApiCollection & { data: JsonApiNode }>(`/node/forum/${id}?include=uid`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapForum(res.data.data, res.data.included ?? []) };
    },

    /**
     * Fetch a single topic with its full body text and all replies.
     *
     * NOTE TO DRUPAL DEVELOPER:
     *   Confirm the comment entity type name and filter path.
     *   Common: /jsonapi/comment/comment?filter[entity_id.id]=[uuid]
     *   May need: &sort=created&page[limit]=100&include=uid
     *   The topic body comes from node.attributes.body.value (or .processed).
     */
    async topicDetail(id: string): Promise<
      { ok: true; data: ForumTopicDetail } | { ok: false; error: string }
    > {
      const [topicRes, commentsRes] = await Promise.all([
        jsonApi<{ data: JsonApiNode }>(`/node/forum/${id}`),
        jsonApi<JsonApiCollection>(`/comment/comment?filter[entity_id.id]=${id}&sort=created&page[limit]=100`),
      ]);

      if (!topicRes.ok) return topicRes;

      const topic = mapForum(topicRes.data.data);
      const body = String(topicRes.data.data.attributes.body?.value ?? topicRes.data.data.attributes.body?.processed ?? '');
      const url = `${BASE}${topicRes.data.data.attributes.path?.alias ?? `/node/${topicRes.data.data.attributes.drupal_internal__nid}`}`;
      const replies: ForumReply[] = commentsRes.ok ? commentsRes.data.data.map(mapComment) : [];

      return { ok: true, data: { ...topic, body, replies, url } };
    },

    /**
     * Submit a reply to a forum topic.
     *
     * NOTE TO DRUPAL DEVELOPER:
     *   Confirm: comment content type name, field names, entity relationship type.
     *   Standard Drupal JSON:API comment POST:
     *     type: 'comment--comment' (may differ per content type)
     *     relationships.entity_id: { type: 'node--forum', id: topicId }
     */
    async submitReply(topicId: string, body: string, csrfToken: string) {
      return jsonApi<{ data: JsonApiNode }>('/comment/comment', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'comment--comment',
            attributes: {
              subject: 'Reply',
              comment_body: { value: body, format: 'basic_html' },
            },
            relationships: {
              entity_id: { data: { type: 'node--forum', id: topicId } },
              comment_type: { data: { type: 'comment_type--comment_type', id: 'comment' } },
            },
          },
        }),
      });
    },

    markRead: (id: string, token: string) =>
      drupalRest<void>(`/node/${id}/flag/read`, { method: 'POST', headers: { 'X-CSRF-Token': token } }),

    follow: (id: string, token: string) =>
      drupalRest<void>(`/node/${id}/flag/follow_content`, { method: 'POST', headers: { 'X-CSRF-Token': token } }),

    unfollow: (id: string, token: string) =>
      drupalRest<void>(`/node/${id}/flag/follow_content`, { method: 'DELETE', headers: { 'X-CSRF-Token': token } }),
  },

  podcasts: {
    async episodes(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/podcast?sort=-created&include=field_podcast&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: {
          items: res.data.data.map((n) => mapPodcast(n, res.data.included ?? [])),
          hasMore: hasNextPage(res.data),
        } satisfies PaginatedResult<PodcastEpisode>,
      };
    },

    async episode(id: string) {
      const res = await jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(
        `/node/podcast/${id}?include=field_podcast`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: mapPodcast(res.data.data, res.data.included ?? []) };
    },

    transcript: (id: string) =>
      drupalRest<{ text: string; vttUrl?: string }>(`/api/v1/podcasts/episodes/${id}/transcript`),
  },

  apps: {
    async list(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map(mapApp), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<AppListing>,
      };
    },

    async listing(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/ios_app_directory/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapApp(res.data.data) };
    },

    /**
     * Fetch a single app listing with its full body and all reviews.
     * NOTE TO DRUPAL DEVELOPER: confirm comment entity type for app reviews.
     */
    async detail(id: string): Promise<
      { ok: true; data: AppDetail } | { ok: false; error: string }
    > {
      const [appRes, reviewsRes] = await Promise.all([
        jsonApi<{ data: JsonApiNode }>(`/node/ios_app_directory/${id}`),
        jsonApi<JsonApiCollection>(`/comment/comment?filter[entity_id.id]=${id}&sort=-created&page[limit]=50`),
      ]);

      if (!appRes.ok) return appRes;

      const app = mapApp(appRes.data.data);
      const body = String(appRes.data.data.attributes.body?.value ?? appRes.data.data.attributes.body?.processed ?? '');
      const reviews: AppReview[] = reviewsRes.ok ? reviewsRes.data.data.map(mapAppReview) : [];

      return { ok: true, data: { ...app, body, reviews } };
    },

    async updates(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map(mapApp), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<AppListing>,
      };
    },
  },

  resources: {
    async list(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/guides?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map(mapResource), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<Resource>,
      };
    },

    async item(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/guides/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapResource(res.data.data) };
    },

    /**
     * Fetch a resource with its full body text.
     * NOTE TO DRUPAL DEVELOPER: confirm body field name for guides content type.
     */
    async detail(id: string): Promise<
      { ok: true; data: ResourceDetail } | { ok: false; error: string }
    > {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/guides/${id}`);
      if (!res.ok) return res;
      const resource = mapResource(res.data.data);
      const body = String(res.data.data.attributes.body?.value ?? res.data.data.attributes.body?.processed ?? '');
      const authorName = String(res.data.data.attributes.field_author ?? '');
      return { ok: true, data: { ...resource, body, authorName: authorName || undefined } };
    },
  },

  // ─── Search ──────────────────────────────────────────────────────────────────

  search: {
    async forums(query: string) {
      const q = encodeURIComponent(query.trim());
      const res = await jsonApi<JsonApiCollection>(
        `/node/forum?filter[title][operator]=CONTAINS&filter[title][value]=${q}&sort=-changed&page[limit]=10`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: { items: res.data.data.map((n) => mapForum(n, res.data.included ?? [])), hasMore: false } satisfies PaginatedResult<ForumTopic> };
    },

    async apps(query: string) {
      const q = encodeURIComponent(query.trim());
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?filter[title][operator]=CONTAINS&filter[title][value]=${q}&sort=-changed&page[limit]=10`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: { items: res.data.data.map(mapApp), hasMore: false } satisfies PaginatedResult<AppListing> };
    },

    async resources(query: string) {
      const q = encodeURIComponent(query.trim());
      const res = await jsonApi<JsonApiCollection>(
        `/node/guides?filter[title][operator]=CONTAINS&filter[title][value]=${q}&sort=-changed&page[limit]=10`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: { items: res.data.data.map(mapResource), hasMore: false } satisfies PaginatedResult<Resource> };
    },
  },

  // ─── Authentication ──────────────────────────────────────────────────────────

  account: {
    async getSessionToken(): Promise<string> {
      const res = await fetch(`${BASE}/session/token`);
      return res.ok ? res.text() : '';
    },

    async signIn(email: string, password: string) {
      return drupalRest<{ current_user: { uid: string; name: string }; csrf_token: string; logout_token: string }>(
        `/user/login?_format=json`,
        { method: 'POST', body: JSON.stringify({ name: email, pass: password }) },
      );
    },

    async signOut(logoutToken: string) {
      return drupalRest<void>(`/user/logout?_format=json&token=${encodeURIComponent(logoutToken)}`, {
        method: 'POST',
      });
    },

    registerPushToken: (token: string, csrfToken: string) =>
      drupalRest<void>(`/api/v1/account/push-token`, {
        method: 'POST', headers: { 'X-CSRF-Token': csrfToken }, body: JSON.stringify({ token }),
      }),

    removePushToken: (token: string, csrfToken: string) =>
      drupalRest<void>(`/api/v1/account/push-token`, {
        method: 'DELETE', headers: { 'X-CSRF-Token': csrfToken }, body: JSON.stringify({ token }),
      }),

    deleteAccount: (csrfToken: string) =>
      drupalRest<void>(`/api/v1/account`, {
        method: 'DELETE', headers: { 'X-CSRF-Token': csrfToken },
      }),

    sync: (csrfToken: string, payload: Record<string, unknown>) =>
      drupalRest<{ syncedAt: string }>(`/api/v1/account/sync`, {
        method: 'POST', headers: { 'X-CSRF-Token': csrfToken }, body: JSON.stringify(payload),
      }),
  },
};
