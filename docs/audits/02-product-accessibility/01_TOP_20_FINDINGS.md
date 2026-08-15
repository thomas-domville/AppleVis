# Top 20 Highest-Impact Findings

Ranked by real-world impact on the app's core mission — a calm, trustworthy,
highly accessible experience for a blind/low-vision community — not
mechanically by severity label alone. Full detail, evidence, and exact
file/line citations for each item live in the referenced document; this file
is the executive entry point. Status vocabulary and priority scale as defined
in `00_INDEX.md`.

---

## 1. Duplicate VoiceOver custom actions on nearly every content card, app-wide

**ID:** CARD-01 · **Priority:** P0 · **Category:** ACCESSIBILITY DEFECT
**Full detail:** `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md`

`ContentActionsModifier`'s own `.contextMenu` block (used by every Forum/
Podcast/App/Guide/Blog row and detail screen) has no `.accessibilityHidden(true)`
on its Button children, even though nearly every one of those same operations
(Save, Follow, Add Comment, Open in Browser, Share, Edit, Unpublish, Delete,
Mark as Read) is *also* declared as an explicit `.accessibilityAction`. The
fix pattern already exists correctly one call site away, on
`PodcastEpisodeRow`'s `extraMenuItems` — it was simply never applied to the
modifier's own, much larger internal menu. This is the single highest-reach
fix in the app: one change ripples across every screen simultaneously.

## 2. Podcast playback silently loses background/Lock Screen eligibility on the first pause

**ID:** PODCAST-01 · **Priority:** P0 · **Category:** BUG / ARCHITECTURE ISSUE
**Full detail:** `05_SCREEN_PODCASTS.md`

`SoundPlayer`'s confirmation-sound playback unconditionally resets the shared
`AVAudioSession` category to `.ambient` whenever it isn't already `.ambient`
— which it never is while a podcast is loaded (`.playback`/`.spokenAudio`).
Because every play/pause, including ones triggered from the Lock Screen,
fires a confirmation sound, the very first pause after starting an episode
silently downgrades the session away from background-eligible, mute-switch-
immune playback. This defeats two of the app's most safety-critical features
for a user who locks their phone or pockets it while listening.

## 3. Podcast audio files silently omitted from submissions picked via iCloud Drive/Files — real data loss

**ID:** SUBMIT-04 · **Priority:** P1 · **Category:** BUG (real data loss)
**Full detail:** `15_SCREEN_SUBMISSION_FLOWS.md`

`SubmitPodcastView` never calls `startAccessingSecurityScopedResource()` for
files picked from iCloud Drive/Files, unlike the correctly-implemented
`SubmitBlogView` path; `DrupalFormClient` then reads the file via
`try? Data(contentsOf:)`, which silently swallows the resulting permission
failure. The audio part is simply **omitted** from the submission, with no
error anywhere in the chain — the submission "succeeds" server-side with no
audio file. This hits exactly the workflow the app's own What's New
changelog advertises. Very likely the single worst correctness bug found in
this audit.

## 4. Delete Account has the weakest confirmation of any destructive action in the app

**ID:** PROFILE-07 · **Priority:** P2 (elevated for impact) · **Category:** UX INCONSISTENCY / IMPROVEMENT
**Full detail:** `12_SCREEN_PROFILE_ONBOARDING.md`

Every other destructive action found in this audit (Sign Out, Remove
Downloads, Unsave All, Clear Queue) uses a `.confirmationDialog` as a
required second step. Delete Account's only gate is a single `Toggle` — one
accidental activation (a slipped VoiceOver double-tap, a mistimed Switch
Control scan) irreversibly deletes the account with no second chance to
catch the mistake.

## 5. Submission wizards give no reliable VoiceOver confirmation of success or failure

**IDs:** SUBMIT-02, SUBMIT-03 · **Priority:** P1 · **Category:** ACCESSIBILITY DEFECT
**Full detail:** `15_SCREEN_SUBMISSION_FLOWS.md`

`ThankYouView` exists specifically because wizards used to "toast and
dismiss immediately, giving VoiceOver users no confirmation focus point" —
yet 4 of 5 submission wizards (App/Blog/Bug/Podcast) still do exactly that;
only Contact routes through the fix. Separately, every failure branch across
**all 5** wizards sets a plain red `Text` with no announcement and no focus
movement — the worst-case screen-reader outcome, on forms representing real
user effort. Combined with SUBMIT-04, a user has essentially no way to
discover a podcast submission silently lost its audio file.

## 6. The "AppleVis Tips" toggle has zero effect

**ID:** SETTINGS-02 · **Priority:** P1 · **Category:** BUG (violates documented intent)
**Full detail:** `13_SCREEN_SETTINGS.md`

