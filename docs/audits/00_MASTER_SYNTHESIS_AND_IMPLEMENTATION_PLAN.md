# AppleVis Master Audit Synthesis & Implementation Plan

Synthesizes three independent audits completed 2026-08-13/14 under `docs/audits/`:
- `01-migration-parity/` — Expo 2026.0.7 vs. native Swift, ~522 deduplicated findings, 16 files
- `02-product-accessibility/` — native app audited as its own baseline, ~150+ findings, 20 files
- `03-app-store-compliance/` — release/distribution readiness, 84 checklist items, 2 files

Read-only synthesis. Nothing has been implemented yet. This is deliverable #6 in the master package's mandatory work order ("produce a prioritized implementation plan") — implementation (#7) follows only after user review.

## Overall verdict

The native rewrite is **substantively real, not a shell** — every major product area (Home, Discover, For You, Forums, Podcasts, Apps, Blogs, Bugs, Resources, Profile, Settings, Onboarding, Help, Guided Experience, all five submission wizards) exists with genuine behavior behind it. All 15 themes survived with exact hex parity. Several previously-stubbed legacy features (Voice Boost, Trim Silence, Spotlight, iCloud conflict resolution) are now genuinely implemented for the first time — protect these during repair.

The app is **not release-ready**, for three distinct reasons that must not be conflated:
1. **Release-configuration blockers** — hours-to-days of config/decisions, not engineering (App Store audit)
2. **Silent data-loss and safety-critical bugs** — small, isolated code fixes, high urgency (product-accessibility audit)
3. **Functional/accessibility regressions vs. the previous app** — real engineering, some requiring product decisions (migration-parity audit)

## The single most important thing to know

Two findings compete for "most severe," and both should be fixed before anything else, including the App Store blockers:

- **The Submit App wizard can be published with a completely blank accessibility assessment.** `SubmitAppView.swift`'s validation checks only App Name/URL/Category — OS version, VoiceOver Performance, Button Labelling, Usability, and accessibility comments are entirely unenforced. Confirmed independently by two separate audit passes reading the same source lines. AppleVis exists to document app accessibility; letting that information be skipped entirely undermines the product's core purpose.
- **Podcast audio files are silently dropped from submissions** picked via iCloud Drive/Files — a missing `startAccessingSecurityScopedResource()` call plus a swallowed `try?` read failure means the submission "succeeds" server-side with no audio attached, no error anywhere in the chain. This hits the exact workflow the app's own changelog advertises. Real, current, user-facing data loss.

## Top 25 unified findings

Merged and deduplicated across all three audits, ranked by real-world impact on AppleVis's mission (a calm, trustworthy, highly accessible experience for a blind/low-vision community), not mechanically by severity label. Source audit(s) and finding IDs in brackets.

