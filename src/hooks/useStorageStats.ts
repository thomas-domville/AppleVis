import { useCallback, useEffect, useState } from 'react';
import { contentCache } from '../services/contentCache';
import { getDownloadedSize } from '../services/downloads';

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

export type StorageStats = {
  downloadsBytes: number;
  cacheBytes: number;
  formattedDownloads: string;
  formattedCache: string;
  formattedTotal: string;
  isLoading: boolean;
  refresh: () => Promise<void>;
};

export function useStorageStats(): StorageStats {
  const [downloadsBytes, setDownloadsBytes] = useState(0);
  const [cacheBytes, setCacheBytes] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    const [dl, cache] = await Promise.all([
      getDownloadedSize(),
      contentCache.getByteSize(),
    ]);
    setDownloadsBytes(dl);
    setCacheBytes(cache);
    setIsLoading(false);
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  return {
    downloadsBytes,
    cacheBytes,
    formattedDownloads: formatBytes(downloadsBytes),
    formattedCache: formatBytes(cacheBytes),
    formattedTotal: formatBytes(downloadsBytes + cacheBytes),
    isLoading,
    refresh,
  };
}
