# Screen Audit — Discover & Search

Mission (per audit package): Discover — "What else should I explore?" · Search
— "Help me find exactly what I need."

Evidence files: `Sources/Views/Discover/DiscoverView.swift`,
`Sources/Views/Discover/SearchResultsView.swift`,
`Sources/Views/Shared/LoadingView.swift` (cross-referenced from CARD-13).

---

## DISCOVER-01 — Be My Eyes deep link opens optimistically with a spoken explanation and graceful fallback (PASS)

- **Category:** PASS
- **Evidence:** The Be My Eyes entry point opens the deep link optimistically with a spoken explanation and a graceful App Store fallback, rather than relying on an unreliable `canOpenURL` pre-check (which requires an `LSApplicationQueriesSchemes` entry and can silently mis-report app-installed status).
- **Recommended behavior:** No change; good reference pattern for any other "open another app if installed, else App Store" flow elsewhere in the app.
- **Manual verification required:** No. **Regression tests required:** No.

---

## DISCOVER-02 — Hub section headers correctly support the Headings rotor (PASS)

- **Category:** PASS
- **Evidence:** Every hub section header is `.accessibilityElement(children: .combine)`d and `.isHeader`-tagged, with a spoken title distinct from its visually-uppercased rendering.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## DISCOVER-03 — Shipped tab structure (3 tabs) diverges from the master spec's 5-tab requirement

- **Screen/component:** App-wide tab bar / `DiscoverView`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `APPLEVIS_2026_1_MASTER_SPEC.md` requires a 5-tab bar (Home/Forums/Podcasts/Apps/Resources); the shipped app has 3 tabs (Home/Discover/For You) with Forums/Podcasts/Apps/Resources collapsed into a hub grid inside Discover.
- **Current behavior:** A significant, deliberate architectural divergence from the written spec — this reads as an intentional later product decision (the "3-tab redesign" referenced in project history/memory) rather than an oversight, but it means the master spec document itself is now stale on this specific point.
- **Recommended behavior:** This needs a product decision, not a code fix: either update `APPLEVIS_2026_1_MASTER_SPEC.md` to reflect the 3-tab structure as the current intended design, or treat the spec as still-authoritative and reconsider the tab structure. Flagging here so the audit doesn't silently treat one or the other as ground truth.
- **Exact reason:** Every other finding in this audit package that references "the master spec" for Forums/Podcasts/Apps/Resources implicitly assumes those are reachable top-level destinations; if the 3-tab structure is the intended final design, several other findings' framing (e.g. "add a keyboard shortcut to reach Forums directly," ALL-06) should be revisited against the hub-based navigation model instead.
- **Suggested implementation approach:** Product/design decision, not an engineering task; once decided, reconcile the written spec document accordingly.
- **Manual verification required:** No. **Regression tests required:** No.

---

## DISCOVER-04 — Contribute row chevrons are not hidden from VoiceOver, unlike every other decorative chevron in the app

