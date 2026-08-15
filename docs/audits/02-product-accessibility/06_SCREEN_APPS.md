# Screen Audit — Apps (App Directory)

Per `APPLEVIS_2026_1_MASTER_SPEC.md`: App directory, reviews, updates, new apps,
saved/followed apps, search and filters, rich visual cards.

Evidence files: `Sources/Views/Apps/AppBrowseView.swift`,
`Sources/Views/Apps/AppDetailView.swift`, `Sources/Models/AppListing.swift`,
`Sources/Views/Shared/RowViews.swift` (`AppListingRow`). Cross-screen findings
shared with Guides/Blogs/Bug Tracker are filed in full here (ALL-01 through
ALL-06) and cross-referenced from those docs rather than duplicated.

---

## APPS-01 — No search in the App Directory at all

- **Screen/component:** `AppBrowseView`
- **Severity:** P1
- **Category:** BUG
- **Evidence:** No `.searchable` modifier anywhere in `AppBrowseView.swift`, unlike Guides/Blogs/Bugs browse screens, which all have it.
- **Current behavior:** Users can only drill Platform → Category → paged list; there is no way to type an app name directly. `APPLEVIS_2026_1_MASTER_SPEC.md`'s Apps section explicitly lists "Search and filters" as a required feature.
- **Recommended behavior:** Add `.searchable` to the category list screen, ideally with a cross-category "search all apps" mode rather than requiring a category to already be selected.
- **Exact reason:** This is a direct, named spec violation, and search is one of the highest-value ways to find a specific app quickly rather than paging through a whole category — especially valuable for a screen-reader user for whom browsing by scroll is slower than for a sighted user visually scanning a grid.
- **Suggested implementation approach:** Add `.searchable(text:)` bound to a query that filters/fetches across the app directory, reusing the same result-row rendering (`AppListingRow`) already used elsewhere.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes.

---

## APPS-02 — No Saved/Followed local filter in the Apps tab, contradicting the spec's Saved Model

- **Screen/component:** `AppBrowseView.platformMenu`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** No `.saved` (or `.followed`) case exists among `AppBrowseView`'s filter options, though `APPLEVIS_2026_1_MASTER_SPEC.md`'s Saved Model section explicitly requires local filters including "Apps Saved."
- **Current behavior:** A user can only reach saved apps via the global Home Saved hub or For You, not from within the Apps tab itself.
- **Recommended behavior:** Add a Saved filter case to the Apps browse screen using `PersistenceStore.shared.isSaved`/`savedItems()`, matching the pattern the spec describes for "local filters" across all content areas.
- **Exact reason:** Direct, named spec gap; "Saved is not account/profile-only because users expect saved content where they use content" is explicit product intent in the spec.
- **Suggested implementation approach:** Add a `.saved` filter case alongside the existing platform/category filters, sourced from `PersistenceStore`.
- **Manual verification required:** No.
- **Regression tests required:** Yes.

---

## APPS-03 — VoiceOver accessibility rating is invisible in the browse row — the single most AppleVis-relevant signal is hidden until detail

