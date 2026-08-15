# 01 — Executive Migration Summary

## What this audit covered

A complete evidence-backed parity comparison between the last Expo/React Native AppleVis release (version 2026.0.7, git HEAD `d58a458`) and the current native Swift/SwiftUI rewrite (`AppleVisSwift`), across 81 legacy routes, 32 shared components, 13 contexts, 27 hooks, 23 services, 17 native config plugins, 34 assets, 23 locales, and 15 theme IDs, mapped against 126 native Swift source files. Twelve parallel research lenses independently read both trees, cross-referenced each other's findings, and are compiled into 15 ledger files plus a supplementary Temp-requirements disposition audit under `docs/audits/01-migration-parity/`. This is inventory and diagnosis only — nothing has been fixed.

## Top-line numbers

Across ~522 deduplicated, individually-evidenced findings: **283 PASS** (54%, including a meaningful number of documented native improvements), **122 PARTIAL** (23%), **52 MISSING** (10%), **18 REGRESSION** (3%), **16 MANUAL VERIFY** (3%, self-acknowledged or structurally uncertain issues awaiting on-device confirmation), plus 6 correctly INTENTIONALLY DEFERRED (Watch/Widgets/Dynamic Island/Live Activities), 15 NOT APPLICABLE, and 10 UNKNOWN / INSUFFICIENT EVIDENCE. Full breakdown and methodology in `15_FINAL_COUNTS.md`; curated, ranked, deduplicated action items in `14_RANKED_REPAIR_BACKLOG.md` (58 items across 5 tiers).

## Overall verdict

The migration is **substantively real, not a shell.** Every major product area exists natively with genuine behavior behind it — Home, Discover, For You, Forums, Podcasts, Apps, Blogs, Bugs, Resources, Profile, Settings, Onboarding, Help, Guided Experience, and all five submission wizards. All 15 authoritative theme IDs survived the rewrite with exact hex-for-hex color parity. Several previously-stubbed legacy features (Voice Boost, Trim Silence, Spotlight indexing, iCloud conflict resolution) are now genuinely implemented for the first time. Native's automated accessibility-API usage looks numerically lower than legacy's, but that's expected and not itself evidence of a gap — SwiftUI's Form/Toggle/List/NavigationLink synthesize correct semantics for free where React Native needed everything spelled out manually; the row-by-row ledgers, not the raw counts, are the reliable evidence, and they show real, substantive coverage.

But the migration is **not release-ready**, for two separate reasons that must not be conflated: release-configuration blockers (fixable in hours to days) and functional/accessibility regressions (fixable but requiring real engineering and, in a few cases, a product decision).

## The single most important thing to know before starting implementation

**The native app's Submit App wizard can currently be published with a completely blank accessibility assessment.** `SubmitAppView.swift`'s validation (`isValid`) checks only that App Name, App Store URL, and Category are non-empty — OS version, VoiceOver Performance, Button Labelling, Usability, and the accessibility comments field are entirely unenforced. This was found independently by two different research lenses reading the same source (the feature-parity audit and the route-map audit), both citing the exact same line numbers in `SubmitAppView.swift`. AppleVis exists specifically to document accessibility information about apps; a submission path that lets that information be skipped entirely is not a peripheral bug, it undermines the product's core purpose. Fix this first, before anything else on the repair backlog, including the release-configuration blockers — a correctly-signed app that can silently accept accessibility-free submissions is worse than a broken build.

Two more submission-wizard gaps compound this and were also independently confirmed by full source reads: **no platform picker exists** (`ItunesAPI.swift` hardcodes `entity=software`, so macOS/tvOS apps cannot be submitted at all), and **no duplicate-in-directory check exists anywhere** (confirmed by an exhaustive grep). All three should be treated as one connected piece of work, not three separate tickets — see backlog items 6, 6b, and 6c in `14_RANKED_REPAIR_BACKLOG.md`.

## What else needs attention before release, in order

