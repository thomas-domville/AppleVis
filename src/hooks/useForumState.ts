import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import * as Haptics from 'expo-haptics';
import { api } from '../services/api';
import { cachedApi } from '../services/cachedApi';
import { apiHealth } from '../services/apiHealth';
import { authEvents } from '../services/authEvents';
import { persistence } from '../services/persistence';
import { relativeTime } from '../utils/relativeTime';
import { useToast } from '../contexts/ToastContext';
import type { ForumTopic } from '../types/content';

export type ForumFilter = 'Recent' | 'New' | 'Unread' | 'Since Last Visit' | 'Following' | 'Saved';
export const FORUM_FILTERS: ForumFilter[] = ['Recent', 'New', 'Unread', 'Since Last Visit', 'Following', 'Saved'];

const MAX_FOLLOWING = 50;

export function useForumState() {
  const { showToast } = useToast();

  const [filter, setFilterState]         = useState<ForumFilter>('Recent');
  const [topics, setTopics]               = useState<ForumTopic[]>([]);
  const [loading, setLoading]             = useState(true);
  const [refreshing, setRefreshing]       = useState(false);
  const [error, setError]                 = useState<string | null>(null);
  const [fromCache, setFromCache]         = useState(false);
  const [cachedAt, setCachedAt]           = useState<number | undefined>(undefined);
  const [page, setPage]                   = useState(0);
  const [hasMore, setHasMore]             = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [readIds, setReadIds]             = useState<Set<string>>(new Set());
  const [followedIds, setFollowedIds]     = useState<Set<string>>(new Set());
  const [savedIds, setSavedIds]           = useState<Set<string>>(new Set());
  const lastVisitRef = useRef<string | null>(null);

  // Refs mirror state so annotate and loadTopics always read the latest values
  // without those values appearing in dependency arrays (which would cause
  // unnecessary topic reloads on every read/follow action).
  const readIdsRef     = useRef<Set<string>>(new Set());
  const followedIdsRef = useRef<Set<string>>(new Set());
  useEffect(() => { readIdsRef.current = readIds; }, [readIds]);
  useEffect(() => { followedIdsRef.current = followedIds; }, [followedIds]);

  useEffect(() => {
    Promise.all([
      persistence.getReadIds(),
      persistence.getFollowedIds(),
      persistence.getSavedItems(),
      persistence.getLastVisit(),
    ]).then(([reads, follows, saved, lastVisit]) => {
      setReadIds(reads);
      setFollowedIds(follows);
      setSavedIds(new Set(saved.filter((s) => s.kind === 'forumTopic').map((s) => s.id)));
      lastVisitRef.current = lastVisit || null;
    });
  }, []);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'background' || state === 'inactive') persistence.stampVisit();
    });
    return () => sub.remove();
  }, []);

  // Synchronous — uses refs so it never causes loadTopics to be recreated
  // when read/follow state changes.
  const annotate = useCallback(
    (list: ForumTopic[]): ForumTopic[] =>
      list.map((t) => ({
        ...t,
        isUnread:    !readIdsRef.current.has(t.id),
        isFollowing: followedIdsRef.current.has(t.id),
        isSaved:     savedIds.has(t.id),
      })),
    [savedIds],
  );

  const loadTopics = useCallback(async (activeFilter: ForumFilter, background = false) => {
    if (background) {
      setRefreshing(true);
    } else {
      setLoading(true);
      setError(null);
      setPage(0);
      setHasMore(false);
      setFromCache(false);
      setCachedAt(undefined);
    }

    const finish = (isBackground: boolean) => {
      if (isBackground) setRefreshing(false);
      else setLoading(false);
    };

    // ── Local-only: Saved ───────────────────────────────────────────────────
    if (activeFilter === 'Saved') {
      const saved = await persistence.getSavedItems();
      const forumSaved = saved.filter((s) => s.kind === 'forumTopic');
      setTopics(
        forumSaved.map((s) => ({
          id: s.id,
          title: s.title,
          meta: `Saved · last activity ${relativeTime(s.lastActivityAt ?? s.savedAt)}`,
          authorName: '',
          createdAt: s.savedAt,
          lastActivityAt: s.lastActivityAt ?? s.savedAt,
          replyCount: 0,
          isUnread: false,
          isFollowing: true,
          isSaved: true,
        })),
      );
      finish(background);
      return;
    }

    // ── Local-only: Following ───────────────────────────────────────────────
    if (activeFilter === 'Following') {
      const ids = await persistence.getFollowedIds();
      if (ids.size === 0) {
        if (!background) setTopics([]);
        finish(background);
        return;
      }

      const idArray = Array.from(ids).slice(0, MAX_FOLLOWING);
      if (ids.size > MAX_FOLLOWING) {
        showToast(`Showing first ${MAX_FOLLOWING} followed topics.`, 'warning');
      }

      const result = await cachedApi.forums.topicsById(idArray);
      if (result.ok) {
        setTopics(annotate(result.data.items));
        setFromCache(result.fromCache);
        setCachedAt(result.fromCache ? result.cachedAt : undefined);
      } else if (!background) {
        setError(result.error);
      }
      finish(background);
      return;
    }

    // ── Server-fetched filters ──────────────────────────────────────────────
    const sinceDate = activeFilter === 'Since Last Visit' ? lastVisitRef.current ?? undefined : undefined;
    const result = await cachedApi.forums.list(activeFilter, 0, sinceDate);

    if (!result.ok) {
      if (!background) setError(result.error);
      finish(background);
      return;
    }

    setFromCache(result.fromCache);
    setCachedAt(result.fromCache ? result.cachedAt : undefined);
    setHasMore(result.data.hasMore);
    setPage(0);

    let list = result.data.items;
    if (activeFilter === 'Unread') list = list.filter((t) => !readIdsRef.current.has(t.id));
    setTopics(annotate(list));
    finish(background);
  }, [savedIds, showToast, annotate]);

  const loadMore = useCallback(async () => {
    if (!hasMore || isLoadingMore || filter === 'Saved' || filter === 'Following') return;
    setIsLoadingMore(true);

    const nextPage = page + 1;
    const sinceDate = filter === 'Since Last Visit' ? lastVisitRef.current ?? undefined : undefined;
    const result = await cachedApi.forums.list(filter, nextPage, sinceDate);

    if (result.ok) {
      let newItems = result.data.items;
      if (filter === 'Unread') newItems = newItems.filter((t) => !readIdsRef.current.has(t.id));
      setTopics((prev) => [...prev, ...annotate(newItems)]);
      setHasMore(result.data.hasMore);
      setPage(nextPage);
    }
    setIsLoadingMore(false);
  }, [hasMore, isLoadingMore, filter, page, annotate]);

  useEffect(() => { loadTopics(filter); }, [filter, loadTopics]);

  const setFilter = useCallback((f: ForumFilter) => setFilterState(f), []);

  // Pull-to-refresh: keep existing data visible while fetching fresh content.
  const refresh = useCallback(async () => {
    apiHealth.reset();
    apiHealth.probe();
    await loadTopics(filter, true);
  }, [filter, loadTopics]);

  const markRead = useCallback(async (id: string) => {
    await persistence.markRead(id);
    setReadIds((prev) => new Set([...prev, id]));
    setTopics((prev) => prev.map((t) => (t.id === id ? { ...t, isUnread: false } : t)));
    await Haptics.selectionAsync();
    showToast('Marked as read.', 'success');
  }, [showToast]);

  const toggleFollow = useCallback(async (id: string, currentlyFollowing: boolean) => {
    if (currentlyFollowing) {
      await persistence.unfollowTopic(id);
      setFollowedIds((prev) => { const s = new Set(prev); s.delete(id); return s; });
      setTopics((prev) => prev.map((t) => (t.id === id ? { ...t, isFollowing: false } : t)));
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      showToast('Unfollowed topic.', 'success');
    } else {
      await persistence.followTopic(id);
      setFollowedIds((prev) => new Set([...prev, id]));
      setTopics((prev) => prev.map((t) => (t.id === id ? { ...t, isFollowing: true } : t)));
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

      const result = await api.forums.follow(id, '');
      if (!result.ok && result.status === 401) {
        authEvents.emitSessionExpiry();
      } else if (result.ok) {
        showToast('Following topic.', 'success');
      } else {
        showToast('Following saved. Server sync not yet available.', 'warning');
      }
    }
  }, [showToast]);

  return {
    filter, setFilter,
    topics,
    loading, refreshing, error,
    fromCache, cachedAt,
    hasMore, isLoadingMore,
    markRead, toggleFollow,
    refresh, loadMore,
  };
}