- **Screen/component:** `RowViews.swift` `AppListingRow`, `Sources/Models/AppListing.swift`
- **Severity:** P2
- **Category:** IMPROVEMENT / UX INCONSISTENCY
- **Evidence:** `AppListing.voiceOverPerformance` is fetched as part of the model but never rendered anywhere in `AppListingRow`.
- **Current behavior:** A user scanning the App Directory list has no way to see or hear an app's VoiceOver accessibility rating without opening every individual app's detail page.
- **Recommended behavior:** Surface a compact rating indicator directly in the row (visible + spoken), consistent with the Unified Card Standard's "state that affects the decision to open it" hierarchy principle.
- **Exact reason:** For an app specifically built for a blind/low-vision community browsing an *accessibility-focused* app directory, the VoiceOver rating is arguably the single most decision-relevant piece of metadata — hiding it behind a detail-page tap adds friction to the app's core use case.
- **Suggested implementation approach:** Add a compact rating chip/text (reusing `RatingGaugeView`'s presentation approach — see APPS-08 PASS — scaled down for row use) to `AppListingRow`, included in both the visible layout and the row's combined accessibility label.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## APPS-04 — "Reviewed on" version/OS info is fetched but never rendered, hiding how current an accessibility review is

- **Screen/component:** `AppDetailView`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** `AppDetail.supportedDevices` is fetched but only feeds Spotlight indexing (never rendered in the UI); `.testedOnIOS` and `.reviewedVersion` have zero UI references anywhere in `AppDetailView.swift`.
- **Current behavior:** A user reading an app's accessibility review has no way to tell whether that review reflects the current app version or iOS release, or an outdated one.
- **Recommended behavior:** Render a "Reviewed on iOS X, app version Y" line near the review metadata.
- **Exact reason:** Whether an accessibility review is current matters materially more to a blind user deciding whether to trust it (apps change VoiceOver behavior across updates) than it would for a general app-store review — this is directly relevant to AppleVis's core mission.
- **Suggested implementation approach:** Add the already-fetched `testedOnIOS`/`reviewedVersion` fields to the review metadata display.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## APPS-05 — App reviews mix "Review" (visible UI) and "Comment" (VoiceOver) terminology for the identical content, in the same context menu

- **Screen/component:** `AppDetailView.swift` `AppReviewRow` / `ComposeAppReviewView`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** The same long-press context menu on a review row mixes vocabulary: visible UI labels say "Write Review"/"Edit Review"/"Delete Review," while the same row's VoiceOver label says "Comment X of Y" and its accessibility actions say "Reply to this Comment"/"Copy Comment Text"/"Report Comment" — sitting in the same menu as "Edit Review"/"Delete Review."
- **Current behavior:** A sighted user and a VoiceOver user form contradictory mental models of what this feature actually is (a review system vs. a comment thread) purely because of which modality they're using.
- **Recommended behavior:** Pick one vocabulary — "Comment" is the more accurate choice since the underlying count field is Drupal's `comment_count` (matching `AppListingRow`'s own deliberate "comment(s)" wording decision noted elsewhere in the codebase) — and apply it consistently across both visible UI and VoiceOver strings.
- **Exact reason:** Inconsistent terminology for identical functionality is confusing regardless of modality, and directly violates the Unified Card Standard's "same semantic operation, same wording everywhere" rule; it's particularly stark here because both vocabularies appear in the *same* menu simultaneously.
- **Suggested implementation approach:** Rename the visible "Write/Edit/Delete Review" strings to "Write/Edit/Delete Comment" (or vice versa, standardizing on "Review" if that's judged the more discoverable term — but the count field's actual meaning argues for "Comment").
- **Manual verification required:** No.
- **Regression tests required:** Yes — a wording-consistency test once the direction is chosen.

---

## APPS-06 — "Open in App Store" vs. "Open App Entry in Browser" are clearly distinguished (PASS)

