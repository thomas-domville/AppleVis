/**
 * AppleVis API client
 *
 * Content (forums, podcasts, apps, resources) is served via Drupal JSON:API.
 * Authentication uses Drupal's REST Simple Auth module.
 *
 * WORKING NOW  : all content GET endpoints, login, account deletion, push token
 * STILL NEEDED : follow/unfollow server-side flag (subscribe_node), search API path
 */

import { relativeTime } from '../utils/relativeTime';
import type { ForumTopic, ForumReply, ForumTopicDetail, AppListing, AppDetail, AppReview, Resource, ResourceDetail, PodcastEpisode, PaginatedResult, BlogPost, SearchResult } from '../types/content';

// ─── Phase 4 gate constants ───────────────────────────────────────────────────
// Replace each null / placeholder with the confirmed value from the Drupal
// developer, then flip the corresponding gated flag in the UI.
//
// Gate 1 — Blog content type:
//   Confirmed by live API inspection: Drupal content type is 'blog2'.
const BLOG_CONTENT_TYPE: string | null = 'blog2';
//
// Gate 2 — Forum Apple-related filter:
//   Field path confirmed by live API: 'taxonomy_forums.name'.
//   Value TBD — no single term is named 'Apple'. The forum has: iOS and iPadOS,
//   macOS and Mac Apps, Apple Beta Releases, Apple Hardware and Compatible
//   Accessories, Other Apple Chat, tvOS and Apple TV Apps, watchOS and Apple
//   Watch Apps, Braille on Apple Products, Low Vision Accessibility on Apple
//   Products, iOS and iPadOS Gaming, App Development and Programming,
//   Accessibility Advocacy, Assistive Technology, Site News, Android, Windows,
//   Smart Home Tech and Gadgets.
//   TODO: ask developer what term value(s) define "Apple-related" for this filter,
//   or switch to a NOT IN exclusion for Android / Windows.
const FORUM_APPLE_FILTER_PATH: string | null = 'taxonomy_forums.name';
const FORUM_APPLE_FILTER_VALUE = 'Apple';
//
// Gate 3 — Full-text Search API:
//   Set to the REST path prefix, e.g. '/search_api/index/content?fulltext=' or
//   '/views/site_search/page_1?fulltext='.
//   Affects: Discover tab search (upgrades from title-CONTAINS to full-text).
const SEARCH_API_PATH: string | null = null;

const BASE             = 'https://www.applevis.com';
const JSONAPI          = `${BASE}/jsonapi`;
const FETCH_TIMEOUT_MS = 10_000;
const APP_UA           = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AppleVis/2026';
const COMMON_HEADERS   = {
  'User-Agent':      APP_UA,
  'Accept-Language': 'en-US,en;q=0.9',
  'Origin':          BASE,
  'Referer':         `${BASE}/`,
  'X-App-Auth':      '2ff01dc7bf35469d93c6',
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
    meta: `${a.comment_forum?.comment_count ?? 0} replies · ${relativeTime(a.changed)}`,
    authorName,
    createdAt: a.created ?? '',
    lastActivityAt: a.changed ?? '',
    replyCount: a.comment_forum?.comment_count ?? 0,
    isUnread: false,
    isFollowing: false,
    isSaved: false,
    url: a.path?.alias ? `${BASE}${a.path.alias}` : undefined,
  };
}

// ─── Podcasts ─────────────────────────────────────────────────────────────────

// NOTE TO DRUPAL DEVELOPER:
//   Please confirm the exact field names for:
//   (1) Episode duration in seconds  — tried: field_duration, field_podcast_duration, field_episode_duration
//   (2) Episode artwork/thumbnail    — tried: field_image, field_artwork, field_thumbnail
//   (3) Transcript URL               — tried: field_transcript_url, field_vtt_url
//   (4) Chapter markers              — needs a relationship include (e.g. field_chapters → paragraph)
//       Each chapter paragraph should expose: title (string) and field_start_time (float, seconds)
//   Update mapPodcast and the episodes() query below once confirmed.

