import { Paths, File, Directory } from 'expo-file-system';
import { persistence } from './persistence';

function getDownloadsDir(): Directory {
  const dir = new Directory(Paths.document, 'applevis-podcasts');
  if (!dir.exists) dir.create();
  return dir;
}

export async function downloadEpisode(
  episodeId: string,
  audioUrl: string,
  onProgress?: (progress: number) => void,
): Promise<{ ok: boolean; localUri?: string; error?: string }> {
  try {
    const dir = getDownloadsDir();
    const localFile = new File(dir, `${episodeId}.mp3`);

    if (localFile.exists) {
      await persistence.saveDownloadedEpisode(episodeId, localFile.uri);
      return { ok: true, localUri: localFile.uri };
    }

    // File.downloadFileAsync doesn't expose progress natively in the new API;
    // onProgress is accepted for future wiring via DownloadTask.
    const downloaded = await File.downloadFileAsync(audioUrl, localFile);
    await persistence.saveDownloadedEpisode(episodeId, downloaded.uri);
    return { ok: true, localUri: downloaded.uri };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Unknown download error' };
  }
}

export async function deleteDownload(episodeId: string): Promise<void> {
  const downloads = await persistence.getDownloadedEpisodes();
  const path = downloads[episodeId];
  if (path) {
    const file = new File(path);
    if (file.exists) file.delete();
  }
  await persistence.removeDownloadedEpisode(episodeId);
}

export async function getLocalUri(episodeId: string): Promise<string | null> {
  const downloads = await persistence.getDownloadedEpisodes();
  const path = downloads[episodeId];
  if (!path) return null;
  const file = new File(path);
  return file.exists ? file.uri : null;
}

export async function getDownloadedSize(): Promise<number> {
  try {
    const dir = new Directory(Paths.document, 'applevis-podcasts');
    if (!dir.exists) return 0;
    return dir.list().reduce((total, item) => {
      if (item instanceof File) {
        try { return total + (item.size ?? 0); } catch { return total; }
      }
      return total;
    }, 0);
  } catch {
    return 0;
  }
}

export async function deleteAllDownloads(): Promise<void> {
  const downloads = await persistence.getDownloadedEpisodes();
  await Promise.all(Object.keys(downloads).map(deleteDownload));
}
