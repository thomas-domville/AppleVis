import { useState, useEffect, useCallback } from 'react';
import { persistence } from '../services/persistence';
import { downloadEpisode, deleteDownload } from '../services/downloads';

export function useEpisodeMeta() {
  const [positions, setPositions]   = useState<Record<string, number>>({});
  const [downloaded, setDownloaded] = useState<Record<string, string>>({});
  const [downloading, setDownloading] = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    const [pos, dl] = await Promise.all([
      persistence.getPodcastPositions(),
      persistence.getDownloadedEpisodes(),
    ]);
    setPositions(pos);
    setDownloaded(dl);
  }, []);

  useEffect(() => { load(); }, [load]);

  const startDownload = useCallback(async (
    episodeId: string,
    audioUrl: string,
  ): Promise<{ ok: boolean; error?: string }> => {
    setDownloading(prev => new Set(prev).add(episodeId));
    const result = await downloadEpisode(episodeId, audioUrl);
    setDownloading(prev => { const s = new Set(prev); s.delete(episodeId); return s; });
    if (result.ok && result.localUri) {
      setDownloaded(prev => ({ ...prev, [episodeId]: result.localUri! }));
    }
    return result;
  }, []);

  const removeDownload = useCallback(async (episodeId: string): Promise<void> => {
    await deleteDownload(episodeId);
    setDownloaded(prev => { const d = { ...prev }; delete d[episodeId]; return d; });
  }, []);

  return { positions, downloaded, downloading, startDownload, removeDownload, reload: load };
}