function mapPodcast(node: JsonApiNode, included: JsonApiNode[] = []): PodcastEpisode {
  const a = node.attributes;

  // Audio file
  const fileId   = node.relationships?.field_podcast?.data?.id as string | undefined;
  const fileNode = fileId ? included.find((n) => n.id === fileId) : undefined;
  const rawUri   = fileNode?.attributes?.uri?.value as string | undefined;

  // Duration — confirmed by live API inspection: Drupal does NOT store episode
  // duration on the node or the file entity. Duration must be resolved client-side
  // from the audio file (AVFoundation / expo-av asset duration).
  const duration = 0;

  // Artwork — confirmed by live API: no per-episode artwork field exists on
  // node--podcast. The app uses a static show artwork asset.
  const artworkUrl: string | undefined = undefined;

  // Transcript URL — field not found on live nodes; may not be in use.
  const transcriptUrl = (a.field_transcript_url ?? a.field_vtt_url) as string | undefined;

  // Chapters — no field_chapters relationship exists on live nodes.
  const chapterRefs = (node.relationships?.field_chapters?.data as { id: string }[] | undefined) ?? [];
  const chapters = chapterRefs.length > 0
    ? chapterRefs
        .map((ref) => included.find((n) => n.id === ref.id))
        .filter((n): n is JsonApiNode => !!n)
        .map((n) => ({
          title: String(n.attributes.title ?? n.attributes.field_title ?? ''),
          startTime: parseFloat(String(n.attributes.field_start_time ?? n.attributes.field_time ?? 0)) || 0,
        }))
        .filter((c) => c.title)
        .sort((a, b) => a.startTime - b.startTime)
    : undefined;

  return {
    id: node.id,
    title: a.title ?? '',
    showTitle: 'AppleVis Podcast',
    audioUrl: rawUri ? fileUri(rawUri) : '',
    duration,
    publishedAt: a.created ?? '',
    lastActivityAt: (a.changed as string | undefined) ?? undefined,
    description: a.body?.value ?? '',
    artworkUrl,
    transcriptUrl: transcriptUrl || undefined,
    chapters,
    url: a.path?.alias ? `${BASE}${a.path.alias}` : undefined,
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
    url: a.path?.alias ? `${BASE}${a.path.alias}` : undefined,
  };
}

// ─── Blog posts (Phase 4 gate) ───────────────────────────────────────────────
// NOTE TO DRUPAL DEVELOPER: confirm comment field name on blog nodes
// (likely comment_node_blog or comment — check with field_info_field()).

function mapBlog(node: JsonApiNode, included: JsonApiNode[] = []): BlogPost {
  const a = node.attributes;
  const uidId = (node.relationships?.uid?.data as { id?: string } | undefined)?.id;
  const userNode = uidId ? included.find((n) => n.id === uidId) : undefined;
  const authorName = String(
    userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? '',
  );
  return {
    id: node.id,
    title: a.title ?? '',
    authorName,
    publishedAt: a.created ?? '',
    lastActivityAt: (a.changed as string | undefined) ?? undefined,
    summary: a.body?.summary ?? a.body?.value ?? '',
    commentCount: a.comment_node_blog2?.comment_count ?? 0,
    url: `${BASE}${a.path?.alias ?? `/node/${a.drupal_internal__nid}`}`,
  };
}

// ─── Forum replies / comments ────────────────────────────────────────────────

function mapComment(node: JsonApiNode, included: JsonApiNode[] = []): ForumReply {
  const a = node.attributes;
  const uidId = (node.relationships?.uid?.data as { id?: string } | undefined)?.id;
  const userNode = uidId ? included.find((n) => n.id === uidId) : undefined;
  const authorName = String(
    userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? a.name ?? '',
  );
  return {
    id: node.id,
    authorName,
    authorId: uidId ?? '',
    body: (a.comment_body?.processed ?? a.comment_body?.value ?? '') as string,
    createdAt: (a.created ?? '') as string,
  };
}

