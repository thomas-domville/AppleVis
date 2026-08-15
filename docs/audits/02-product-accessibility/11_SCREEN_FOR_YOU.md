# Screen Audit — For You

Mission (per audit package): "What did I choose to keep, continue or follow?"
— Queue / Downloads / Saved / Following.

Evidence files: `Sources/Views/ForYou/ForYouView.swift`, cross-referenced
against `Sources/Stores/PlayerStore.swift`/`DownloadManager.swift`
(Podcasts doc) and `Sources/Stores/PersistenceStore.swift`.

---

## FORYOU-01 — Screen's orientation sentence is hidden from VoiceOver; bare segment names may not convey the screen's mission

- **Screen/component:** `ForYouView`
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT / MANUAL VERIFY
- **Evidence:** The screen's orientation sentence (explaining what For You is for) is deliberately `.accessibilityHidden(true)`, on the theory that the segmented Picker's own announcement of "Queue"/"Downloads"/"Saved"/"Following" suffices.
- **Current behavior:** Sighted users see the explanatory sentence; VoiceOver users get only the bare segment names with no equivalent framing sentence.
- **Recommended behavior:** Reconsider whether bare segment names alone convey the screen's mission as well as the hidden sentence does visually — if not, expose an abbreviated version of the orientation text to VoiceOver (e.g. via the screen's navigation title or a one-time announcement on first entry) rather than hiding it entirely.
- **Exact reason:** The audit package explicitly calls for "orientation text explaining the screen's purpose" for For You; hiding it entirely from VoiceOver users, even if the original intent (avoiding redundancy with the Picker's own speech) was reasonable, risks losing real orientation value for exactly the users who benefit most from it.
- **Suggested implementation approach:** A/B this manually with VoiceOver: try exposing a short version of the orientation text (not the full sentence, to avoid redundancy with the Picker) and judge whether it improves first-time comprehension of the screen.
- **Manual verification required:** Yes — this is fundamentally a judgment call needing an actual VoiceOver listen-through.
- **Regression tests required:** No.

---

## FORYOU-02 — Picker tick sound correctly gated and defaults off (PASS)

- **Category:** PASS
- **Evidence:** The segment-switch tick sound is correctly gated behind `interfaceSoundsEnabled` and defaults off, matching the master spec's sound-default table exactly (tab/segment switching sounds should default off).
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-03 — "Delete downloaded episode" has three different labels depending on interaction modality

- **Screen/component:** `ForYouView` Downloads section
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** The identical operation (removing a downloaded episode) is labeled "Delete" on the swipe action, "Remove Download" as the VoiceOver custom action, and "Remove Downloads" on the bulk-action button — three different strings for one operation.
- **Current behavior:** A Voice Control user who hears VoiceOver announce "Remove Download" and then tries to say that exact phrase to activate the equivalent swipe action (labeled "Delete" visually) won't find a match, since Voice Control's "tap X" command matches against the *visible* label, not the VoiceOver custom-action name.
- **Recommended behavior:** Standardize on one term (e.g. "Remove Download"/"Remove Downloads" for the singular/plural forms) across swipe, VoiceOver action, and bulk button.
- **Exact reason:** This is a concrete instance of the Unified Card Standard's "same semantic operation, same wording everywhere" rule causing a *real cross-modality failure*, not just an inconsistency of taste — Voice Control specifically depends on visible label text matching what the user says.
- **Suggested implementation approach:** Rename the swipe action's visible label from "Delete" to "Remove Download," aligning all three surfaces.
- **Manual verification required:** Yes — Voice Control pass attempting to activate the swipe action by voice using the VoiceOver-announced phrase.
- **Regression tests required:** Yes — wording-consistency test across the three surfaces.

---

## FORYOU-04 — Pull-to-refresh correctly scopes to the currently-selected section (PASS)

- **Category:** PASS
- **Evidence:** Each section's pull-to-refresh only reloads that section's own data, matching the audit package's explicit "refresh should match the selected section" requirement.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-05 — Saved/Following data can go stale across tab switches with no visual cue and no automatic refresh

- **Screen/component:** `ForYouView`'s `SavedItemsView`/`FollowingView`
- **Severity:** P2
- **Category:** BUG / ARCHITECTURE ISSUE
- **Evidence:** `SavedItemsView`/`FollowingView` load their data via `.task` only, which SwiftUI re-runs on first appearance or on view identity change, but not on tab reselection alone; there is no subscription to `PersistenceStore` change events either.
- **Current behavior:** If a user saves or follows an item elsewhere in the app (e.g. from a Forums row) while the For You tab remains on the Saved/Following segment in the background, returning to that segment shows stale data — the newly saved/followed item is missing — until a manual pull-to-refresh, with no visual cue that anything is stale.
- **Recommended behavior:** Either subscribe to `PersistenceStore`'s underlying save/follow change events (so the view updates reactively, matching how `ContentActionsModifier`'s own `isSaved`/`isFollowing` `@State` refreshes locally), or force a reload on every tab reselection, not just first appearance.
- **Exact reason:** This directly conflicts with the audit package's explicit "saved/follow state update immediately" requirement for For You, and is a believable, easy-to-hit real-world scenario (save something from a list, immediately switch to For You to confirm it's there).
- **Suggested implementation approach:** The cleanest fix is likely making `PersistenceStore`'s saved/followed collections independently observable (e.g. `@Published` arrays on a `@MainActor` `ObservableObject`, which `PersistenceStore` may already partially be — worth checking against the Engineering audit's architecture findings) so `SavedItemsView`/`FollowingView` update reactively without any manual refresh at all, rather than only fixing the `.task` re-run trigger.
- **Manual verification required:** Yes — save an item from another screen, background-switch to For You's Saved segment (already visible/loaded), confirm it doesn't appear until manual refresh; then confirm the fix.
- **Regression tests required:** Yes — a test simulating a `PersistenceStore` mutation while a `SavedItemsView`/`FollowingView` instance is alive, asserting it reflects the change without requiring a manual reload trigger.