`TipStore.show(_:)` never reads `preferences.helpfulTipsEnabled`, directly
contradicting `docs/IMPLEMENTATION_NOTES.md`'s explicit requirement.
Disabling the toggle has no observable effect — tips still show on every
trigger. A demonstrably broken toggle, once noticed, undermines trust in
every other setting on the same screen.

## 7. Push notifications likely deliver nothing at all

**ID:** ARCH-02 · **Priority:** P1 · **Category:** ARCHITECTURE ISSUE
**Full detail:** `16_ENGINEERING_ARCHITECTURE_CONCURRENCY_NETWORKING.md`

Native registers a raw APNs device token where the backend integration
expects an Expo push token; per the code's own doc comment, tokens
registered this way "won't receive anything" until Drupal's send logic calls
APNs directly. Three independent audit passes converged on the same finding
— strong signal this is real, current, and unresolved.

## 8. Signing out never clears local saved/followed/read state — a shared-device privacy leak

**ID:** ARCH-04 / PERS-05 · **Priority:** P1–P2 · **Category:** BUG / ACCESSIBILITY DEFECT (privacy)
**Full detail:** `17_ENGINEERING_PERSISTENCE_PERFORMANCE_SECURITY_TESTING.md`

`AuthStore.signOut()`/`handleSessionExpired()` deliberately clear Keychain,
applevis.com cookies, and the Spotlight index (each a documented fix for a
real prior bug) — but never call `PersistenceStore.clearAllLocalData()`. On
a shared household device, the next person to sign in inherits the previous
user's saved items, followed topics, and read history.

## 9. Two of the six required Forums filters are effectively non-functional

**ID:** FORUM-01, FORUM-02 · **Priority:** P1 · **Category:** BUG
**Full detail:** `04_SCREEN_FORUMS.md`

`forumsLastVisit` is re-stamped to "now" on every load, so New/Since Last
Visit almost always compare against a timestamp of "this exact moment,"
making them close to always empty. Separately, client-side-filtered empty
pages don't continue auto-paginating even when more pages exist, so Unread/
New/Since Last Visit can silently dead-end. Together these break half of the
six filters the master spec explicitly requires.

## 10. No search in the App Directory at all — a named, explicit spec violation

**ID:** APPS-01 · **Priority:** P1 · **Category:** BUG
**Full detail:** `06_SCREEN_APPS.md`

`APPLEVIS_2026_1_MASTER_SPEC.md` explicitly lists "Search and filters" as
required for Apps. No `.searchable` modifier exists anywhere in
`AppBrowseView`.

## 11. Long forum threads are fully fetched and eagerly rendered, non-lazily

**ID:** FORUM-05 · **Priority:** P1 · **Category:** PERFORMANCE ISSUE
**Full detail:** `04_SCREEN_FORUMS.md`

