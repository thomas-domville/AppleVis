import { router } from 'expo-router';
import { routeForContentDestination } from '../navigation/routeResolver';

/**
 * Universal Links handler for applevis.com URLs.
 *
 * Apple associated domains entitlement (already in app.config.ts):
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

    if (action === 'submit-blog') {
      const text = params.get('text') ?? '';
      if (text) {
        router.push({ pathname: '/submit-blog' as any, params: { prefillText: text } });
      } else {
        router.push('/submit-blog' as any);
      }
      return true;
    }

    if (action === 'submit-podcast') {
      router.push('/submit-podcast' as any);
      return true;
    }

    if (action === 'submit-bug') {
      router.push('/submit-bug' as any);
      return true;
    }

    if (action === 'forums') {
      router.push(routeForContentDestination('forums') as any);
      return true;
    }

    // podcasts?action=resume|play|pause|playLatest
    // Navigating to the browse screen is sufficient: usePodcastPlayer restores the
    // last episode on launch, and the player bar appears immediately if audio was
    // previously active. The action param is reserved for future in-tab dispatch.
    if (action === 'podcasts') {
      router.push(routeForContentDestination('podcasts') as any);
      return true;
    }

    // applevis://saved — Saved / Queue / Downloads live in the For You tab
    if (action === 'saved') {
      router.push(routeForContentDestination('saved') as any);
      return true;
    }

    // applevis://search?q=VoiceOver tips
    if (action === 'search') {
      const q = params.get('q') ?? '';
      if (q) {
        router.push({ pathname: '/search', params: { q } });
      } else {
        router.push('/search');
      }
      return true;
    }

    if (action === 'share') {
      // Generic share — route to the forum browse screen; refine per content type in future.
      router.push(routeForContentDestination('forums') as any);
      return true;
    }

    return false;
  }

  // ── Universal links (applevis.com) ──────────────────────────────────────────
  const parsed = getHostAndPath(url);
  if (!parsed || !APPLEVIS_HOSTS.has(parsed.host)) return false;

  const path = parsed.path;

  if (/^\/(forum|node\/\d+|community)/.test(path)) {
    router.push(routeForContentDestination('forums') as any);
    return true;
  }

  if (/^\/(accessibility-apps?|app\/)/.test(path)) {
    router.push(routeForContentDestination('apps') as any);
    return true;
  }

  if (/^\/(podcast|audio|episode)/.test(path)) {
    router.push(routeForContentDestination('podcasts') as any);
    return true;
  }

  if (/^\/(resource|guide|tutorial|article|help)/.test(path)) {
    router.push(routeForContentDestination('resources') as any);
    return true;
  }

  return false;
}
