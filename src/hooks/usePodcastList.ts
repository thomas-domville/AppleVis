import { useCallback, useEffect, useState } from 'react';
import { cachedApi } from '../services/cachedApi';
import { apiHealth } from '../services/apiHealth';
import type { PodcastEpisode } from '../types/content';

export function usePodcastList(tagTid?: number) {
  const [episodes, setEpisodes]           = useState<PodcastEpisode[]>([]);
  const [loading, setLoading]             = useState(true);
  const [refreshing, setRefreshing]       = useState(false);
  const [error, setError]                 = useState<string | null>(null);
  const [fromCache, setFromCache]         = useState(false);
  const [cachedAt, setCachedAt]           = useState<number | undefined>(undefined);
  const [page, setPage]                   = useState(0);
  const [hasMore, setHasMore]             = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  const load = useCallback(async (background = false) => {
    if (background) {
      setRefreshing(true);
    } else {
      setLoading(true);
      setError(null);
      setPage(0);
      setHasMore(false);
    }

    const result = await cachedApi.podcasts.episodes(0, tagTid);

    if (result.ok) {
      setEpisodes(result.data.items);
      setHasMore(result.data.hasMore);
      setPage(0);
      setFromCache(result.fromCache);
      setCachedAt(result.fromCache ? result.cachedAt : undefined);
    } else if (!background) {
      setError(result.error);
      setFromCache(false);
      setCachedAt(undefined);
    }

    if (background) setRefreshing(false);
    else setLoading(false);
  }, [tagTid]);

  const loadMore = useCallback(async () => {
    if (!hasMore || isLoadingMore) return;
    setIsLoadingMore(true);
    const nextPage = page + 1;
    const result = await cachedApi.podcasts.episodes(nextPage, tagTid);
    if (result.ok) {
      setEpisodes((prev) => [...prev, ...result.data.items]);
      setHasMore(result.data.hasMore);
      setPage(nextPage);
    }
    setIsLoadingMore(false);
  }, [hasMore, isLoadingMore, page, tagTid]);

  // Pull-to-refresh: keep existing episodes visible while fetching fresh content.
  const refresh = useCallback(async () => {
    apiHealth.reset();
    apiHealth.probe();
    await load(true);
  }, [load]);

  useEffect(() => { load(); }, [load]);

  return { episodes, loading, refreshing, error, fromCache, cachedAt, hasMore, isLoadingMore, refresh, loadMore };
}