- **Screen/component:** `AppDetailView` toolbar + bottom bar
- **Severity:** n/a
- **Category:** PASS
- **Evidence:** The toolbar's "Open in App Store" and the bottom bar's "Open App Entry in Browser" are clearly visually and semantically distinct in both icon and VoiceOver label.
- **Current behavior:** Correct as implemented — no ambiguity between the two very different destinations.
- **Recommended behavior:** No change; keep as the reference pattern when auditing similar dual-destination actions elsewhere (see CARD-04's podcast Share/Browser ambiguity for a contrasting case that should be brought up to this standard).
- **Manual verification required:** No. **Regression tests required:** No.

---

## APPS-07 — App Store button silently disappears (not disabled/explained) when no App Store URL exists

- **Screen/component:** `AppDetailView`
- **Severity:** P4
- **Category:** FUTURE IDEA
- **Evidence:** The "Open in App Store" control is simply omitted, not shown-disabled-with-explanation, when no App Store URL is available for a listing.
- **Current behavior:** A user browsing an app with no App Store link gets no explanation of why the button they'd expect isn't there.
- **Recommended behavior:** Low priority; consider a disabled state with a brief explanatory hint ("No App Store link available") if this proves confusing in practice.
- **Exact reason:** Minor discoverability nuance, not a functional gap.
- **Suggested implementation approach:** Optional; low priority.
- **Manual verification required:** No. **Regression tests required:** No.

---

## APPS-08 — `RatingGaugeView` conveys rating via text + description + color, never color alone (PASS)

- **Screen/component:** `AppDetailView`'s rating presentation
- **Severity:** n/a
- **Category:** PASS
- **Evidence:** `RatingGaugeView` combines a text value, a descriptive sentence, and color — matching the audit's explicit "no state may be conveyed only by color" requirement precisely.
- **Current behavior:** Correct.
- **Recommended behavior:** Use as the reference pattern for surfacing this same rating compactly in the row per APPS-03.
- **Manual verification required:** No. **Regression tests required:** No.

---

## APPS-09 — Platform selection is not persisted across cold launches

- **Screen/component:** `AppBrowseView` (`platform: AppPlatform = .ios` as plain `@State`)
- **Severity:** P4
- **Category:** IMPROVEMENT
- **Evidence:** Platform selection resets to `.ios` on every cold launch rather than remembering the user's last choice.
- **Current behavior:** A macOS-focused user has to re-select their platform every session.
- **Recommended behavior:** Persist the last-selected platform (e.g. via `@AppStorage` or `PreferencesStore`).
- **Exact reason:** Small but real repeated-friction papercut for macOS-focused users.
- **Suggested implementation approach:** Switch `@State` to `@AppStorage`.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Cross-screen findings (Apps + Guides + Blogs + Bug Tracker)

These findings were observed identically across all four content-kind screens
and are filed once here rather than duplicated in each screen's document;
`07_SCREEN_GUIDES_RESOURCES.md`, `08_SCREEN_BLOGS.md`, and
`09_SCREEN_BUG_TRACKER.md` each cross-reference back to this section.

### ALL-01 — `CommunityDiscussionHeading` omits the "new" count the app's own documentation specifies

- **Severity:** P3 · **Category:** UX INCONSISTENCY (vs. documented intent)
- **Evidence:** `Sources/Views/Shared/CommunityDiscussionHeading.swift`'s accessibility label has no "new" count segment anywhere, though `docs/IMPLEMENTATION_NOTES.md`'s own example wording is *"Community Discussion - 32 comments - 1 new."* All four content-kind detail screens (Apps, Guides, Blogs, Bugs) are internally consistent with each other, but all diverge from the documented target in the same way. (Forums has the same gap independently filed as FORUM-09.)
- **Current behavior:** Heading never states how many of the comments are new, app-wide.
- **Recommended behavior:** Add an optional `newCount` parameter to `CommunityDiscussionHeading`, computed via `PersistenceStore.shared.newReplyCount` at each of the five call sites (Forums, Apps, Guides, Blogs, Bugs).
- **Exact reason:** The app's own written accessibility convention describes this exact wording; every detail screen currently falls short of it identically, suggesting the heading component was built before the "new" convention was written, or the convention was written aspirationally and never wired through.
- **Suggested implementation approach:** Extend `CommunityDiscussionHeading`'s parameters and thread the appropriate `newReplyCount` call through each of its five call sites.
- **Manual verification required:** No. **Regression tests required:** Yes — one wording test would cover all five call sites once the component itself is fixed.

### ALL-02 — All four screens build comments on the identical shared component (PASS)

- **Category:** PASS. No per-screen structural divergence found in how Apps/Guides/Blogs/Bugs assemble their comment sections — genuinely unified, a good sign for long-term maintainability.

### ALL-03 — Comment/review rows correctly split header from body (PASS)

- **Category:** PASS. Every comment/review row across all four screens renders an actionable combined header (author/date/subject/state/actions) separate from a plain readable body — exactly matching `docs/IMPLEMENTATION_NOTES.md`'s documented "two accessibility areas" rule.

### ALL-04 — No VoiceOver refocus/confirmation after posting a comment, across all four compose flows

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** None of the four compose sheets (App review, Guide comment, Blog comment, Bug comment) set `@AccessibilityFocusState` after a successful post, unlike the existing "Jump to Last Comment" mechanism used elsewhere for navigation.
- **Current behavior:** A screen-reader user isn't confirmed, without extra swiping, that their comment posted successfully or where it landed in the thread.
- **Recommended behavior:** After a successful post, dismiss the compose sheet and move VoiceOver focus to the newly-posted comment (mirroring Forums' well-implemented post-reply focus pattern — see FORUM-P2 in `04_SCREEN_FORUMS.md`).
- **Exact reason:** Forums already solves this correctly; Apps/Guides/Blogs/Bugs should match that existing, proven pattern rather than reinvent or omit it.
- **Suggested implementation approach:** Reuse the Forums post-reply focus/scroll pattern for the four other content kinds' compose flows.
- **Manual verification required:** Yes. **Regression tests required:** Yes.

### ALL-05 — HTML rendering is documented as main-thread, WebKit-backed, and slow; more noticeable under VoiceOver's linear swipe-through

- **Severity:** P3 · **Category:** PERFORMANCE ISSUE / MANUAL VERIFY
- **Evidence:** `NSAttributedString(html:)` usage is documented in-file as "known-slow, WebKit-backed, main-thread-only," mitigated only after first render by an `NSCache`.
- **Current behavior:** First-render jank is a known, accepted tradeoff; the risk specifically called out here is that janky scrolling during VoiceOver's linear swipe-through of a long comment thread is more noticeable/disruptive than the equivalent for a sighted fast-scroller (who can visually skim past a stutter; a VoiceOver user's navigation rhythm is directly interrupted by a frame hitch).
- **Recommended behavior:** Profile with Instruments specifically under VoiceOver navigation on a long thread; consider pre-warming the cache or moving parsing further off the critical path if profiling confirms a real-world impact.
- **Exact reason:** Matches the audit package's "Performance is accessibility" north-star rule directly — this is a case where a performance characteristic has a measurably different impact depending on interaction modality.
- **Suggested implementation approach:** Instruments profiling pass on a long real thread with VoiceOver running; consider prefetching/caching ahead of scroll position.
- **Manual verification required:** Yes. **Regression tests required:** No formal test; flag as a periodic MANUAL VERIFY.

### ALL-06 — `CommandMenu("Go")` doesn't reach Apps or Resources at all

- **Severity:** P3 · **Category:** BUG / MANUAL VERIFY
- **Evidence:** `Sources/App/AppleVisApp.swift`'s `CommandMenu("Go")` only has shortcuts for Home/Discover/For You (Cmd+1/2/3) — no shortcut reaches Apps or Resources, and (per `04_SCREEN_FORUMS.md` FORUM-15) none reaches Forums either.
- **Current behavior:** Only 2 of 5 primary content areas (Home, plus Discover as a proxy for browsing) are directly keyboard-reachable; Forums, Apps, and Resources all require multi-step keyboard/pointer navigation first.
- **Recommended behavior:** Add direct shortcuts/menu entries for all five primary tabs, consistent with the master spec's "Full keyboard navigation" / "External keyboard shortcuts" requirement for iPad.
- **Exact reason:** Undercuts the explicit iPad keyboard-navigation requirement; inconsistent that only 2 of 5 destinations are one shortcut away.
- **Suggested implementation approach:** Extend the existing `CommandMenu("Go")` with the remaining three destinations.
- **Manual verification required:** Yes — external keyboard/iPad pass. **Regression tests required:** No.

---

## Apps summary

Apps has one direct, named spec violation (APPS-01: no search) and one
Saved-model gap (APPS-02) that should both be treated as high priority given
they're explicit master-spec requirements, not just polish. APPS-05's
Review/Comment terminology split is a good example of a defect visible to
*both* sighted and blind users simultaneously — worth fixing regardless of
audience. APPS-03/04 are both "the data already exists, it's just not
rendered" gaps, which is the cheapest class of fix in this audit. The
cross-screen findings (ALL-01 through ALL-06) show Apps/Guides/Blogs/Bugs are
unusually consistent with *each other* (ALL-02, ALL-03 are strong PASSes) —
the remaining work is bringing all four up to match Forums' more mature
focus-management patterns (ALL-04) and closing the documented-vs-actual
wording gap in the shared discussion heading (ALL-01).
