# Screen Audit — Guides / Resources

Mission (per `APPLEVIS_2026_1_MASTER_SPEC.md`): "the knowledge center" — Guides,
Tutorials, How-to articles, Accessibility resources, Events, Developer
resources, Getting Started content, News/educational content.

Evidence files: `Sources/Views/Guides/GuideBrowseView.swift`,
`Sources/Views/Guides/ResourceDetailView.swift`,
`Sources/Views/Shared/HTMLTextView.swift`, `Sources/Views/Shared/HTMLSegmenter.swift`,
`Sources/Views/Shared/AuthorProfileButton.swift`, `Sources/Models/Resource.swift`.

Cross-screen findings shared with Apps/Blogs/Bug Tracker (ALL-01 through
ALL-06) are filed in full in `06_SCREEN_APPS.md` and only cross-referenced
here.

---

## GUIDES-01 — Real heading rotor navigation + visible table of contents (PASS)

- **Category:** PASS
- **Evidence:** `HTMLSegmenter` correctly applies `.isHeader` accessibility traits per heading, and `ResourceDetailView` passes `showTableOfContents: true`, giving both real rotor heading navigation for VoiceOver *and* a visible jump-list — useful redundancy that also benefits Switch Control and Voice Control users who don't have a heading rotor equivalent.
- **Recommended behavior:** No change; this is a strong reference pattern. Worth extending to Blogs (see BLOGS-04) where the same call isn't made consistently.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDES-02 — No table segment kind; HTML tables flatten into unreadable prose

- **Screen/component:** `HTMLSegmenter.swift` / `HTMLTextView.swift`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** No `.table` segment kind exists in `HTMLSegmenter`; tables fall into the generic `.prose` case and are flattened by a weak HTML importer, with no VoiceOver row/column semantics and no Braille cell boundaries.
- **Current behavior:** Comparison tables — common in accessibility how-to guides (e.g. "which gesture does what," "setting X vs setting Y") — become an unstructured wall of text with no way to navigate by row/column or understand which cell corresponds to which header.
- **Recommended behavior:** Add a `.table` segment kind, rendered via SwiftUI `Grid`/`Table` with real accessibility row/column semantics (accessibility traits communicating header cells, row/column position).
- **Exact reason:** Tables are one of the few HTML constructs where flattening to prose genuinely destroys the information's structure, not just its formatting — a sighted user can still visually parse a mis-rendered table's grid; a VoiceOver/Braille user gets no equivalent fallback once the semantics are gone.
- **Suggested implementation approach:** Extend `HTMLSegmenter`'s segment-kind enum with `.table`, parse `<table>`/`<tr>`/`<th>`/`<td>` into a structured representation, and render via SwiftUI `Grid` or `Table` with appropriate accessibility trait annotations.
- **Manual verification required:** Yes — VoiceOver + Braille pass on a real guide containing a comparison table.
- **Regression tests required:** Yes — a parser test asserting `<table>` content produces `.table` segments, not `.prose`.

---

## GUIDES-03 — "Show Full Guide" only renders when there's actually hidden content (PASS)

- **Category:** PASS
- **Evidence:** `collapsedSegmentLimit`/"Show Full Guide" logic only renders the expand control when content is genuinely truncated — matches `docs/IMPLEMENTATION_NOTES.md`'s documented rule exactly ("only render 'Show full ...' controls when there is actually hidden content").
- **Recommended behavior:** No change; good reference implementation.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDES-04 — No Saved filter in the Guides browse screen, contradicting the spec's Saved Model

- **Screen/component:** `GuideBrowseView.GuideFilter`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** No `.saved` filter case exists in `GuideBrowseView`'s filter enum, though `APPLEVIS_2026_1_MASTER_SPEC.md`'s Saved Model section explicitly requires "Resources Saved" as a local filter.
- **Current behavior:** Same gap as APPS-02, for Guides specifically.
- **Recommended behavior:** Add a `.saved` filter case sourced from `PersistenceStore.shared.isSaved`/`savedItems()`.
- **Exact reason:** Direct, named spec gap.
- **Suggested implementation approach:** Same pattern as APPS-02.
- **Manual verification required:** No. **Regression tests required:** Yes.

---

## GUIDES-05 — No reading-position persistence for long-form guides

- **Screen/component:** `ResourceDetailView`
- **Severity:** P3
- **Category:** FUTURE IDEA
- **Evidence:** No scroll/reading-position restoration logic found for long-form guide content across sessions.
- **Current behavior:** Returning to a long guide starts from the top every time.
- **Recommended behavior:** Persist and restore scroll/reading position per resource.
- **Exact reason:** This is a bigger relative tax on screen-reader/Braille users, who can't visually skim back to where they left off the way a sighted user glancing down the page can.
- **Suggested implementation approach:** Persist a scroll offset or last-read segment id per resource id, restore on reopen.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## GUIDES-06 — Author names are inert plain text everywhere except Forums (see full detail in `06_SCREEN_APPS.md` GUIDES-06/BLOGS-06/APPS-13/BUGS-10)

