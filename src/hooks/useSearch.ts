import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '../services/api';
import type { ForumTopic, AppListing, Resource, SearchResult } from '../types/content';

export type SearchResults = {
  site:      SearchResult[];
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
  source:    'api' | 'public' | 'title' | null;
  search:    (query: string) => void;
  clear:     () => void;
};

const EMPTY: SearchResults = { site: [], forums: [], apps: [], resources: [] };

export function useSearch(): SearchState {
  const [results, setResults] = useState<SearchResults>(EMPTY);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [source, setSource] = useState<SearchState['source']>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const run = useCallback(async (q: string) => {
    const trimmed = q.trim();
    if (trimmed.length < 2) {
      setResults(EMPTY);
      setLoading(false);
      setError(null);
      setSource(null);
      return;
    }

    setLoading(true);
    setError(null);
    setSource(null);

    const fullText = await api.search.fullText(trimmed);
    const publicSite = fullText.ok ? null : await api.search.publicSite(trimmed);

    const [forums, apps, resources] = await Promise.allSettled([
      api.search.forums(trimmed),
      api.search.apps(trimmed),
      api.search.resources(trimmed),
    ]);

    setResults({
      site: fullText.ok ? fullText.data : publicSite?.ok ? publicSite.data : [],
      forums: forums.status === 'fulfilled' && forums.value.ok ? forums.value.data.items : [],
      apps: apps.status === 'fulfilled' && apps.value.ok ? apps.value.data.items : [],
      resources: resources.status === 'fulfilled' && resources.value.ok ? resources.value.data.items : [],
    });

    setSource(fullText.ok ? 'api' : publicSite?.ok ? 'public' : 'title');

    const anyError =
      (!fullText.ok && !publicSite?.ok) ||
      forums.status === 'rejected' ||
      apps.status === 'rejected' ||
      resources.status === 'rejected';
    if (anyError) {
      setError('Some results may be missing. AppleVis search is using the available fallback sources.');
    }

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
    setSource(null);
    setLoading(false);
  }, []);

  useEffect(() => () => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
  }, []);

  const totalCount = results.site.length + results.forums.length + results.apps.length + results.resources.length;

  return { results, loading, error, hasQuery: query.trim().length >= 2, totalCount, source, search, clear };
}