// ─── App reviews ─────────────────────────────────────────────────────────────

function mapAppReview(node: JsonApiNode, included: JsonApiNode[] = []): AppReview {
  const a = node.attributes;
  const uidId = (node.relationships?.uid?.data as { id?: string } | undefined)?.id;
  const userNode = uidId ? included.find((n) => n.id === uidId) : undefined;
  const authorName = String(
    userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? a.name ?? '',
  );
  return {
    id: node.id,
    authorName,
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

// ─── Auth helpers ────────────────────────────────────────────────────────────

async function resolveMyUuid(csrfToken: string): Promise<string | null> {
  const res = await jsonApi<{ meta?: { links?: { me?: { meta?: { id?: string } } } } }>('', {
    headers: { 'X-CSRF-Token': csrfToken },
  });
  if (!res.ok) return null;
  return res.data?.meta?.links?.me?.meta?.id ?? null;
}

// ─── Public API ───────────────────────────────────────────────────────────────

export const api = {

  forums: {
    async list(filter: string, page = 0, sinceDate?: string, appleOnly?: boolean) {
      const sort = filter === 'New' ? '-created' : '-changed';
      let path = `/node/forum?sort=${sort}&${pageParams(page)}&include=uid`;
      if (sinceDate) {
        const encoded = encodeURIComponent(sinceDate);
        path +=
          `&filter[since][condition][path]=changed` +
          `&filter[since][condition][operator]=%3E` +
          `&filter[since][condition][value]=${encoded}`;
      }
      // Gate 2 — Apple-related filter. Active only once FORUM_APPLE_FILTER_PATH is set.
      if (appleOnly && FORUM_APPLE_FILTER_PATH) {
        path +=
          `&filter[apple][condition][path]=${encodeURIComponent(FORUM_APPLE_FILTER_PATH)}` +
          `&filter[apple][condition][operator]=%3D` +
          `&filter[apple][condition][value]=${encodeURIComponent(FORUM_APPLE_FILTER_VALUE)}`;
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
        jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(`/node/forum/${id}?include=uid,taxonomy_forums`),
        jsonApi<JsonApiCollection>(`/comment/comment_forum?filter[entity_id.id]=${id}&sort=created&page[limit]=100&include=uid`),
      ]);

      if (!topicRes.ok) return topicRes;

      const topic = mapForum(topicRes.data.data, topicRes.data.included ?? []);
      const body = String(topicRes.data.data.attributes.body?.value ?? topicRes.data.data.attributes.body?.processed ?? '');
      const url = `${BASE}${topicRes.data.data.attributes.path?.alias ?? `/node/${topicRes.data.data.attributes.drupal_internal__nid}`}`;
      const replies: ForumReply[] = commentsRes.ok ? commentsRes.data.data.map((n) => mapComment(n, commentsRes.data.included ?? [])) : [];

      // NOTE TO DRUPAL DEVELOPER:
      //   category — confirm taxonomy field: field_forum.name, field_category.name, or taxonomy_forums.name
      //   viewCount — confirm view count field: field_view_count, totalcount, or similar
      const n = topicRes.data.data;
      // Category: confirmed by live API — relationship is 'taxonomy_forums',
      // resolved via include. The included term name is in its own attributes.name.
      const taxId = (n.relationships?.taxonomy_forums?.data as { id?: string } | undefined)?.id;
      const taxTerm = taxId ? (topicRes.data.included ?? []).find((inc) => inc.id === taxId) : undefined;
      const category = (taxTerm?.attributes?.name ?? undefined) as string | undefined;
      const viewCount = (
        n.attributes.field_view_count ??
        n.attributes.totalcount ??
        undefined
      ) as number | undefined;

      return { ok: true, data: { ...topic, body, replies, url, category, viewCount } };
    },

    /**
     * Create a new forum topic.
     *
     * NOTE TO DRUPAL DEVELOPER:
     *   Confirm: node type name ('node--forum'?), body field name, any required taxonomy.
     *   Standard Drupal JSON:API node POST:
     *     type: 'node--forum' (may differ — confirm with dev)
     *     attributes.title: topic subject line
     *     attributes.body: { value, format: 'basic_html' }
     */
    async submitNewTopic(title: string, body: string, csrfToken: string) {
      return jsonApi<{ data: JsonApiNode }>('/node/forum', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'node--forum',
            attributes: {
              title,
              body: { value: body, format: 'basic_html' },
            },
          },
        }),
      });
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

    // follow — creates a flagging--subscribe_node entity via JSON:API.
    // The flag machine name on this site is 'subscribe_node' (confirmed by live API).
    async follow(nodeUuid: string, token: string) {
      return jsonApi<{ data: JsonApiNode }>('/flagging/subscribe_node', {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
        body: JSON.stringify({
          data: {
            type: 'flagging--subscribe_node',
            relationships: {
              flagged_entity: { data: { type: 'node--forum', id: nodeUuid } },
            },
          },
        }),
      });
    },

    // unfollow — resolves the flagging UUID first, then deletes it.
    async unfollow(nodeUuid: string, token: string) {
      const listRes = await jsonApi<JsonApiCollection>(
        `/flagging/subscribe_node?filter[flagged_entity.id]=${nodeUuid}`,
      );
      if (!listRes.ok) return listRes;
      const flagging = listRes.data.data[0];
      if (!flagging) return { ok: true as const, data: undefined };
      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
      try {
        const res = await fetch(`${JSONAPI}/flagging/subscribe_node/${flagging.id}`, {
          method: 'DELETE',
          headers: { ...COMMON_HEADERS, 'Content-Type': 'application/vnd.api+json', 'X-CSRF-Token': token },
          signal: ctrl.signal,
        });
        if (!res.ok) return { ok: false as const, error: `HTTP ${res.status}` };
        return { ok: true as const, data: undefined };
      } catch (err) {
        if (err instanceof Error && err.name === 'AbortError') return { ok: false as const, error: 'Request timed out.' };
        return { ok: false as const, error: err instanceof Error ? err.message : 'Network error' };
      } finally {
        clearTimeout(timer);
      }
    },
  },

  podcasts: {
    async episodes(page = 0, sort: '-created' | '-changed' = '-created') {
      const res = await jsonApi<JsonApiCollection>(
        `/node/podcast?sort=${sort}&include=field_podcast&${pageParams(page)}`,
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

    // Episode comments — confirmed bundle name: comment_node_podcast
    async comments(episodeId: string) {
      const res = await jsonApi<JsonApiCollection>(
        `/comment/comment_node_podcast?filter[entity_id.id]=${episodeId}&sort=created&page[limit]=100&include=uid`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: res.data.data.map((n) => mapComment(n, res.data.included ?? [])),
      };
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
        jsonApi<JsonApiCollection>(`/comment/comment_node_ios_app_directory?filter[entity_id.id]=${id}&sort=-created&page[limit]=50&include=uid`),
      ]);

      if (!appRes.ok) return appRes;

      const app = mapApp(appRes.data.data);
      const body = String(appRes.data.data.attributes.body?.value ?? appRes.data.data.attributes.body?.processed ?? '');
      const reviews: AppReview[] = reviewsRes.ok ? reviewsRes.data.data.map((n) => mapAppReview(n, reviewsRes.data.included ?? [])) : [];

      // NOTE TO DRUPAL DEVELOPER:
      //   reportedIssueCount — confirm field: field_reported_issues, field_issue_count, or similar
      const reportedIssueCount = (
        appRes.data.data.attributes.field_reported_issues ??
        appRes.data.data.attributes.field_issue_count ??
        undefined
      ) as number | undefined;

      return { ok: true, data: { ...app, body, reviews, reportedIssueCount } };
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

  // ─── Blogs (Phase 4 gate) ────────────────────────────────────────────────────
  // Active once BLOG_CONTENT_TYPE is set to the confirmed Drupal resource type.

  blogs: {
    async list(page = 0) {
      if (!BLOG_CONTENT_TYPE) return { ok: false as const, error: 'BLOG_NOT_CONFIGURED' };
      const res = await jsonApi<JsonApiCollection>(
        `/node/${BLOG_CONTENT_TYPE}?sort=-changed&${pageParams(page)}&include=uid`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map((n) => mapBlog(n, res.data.included ?? [])), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<BlogPost>,
      };
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

    // Gate 3 — Full-text search across all content types via Drupal Search API.
    // Returns 'SEARCH_NOT_CONFIGURED' when SEARCH_API_PATH is null, so callers
    // can fall back to per-type title-CONTAINS search in the meantime.
    async fullText(query: string): Promise<{ ok: true; data: SearchResult[] } | { ok: false; error: string }> {
      if (!SEARCH_API_PATH) return { ok: false, error: 'SEARCH_NOT_CONFIGURED' };
      const q   = encodeURIComponent(query.trim());
      const res = await drupalRest<any[]>(`${SEARCH_API_PATH}${q}`);
      if (!res.ok) return res;
      const results: SearchResult[] = (Array.isArray(res.data) ? res.data : []).map((item: any) => ({
        id:          String(item.id ?? item.nid ?? item.uuid ?? ''),
        contentType: (item.type ?? item.content_type ?? 'topic') as SearchResult['contentType'],
        title:       String(item.title ?? item.name ?? ''),
        summary:     (item.body ?? item.summary ?? item.field_summary ?? undefined) as string | undefined,
        url:         String(item.url ?? item.path ?? ''),
        updatedAt:   String(item.changed ?? item.updated ?? ''),
      }));
      return { ok: true, data: results };
    },
  },

  // ─── Authentication ──────────────────────────────────────────────────────────

  account: {
    async getSessionToken(): Promise<string> {
      const res = await fetch(`${BASE}/session/token`, { headers: COMMON_HEADERS });
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

    async registerPushToken(pushToken: string, csrfToken: string) {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false as const, error: 'Could not resolve account ID.' };
      return jsonApi<void>(`/user/user/${uuid}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ data: { type: 'user--user', id: uuid, attributes: { field_push_token: pushToken } } }),
      });
    },

    async removePushToken(csrfToken: string) {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false as const, error: 'Could not resolve account ID.' };
      return jsonApi<void>(`/user/user/${uuid}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ data: { type: 'user--user', id: uuid, attributes: { field_push_token: '' } } }),
      });
    },

    async deleteAccount(csrfToken: string): Promise<JsonApiResult<undefined>> {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false, error: 'Could not resolve account ID from server.' };

      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
      try {
        const res = await fetch(`${JSONAPI}/user/user/${uuid}`, {
          method: 'DELETE',
          headers: { ...COMMON_HEADERS, 'Content-Type': 'application/vnd.api+json', 'X-CSRF-Token': csrfToken },
          signal: ctrl.signal,
        });
        if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
        return { ok: true, data: undefined };
      } catch (err) {
        if (err instanceof Error && err.name === 'AbortError') return { ok: false, error: 'Request timed out.' };
        return { ok: false, error: err instanceof Error ? err.message : 'Network error' };
      } finally {
        clearTimeout(timer);
      }
    },

    sync: (csrfToken: string, payload: Record<string, unknown>) =>
      drupalRest<{ syncedAt: string }>(`/api/v1/account/sync`, {
        method: 'POST', headers: { 'X-CSRF-Token': csrfToken }, body: JSON.stringify(payload),
      }),
  },
};
