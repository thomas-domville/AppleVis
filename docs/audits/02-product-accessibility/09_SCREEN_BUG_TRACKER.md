# Screen Audit — Bug Tracker

Evidence files: `Sources/Views/Bugs/BugBrowseView.swift`,
`Sources/Views/Bugs/BugDetailView.swift`, `Sources/Models/BugReport.swift`.

Cross-screen findings shared with Apps/Guides/Blogs (ALL-01 through ALL-06)
are filed in full in `06_SCREEN_APPS.md` and only cross-referenced here.

---

## BUGS-01 — No empty-state handling; default filter can render a blank list

- **Screen/component:** `BugBrowseView`
- **Severity:** P2
- **Category:** BUG
- **Evidence:** Same missing-empty-state pattern as BLOGS-01 — no branch handling a filtered-to-zero result.
- **Current behavior:** The default `.active` filter combined with zero currently-active bugs for a given platform renders a blank list with no explanation.
- **Recommended behavior:** Add the shared `EmptyStateView` branch, as recommended for BLOGS-01, with wording appropriate to the active filter (e.g. "No active bugs for iOS right now").
- **Exact reason:** Same as BLOGS-01 — a blank screen is indistinguishable from a broken one without an explicit empty-state message.
- **Suggested implementation approach:** Add the missing branch, reusing `EmptyStateView`.
- **Manual verification required:** No. **Regression tests required:** Yes.

---

## BUGS-02 — Metadata rows are not combined into single accessibility elements, doubling required swipes

