# Recommended Implementation Phases

Adapted from the audit package's own `08_PRIORITIZED_ROADMAP.md` template,
populated with this audit's actual findings and reordered where evidence
justified a different priority than the template's default assumption. Per
the package's explicit rule: **do not mix architectural cleanup with large UX
changes in the same commit when avoidable** — it makes accessibility
regression tracing much harder. Each phase below should land as its own
focused set of changes.

All six research passes (Forums, Podcasts, Apps/Guides/Blogs/Bugs, Discover/
Search/For You/Profile/Onboarding, Settings/Guided Experience/Submission,
Engineering) are now incorporated. Phase 7 below is fully populated.

---

## Phase 0 — Four release-blocking/emergency fixes, ship independently and immediately

These should not wait for a broader phase; each is small and isolated enough
to fix in near-isolation, and severe enough to justify an out-of-cycle fix.

- **SUBMIT-04** — Fix the silent podcast-audio-file data loss on submissions
  picked from iCloud Drive/Files: add the missing
  `startAccessingSecurityScopedResource()` call in `SubmitPodcastView`, and
  make `DrupalFormClient` surface a file-read failure explicitly instead of
  swallowing it via `try?`. **Treat this as the highest-priority item in the
  entire audit** — it is silent, real, user-facing data loss on an actively-
  advertised feature.
- **PODCAST-01** — Stop `SoundPlayer`'s confirmation-sound playback from
  reconfiguring the shared `AVAudioSession` category away from `.playback`
  while an episode is loaded. One-file, narrowly-scoped fix; breaks
  background/Lock Screen audio otherwise.
- **PROFILE-07** — Add a `.confirmationDialog` second-confirmation step to
  Delete Account, matching every other destructive action in the app. Small,
  isolated, and the highest-consequence action in the app currently has the
  weakest protection against accidental activation.
- **SETTINGS-02** — Guard `TipStore.show(_:)` on `preferences.helpfulTipsEnabled`.
  A one-line fix for a toggle that currently has zero effect, directly
  contradicting the app's own written accessibility convention.

## Phase 1 — Unified cards and VoiceOver actions

Do first among the larger phases because it affects the most screens
simultaneously.

- **CARD-01** — Hide `ContentActionsModifier`'s own context-menu Buttons from
  VoiceOver (the fix pattern already exists correctly on `PodcastEpisodeRow`'s
  `extraMenuItems` — apply the same pattern to the modifier's primary menu).
- **CARD-03 / PODCAST-09 / FORUM-16 / FORUM-17** — Reorder VoiceOver actions
  to the proposed canonical order (routine actions first, dangerous/admin
  actions last), applied consistently to both `ContentActionsModifier` and
  `ContentDetailActions`.
- **FORUM-03** — Fix the concrete owner+admin duplicate Edit/Delete Topic
  actions (gate the owner-only block on `!isAdmin`).
- **CARD-04, PODCAST-08, APPS-05, FORYOU-03** — Wording-consistency sweep:
  standardize each semantic operation's name across swipe label, context-menu
  label, and VoiceOver action name, with particular attention to APPS-05
  (Review vs. Comment terminology visible to sighted AND VoiceOver users
  simultaneously) and FORYOU-03 (a confirmed Voice Control failure mode).
- **CARD-05, FORUM-08, FORUM-20** — Resolve the dead `isUnread`/`ForumReply.isNew`
  fields (wire to real state or remove, app-wide).
- Regression test: build the semantic action-de-duplication/ordering test the
  package's own `02_UNIFIED_CONTENT_CARD_STANDARD.md` recommends, covering
  every `ContentKind` × permission permutation (signed out / signed in /
  owner / admin / owner+admin) — this single test suite protects nearly all
  of Phase 1's fixes from silent regression.

## Phase 2 — Home refinement

- **HOME-02, HOME-03** — Consolidate the parallel "newness" computation
  (`isNew` vs. `newCount`) into one source of truth; route `HomeViewModel`
  through `PreferencesStore` instead of raw `UserDefaults` keys.
- **HOME-05** — De-duplicate the offline/degraded-source banner logic so the
  same root cause can't trigger two different banners at once.
- **HOME-09** — Fix "New" filter pagination so it doesn't silently cap at
  whatever's already been paged in via "All."
- **CARD-12 / HOME-01** — Replace the two independent hardcoded-delay focus-
  retry loops with a shared, reactive (not guessed-delay) mechanism where
  feasible.

## Phase 3 — Forums

- **FORUM-01** — Fix `forumsLastVisit` re-stamping so New/Since Last Visit
  filters aren't always empty (the highest-impact Forums fix — restores 2 of
  6 required filters).
