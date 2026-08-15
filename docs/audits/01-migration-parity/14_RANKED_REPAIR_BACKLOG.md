# 14 — Ranked Repair Backlog (Reference Only — Not Implemented)

Per `15_REPAIR_PHASE_RULES.md`: this backlog is frozen from the completed parity ledgers and is for planning only. Nothing in this audit has been fixed. Ordering follows the mandated repair priority: (1) crashes/data loss/auth/audio, (2) inaccessible blockers, (3) core feature loss, (4) state/visual polish. Duplicate findings identified in `13_ORPHAN_DEAD_STALE_CAPABILITY_LIST.md` section G are consolidated here into single line items.

## Tier 0 — Release blockers (must resolve before any TestFlight/App Store submission)

| # | Finding | Ledger IDs | Why it blocks release |
|---|---|---|---|
| 1 | App icon asset catalog does not exist; build setting references a nonexistent `AppIcon` catalog | VIS-015, SEC-015 | Archive/validation will likely fail, or ship with a blank icon |
| 2 | Bundle identifier (`com.applevis.AppleVisSwift` vs. production `com.applevis.app`), version (1.0 vs. 2026.0.7), build (1 vs. 11), and deployment target (26.5, apparent typo, vs. 16.0) all need explicit reconciliation | SEC-015 | Wrong bundle ID means this cannot replace the existing App Store listing; version/build would be rejected as a downgrade |
| 3 | Missing `com.apple.developer.associated-domains` entitlement | LIFECYCLE-014, NATIVE-019, SEC-005 | Universal links from applevis.com cannot open the app at all in production, regardless of the (correctly written) router code behind it |
| 4 | `aps-environment` hardcoded to `development` in the single entitlements file used for both Debug and Release | SEC-012 | Risk of shipping a build where push notifications are silently non-functional for every production user |
| 5 | Open-source license disclosure screen (`OpenSourceView.swift`) lists literally one entry (Swift itself) where legacy disclosed 20+ third-party libraries | open-source.tsx (route map), REGRESSION, High, independently confirmed by full source read | This is an App-Store-facing legal disclosure; if any third-party/vendored code exists anywhere in the app, this screen is legally incomplete. Needs explicit legal/compliance sign-off, not an assumption it's correct as-is |

## Tier 1 — Data loss / auth / core-mission accessibility integrity

| # | Finding | Ledger IDs | Severity | Why it's this tier |
|---|---|---|---|
| 5 | No Expo→native data migration path exists at all — every local preference, saved/followed item, playback position, and cached download resets to native defaults on first launch, even under identical iCloud account + sync-enabled conditions | DATA-047 | Critical | Direct, confirmed data loss for every upgrading user |
| 6 | Native Submit App wizard can be submitted with ZERO accessibility-assessment content — `isValid` in `SubmitAppView.swift` checks only appName/appStoreUrl/category; osVersion/voiceOverPerformance/buttonLabelling/usabilityNotes/accessibilityComments are completely unenforced (confirmed by direct source read at submit-wizard/notes.tsx lines 80-84) | SUBMIT-005, submit-wizard/notes.tsx (route map) | **Critical** (elevated from High — independently confirmed twice, by two separate research lenses reading the same source directly) | Undermines the App Directory's entire reason for existing — **the single most consequential functional finding in the whole audit** |
| 6b | No platform picker exists for app submission; `ItunesAPI.swift` hardcodes `entity=software` on both network calls — native cannot submit a macOS or Apple TV app at all | SUBMIT-003, submit-wizard/platform.tsx (route map) | **Critical** (elevated from High — independently confirmed by direct source read) | A structural capability gap, not a UI nicety |
| 6c | No duplicate-app-in-directory check exists anywhere (full-tree grep, zero matches); `payload.supportedDevices` is fetched but never assigned, silently submitting `[]` | SUBMIT-004, submit-wizard/confirm.tsx (route map) | **Critical** (elevated from High — independently confirmed) | Users can unknowingly submit duplicate entries; editorial cleanup burden and community confusion |
| 7 | Native app-review compose flow has no star-rating picker at all; reviews authored natively can never carry an accessibility rating, breaking the read-side display logic that depends on this exact convention | APPS-008 | High | Data-model-breaking, not just a missing control |
| 8 | Push-notification pipeline likely broken end-to-end: raw APNs token registered against a field built for Expo push tokens, `remote-notification` background mode dropped, and payload schema changed without confirmed backend alignment | API-026, NATIVE-013, SEC-008, LIFECYCLE-028 | High | Users may receive zero notifications with no visible error anywhere in the app |
| 9 | Auth-session Keychain identifiers are incompatible between legacy and native with zero bridging code | DATA-033 | High | Every upgrading signed-in user is forced to sign in again |

## Tier 2 — Accessibility blockers (VoiceOver/braille users lose real capability, not polish)

