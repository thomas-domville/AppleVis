/**
 * iTunes Search API — public, free, no authentication required.
 * Used to enrich app detail pages with live App Store metadata:
 * price, version, release notes, App Store rating, app size, etc.
 *
 * Endpoint: https://itunes.apple.com/lookup?id={numericId}
 * The numeric App Store ID is extracted from the App Store URL we already store.
 */

export type ItunesMetadata = {
  appStoreId:        string;
  appName:           string;          // trackName — app display name
  developerName:     string;          // artistName — developer or publisher
  category:          string;          // primaryGenreName — e.g. "Productivity"
  bundleId:          string;          // e.g. "com.agilebits.onepassword-ios-ifap"
  appStoreUrl:       string;          // canonical trackViewUrl from iTunes
  artworkUrl:        string;          // artworkUrl100 — 100×100 icon URL
  price:             string;          // "Free", "$2.99", etc.
  version:           string;          // "3.2.1"
  versionDate:       string;          // ISO date of current version release
  releaseNotes:      string;          // What's new in this version
  appStoreRating:    number | null;   // 0–5, all-time average
  appStoreRatingCount: number;
  fileSizeMb:        string;          // "52.4 MB"
  minimumOsVersion:  string;          // "16.0"
  ageRating:         string;          // "4+", "12+", etc.
  languages:         string[];        // ISO 2-letter codes e.g. ["EN","FR"]
  screenshotUrls:    string[];
  ipadScreenshotUrls: string[];
  developerWebsite:  string | null;   // sellerUrl — may be absent
  appStoreDescription: string;        // Full App Store description (different from AppleVis body)
};

function extractAppStoreId(url: string): string | null {
  if (!url) return null;
  const m = url.match(/\/id(\d+)/i);
  return m?.[1] ?? null;
}

function formatBytes(bytesStr: string): string {
  const b = parseInt(bytesStr, 10);
  if (isNaN(b) || b === 0) return '';
  if (b < 1_048_576) return `${(b / 1024).toFixed(0)} KB`;
  return `${(b / 1_048_576).toFixed(1)} MB`;
}

export async function fetchItunesMetadata(appStoreUrl: string): Promise<ItunesMetadata | null> {
  const id = extractAppStoreId(appStoreUrl);
  if (!id) return null;

  try {
    const res = await fetch(
      `https://itunes.apple.com/lookup?id=${id}&entity=software`,
      { headers: { Accept: 'application/json' } },
    );
    if (!res.ok) return null;

    const json = await res.json() as {
      resultCount: number;
      results: Record<string, unknown>[];
    };

    if (!json.resultCount || !json.results[0]) return null;

    const r = json.results[0] as Record<string, unknown>;

    return {
      appStoreId:          id,
      appName:             (r.trackName as string | undefined) ?? '',
      developerName:       (r.artistName as string | undefined) ?? '',
      category:            (r.primaryGenreName as string | undefined) ?? '',
      bundleId:            (r.bundleId as string | undefined) ?? '',
      appStoreUrl:         (r.trackViewUrl as string | undefined) ?? appStoreUrl,
      artworkUrl:          (r.artworkUrl100 as string | undefined) ?? (r.artworkUrl60 as string | undefined) ?? '',
      price:               (r.formattedPrice as string | undefined) ?? (r.price === 0 ? 'Free' : String(r.price ?? '')),
      version:             (r.version as string | undefined) ?? '',
      versionDate:         (r.currentVersionReleaseDate as string | undefined) ?? '',
      releaseNotes:        (r.releaseNotes as string | undefined) ?? '',
      appStoreRating:      typeof r.averageUserRating === 'number' ? r.averageUserRating : null,
      appStoreRatingCount: typeof r.userRatingCount   === 'number' ? r.userRatingCount   : 0,
      fileSizeMb:          formatBytes((r.fileSizeBytes as string | undefined) ?? ''),
      minimumOsVersion:    (r.minimumOsVersion as string | undefined) ?? '',
      ageRating:           (r.contentAdvisoryRating as string | undefined) ?? '',
      languages:           Array.isArray(r.languageCodesISO2A) ? (r.languageCodesISO2A as string[]) : [],
      screenshotUrls:      Array.isArray(r.screenshotUrls)     ? (r.screenshotUrls as string[])     : [],
      ipadScreenshotUrls:  Array.isArray(r.ipadScreenshotUrls) ? (r.ipadScreenshotUrls as string[]) : [],
      developerWebsite:    (r.sellerUrl as string | undefined) ?? null,
      appStoreDescription: (r.description as string | undefined) ?? '',
    };
  } catch {
    return null;
  }
}
