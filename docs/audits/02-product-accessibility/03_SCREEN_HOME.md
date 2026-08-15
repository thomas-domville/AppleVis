# Screen Audit — Home

Mission (per audit package): "What happened since I was last here?"

Evidence files: `Sources/Views/Home/HomeView.swift`, `Sources/Views/Home/HomeViewModel.swift`,
`Sources/Stores/PersistenceStore.swift`, `Sources/Models/FeedItem.swift`,
`Sources/Models/Forum.swift`. Findings that are really about the shared row/action
system rendered on Home (`ForumTopicRow`, `PodcastEpisodeRow`, etc.) are filed in
`02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` (CARD-01 through CARD-12) and are not
repeated here except by reference.

---

## HOME-01 — Two independent hardcoded-delay VoiceOver focus-retry loops (see CARD-12)

- **Screen/component:** `HomeView.announceWelcomeIfNeeded()` (lines 176–184) and `WhatsNewCard.onTap` (lines 306–312)
- **Severity:** P2
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** See `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` CARD-12 for full detail. Filed there because the pattern (and its risk of being copy-pasted into future screens) is cross-app relevant; recorded here as it is currently Home-only.
- **Current/recommended/reason/approach:** See CARD-12.
- **Manual verification required:** Yes.
- **Regression tests required:** No practical automated test; MANUAL VERIFY each release.

---

## HOME-02 — "Mark as Read" gating previously missed brand-new (never-visited) items; now fixed, but the underlying two-signal model (`isNew` vs `newCount`) is fragile and worth simplifying

