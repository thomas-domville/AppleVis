import { useState, useEffect, useCallback } from 'react';
import { persistence } from '../services/persistence';
import { downloadEpisode, deleteDownload } from '../services/downloads';
import type { PodcastEpisode } from '../types/content';

export function useEpisodeMeta() {
  const [positions,     setPositions]     = useState<Record<string, number>>({});
  const [downloaded,    setDownloaded]    = useState<Record<string, string>>({});
  const [downloadedMeta, setDownloadedMeta] = useState<Record<string, PodcastEpisode>>({});
  const [downloading,   setDownloading]   = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    const [pos, dl, meta] = await Promise.all([
      persistence.getPodcastPositions(),
      persistence.getDownloadedEpisodes(),
      persistence.getDownloadedEpisodesMeta(),
    ]);
    setPositions(pos);
    setDownloaded(dl);
    setDownloadedMeta(meta);
  }, []);

  useEffect(() => { load(); }, [load]);

  const startDownload = useCallback(async (
    episode: PodcastEpisode,
  ): Promise<{ ok: boolean; error?: string }> => {
    setDownloading(prev => new Set(prev).add(episode.id));
    const result = await downloadEpisode(episode.id, episode.audioUrl, episode);
    setDownloading(prev => { const s = new Set(prev); s.delete(episode.id); return s; });
    if (result.ok && result.localUri) {
      setDownloaded(prev => ({ ...prev, [episode.id]: result.localUri! }));
      setDownloadedMeta(prev => ({ ...prev, [episode.id]: episode }));
    }
    return result;
  }, []);

  const removeDownload = useCallback(async (episodeId: string): Promise<void> => {
    await deleteDownload(episodeId);
    setDownloaded(prev => { const d = { ...prev }; delete d[episodeId]; return d; });
    setDownloadedMeta(prev => { const d = { ...prev }; delete d[episodeId]; return d; });
  }, []);

  return { positions, downloaded, downloadedMeta, downloading, startDownload, removeDownload, reload: load };
}
