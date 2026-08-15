# 13 — Orphan, Dead, and Stale Capability List

This is the adversarial cross-reference pass required by the methodology: settings/preferences that exist but are never consumed, capabilities that are declared but not implemented (or implemented but not declared), stale copy describing deferred/removed features, and code paths with no live caller. Compiled from findings surfaced independently across multiple ledgers, plus a direct grep pass for dead-code patterns.

Status vocabulary note: items here are drawn from MISSING/PARTIAL/REGRESSION rows already logged in the primary ledgers — this file re-groups them by "what kind of orphan they are" rather than introducing new findings, except where noted as newly observed during this cross-reference pass.

## A. Dead/inert settings (UI + storage exist, zero consuming code)

| Item | Evidence | Cross-referenced in |
|---|---|---|
| "Auto-Focus Search Field" preference (`searchAutoFocusEnabled` / `a11y.searchAutoFocus`) | Persisted `@AppStorage`, has a Settings row, but grep confirms zero read sites in `DiscoverView`/`SearchResultsView` | A11Y-003, DISC-003, SEARCH-004, Temp Phase 05 disposition row |
| Home `defaultForumFilter`-seeding behavior | `homeFeedFilter` is hardcoded to `.all` in `HomeViewModel`, never reads the persisted preference intended to seed it | HOME-009 |
| Cancel-download UI action | `DownloadManager.cancelDownload(_:)` exists and is fully implemented in the store, but no view invokes it | PODCAST-016 |

## B. Declared capability with no/incomplete backing implementation

| Item | Evidence | Cross-referenced in |
|---|---|---|
| `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` build setting | Points at an asset catalog that does not exist anywhere in the tree — no `Assets.xcassets`, no icon variants | VIS-015 (highest-priority visual finding), SEC-015 |
| `associatedDomains`/universal links | Declared in legacy config intent; native has ZERO `com.apple.developer.associated-domains` entitlement anywhere, confirmed via pbxproj + entitlements + full-repo grep — the correctly-written `DeepLinkRouter.handleUniversalLink` is consequently unreachable in production | LIFECYCLE-014, NATIVE-019, SEC-005 (same root cause, filed three times — count once) |
| `com.apple.developer.siri` entitlement / `NSSiriUsageDescription` | Absent despite 7 working AppIntents that plausibly don't require it | NATIVE-007, SEC-007 |
| `remote-notification` background mode | Declared by legacy, absent from native's `UIBackgroundModes` (`[audio, processing]` only) | NATIVE-013, SEC-008 |
| Push token type mismatch | Native registers a raw APNs device token against a Drupal field legacy populated with an Expo push token — native's own code comment flags delivery as likely broken | API-026 |
| General background feed-refresh task | Full-tree grep for `BGTaskScheduler`/`BGAppRefreshTask`/`BGProcessingTask` finds only the podcast auto-download task — no general content-refresh background task exists at all, despite legacy running two | API-036, DATA-043 |
| Cache warm-up / prefetch-on-launch | No equivalent to legacy's `apiHealth.probe()` + `cachedApi.prefetchAll()` anywhere native | API-035 |
| App Store review-prompt system | Legacy's 90-day-cooldown/3-action-threshold `StoreKit` review prompt has zero native counterpart — confirmed via exhaustive grep, zero hits for `requestReview`/`SKStoreReviewController` | DATA-044 |

## C. Stale copy describing features that don't exist (or no longer match reality)

| Item | Evidence | Cross-referenced in |
|---|---|---|
| Dynamic Island playback controls described in Help Center and What's New | `HelpContent.swift` (~lines 275, 280, 286, 890, 898) and `WhatsNewView.swift` (~lines 223, 226) describe Dynamic Island controls as shipped; no LiveActivity target/code exists anywhere (deferral itself is clean — this is purely a copy defect) | NATIVE-018 |
| "Apple-Related Forum Topics Only" filter label | Temp Phase 06 specifies this exact renamed wording; native shows a third, shorter variant ("Apple Topics Only") matching neither the old nor the new spec text | Temp disposition Phase 06 |
| Account-deletion "local data is not affected" disclosure | Legacy explicitly tells the user local downloads/cache/settings survive account deletion; native's `DeleteAccountView` has no equivalent statement even though the underlying behavior does match | PROFILE-005 (cross-referenced against SEC-003/DATA-046, which confirm the *behavior* is actually fine — this is a missing-disclosure gap, not a behavior gap) |
| "Clear Local Data" confirmation-dialog over-promise | Native's dialog text explicitly promises to clear "cache, downloads, queue, reading progress, and preferences" — the code does NOT clear queue or preferences | DATA-045 |