- **Screen/component:** `FeedRow` (`HomeView.swift` lines 579–631)
- **Severity:** P3
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** `FeedRow` carries two independent "newness" signals — `isNew` (item never visited, or visited-but-with-newer-activity, computed by `HomeViewModel.isNewActivity`) and `newCount` (reply delta since last visit, computed by `HomeViewModel.newReplyCount`). The `ConditionalAccessibilityAction` at lines 627–629 already had to be widened to `(isNew || newCount > 0)` specifically because a brand-new item has `newCount == 0` (no prior comment-count baseline to diff against) even though it is clearly new — the code comment there documents this exact bug having been reported and fixed. The visible "NEW" badge overlay (lines 606–619) similarly has to special-case `isNew && newCount == 0` to avoid showing two different "new" badges (`NewCountBadge` from the underlying row + this "NEW" overlay) at once.
- **Current behavior:** Correct today, but arrived at via what reads as a small patch (widening one boolean condition) rather than a single unified model. Two people modifying "newness" logic independently (one in `HomeViewModel`, one in the individual row's own `newCount` computed property in `RowViews.swift`) is a plausible source of a *third* variant of this same bug reappearing elsewhere — e.g. if a future new content type or new screen (For You, Search) reintroduces its own newness calculation without noticing both signals need combining.
- **Recommended behavior:** Introduce a single `ItemNewness` value (e.g., an enum or small struct with `isBrandNew: Bool` and `newReplyCount: Int`, or simply a single computed `effectiveNewCount`/`isNewOrHasNewReplies` helper) computed once in `PersistenceStore` or `FeedItem`, and have every call site (Home's `FeedRow`, every unified row's own `newCount`, and any future consumer) go through that single helper instead of independently reconstructing the "is this new" logic.
- **Exact reason:** Reduces the chance of the exact bug class already found and fixed once (brand-new items not being markable-as-read) from recurring in a new call site; also simplifies future maintenance since there is currently no single documented definition of "new" — it's implicitly defined by the combination of two independently-computed booleans.
- **Suggested implementation approach:** Add a single source-of-truth function, e.g. `PersistenceStore.newness(kind:id:currentCount:lastActivityAt:) -> (isNew: Bool, newReplyCount: Int)`, and refactor `HomeViewModel.isNewActivity`/`newReplyCount` and `RowViews.swift`'s per-row `newCount` computed properties to call it, rather than maintaining parallel implementations.
- **Manual verification required:** No for the refactor itself; a quick manual pass after refactoring to confirm brand-new/revisited/with-new-replies items all still behave identically.
- **Regression tests required:** Yes — this is an ideal target for the "state wording"/"missing baseline" unit tests already recommended in the Unified Card Standard's Tests section (`02_UNIFIED_CONTENT_CARD_STANDARD.md`).

---

## HOME-03 — Home's own filter/preference reads bypass `PreferencesStore`, duplicating the source of truth via raw `UserDefaults` keys

- **Screen/component:** `HomeViewModel.fetchPage(page:)` (lines 161–172)
- **Severity:** P2
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** `HomeViewModel.fetchPage` reads `UserDefaults.standard.object(forKey: "feed.showForums")`, `"feed.showPodcasts"`, `"feed.showApps"`, `"feed.showGuides"`, `"feed.showBlogs"`, `"feed.appleOnly"`, and `"forums.defaultFilter"` directly, with an inline comment explicitly justifying this: *"Read preferences from UserDefaults directly to avoid environment dependency."* Meanweile `CustomizeHomeView` (same file, lines 417–445) reads/writes the same logical settings through `@EnvironmentObject private var preferences: PreferencesStore` (`$preferences.showForums`, etc.) — i.e., the same settings have two different access paths (raw `UserDefaults` string keys in one place, a typed `PreferencesStore` object in another) that must be kept in sync by hand (the raw string keys in `fetchPage` must exactly match whatever key `PreferencesStore`'s `@AppStorage`/backing implementation uses for `showForums`, etc. — this was not independently verified against `PreferencesStore.swift`, which is audited separately in the engineering doc).
- **Current behavior:** Works as long as the two key sets never drift, but there is no compiler-enforced link between them — a future rename of a `PreferencesStore` property (and its backing `@AppStorage` key) would silently break `HomeViewModel.fetchPage`'s filtering with no compile error, only a runtime behavior change (Home would silently stop respecting the toggle).
- **Recommended behavior:** Have `HomeViewModel` read through `PreferencesStore` like every other consumer, or if there's a genuine architectural reason to avoid the `@EnvironmentObject` dependency inside a non-view `ObservableObject`, inject `PreferencesStore.shared` (or an equivalent singleton access path, consistent with how `PersistenceStore.shared` is already used elsewhere in the same function) rather than re-deriving the same values from raw string keys.
- **Exact reason:** A single, un-typed source of truth prevents this exact class of silent drift; "avoid environment dependency" is a reasonable instinct inside a `@MainActor` model class that isn't a View, but the fix should be dependency injection of the typed store, not bypassing it with hand-duplicated string keys.
- **Suggested implementation approach:** Check whether `PreferencesStore` is itself a `@MainActor` singleton with a `.shared` accessor (worth confirming in the engineering pass); if so, have `HomeViewModel.fetchPage` call `PreferencesStore.shared.showForums` etc. directly instead of `UserDefaults.standard.object(forKey: "feed.showForums")`.
- **Manual verification required:** No.
- **Regression tests required:** Yes — a unit test toggling a `PreferencesStore` content-type flag and asserting `HomeViewModel.fetchPage` respects it would have caught this class of drift immediately, and is a reasonable low-cost regression test to add regardless of which fix is chosen.

---

## HOME-04 — "Detailed" welcome announcement mode calls an AI summarization service with no visible loading state and only a bare fallback

- **Screen/component:** `HomeView.announceWelcomeIfNeeded()` (lines 151–163)
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** When `preferences.homeStartupBehavior == .detailed`, the code launches `Task { let digest = await IntelligenceService.generateDigest(rawSummary); UIAccessibility.post(...) }` — the announcement is posted only once the AI call resolves (success or fallback to raw summary), with no interim "generating summary" state and no user-visible indication that a network/on-device-AI call is happening at all before the welcome announcement fires. If `generateDigest` is slow, a VoiceOver user gets no announcement at all for a period after Home finishes loading, which can read as if the feature silently did nothing (echoing the exact "call site never actually reached" failure class this same comment says was already found and fixed once for this feature: *"IntelligenceService.generateDigest existed but was never called anywhere."*).
- **Current behavior:** Silent gap between Home load completing and the (now-working) detailed announcement firing, bounded only by however long `generateDigest` takes.
- **Recommended behavior:** Either post the plain/raw-summary announcement immediately and follow up with a second, clearly-differentiated announcement if/when the AI digest resolves noticeably later (avoiding total silence in the interim), or add an explicit timeout so "Detailed" mode never waits more than e.g. 1–2 seconds before falling back to the raw summary it already has on hand.
- **Exact reason:** A silent multi-second gap right after Home loads is easy to misread as "nothing happened," especially for a user who has just chosen the more verbose "Detailed" welcome mode specifically because they want more information sooner, not later.
- **Suggested implementation approach:** Wrap the `IntelligenceService.generateDigest` call in `withTimeout`-style logic (e.g., `Task.sleep` racing against the digest task via `TaskGroup`) capped at a short duration, falling back to `rawSummary` if it doesn't resolve in time; this reuses the same fallback path that already exists for outright failure.
- **Manual verification required:** Yes — confirm with VoiceOver on a slow/throttled network that the welcome announcement still arrives promptly.
- **Regression tests required:** Yes — a unit test asserting `announceWelcomeIfNeeded`'s underlying digest-or-fallback logic resolves within a bounded time (using a fake slow `IntelligenceService` implementation) would catch a regression here.

---

## HOME-05 — Offline/degraded-source banners are three visually similar but structurally different banner types, evaluated in a specific hardcoded order

- **Screen/component:** `HomeView.feedList` (lines 268–280): `OfflineBanner`, `SourceErrorBanner`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Two different banner components can appear stacked in the same list: `OfflineBanner()` (shown when `!networkMonitor.isConnected || isAnySourceDegraded`) and `SourceErrorBanner` (shown when `!vm.failedSourceNames.isEmpty`). These are structurally distinct types (`OfflineBanner` defined in `Views/Shared/OfflineBanner.swift`, not reviewed in this pass; `SourceErrorBanner` defined locally in `HomeView.swift` lines 453–480) that can both render at once for overlapping-but-not-identical conditions (a single degraded source can trigger the offline-style banner via `isAnySourceDegraded` AND, if that source's fetch actually threw, also populate `failedSourceNames` and trigger `SourceErrorBanner` — meaning a user could see two banners about what is functionally the same one broken source, worded differently, stacked back-to-back).
- **Current behavior:** Plausible in the "partially degraded API" edge case explicitly called out in the audit package's edge-case matrix. Not confirmed to reproduce without a live degraded-source scenario, but the two trigger conditions are not mutually exclusive by construction (`isAnySourceDegraded` reads `NetworkStatusStore.degradedGroups`; `failedSourceNames` reads `HomeViewModel`'s own per-load failure tracking) so they can plausibly both be true simultaneously for the same underlying cause.
- **Recommended behavior:** Unify these into one banner concept with one severity/wording per distinct cause, or explicitly de-duplicate: if `isAnySourceDegraded` is already true for a group whose name also appears in `failedSourceNames`, suppress the more generic `OfflineBanner` in favor of the more specific `SourceErrorBanner` (which already names the failed sources), rather than risking both firing for the same root cause.
- **Exact reason:** Two banners describing the same underlying problem in different words adds VoiceOver swipe stops and cognitive load right at the top of Home's list — exactly what the audit package's "calm activity inbox, not a dashboard crowded with controls" recommendation warns against.
- **Suggested implementation approach:** Add a small reconciliation step before rendering: if `failedSourceNames` is non-empty, skip `OfflineBanner` and rely on `SourceErrorBanner` alone (it's the more specific, more actionable of the two — it names sources and offers Retry); fall back to `OfflineBanner` only when `!networkMonitor.isConnected` is the actual cause (a true connectivity loss, not a partial API failure).
- **Manual verification required:** Yes — needs a live or simulated partial-API-failure scenario to visually confirm the current double-banner risk and the fix.
- **Regression tests required:** Yes — a `HomeViewModel`/`NetworkStatusStore` fixture test asserting only one banner-condition is true for a given simulated failure would be a reasonable regression guard, though it depends on `OfflineBanner`/`NetworkStatusStore` internals not reviewed in this pass.

---

## HOME-06 — `ForumTopic.isUnread` dead field affects Home's `unreadIndicator` dot (see CARD-05)

- **Screen/component:** `FeedRow` — `.unreadIndicator(item.isUnread)` (`HomeView.swift` line 605)
- **Severity:** P2
- **Category:** BUG
- **Evidence/current/recommended/reason/approach:** Full detail filed as CARD-05 in `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` (cross-app because the same dead field affects any future non-Home consumer of `ForumTopic.isUnread`/`FeedItem.isUnread`). Recorded here because Home is the only screen that currently visually renders this indicator at all.
- **Manual verification required:** No for the fix; yes for confirming the dot appears correctly afterward.
- **Regression tests required:** Yes (see CARD-05).

---

## HOME-07 — Home Feed Filter segmented control announcement duplicates information already in the immediately-following section header

- **Screen/component:** `HomeView.feedList`, `Picker("Home Feed", ...)` `.onChange` handler (lines 329–335) and the section header immediately below it (lines 343–365)
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Switching the All/New segmented picker posts an explicit announcement: `"\(vm.newItems.count) new activity item(s)."` or `"Showing all Home activity."` (line 331–334). Immediately below, in the same list, a section header renders `"New Activity"`/`"Latest Activity"` as visible + `.isHeader`-tagged text (lines 344–349), and further down each row itself speaks its own new/saved/following state per `detailLevelLabel`. A VoiceOver user who changes the segmented control hears the announcement, then — continuing to swipe forward, as is the natural next gesture — immediately re-encounters closely related information (the section header, then per-row "new" state) a few swipes later.
- **Current behavior:** Not a hard duplicate (the announcement gives a count; the header gives a label; rows give per-item detail) but borders on redundant given how close together these three pieces of information land for someone continuing to swipe forward, which the audit package's Announcements classification ("required / useful / redundant / interruptive") specifically asks reviewers to judge.
- **Recommended behavior:** Consider whether the `.onChange` announcement is necessary at all given VoiceOver already re-reads the Picker's own updated selection state as part of the interaction, and the section header a few elements later already communicates which mode is active — if kept, keep it brief and complementary (e.g., just the count, letting the header supply the "New"/"Latest" framing) rather than restating both the mode and a near-duplicate of the header text.
- **Exact reason:** Every additional announcement is a small tax on scanning speed for a screen the audit package explicitly wants to feel calm rather than crowded with controls; this is a borderline case worth a deliberate decision rather than an accident of incremental feature addition.
- **Suggested implementation approach:** A/B this manually with VoiceOver on: try removing the `.onChange` announcement entirely (relying on the Picker's own selection-change speech plus the header a few swipes later) and judge whether anything useful is actually lost.
- **Manual verification required:** Yes — this is a judgment call that needs an actual VoiceOver listen-through, not a code-level fix.
- **Regression tests required:** No.

---

## HOME-08 — Positive pattern: partial-source-failure handling keeps already-successful content visible (PASS)

- **Screen/component:** `HomeViewModel.fetchSource(name:_:)` (lines 153–159), `load()` (lines 61–68)
- **Severity:** n/a
- **Category:** PASS
- **Evidence:** Each of the five Home sources (Forums/Podcasts/Apps/Guides/Blogs) is fetched in isolation via `fetchSource`, with an explicit code comment explaining that a naive `try await (a, b, c, d, e)` tuple of `async let`s would let one failing source discard every other already-succeeded result — the actual implementation avoids that by catching per-source and only recording a `failedName`. On a later refresh, `load()` explicitly leaves existing on-screen content alone rather than blanking it when a total failure occurs (lines 61–68), showing only the failure banner.
- **Current behavior:** Correct and well-reasoned; exactly matches the audit package's "partial-source failure" and "cache fallback" requirements from the engineering audit dimensions.
- **Recommended behavior:** No change — good reference implementation to point to when auditing other multi-source screens (e.g., Discover, Search) for the same resilience pattern.
- **Manual verification required:** No.
- **Regression tests required:** Already a good target for a unit test (mock one of five sources failing, assert the other four still populate `items` and `failedSourceNames` contains only the failing one) if not already covered — flag as a TEST GAP if the Engineering findings confirm no such test exists today.

---

## HOME-09 — Home is a single flat `List`; no evidence of Home-specific pagination limits beyond the shared 20-item page size, and "New" segment has no pagination

- **Screen/component:** `HomeViewModel` (`pageSize = 20`, `hasMore`, `loadMore()`), `HomeView.feedList` (lines 376–386)
- **Severity:** P3
- **Category:** IMPROVEMENT
- **Evidence:** `HomeView.feedList`'s pagination trigger (`ProgressView().task { await vm.loadMore() }`, lines 376–380) is gated `vm.hasMore && homeFeedFilter == .all` — the "New" segment (`homeFeedFilter == .new`) never triggers `loadMore()`, so `visibleItems` when filtered to New is always drawn from whatever's already in `vm.items` (up to however many pages have been loaded for "All"). If a user switches to "New" before scrolling far enough in "All" to trigger additional pages, they may see a truncated view of what's actually new (new items from page 3+ wouldn't be loaded yet), with no visual indication that "New" might be incomplete.
- **Current behavior:** Silently caps "New" to whatever's already been paged in via "All" browsing.
- **Recommended behavior:** Either page independently for the "New" filter (fetch until no more "new" items are found or a reasonable cap is hit), or make the incompleteness explicit (e.g., "New" section shows a "Load more" affordance too, sourced from continuing to paginate the underlying `items` list even while filtered).
- **Exact reason:** A user who trusts "New" to be a complete picture of everything since their last visit could reasonably miss real new content purely because they hadn't scrolled far enough in the "All" tab first — this directly undermines Home's stated mission ("what happened since I was last here?").
- **Suggested implementation approach:** Allow `loadMore()` to trigger regardless of `homeFeedFilter`, keyed off `vm.hasMore` alone, so continuing to scroll in "New" (once `visibleItems` runs out) still fetches further pages and re-filters.
- **Manual verification required:** Yes — needs an account/fixture with more than 20 items of new activity across sources to observe directly.
- **Regression tests required:** Yes — a `HomeViewModel` test with a fake multi-page data source asserting `newItems` continues to grow as `loadMore()` is called while filtered to "New."

---

## Home summary

Home is well-architected for resilience (HOME-08) and has clearly already been through multiple rounds of real bug-driven hardening (the "New" vs `newCount` fix, the digest-never-called fix, the deduplication-by-id fix visible in `HomeViewModel.deduplicated`). The remaining issues are less about missing features and more about **consolidating parallel/duplicated logic** (HOME-02, HOME-03, HOME-05, CARD-12) before it drifts further, plus one real completeness gap in "New" pagination (HOME-09) and the app-wide dead-field/context-menu issues that also surface here (HOME-06/CARD-05, CARD-01).