1. **Release-configuration blockers** (Tier 0, `14_RANKED_REPAIR_BACKLOG.md`): no `Assets.xcassets`/`AppIcon` catalog exists despite the Xcode build setting referencing one (archive will likely fail or ship with a blank icon); bundle identifier, version, build number, and iOS deployment target all diverge from production values in ways that would break App Store continuity; the associated-domains entitlement needed for universal links is entirely absent; and the checked-in APNs entitlement is hardcoded to the development environment. None of these require deep engineering — they require deliberate configuration decisions, ideally made together as a single "release readiness" pass.
2. **Data continuity**: there is no data-level migration path from an existing Expo-app install to the native build — confirmed by exhaustive grep for legacy's storage-key patterns anywhere in native source. Every local preference, saved/followed item, playback position, cached download, and auth session resets to native defaults on first launch, even for a user on the same iCloud account with sync previously enabled. If this app is meant to replace the existing AppleVis on users' devices rather than launch as a new install, this needs an explicit decision and, likely, a one-time migration routine.
3. **Push notifications may not work at all**: native registers a raw APNs device token against a Drupal field the legacy app populated with an Expo push token, drops the `remote-notification` background mode, and native's own code comments flag the resulting delivery risk explicitly. This needs backend coordination, not just client-side work.
4. **Accessibility regressions with concrete, reproducible evidence** (not speculation): the episode transcript renders as one giant unnavigable text block instead of per-cue elements (a real braille/VoiceOver regression on long transcripts); the forum/blog/episode compose body field has no accessibility label or hint at all; a self-acknowledged, unresolved duplicate-VoiceOver-announcement bug in the shared long-press context-menu pattern spans Forums, Apps, Resources, Blogs, and Bug rows; Home's pull-to-refresh no longer announces outcome ("N new items" / "no new items"); and the welcome flow no longer restores VoiceOver focus to a returning user's last-read item, only to the greeting card.
5. **Core feature loss beyond accessibility**: no general background feed-refresh task exists (only podcast auto-download runs in the background — confirmed by a full-tree grep for every `BGTaskScheduler` variant); the entire "Site Results" full-text search fallback category is gone, so search can only match six typed JSON:API categories; forum threads have no new-reply indicator at all (native's own comment confirms this was never built); and Card Density has zero visible effect anywhere in the For You tab despite working correctly on Home.

## What's genuinely good and should be protected during repair

This audit deliberately looked for regressions and found real ones, but it also found deliberate, well-documented improvements that must not be undone in the name of "matching legacy": working Spotlight search (legacy's was dead code, never wired up), functional Voice Boost and Trim Silence audio processing (legacy's native module explicitly stubbed both), a materially better iCloud conflict-resolution strategy for saved/followed items and settings (shadow-merge vs. legacy's whole-blob overwrite), real AVAudioSession interruption handling that legacy never had, live download-progress UI, and a more robust AirPlay route picker that doesn't rely on a private-API workaround. The repair-phase rules in `15_REPAIR_PHASE_RULES.md` explicitly require preserving these.

## Deliverables in this package

| # | File | Contents |
|---|---|---|
| 01 | `01_EXECUTIVE_SUMMARY.md` | This file |
| 02 | `02_ROUTE_SCREEN_MAP.md` | All 81 legacy routes mapped to native destinations |
| 03 | `03_FEATURE_BEHAVIOR_PARITY_LEDGER.md` | Screen/feature behavior comparison across Home, Discover, For You, Search, Forums, Apps, Resources, Profile, Settings, Onboarding, Help, and all submission wizards |
| 04 | `04_VISUAL_THEME_LOW_VISION_LEDGER.md` | All 15 themes hex-verified; card density, Dynamic Type, contrast, asset disposition |
| 05 | `05_ACCESSIBILITY_LEDGER.md` | VoiceOver, Switch Control, Voice Control, keyboard, braille |
| 06 | `06_DATA_STATE_PERSISTENCE_LEDGER.md` | Every persisted key, migration compatibility, iCloud sync scope |
| 07 | `07_NATIVE_INTEGRATION_CAPABILITY_LEDGER.md` | Share Extension, Handoff, Spotlight, Siri, Focus Filter, AirPlay, deferral cleanup |
| 08 | `08_API_NETWORK_OFFLINE_LEDGER.md` | Endpoint-by-endpoint mapping, caching, background fetch, failure handling |
| 09 | `09_PODCAST_AUDIO_LEDGER.md` | Full player/queue/downloads/audio-effects/Now Playing subsystem |
| 10 | `10_LIFECYCLE_DEEPLINK_NOTIFICATION_LEDGER.md` | Deep links, notifications, app lifecycle matrix |
| 11 | `11_SECURITY_PRIVACY_APPSTORE_LEDGER.md` | Auth storage, entitlements, release readiness |
| 12 | `12_MANUAL_REAL_DEVICE_TEST_LIST.md` | 74 on-device test cases derived from every MANUAL VERIFY finding above |
| 13 | `13_ORPHAN_DEAD_STALE_CAPABILITY_LIST.md` | Dead settings, stale copy, duplicate findings, deferral cleanup audit |
| 14 | `14_RANKED_REPAIR_BACKLOG.md` | 58 curated, tiered, deduplicated action items (reference only, not implemented) |
| 15 | `15_FINAL_COUNTS.md` | Full status/severity tallies and reconciliation methodology |
| 16 | `16_TEMP_REQUIREMENT_DISPOSITION.md` | Phase-by-phase disposition of the Temp/ product-enhancement backlog |

## What remains genuinely unresolved

10 findings across the ledgers are marked UNKNOWN / INSUFFICIENT EVIDENCE — each one states the specific follow-up read or device test needed to resolve it (see the individual ledgers). 16 more are MANUAL VERIFY and require on-device VoiceOver/Switch Control/hardware-keyboard testing before their true severity can be confirmed; `12_MANUAL_REAL_DEVICE_TEST_LIST.md` gives a concrete test for every one of them. No further static-analysis work will resolve these — they need real devices, real accounts, and in a few cases (the associated-domains entitlement, the push-token format, the App Store legal disclosure) coordination with backend/legal stakeholders outside this codebase.