- **FORUM-02** — Fix client-filtered-empty-page pagination so Unread/New/
  Since Last Visit don't silently dead-end (restores reliability of the
  remaining filters).
- **FORUM-05** — Switch long-thread rendering to `LazyVStack`, cap
  auto-pagination behind a threshold.
- **FORUM-06** — Fix stale reply count after post/delete.
- **FORUM-11, FORUM-12, FORUM-18** — Add missing post-action VoiceOver focus
  restoration (delete reply, delete topic, empty filter result).
- **FORUM-04** — Surface owner/admin moderation actions on the detail screen,
  not just the browse row.
- **FORUM-14** — Implement list-position-by-content-ID restoration per the
  explicit spec requirement.

## Phase 4 — Podcasts

- **PODCAST-04** — Segment the transcript (reuse `SegmentedHTMLView`'s
  existing pattern) — the highest-value Podcasts fix after Phase 0's audio
  session bug.
- **PODCAST-02, PODCAST-03** — Background `URLSession` for downloads; wire
  the already-existing but never-called `DownloadManager.cancelDownload`.
- **PODCAST-06, PODCAST-07** — Fix speed control's `accessibilityValue`;
  add "Now playing" to the browse-row VoiceOver label.
- **PODCAST-10, PODCAST-11** — Consolidate duration formatting to one shared
  formatter; standardize progress-announcement wording.
- **PODCAST-12** — Add a drag gesture with a visible thumb to the scrubber
  (VoiceOver's adjustable action is already correct — this is the low-vision
  gap alongside it).
- **PODCAST-13, PODCAST-14** — Add Queue access from the full player and
  episode detail screen.

## Phase 5 — Search / Discover / For You

- **SEARCH-01 / SEARCH-08** — Fix the debounce-timing bug causing the false
  "No Results" announcement and stale-results-with-no-loading-cue — single
  root cause, single fix.
- **SEARCH-09** — Theme the shared `LoadingView`/`ErrorView`/`EmptyStateView`
  (cross-cutting — benefits every screen using these components, not just
  Search).
- **FORYOU-05** — Fix Saved/Following staleness across tab switches (ideally
  by making `PersistenceStore`'s collections reactively observable, per the
  Engineering audit's architecture notes, rather than patching the `.task`
  trigger alone).
- **FORYOU-07, FORYOU-08** — Add empty-state CTAs; distinguish "nothing
  saved at all" from "nothing saved of this filtered kind."
- **DISCOVER-04** — Hide the decorative chevron on Contribute rows.
- **DISCOVER-03** — Resolve the 3-tab-vs-5-tab spec/implementation
  discrepancy as an explicit product decision (documentation reconciliation,
  not an engineering task, but blocking for anyone using the written spec as
  ground truth).

## Phase 6 — Apps / Guides / Blogs / Bug Tracker

- **APPS-01, APPS-02, GUIDES-04** — Add App Directory search (named spec
  violation) and Saved filters to Apps/Guides (named spec violations).
- **GUIDES-02** — Add a `.table` segment kind to `HTMLSegmenter` so
  comparison tables in guides don't flatten to unreadable prose.
- **BLOGS-01, BUGS-01** — Add the missing empty-state branch (copy the
  existing pattern from Apps/Guides).
- **BUGS-02** — Combine Bug Tracker metadata rows into single accessibility
  elements (one-modifier fix with an existing correct example in the same
  codebase).
- **ALL-01, ALL-04** — Add the documented "N new" count to
  `CommunityDiscussionHeading`; add post-comment VoiceOver focus confirmation
  across all four compose flows (reuse Forums' already-correct pattern).
- **GUIDES-06 / BLOGS-06 / APPS-13 / BUGS-10** — Reuse `AuthorProfileButton`
  for author names outside of Forums.
- **GUIDES-08, GUIDES-09** — Manual-verify in-body link and inline-code/
  keyboard-shortcut pronunciation after HTML conversion; fix if confirmed
  broken.

## Phase 7 — Settings / Onboarding / Help / Submission

Submission-flow reliability and feedback come first within this phase — they
carry this audit's highest-severity remaining findings outside Phase 0.

- **SUBMIT-02** — Route all 5 submission wizards' success paths through
  `ThankYouView` (currently only Contact does) — the shared component exists
  specifically to fix this exact problem.
- **SUBMIT-03** — Add `UIAccessibility.post(.announcement, ...)` plus
  `@AccessibilityFocusState` movement to every failure branch across all 5
  wizards; build one shared helper rather than patching 5 independently, and
  verify it composes correctly with SUBMIT-04's fix (a surfaced file-read
  failure should flow through this same announced-error path).
