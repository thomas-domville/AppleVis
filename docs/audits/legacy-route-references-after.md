# Legacy Tab Route References — After Migration

Re-scan performed after Phases 01–05 of the Legacy Route Migration package.

## Remaining `(tabs)/(forums|podcasts|apps|resources)` matches

- `app/(tabs)/_layout.tsx` — the tab registration itself (`href: null`), now with a
  deprecation comment explaining it's a compatibility net only.
- `src/navigation/routeResolver.ts` — doc comment naming the legacy routes it replaces.
- `src/services/notifications.ts` — doc comment explaining why fallbacks avoid them.
- `docs/audits/legacy-route-references-before.md` — historical baseline record.

No `router.push` / `router.replace` call anywhere in `app/` or `src/` targets a hidden
legacy tab anymore. Every reference found in the baseline has been migrated:

| Owner phase | Status |
|---|---|
| Phase 02 (Profile) | Migrated to `/(tabs)/foryou?section=saved&savedType=...` |
| Phase 03 (Notifications) | Migrated to `routeForContentDestination(...)` |
| Phase 04 (Universal links) | Migrated to `routeForContentDestination(...)` |
| Phase 05 (Submission success) | Migrated to `routeForContentDestination('podcasts')` |

## Phase 06 decision: keep, convert, or remove

**Decision: keep (Option A), now clearly marked deprecated.**

Per `PHASE_06_DECIDE_LEGACY_ROUTE_FATE.md`'s own recommended path, converting to redirect
shims or deleting outright is explicitly gated on "a release cycle" of confirming no
external usage (deep links, Siri shortcuts, Spotlight items, or anything outside this
repo) — that can't be verified from source code alone in one sitting. Converting or
removing now would skip that safety gate.

What was done instead:
- All 4 hidden tab files (`forums.tsx`, `podcasts.tsx`, `apps.tsx`, `resources.tsx`) now
  have a `DEPRECATED` header comment pointing at their replacement browse screen.
- The `Tabs.Screen` registrations in `_layout.tsx` have a comment explaining the
  compatibility-net status and pointing at this phase doc for the next step.

**Next step for a future session/release:** re-run this scan against production
telemetry/crash reports (or simply after enough time has passed with no support
tickets about broken links), then proceed to Option B (redirect shims) per the phase
doc, and only delete the files once shims have also been live for a release.
