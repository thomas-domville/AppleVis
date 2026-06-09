import { router } from 'expo-router';

/**
 * Universal Links handler for applevis.com URLs.
 *
 * Apple associated domains entitlement (already in app.json):
 *   applinks:www.applevis.com
 *   applinks:applevis.com
 *
 * The server must serve a valid apple-app-site-association (AASA) file at:
 *   https://www.applevis.com/.well-known/apple-app-site-association
 *
 * Minimal AASA contents:
 * {
 *   "applinks": {
 *     "details": [{
 *       "appIDs": ["TEAMID.com.applevis.app"],
 *       "components": [
 *         { "/": "/forum/*" },
 *         { "/": "/accessibility-apps/*" },
 *         { "/": "/podcast/*" },
 *         { "/": "/resources/*" },
 *         { "/": "/node/*" }
 *       ]
 *     }]
 *   }
 * }
 *
 * The AASA must be served with Content-Type: application/json and must NOT
 * redirect. CDN caching is fine (Apple caches it too).
 */

const APPLEVIS_HOSTS = new Set(['www.applevis.com', 'applevis.com']);

function getHostAndPath(url: string): { host: string; path: string } | null {
  try {
    const parsed = new URL(url);
    return { host: parsed.hostname, path: parsed.pathname };
  } catch {
    return null;
  }
}

/**
 * Inspects an incoming URL (from Universal Link or custom scheme)
 * and navigates to the correct tab/screen.
 *
 * Returns true if the URL was handled, false if it was ignored.
 */
export function handleIncomingUrl(url: string): boolean {
  // ── Custom scheme (applevis://[action]?[params]) ────────────────────────────
  if (url.startsWith('applevis://')) {
    const withoutScheme = url.replace(/^applevis:\/\//, '');
    const qMark = withoutScheme.indexOf('?');
    const action = (qMark === -1 ? withoutScheme : withoutScheme.slice(0, qMark)).toLowerCase();
    const params = qMark !== -1 ? new URLSearchParams(withoutScheme.slice(qMark + 1)) : new URLSearchParams();

    if (action === 'submit-app') {
      const appUrl = params.get('url') ?? '';
      if (appUrl) {
        router.push({ pathname: '/submit-app', params: { url: appUrl } });
      } else {
        router.push('/submit-app');
      }
      return true;
    }

    if (action === 'share') {
      // Generic share — route to forums; refine per content type in future.
      router.push('/(tabs)/forums');
      return true;
    }

    return false;
  }

  // ── Universal links (applevis.com) ──────────────────────────────────────────
  const parsed = getHostAndPath(url);
  if (!parsed || !APPLEVIS_HOSTS.has(parsed.host)) return false;

  const path = parsed.path;

  if (/^\/(forum|node\/\d+|community)/.test(path)) {
    router.push('/(tabs)/forums');
    return true;
  }

  if (/^\/(accessibility-apps?|app\/)/.test(path)) {
    router.push('/(tabs)/apps');
    return true;
  }

  if (/^\/(podcast|audio|episode)/.test(path)) {
    router.push('/(tabs)/podcasts');
    return true;
  }

  if (/^\/(resource|guide|tutorial|article|help)/.test(path)) {
    router.push('/(tabs)/resources');
    return true;
  }

  return false;
}