- **SUBMIT-01** — Add a review step to `SubmitAppView`, matching the other 4
  wizards.
- **SUBMIT-08, SUBMIT-09** — Extend Contact's required-field labeling and
  live character-count/threshold feedback to the other 4 wizards.
- **SUBMIT-12** — Add an early, non-blocking offline warning at each
  wizard's entry point (reuse `OfflineBanner`).
- **SUBMIT-14, SUBMIT-11** — Bring `SubmitAppView`'s intro step into the
  standard `WizardStepIndicator` heading/focus pattern; standardize the one
  inconsistent picker style on `SubmitBugView`.
- **GUIDED-01** — Extract one shared VoiceOver-focus-retry helper and migrate
  all 7+ known independently-tuned instances onto it (Home's 2, Guided
  Experience's 1+, the submission wizards' several) — fold this in alongside
  Phase 2's `CARD-12`/`HOME-01` fix as one consolidated effort, since they're
  the same underlying pattern.
- **GUIDED-04, GUIDED-05** — Expand `RelatedLinkDestination` to cover the
  settings screens most-referenced in help text; fix the one stale "Siri &
  Intelligence" reference.
- **SETTINGS-01, SETTINGS-12** — Reconcile the Settings IA against the
  written master spec (documentation task); differentiate the two
  similarly-worded "Clear All..." destructive buttons (Privacy vs. Storage)
  by scope.
- **SETTINGS-03** — Tie notification toggles to actual system push-permission
  status with an inline explanation.
- **SETTINGS-04, SETTINGS-05** — Add a Reset to Defaults action per settings
  screen; audit manual `.isSelected`-Button selection controls against native
  Picker semantics where feasible.
- **PROFILE-01, PROFILE-02** — Add VoiceOver focus-to-error in
  `EditProfileView`/`DeleteAccountView` (the correct pattern already exists
  in `SignInView` — copy it).
- **PROFILE-03, PROFILE-04, PROFILE-05** — Fix the fabricated "Member since"
  date, add the missing heading trait, and reconcile the
  `AuthorProfileModal`/`AuthorProfileSheet` documentation-vs-code naming
  drift that plausibly let the first two ship unnoticed.
- **ONBOARD-05** — Add AutoFill content-type hints to onboarding's sign-in
  step; consider extracting a shared credentials-form component so
  `SignInView` and `SignInStep` can't drift independently again.
- **ONBOARD-06** — Confirm/clarify whether users can intentionally replay the
  full onboarding flow, not just the lighter Welcome Tour.
- Lower priority, batch opportunistically: **SETTINGS-06, SETTINGS-07,
  GUIDED-03, GUIDED-08, SUBMIT-11**.

## Phase 8 — Low Vision certification

- **CARD-07** — Add semantic tokens (warning/error/success/unread) to
  `ThemeColors`, sweep hardcoded `Color.red`/`Color.orange`/state-styled
  `Color.accentColor` usages onto them.
- **CARD-08** — Reconcile the actual theme count (13 found in `ThemeColors.swift`
  vs. "15" assumed by the audit package) before any contrast certification
  claim is made.