- **Screen/component:** `BugDetailView.metaRow`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `metaRow` is missing `.accessibilityElement(children: .combine)`, unlike `AppDetailView`'s structurally equivalent `infoRow`, which has it.
- **Current behavior:** Every metadata row (First Seen, Fixed In, Device, etc.) exposes as **two** separate VoiceOver stops (label, then value) instead of one combined "First Seen: March 2025"-style stop.
- **Recommended behavior:** Add `.accessibilityElement(children: .combine)` to `metaRow`, matching `AppDetailView.infoRow`.
- **Exact reason:** This doubles the required swipes to read through the bug's metadata block, and produces two disconnected Braille cells for what is conceptually one fact — directly contrary to the Unified Card Standard's "concise, one intentional accessibility representation" principle, and a case where the app's own codebase already demonstrates the correct pattern one screen away.
- **Suggested implementation approach:** Add the missing modifier to `metaRow`; verify no interactive child within the row needs independent focus (if none, `.combine` is safe and correct here, consistent with `infoRow`'s precedent).
- **Manual verification required:** Yes — confirm VoiceOver reads each metadata row as one stop after the fix. **Regression tests required:** Yes — accessibility-element-count assertion.

---

## BUGS-03 — No explanation of what the Bug Tracker is or how its fields relate to Apple's Feedback Assistant

- **Screen/component:** `BugBrowseView` / `BugDetailView`
- **Severity:** P2
- **Category:** IMPROVEMENT
- **Evidence:** No help/tip affordance found explaining the Bug Tracker's purpose or its "First Seen"/"Fixed In" fields' relationship to Apple's own Feedback Assistant process.
- **Current behavior:** A first-time user encountering the Bug Tracker has no in-context explanation of what it's for or how the fields it shows relate to Apple's own bug-tracking system.
- **Recommended behavior:** Add a brief contextual tip or Help article link explaining the Bug Tracker's purpose and terminology, per the audit package's explicit call-out ("Help explanation of Bug Tracker" as a required Discover/Bug Tracker audit item).
- **Exact reason:** This is explicitly named in the audit methodology as something to check for; a community bug tracker with unexplained domain-specific terminology ("Fixed In," "First Seen") is a real onboarding gap for new users.
- **Suggested implementation approach:** Use the existing `HelpfulTip`/`TipOverlay` pattern already established elsewhere in the app (per `docs/IMPLEMENTATION_NOTES.md`'s "AppleVis Tips Pattern" guidance) to add a one-time contextual explanation, plus a Help article link if one doesn't already exist.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BUGS-04 — Default "Active" filter hides Fixed bugs with no on-screen indication a filter is active

- **Screen/component:** `BugBrowseView`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** The default `.active` filter silently excludes Fixed bugs, with no persistent visible/spoken indication that a filter is currently narrowing the list.
- **Current behavior:** A user could reasonably believe they're seeing the full bug list when they're only seeing a filtered subset.
- **Recommended behavior:** Show a persistent, low-key indication of the active filter (e.g. in the navigation title or a subtitle), consistent with how filtered views elsewhere in the app (e.g. Forums) make the active filter visible.
- **Exact reason:** Silent filtering is a common source of "where did X go?" confusion, worth a small but real fix.
- **Suggested implementation approach:** Surface the active filter name in the screen's title/subtitle.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BUGS-05 — Status is never conveyed by color alone (PASS)

- **Category:** PASS
- **Evidence:** The status dot's color is always paired with a text label; `statusBanner`'s `accessibilityLabel` spells out status + platform + severity as one combined sentence.
- **Recommended behavior:** No change; good reference implementation for BUGS-06's severity-indicator gap below.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BUGS-06 — Severity has no visual distinction beyond plain gray text

- **Screen/component:** `BugDetailView`/`BugBrowseView` severity display
- **Severity:** P3
- **Category:** VISUAL-LOW-VISION ISSUE
- **Evidence:** Severity (Low/Medium/High) is always rendered as plain secondary-gray text with no color or icon distinction between levels.
- **Current behavior:** A sighted/low-vision user fast-scanning a bug list or detail page for high-severity issues has no visual differentiation to scan for — every severity level looks identical except for the word itself.
- **Recommended behavior:** Add a color/icon distinction between severity levels (using new semantic tokens per CARD-07's recommendation, e.g. a `warning`/`error`-tier color for High), while keeping the text label as the primary source of truth (matching BUGS-05's own correct pattern of text + color, never color alone).
- **Exact reason:** Fast visual triage by severity is a natural, expected workflow for a bug tracker; today it requires reading every row's text individually.
- **Suggested implementation approach:** Once CARD-07's semantic color tokens exist, map severity levels to `warning`/`error`/neutral tokens, applied alongside (not instead of) the existing text label.
- **Manual verification required:** Yes — low-vision visual scan check. **Regression tests required:** No.

---

## BUGS-07 — No author name field on bug report details (possible API limitation)

- **Screen/component:** `BugReportDetail` model
- **Severity:** P4
- **Category:** FUTURE IDEA
- **Evidence:** `BugReportDetail` has no `authorName` field at all.
- **Current behavior:** Bug reports show no submitter attribution; this may be an API/backend limitation rather than an app-level omission, and was not confirmed either way in this pass.
- **Recommended behavior:** If the API can supply an author, surface it consistent with other content kinds; otherwise no action needed.
- **Exact reason:** Low priority; flagged for completeness given every other content kind shows an author.
- **Suggested implementation approach:** Check with backend/API team whether author data is available for bug reports.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BUGS-08 — Comment/edit/delete/admin pattern matches Apps/Guides/Blogs exactly (PASS)

- **Category:** PASS
- **Evidence:** No divergence found between Bug Tracker's comment/moderation pattern and the shared implementation used by Apps/Guides/Blogs.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## BUGS-09 — External Apple Feedback Assistant links clearly explain they leave the app (PASS)

- **Category:** PASS
- **Evidence:** Both external Apple Feedback Assistant links have explicit `.accessibilityHint`s clarifying that activating them leaves the app.
- **Recommended behavior:** No change; good reference pattern for any other external-link surface being audited (cf. Discover's "Browser vs another app vs App Store" wording requirement).
- **Manual verification required:** No. **Regression tests required:** No.

---

## BUGS-10 — Author names are inert plain text, no tappable profile (cross-reference)

- **Severity:** P3 · **Category:** UX INCONSISTENCY
- **Evidence:** Filed in full as GUIDES-06/BLOGS-06/APPS-13 in `06_SCREEN_APPS.md`/`07_SCREEN_GUIDES_RESOURCES.md`; applies identically here wherever a comment author name is shown (subject to BUGS-07's note that the top-level report itself may have no author field at all).
- **Recommended behavior:** See GUIDES-06.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Cross-screen findings

See `06_SCREEN_APPS.md`'s "Cross-screen findings" section for ALL-01 through
ALL-06, all of which apply identically to the Bug Tracker.

---

## Bug Tracker summary

The Bug Tracker's biggest single accessibility win would be BUGS-02
(combining metadata rows) — a one-modifier fix with an existing correct
example already in the same codebase (`AppDetailView.infoRow`), directly cutting
the swipe count needed to read a bug's core facts. BUGS-01 (empty state) and
BUGS-03 (no in-context explanation of the feature) are the two gaps most
likely to confuse a first-time or infrequent visitor. BUGS-05/08/09 show the
Bug Tracker correctly inherited the app's better shared patterns (color+text
status, shared comment/moderation logic, clear external-link hints) — the
open work here is smaller and more targeted than on the other three
content-kind screens.
