# Screen Audit — Blogs

Evidence files: `Sources/Views/Blogs/BlogBrowseView.swift`,
`Sources/Views/Blogs/BlogDetailView.swift`, `Sources/Models/Blog.swift`,
`Sources/Views/Shared/RowViews.swift` (`BlogPostRow`).

Cross-screen findings shared with Apps/Guides/Bug Tracker (ALL-01 through
ALL-06) are filed in full in `06_SCREEN_APPS.md` and only cross-referenced
here.

---

## BLOGS-01 — No empty-state handling; a legitimately empty successful load renders a blank list

- **Screen/component:** `BlogBrowseView`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** No `posts.isEmpty` → `EmptyStateView` branch exists in `BlogBrowseView.swift`, unlike Apps and Guides, which both have this branch.
- **Current behavior:** If a successful load returns zero blog posts (e.g. a filter with no matches, or a genuinely empty category), the screen falls through to a blank `List` with no title, message, or retry affordance — indistinguishable from a silent failure.
- **Recommended behavior:** Add the same `EmptyStateView` branch Apps/Guides already use, with a clear title/message and, where applicable, a way to change filters.
- **Exact reason:** A blank screen with no explanation is one of the most disorienting states possible for a VoiceOver user — there's no visual "empty list" cue to fall back on the way a sighted user might infer from an obviously blank white area; it can easily read as "the app is broken" rather than "there's nothing here."
- **Suggested implementation approach:** Add the missing `posts.isEmpty` branch, reusing `EmptyStateView` exactly as Apps/Guides already do.
- **Manual verification required:** No — directly reproducible by filtering to an empty result set. **Regression tests required:** Yes.

---

## BLOGS-02 — `BlogPostRow` follows the unified card standard correctly (PASS)

- **Category:** PASS
- **Evidence:** `BlogPostRow` shares the same accent-bar/comment-count/saved/new-badge structure as every other content-kind row in `RowViews.swift` — a genuinely unified implementation, not a bespoke divergence.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BLOGS-03 — No post-comment focus confirmation (cross-reference to ALL-04)

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** Filed in full as ALL-04 in `06_SCREEN_APPS.md`; recorded here because Blogs was the screen where this was first observed. No `@AccessibilityFocusState` is set after posting a blog comment, unlike Forums' well-implemented equivalent.
- **Recommended behavior:** See ALL-04.
- **Manual verification required:** Yes. **Regression tests required:** Yes.

---

## BLOGS-04 — Long blog posts get no table of contents purely because of which screen they're on

- **Screen/component:** `BlogDetailView`'s `SegmentedHTMLView` call, vs. `ResourceDetailView`'s equivalent call
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `BlogDetailView`'s call to `SegmentedHTMLView` passes no `collapsedSegmentLimit`/`showTableOfContents` arguments, while the structurally identical `ResourceDetailView` call (see GUIDES-01) does pass both.
- **Current behavior:** A long blog post gets none of the navigation aids (visible jump-list, collapsed-by-default long content) that a long guide of similar length gets, purely as an artifact of which screen renders it, not any real content difference.
- **Recommended behavior:** Pass the same `collapsedSegmentLimit`/`showTableOfContents` parameters in `BlogDetailView` that `ResourceDetailView` already uses.
- **Exact reason:** Both screens render the same underlying `SegmentedHTMLView` component; there's no product reason a long blog post should read differently from a long guide of the same length.
- **Suggested implementation approach:** Align `BlogDetailView`'s `SegmentedHTMLView` call arguments with `ResourceDetailView`'s.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BLOGS-05 — Blogs uses the same shared `CommunityDiscussionHeading` as Apps/Guides/Bugs (PASS)

- **Category:** PASS
- **Evidence:** No structural divergence found; Blogs' comment section is built on the identical shared component used across all four content-kind screens.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Cross-screen findings

See `06_SCREEN_APPS.md`'s "Cross-screen findings" section for ALL-01 through
ALL-06, all of which apply identically to Blogs.

---

## Blogs summary

Blogs is the smallest of the four content-kind screens by finding count,
which is itself a reasonably good sign — it inherits the same shared
infrastructure (rows, comment sections) as Apps/Guides/Bugs without adding
much bespoke code of its own. The one real bug is BLOGS-01 (missing empty
state), which is a straightforward, low-risk fix by copying an existing
pattern from a sibling screen. BLOGS-04 is a good example of a config-level
inconsistency (a missing function argument) rather than a structural problem
— also a low-risk, high-value fix.
