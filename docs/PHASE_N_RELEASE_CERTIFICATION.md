# Phase N — Post-Migration Cleanup & Release Certification

Reconciles `docs/audits/03-app-store-compliance/08_FINAL_COMPLIANCE_REPORT.md`
(written 2026-08-13, before Phases D–M's implementation work) against the
actual current state as of commit `75e5e34` (2026-08-15). That report is
otherwise still the authoritative full checklist — this document only
updates its "Release blockers" section and folds in this session's own
repo-hygiene/dead-code/architecture pass.

## Release blockers — updated status

| # | Blocker (as of 2026-08-13) | Status now |
|---|---|---|
| 1 | No `Assets.xcassets`/`AppIcon` catalog exists | **RESOLVED.** `Assets.xcassets/AppIcon.appiconset` exists with real icon files (`app-icon.png`, `app-icon-dark.png`, `app-icon-tinted.png`) plus `AccentColor.colorset`. |
| 2 | Bundle ID mismatch (`com.applevis.AppleVisSwift` vs. legacy `com.applevis.app`) | **RESOLVED.** `project.pbxproj` now uses `com.applevis.app` (main app) and `com.applevis.app.ShareExtension`. |
| 3 | Associated Domains entitlement absent | **RESOLVED.** `AppleVisSwift.entitlements` declares `applinks:www.applevis.com` and `applinks:applevis.com`; `DeepLinkRouter.handleUniversalLink` has a live caller (`AppleVisApp.swift`'s `.onOpenURL`). |
| 4 | Marketing version/build regressed behind legacy (`1.0`/`1` vs. `2026.0.7`/`11`) | **RESOLVED.** Now `MARKETING_VERSION = 2026.0.8`, `CURRENT_PROJECT_VERSION = 12` — post-dates the legacy reference. |
| 5 | iOS 26.5 minimum deployment target | **RESOLVED.** `IPHONEOS_DEPLOYMENT_TARGET = 17.0` across all targets. |
| 6 | Thin UGC reporting (no per-item "Report" action) | **PARTIALLY RESOLVED.** A "Report Comment" UI action now exists (accessibility action + menu item on Guide/Blog/Bug Report comments), but its handler is a stub toast ("Reporting is coming once the Drupal Flags API is confirmed.") — no real backend call yet. See `docs/BACKEND_COORDINATION_NOTES.md` for what's needed to finish this. The general Contact App Support wizard and admin-gated edit/delete/unpublish remain as the functional fallback in the meantime. |

**All of the hard release blockers (#1–#5) are resolved.** #6 has a real UI
affordance now but isn't functionally complete pending a backend
confirmation — worth an explicit App Review note if submitted before
that's finished, same as the original report suggested.

## This session's repo-hygiene / dead-code / architecture pass

Investigated 18 findings from `docs/audits/01-migration-parity/13_ORPHAN_DEAD_STALE_CAPABILITY_LIST.md`
against current source (not assumed from the doc). Results:

**Fixed this pass:**
- "Auto-Focus Search Field" setting (`searchAutoFocusEnabled`) was declared
  and shown in Settings with zero consuming code — now wired to
  `DiscoverView`'s `.searchFocused()` (iOS 17+ API), so the toggle actually
  does something.
- Added an "Account deletion does not affect local data" disclosure to
  `DeleteAccountView.swift` (downloads/queue/settings survive deletion —
  matches what `AccountEndpoints.deleteAccount` + `PersistenceStore` actually
  do, previously undisclosed).
- Extracted the Cloudflare-bypass headers (including the shared `X-App-Auth`
  secret) duplicated across `APIClient.swift` and `DrupalFormClient.swift`
  into one shared `CloudflareBypass.swift` — a header/secret rotation
  previously had to be made in two places (ARCH-01/ARCH-03).

**Investigated, audit finding does not hold (no action taken):**
- Dynamic Island copy in `HelpContent.swift`/`WhatsNewView.swift` was
  flagged as describing a nonexistent feature. It's actually accurate:
  `PlayerStore` correctly wires up `MPNowPlayingInfoCenter` +
  `MPRemoteCommandCenter`, which gives standard system Dynamic Island/Lock
  Screen playback controls automatically on supported devices — no custom
  Live Activity/ActivityKit code is needed for this, and none was ever
  required. The audit conflated "no ActivityKit found" with "no Dynamic
  Island at all," which doesn't hold given how the OS surfaces Now Playing.
- `com.apple.developer.siri` entitlement / `NSSiriUsageDescription` flagged
  as missing despite working Siri intents. Confirmed the app exclusively
  uses the modern `AppIntents`/`AppShortcutsProvider` framework (iOS 16+),
  not the legacy `Intents`/`INIntent` SiriKit framework — the entitlement
  and usage-description key are a legacy-framework requirement that
  doesn't apply here. Not adding them.
- "Apple Topics Only" (Settings, Home-feed scope) vs. "Apple Related"
  (Forums tab's own 3-state browse filter) wording difference flagged as
  an inconsistency. On inspection these are two intentionally different
  features — a binary Home-feed preference and a richer 3-state
  Forums-tab-local filter, documented as a deliberate superset in
  `ForumsBrowseView.swift`'s own header comment. Not a bug.

**Confirmed still genuinely open (out of this pass's scope — feature work, not hygiene):**
- No general background content-refresh task (only podcast auto-download
  has one) — `API-036`/`DATA-043`.
- No cache warm-up/prefetch-on-launch equivalent to the legacy app — `API-035`.
- No App Store review-prompt (`SKStoreReviewController`/`requestReview`)
  anywhere — `DATA-044`.
- No episode-duration cache, no client-side ID3 chapter parser, no play
  history, no per-show playback-speed memory — `PODCAST-032/035`,
  migration-parity ledger section E. (One note: an older project-memory
  entry claimed duration/chapter caching had been built — that memory
  predates the full Swift rewrite and is historical-only per
  `project_native_swift_migration`; it does not describe the current app.)
- "Report Comment" real backend wiring — see above.

None of these four bullets were built this pass — they're legitimate
product/feature additions, not "prove unreachable and delete" cleanup, and
building any of them wasn't part of what was asked for.

## Outstanding before submission (unchanged from the original report)

- `aps-environment = development` in checked-in entitlements — confirm the
  actual **signed archive** exports as `production` (still not verified —
  needs the real archive, not source inspection).
- `PrivacyInfo.xcprivacy`'s required-reason API codes (`CA92.1` vs.
  `1C8F.1` for the `UserDefaults(suiteName:)` App Group sharing case) still
  need a human recheck against Apple's live reason-code documentation.
- All App Store Connect metadata (description, keywords, screenshots,
  review notes, age rating, etc.) — entirely outside the codebase, still
  fully TO BE PREPARED.
- A full Archive + Organizer validation pass has still not been performed
  — this document reflects source-level readiness, not a validated archive.
