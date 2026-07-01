import { useCallback, useEffect, useState } from 'react';
import { api } from '../services/api';
import type { AppCategory, AppCategoryProbe, AppListing } from '../types/content';

function hasPreviewFields(app: AppListing): boolean {
  return !!(
    app.price ||
    app.createdAt ||
    app.lastActivityAt ||
    app.voiceOverPerformance ||
    app.buttonLabelling ||
    app.usabilityNotes
  );
}

function previewFieldCount(apps: AppListing[]): number {
  return apps.reduce((count, app) => count + (hasPreviewFields(app) ? 1 : 0), 0);
}

function mergeListingPreview(base: AppListing, enriched: AppListing): AppListing {
  return {
    ...base,
    price: enriched.price ?? base.price,
    supportedDevices: enriched.supportedDevices ?? base.supportedDevices,
    voiceOverPerformance: enriched.voiceOverPerformance ?? base.voiceOverPerformance,
    buttonLabelling: enriched.buttonLabelling ?? base.buttonLabelling,
    usabilityNotes: enriched.usabilityNotes ?? base.usabilityNotes,
    createdAt: enriched.createdAt ?? base.createdAt,
    lastActivityAt: enriched.lastActivityAt ?? base.lastActivityAt,
    lastUpdatedAt: enriched.lastUpdatedAt || base.lastUpdatedAt,
    reviewCount: enriched.reviewCount || base.reviewCount,
    appStoreUrl: enriched.appStoreUrl || base.appStoreUrl,
    iconUrl: enriched.iconUrl ?? base.iconUrl,
  };
}

async function enrichSparsePreviewFields(apps: AppListing[]): Promise<AppListing[]> {
  const enriched: AppListing[] = [];
  const batchSize = 6;

  for (let i = 0; i < apps.length; i += batchSize) {
    const batch = apps.slice(i, i + batchSize);
    const results = await Promise.all(batch.map(async (app) => {
      if (hasPreviewFields(app) || app.id.startsWith('public:')) return app;
      const listing = await api.apps.listing(app.id);
      return listing.ok ? mergeListingPreview(app, listing.data) : app;
    }));
    enriched.push(...results);
  }

  return enriched;
}

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

    if (apiResult.ok) {
      const needsRicherPreview = previewFieldCount(apiResult.data.items) === 0;
      if (needsRicherPreview) {
        const jsonApiResult = await api.apps.categoryExperiment(category, platform, nextPage);
        if (jsonApiResult.ok && previewFieldCount(jsonApiResult.data.items) > 0) {
          attempted.push(...apiResult.data.probe.attemptedFields);
          result = jsonApiResult;
        } else if (!jsonApiResult.ok) {
          attempted.push(...jsonApiResult.attemptedFields);
        }
      }
    } else {
      attempted.push(...apiResult.attemptedFields);
      const jsonApiResult = await api.apps.categoryExperiment(category, platform, nextPage);
      result = jsonApiResult;
      if (!jsonApiResult.ok) {
        attempted.push(...jsonApiResult.attemptedFields);
        result = await api.apps.publicCategory(category, platform, nextPage);
      }
    }

    if (result.ok) {
      const items = previewFieldCount(result.data.items) === 0
        ? await enrichSparsePreviewFields(result.data.items)
        : result.data.items;
      setApps((prev) => nextPage === 0 ? items : [...prev, ...items]);
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
