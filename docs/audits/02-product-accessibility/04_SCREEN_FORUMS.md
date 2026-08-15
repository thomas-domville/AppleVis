# Screen Audit — Forums

Mission: "Forums should feel like AppleVis.com but optimized for native iOS"
(`APPLEVIS_2026_1_MASTER_SPEC.md`). Six required filters: Recent, New, Unread,
Since Last Visit, Following, Saved.

Evidence files: `Sources/Views/Forums/ForumsBrowseView.swift`,
`ForumTopicDetailView.swift`, `ComposeTopicView.swift` (incl. `ComposeReplyView`),
`Sources/Models/Forum.swift`, `Sources/Views/Shared/RowViews.swift`
(`ForumTopicRow`), `Sources/Views/Shared/ContentActions.swift`,
`Sources/Views/Shared/CommunityDiscussionHeading.swift`,
`Sources/Stores/KeyCommandRouter.swift`, `Sources/App/AppleVisApp.swift`,
`Sources/App/ContentView.swift`, `Sources/Networking/Mappers.swift`,
`Sources/Stores/PersistenceStore.swift`. Card/action-system duplication
findings (CARD-01–03) apply here too and are only cross-referenced, not
repeated in full.

---

## FORUM-01 — Filter sheet re-stamps `forumsLastVisit` on every load, making "New" and "Since Last Visit" almost always empty after the first visit

- **Screen/component:** `ForumsBrowseView.load(reset:)`
- **Severity:** P1
- **Category:** BUG
- **Evidence:** `Sources/Views/Forums/ForumsBrowseView.swift` lines 232–247 (`PersistenceStore.shared.markForumsVisited()` called at line 243, unconditionally, at the end of every successful load); `Sources/Stores/PersistenceStore.swift` lines 119–125 (`markForumsVisited()`); `Sources/Models/Forum.swift` lines 59–73 (`ForumFilter.apply` — `.new` and `.sinceLastVisit` both filter against `PersistenceStore.shared.forumsLastVisit`).
- **Current behavior:** `load(reset:)` stamps `forumsLastVisit = now` at the end of every successful load — the initial `.task`, every pull-to-refresh, and every filter-sheet dismissal. Selecting "New" or "Since Last Visit" in the filter sheet triggers a reload, which immediately re-stamps `lastVisit` to the moment of *that* reload, before the user has actually read anything — so both filters end up comparing against a timestamp that is always "now," making them almost always empty right after the very load that's supposed to show their contents.
- **Recommended behavior:** Snapshot `forumsLastVisit` once on screen entry (or once per genuine "visit," not per reload) and use that snapshot for filtering; only advance the persisted timestamp on a real visit boundary (leaving the screen, backgrounding, or after a dwell period), not inside every `load(reset:)` call.
- **Exact reason:** This silently breaks 2 of the 6 required Forums filters listed explicitly in the master spec — "New: newly created topics" and "Since Last Visit: all forum changes since the user's last visit" are core, spec-mandated features that are effectively non-functional as implemented.
- **Suggested implementation approach:** Read `forumsLastVisit` into a local `let` at the start of the screen's session (e.g. in `.onAppear`/`.task`, guarded so it only captures once per genuine visit) and pass that captured value through to `ForumFilter.apply`, decoupling it from `load(reset:)`'s own stamping. Move the actual `markForumsVisited()` call to a true end-of-visit signal (e.g. `.onDisappear` from the Forums tab root, or app background).
- **Manual verification required:** Yes — visit Forums, select New or Since Last Visit, confirm topics that should qualify are actually shown, then verify the boundary correctly advances only on an actual visit end.
- **Regression tests required:** Yes — a `ForumFilter.apply` unit test with a fixed `lastVisit` fixture and topics straddling that boundary, decoupled from any reload-triggered mutation.

---

## FORUM-02 — Client-side-filtered empty page doesn't keep paginating even when more pages exist, silently breaking 3 of 6 filters

