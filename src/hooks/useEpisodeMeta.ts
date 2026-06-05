import { useState, useEffect, useCallback } from 'react';
import { persistence } from '../services/persistence';
import { downloadEpisode, deleteDownload } from '../services/downloads';
import type { PodcastEpisode, SavedItem } from '../types/content';

export function useEpisodeMeta() {
  const [positions,     setPositions]     = useState<Record<string, number>>({});
  const [downloaded,    setDownloaded]    = useState<Record<string, string>>({});
  const [downloadedMeta, setDownloadedMeta] = useState<Record<string, PodcastEpisode>>({});
  const [downloading,   setDownloading]   = useState<Set<string>>(new Set());
  const [savedIds,      setSavedIds]      = useState<Set<string>>(new Set());
  const [savedMeta,     setSavedMeta]     = useState<Record<string, PodcastEpisode>>({});
  const [savedItems,    setSavedItems]    = useState<SavedItem[]>([]);

  const load = useCallback(async () => {
    const [pos, dl, meta, savedItemsData, savedEpisodeMeta] = await Promise.all([
      persistence.getPodcastPositions(),
      persistence.getDownloadedEpisodes(),
      persistence.getDownloadedEpisodesMeta(),
      persistence.getSavedItems(),
      persistence.getSavedEpisodeMeta(),
    ]);
    setPositions(pos);
    setDownloaded(dl);
    setDownloadedMeta(meta);
    setSavedIds(new Set(savedItemsData.map(s => s.id)));
    setSavedItems(savedItemsData);
    setSavedMeta(savedEpisodeMeta);
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

  const saveEpisode = useCallback(async (episode: PodcastEpisode): Promise<void> => {
    const newItem: SavedItem = { id: episode.id, kind: 'podcastEpisode', title: episode.title, savedAt: new Date().toISOString() };
    await persistence.saveItem(newItem);
    await persistence.saveSavedEpisodeMeta(episode);
    setSavedIds(prev => new Set(prev).add(episode.id));
    setSavedMeta(prev => ({ ...prev, [episode.id]: episode }));
    setSavedItems(prev => [newItem, ...prev.filter(s => s.id !== episode.id)]);
  }, []);

  const unsaveEpisode = useCallback(async (episodeId: string): Promise<void> => {
    await persistence.unsaveItem(episodeId);
    await persistence.removeSavedEpisodeMeta(episodeId);
    setSavedIds(prev => { const s = new Set(prev); s.delete(episodeId); return s; });
    setSavedMeta(prev => { const d = { ...prev }; delete d[episodeId]; return d; });
    setSavedItems(prev => prev.filter(s => s.id !== episodeId));
  }, []);

  return {
    positions, downloaded, downloadedMeta, downloading,
    savedIds, savedMeta, savedItems,
    startDownload, removeDownload, saveEpisode, unsaveEpisode,
    reload: load,
  };
}
