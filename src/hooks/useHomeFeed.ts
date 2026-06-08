import { useCallback, useEffect, useRef, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { api } from '../services/api';
import type { BlogPost, FeedItem, FeedPrefs } from '../types/content';

const PREFS_KEY = '@applevis_home_feed_prefs';

export const DEFAULT_FEED_PREFS: FeedPrefs = {
  topics:    true,
  podcasts:  true,
  apps:      true,
  guides:    true,
  blogs:     false,    // gate — pending Drupal blog content type name
  appleOnly: false,    // gate — pending taxonomy field name
};

type SourceKey = 'topics' | 'podcasts' | 'apps' | 'guides' | 'blogs';
type PageMap   = Partial<Record<SourceKey, number>>;
type MoreMap   = Partial<Record<SourceKey, boolean>>;
type ErrMap    = Partial<Record<SourceKey, string>>;

function sortByActivity(items: FeedItem[]): FeedItem[] {
  return [...items].sort(
    (a, b) => new Date(b.activityAt).getTime() - new Date(a.activityAt).getTime(),
  );
}

async function fetchPage(prefs: FeedPrefs, page: number): Promise<{
  items: FeedItem[];
  hasMore: MoreMap;
  errors: ErrMap;
}> {
  const items: FeedItem[] = [];
  const hasMore: MoreMap  = {};
  const errors: ErrMap    = {};

  const calls: Promise<void>[] = [];

  if (prefs.topics) {
    calls.push(api.forums.list('Recent', page, undefined, prefs.appleOnly).then((res) => {
      if (res.ok) {
        res.data.items.forEach((t) =>
          items.push({ kind: 'topic', data: t, activityAt: t.lastActivityAt }),
        );
        hasMore.topics = res.data.hasMore;
      } else {
        errors.topics = res.error;
      }
    }));
  }

  if (prefs.podcasts) {
    calls.push(api.podcasts.episodes(page, '-changed').then((res) => {
      if (res.ok) {
        res.data.items.forEach((p) =>
          items.push({ kind: 'podcast', data: p, activityAt: p.lastActivityAt ?? p.publishedAt }),
        );
        hasMore.podcasts = res.data.hasMore;
      } else {
        errors.podcasts = res.error;
      }
    }));
  }

  if (prefs.apps) {
    calls.push(api.apps.list(page).then((res) => {
      if (res.ok) {
        res.data.items.forEach((a) =>
          items.push({ kind: 'app', data: a, activityAt: a.lastUpdatedAt }),
        );
        hasMore.apps = res.data.hasMore;
      } else {
        errors.apps = res.error;
      }
    }));
  }

  if (prefs.guides) {
    calls.push(api.resources.list(page).then((res) => {
      if (res.ok) {
        res.data.items.forEach((g) =>
          items.push({ kind: 'guide', data: g, activityAt: g.updatedAt }),
        );
        hasMore.guides = res.data.hasMore;
      } else {
        errors.guides = res.error;
      }
    }));
  }

  // Gate 1 — Blogs. Silently skipped when BLOG_CONTENT_TYPE is null.
  if (prefs.blogs) {
    calls.push(api.blogs.list(page).then((res) => {
      if (res.ok) {
        res.data.items.forEach((b: BlogPost) =>
          items.push({ kind: 'blog', data: b, activityAt: b.lastActivityAt ?? b.publishedAt }),
        );
        hasMore.blogs = res.data.hasMore;
      } else if (res.error !== 'BLOG_NOT_CONFIGURED') {
        errors.blogs = res.error;
      }
    }));
  }

  await Promise.all(calls);

  return { items, hasMore, errors };
}

export function useHomeFeed() {
  const [prefs, setPrefs]           = useState<FeedPrefs>(DEFAULT_FEED_PREFS);
  const [prefsLoaded, setPrefsLoaded] = useState(false);
  const [items, setItems]           = useState<FeedItem[]>([]);
  const [loading, setLoading]       = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [errors, setErrors]         = useState<ErrMap>({});
  const [pages, setPages]           = useState<PageMap>({});
  const [hasMore, setHasMore]       = useState<MoreMap>({});
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  // Used to cancel in-flight loads when prefs change mid-fetch
  const loadGenRef = useRef(0);

  // Load saved preferences once on mount
  useEffect(() => {
    AsyncStorage.getItem(PREFS_KEY).then((raw) => {
      if (raw) {
        try {
          const saved = JSON.parse(raw) as Partial<FeedPrefs>;
          setPrefs({ ...DEFAULT_FEED_PREFS, ...saved });
        } catch {}
      }
      setPrefsLoaded(true);
    });
  }, []);

  const loadFromStart = useCallback(async (currentPrefs: FeedPrefs, background = false) => {
    const gen = ++loadGenRef.current;
    if (background) setRefreshing(true);
    else { setLoading(true); setErrors({}); }

    const result = await fetchPage(currentPrefs, 0);
    if (gen !== loadGenRef.current) return; // superseded

    setItems(sortByActivity(result.items));
    setErrors(result.errors);
    setHasMore(result.hasMore);
    setPages({ topics: 0, podcasts: 0, apps: 0, guides: 0, blogs: 0 });

    if (background) setRefreshing(false);
    else setLoading(false);
  }, []);

  // Initial load + re-load when prefs change
  useEffect(() => {
    if (!prefsLoaded) return;
    loadFromStart(prefs);
  }, [prefsLoaded, prefs, loadFromStart]);

  const refresh = useCallback(() => loadFromStart(prefs, true), [prefs, loadFromStart]);

  const updatePref = useCallback(async (key: keyof FeedPrefs, value: boolean) => {
    const next = { ...prefs, [key]: value };
    setPrefs(next);
    await AsyncStorage.setItem(PREFS_KEY, JSON.stringify(next));
    // loadFromStart fires via the useEffect above when prefs state updates
  }, [prefs]);

  const loadMore = useCallback(async () => {
    if (isLoadingMore) return;
    const anyMore = Object.values(hasMore).some(Boolean);
    if (!anyMore) return;

    setIsLoadingMore(true);

    // Fetch page+1 for every source that still has more
    const nextPages: PageMap = { ...pages };
    const morePrefs: FeedPrefs = {
      ...DEFAULT_FEED_PREFS,
      topics:    prefs.topics   && !!hasMore.topics,
      podcasts:  prefs.podcasts && !!hasMore.podcasts,
      apps:      prefs.apps     && !!hasMore.apps,
      guides:    prefs.guides   && !!hasMore.guides,
      blogs:     prefs.blogs    && !!hasMore.blogs,
      appleOnly: prefs.appleOnly,
    };
    const nextPageNum = Math.max(
      (nextPages.topics   ?? 0),
      (nextPages.podcasts ?? 0),
      (nextPages.apps     ?? 0),
      (nextPages.guides   ?? 0),
      (nextPages.blogs    ?? 0),
    ) + 1;

    const result = await fetchPage(morePrefs, nextPageNum);

    setItems((prev) => sortByActivity([...prev, ...result.items]));
    setHasMore((prev) => ({ ...prev, ...result.hasMore }));
    setPages({
      topics:   morePrefs.topics   ? nextPageNum : pages.topics,
      podcasts: morePrefs.podcasts ? nextPageNum : pages.podcasts,
      apps:     morePrefs.apps     ? nextPageNum : pages.apps,
      guides:   morePrefs.guides   ? nextPageNum : pages.guides,
      blogs:    morePrefs.blogs    ? nextPageNum : pages.blogs,
    });
    setIsLoadingMore(false);
  }, [isLoadingMore, hasMore, pages, prefs]);

  return {
    items,
    loading,
    refreshing,
    errors,
    prefs,
    updatePref,
    refresh,
    loadMore,
    hasMore: Object.values(hasMore).some(Boolean),
    isLoadingMore,
  };
}