- **Screen/component:** `DiscoverView.contributeRow`
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `contributeRow`'s trailing chevron lacks `.accessibilityHidden(true)`, unlike every other decorative chevron in the codebase (e.g. `externalAppRow`, which does hide its own).
- **Current behavior:** VoiceOver likely appends "chevron right" noise to all 5 Contribute rows (Submit App/Blog/Bug/Podcast/Contact), one extra spoken word per row for information that adds nothing (the row itself already indicates it's tappable via its trait).
- **Recommended behavior:** Add `.accessibilityHidden(true)` to the chevron, matching the established app-wide pattern.
- **Exact reason:** Small, consistent, one-line fix; worth doing as part of any pass touching this file since it's an easy win.
- **Suggested implementation approach:** Add the modifier to `contributeRow`'s chevron `Image`.
- **Manual verification required:** No. **Regression tests required:** No.

---

## DISCOVER-05 — No in-page jump mechanism for the large hub screen beyond the Headings rotor

- **Screen/component:** `DiscoverView`
- **Severity:** P4
- **Category:** VISUAL-LOW-VISION ISSUE / FUTURE IDEA
- **Evidence:** The Discover hub screen has roughly 23 rows across its sections, with no in-page jump mechanism other than the VoiceOver Headings rotor.
- **Current behavior:** A Switch Control user (who has no rotor-equivalent jump mechanism) must step through the screen serially, which is costly on a screen this long.
- **Recommended behavior:** Consider a lightweight section-jump affordance (e.g. a segmented control or menu) usable without VoiceOver's rotor, if this screen continues to grow.
- **Exact reason:** Rotor-based navigation shortcuts are VoiceOver-specific; Switch Control users get no equivalent benefit from `.isHeader` traits alone.
- **Suggested implementation approach:** Low priority; revisit if the hub screen's row count grows further.
- **Manual verification required:** Yes — Switch Control timing pass on this specific screen. **Regression tests required:** No.

---

## SEARCH-01 — A fabricated "No Results" VoiceOver announcement fires before any search request is even sent

- **Screen/component:** `SearchResultsView` / the search view model's `runSearch`
- **Severity:** P2
- **Category:** BUG / ACCESSIBILITY DEFECT
- **Evidence:** `runSearch` only sets `isSearching = true` *after* a 400ms debounce `Task.sleep`. During that debounce window, `SearchResultsView` renders its `EmptyStateView("No Results")` branch (since no search is registered as "in progress" yet and there are no results yet either) — and per CARD-13, `EmptyStateView` immediately posts a `.screenChanged` announcement on `.onAppear`. The practical effect: on every first character typed into the search field, VoiceOver announces "No Results" before the debounced request has even been sent, let alone returned.
- **Current behavior:** A completely fabricated "No Results" announcement fires on every fresh search, before there was ever a chance for real results to exist.
- **Recommended behavior:** Set `isSearching = true` synchronously, before the debounced `Task` begins (so the screen renders a loading state immediately, not the empty-results state), or introduce an explicit `hasSearched` gate so `EmptyStateView`'s "No Results" branch can only render after a real request has actually completed with zero matches.
- **Exact reason:** This is a textbook "announcing information VoiceOver will immediately contradict" problem the audit package explicitly warns against — worse, it's not just redundant, it's actively false, undermining trust in the app's own announcements on one of the most frequently used screens.
- **Suggested implementation approach:** Move `isSearching = true` to fire synchronously on text change, before entering the debounce `Task.sleep`; gate the "No Results" empty state behind an explicit "a real request has completed" flag rather than inferring it from `isSearching == false && results.isEmpty`.
- **Manual verification required:** Yes — type a single character with VoiceOver running and confirm no "No Results" announcement fires prematurely.
- **Regression tests required:** Yes — a view-model test asserting `isSearching` is `true` immediately (synchronously) on query change, before the debounce elapses.

---

## SEARCH-02 — Identical search-result announcements repeat on every settle, even with no actual change

- **Screen/component:** Search results announcement logic
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `announceSearchResults` posts a VoiceOver announcement on every debounce settle even when the message is byte-for-byte identical to the previous one (only the accompanying sound effect is deduplicated, not the announcement itself).
- **Current behavior:** Refining a query in a way that doesn't change the result count/summary (e.g. typing then deleting a character) can still re-trigger an identical, interrupting announcement.
- **Recommended behavior:** Deduplicate the announcement the same way the sound is already deduplicated — skip posting if the message is unchanged from the last announcement.
- **Exact reason:** Matches the audit package's "avoid announcing information VoiceOver will immediately speak through moved focus" / redundant-announcement guidance; repeated identical interruptions during active typing are a real annoyance.
- **Suggested implementation approach:** Track the last-announced message string and compare before posting.
- **Manual verification required:** Yes. **Regression tests required:** Yes — unit test asserting no duplicate announcement for an unchanged result summary.

---

## SEARCH-03 — Search results reuse the exact same shared row components as their home screens (PASS)

- **Category:** PASS
- **Evidence:** Search results reuse `ForumTopicRow`/`PodcastEpisodeRow`/etc. directly rather than a bespoke result-row type — no drift risk against the Unified Card Standard.
- **Recommended behavior:** No change; good reference pattern, in contrast to any screen found building its own bespoke row type elsewhere in the audit.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SEARCH-04 — Correctly distinguishes zero-match search from a search where every category failed (PASS)

- **Category:** PASS
- **Evidence:** A genuine zero-match search renders `EmptyStateView`; a search where every category's underlying fetch failed renders `ErrorView` with Retry — these are correctly treated as distinct states, not conflated.
- **Recommended behavior:** No change; this is exactly the "empty search vs. zero results" and "failed search recovery" distinction the audit package calls out as a required check.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SEARCH-05 — No recent-search history

- **Screen/component:** `SearchResultsView`
- **Severity:** P4
- **Category:** FUTURE IDEA
- **Evidence:** No recent-search history feature exists.
- **Current behavior:** Every search starts from a blank field with no memory of prior queries.
- **Recommended behavior:** Consider adding recent-search history as a future enhancement.
- **Exact reason:** Standard search-UX convenience; low priority relative to the correctness bugs above.
- **Suggested implementation approach:** Future work.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SEARCH-06 — No explicit focus-into-search-field on Discover tab entry

- **Screen/component:** `DiscoverView` / `SearchResultsView`
- **Severity:** P4
- **Category:** MANUAL VERIFY
- **Evidence:** No explicit focus-into-search-field logic found; relies entirely on the system `.searchable` default behavior, which has historically been inconsistent across iOS versions.
- **Current behavior:** Unconfirmed from static code whether the search field reliably receives focus/keyboard on entry across the app's supported OS range.
- **Recommended behavior:** Confirm on-device across supported iOS versions; add explicit focus management only if the system default proves unreliable.
- **Exact reason:** System-default behavior for `.searchable` focus is a known area of OS-version variance.
- **Suggested implementation approach:** Manual test first.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## SEARCH-07 — Partial-category-failure banner correctly combines warning icon, message, and Retry into one accessible element plus a real button (PASS)

- **Category:** PASS
- **Evidence:** The partial-failure banner hides its warning icon and combines the message into one element, while still exposing a real, independently-activatable `Button` for Retry — avoiding the "buried interactive child inside a `.combine`d element" trap.
- **Recommended behavior:** No change; good reference pattern (compare to `SourceErrorBanner` on Home, HOME-05, which has a similar structure).
- **Manual verification required:** No. **Regression tests required:** No.

---

## SEARCH-08 — Stale results remain visible with no loading cue during the debounce window (same root cause as SEARCH-01)

- **Screen/component:** `SearchResultsView`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Same root cause as SEARCH-01 — because `isSearching` doesn't flip until after the debounce, stale results from a *previous* query remain on screen with no loading indicator while the user continues typing, risking the user reading/acting on outdated results.
- **Current behavior:** No visible signal that displayed results may not correspond to the current query text during the debounce window.
- **Recommended behavior:** Fixed by the same change recommended for SEARCH-01 (flip `isSearching` synchronously) — this entry records the sighted-user-facing consequence of that same bug, distinct from SEARCH-01's VoiceOver-specific consequence.
- **Exact reason:** Both are symptoms of the same underlying timing bug; worth fixing together.
- **Suggested implementation approach:** See SEARCH-01.
- **Manual verification required:** Yes, as part of the SEARCH-01 fix verification. **Regression tests required:** Covered by the SEARCH-01 test.

---

## SEARCH-09 — Shared `LoadingView`/`ErrorView`/`EmptyStateView` apply no theme/background, causing a visible flash to default system background on custom themes

- **Screen/component:** `Sources/Views/Shared/LoadingView.swift` (all three views) — cross-cutting, not Search-specific
- **Severity:** P2
- **Category:** VISUAL-LOW-VISION ISSUE
- **Evidence:** `LoadingView`/`ErrorView`/`EmptyStateView` (see CARD-13 for their positive VoiceOver-announcement behavior) apply no theme/background modifier at all, unlike the surrounding hub grid and results list, which both explicitly theme their background via `preferences.colors`/`.themedList`.
- **Current behavior:** A user on a custom theme (any of the 15 in `ThemeColors`, especially the two dedicated high-contrast themes or the darker `midnight`/`nebula` themes) sees the screen flash to the default system background color during searching/error/empty transient states, then back to their chosen theme's background once real content renders.
- **Recommended behavior:** Apply the active theme's background to all three shared state views, consistent with every other themed surface in the app.
- **Exact reason:** This is a shared-component-level bug, so it affects every screen that uses `LoadingView`/`ErrorView`/`EmptyStateView` app-wide, not just Search — for a user on a high-contrast theme specifically for low-vision reasons, an unexpected flash to a low-contrast default background during a loading/error/empty transition is a real, jarring low-vision usability problem, not merely a cosmetic one.
- **Suggested implementation approach:** Add `preferences.colors.background` (or equivalent theming modifier already used elsewhere) to `LoadingView`/`ErrorView`/`EmptyStateView`'s outer container, sourced the same way other themed screens already do.
- **Manual verification required:** Yes — visually confirm on at least one high-contrast theme and one dark theme that no flash to default system background occurs during a loading/error/empty transition.
- **Regression tests required:** No automated visual-regression test is practical without snapshot infrastructure; flag as periodic MANUAL VERIFY, but consider a lightweight assertion that these views read from `PreferencesStore`/`EnvironmentObject` at all, if that infrastructure exists elsewhere.

---

## SEARCH-10 — Braille display behavior with the standard `.searchable` field needs a real-device pass

- **Screen/component:** `SearchResultsView`
- **Severity:** P4
- **Category:** MANUAL VERIFY
- **Evidence:** Standard `.searchable` field, no custom keyboard overrides found in source.
- **Current behavior:** Likely fine (standard system control), but not independently confirmed with a real Bluetooth Braille display.
- **Recommended behavior:** Confirm on-device per the audit package's explicit Braille input testing requirement.
- **Exact reason:** Per the audit package's Braille input checklist ("search" is explicitly named).
- **Suggested implementation approach:** Manual test only.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## Discover & Search summary

Search has one real, actively-misleading VoiceOver bug (SEARCH-01/SEARCH-08 —
same root cause, a debounce-timing gap that fires a false "No Results"
announcement and leaves stale results visible with no loading cue) that
should be fixed together as a single timing fix. SEARCH-09 is the most
consequential *cross-cutting* finding to come out of this pair of screens: it
extends CARD-13's otherwise-positive shared-state-view finding with a real
low-vision regression (theme flash) that affects every screen using those
three shared components, not just Search. Discover itself is in solid shape
(DISCOVER-01/02 are good reference patterns); its one open question
(DISCOVER-03) is a product/documentation reconciliation, not an engineering
defect.