- **Screen/component:** `ResourceDetailView`, `CommentRow` as used here
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `AuthorProfileButton` (tappable author name → profile sheet) is only actually used in Forums (`ForumTopicDetailView`); every author name shown in Guides is a plain, inert `Text`, despite `authorId` already being available on the `Resource`/comment models.
- **Current behavior:** A user reading a guide has no way to tap through to the author's profile, unlike a forum topic.
- **Recommended behavior:** Reuse `AuthorProfileButton` in the guide's comment rows and detail header, matching Forums.
- **Exact reason:** This falls hardest on screen-reader users, who have no visual "recognize this name, I know who that is" workaround the way a sighted user browsing might — a tappable profile link is the accessible equivalent.
- **Suggested implementation approach:** Swap the plain `Text` author name for `AuthorProfileButton` wherever `authorId` is available.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDES-07 — Documentation names a symbol that doesn't exist under that name

- **Screen/component:** Documentation vs. code
- **Severity:** P4
- **Category:** BUG (doc/code naming drift)
- **Evidence:** `docs/IMPLEMENTATION_NOTES.md` refers to the shared author-popup component as `AuthorProfileModal`; the actual type in source is `private struct AuthorProfileSheet`.
- **Current behavior:** Minor documentation drift, no functional impact.
- **Recommended behavior:** Update the doc reference (or rename the type) so the two agree.
- **Exact reason:** Small but real friction for any future contributor searching the codebase using the documented name.
- **Suggested implementation approach:** Update `IMPLEMENTATION_NOTES.md`'s reference to the actual current type name.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDES-08 — Whether in-body `<a href>` links remain tappable/announced as "link" after HTML conversion cannot be confirmed from source alone

- **Screen/component:** `HTMLTextView`
- **Severity:** P2
- **Category:** MANUAL VERIFY
- **Evidence:** Body HTML is converted via `AttributedString(ns, including: \.uiKit)`; whether `<a href>` link attributes survive this specific conversion scope and remain both tappable and announced as "link" by VoiceOver cannot be determined from static source inspection alone.
- **Current behavior:** Unconfirmed; if links are silently dropped or become inert plain text after conversion, this is a real usability loss specifically for VoiceOver users, who have no visual underline/color cue to fall back on the way a sighted user would if the tap target failed but the visual style survived.
- **Recommended behavior:** Confirm on a real device with VoiceOver whether in-body links in guide content are reachable, tappable, and correctly announced.
- **Exact reason:** Guide content frequently includes reference links (to Apple documentation, other AppleVis content, external resources); a silently broken link path would be a significant, easy-to-miss regression.
- **Suggested implementation approach:** Add a unit test asserting a known `<a href>` fixture survives the `AttributedString` conversion with its link attribute intact, plus a real-device VoiceOver spot check.
- **Manual verification required:** Yes. **Regression tests required:** Yes.

---

## GUIDES-09 — No inline `<kbd>`/`<code>` handling; keyboard-shortcut guides could mispronounce shortcuts

- **Screen/component:** `HTMLTextView` / `HTMLSegmenter`
- **Severity:** P3
- **Category:** MANUAL VERIFY
- **Evidence:** Only block-level `<pre>` is special-cased in the segmenter; there is no inline `<kbd>`/`<code>` handling.
- **Current behavior:** Unconfirmed whether VoiceOver mispronounces inline keyboard-shortcut notation (e.g. "Cmd+Shift+3") when it appears inline rather than in a code block — keyboard-shortcut guides are core AppleVis content, so this is a real-world-relevant gap if it does mispronounce.
- **Recommended behavior:** Real-device VoiceOver spot-check on a guide containing inline keyboard shortcuts; add inline `<kbd>`/`<code>` handling (verbatim speech / phonetic hints) if mispronunciation is confirmed.
- **Exact reason:** Same class of concern as GUIDES-08 — content correctness after HTML conversion needs device-level confirmation, not just code review.
- **Suggested implementation approach:** Manual test first; implement inline handling only if a real problem is confirmed.
- **Manual verification required:** Yes. **Regression tests required:** No, pending the manual check's outcome.

---

## Cross-screen findings

See `06_SCREEN_APPS.md`'s "Cross-screen findings" section for the full detail
of ALL-01 (missing "new" count in `CommunityDiscussionHeading`), ALL-02/ALL-03
(PASS — shared comment component, header/body split), ALL-04 (no post-comment
focus confirmation), ALL-05 (HTML rendering performance under VoiceOver), and
ALL-06 (no keyboard shortcut reaches Resources). All six apply identically to
Guides/Resources.

---

## Guides/Resources summary

Guides has the strongest content-reading accessibility foundation of the four
content-kind screens audited together (GUIDES-01/03 are genuinely excellent
reference patterns — real heading navigation, visible table of contents,
correctly-conditional "show more"). The two concrete gaps are GUIDES-02
(tables flatten to unreadable prose — a real content-structure loss, not just
a wording nit) and GUIDES-04 (missing Saved filter, a named spec violation
shared with Apps). GUIDES-08/09 are flagged MANUAL VERIFY rather than
confirmed bugs because they depend on runtime HTML-conversion behavior that
static analysis can't fully resolve — both should be prioritized for an
actual on-device pass given how central guide content is to AppleVis's
mission.