## D. Orphan native code vs. legacy features with no mapping (native-only additions — not defects, but flagged per the audit's "prove intentional native divergence" rule)

| Item | Evidence | Disposition |
|---|---|---|
| Spotlight indexing actually wired up and functional (deindex/deindexAll on sign-out) | Legacy's Spotlight plugin was dead code, never called from any screen | Intentional, documented improvement — LIFECYCLE-030, NATIVE-010 |
| `accessibilityConsensus` (VoiceOver-specific review-sentiment aggregation) | No legacy equivalent at all | Intentional net-new feature — NATIVE-012 |
| Voice Boost / Trim Silence real DSP processing | Legacy's own native module explicitly stubbed both ("operates in a stub mode that logs intent") | Intentional fix, not scope creep — PODCAST-024, PODCAST-026 |
| Bug-report comment submission (`ContentEndpoints.submitComment` for bugs) | Legacy's bug-report comments were read-only | Flagged for explicit product sign-off — feature addition or unintended scope drift — API-020 |
| iCloud shadow-merge conflict resolution for saved/followed/settings | Legacy used whole-blob last-write-wins overwrite | Intentional, documented improvement — DATA-001/028/029, NATIVE-009 |

## E. Legacy device-local caches with no located native counterpart (unresolved — MISSING or UNKNOWN, not confirmed absent)

| Item | Evidence | Status |
|---|---|---|
| Play history (`applevis:playHistory`, capped 100) | No equivalent found in the Stores-scoped files read this pass | MISSING or UNKNOWN — needs a second pass across `PlayerStore.swift` specifically |
| Per-show playback speed memory (`applevis:showSpeeds`) | Native's `podcast.speed` appears global-only | MISSING or UNKNOWN |
| Episode durations cache (`applevis:episodeDurations`) | No equivalent found; corroborated as a real gap by PODCAST-035 (native hardcodes `duration: 0` pre-play with no cache to fall back on) | Confirmed MISSING (elevated from UNKNOWN by the podcast ledger's independent finding) |
| Episode chapters cache (`applevis:episodeChapters`, parsed client-side from ID3 CHAP frames) | No client-side ID3 fallback parser found anywhere native; native depends entirely on Drupal's `field_chapters` | Confirmed MISSING — cross-referenced against PODCAST-032 |

## F. Deferral cleanup (Watch / Widgets / Dynamic Island / Live Activities)

Result: **clean.** No orphaned Xcode targets, entitlements, App Group keys consumed only by deferred features, notification action categories, or dangling imports were found for any of the four deferred areas. The single exception is the stale Help/What's New copy already listed in section C (NATIVE-018) — a documentation defect, not a code-cleanliness defect.

## G. Duplicate/triplicate findings across ledgers (dedupe note for the final counts and repair backlog)

The following root causes were independently discovered by more than one research lens and must be counted **once**, not once per ledger, in the final tally:

1. Missing associated-domains entitlement — appears as LIFECYCLE-014, NATIVE-019, and SEC-005.
2. Dead "Auto-Focus Search Field" setting — appears as A11Y-003, DISC-003, and SEARCH-004.
3. Long-press context menu duplicate-VoiceOver-announcement bug — appears as FORUM-007, APPS-014, and RES-009 (one shared `ContentActionsModifier`/`CommentRow` root cause).
4. Skip-back default mismatch (10s vs. 15s) — appears as DATA-014 and PODCAST-009.
5. Per-show playback speed memory absence — appears as DATA-037 and (indirectly) PODCAST-011.
6. Push-notification delivery risk — appears as API-026, NATIVE-013, SEC-008, and LIFECYCLE-028 (four related but distinct facets of the same underlying push-pipeline problem: token type, background mode, payload schema).
7. Background general-refresh task absence — appears as API-036 and DATA-043.
8. Card Density inert in For You — appears as FY-003 and is cross-referenced by VIS-002.

These are consolidated into single line items in `14_RANKED_REPAIR_BACKLOG.md` and counted once each in `15_FINAL_COUNTS.md`.
