import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '../services/api';
import type { ForumTopic, AppListing, Resource } from '../types/content';

export type SearchResults = {
  forums:    ForumTopic[];
  apps:      AppListing[];
  resources: Resource[];
};

export type SearchState = {
  results:   SearchResults;
  loading:   boolean;
  error:     string | null;
  hasQuery:  boolean;
  totalCount: number;
  search:    (query: string) => void;
  clear:     () => void;
};

const EMPTY: SearchResults = { forums: [], apps: [], resources: [] };

export function useSearch(): SearchState {
  const [results, setResults]   = useState<SearchResults>(EMPTY);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState<string | null>(null);
  const [query, setQuery]       = useState('');
  const debounceRef             = useRef<ReturnType<typeof setTimeout> | null>(null);

  const run = useCallback(async (q: string) => {
    const trimmed = q.trim();
    if (trimmed.length < 2) {
      setResults(EMPTY);
      setLoading(false);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);

    const [forums, apps, resources] = await Promise.allSettled([
      api.search.forums(trimmed),
      api.search.apps(trimmed),
      api.search.resources(trimmed),
    ]);

    setResults({
      forums:    forums.status    === 'fulfilled' && forums.value.ok    ? forums.value.data.items    : [],
      apps:      apps.status      === 'fulfilled' && apps.value.ok      ? apps.value.data.items      : [],
      resources: resources.status === 'fulfilled' && resources.value.ok ? resources.value.data.items : [],
    });

    const anyError =
      (forums.status    === 'rejected') ||
      (apps.status      === 'rejected') ||
      (resources.status === 'rejected');
    if (anyError) setError('Some results may be missing — check your connection.');

    setLoading(false);
  }, []);

  const search = useCallback((q: string) => {
    setQuery(q);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => run(q), 500);
  }, [run]);

  const clear = useCallback(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    setQuery('');
    setResults(EMPTY);
    setError(null);
    setLoading(false);
  }, []);

  useEffect(() => () => { if (debounceRef.current) clearTimeout(debounceRef.current); }, []);

  const totalCount = results.forums.length + results.apps.length + results.resources.length;

  return { results, loading, error, hasQuery: query.trim().length >= 2, totalCount, search, clear };
}