---

## FORYOU-06 — Bulk-destructive actions use `.confirmationDialog` with scope-reassurance text (PASS)

- **Category:** PASS
- **Evidence:** Both "Remove Downloads" and "Unsave All" use `.confirmationDialog` with explicit text reassuring the user about the action's scope (e.g. confirming it only affects downloads, not the underlying saved-item record, or vice versa).
- **Recommended behavior:** No change; this is the correct pattern to extend to Delete Account (see PROFILE-07, which currently lacks this exact pattern despite being far more consequential).
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-07 — Empty states have descriptive text but no actionable CTA to jump to relevant content

- **Screen/component:** `ForYouView` Downloads/Saved/Following empty states
- **Severity:** P3
- **Category:** IMPROVEMENT
- **Evidence:** These empty states show descriptive text but, unlike Search's "Clear Search" CTA pattern, offer no actionable button (e.g. "Browse Forums," "Browse Podcasts") to help a user with nothing saved/followed/downloaded find something to add.
- **Current behavior:** A first-time user landing on an empty For You segment gets an explanation but no direct next step.
- **Recommended behavior:** Add a primary CTA button per empty state (reusing `EmptyStateView`'s existing `primaryActionLabel`/`primaryAction` parameters, which are already designed for exactly this — see `Sources/Views/Shared/LoadingView.swift`) that navigates to a relevant browse screen.
- **Exact reason:** Matches the audit package's explicit "empty-state actions" requirement for For You ("is there a helpful CTA, not just 'nothing here'?").
- **Suggested implementation approach:** Populate `EmptyStateView`'s existing optional CTA parameters at each of the three empty-state call sites, since the underlying component already supports this — it's simply unused here.
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-08 — Filtered-to-zero Saved results show the same generic empty state as genuinely-empty Saved, with no way to clear the filter

- **Screen/component:** `ForYouView` Saved segment, kind filter
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Filtering Saved to a single content kind (e.g. Podcasts only) with zero matches shows the identical generic "Nothing Saved" empty state used when the user has literally nothing saved at all, with no way to clear the active filter from that empty state.
- **Current behavior:** A user with plenty saved (just none of the filtered kind) sees the same message as a user with nothing saved at all — and has no direct path back to "show everything" from the empty state itself.
- **Recommended behavior:** Distinguish the two cases with different wording ("Nothing saved yet" vs. "No saved [kind] — you have other saved items") and add a "Clear Filter" affordance to the filtered-empty variant.
- **Exact reason:** Matches the audit package's explicit "filter-specific empty state" requirement for For You.
- **Suggested implementation approach:** Branch the empty-state message/CTA on whether a filter is active and whether the *unfiltered* collection is also empty.
- **Manual verification required:** No. **Regression tests required:** Yes — a test asserting the two distinct empty-state variants render correctly.

---

## FORYOU-09 — Queue reorder correctly exposes Move Up/Move Down (cross-cutting confirmation, see PODCAST-P2)

- **Category:** PASS (cross-reference)
- **Evidence:** Confirms, from the For You side, the same finding independently verified in `05_SCREEN_PODCASTS.md` (PODCAST-P2): queue reorder correctly exposes Move Up/Move Down VoiceOver actions alongside drag, satisfying the "never require drag-only interactions" requirement.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-10 — In-progress downloads combine title and progress into one spoken element (PASS)

- **Category:** PASS
- **Evidence:** In-progress download rows combine title and progress percentage into a single accessibility element with a spoken percent value, rather than exposing them as separate stops.
- **Recommended behavior:** No change; contrast with PODCAST-03 (episode detail's download indicator, which has no interactive cancel affordance at all) — For You's presentation is accessible for *reading* state, though it inherits the same lack-of-cancel gap from `DownloadManager` if a cancel action isn't wired here either (not independently confirmed in this pass; worth checking during implementation of PODCAST-03's fix).
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-11 — All custom row types route Save/Follow/Share through the shared `.contentActions` modifier (PASS)

- **Category:** PASS
- **Evidence:** No bespoke reimplementation of Save/Follow/Share logic found in For You's row types — everything routes through the shared modifier, meaning any CARD-01/CARD-03 fix to the shared system will automatically apply here too, with no separate For You-specific fix needed.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## FORYOU-12 — Signed-out state is visually/semantically distinct from signed-in-but-empty (PASS)

- **Category:** PASS
- **Evidence:** The Following segment correctly distinguishes "you're not signed in, so Following isn't available" from "you're signed in but haven't followed anything yet" — two meaningfully different states with different messaging.
- **Recommended behavior:** No change; good reference pattern for any other feature that's gated on sign-in status.
- **Manual verification required:** No. **Regression tests required:** No.

---

## For You summary

For You is well-architected in its per-row action reuse (FORYOU-11) and its
scoped-refresh/bulk-confirmation patterns (FORYOU-04, FORYOU-06) — the
strongest finding here is FORYOU-05, a real staleness bug that directly
contradicts an explicit product requirement ("saved/follow state updates
immediately") and is easy to hit in ordinary use (save something elsewhere,
check For You). FORYOU-03's three-way wording split for the same download
operation is a concrete, verifiable Voice Control failure mode, not just a
style nit. The remaining findings (FORYOU-07, FORYOU-08, FORYOU-01) are
lower-severity completeness gaps in an otherwise solid screen.
