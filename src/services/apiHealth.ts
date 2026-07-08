/**
 * Session-scoped API health monitor.
 *
 * Call probe() once on app start. It fires a minimal request to each endpoint
 * group and marks any that fail as 'down'. If a live API call later fails,
 * markDown() can be called to disable that group too. A "down" mark expires
 * after RECOVERY_MS so a single transient failure (e.g. a slow cold-launch
 * probe) doesn't lock a whole content category out of live fetches for the
 * rest of the session.
 *
 * Unknown groups are treated as available (optimistic default).
 */

const JSONAPI = 'https://www.applevis.com/jsonapi';
const PROBE_TIMEOUT_MS = 3000;

// A single slow/failed request (e.g. a cold-launch probe timing out on a
// weak connection) shouldn't lock a whole content category out for the rest
// of the session. Treat "down" as stale after this long so the next fetch
// gets a real retry instead of an automatic offline error.
const RECOVERY_MS = 60_000;

export type ApiGroup = 'forums' | 'podcasts' | 'apps' | 'resources' | 'blogs' | 'bugs';
export type HealthStatus = 'unknown' | 'up' | 'down';

const _status: Record<ApiGroup, HealthStatus> = {
  forums: 'unknown',
  podcasts: 'unknown',
  apps: 'unknown',
  resources: 'unknown',
  blogs: 'unknown',
  bugs: 'unknown',
};

const _downSince: Partial<Record<ApiGroup, number>> = {};

function setDown(group: ApiGroup): void {
  _status[group] = 'down';
  _downSince[group] = Date.now();
}

const PROBES: Record<ApiGroup, string> = {
  forums:    '/node/forum?page[limit]=1',
  podcasts:  '/node/podcast?page[limit]=1',
  apps:      '/node/ios_app_directory?page[limit]=1',
  resources: '/node/guides?page[limit]=1',
  blogs:     '/node/blog2?page[limit]=1',
  bugs:      '/node/ios_bug_report?page[limit]=1',
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
          if (res.ok) { _status[group] = 'up'; delete _downSince[group]; }
          else setDown(group);
        } catch {
          setDown(group);
        } finally {
          clearTimeout(timer);
        }
      }),
    );
  },

  // Returns true for 'unknown' and 'up', and for 'down' once the cooldown
  // has elapsed (self-recovery from a one-off transient failure).
  isAvailable(group: ApiGroup): boolean {
    if (_status[group] !== 'down') return true;
    const since = _downSince[group];
    if (since !== undefined && Date.now() - since > RECOVERY_MS) {
      _status[group] = 'unknown';
      delete _downSince[group];
      return true;
    }
    return false;
  },

  markDown(group: ApiGroup): void {
    setDown(group);
  },

  getStatus(): Readonly<Record<ApiGroup, HealthStatus>> {
    return { ..._status };
  },

  // Reset one group (or all groups) back to 'unknown' so the next fetch
  // attempt goes live again. Call this before pull-to-refresh.
  reset(group?: ApiGroup): void {
    if (group) {
      _status[group] = 'unknown';
      delete _downSince[group];
    } else {
      (Object.keys(_status) as ApiGroup[]).forEach((g) => { _status[g] = 'unknown'; delete _downSince[g]; });
    }
  },

  // True only when every group has been probed and all are down (fully offline).
  isFullyOffline(): boolean {
    const statuses = Object.values(_status) as HealthStatus[];
    return statuses.every((s) => s === 'down');
  },
};