1. **Submit App wizard: zero accessibility-assessment validation** — a blank submission goes through. `SubmitAppView.swift` lines 80-84. [migration-parity SUBMIT-005/Tier1#6, confirmed twice]
2. **Podcast submission silently drops the audio file** picked from iCloud Drive/Files, no error surfaced anywhere. [product-accessibility SUBMIT-04]
3. **Podcast playback silently loses background/Lock Screen eligibility** on the first pause — `SoundPlayer`'s confirmation sound resets the shared `AVAudioSession` to `.ambient`. [product-accessibility PODCAST-01]
4. **App icon asset catalog does not exist** — build references `AppIcon`/`AccentColor` catalogs that aren't there. Archive will fail or ship with a blank icon. [App Store #1, migration-parity Tier0#1 — release blocker]
5. **No Expo→native data migration path** — every local preference, saved/followed item, playback position, and download resets to defaults on first launch, even under identical iCloud account + sync-enabled conditions. [migration-parity Tier1#5]
6. **Duplicate VoiceOver custom actions on nearly every content card app-wide** — `ContentActionsModifier`'s context menu isn't hidden from the accessibility tree; the correct pattern already exists one call site away. Highest-reach single fix in the app. [product-accessibility CARD-01, corroborated by migration-parity FORUM-007/APPS-014/RES-009]
7. **Bundle ID / version / build / deployment target all diverge from production** (`com.applevis.AppleVisSwift` vs. `com.applevis.app`; `1.0`/`1` vs. `2026.0.7`/`11`; iOS 26.5 vs. 16.0) — needs an explicit "update existing app vs. launch new one" decision. [App Store #2/#4, migration-parity Tier0#2 — release blocker]
8. **Associated Domains entitlement missing** — universal links to applevis.com can never open the app in production, regardless of the correctly-written router code behind it. [App Store #3, migration-parity Tier0#3 — release blocker]
9. **No macOS/tvOS app-submission path exists at all** — `ItunesAPI.swift` hardcodes `entity=software` on every call. [migration-parity Tier1#6b, confirmed via source]
10. **No duplicate-app-in-directory check** before submission — the JSON:API lookup legacy used has no native equivalent anywhere. [migration-parity Tier1#6c]
11. **Push notifications likely deliver nothing** — raw APNs token registered against a field built for Expo push tokens; three independent audit passes converged on this. [all three audits — migration-parity Tier1#8, product-accessibility ARCH-02, App Store aps-environment note]
12. **Delete Account has the weakest confirmation of any destructive action in the app** — a single Toggle, no second-stage dialog, for the one truly irreversible action. [product-accessibility PROFILE-07]
13. **Submission wizards give no reliable success/failure VoiceOver feedback** — 4 of 5 wizards skip the `ThankYouView` success screen; all 5 have silent failure branches. Compounds #2 directly. [product-accessibility SUBMIT-02/03]
14. **Sign-out never clears local saved/followed/read state** — shared-device privacy leak; the next person to sign in inherits the previous user's data. [product-accessibility ARCH-04/PERS-05]
15. **Auth Keychain identifiers incompatible between legacy and native** — every upgrading signed-in user is forced to re-authenticate. [migration-parity Tier1#9]
16. **App reviews have no star-rating picker** — reviews authored natively can never carry a rating, breaking the read-side display logic that depends on this exact convention. [migration-parity Tier1#7]
17. **Two of the six required Forums filters are effectively non-functional** — a re-stamped "last visit" timestamp and dead-ending pagination make New/Since Last Visit/Unread almost always empty. [product-accessibility FORUM-01/02]
18. **No search in the App Directory at all** — a named, explicit master-spec violation. [product-accessibility APPS-01]
19. **Long forum threads are fully fetched and eagerly rendered non-lazily**, slowing exactly the interaction (VoiceOver's linear walk) most sensitive to jank. [product-accessibility FORUM-05]
20. **Podcast transcripts are one unsegmented text blob** — the app already has a working segmentation pattern that was never applied here. [product-accessibility PODCAST-04, corroborated by migration-parity A11Y-013]
21. **Search fabricates a false "No Results" VoiceOver announcement** before any search has actually run, on one of the most-used screens in the app. [product-accessibility SEARCH-01]
22. **Episode detail: VoiceOver focus never lands on the title**, plus missing Queue toggle, Play Next, Mark as Played (function doesn't exist anywhere natively), and Jump-to-First-New-Comment. [migration-parity route-map, confirmed source bug]
23. **Open-source license disclosure collapsed from 20+ real entries to exactly 1** — a legal disclosure screen that needs explicit compliance sign-off, not an assumption it's accurate. [App Store #5, migration-parity Tier0#5, confirmed via source]
24. **The two most complex, most historically bug-prone systems have almost zero test coverage** — the entire automated suite is 4 unit-test files; `ICloudSyncManager`'s merge logic and the JSON:API mapping layer are essentially unverified. [product-accessibility TEST-01/03]
25. **User-generated-content reporting is thin** — no per-post "Report" action exists anywhere; the only path is the general Contact form, against an app whose entire content model is forums/comments/reviews (App Review Guideline 1.2 applies directly). [App Store #6]

## What's genuinely good — protect during repair

Real fixes to previously-stubbed legacy features (Voice Boost, Trim Silence DSP), a materially better iCloud shadow-merge conflict-resolution strategy than legacy's whole-blob overwrite, functional Spotlight indexing (legacy's was dead code), real `AVAudioSession` interruption handling legacy never had, live download-progress UI, a more robust AirPlay route picker not reliant on a private-API workaround, and native additions like Sounds & Haptics settings and 7 real Siri shortcuts (vs. legacy's "coming soon" stubs). None of this should be undone in the name of "matching legacy."

## Unified implementation plan

Merges migration-parity's 5-tier repair backlog (`14_RANKED_REPAIR_BACKLOG.md`) with product-accessibility's 11-phase roadmap (`19_IMPLEMENTATION_ROADMAP.md`) and the App Store blockers into one sequence. Per both source documents' explicit rule: **do not mix architectural cleanup with large UX changes in the same commit** — each phase lands as its own focused set of changes, with regression tests where the audits called them out.

### Phase 0 — Emergency fixes (ship independently, immediately)
Small, isolated, severe enough to not wait for their natural phase:
- Podcast submission audio-file data loss (`SubmitPodcastView` security-scoped resource access + surfaced read failure)
- Podcast audio-session `.ambient` downgrade bug (`SoundPlayer` confirmation sound)
- Submit App wizard accessibility-assessment validation gate (`SubmitAppView.isValid`)
- Delete Account second-confirmation dialog
- `TipStore.show(_:)` guard on `helpfulTipsEnabled`

### Phase A — Release configuration (App Store blockers; decisions + config, not engineering)
- Build/add the `Assets.xcassets`/`AppIcon` catalog from legacy source art
- Resolve bundle ID / version / build number / deployment target as one decision ("update existing app" vs. "new app")
- Add Associated Domains entitlement + verify AASA hosting
- Verify `aps-environment` is `production` on the actual signed archive
- Resolve the open-source license disclosure screen (confirm zero third-party deps, or restore the real list)
- Decide on a UGC "Report" action or prepare App Review notes explaining the existing moderation model

### Phase B — Unified card/action system (highest-reach engineering fix; do first among the big phases)
- Hide `ContentActionsModifier`'s context-menu buttons from VoiceOver (fix pattern exists on `PodcastEpisodeRow`)
- Reorder VoiceOver actions to canonical order (routine first, dangerous/admin last), across `ContentActionsModifier` and `ContentDetailActions`
- Fix concrete owner+admin duplicate Edit/Delete Topic actions
- Wording-consistency sweep (Review vs. Comment terminology, swipe/menu/VO-action name agreement)
- Resolve dead `isUnread`/`ForumReply.isNew` fields
- Build the semantic action-dedup/ordering regression test suite this phase's own fixes depend on

### Phase C — Submission-wizard reliability
- Route all 5 wizards' success paths through `ThankYouView`
- Add announcement + focus movement to every failure branch (shared helper, composes with Phase 0's podcast fix)
- Add a review step to `SubmitAppView`
- Add a platform picker (iOS/macOS/tvOS) and duplicate-in-directory check to the App wizard
- Add the star-rating picker to app reviews
- Restore minimum-length validation on Blog/Podcast/Bug content fields
- Extend Contact's required-field labeling and live character-count feedback to the other 4 wizards

### Phase D — Data continuity & auth
- Decide on and implement an Expo→native migration routine (or explicitly accept the reset as a one-time cost)
- Bridge or reconcile Keychain identifiers so upgrading users aren't forced to re-authenticate

### Phase E — Forums
- Fix `forumsLastVisit` re-stamping (restores 2 of 6 required filters)
- Fix client-filtered-empty-page pagination dead-ending
- Switch long-thread rendering to `LazyVStack`, cap auto-pagination
- Fix stale reply count, missing post-action VoiceOver focus restoration
- Surface owner/admin moderation actions on the detail screen
- Implement list-position-by-content-ID restoration per spec

### Phase F — Podcasts
- Segment the transcript (reuse `SegmentedHTMLView`)
- Background `URLSession` for downloads; wire the existing but never-called `cancelDownload`
- Fix speed control's `accessibilityValue`; add "Now playing" to browse-row label
- Consolidate duration formatting; standardize progress-announcement wording
- Add Queue access from the full player and episode detail screen
- Fix episode detail's never-set `isTitleFocused`; add missing Queue/Play Next/Mark as Played/Jump-to-New-Comment

### Phase G — Search / Discover / For You
- Fix the debounce-timing bug causing the false "No Results" announcement
- Theme the shared `LoadingView`/`ErrorView`/`EmptyStateView` (benefits every screen)
- Fix Saved/Following staleness across tab switches
- Add empty-state CTAs; distinguish "nothing saved" from "nothing saved of this filtered kind"
- Resolve the 3-tab-vs-5-tab spec/implementation discrepancy as an explicit product decision

### Phase H — Apps / Guides / Blogs / Bug Tracker
- Add App Directory search and Saved filters (named spec violations)
- Add `.table` segment kind to `HTMLSegmenter` for guide comparison tables
- Add missing empty-state branches (Blogs/Bugs)
- Combine Bug Tracker metadata rows into single accessibility elements
- Add "N new" count to `CommunityDiscussionHeading`; post-comment VoiceOver focus confirmation across all compose flows
- Reuse `AuthorProfileButton` for author names outside Forums

### Phase I — Settings / Onboarding / Help
- Extract one shared VoiceOver-focus-retry helper, migrate all 7+ independently-tuned instances onto it
- Tie notification toggles to actual system push-permission status
- Add Reset to Defaults per settings screen
- Fix VoiceOver focus-to-error in `EditProfileView`/`DeleteAccountView` (pattern exists in `SignInView`)
- Fix the fabricated "Member since" date; add missing heading trait
- Add AutoFill content-type hints to onboarding's sign-in step

### Phase J — Push notifications (cross-team)
- Resolve the APNs/Expo token mismatch with backend
- Confirm payload schema alignment with Drupal's send logic
- Re-add `remote-notification` background mode if silent pushes are used

### Phase K — Low-vision certification
- Add semantic color tokens (warning/error/success/unread) to `ThemeColors`
- Reconcile actual theme count before any contrast certification claim
- Sweep fixed-point fonts onto scalable semantic text styles
- Add color/icon distinction for bug severity (paired with, not replacing, the existing text label)
- Full settings-combination manual pass (High Contrast, AX5+VoiceOver, Bold Text, Increase Contrast, Differentiate Without Color, Button Shapes, Reduce Transparency)

### Phase L — Engineering hardening
- Sign-out clears local saved/followed/read/notification-history state (privacy fix)
- Instruments-profile main-thread decode/regex work; fix if confirmed
- Fix the toast-dismissal race
- Converge the three pagination idioms onto server-provided `hasMore`
- Add `AppLog` diagnostic coverage to submission-form token-scraping and the networking layer generally
- Change 5 error-logging sites from `.public` to `.private`
- Begin closing test-coverage gap: `Mappers` (extend existing pattern) and `ICloudSyncManager`'s merge logic first

### Phase M — Manual certification
Per `18_ACCESSIBILITY_CERTIFICATION_GAPS.md` and `12_MANUAL_REAL_DEVICE_TEST_LIST.md` (74 device tests). Nothing in this phase is verifiable from source alone:
- Populate a living manual test script covering every MANUAL VERIFY item across all three audits
- Independent Braille-display pass
- Dedicated Switch Control pass (essentially unaudited by static review)
- Dedicated Voice Control pass (visible-label-to-spoken-action-name agreement)
- Hardware-keyboard/iPad pass (split-view, pointer support, Stage Manager)
- Full device/OS matrix (small/large iPhone, iPad, minimum-supported iOS, current iOS)
- Decide whether to establish this as a recurring process (several findings show evidence of previously-fixed-then-regressed behavior — exactly what a recurring process prevents)

### Phase N — Post-migration cleanup & release certification (per master package step 8)
Run only after behavior from Phases 0–M is stable, per the master package's own sequencing rule. Covers repository/Xcode hygiene, dead-code verification (prove unreachability before deleting), architecture boundaries, and the final release-archive certification.

## Sequencing rationale

Phase 0 exists because those five findings are severe and small enough not to justify waiting. Phase A (release config) can run in parallel with Phase 0 since it's mostly decisions/configuration, not code that risks accessibility regressions. Phase B (card system) goes first among the large engineering phases because it has the highest reach — one fix ripples across every screen. Phases E–F (Forums/Podcasts) are promoted ahead of Phases G–H because they contain concrete correctness bugs, not just polish. Phase D (data continuity/auth) is a product decision as much as engineering and should be resolved early since it affects how urgently everything else needs to ship. Phases K (low-vision) and L (engineering) are sequenced after the UX-facing phases per the explicit rule against mixing architectural and UX changes in the same window, but could run in parallel with resourcing. Phase M (manual certification) is last because it depends on Phases 0–L's fixes existing to verify against. Phase N closes the loop per the master package's own mandated order.

## Recommendation

Given the size of this backlog (25 top-line items, 14 phases), suggest starting with **Phase 0** (5 small, isolated, high-severity fixes) as a single reviewable batch, then checking in before moving to Phase A/B. This keeps early work low-risk while addressing the two most urgent real-world bugs (data loss, broken background audio) immediately.