| # | Finding | Ledger IDs | Severity |
|---|---|---|---|
| 10 | Episode transcript renders as a single giant unnavigable `Text()` element instead of per-cue elements | A11Y-013 | Medium |
| 11 | Forum/blog/episode/guide compose body field has no accessibility label or hint at all | A11Y-009, A11Y-036, FORUM-006 | Medium |
| 12 | Self-acknowledged, unresolved duplicate-VoiceOver-announcement bug in the shared long-press context-menu pattern, spanning Forums/Apps/Resources/Blogs/Bug rows | FORUM-007, APPS-014, RES-009 | Medium |
| 13 | Home's manual pull-to-refresh no longer announces "N new items"/"no new items," and does not VoiceOver-focus the first new item | HOME-003, A11Y-020 | High (per feature ledger) |
| 14 | Home welcome flow no longer restores VoiceOver focus to the specific feed item a returning user last engaged with — only to the greeting/What's New card | HOME-005 | High |
| 15 | VoiceOver Detail Level settings screen collapsed 9 individual live iOS-status rows into 1 static summary row | A11Y-002, SETTINGS-003 | Medium |
| 16 | Only 1 explicit VoiceOver-escape override exists in native vs. ~15 in legacy; every custom overlay (toasts, guidelines reminder, translate prompt) needs on-device escape-gesture verification | A11Y-008 | Medium |
| 17 | Magic Tap has only one global handler vs. legacy's three per-context handlers; uncertain whether it fires while the Full Player sheet is presented, given SwiftUI sheet accessibility-tree isolation | A11Y-007, PODCAST-034 | Medium |

## Tier 3 — Core feature loss (functionality gaps beyond accessibility)

