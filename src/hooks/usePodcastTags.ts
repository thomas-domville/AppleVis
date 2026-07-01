import { useEffect, useState } from 'react';
import { api } from '../services/api';
import type { PodcastTag } from '../types/content';

// Full vocabulary from /jsonapi/taxonomy_term/vocabulary_15 — confirmed 2026-06-25.
export const FALLBACK_PODCAST_TAGS: PodcastTag[] = [
  { name: 'Accessories',           tid: 108 },
  { name: 'AirTag',                tid: 252 },
  { name: 'Apple TV',              tid: 187 },
  { name: 'Apple Watch',           tid: 202 },
  { name: 'Braille',               tid: 109 },
  { name: 'Gaming',                tid: 157 },
  { name: 'HomePod',               tid: 251 },
  { name: 'Interview',             tid: 184 },
  { name: 'iOS',                   tid: 105 },
  { name: 'iOS and iPadOS Apps',   tid: 104 },
  { name: 'iPadOS',                tid: 243 },
  { name: 'iTunes',                tid: 190 },
  { name: 'Mac Apps',              tid: 117 },
  { name: 'macOS',                 tid: 116 },
  { name: 'Miscellaneous',         tid: 154 },
  { name: 'New Users',             tid: 111 },
  { name: 'News',                  tid: 110 },
  { name: 'Programming',           tid: 196 },
  { name: 'Quick Tips',            tid: 155 },
  { name: 'Review',                tid: 106 },
  { name: 'Roundtable Discussion', tid: 185 },
  { name: 'Walk-through',          tid: 107 },
];

export function usePodcastTags() {
  const [tags, setTags]       = useState<PodcastTag[]>(FALLBACK_PODCAST_TAGS);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    api.podcasts.tagVocabulary().then(result => {
      if (cancelled) return;
      // Only replace if the live fetch returned more tags than the fallback
      if (result.ok && result.data.length >= FALLBACK_PODCAST_TAGS.length) {
        setTags(result.data);
      }
      setLoading(false);
    }).catch(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, []);

  return { tags, loading };
}
