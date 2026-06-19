import { useCallback, useEffect, useState } from 'react';
import { api } from '../services/api';
import type { AppCategory, AppCategoryProbe, AppListing } from '../types/content';

export function useAppCategoryExperiment(platform: string, category: AppCategory | null) {
  const [apps, setApps] = useState<AppListing[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [attemptedFields, setAttemptedFields] = useState<string[]>([]);
  const [probe, setProbe] = useState<AppCategoryProbe | null>(null);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  const load = useCallback(async (nextPage = 0) => {
    if (!category) return;
    if (nextPage === 0) {
      setLoading(true);
      setError(null);
      setApps([]);
      setPage(0);
      setHasMore(false);
      setProbe(null);
      setAttemptedFields([]);
    } else {
      setIsLoadingMore(true);
    }

    const attempted: string[] = [];
    const apiResult = await api.apps.category(platform, category, nextPage);
    let result:
      | typeof apiResult
      | Awaited<ReturnType<typeof api.apps.categoryExperiment>>
      | Awaited<ReturnType<typeof api.apps.publicCategory>> = apiResult;

    if (!apiResult.ok) {
      attempted.push(...apiResult.attemptedFields);
      const jsonApiResult = await api.apps.categoryExperiment(category, platform, nextPage);
      result = jsonApiResult;
      if (!jsonApiResult.ok) {
        attempted.push(...jsonApiResult.attemptedFields);
        result = await api.apps.publicCategory(category, platform, nextPage);
      }
    }

    if (result.ok) {
      setApps((prev) => nextPage === 0 ? result.data.items : [...prev, ...result.data.items]);
      setHasMore(result.data.hasMore);
      setPage(nextPage);
      setProbe(result.data.probe);
      setAttemptedFields([...attempted, ...result.data.probe.attemptedFields]);
    } else {
      setError(result.error);
      setAttemptedFields([...attempted, ...result.attemptedFields]);
    }

    setLoading(false);
    setIsLoadingMore(false);
  }, [category, platform]);

  useEffect(() => {
    if (!category) {
      setApps([]);
      setLoading(false);
      setError(null);
      setAttemptedFields([]);
      setProbe(null);
      setPage(0);
      setHasMore(false);
      return;
    }
    load(0);
  }, [category, load]);

  const retry = useCallback(() => load(0), [load]);
  const loadMore = useCallback(() => {
    if (!hasMore || isLoadingMore) return;
    load(page + 1);
  }, [hasMore, isLoadingMore, load, page]);

  return { apps, loading, error, attemptedFields, probe, hasMore, isLoadingMore, retry, loadMore };
}
