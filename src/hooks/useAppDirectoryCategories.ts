import { useCallback, useEffect, useState } from 'react';
import { api } from '../services/api';
import { FALLBACK_APP_CATEGORIES } from '../data/appDirectory';
import type { AppCategory } from '../types/content';

export function useAppDirectoryCategories(platform: string) {
  const [categories, setCategories] = useState<AppCategory[]>(FALLBACK_APP_CATEGORIES[platform] ?? []);
  const [loading, setLoading] = useState(false);
  const [fromFallback, setFromFallback] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    const fallback = FALLBACK_APP_CATEGORIES[platform] ?? [];
    const result = await api.apps.categories(platform);
    if (result.ok && result.data.length > 0) {
      setCategories(result.data);
      setFromFallback(false);
    } else {
      setCategories(fallback);
      setFromFallback(true);
    }
    setLoading(false);
  }, [platform]);

  useEffect(() => {
    setCategories(FALLBACK_APP_CATEGORIES[platform] ?? []);
    setFromFallback(true);
    load();
  }, [load, platform]);

  return { categories, loading, fromFallback, refresh: load };
}
