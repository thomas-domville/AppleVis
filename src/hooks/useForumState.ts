/**
 * Forum state hook
 *
 * Manages the active filter, topic list, and all iCloud-backed user state:
 *
 * "Since Last Visit"  — queries the server for topics changed after the
 *                       last visit timestamp stored in iCloud.
 *
 * "Unread"            — shows topics whose IDs are NOT in the local read set.
 *
 * "Following"         — shows topics whose IDs ARE in the local follow set.
 *
 * "Saved"             — shows topics whose IDs are in the local saved set.
 *
 * "Recent" / "New"    — sorted by latest activity / creation date, no local
 *                       filtering needed.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import { api } from '../services/api';
import { persistence } from '../services/persistence';
import type { ForumTopic } from '../types/content';

export type ForumFilter = 'Recent' | 'New' | 'Unread' | 'Since Last Visit' | 'Following' | 'Saved';
export const FORUM_FILTERS: ForumFilter[] = ['Recent', 'New', 'Unread', 'Since Last Visit', 'Following', 'Saved'];

export function useForumState() {
  const [filter, setFilterState] = useState<ForumFilter>('Recent');
  const [topics, setTopics] = useState<ForumTopic[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [readIds, setReadIds] = useState<Set<string>>(new Set());
  const [followedIds, setFollowedIds] = useState<Set<string>>(new Set());
  const [savedIds, setSavedIds] = useState<Set<string>>(new Set());
  const lastVisitRef = useRef<string | null>(null);

  // Load local sets and last visit on mount
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

  // Stamp visit when app goes to background
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'background' || state === 'inactive') {
        persistence.stampVisit();
      }
    });
    return () => sub.remove();
  }, []);

  const loadTopics = useCallback(async (activeFilter: ForumFilter) => {
    setLoading(true);
    setError(null);

    // "Saved" and "Following" are local-only — no server call needed
    if (activeFilter === 'Saved') {
      const saved = await persistence.getSavedItems();
      const forumSaved = saved.filter((s) => s.kind === 'forumTopic');
      setTopics(
        forumSaved.map((s) => ({
          id: s.id,
          title: s.title,
          meta: `Saved · last activity ${new Date(s.lastActivityAt ?? s.savedAt).toLocaleDateString()}`,
          authorName: '',
          createdAt: s.savedAt,
          lastActivityAt: s.lastActivityAt ?? s.savedAt,
          replyCount: 0,
          isUnread: false,
          isFollowing: true,
          isSaved: true,
        })),
      );
      setLoading(false);
      return;
    }

    if (activeFilter === 'Following') {
      const ids = await persistence.getFollowedIds();
      if (ids.size === 0) {
        setTopics([]);
        setLoading(false);
        return;
      }
      // Fetch the followed topics from the server by ID
      const results = await Promise.all(
        Array.from(ids).map((id) => api.forums.topic(id)),
      );
      setTopics(
        results
          .filter((r) => r.ok)
          .map((r) => (r as { ok: true; data: ForumTopic }).data),
      );
      setLoading(false);
      return;
    }

    // For "Since Last Visit", pass the stored timestamp to the API
    const sinceDate =
      activeFilter === 'Since Last Visit' ? lastVisitRef.current ?? undefined : undefined;

    const result = await api.forums.list(activeFilter, 0, sinceDate);
    if (!result.ok) {
      setError(result.error);
      setLoading(false);
      return;
    }

    let list = result.data;

    // "Unread" — filter out topics the user has already opened
    if (activeFilter === 'Unread') {
      list = list.filter((t) => !readIds.has(t.id));
    }

    // Annotate with local state
    const reads = await persistence.getReadIds();
    const follows = await persistence.getFollowedIds();
    const savedSet = savedIds;

    list = list.map((t) => ({
      ...t,
      isUnread: !reads.has(t.id),
      isFollowing: follows.has(t.id),
      isSaved: savedSet.has(t.id),
    }));

    setTopics(list);
    setLoading(false);
  }, [readIds, followedIds, savedIds]);

  // Reload when filter changes
  useEffect(() => {
    loadTopics(filter);
  }, [filter, loadTopics]);

  const setFilter = useCallback((f: ForumFilter) => {
    setFilterState(f);
  }, []);

  const markRead = useCallback(async (id: string) => {
    await persistence.markRead(id);
    setReadIds((prev) => new Set([...prev, id]));
    setTopics((prev) =>
      prev.map((t) => (t.id === id ? { ...t, isUnread: false } : t)),
    );
  }, []);

  const toggleFollow = useCallback(async (id: string, currentlyFollowing: boolean) => {
    if (currentlyFollowing) {
      await persistence.unfollowTopic(id);
      setFollowedIds((prev) => { const s = new Set(prev); s.delete(id); return s; });
    } else {
      await persistence.followTopic(id);
      setFollowedIds((prev) => new Set([...prev, id]));
      // Best-effort server call for push notifications (silent failure is fine)
      // When the developer builds the flag endpoint, this will start working automatically
      api.forums.follow(id, '').catch(() => {});
    }
    setTopics((prev) =>
      prev.map((t) => (t.id === id ? { ...t, isFollowing: !currentlyFollowing } : t)),
    );
  }, []);

  const refresh = useCallback(() => loadTopics(filter), [filter, loadTopics]);

  return {
    filter,
    setFilter,
    topics,
    loading,
    error,
    markRead,
    toggleFollow,
    refresh,
  };
}
