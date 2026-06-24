/**
 * AppleVis API client
 *
 * Content (forums, podcasts, apps, resources) is served via Drupal JSON:API.
 * Authentication uses Drupal's REST Simple Auth module.
 *
 * WORKING NOW  : all content GET/POST endpoints, login, follow/unfollow, push token
 * STILL NEEDED : full-text search API path, app categories, apple-only filter value
 */

import { relativeTime } from '../utils/relativeTime';
import { IOS_PUBLIC_CATEGORY_PATHS } from '../data/appDirectory';
import type { ForumTopic, ForumReply, ForumTopicDetail, AppListing, AppDetail, AppReview, Resource, ResourceDetail, PodcastEpisode, PodcastTag, PaginatedResult, BlogPost, BlogPostDetail, SearchResult, AppCategoryProbe, AppCategory, AppPlatform, BugReport, BugReportDetail } from '../types/content';

// ─── Phase 4 gate constants ───────────────────────────────────────────────────
// Replace each null / placeholder with the confirmed value from the Drupal
// developer, then flip the corresponding gated flag in the UI.
//
// Gate 1 — Blog content type:
//   Confirmed by live API inspection: Drupal content type is 'blog2'.
const BLOG_CONTENT_TYPE: string | null = 'blog2';
//
// Gate 2 — Forum Apple-related filter:
//   Non-Apple forum TIDs confirmed by developer:
//     265 = Windows, 266 = Android, 267 = Smart Home Tech and Gadgets, 269 = Assistive Technology
//   All other 13 forums are Apple-related. Filter uses NOT IN on drupal_internal__tid.
const FORUM_NON_APPLE_TIDS = [265, 266, 267, 269];
//
// Gate 3 — Full-text Search API:
//   Set to the REST path prefix, e.g. '/search_api/index/content?fulltext=' or
//   '/views/site_search/page_1?fulltext='.
//   Affects: Discover tab search (upgrades from title-CONTAINS to full-text).
const SEARCH_API_PATH: string | null = '/api/v1/search';

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

function profileFieldText(value: unknown): string {
  if (typeof value === 'string') return value;
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const nested = record.value ?? record.processed ?? record.uri ?? record.title;
    return typeof nested === 'string' ? nested : '';
  }
  return '';
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
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      let detail = text.trim();
      try {
        const json = detail ? JSON.parse(detail) : null;
        detail = String(json?.message ?? json?.error ?? json?.errors?.[0]?.detail ?? detail);
      } catch { /* keep plain response text */ }
      return {
        ok: false,
        error: detail ? `HTTP ${res.status}: ${detail}` : `HTTP ${res.status}`,
        status: res.status,
      };
    }
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
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      let detail = text.trim();
      try {
        const json = detail ? JSON.parse(detail) : null;
        detail = String(json?.message ?? json?.error ?? json?.errors?.[0]?.detail ?? detail);
      } catch { /* keep plain response text */ }
      return {
        ok: false,
        error: detail ? `HTTP ${res.status}: ${detail}` : `HTTP ${res.status}`,
        status: res.status,
      };
    }
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