`ForumTopicDetailView` renders replies in a plain `VStack` (not `LazyVStack`)
and auto-fetches every remaining page unconditionally, directly slowing
exactly the interaction (VoiceOver's linear element-tree walk) most
sensitive to jank.

## 12. Podcast transcripts are a single unsegmented text blob

**ID:** PODCAST-04 · **Priority:** P1 · **Category:** ACCESSIBILITY DEFECT / BRAILLE ISSUE
**Full detail:** `05_SCREEN_PODCASTS.md`

One accessibility element for a multi-thousand-word string, on what the
master spec calls a flagship accessibility feature — the app already has a
working segmentation pattern (`SegmentedHTMLView`) that was never applied
here.

## 13. Search fabricates a "No Results" VoiceOver announcement before any search has run

**ID:** SEARCH-01 · **Priority:** P2 (elevated for impact) · **Category:** BUG / ACCESSIBILITY DEFECT
**Full detail:** `10_SCREEN_DISCOVER_SEARCH.md`

`isSearching` only flips true *after* a 400ms debounce sleep; during that
window the empty-results state renders and immediately posts a false "No
Results" announcement, on one of the most frequently used screens in the
app.

## 14. The two most complex, most historically bug-prone systems in the app have essentially zero test coverage

**ID:** TEST-01, TEST-03 · **Priority:** P1–P2 · **Category:** TEST GAP
**Full detail:** `17_ENGINEERING_PERSISTENCE_PERFORMANCE_SECURITY_TESTING.md`

The entire automated suite is 4 unit-test files plus one UI test that's
explicitly skipped by default. `ICloudSyncManager`'s merge logic and
`Mappers`' JSON:API translation layer — the layer with the most documented
history of real live-production bugs — have almost no coverage.

## 15. A VoiceOver focus-delay pattern with hand-tuned magic numbers is duplicated 7+ times across the app

**ID:** CARD-12, HOME-01, GUIDED-01 · **Priority:** P2 · **Category:** ARCHITECTURE ISSUE
**Full detail:** `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md`, `14_SCREEN_GUIDED_EXPERIENCE_HELP.md`

Fixed `Task.sleep`-based VoiceOver-focus retry logic, each copy independently
tuned, recurs at least 7 times: twice in Home, at least once in Guided
Experience, and across 4+ submission wizards. None is derived from an actual
layout-completion signal — a classic "too-short delay silently drops focus
on a slow device" bug source, worth one shared fix rather than continuing to
patch instances individually.

## 16. VoiceOver action ordering puts destructive actions too close to the top, app-wide

**ID:** CARD-03 · **Priority:** P2 · **Category:** UX INCONSISTENCY
**Full detail:** `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md`

The current order places Edit/Delete/Unpublish in positions 2–6 of a
roughly 9–11 item rotor list, ahead of routine actions like Mark as Read —
opposite of the "dangerous actions always last" principle this audit's own
north-star rules require.

## 17. No semantic color tokens for warning/error/success/unread, and shared state views ignore the active theme

**IDs:** CARD-07, SEARCH-09 · **Priority:** P2 · **Category:** ARCHITECTURE ISSUE / VISUAL-LOW-VISION ISSUE
**Full detail:** `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md`, `10_SCREEN_DISCOVER_SEARCH.md`

State colors fall back to ad hoc system colors independent of the active
theme, missing per-theme contrast tuning across 15 themes including two
dedicated high-contrast themes. Separately, the app-wide `LoadingView`/
`ErrorView`/`EmptyStateView` components apply no theme background at all,
flashing to the default system background during every loading/error/empty
transition on a custom theme.

## 18. Saved/Following content can silently go stale across tab switches

**ID:** FORYOU-05 · **Priority:** P2 · **Category:** BUG / ARCHITECTURE ISSUE
**Full detail:** `11_SCREEN_FOR_YOU.md`

Saving/following an item elsewhere while For You stays open on that segment
shows stale data with no visible cue, directly contradicting the product's
explicit "state updates immediately" requirement.

## 19. HTML tables in guide/article content flatten into unreadable prose

**ID:** GUIDES-02 · **Priority:** P2 · **Category:** ACCESSIBILITY DEFECT
**Full detail:** `07_SCREEN_GUIDES_RESOURCES.md`

Comparison tables — common in accessibility how-to content, core to
AppleVis's mission — fall into generic prose with no row/column semantics
and no Braille cell boundaries.

## 20. Multiple correct accessibility patterns exist once but weren't applied to sibling screens

**IDs:** PROFILE-01/02/03, ONBOARD-05, CARD-05, CARD-11, BLOGS-04, APPS-05 · **Priority:** P2–P3 · **Category:** ACCESSIBILITY DEFECT / UX INCONSISTENCY
**Full detail:** `12_SCREEN_PROFILE_ONBOARDING.md`, `08_SCREEN_BLOGS.md`, `06_SCREEN_APPS.md`, `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md`

The single most repeated shape in this entire audit: `SignInView` correctly
moves VoiceOver focus to its error text, but `EditProfileView`/
`DeleteAccountView` don't; `SignInView` declares AutoFill content types, but
Onboarding's own sign-in step doesn't; a dead `isUnread` field looks real but
can never fire; fixed-point fonts bypass Dynamic Type in several places;
`ResourceDetailView` passes table-of-contents parameters `BlogDetailView`
doesn't; App reviews mix "Review" and "Comment" terminology in the same
menu; a fabricated "Member since [distant-past date]" ships despite a
written rule against it. Each instance is small individually; the pattern —
a correct solution invented once, then not propagated — is worth fixing
structurally (shared components, documented conventions enforced by tests),
not screen by screen.

---

## What these 20 have in common

Three repeating root causes explain most of this list:

1. **A correct pattern exists once but wasn't propagated** (#1, #4, #5, #15,
   #16, #17, #20) — the fix in each case is usually cheap once you know where
   the working example already lives in the same codebase. This is by far
   the largest category, and the reason Phase 1 of the roadmap (fixing the
   shared card/action system) and the shared-component consolidations in
   later phases have outsized leverage.
2. **Timing/state assumptions that don't hold under real conditions** (#2,
   #9, #13, #15, #18) — a debounce window, a re-stamped timestamp, an audio
   session reconfigured by an unrelated sound effect, a `.task` that doesn't
   re-fire on tab reselection, a hand-tuned delay that's sometimes too short.
3. **Real functionality gaps or losses that read as complete but aren't**
   (#3, #6, #7, #10, #11, #12, #14, #19) — a feature that "works" in the
   demo path but is silently broken, missing, untested, or degraded under
   realistic content volume or realistic file-picker origin.

None of these require a rewrite. Every one of the 20 has a concrete,
bounded, already-precedented fix described in its full-detail document.
**#3 (SUBMIT-04) is the one item on this list that should be treated as an
emergency fix regardless of how the rest of the roadmap is sequenced** — it
is silent, real, user-facing data loss on a feature the app actively
advertises, and it is compounded by #5's finding that the failure wouldn't
even be announced if the user were using VoiceOver.