- **CARD-11 and per-screen instances** (Home greeting/headers, `CommunityDiscussionHeading`,
  `ContentDetailActions`' icon) — sweep fixed-point `.font(.system(size:))`
  usages onto scalable semantic text styles.
- **BUGS-06** — Add a color/icon distinction for bug severity levels, paired
  with (not replacing) the existing correct text label.
- Full settings-combination manual pass per `18_ACCESSIBILITY_CERTIFICATION_GAPS.md`
  section 6 (High Contrast Light/Dark separately, AX5 + VoiceOver together,
  Bold Text, Increase Contrast, Differentiate Without Color, Button Shapes,
  Reduce Transparency) — none of this is verifiable from source alone.

## Phase 9 — Engineering hardening

- **ARCH-02** — Resolve the push-notification APNs/Expo token mismatch with
  the backend team (cross-team, not client-only).
- **ARCH-04 / PERS-05** — Clear local saved/followed/read/notification-history
  state on sign-out (privacy fix, shared-device scenario).
- **CONC-01** — Instruments-profile whether decode/regex work genuinely
  executes on the main thread under the project's `MainActor` default
  isolation; fix if confirmed.
- **CONC-02** — Fix the toast-dismissal race (concrete, reproducible,
  low-risk fix).
- **ARCH-10 / TEST-05** — Converge the three pagination idioms onto
  server-provided `hasMore` where available; add coverage.
- **NET-09** — Add `AppLog` diagnostic coverage to the submission-form
  token-scraping failure paths (currently zero diagnostic trail on the most
  fragile integration point in the app).
- **DIAG-02** — Add an `AppLog.network` category with circuit-breaker/cache-
  fallback logging — the one major subsystem currently missing the app's
  otherwise-disciplined logging practice.
- **SEC-07** — Change 5 error-logging sites from `.public` to `.private`
  (zero-cost defense-in-depth fix).
- **TEST-01, TEST-03** — Begin closing the test-coverage gap, starting with
  `Mappers` (extend the existing well-targeted `forumFromRecent` test to the
  remaining ~8 functions) and `ICloudSyncManager`'s merge logic — the two
  highest-complexity, highest-real-world-bug-history systems in the app.

## Phase 10 — Manual certification

Per `18_ACCESSIBILITY_CERTIFICATION_GAPS.md` in full detail. Summary of what
this phase must produce before any accessibility-certification claim is
made:

- Adopt and populate a living manual test script (the audit package's
  `10_MANUAL_ACCESSIBILITY_TEST_SCRIPT.md` template is a ready starting
  point) covering every MANUAL VERIFY item raised across this entire audit.
- A genuine, independent Braille-display pass — no finding in this audit
  should be treated as Braille-certified from source review alone.
- A dedicated Switch Control pass across every root screen (essentially
  unaudited by this static-review-only pass).
- A dedicated Voice Control pass specifically checking visible-label-to-
  spoken-action-name agreement, informed by FORYOU-03's confirmed failure
  mode and Phase 1's wording-consistency work.
- A hardware-keyboard/iPad pass covering split-view layout, pointer support,
  and Stage Manager — none confirmed in this audit.
- The full device/OS matrix (small iPhone, large iPhone, iPad, minimum-
  supported iOS, current iOS) — zero device testing was performed in this
  audit; everything here was static source review.
- A decision on establishing this as a **recurring** process (automated
  where feasible per Phase 9's test-coverage work, manual script otherwise)
  rather than a one-time pass — several of this audit's own findings show
  evidence of previously-fixed-then-partially-regressed behavior
  (`ContentActions.swift`'s own code comments document this history for the
  Save/Share duplication issue specifically), which is exactly what a
  recurring process exists to prevent.

---

## Sequencing rationale

Phase 0 exists because four findings are severe and small enough to not
justify waiting for their natural phase — three are narrowly-scoped bug
fixes (SUBMIT-04, PODCAST-01, SETTINGS-02), and PROFILE-07 is a small,
isolated addition of an existing pattern. SUBMIT-04 in particular should not
wait for Phase 7's broader submission-flow work; it is real data loss
happening in production today. Phases 1–7 are ordered by the package's own
"affects the most screens first" logic, with Forums and Podcasts promoted
ahead of Apps/Guides/Blogs/Bugs because this audit found concrete
correctness bugs (not just polish items) in Forums and Podcasts specifically
(FORUM-01/02, PODCAST-01/02), and Phase 7 (Settings/Onboarding/Help/
Submission) placed last among the UX-facing phases despite containing
several P1 findings, because — SUBMIT-04 and SETTINGS-02 having already been
pulled forward into Phase 0 — its remaining work (SUBMIT-02/03's shared
success/failure feedback components) benefits from Phase 1's shared-component
consolidation work already being complete as a reference pattern. Phase 8
(Low Vision) and Phase 9
(Engineering) are intentionally sequenced after the UX-facing phases per the
package's explicit rule against mixing architectural and UX changes in the
same window — both phases' fixes are largely independent of the UX-facing
phases and could in practice run in parallel with them if resourcing allows,
but should not be *combined into the same commits*. Phase 10 is last because
it depends on Phases 1–9's fixes actually being in place to verify against;
running it prematurely would mean re-running most of it later.