async function publicHtml(path: string): Promise<JsonApiResult<string>> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(`${BASE}${path}`, {
      headers: { ...COMMON_HEADERS, Accept: 'text/html' },
      signal: ctrl.signal,
    });
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}`, status: res.status };
    return { ok: true, data: await res.text() };
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

type JsonApiNode = { id: string; type: string; attributes: Record<string, any>; relationships: Record<string, any> };
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
  const taxId = (node.relationships?.taxonomy_forums?.data as { id?: string } | undefined)?.id;
  const taxTerm = taxId ? included.find((n) => n.id === taxId) : undefined;
  const category = (taxTerm?.attributes?.name ?? undefined) as string | undefined;
  // last_comment_timestamp is a Unix timestamp (seconds) of the most recent comment —
  // more precise than the node's changed field which also updates on body edits.
  const lastCommentTs = a.comment_forum?.last_comment_timestamp as number | undefined;
  const lastActivityAt = (lastCommentTs && lastCommentTs > 0)
    ? new Date(lastCommentTs * 1000).toISOString()
    : (a.changed ?? '');
  return {
    id: node.id,
    title: a.title ?? '',
    meta: `${a.comment_forum?.comment_count ?? 0} replies · ${relativeTime(a.changed)}`,
    authorName,
    authorId: uidId ?? '',
    createdAt: a.created ?? '',
    lastActivityAt,
    replyCount: a.comment_forum?.comment_count ?? 0,
    isUnread: false,
    isFollowing: false,
    isSaved: false,
    category,
    url: a.path?.alias ? `${BASE}${a.path.alias}` : undefined,
  };
}

// Converts a forum URL slug to a display category name.
// e.g. "apple-beta-releases" → "Apple Beta Releases"
function categoryFromForumUrl(url: string): string | undefined {
  try {
    const parts = new URL(url).pathname.split('/').filter(Boolean);
    // pathname: /forum/{category-slug}/{topic-slug}
    if (parts.length >= 2 && parts[0] === 'forum') {
      return parts[1].split('-').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
    }
  } catch (_) { /* ignore malformed URLs */ }
  return undefined;
}

// Maps a flat item from GET /api/v1/forums/recent to ForumTopic.
// This endpoint returns correct last_comment_timestamp order (matching the website)
// but does not include author or numeric category ID.
function mapForumFromRecent(item: Record<string, string>): ForumTopic {
  const lastTs = Number(item.last_comment_timestamp ?? 0);
  const lastActivityAt = lastTs > 0
    ? new Date(lastTs * 1000).toISOString()
    : new Date(Number(item.changed) * 1000).toISOString();
  const replyCount = Number(item.comment_count ?? 0);
  return {
    id: item.uuid,
    title: item.title ?? '',
    meta: `${replyCount} repl${replyCount === 1 ? 'y' : 'ies'} · ${relativeTime(lastActivityAt)}`,
    authorName: '',
    createdAt: new Date(Number(item.created) * 1000).toISOString(),
    lastActivityAt,
    replyCount,
    isUnread: false,
    isFollowing: false,
    isSaved: false,
    category: categoryFromForumUrl(item.url ?? ''),
    url: item.url,
  };
}

const RECENT_PAGE_SIZE = 20;

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

  // Author (uid relationship — same pattern as mapComment)
  const uidId    = (node.relationships?.uid?.data as { id?: string } | undefined)?.id;
  const userNode = uidId ? included.find((n) => n.id === uidId) : undefined;
  const authorName = String(
    userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? '',
  ) || undefined;

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

  // Tags — vocabulary_15 relationship confirmed live (2026-06-20 probe)
  const tagRefs = (node.relationships?.taxonomy_vocabulary_15?.data as { id: string }[] | undefined) ?? [];
  const tags: PodcastTag[] = tagRefs
    .map((ref) => included.find((n) => n.id === ref.id))
    .filter((n): n is JsonApiNode => !!n && n.type.startsWith('taxonomy_term'))
    .map((n) => ({
      name: String(n.attributes.name ?? ''),
      tid:  Number(n.attributes.drupal_internal__tid ?? 0),
    }))
    .filter((t) => t.tid && t.name);

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
    authorName,
    tags: tags.length > 0 ? tags : undefined,
  };
}

// ─── Apps ─────────────────────────────────────────────────────────────────────

const APP_CATEGORY_RELATIONSHIP_CANDIDATES = [
  'field_category',
  'field_app_category',
  'field_app_categories',
  'field_directory_category',
  'field_ios_app_category',
  'field_app_store_category',
  'taxonomy_app_category',
  'taxonomy_categories',
];

function relatedTermName(node: JsonApiNode, included: JsonApiNode[], relationshipNames: string[]): string {
  for (const fieldName of relationshipNames) {
    const relData = node.relationships?.[fieldName]?.data;
    const refs = Array.isArray(relData) ? relData : relData ? [relData] : [];
    for (const ref of refs) {
      const term = included.find((n) => n.id === ref.id);
      const name = term?.attributes?.name;
      if (typeof name === 'string' && name.trim()) return name.trim();
    }
  }
  return '';
}

function normaliseAppCategoryName(category: string): string {
  const aliases: Record<string, string> = {
    'Food & Drink': 'Food and Drink',
    'Graphics & Design': 'Graphics and Design',
    'Health & Fitness': 'Health and Fitness',
    'Photo & Video': 'Photo and Video',
    Sports: 'Sports and Activities',
  };
  return aliases[category] ?? category;
}

function decodeHtml(text: string): string {
  return text
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#039;|&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#(\d+);/g, (_m, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_m, code) => String.fromCharCode(parseInt(code, 16)));
}

type DirectoryApiListing = Partial<{
  id: string | number;
  nid: string | number;
  uuid: string;
  name: string;
  title: string;
  developer: string;
  platform: string;
  category: string;
  summary: string;
  body: string;
  url: string;
  path: string;
  appStoreUrl: string;
  app_store_url: string;
  lastUpdatedAt: string;
  last_updated_at: string;
  changed: string;
  updated: string;
  reviewCount: number;
  review_count: number;
  commentCount: number;
  comment_count: number;
  iconUrl: string;
  icon_url: string;
}>;

function mapDirectoryApiListing(item: DirectoryApiListing, platform: string, category: string): AppListing {
  const url = String(item.url ?? item.path ?? '');
  const changed = String(item.lastUpdatedAt ?? item.last_updated_at ?? item.changed ?? item.updated ?? new Date().toISOString());
  return {
    id: String(item.id ?? item.uuid ?? item.nid ?? url),
    name: String(item.name ?? item.title ?? ''),
    developer: String(item.developer ?? ''),
    platform: String(item.platform ?? platform),
    category: String(item.category ?? category),
    reviewCount: Number(item.reviewCount ?? item.review_count ?? item.commentCount ?? item.comment_count ?? 0),
    lastUpdatedAt: changed,
    appStoreUrl: String(item.appStoreUrl ?? item.app_store_url ?? ''),
    iconUrl: item.iconUrl ?? item.icon_url,
    summary: String(item.summary ?? item.body ?? ''),
    url: url || undefined,
  };
}

function textFromHtml(html: string): string {
  return decodeHtml(
    html
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim(),
  );
}

function parsePublicAppDirectory(html: string, category: string): AppListing[] {
  const headingPattern = /<h3[^>]*>\s*<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>\s*<\/h3>/gi;
  const matches = [...html.matchAll(headingPattern)];
  return matches.map((match, index) => {
    const rawHref = match[1] ?? '';
    const url = rawHref.startsWith('http') ? rawHref : `${BASE}${rawHref}`;
    const title = textFromHtml(match[2] ?? '');
    const start = (match.index ?? 0) + match[0].length;
    const end = index + 1 < matches.length ? (matches[index + 1].index ?? html.length) : html.search(/<h2[^>]*>\s*Site Information/i);
    const chunk = html.slice(start, end > start ? end : html.length);
    const text = textFromHtml(chunk);
    const postDate = text.match(/Post Date:\s*((?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s+[A-Z][a-z]+\s+\d{1,2},\s+\d{4})/)?.[1]?.trim();
    const parsedDate = postDate ? new Date(postDate) : null;
    const summary = text
      .replace(/Post Date:\s*[^.]+?\d{4}/, '')
      .replace(/Pagination\s+Page\s+\d+[\s\S]*$/i, '')
      .trim();

    return {
      id: `public:${url}`,
      name: title,
      developer: '',
      platform: 'iOS',
      category,
      reviewCount: 0,
      lastUpdatedAt: parsedDate && !Number.isNaN(parsedDate.getTime()) ? parsedDate.toISOString() : new Date().toISOString(),
      appStoreUrl: '',
      summary,
      url,
    };
  }).filter((app) => app.name && app.url);
}

function inferSearchContentType(path: string): SearchResult['contentType'] {
  if (path.startsWith('/forum/')) return 'topic';
  if (path.startsWith('/podcasts/') || path === '/podcasts') return 'podcast';
  if (path.includes('app-directory') || path.includes('apps/')) return 'app';
  if (path.startsWith('/guides/') || path === '/guides') return 'guide';
  if (path.startsWith('/blog/')) return 'blog';
  if (path.startsWith('/bugs/')) return 'bug';
  if (path.startsWith('/reviews/')) return 'review';
  if (path.startsWith('/new-to-')) return 'page';
  return 'unknown';
}

function parsePublicSearch(html: string): SearchResult[] {
  const headingPattern = /<h3[^>]*>\s*<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>\s*<\/h3>/gi;
  const matches = [...html.matchAll(headingPattern)];
  const seen = new Set<string>();

  return matches.map((match, index) => {
    const rawHref = match[1] ?? '';
    const path = rawHref.startsWith(BASE) ? rawHref.slice(BASE.length) : rawHref;
    const url = rawHref.startsWith('http') ? rawHref : `${BASE}${rawHref}`;
    const title = textFromHtml(match[2] ?? '');
    const start = (match.index ?? 0) + match[0].length;
    const end = index + 1 < matches.length ? (matches[index + 1].index ?? html.length) : html.length;
    const chunk = html.slice(start, end);
    const summary = textFromHtml(chunk)
      .replace(/^Submitted by\s+.+?\s+on\s+/i, '')
      .slice(0, 260)
      .trim();

    return {
      id: `public:${url}`,
      contentType: inferSearchContentType(path),
      title,
      summary,
      url,
      updatedAt: '',
      source: 'public' as const,
    };
  }).filter((result) => {
    if (!result.title || !result.url || seen.has(result.url)) return false;
    seen.add(result.url);
    return true;
  });
}

function mapApp(node: JsonApiNode, included: JsonApiNode[] = []): AppListing {
  const a = node.attributes;
  return {
    id: node.id,
    name: a.title ?? '',
    developer: '',
    platform: 'iOS',
    category: relatedTermName(node, included, APP_CATEGORY_RELATIONSHIP_CANDIDATES),
    reviewCount: a.comment_node_ios_app_directory?.comment_count ?? 0,
    lastUpdatedAt: a.changed ?? '',
    appStoreUrl: a.field_link2?.uri ?? a.field_link3?.uri ?? '',
    summary: a.body?.summary ?? a.body?.value ?? '',
    url: a.path?.alias ? `${BASE}${a.path.alias}` : undefined,
  };
}

// ─── Blog posts ───────────────────────────────────────────────────────────────
// Comment bundle confirmed: comment_node_blog2 (observed via comment_count attribute key).

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
    authorId: uidId ?? undefined,
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
    subject: (a.subject as string | undefined) || undefined,
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
    subject: (a.subject as string | undefined) || undefined,
    authorName,
    authorId: uidId ?? undefined,
    body: (a.comment_body?.processed ?? a.comment_body?.value ?? '') as string,
    createdAt: (a.created ?? '') as string,
    appVersion: (a.field_app_version ?? undefined) as string | undefined,
    platform: (a.field_platform ?? undefined) as string | undefined,
  };
}

// ─── Resources / Guides ──────────────────────────────────────────────────────

function mapResource(node: JsonApiNode, included: JsonApiNode[] = []): Resource {
  const a = node.attributes;
  const categoryRefs = (node.relationships?.taxonomy_vocabulary_3?.data as { id: string }[] | undefined) ?? [];
  const categories = categoryRefs
    .map((ref) => included.find((n) => n.id === ref.id))
    .filter((n): n is JsonApiNode => !!n && n.type.startsWith('taxonomy_term'))
    .map((term) => ({
      name: String(term.attributes.name ?? ''),
      tid: Number(term.attributes.drupal_internal__tid ?? 0),
    }))
    .filter((category) => category.name && category.tid > 0);

  return {
    id: node.id,
    title: a.title ?? '',
    kind: 'guide',
    categories,
    summary: a.body?.summary ?? a.body?.value ?? '',
    createdAt: (a.created as string | undefined) ?? undefined,
    updatedAt: a.changed ?? '',
    commentCount: a.comment_node_guides?.comment_count ?? 0,
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
  follows: {
    async follow(nodeUuid: string, nodeType: string, token: string) {
      return jsonApi<{ data: JsonApiNode }>('/flagging/subscribe_node', {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
        body: JSON.stringify({
          data: {
            type: 'flagging--subscribe_node',
            relationships: {
              flagged_entity: { data: { type: nodeType, id: nodeUuid } },
            },
          },
        }),
      });
    },

    async unfollow(nodeUuid: string, token: string): Promise<{ ok: true; data: undefined } | { ok: false; error: string; status?: number }> {
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

  forums: {
    async list(filter: string, page = 0, sinceDate?: string, appleOnly?: boolean) {
      // "New" sorts by creation date — JSON:API only.
      // All other filters use the dedicated /api/v1/forums/recent endpoint which sorts
      // by last_comment_timestamp DESC, matching the website's sort order exactly.
      if (filter !== 'New') {
        let qs = `page=${page}`;
        if (appleOnly) {
          FORUM_NON_APPLE_TIDS.forEach((tid) => { qs += `&apple_only[]=${tid}`; });
        }
        const res = await fetch(`${BASE}/api/v1/forums/recent?${qs}`, {
          headers: { Accept: 'application/json' },
        });
        if (!res.ok) return { ok: false as const, error: `Forums: ${res.status}` };
        const items: Record<string, string>[] = await res.json();
        return {
          ok: true as const,
          data: {
            items: items.map(mapForumFromRecent),
            hasMore: items.length === RECENT_PAGE_SIZE,
          } satisfies PaginatedResult<ForumTopic>,
        };
      }

      // "New" filter — creation-date sort via JSON:API.
      let path = `/node/forum?sort=-created&${pageParams(page, 20)}&include=uid,taxonomy_forums`;
      if (sinceDate) {
        const encoded = encodeURIComponent(sinceDate);
        path +=
          `&filter[since][condition][path]=changed` +
          `&filter[since][condition][operator]=%3E` +
          `&filter[since][condition][value]=${encoded}`;
      }
      if (appleOnly) {
        path += `&filter[notApple][condition][path]=taxonomy_forums.drupal_internal__tid` +
          `&filter[notApple][condition][operator]=NOT%20IN`;
        FORUM_NON_APPLE_TIDS.forEach((tid, i) => {
          path += `&filter[notApple][condition][value][${i}]=${tid}`;
        });
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
        `&include=uid,taxonomy_forums`;
      const res = await jsonApi<JsonApiCollection>(path);
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map((n) => mapForum(n, res.data.included ?? [])), hasMore: false } satisfies PaginatedResult<ForumTopic>,
      };
    },

    // Fetch all Drupal forum taxonomy terms (categories) sorted by name.
    // Uses JSON:API taxonomy endpoint — no Drupal developer needed.
    async categories(): Promise<{ ok: true; data: Array<{ name: string; tid: number }> } | { ok: false; error: string }> {
      const res = await jsonApi<JsonApiCollection>(
        '/taxonomy_term/forums?fields[taxonomy_term--forums]=name,drupal_internal__tid&sort=name',
      );
      if (!res.ok) return res;
      return {
        ok: true,
        data: res.data.data
          .map((term) => ({
            name: String(term.attributes.name ?? ''),
            tid: Number(term.attributes.drupal_internal__tid ?? 0),
          }))
          .filter((c) => c.name && c.tid > 0),
      };
    },

    // Fetch topics for a specific forum category by taxonomy TID.
    // Uses JSON:API filter; sorted by last-edit date (closest to "most recently commented").
    async listByCategory(tid: number, page = 0): Promise<{ ok: true; data: PaginatedResult<ForumTopic> } | { ok: false; error: string }> {
      const path =
        `/node/forum` +
        `?filter[cat][condition][path]=taxonomy_forums.drupal_internal__tid` +
        `&filter[cat][condition][operator]=%3D` +
        `&filter[cat][condition][value]=${tid}` +
        `&sort=-changed` +
        `&${pageParams(page, 20)}` +
        `&include=uid,taxonomy_forums`;
      const res = await jsonApi<JsonApiCollection>(path);
      if (!res.ok) return res;
      return {
        ok: true,
        data: {
          items: res.data.data.map((n) => mapForum(n, res.data.included ?? [])),
          hasMore: hasNextPage(res.data),
        } satisfies PaginatedResult<ForumTopic>,
      };
    },

    async listByCategories(tids: number[], page = 0): Promise<{ ok: true; data: PaginatedResult<ForumTopic> } | { ok: false; error: string }> {
      if (tids.length === 0) {
        return { ok: true, data: { items: [], hasMore: false } satisfies PaginatedResult<ForumTopic> };
      }
      const values = tids
        .map((tid, index) => `&filter[cat][condition][value][${index}]=${tid}`)
        .join('');
      const path =
        `/node/forum` +
        `?filter[cat][condition][path]=taxonomy_forums.drupal_internal__tid` +
        `&filter[cat][condition][operator]=IN` +
        values +
        `&sort=-changed` +
        `&${pageParams(page, 20)}` +
        `&include=uid,taxonomy_forums`;
      const res = await jsonApi<JsonApiCollection>(path);
      if (!res.ok) return res;
      return {
        ok: true,
        data: {
          items: res.data.data.map((n) => mapForum(n, res.data.included ?? [])),
          hasMore: hasNextPage(res.data),
        } satisfies PaginatedResult<ForumTopic>,
      };
    },

    async topic(id: string) {
      const res = await jsonApi<JsonApiCollection & { data: JsonApiNode }>(`/node/forum/${id}?include=uid,taxonomy_forums`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapForum(res.data.data, res.data.included ?? []) };
    },

    // Fetch a single topic with its full body text and all replies.
    // Comment bundle confirmed working: comment_forum (GET /comment/comment_forum).
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

    // Fetch the next page of replies for a topic (used by "Load more" in the UI).
    async moreReplies(topicId: string, offset: number) {
      const res = await jsonApi<JsonApiCollection>(
        `/comment/comment_forum?filter[entity_id.id]=${topicId}&sort=created&page[limit]=100&page[offset]=${offset}&include=uid`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: res.data.data.map((n) => mapComment(n, res.data.included ?? [])) };
    },

    // Create a new forum topic.
    // Type 'node--forum' follows standard Drupal JSON:API content type naming.
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

    // Submit a reply to a forum topic.
    // Bundle confirmed: comment_forum (same bundle used by the GET /comment/comment_forum endpoint).
    async submitReply(topicId: string, body: string, csrfToken: string, subject?: string) {
      return jsonApi<{ data: JsonApiNode }>('/comment/comment_forum', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'comment--comment_forum',
            attributes: {
              subject: subject || 'Reply',
              comment_body: { value: body, format: 'basic_html' },
            },
            relationships: {
              entity_id: { data: { type: 'node--forum', id: topicId } },
              comment_type: { data: { type: 'comment_type--comment_type', id: 'comment_forum' } },
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
      return api.follows.follow(nodeUuid, 'node--forum', token);
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
    async episodes(page = 0, sort: '-created' | '-changed' = '-created', tagTid?: number) {
      const tagFilter = tagTid
        ? `&filter[taxonomy_vocabulary_15.drupal_internal__tid]=${tagTid}`
        : '';
      const res = await jsonApi<JsonApiCollection>(
        `/node/podcast?sort=${sort}&include=field_podcast,uid,taxonomy_vocabulary_15&${pageParams(page)}${tagFilter}`,
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

    // Fetch the live tag vocabulary by sampling 50 episodes and collecting unique tags.
    // Falls back gracefully — callers use FALLBACK_PODCAST_TAGS if this returns empty.
    async tagVocabulary(): Promise<{ ok: true; data: PodcastTag[] } | { ok: false; error: string }> {
      const res = await jsonApi<JsonApiCollection>(
        `/node/podcast?sort=-created&page[limit]=50&include=taxonomy_vocabulary_15&fields[node--podcast]=id`,
      );
      if (!res.ok) return res;
      const tagMap = new Map<number, string>();
      for (const term of (res.data.included ?? [])) {
        if (!term.type.startsWith('taxonomy_term')) continue;
        const tid  = Number(term.attributes.drupal_internal__tid ?? 0);
        const name = String(term.attributes.name ?? '');
        if (tid && name) tagMap.set(tid, name);
      }
      return {
        ok: true,
        data: [...tagMap.entries()]
          .map(([tid, name]) => ({ tid, name }))
          .sort((a, b) => a.name.localeCompare(b.name)),
      };
    },

    async episode(id: string) {
      const res = await jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(
        `/node/podcast/${id}?include=field_podcast,uid,taxonomy_vocabulary_15`,
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

    async submitComment(episodeId: string, body: string, csrfToken: string) {
      return jsonApi<{ data: JsonApiNode }>('/comment/comment_node_podcast', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'comment--comment_node_podcast',
            attributes: {
              subject: 'Comment',
              comment_body: { value: body, format: 'basic_html' },
            },
            relationships: {
              entity_id: { data: { type: 'node--podcast', id: episodeId } },
              comment_type: { data: { type: 'comment_type--comment_type', id: 'comment_node_podcast' } },
            },
          },
        }),
      });
    },

    // Love a comment — flag machine name 'love_it' unconfirmed.
    // TODO: Confirm with Drupal dev: flag machine name + whether comment entity
    //       type is comment--comment_node_podcast.
    async loveComment(commentUuid: string, token: string) {
      return jsonApi<{ data: JsonApiNode }>('/flagging/love_it', {
        method: 'POST',
        headers: { 'X-CSRF-Token': token },
        body: JSON.stringify({
          data: {
            type: 'flagging--love_it',
            relationships: {
              flagged_entity: { data: { type: 'comment--comment_node_podcast', id: commentUuid } },
            },
          },
        }),
      });
    },

    async unloveComment(commentUuid: string, token: string) {
      const listRes = await jsonApi<JsonApiCollection>(
        `/flagging/love_it?filter[flagged_entity.id]=${commentUuid}`,
      );
      if (!listRes.ok) return listRes;
      const flagging = listRes.data.data[0];
      if (!flagging) return { ok: true as const, data: undefined };
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
      try {
        const res = await fetch(`${JSONAPI}/flagging/love_it/${flagging.id}`, {
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

    transcript: (id: string) =>
      drupalRest<{ text: string; vttUrl?: string }>(`/api/v1/podcasts/episodes/${id}/transcript`),
  },

  apps: {
    async platforms(): Promise<{ ok: true; data: AppPlatform[] } | { ok: false; error: string; status?: number }> {
      const res = await drupalRest<AppPlatform[]>('/api/v1/apps/platforms');
      if (!res.ok) return res;
      return { ok: true, data: Array.isArray(res.data) ? res.data : [] };
    },

    async categories(platform: string): Promise<{ ok: true; data: AppCategory[] } | { ok: false; error: string; status?: number }> {
      const res = await drupalRest<AppCategory[]>(`/api/v1/apps/${encodeURIComponent(platform)}/categories`);
      if (!res.ok) return res;
      return {
        ok: true,
        data: (Array.isArray(res.data) ? res.data : [])
          .map((category) => {
            const rawCount = (category as Record<string, unknown>).count
              ?? (category as Record<string, unknown>).appCount
              ?? (category as Record<string, unknown>).app_count;
            const count = typeof rawCount === 'number'
              ? rawCount
              : typeof rawCount === 'string' && rawCount.trim()
                ? Number(rawCount)
                : undefined;
            return {
              name: String(category.name ?? ''),
              slug: String(category.slug ?? ''),
              count: typeof count === 'number' && Number.isFinite(count) ? count : undefined,
            };
          })
          .filter((category) => category.name && category.slug),
      };
    },

    async category(platform: string, category: AppCategory, page = 0, limit = 20): Promise<
      | { ok: true; data: PaginatedResult<AppListing> & { probe: AppCategoryProbe } }
      | { ok: false; error: string; attemptedFields: string[]; status?: number }
    > {
      const path = `/api/v1/apps/${encodeURIComponent(platform)}/categories/${encodeURIComponent(category.slug)}?page=${page}&limit=${limit}`;
      const res = await drupalRest<{ items?: DirectoryApiListing[]; hasMore?: boolean } | DirectoryApiListing[]>(path);
      if (!res.ok) {
        return { ok: false, error: res.error, status: res.status, attemptedFields: ['custom app directory API'] };
      }
      const rawItems = Array.isArray(res.data) ? res.data : (res.data.items ?? []);
      return {
        ok: true,
        data: {
          items: rawItems.map((item) => mapDirectoryApiListing(item, platform, category.name)),
          hasMore: Array.isArray(res.data) ? rawItems.length >= limit : !!res.data.hasMore,
          probe: {
            category: category.name,
            fieldName: 'AppleVis app directory API',
            attemptedFields: ['custom app directory API'],
            source: 'api',
          },
        },
      };
    },

    async list(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map((n) => mapApp(n)), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<AppListing>,
      };
    },

    async categoryExperiment(category: AppCategory, platform = 'ios', page = 0): Promise<
      | { ok: true; data: PaginatedResult<AppListing> & { probe: AppCategoryProbe } }
      | { ok: false; error: string; attemptedFields: string[] }
    > {
      if (platform !== 'ios') {
        return {
          ok: false,
          error: 'JSON:API category probing is currently only available for the iOS app directory.',
          attemptedFields: ['jsonapi category probe'],
        };
      }
      const normalised = normaliseAppCategoryName(category.name);
      const encoded = encodeURIComponent(normalised);
      const attemptedFields: string[] = [];
      let lastError = '';

      for (const fieldName of APP_CATEGORY_RELATIONSHIP_CANDIDATES) {
        attemptedFields.push(fieldName);
        const res = await jsonApi<JsonApiCollection>(
          `/node/ios_app_directory?include=${fieldName}&filter[${fieldName}.name]=${encoded}&sort=title&${pageParams(page)}`,
        );

        if (!res.ok) {
          lastError = res.error;
          continue;
        }

        const items = res.data.data.map((n) => {
          const app = mapApp(n, res.data.included ?? []);
          return { ...app, category: app.category || normalised };
        });

        if (items.length === 0 && page === 0) continue;

        return {
          ok: true,
          data: {
            items,
            hasMore: hasNextPage(res.data),
            probe: {
              category: normalised,
              fieldName,
              attemptedFields,
              source: 'jsonapi',
            },
          },
        };
      }

      return {
        ok: false,
        error: lastError || 'No standard Drupal category relationship matched this app directory.',
        attemptedFields,
      };
    },

    async publicCategory(category: AppCategory, platform = 'ios', page = 0): Promise<
      | { ok: true; data: PaginatedResult<AppListing> & { probe: AppCategoryProbe } }
      | { ok: false; error: string; attemptedFields: string[] }
    > {
      const normalised = normaliseAppCategoryName(category.name);
      if (platform !== 'ios') {
        return {
          ok: false,
          error: `${normalised} is waiting for the AppleVis app directory API for this platform.`,
          attemptedFields: ['public category page'],
        };
      }
      const basePath = IOS_PUBLIC_CATEGORY_PATHS[category.slug];
      if (!basePath) {
        return {
          ok: false,
          error: `No public AppleVis category page is mapped for ${normalised}.`,
          attemptedFields: ['public category page'],
        };
      }

      const path = page > 0 ? `${basePath}?page=${page}` : basePath;
      const res = await publicHtml(path);
      if (!res.ok) {
        return { ok: false, error: res.error, attemptedFields: ['public category page'] };
      }

      const items = parsePublicAppDirectory(res.data, normalised);
      return {
        ok: true,
        data: {
          items,
          hasMore: /Next page|rel=["']next["']|pagination.+Last page/is.test(res.data),
          probe: {
            category: normalised,
            fieldName: 'public category page',
            attemptedFields: ['public category page'],
            source: 'public',
          },
        },
      };
    },

    async listing(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/ios_app_directory/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapApp(res.data.data) };
    },

    // Fetch a single app listing with its full body and all reviews.
    // Review bundle confirmed: comment_node_ios_app_directory (same key used by comment_count attribute).
    async detail(id: string): Promise<
      { ok: true; data: AppDetail } | { ok: false; error: string }
    > {
      const [appRes, reviewsRes] = await Promise.all([
        jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(`/node/ios_app_directory/${id}?include=uid`),
        jsonApi<JsonApiCollection>(`/comment/comment_node_ios_app_directory?filter[entity_id.id]=${id}&sort=-created&page[limit]=50&include=uid`),
      ]);

      if (!appRes.ok) return appRes;

      const app = mapApp(appRes.data.data);
      const a    = appRes.data.data.attributes;

      // Submitter — uid relationship → display_name (same pattern as mapBlog)
      const uidId      = (appRes.data.data.relationships?.uid?.data as { id?: string } | undefined)?.id;
      const userNode   = uidId ? appRes.data.included?.find((n) => n.id === uidId) : undefined;
      const submittedBy = String(userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? '');
      const createdAt   = String(a.created ?? '');

      const body    = String(a.body?.value ?? a.body?.processed ?? '');
      const reviews: AppReview[] = reviewsRes.ok ? reviewsRes.data.data.map((n) => mapAppReview(n, reviewsRes.data.included ?? [])) : [];

      // Confirmed field names from live JSON:API probe (2026-06-16):
      const reviewedVersion  = a.field_version        ? String(a.field_version)        : undefined;
      const testedOnIOS      = a.field_ios_version     ? String(a.field_ios_version)    : undefined;

      // Rich-text fields — prefer .value, fall back to .processed
      const accessibilityComments = (a.field_comments?.value        ?? a.field_comments?.processed        ?? undefined) as string | undefined;
      const otherComments         = (a.field_other_comments?.value  ?? a.field_other_comments?.processed  ?? undefined) as string | undefined;

      // Plain-string fields
      const voiceOverPerformance = a.field_voiceover ? String(a.field_voiceover) : undefined;
      const buttonLabelling      = a.field_labelling ? String(a.field_labelling) : undefined;
      const usabilityNotes       = a.field_usability ? String(a.field_usability) : undefined;

      return {
        ok: true,
        data: {
          ...app,
          submittedBy:  submittedBy  || undefined,
          submitterUid: uidId        || undefined,
          createdAt:    createdAt    || undefined,
          body,
          reviews,
          reviewedVersion,
          testedOnIOS,
          accessibilityComments,
          voiceOverPerformance,
          buttonLabelling,
          usabilityNotes,
          otherComments,
        },
      };
    },

    async updates(page = 0) {
      const res = await jsonApi<JsonApiCollection>(
        `/node/ios_app_directory?sort=-changed&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: { items: res.data.data.map((n) => mapApp(n)), hasMore: hasNextPage(res.data) } satisfies PaginatedResult<AppListing>,
      };
    },

    // Fetch the next page of reviews for an app (used by "Load more" in the UI).
    async moreReviews(appId: string, offset: number) {
      const res = await jsonApi<JsonApiCollection>(
        `/comment/comment_node_ios_app_directory?filter[entity_id.id]=${appId}&sort=-created&page[limit]=50&page[offset]=${offset}&include=uid`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: res.data.data.map((n) => mapAppReview(n, res.data.included ?? [])) };
    },

    // Submit an app review. Bundle confirmed: comment_node_ios_app_directory.
    // field_app_version and field_platform are written to the same fields mapAppReview reads.
    async submitReview(appId: string, body: string, csrfToken: string, opts?: { platform?: string; appVersion?: string }) {
      return jsonApi<{ data: JsonApiNode }>('/comment/comment_node_ios_app_directory', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'comment--comment_node_ios_app_directory',
            attributes: {
              subject: 'Review',
              comment_body: { value: body, format: 'basic_html' },
              ...(opts?.appVersion ? { field_app_version: opts.appVersion } : {}),
              ...(opts?.platform   ? { field_platform:   opts.platform }   : {}),
            },
            relationships: {
              entity_id: { data: { type: 'node--ios_app_directory', id: appId } },
              comment_type: { data: { type: 'comment_type--comment_type', id: 'comment_node_ios_app_directory' } },
            },
          },
        }),
      });
    },

    // Submit a new app entry via JSON:API.
    // All assessment fields are plain strings (confirmed from live node inspection).
    // Only taxonomy_vocabulary_1 (category) requires a UUID relationship.
    async submitApp(
      payload: {
        appName:               string;
        appStoreUrl:           string;
        appVersion:            string;
        price:                 string;
        supportedDevices:      string[];
        appStoreDescription:   string;
        category:              string;
        osVersion:             string;
        voiceOverPerformance:  string;
        buttonLabelling:       string;
        usabilityNotes:        string;
        accessibilityComments: string;
        otherComments:         string;
        shortSummary:          string;
      },
      csrfToken: string,
    ): Promise<{ ok: true; data: { nid: number; nodeUrl: string } } | { ok: false; error: string }> {
      // Vocabulary 1 category UUIDs — fetched from /jsonapi/taxonomy_term/vocabulary_1 2026-06-24.
      const CATEGORY_UUIDS: Record<string, string> = {
        'Books':               'bee9a94d-2a9c-4b1d-8ea7-8e9d0c3fc3dd',
        'Business':            '20dcbad3-c417-48e3-8b5b-ff4069f87d7b',
        'Catalogs':            '87aae28a-0741-4f66-b440-63aacccaf29f',
        'Developer Tools':     '16251ccf-925e-453a-848d-8e1b33dffb71',
        'Education':           '8726dafb-e470-4338-9dd0-a868144a5d7f',
        'Entertainment':       '7f69826f-a3b0-4fc4-b7d4-7fbdacb5cfcc',
        'Finance':             '6425c1d3-6ee4-4724-ac76-5443f58ec373',
        'Food & Drink':        'b1a99efd-7626-4fb5-bfe4-1c14ad0947f2',
        'Food and Drink':      'b1a99efd-7626-4fb5-bfe4-1c14ad0947f2',
        'Games':               'a63cc23a-836a-4068-8f23-b3afbf5b994e',
        'Graphics & Design':   'a2cc7759-0e37-4188-a4a2-b9f2188793ce',
        'Graphics and Design': 'a2cc7759-0e37-4188-a4a2-b9f2188793ce',
        'Health & Fitness':    '0cb652cc-2b6c-4d43-bf50-5d42471c8b81',
        'Health and Fitness':  '0cb652cc-2b6c-4d43-bf50-5d42471c8b81',
        'Lifestyle':           '387c7f86-4719-43ee-a36f-a2f043b10c44',
        'Medical':             'c36d6ca0-fef3-41d8-9b96-5530828d4895',
        'Music':               '042bdef6-e708-4375-bd86-b6b2ee53e484',
        'Navigation':          '551ed39e-0816-40b5-8c5b-fb9c700eaf9e',
        'News':                '62329830-4955-46a9-99b4-ccc2ff49a676',
        'Photo & Video':       'a8cfec9b-e132-42ee-9169-a0e404204656',
        'Photo and Video':     'a8cfec9b-e132-42ee-9169-a0e404204656',
        'Productivity':        'cc18cc76-e08e-4037-a3bf-064f5f5b696f',
        'Reference':           'a4475fb2-444b-420c-9bf5-d2c29bb02044',
        'Safari Extensions':   '55a3c4a5-1b9f-43f1-8c3d-0eeee3eb57f2',
        'Shopping':            '21d1f775-a5d3-45de-b421-3e90c9c51873',
        'Social Networking':   '33821fa2-114a-467f-a7a1-04f699ee53b6',
        'Sports':              'a901f670-1d53-4eb3-9e43-82653568e1f1',
        'Sports and Activities': 'a901f670-1d53-4eb3-9e43-82653568e1f1',
        'Stickers':            '2e3945ff-9876-403d-8aea-1178f4647864',
        'Travel':              '17c20229-4532-4e40-8853-88da8d9a8c46',
        'Utilities':           '870e83b5-6299-4d30-96e5-b54ae778dea5',
        'Weather':             '5df92429-93bc-4d33-a882-a303b899959e',
      };

      const categoryUuid = CATEGORY_UUIDS[payload.category];

      const attributes: Record<string, unknown> = {
        title:            payload.appName,
        field_link2:      { uri: payload.appStoreUrl, title: '', options: [] },
        field_version:    payload.appVersion,
        field_cost:       payload.price,
        field_device_used: payload.supportedDevices.join(', '),
        field_ios_version: payload.osVersion,
        field_voiceover:  payload.voiceOverPerformance,
        field_labelling:  payload.buttonLabelling,
        field_usability:  payload.usabilityNotes,
        field_comments:   { value: payload.accessibilityComments, format: 'basic_html' },
      };

      if (payload.otherComments.trim()) {
        attributes.field_other_comments = { value: payload.otherComments.trim(), format: 'basic_html' };
      }

      if (payload.appStoreDescription || payload.shortSummary) {
        attributes.body = {
          value:   payload.appStoreDescription || '',
          summary: payload.shortSummary || '',
          format:  'basic_html',
        };
      }

      const relationships: Record<string, unknown> = categoryUuid
        ? { taxonomy_vocabulary_1: { data: { type: 'taxonomy_term--vocabulary_1', id: categoryUuid } } }
        : {};

      const res = await jsonApi<{ data: JsonApiNode }>('/node/ios_app_directory', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'node--ios_app_directory',
            attributes,
            ...(Object.keys(relationships).length > 0 ? { relationships } : {}),
          },
        }),
      });

      if (!res.ok) return res;

      const a   = res.data.data.attributes as Record<string, unknown>;
      const nid = a.drupal_internal__nid as number;
      const alias = (a.path as { alias?: string } | undefined)?.alias;
      return {
        ok:   true,
        data: {
          nid,
          nodeUrl: alias ? `${BASE}${alias}` : `${BASE}/node/${nid}`,
        },
      };
    },
  },

  resources: {
    async list(page = 0, categoryTids?: number[]) {
      const categoryFilter = categoryTids?.length
        ? categoryTids
          .map((tid, index) => `&filter[category][condition][value][${index}]=${tid}`)
          .join('')
        : '';
      const categoryCondition = categoryTids?.length
        ? `&filter[category][condition][path]=taxonomy_vocabulary_3.drupal_internal__tid` +
          `&filter[category][condition][operator]=IN${categoryFilter}`
        : '';
      const res = await jsonApi<JsonApiCollection>(
        `/node/guides?sort=-changed&include=taxonomy_vocabulary_3&${pageParams(page)}${categoryCondition}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: {
          items: res.data.data.map((n) => mapResource(n, res.data.included ?? [])),
          hasMore: hasNextPage(res.data),
        } satisfies PaginatedResult<Resource>,
      };
    },

    async item(id: string) {
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/guides/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapResource(res.data.data) };
    },

    /**
     * Fetch a resource with its full body text and author info via uid relationship.
     */
    async detail(id: string): Promise<
      { ok: true; data: ResourceDetail } | { ok: false; error: string }
    > {
      const res = await jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(`/node/guides/${id}?include=uid`);
      if (!res.ok) return res;
      const node     = res.data.data;
      const included = res.data.included ?? [];
      const resource = mapResource(node, included);
      const body     = String(node.attributes.body?.value ?? node.attributes.body?.processed ?? '');
      const uidId    = (node.relationships?.uid?.data as { id?: string } | undefined)?.id;
      const userNode = uidId ? included.find((n) => n.id === uidId) : undefined;
      const authorName = String(
        userNode?.attributes?.display_name ?? userNode?.attributes?.name ?? node.attributes.field_author ?? '',
      );
      return { ok: true, data: { ...resource, body, authorName: authorName || undefined, authorId: uidId ?? undefined } };
    },

    // Fetch comments on a guide/resource.
    // Bundle inferred from Drupal naming convention: comment_node_{content_type}.
    async comments(resourceId: string) {
      const res = await jsonApi<JsonApiCollection>(
        `/comment/comment_node_guides?filter[entity_id.id]=${resourceId}&sort=created&page[limit]=100&include=uid`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: res.data.data.map((n) => mapComment(n, res.data.included ?? [])),
      };
    },

    async submitComment(resourceId: string, body: string, csrfToken: string) {
      return jsonApi<{ data: JsonApiNode }>('/comment/comment_node_guides', {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: 'comment--comment_node_guides',
            attributes: {
              subject: 'Comment',
              comment_body: { value: body, format: 'basic_html' },
            },
            relationships: {
              entity_id: { data: { type: 'node--guides', id: resourceId } },
              comment_type: { data: { type: 'comment_type--comment_type', id: 'comment_node_guides' } },
            },
          },
        }),
      });
    },
  },

  // ─── Blogs ────────────────────────────────────────────────────────────────────
  // Blog content type confirmed: 'blog2'.

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

    async detail(id: string): Promise<
      { ok: true; data: BlogPostDetail } | { ok: false; error: string }
    > {
      if (!BLOG_CONTENT_TYPE) return { ok: false, error: 'BLOG_NOT_CONFIGURED' };
      const res = await jsonApi<{ data: JsonApiNode; included?: JsonApiNode[] }>(
        `/node/${BLOG_CONTENT_TYPE}/${id}?include=uid`,
      );
      if (!res.ok) return res;
      const node     = res.data.data;
      const included = res.data.included ?? [];
      const blog     = mapBlog(node, included);
      const body     = String(node.attributes.body?.value ?? node.attributes.body?.processed ?? '');
      return { ok: true, data: { ...blog, body } };
    },

    // Fetch comments on a blog post.
    // Bundle confirmed: comment_node_blog2 (observed via comment_count attribute key on blog nodes).
    async comments(blogId: string) {
      if (!BLOG_CONTENT_TYPE) return { ok: false as const, error: 'BLOG_NOT_CONFIGURED' };
      const res = await jsonApi<JsonApiCollection>(
        `/comment/comment_node_${BLOG_CONTENT_TYPE}?filter[entity_id.id]=${blogId}&sort=created&page[limit]=100&include=uid`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: res.data.data.map((n) => mapComment(n, res.data.included ?? [])),
      };
    },

    async submitComment(blogId: string, body: string, csrfToken: string) {
      if (!BLOG_CONTENT_TYPE) return { ok: false as const, error: 'BLOG_NOT_CONFIGURED' };
      return jsonApi<{ data: JsonApiNode }>(`/comment/comment_node_${BLOG_CONTENT_TYPE}`, {
        method: 'POST',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type: `comment--comment_node_${BLOG_CONTENT_TYPE}`,
            attributes: {
              subject: 'Comment',
              comment_body: { value: body, format: 'basic_html' },
            },
            relationships: {
              entity_id: { data: { type: `node--${BLOG_CONTENT_TYPE}`, id: blogId } },
              comment_type: { data: { type: 'comment_type--comment_type', id: `comment_node_${BLOG_CONTENT_TYPE}` } },
            },
          },
        }),
      });
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
      return { ok: true as const, data: { items: res.data.data.map((n) => mapApp(n)), hasMore: false } satisfies PaginatedResult<AppListing> };
    },

    async resources(query: string) {
      const q = encodeURIComponent(query.trim());
      const res = await jsonApi<JsonApiCollection>(
        `/node/guides?filter[title][operator]=CONTAINS&filter[title][value]=${q}&sort=-changed&page[limit]=10`,
      );
      if (!res.ok) return res;
      return { ok: true as const, data: { items: res.data.data.map((n) => mapResource(n)), hasMore: false } satisfies PaginatedResult<Resource> };
    },

    async publicSite(query: string): Promise<{ ok: true; data: SearchResult[] } | { ok: false; error: string }> {
      const q = encodeURIComponent(query.trim());
      const res = await publicHtml(`/search?key=${q}`);
      if (!res.ok) return res;
      return { ok: true, data: parsePublicSearch(res.data).slice(0, 20) };
    },

    // Gate 3 — Full-text search across all content types via Drupal Search API.
    // Returns 'SEARCH_NOT_CONFIGURED' when SEARCH_API_PATH is null, so callers
    // can fall back to per-type title-CONTAINS search in the meantime.
    async fullText(query: string): Promise<{ ok: true; data: SearchResult[] } | { ok: false; error: string }> {
      if (!SEARCH_API_PATH) return { ok: false, error: 'SEARCH_NOT_CONFIGURED' };
      const q   = encodeURIComponent(query.trim());
      const separator = SEARCH_API_PATH.includes('?') ? '&' : '?';
      const res = await drupalRest<any[] | { items?: any[]; results?: any[] }>(
        `${SEARCH_API_PATH}${separator}key=${q}&q=${q}&page=0&limit=20`,
      );
      if (!res.ok) return res;
      const rawItems = Array.isArray(res.data) ? res.data : (res.data.items ?? res.data.results ?? []);
      const results: SearchResult[] = rawItems.map((item: any) => ({
        id:          String(item.id ?? item.nid ?? item.uuid ?? ''),
        contentType: (item.type ?? item.contentType ?? item.content_type ?? 'unknown') as SearchResult['contentType'],
        title:       String(item.title ?? item.name ?? ''),
        summary:     (item.body ?? item.summary ?? item.field_summary ?? undefined) as string | undefined,
        url:         String(item.url ?? item.path ?? ''),
        updatedAt:   String(item.changed ?? item.updated ?? ''),
        source:      'api',
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

    async signIn(email: string, password: string): Promise<
      | { ok: true; data: { current_user: { uid: string; name: string }; csrf_token: string; logout_token: string } }
      | { ok: false; error: string; status?: number }
    > {
      const reqHeaders = {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-App-Auth': COMMON_HEADERS['X-App-Auth'],
      };
      const url = `${BASE}/user/login?_format=json`;
      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
      try {
        const body = JSON.stringify({ name: email, pass: password });
        const parseLoginResponse = async (res: Response) => {
          const text = await res.text().catch(() => '');
          if (!res.ok) {
            let detail = text.trim();
            try {
              const json = detail ? JSON.parse(detail) : null;
              detail = String(json?.message ?? json?.error ?? json?.errors?.[0]?.detail ?? detail);
            } catch { /* keep plain text */ }
            return {
              ok: false as const,
              error: detail ? `HTTP ${res.status}: ${detail}` : `HTTP ${res.status}`,
              status: res.status,
            };
          }
          const json = JSON.parse(text) as { current_user: { uid: string; name: string }; csrf_token: string; logout_token: string };
          return { ok: true as const, data: json };
        };

        const first = await fetch(url, {
          method: 'POST',
          headers: reqHeaders,
          body,
          signal: ctrl.signal,
        });
        const firstResult = await parseLoginResponse(first);
        if (firstResult.ok || firstResult.status !== 403) return firstResult;

        const retry = await fetch(url, {
          method: 'POST',
          headers: { ...reqHeaders, 'Cache-Control': 'no-cache' },
          body,
          credentials: 'omit',
          signal: ctrl.signal,
        });
        return parseLoginResponse(retry);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        const isTimeout = err instanceof Error && err.name === 'AbortError';
        return {
          ok: false,
          error: isTimeout ? 'Request timed out.' : msg,
        };
      } finally {
        clearTimeout(timer);
      }
    },

    async signOut(logoutToken: string) {
      return drupalRest<void>(`/user/logout?_format=json&token=${encodeURIComponent(logoutToken)}`, {
        method: 'POST',
      });
    },

    async registerPushToken(pushToken: string, csrfToken: string, soundFile?: string) {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false as const, error: 'Could not resolve account ID.' };
      const attributes: Record<string, string> = { field_push_token: pushToken };
      if (soundFile) attributes.field_push_sound = soundFile;
      return jsonApi<void>(`/user/user/${uuid}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ data: { type: 'user--user', id: uuid, attributes } }),
      });
    },

    async updatePushSound(soundFile: string, csrfToken: string) {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false as const, error: 'Could not resolve account ID.' };
      return jsonApi<void>(`/user/user/${uuid}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ data: { type: 'user--user', id: uuid, attributes: { field_push_sound: soundFile } } }),
      });
    },

    async removePushToken(csrfToken: string) {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false as const, error: 'Could not resolve account ID.' };
      return jsonApi<void>(`/user/user/${uuid}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ data: { type: 'user--user', id: uuid, attributes: { field_push_token: '', field_push_sound: '' } } }),
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

    // Expose resolveMyUuid publicly so AuthContext can persist the UUID after sign-in.
    resolveUuid: (csrfToken: string) => resolveMyUuid(csrfToken),

    async editProfile(csrfToken: string, fields: Record<string, unknown>): Promise<JsonApiResult<undefined>> {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false, error: 'Could not resolve account ID.' };
      return jsonApi<undefined>(`/user/user/${uuid}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({ data: { type: 'user--user', id: uuid, attributes: fields } }),
      });
    },

    async fetchMyProfile(csrfToken: string) {
      const uuid = await resolveMyUuid(csrfToken);
      if (!uuid) return { ok: false as const, error: 'Could not resolve account ID.' };
      type UserNode = { data: JsonApiNode };
      const res = await jsonApi<UserNode>(`/user/user/${uuid}`, {
        headers: { 'X-CSRF-Token': csrfToken },
      });
      if (!res.ok) return res;
      const a = res.data.data.attributes;
      return {
        ok: true as const,
        data: {
          uuid,
          displayName:   String(a.display_name ?? a.name ?? ''),
          realName:      String(a.field_profile_realname ?? ''),
          bio:           String(a.field_profile_bio ?? ''),
          location:      String(a.field_profile_location ?? ''),
          facebook:      String(a.field_profile_facebook ?? ''),
          twitter:       String(a.field_profile_twitter ?? ''),
          mastodon:      String(a.field_mastodon_username ?? ''),
          homepage:      String(a.field_profile_homepage ?? ''),
          interests:     String(a.field_profile_interests ?? ''),
        },
      };
    },
  },

  // ─── Content editing & deletion ───────────────────────────────────────────────

  content: {
    // Fetch raw comment body + format code (needed before a PATCH to preserve format).
    async fetchRawComment(commentType: string, commentId: string, csrfToken: string) {
      type Node = { data: JsonApiNode };
      const res = await jsonApi<Node>(`/comment/${commentType}/${commentId}`, {
        headers: { 'X-CSRF-Token': csrfToken },
      });
      if (!res.ok) return res;
      const cb = res.data.data.attributes?.comment_body as { value?: string; format?: string } | undefined;
      return {
        ok: true as const,
        data: {
          rawValue:  String(cb?.value ?? ''),
          format:    String(cb?.format ?? 'basic_html'),
        },
      };
    },

    async editComment(
      commentType: string,
      commentId: string,
      newBody: string,
      format: string,
      csrfToken: string,
    ): Promise<JsonApiResult<undefined>> {
      return jsonApi<undefined>(`/comment/${commentType}/${commentId}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type:       `comment--${commentType}`,
            id:          commentId,
            attributes: { comment_body: { value: newBody, format } },
          },
        }),
      });
    },

    async deleteComment(
      commentType: string,
      commentId: string,
      csrfToken: string,
    ): Promise<JsonApiResult<undefined>> {
      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
      try {
        const res = await fetch(`${JSONAPI}/comment/${commentType}/${commentId}`, {
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

    async editForumPost(
      nodeId: string,
      title: string,
      body: string,
      csrfToken: string,
    ): Promise<JsonApiResult<undefined>> {
      return jsonApi<undefined>(`/node/forum/${nodeId}`, {
        method: 'PATCH',
        headers: { 'X-CSRF-Token': csrfToken },
        body: JSON.stringify({
          data: {
            type:       'node--forum',
            id:          nodeId,
            attributes: { title, body: { value: body, format: 'basic_html' } },
          },
        }),
      });
    },

    async deleteForumPost(
      nodeId: string,
      csrfToken: string,
    ): Promise<JsonApiResult<undefined>> {
      const ctrl  = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
      try {
        const res = await fetch(`${JSONAPI}/node/forum/${nodeId}`, {
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
  },

  // ─── User profiles & contact ─────────────────────────────────────────────────

  users: {
    /**
     * Fetch a public user profile by JSON:API UUID.
     * Returns display name, username, member-since date, and numeric uid
     * (needed for the contact form recipient field).
     */
    async profile(uuid: string) {
      type UserNode = { data: JsonApiNode };
      const res = await jsonApi<UserNode>(`/user/user/${uuid}`);
      if (!res.ok) return res;
      const a = res.data.data.attributes;
      return {
        ok: true as const,
        data: {
          uuid,
          displayName:  String(a.display_name ?? a.name ?? ''),
          username:     String(a.name ?? ''),
          memberSince:  String(a.created ?? ''),
          numericUid:   Number(a.drupal_internal__uid ?? 0),
          profileUrl:   a.path?.alias ? `${BASE}${a.path.alias}` : undefined,
          location:     profileFieldText(a.field_location),
          bio:          profileFieldText(a.field_bio ?? a.field_about ?? a.field_profile_bio ?? a.field_description),
          website:      profileFieldText(a.field_website ?? a.field_url ?? a.field_homepage),
        },
      };
    },

    /**
     * Send a private contact message to another member via Drupal's Contact module.
     * Uses the standard REST endpoint — neither party's email address is revealed.
     * Requires the user to be authenticated (session cookie present).
     *
     * NOTE TO DRUPAL DEVELOPER:
     *   Confirm the personal contact form machine name is 'personal'.
     *   If the REST endpoint /contact_message is not enabled, enable it at
     *   Admin → Config → Services → REST → contact_message (POST, json, cookie).
     */
    async sendContact(numericUid: number, subject: string, message: string) {
      const token = await api.account.getSessionToken();
      if (!token) return { ok: false as const, error: 'Could not get session token.' };
      return drupalRest<void>('/contact_message?_format=json', {
        method:  'POST',
        headers: { 'X-CSRF-Token': token },
        body: JSON.stringify({
          contact_form: [{ target_id: 'personal' }],
          subject:      [{ value: subject  }],
          message:      [{ value: message  }],
          recipient:    [{ target_id: numericUid }],
        }),
      });
    },
  },

  // ─── Bug Reports ─────────────────────────────────────────────────────────────
  // Two confirmed content types: node--ios_bug_report and node--os_x_bug_report.
  // Both confirmed live via JSON:API root enumeration.

  bugs: {
    async list(platform: 'ios' | 'macos', filter: 'active' | 'all', page = 0) {
      const nodeType = platform === 'ios' ? 'ios_bug_report' : 'os_x_bug_report';
      const statusFilter = filter === 'active' ? '&filter[field_status]=1' : '';
      const res = await jsonApi<JsonApiCollection>(
        `/node/${nodeType}?sort=-changed${statusFilter}&${pageParams(page)}`,
      );
      if (!res.ok) return res;
      return {
        ok: true as const,
        data: {
          items: res.data.data.map((n) => mapBug(n, platform)),
          hasMore: hasNextPage(res.data),
        } satisfies PaginatedResult<BugReport>,
      };
    },

    async detail(platform: 'ios' | 'macos', id: string) {
      const nodeType = platform === 'ios' ? 'ios_bug_report' : 'os_x_bug_report';
      const res = await jsonApi<{ data: JsonApiNode }>(`/node/${nodeType}/${id}`);
      if (!res.ok) return res;
      return { ok: true as const, data: mapBugDetail(res.data.data, platform) };
    },
  },
};

// ─── Bug mappers (defined after `api` to avoid hoisting issues) ───────────────

function formatBugVersion(raw: string, platform: 'ios' | 'macos'): string {
  if (!raw || raw === 'unknown' || raw === '0') return '';
  // String term IDs from old taxonomy — numeric-only means no label available
  if (/^\d+$/.test(raw)) return '';
  if (raw.startsWith('ios_ipados_')) {
    return 'iOS/iPadOS ' + raw.replace('ios_ipados_', '').replace(/_/g, '.');
  }
  if (raw.startsWith('macos_')) {
    const parts = raw.replace('macos_', '').split('_');
    const codeName = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
    const version  = parts.slice(1).join('.');
    return version ? `macOS ${codeName} ${version}` : `macOS ${codeName}`;
  }
  // Already human-readable
  return raw;
}

function mapBug(n: JsonApiNode, platform: 'ios' | 'macos'): BugReport {
  const a = n.attributes;
  const commentKey  = platform === 'ios' ? 'comment_node_ios_bug_report' : 'comment_node_os_x_bug_report';
  const firstSeen   = platform === 'ios' ? a.field_bug_first_noticed : a.field_bug_first_encountered;
  const fixedInRaw  = platform === 'ios' ? a.field_fixed_in : a.field_bug_fixed_in;
  const statusInt   = Number(a.field_status ?? 0);
  const severityInt = Number(a.field_severity ?? 0);
  const fixedIn     = fixedInRaw ? formatBugVersion(String(fixedInRaw), platform) : undefined;
  return {
    id:           String(n.id),
    platform,
    title:        String(a.title ?? ''),
    status:       statusInt === 1 ? 'active' : 'fixed',
    severity:     severityInt === 2 ? 'high' : severityInt === 1 ? 'medium' : 'low',
    firstSeen:    formatBugVersion(String(firstSeen ?? ''), platform),
    fixedIn:      fixedIn || undefined,
    feedbackId:   a.field_apple_feedback_ ? String(a.field_apple_feedback_) : undefined,
    commentCount: Number(a[commentKey]?.comment_count ?? 0),
    createdAt:    String(a.created ?? ''),
    changedAt:    String(a.changed ?? ''),
    url:          a.path?.alias ? `${BASE}${a.path.alias}` : `${BASE}/bugs`,
  };
}

function mapBugDetail(n: JsonApiNode, platform: 'ios' | 'macos'): BugReportDetail {
  const a        = n.attributes;
  const base     = mapBug(n, platform);
  const howOftenInt = Number(a.field_how_often_the_bug_occurs ?? 0);
  return {
    ...base,
    body:               textFromHtml(String(a.body?.value ?? a.body?.processed ?? '')),
    stepsToReproduce:   a.field_steps_to_reproduce?.value
                          ? textFromHtml(String(a.field_steps_to_reproduce.value))
                          : undefined,
    workaround:         a.field_workaround?.value
                          ? textFromHtml(String(a.field_workaround.value))
                          : undefined,
    device:             a.field_device_s_bug_has_been_enco
                          ? String(a.field_device_s_bug_has_been_enco)
                          : undefined,
    howOften:           howOftenInt === 2 ? 'always' : howOftenInt === 1 ? 'sometimes' : 'rarely',
  };
}