- **Screen/component:** `ForumsBrowseView` list/pagination
- **Severity:** P1
- **Category:** BUG
- **Evidence:** `Sources/Views/Forums/ForumsBrowseView.swift` lines 138–146 (empty-state branch has no retry action), lines 187–204 (`topicList` — the only place the auto-loading `ProgressView().task { await loadMore() }` trigger lives), lines 242/264 (`hasMore` computed from the raw, unfiltered page size returned by the API, not from the filtered result count).
- **Current behavior:** Forums' Unread/New/Since Last Visit filters are applied client-side (per `Forum.swift`'s `ForumFilter.apply`) to a page fetched from a filter-agnostic "recent" endpoint. If a fetched page happens to filter down to zero matching topics, the view renders the `EmptyStateView` branch — which has no retry action and, critically, is not inside `topicList`, so the auto-pagination trigger (`.task { await loadMore() }`) never runs even though `hasMore` is still `true` and a later page might contain matches.
- **Recommended behavior:** When a filter (Unread/New/Since Last Visit) produces zero visible results but `hasMore` is true, either keep auto-loading additional pages until a non-empty filtered result or the true end of data is reached, or give the empty state itself a "Load more" / retry affordance that continues pagination rather than presenting a dead end.
- **Exact reason:** This silently breaks the same 3 of 6 required Forums filters whenever page 1 (or any early page) happens to have no matches — a very plausible scenario for "Unread" once a user has read most current activity, or "New" outside of a burst of posting activity. The user has no way to know more content might exist further down.
- **Suggested implementation approach:** Restructure the pagination trigger to live outside the filtered-empty/non-empty branch (e.g. attach it to the screen generally, gated on `hasMore`, rather than only inside `topicList`'s rendered rows), or add explicit continued-fetch logic when `filteredTopics.isEmpty && hasMore`.
- **Manual verification required:** Yes — construct or find a scenario where the first fetched page has zero matches for a given filter but later pages do, and confirm the fix surfaces them.
- **Regression tests required:** Yes — a `ForumsBrowseView`/view-model-level test (if the loading logic is extracted testably) asserting that a filtered-to-zero page with `hasMore == true` continues fetching automatically.

---

## FORUM-03 — Own-topic-owner AND admin at once produces literal duplicate "Edit Topic"/"Delete Topic" VoiceOver actions

- **Screen/component:** `ContentActionsModifier` via `ForumTopicRow`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Shared/ContentActions.swift` lines 79–82 (`isOwnTopic`), lines 163–181 (owner block: "Edit Topic"/"Delete Topic" in the context menu), lines 186–190 (owner block: same two as explicit `.accessibilityAction`s) — both unconditional given `isOwnTopic`, run alongside the separate admin block (also unconditional given `isAdmin`) which produces "Edit \(kind.displayName)"/"Unpublish \(kind.displayName)"/"Delete \(kind.displayName)"; since `ContentKind.forumTopic.displayName == "Topic"` (`Sources/Models/User.swift` line 56), the admin block's "Edit Topic"/"Delete Topic" text is textually identical to the owner block's.
- **Current behavior:** When a user is both the topic's author and an admin (a realistic case — moderators post their own topics), both blocks render, producing VoiceOver actions "Edit Topic" ×2 and "Delete Topic" ×2 in the Actions rotor — indistinguishable duplicates with the same spoken name and the same effect, which the rotor gives the user no way to tell apart.
- **Recommended behavior:** Gate the owner-specific action pair on `isOwnTopic && !isAdmin` (letting the admin block, which is a superset — it also adds Unpublish — take over whenever both are true), or merge the two into a single set of actions computed once regardless of which permission granted them.
- **Exact reason:** This is a concrete, reproducible instance of the exact "one operation, one accessibility representation" violation the audit package's north-star rules call out, distinct from (but compounding) the app-wide context-menu duplication in CARD-01.
- **Suggested implementation approach:** Change the two `isOwnTopic`-gated blocks' conditions (both the context-menu items at lines 163–170 and the `.accessibilityAction`/`ConditionalAccessibilityAction` calls at lines 186–187) to `isOwnTopic && !isAdmin`.
- **Manual verification required:** Yes — test with a fixture/account that is both the topic author and an admin, confirming only one Edit and one Delete action appear.
- **Regression tests required:** Yes — extend the CARD-01 action-de-duplication test to include the owner+admin permutation specifically.

---

## FORUM-04 — Owner/admin moderation actions exist only on the browse-list row, never on the topic detail screen itself

- **Screen/component:** `ForumTopicDetailView.bottomActionBar`
- **Severity:** P2
- **Category:** UX INCONSISTENCY / ARCHITECTURE ISSUE
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 430–466: the bottom action bar offers only Follow/Save/Share/Browser/Reply — there is no `.contentActions(...)` or `ContentDetailActions` call anywhere in this file (confirmed by inspection).
- **Current behavior:** Edit/Delete/Unpublish (both owner and admin variants) exist only on `ForumTopicRow` in the browse list. A moderator or topic owner reading the full topic on its own detail screen has no way to edit, unpublish, or delete it without navigating back to the list first.
- **Recommended behavior:** Surface the same owner/admin actions on the detail screen — either by wiring `ContentActionsModifier`'s underlying logic into the detail bar, or by adding equivalent explicit actions to `ForumTopicDetailView`'s own bottom bar.
- **Exact reason:** The detail screen is the natural place a moderator would decide to act on a topic after actually reading it in full; requiring a trip back to a list (which may have since scrolled/reordered) to perform a moderation action is an avoidable detour.
- **Suggested implementation approach:** Extend `ForumTopicDetailView`'s bottom bar to include Edit/Unpublish/Delete (owner/admin-gated, same logic as `ContentActionsModifier`), ideally by factoring the shared logic so both surfaces stay in sync rather than maintaining two independent implementations.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes, once implemented.

---

## FORUM-05 — Long threads are fully fetched and eagerly rendered in a plain `VStack`, not lazily — performance and VoiceOver-scan cost scales with total reply count

- **Screen/component:** `ForumTopicDetailView.topicContent`
- **Severity:** P1
- **Category:** PERFORMANCE ISSUE
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 75–77 (plain `VStack` inside a `ScrollView`, not `LazyVStack`/`List`); lines 382–395 and 336–338 (`loadMoreReplies()` auto-fetches every remaining page in a `while` loop, with no manual "load more" gate).
- **Current behavior:** Long threads (this forum commonly has threads with hundreds of replies) are fully fetched and fully rendered eagerly — every `ReplyView` (which itself carries 7 accessibility actions, a context menu, and 2 sheets per instance) is constructed at once regardless of scroll position. This blocks the main thread during construction, increases memory pressure, and slows VoiceOver's element-tree walk of the screen — directly hurting exactly the users most sensitive to jank and slow response.
- **Recommended behavior:** Switch the reply list to `LazyVStack` (or a `List`), so off-screen replies aren't constructed until scrolled near; consider reintroducing a manual "Load More" affordance past a reply-count threshold instead of auto-fetching every remaining page unconditionally.
- **Exact reason:** Performance is explicitly named as an accessibility concern in the audit package's north-star rules ("Performance is accessibility"); a screen that becomes sluggish specifically on the app's most content-rich threads is a direct hit to the core forum-reading experience.
- **Suggested implementation approach:** Replace `VStack` with `LazyVStack` inside the existing `ScrollView` (minimal change if row heights don't need to be known in advance); separately, cap `loadMoreReplies()`'s automatic fetch-everything loop behind a size or count threshold, falling back to an explicit "Load More" button beyond it.
- **Manual verification required:** Yes — Instruments profiling plus a VoiceOver swipe-timing check on a 100+ reply thread, before and after the change.
- **Regression tests required:** Yes — a synthetic 200-reply layout/construction-time test to catch regressions.

---

## FORUM-06 — Visible/spoken reply count goes stale immediately after posting or deleting a reply

- **Screen/component:** `ForumTopicDetailView` (post/delete reply handlers), `CommunityDiscussionHeading`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 46–53, 54–61, and 136–137: `detail.replies` (the array) is mutated on post/delete, but `detail.replyCount` (the separate integer field driving `CommunityDiscussionHeading`'s spoken/visible count, per the "Community Discussion - 32 comments - 1 new" convention documented in `docs/IMPLEMENTATION_NOTES.md`) is never incremented or decremented alongside it.
- **Current behavior:** The heading's reported comment count is immediately stale after posting or deleting a reply, until the screen is fully reloaded.
- **Recommended behavior:** Update `replyCount` in lockstep with `replies` at all three mutation sites.
- **Exact reason:** A visibly/audibly wrong count right after the exact action that should update it (posting a reply) undermines trust in the number and directly contradicts `IMPLEMENTATION_NOTES.md`'s own stated convention for this heading.
- **Suggested implementation approach:** Increment/decrement `detail.replyCount` alongside each of the three `detail.replies` mutations.
- **Manual verification required:** No — directly observable from code and a quick manual check.
- **Regression tests required:** Yes — a unit test asserting `replyCount` tracks `replies.count` (or the appropriate delta) after post/delete.

---

## FORUM-07 — "Edit Comment"/"Delete Comment" (VoiceOver) vs. "Edit Reply"/"Delete Reply" (context menu) name the same action differently for sighted vs. VoiceOver users

- **Screen/component:** `ForumTopicDetailView` reply actions
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 524–534 (VoiceOver: "Edit Comment"/"Delete Comment") vs. lines 567–573 (context menu: "Edit Reply"/"Delete Reply") — same action, same view, different wording depending on which surface (rotor vs. visible menu) is read.
- **Current behavior:** Inconsistent terminology for the identical operation.
- **Recommended behavior:** Standardize on "Comment," which is the term used everywhere else on this screen (e.g. the "Community Discussion" heading convention itself, and `ContentActionsModifier`'s generic "Add New Comment" wording).
- **Exact reason:** Consistent terminology reduces cognitive load when switching between visual and VoiceOver interaction, and matches the Unified Card Standard's explicit "the same semantic operation should use the same wording everywhere" rule.
- **Suggested implementation approach:** Change the two "Reply" strings to "Comment" at lines 567–573.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## FORUM-08 — `ForumReply.isNew`/`loveCount` are permanently stubbed to `false`/`0`, feeding dead UI

- **Screen/component:** `Mappers.swift` reply mapping, `ForumTopicDetailView` reply rendering
- **Severity:** P3
- **Category:** BUG (dead code)
- **Evidence:** `Sources/Networking/Mappers.swift` lines 124–141 hardcode `loveCount: 0, isNew: false` on every reply-mapping path; consumed by UI that can never actually trigger in `ForumTopicDetailView.swift` lines 506, 537–541, 545.
- **Current behavior:** Identical pattern to the app-wide `ForumTopic.isUnread` dead field (see CARD-05 / FORUM-20 below) — a field and its dependent UI exist and look functional but can never actually fire.
- **Recommended behavior:** Either wire `isNew` to the same last-visit comparison already used elsewhere in the app (`PersistenceStore`), so individual new replies within a thread can be visually/verbally distinguished, or delete the unreachable UI and the dead field together.
- **Exact reason:** Same rationale as CARD-05 — dead-but-plausible-looking fields invite future confusion and represent silent, unfulfilled feature scope.
- **Suggested implementation approach:** If reviving: compute `isNew` per-reply against the topic's last-visited timestamp/comment-count baseline at mapping time. If retiring: remove the field and its dependent rendering branches.
- **Manual verification required:** No.
- **Regression tests required:** Yes, once a direction is chosen.

---

## FORUM-09 — Topic detail heading doesn't show "N new" even though the exact same computation already exists one screen away

- **Screen/component:** `CommunityDiscussionHeading` as used on `ForumTopicDetailView`
- **Severity:** P3
- **Category:** IMPROVEMENT
- **Evidence:** `Sources/Views/Shared/CommunityDiscussionHeading.swift` line 66 has no new-count segment, while `PersistenceStore.newReplyCount` — computing exactly this figure for exactly this topic id — is already used one screen away on `ForumTopicRow` in the browse list.
- **Current behavior:** The detail screen's heading omits information the browse list already successfully surfaces for the same topic.
- **Recommended behavior:** Pass the same computed `newReplyCount` value into the detail heading, consistent with `IMPLEMENTATION_NOTES.md`'s own stated convention ("Community Discussion - 32 comments - 1 new").
- **Exact reason:** Consistency between list and detail views for the same underlying data; the computation already exists, so this is a low-cost wiring gap, not new logic.
- **Suggested implementation approach:** Thread `PersistenceStore.shared.newReplyCount(kind: .forumTopic, id: topicId, currentCount:)` into `CommunityDiscussionHeading`'s call site on the detail screen.
- **Manual verification required:** No.
- **Regression tests required:** No.

---

## FORUM-10 — "COMMUNITY DISCUSSION" section label uses a fixed-size font and `.fixedSize()`, ignoring Dynamic Type

- **Screen/component:** `CommunityDiscussionHeading`
- **Severity:** P2
- **Category:** VISUAL-LOW-VISION ISSUE
- **Evidence:** `Sources/Views/Shared/CommunityDiscussionHeading.swift` lines 56–63: fixed 13pt `.font(.system(size: 13, ...))` combined with `.fixedSize()`, not a scalable semantic text style.
- **Current behavior:** This label will not grow at larger accessibility Dynamic Type sizes, and `.fixedSize()` additionally prevents it from wrapping if it somehow did need more room — a double lock-in against accessibility text scaling.
- **Recommended behavior:** Use a scalable semantic style (e.g. `.caption.weight(.bold)`) and drop `.fixedSize()`.
- **Exact reason:** Same class of issue as CARD-11 (fixed-point fonts bypassing Dynamic Type), specific instance on a heading that is one of the first things read when entering a topic's comment section.
- **Suggested implementation approach:** Replace the font modifier and remove `.fixedSize()`.
- **Manual verification required:** Yes — visual check at largest accessibility text sizes.
- **Regression tests required:** No.

---

## FORUM-11 — No VoiceOver refocus after deleting a reply

- **Screen/component:** `ForumTopicDetailView` delete-reply handler
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 136–137 and 615–624: no `@AccessibilityFocusState` assignment after a reply is deleted, unlike the well-handled post-reply flow (lines 169–182), which the same file already documents the rationale for (scroll + focus the new reply, Reduce-Motion-aware).
- **Current behavior:** After deleting a reply, VoiceOver focus is left wherever the system default lands it (often an unrelated or unpredictable element), rather than a deliberately chosen stable neighbor.
- **Recommended behavior:** Focus a stable neighbor (the previous reply, or the discussion heading if none) and post an announcement ("Reply deleted") after a successful delete — mirroring the existing, well-reasoned post-reply focus pattern in the same file.
- **Exact reason:** Deletion is exactly the kind of destructive-then-list-mutating action the audit package's Focus test checklist calls out by name ("deletion") as needing explicit verification and handling.
- **Suggested implementation approach:** Reuse the same `@AccessibilityFocusState`/scroll pattern already implemented for post-reply, targeted at a neighbor reply id (or the heading) instead of the newly-created reply id.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes.

---

## FORUM-12 — No VoiceOver refocus after deleting a topic from the browse list

- **Screen/component:** `ForumsBrowseView`
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Forums/ForumsBrowseView.swift` lines 193–196: the row is removed from the list with no focus redirect.
- **Current behavior:** Same class of gap as FORUM-11, one screen over — deleting a topic from the list leaves VoiceOver focus wherever the system default lands it.
- **Recommended behavior:** Reuse the existing `focusedTopicId` state (already present in this file for other purposes) to focus the neighboring row after a delete.
- **Exact reason:** Same as FORUM-11.
- **Suggested implementation approach:** Set `focusedTopicId` to the neighboring topic's id immediately after removing the deleted row from the array.
- **Manual verification required:** Yes.
- **Regression tests required:** No (covered adequately by manual verification given the existing state variable already being exercised elsewhere).

---

## FORUM-13 — Compose Topic/Reply `TextEditor`s have no accessibility label; VoiceOver announces bare "Text View"

- **Screen/component:** `ComposeTopicView`, `ComposeReplyView`
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Forums/ComposeTopicView.swift` lines 73–84 and `ComposeReplyView` lines 229–238: no `.accessibilityLabel` on either `TextEditor`.
- **Current behavior:** VoiceOver announces an unlabeled "Text View," particularly noticeable when jumping directly to it via the rotor's "Text Fields" category.
- **Recommended behavior:** Add explicit labels ("Topic body" / "Reply text").
- **Exact reason:** Unlabeled multiline text-entry fields are a basic, easily-avoided VoiceOver gap, and compose/reply is one of the highest-value interactions on this screen.
- **Suggested implementation approach:** Add `.accessibilityLabel(...)` to both `TextEditor`s.
- **Manual verification required:** Yes.
- **Regression tests required:** No.

---

## FORUM-14 — No list-position persistence by content ID for Forums, contradicting an explicit spec requirement

- **Screen/component:** `ForumsBrowseView`, `PersistenceStore`
- **Severity:** P2
- **Category:** IMPROVEMENT
- **Evidence:** No scroll/content-ID restoration logic found anywhere in `ForumsBrowseView.swift` or `PersistenceStore.swift`. `APPLEVIS_2026_1_MASTER_SPEC.md`'s Forums section explicitly requires: *"The app must remember forum list position by content ID, not only by scroll offset. New activity may reorder the list, but Resume Where You Left Off should restore the relevant item."*
- **Current behavior:** No such restoration exists for Forums specifically (Home has its own separate, unrelated focus-restoration logic — see HOME-01/CARD-12 — but that doesn't cover the Forums tab's own browse list).
- **Recommended behavior:** Persist `(active filter, last-viewed topic id)` and scroll/focus to that topic id on return to the Forums tab, tolerating the fact that new activity may have reordered the list around it.
- **Exact reason:** This is an explicit, named requirement in the master spec, not a general best-practice suggestion — its absence is a direct spec gap.
- **Suggested implementation approach:** Add a small persisted value (e.g. in `PersistenceStore`) tracking the last-viewed topic id per filter; on Forums tab appearance, scroll/focus to it if still present in the loaded list.
- **Manual verification required:** Yes.
- **Regression tests required:** Yes.

---

## FORUM-15 — No Forums-specific hardware-keyboard shortcut; Forums isn't directly reachable from the app's Go menu

- **Screen/component:** `KeyCommandRouter`, `AppleVisApp`'s `CommandMenu("Go")`, `ContentView`'s tab structure
- **Severity:** P2
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Stores/KeyCommandRouter.swift` lines 1–15; `Sources/App/AppleVisApp.swift` lines 116–129 (`CommandMenu("Go")` includes Home/Discover/For You/Refresh/Settings, nothing for Forums); `Sources/App/ContentView.swift` lines 14–27 (3-tab structure; Forums is nested inside Discover, not a top-level destination). The master spec requires full keyboard navigation/shortcuts on iPad.
- **Current behavior:** No direct keyboard shortcut reaches Forums; a keyboard-only/iPad user must navigate through Discover first.
- **Recommended behavior:** Add a `CommandMenu` entry that deep-links directly to Forums, at minimum matching the other top-level destinations already present in the Go menu.
- **Exact reason:** Hardware keyboard support is an explicit required audit dimension, and Forums is one of the app's primary content areas — its absence from the Go menu is inconsistent with the other four peers that are present.
- **Suggested implementation approach:** Add a `Button("Forums") { ... }.keyboardShortcut(...)` entry to the existing `CommandMenu("Go")`, wired through the same deep-link mechanism as the existing entries.
- **Manual verification required:** Yes — physical/Sidecar keyboard and iPad pass.
- **Regression tests required:** No.

---

## FORUM-16 — Detail-screen bottom action bar order diverges from the proposed canonical ordering

- **Screen/component:** `ForumTopicDetailView.bottomActionBar`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 430–462: order is Follow, Save, Share, Browser, Reply. The proposed canonical order (per `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` CARD-03) wants Save before Follow, and a content-specific primary action (Reply, in this case) placed earlier, closer to Follow.
- **Current behavior:** Follow-before-Save here, opposite of the row-level `ContentActionsModifier`'s order once CARD-03 is fixed; Reply is placed last rather than near the top.
- **Recommended behavior:** Reorder to Save, Follow, Reply, Share, Browser.
- **Exact reason:** Consistency between the browse-row actions and the detail-screen actions for the same content, per the cross-app ordering standard.
- **Suggested implementation approach:** Fold into the same pass that fixes CARD-03; reorder this bar's `HStack`/button construction accordingly.
- **Manual verification required:** Yes, as part of the CARD-03 verification pass.
- **Regression tests required:** Covered by the CARD-03 ordering test once written, extended to this bar.

---

## FORUM-17 — Shared row action-menu order diverges from the proposed canonical ordering (Forums-visible instance of CARD-03)

- **Screen/component:** `ContentActionsModifier` (as exercised via `ForumTopicRow`, the most-used content kind)
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Shared/ContentActions.swift` lines 131–182: "Add New Comment" appears before Save/Follow; "Open in Browser" appears before "Share." Proposed order: Mark as Read, Save/Unsave, Follow/Unfollow, Add Comment, Share, Browser, Edit/Unpublish/Delete.
- **Current behavior:** As described in CARD-03; this entry records Forums specifically as the highest-traffic content kind exercising this shared code, since Forums is likely to be the first place a reviewer notices the ordering issue in practice.
- **Recommended behavior:** See CARD-03 — this belongs in the shared `ContentActionsModifier`, not a Forums-specific fix, since it affects every content kind simultaneously.
- **Exact reason:** Same as CARD-03.
- **Suggested implementation approach:** Fold into the CARD-01/CARD-03 fix pass.
- **Manual verification required:** Yes, as part of that pass.
- **Regression tests required:** Covered by the CARD-03 test once written.

---

## FORUM-18 — No VoiceOver focus set when a filter change results in an empty list

- **Screen/component:** `ForumsBrowseView`
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Forums/ForumsBrowseView.swift` lines 170–179: an announcement fires on filter change, but there is no corresponding `else` branch setting VoiceOver focus to the empty-state title when `filteredTopics` is empty after the change.
- **Current behavior:** VoiceOver hears an announcement about the filter change but focus itself doesn't move to the resulting empty-state content, leaving the user's swipe cursor wherever it was before (likely the now-hidden filter control).
- **Recommended behavior:** Add an `@AccessibilityFocusState` binding for the empty-state title/message and set it when a filter change results in zero visible topics.
- **Exact reason:** Matches the general pattern already used successfully elsewhere in this file (`focusedTopicId`) and elsewhere in the app for state-transition focus management.
- **Suggested implementation approach:** Add a focus target for the empty state and assign it in the same code path that currently only posts the announcement.
- **Manual verification required:** Yes.
- **Regression tests required:** No.

---

## FORUM-19 — Unstructured background reply-fetch task isn't cancelled on navigate-away

- **Screen/component:** `ForumTopicDetailView.load()`
- **Severity:** P4
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** `Sources/Views/Forums/ForumTopicDetailView.swift` lines 336–338: an unstructured `Task {}` launched inside `load()`, with no cancellation wired to `.onDisappear`.
- **Current behavior:** If a user navigates away from a topic mid-fetch (e.g. a long thread still auto-paginating per FORUM-05), the in-flight task keeps running and can still mutate `@Published` state on a view model that's no longer visible, wasting network/CPU work and risking (low-probability but real) races if the same view model instance is reused.
- **Recommended behavior:** Store the task handle and cancel it in `.onDisappear` (or scope it via `.task` instead of a detached/unstructured `Task {}`, which SwiftUI cancels automatically on view disappearance).
- **Exact reason:** Matches the audit package's explicit concurrency dimension ("task lifetime after dismissal," "cancellation").
- **Suggested implementation approach:** Prefer converting this to a SwiftUI `.task` modifier scoped to the view's lifetime if feasible; otherwise store the `Task` handle in a `@State`/instance property and call `.cancel()` in `.onDisappear`.
- **Manual verification required:** No.
- **Regression tests required:** No practical automated test; low severity.

---

## FORUM-20 — `ForumTopic.isUnread` dead field (cross-reference to CARD-05) — informational only, the real Unread filter works correctly

- **Screen/component:** `Mappers.swift`, `Forum.swift`
- **Severity:** MANUAL VERIFY / informational
- **Category:** MANUAL VERIFY
- **Evidence:** `Sources/Networking/Mappers.swift` lines 45, 98 — `isUnread` is always `false` at construction. Flagged here specifically to record that the actual, functioning "Unread" filter does **not** depend on this dead field — it correctly uses a separate, working mechanism (`PersistenceStore.isTopicSeen`/`markTopicSeen`, exercised via `ForumFilter.apply`'s `.unread` case). Full detail and recommended fix already filed as CARD-05 in `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md`.
- **Current behavior:** Dead/misleading field, but not a functional break of the Unread filter itself.
- **Recommended behavior:** See CARD-05.
- **Exact reason:** Recorded here so a future reviewer auditing Forums specifically doesn't wrongly conclude the Unread filter itself is broken by this field — it isn't; the field is simply unused dead weight, and the only real consumer elsewhere in the app is Home's already-self-documented approximate `FeedItem.isUnread`.
- **Suggested implementation approach:** See CARD-05.
- **Manual verification required:** No (informational cross-reference).
- **Regression tests required:** See CARD-05.

---

## PASS findings

- **FORUM-P1 — PASS.** `ReplyView` correctly follows the two-accessibility-area rule from `docs/IMPLEMENTATION_NOTES.md`: an actionable header (author/date/subject/state/actions) separate from a readable body via `SegmentedHTMLView`.
- **FORUM-P2 — PASS.** Posting a reply correctly scrolls to and moves VoiceOver focus onto the new reply, and is Reduce-Motion-aware.
- **FORUM-P3 — PASS.** Both `ComposeTopicView` and `ComposeReplyView` correctly guard against silent data loss on Cancel by comparing against the initial state rather than plain emptiness (so re-opening a screen with pre-filled content and cancelling without changes doesn't spuriously warn).
- **FORUM-P4 — PASS.** `hasMoreReplies` is computed against the topic's real `replyCount`, not the requested page size — correctly handles server-side page-size clamping rather than assuming a full page always means more data exists.
- **FORUM-P5 — PASS.** `CommentSubject.display` correctly suppresses generic/duplicate Drupal subjects ("Reply," subjects that just repeat the parent title), matching `IMPLEMENTATION_NOTES.md`'s documented convention.
- **FORUM-P6 — PASS.** `loadMore()` only advances its internal `page` counter after a successful fetch — resilient to transient pagination failures (a failed page doesn't silently skip ahead).

---

## Forums summary

Forums has two P1 correctness bugs that quietly defeat 3 of the 6 required
filters (FORUM-01, FORUM-02) — these should be treated as release-blocking in
spirit even though they're not crashes, since "Unread"/"New"/"Since Last
Visit" not reliably showing their own contents is a core feature failure for
a forum-first app. FORUM-05 (unbounded eager thread rendering) is a real
performance risk on this specific forum's characteristically long threads.
The remaining findings are consistency/focus/wording gaps that echo the same
patterns found elsewhere in the app (dead `isUnread`-style fields, ordering
drift, missing post-action focus restoration) — Forums is a good sample of
how the app-wide `ContentActionsModifier` issues (CARD-01/03) manifest in
practice, plus a few genuinely Forums-specific structural bugs.