| # | Finding | Ledger IDs | Severity |
|---|---|---|---|
| 18 | No general background feed-refresh task exists — only podcast auto-download runs in the background; content only updates when foregrounded and manually refreshed | API-036, DATA-043 | High |
| 19 | Entire "Site Results"/full-text search fallback category is missing — search can only match typed JSON:API categories | DISC-004, SEARCH-006, Temp Phase 05 | High |
| 20 | No macOS/tvOS app-submission path exists at all in the native wizard (iOS-only) | SUBMIT-003 | High |
| 21 | No duplicate-app-in-directory check before submission | SUBMIT-004 | High |
| 22 | Forum threads have no visual/audible "new reply since last visit" signal or jump-to-first-new-comment shortcut — native's own comment confirms `isNew` is hardcoded false and never built | FORUM-003 | High |
| 23 | Native Forums category browsing client-filters the general "recent" feed instead of querying a dedicated per-category endpoint — sparse categories show fewer topics than legacy | FORUM-001 | High |
| 24 | Universal links open an in-app web view instead of routing to native content, even once the Tier-0 entitlement fix lands | LIFECYCLE-010 through -013 | High |
| 25 | Card Density setting has zero visible effect anywhere in For You (Queue/Downloads/Saved/Following), while correctly affecting Home/Discover | FY-003, VIS-002 | Medium |
| 26 | Nested `NavigationStack` in Queue (embedded inside For You's own stack) — a known SwiftUI anti-pattern risking double nav-bars/toolbar conflicts | FY-012 | Medium (architectural risk) |
| 27 | Blog/Podcast submission wizards allow near-empty content where legacy enforced a minimum character count | SUBMIT-012, SUBMIT-017 | Medium |
| 28 | App/Blog/Bug/Podcast wizards (all but Contact) show only a transient toast on success instead of a dedicated confirmation screen | SUBMIT-010 | Medium |
| 29 | Episode duration always renders as "0 minutes" for never-played episodes — a literal `duration: 0` in the mapper with no fallback cache | PODCAST-035 | Low–Medium |
| 30 | Episode chapter data depends entirely on Drupal's `field_chapters` with no client-side ID3 CHAP fallback for episodes missing server-side chapter metadata | PODCAST-032 | Medium |
| 31 | No private "contact this member" messaging from author profile cards | FORUM-010 | Medium |
| 32 | Detail screens (Forum Topic, App, Resource) have no owner/admin edit-unpublish-delete menu — only reachable via the browse-list row's context menu | FORUM-008, APPS-010, RES-004 | Medium |
| 33 | Skip-back default mismatch: native defaults to 10s, legacy to 15s | DATA-014, PODCAST-009 | Medium |
| 34 | "New" filter semantics changed: native never time-expires items via a lastVisit boundary, so "New" can accumulate indefinitely (a deliberate but user-visible redesign) | HOME-004 | Medium |
| 35 | Notification-preference defaults flipped from all-off (legacy) to 3-of-8 on-by-default (native), undocumented | DATA-010 | Medium |
| 36 | iCloud-synced settings surface is far narrower on native (6 keys) than legacy (14+) — helpful tips, welcome summary, Home startup mode, sleep timer, Voice Boost, EQ, auto-download/delete, trim silence, and resume-rewind no longer sync across devices | DATA-005/008/009/017-023 | Medium |
| 37 | Read/unread state and "new since last visit" timestamps never sync via iCloud on native | DATA-030, DATA-034, DATA-040 | Medium |
| 38 | "Clear Local Data" under-delivers relative to its own confirmation-dialog promise on native (does not clear queue/preferences as promised) | DATA-045 | Medium |

## Tier 4 — State, visual, and copy polish

| # | Finding | Ledger IDs | Severity |
|---|---|---|---|
| 39 | Auto-Focus Search Field setting is completely dead (persisted, has a UI row, zero consuming code) | A11Y-003, DISC-003, SEARCH-004 | Medium (dead-setting user trust issue) |
| 40 | Stale Help Center/What's New copy still describes Dynamic Island playback controls as shipped | NATIVE-018 | Medium (trust/copy defect, not a functional regression) |
| 41 | Save/Follow toast wording lost kind-specific nouns ("Episode saved." → generic "Saved") | FY-008, FY-009 | Low |
| 42 | App Detail lost "Available On"/supported-devices card, Languages card, title/version-mismatch notices, and the "no longer on App Store" distinct state | APPS-004/005/006/007 | Medium |
| 43 | Resource detail lost the extracted "N Referenced Links" section (links now only reachable inline) | RES-003 | Medium |
| 44 | Profile lost editable Display Name field | PROFILE-003 | Medium |
| 45 | Account-deletion screen lost the explicit "your local data is not affected" disclosure (behavior is fine, copy is missing) | PROFILE-005 | Low |
| 46 | Delete-account flow gives no explicit success confirmation, just a silent sign-out | PROFILE-006 | Medium |
| 47 | Compact card density only varies row padding (2 vs. 6pt) instead of legacy's broader per-element scaling | VIS-002 | Low |
| 48 | Cache-retention change has no immediate effect and purges everything rather than per-entry when it does fire | SETTINGS-015 | Medium |
| 49 | Several legacy device-local caches (play history, per-show speed memory, episode chapters cache) have no located native counterpart | DATA-036/037/039 | Low–Medium |
| 50 | App Store review-prompt system (90-day cooldown, 3-action threshold) has no native counterpart | DATA-044 | Low |

## Additional items surfaced specifically by the route/screen map (02)

| # | Finding | Ledger IDs | Severity |
|---|---|---|---|
| 51 | Unified compose screen split into 7 native structs; only 2 (Topic/Reply) wire Guidelines/Translation/Writing-Tools helpers that legacy applied uniformly across all 5 compose contexts (App review, Blog/Bug/Resource/Podcast comments) | compose.tsx (route map) | Medium |
| 52 | `episode/[id].tsx` → `EpisodeDetailView.swift`: `isTitleFocused` declared and bound but never set `true` anywhere; also missing Queue toggle, Play Next, Queue link, Mark as Played (function doesn't exist anywhere natively), Jump-to-First-New-Comment, direct AirPlay button | episode/[id].tsx (route map), corroborates PODCAST-002 | Medium |
| 53 | `settings-account.tsx`'s app-wide "sign in required" deep-link target has no confirmed native equivalent outside `ProfileView` — whether other content screens present a sign-in gate on an auth-required action is unresolved | settings-account.tsx (route map) | High |
| 54 | `submit-bug/index.tsx` → `SubmitBugView.swift`: the Next button is hardcoded to never disable; Software Version can stay empty through submission — validation is completely gone, not just weakened | submit-bug/index.tsx (route map) | High |
| 55 | Onboarding notifications step always requests system notification permission regardless of the user's per-category toggle state — a behavioral regression, not just a reduced category count | onboarding/notifications.tsx (route map), corroborates ONBOARD-007 | Medium |
| 56 | Onboarding theme step drops the Dynamic-Type-triggered high-contrast recommendation section — a purpose-built accessibility affordance, not cosmetic content | onboarding/theme.tsx (route map) | Medium |
| 57 | Podcast hub's "In Progress" and "History" filters have no native equivalent anywhere — confirm intentional vs. oversight | podcast-browse.tsx (route map) | Medium |
| 58 | Global always-reachable Search screen consolidated into Discover's `.searchable()` with no standalone entry point anywhere (including no keyboard-shortcut equivalent) — a product decision is needed on whether this is acceptable, not an assumed non-issue | search.tsx (route map), corroborates SEARCH-003 | Medium |

## Explicitly out of scope for this backlog (INTENTIONALLY DEFERRED)

Apple Watch app, Watch complications, Widgets, Dynamic Island presentation, Live Activities — confirmed clean deferrals with no orphaned code, entitlements, or build artifacts (see `13_ORPHAN_DEAD_STALE_CAPABILITY_LIST.md` section F), except for the stale copy already listed as item 40 above.

## Notable native-only improvements (preserve, do not regress while repairing the above)

Real fixes to previously-stubbed legacy features (Voice Boost, Trim Silence DSP), superior iCloud shadow-merge conflict resolution for saved/followed/settings, functional Spotlight indexing (legacy's was dead code), working AVAudioSession interruption handling, real live download-progress UI, and a more robust AirPlay route-picker implementation. These should be explicitly protected during Tier 1–4 repair work, per the "preserve intentional native improvements" rule.
