/**
 * Session-scoped API health monitor.
 *
 * Call probe() once on app start. It fires a minimal request to each endpoint
 * group and marks any that fail as 'down' for the lifetime of the session.
 * If a live API call later fails, markDown() can be called to disable that
 * group for the rest of the session too.
 *
 * Unknown groups are treated as available (optimistic default).
 */

const JSONAPI = 'https://www.applevis.com/jsonapi';
const PROBE_TIMEOUT_MS = 3000;

export type ApiGroup = 'forums' | 'podcasts' | 'apps' | 'resources';
export type HealthStatus = 'unknown' | 'up' | 'down';

const _status: Record<ApiGroup, HealthStatus> = {
  forums: 'unknown',
  podcasts: 'unknown',
  apps: 'unknown',
  resources: 'unknown',
};

const PROBES: Record<ApiGroup, string> = {
  forums:    '/node/forum?page[limit]=1',
  podcasts:  '/node/podcast?page[limit]=1',
  apps:      '/node/ios_app_directory?page[limit]=1',
  resources: '/node/guides?page[limit]=1',
};

export const apiHealth = {
  async probe(): Promise<void> {
    await Promise.allSettled(
      (Object.entries(PROBES) as [ApiGroup, string][]).map(async ([group, path]) => {
        const ctrl = new AbortController();
        const timer = setTimeout(() => ctrl.abort(), PROBE_TIMEOUT_MS);
        try {
          const res = await fetch(`${JSONAPI}${path}`, {
            headers: { Accept: 'application/vnd.api+json' },
            signal: ctrl.signal,
          });
          _status[group] = res.ok ? 'up' : 'down';
        } catch {
          _status[group] = 'down';
        } finally {
          clearTimeout(timer);
        }
      }),
    );
  },

  // Returns true for 'unknown' (not yet probed) and 'up'; false only for 'down'.
  isAvailable(group: ApiGroup): boolean {
    return _status[group] !== 'down';
  },

  markDown(group: ApiGroup): void {
    _status[group] = 'down';
  },

  getStatus(): Readonly<Record<ApiGroup, HealthStatus>> {
    return { ..._status };
  },

  // Reset one group (or all groups) back to 'unknown' so the next fetch
  // attempt goes live again. Call this before pull-to-refresh.
  reset(group?: ApiGroup): void {
    if (group) {
      _status[group] = 'unknown';
    } else {
      (Object.keys(_status) as ApiGroup[]).forEach((g) => { _status[g] = 'unknown'; });
    }
  },

  // True only when every group has been probed and all are down (fully offline).
  isFullyOffline(): boolean {
    const statuses = Object.values(_status) as HealthStatus[];
    return statuses.every((s) => s === 'down');
  },
};
