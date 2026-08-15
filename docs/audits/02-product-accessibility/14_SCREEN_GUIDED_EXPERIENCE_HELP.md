# Screen Audit — Guided Experience / Help / Academy

Evidence files: `Sources/Views/GuidedExperience/GuidedExperienceView.swift`,
`GuidedExperienceResumeBanner.swift`, `Sources/Stores/GuidedExperienceStore.swift`,
`GuidedExperiencePauseStore.swift`, `Sources/Views/Info/HelpView.swift`,
`HelpArticleDetailView.swift`, `Sources/Models/HelpContent.swift`.

---

## GUIDED-01 — VoiceOver focus-delay pattern duplicated 5+ times with different magic numbers, across Guided Experience and 4 submission wizards

- **Screen/component:** `GuidedExperienceView.focusHeadingAfterTransition()` and equivalent logic in 4 submission wizards
- **Severity:** P3
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** The fixed-`Task.sleep` VoiceOver-focus-delay pattern (350ms/300ms in this file, per-file-different magic numbers elsewhere) appears independently duplicated at least 5 times across `GuidedExperienceView` and 4 of the 5 submission wizards. This is the same underlying pattern already flagged as CARD-12/HOME-01 (Home's two independent hardcoded-delay focus-retry loops) — this finding confirms the pattern is even more widespread than initially identified, recurring at least 7 times total across the app once Guided Experience and the submission wizards are included.
- **Current behavior:** Each of these 5+ independent copies has its own hand-tuned delay value, none derived from an actual layout-completion signal — exactly the "classic 'too-short delay silently drops VoiceOver focus on a slow device' bug source" the finding's own framing names directly.
- **Recommended behavior:** Extract one shared constant/helper (as already recommended for CARD-12) and have every one of these 7+ call sites use it, rather than each maintaining its own independently-tuned guess.
- **Exact reason:** With this many independent copies now confirmed, the case for a shared utility is stronger than when only Home's two instances were known — this is a genuine, recurring maintainability and reliability risk, not an isolated Home-specific quirk.
- **Suggested implementation approach:** Fold into CARD-12's recommended fix — build one shared `retryAccessibilityFocus`-style helper and migrate all known instances (Home's 2, Guided Experience's 1+, and the submission wizards' several) onto it in one consolidated pass.
- **Manual verification required:** Yes — VoiceOver focus timing pass across Guided Experience and each submission wizard, on both fast and slow devices.
- **Regression tests required:** No practical automated test for real focus timing; consider a test asserting all consolidated call sites reference the same shared constant, to prevent re-divergence.

---

## GUIDED-02 — Resume-banner logic correctly excludes completed/skipped steps (PASS)

- **Category:** PASS
- **Evidence:** `skip()`/`markCompleted()` are correctly excluded from the resume-banner's guard condition — no stale "resume where you left off" banner resurrects after a step has genuinely been skipped or completed, then the app is relaunched.
- **Recommended behavior:** No change; a well-reasoned piece of state-tracking logic.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDED-03 — Resume banner's hardcoded bottom padding isn't coordinated with the podcast mini-player

- **Screen/component:** `GuidedExperienceResumeBanner`
- **Severity:** P3
- **Category:** MANUAL VERIFY / VISUAL-LOW-VISION ISSUE
- **Evidence:** The resume banner's hardcoded bottom padding (76pt) has no coordination with the podcast mini-player's actual height when both are visible simultaneously (e.g. a user resuming Guided Experience while a podcast is playing in the background).
- **Current behavior:** Unconfirmed from static review whether the two overlap, collide, or otherwise render awkwardly together — needs a visual on-device check.
- **Recommended behavior:** Confirm on-device with both surfaces visible simultaneously; if overlap/collision is confirmed, coordinate the banner's positioning against the mini-player's actual frame rather than a hardcoded constant.
- **Exact reason:** Layout coordination between independent bottom-anchored UI elements is a common, easy-to-miss visual bug class that static review can only flag as a risk, not confirm.
- **Suggested implementation approach:** Manual visual check first; if confirmed, use `GeometryReader`/safe-area-inset coordination instead of a hardcoded constant.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## GUIDED-04 — Help content mentions "Settings" 31 times but only 1 of 4 possible link destinations actually points there

- **Screen/component:** `HelpArticleDetailView`, `HelpContent.swift`'s `RelatedLinkDestination`
- **Severity:** P2
- **Category:** IMPROVEMENT
- **Evidence:** Only 4 concrete `RelatedLinkDestination` cases exist in the help-content model, and only one of them points into Settings — despite the word "Settings" appearing 31 times across help article body text.
- **Current behavior:** A help article that mentions a specific setting by name (e.g. "you can change this in Settings > Appearance") almost never actually links there — a user reading the article has to back out of Help and manually re-navigate a remembered menu path to act on the guidance they just read.
- **Recommended behavior:** Expand `RelatedLinkDestination`'s case set to cover the specific settings screens most frequently referenced in help content, and wire those references as actual deep links rather than plain text mentions.
- **Exact reason:** This is exactly the kind of friction the audit package calls out explicitly ("deep links to settings/features from help articles"), and it's especially costly for Switch Control users, for whom re-navigating a remembered menu path from scratch is proportionally far more expensive than for a touch user.
- **Suggested implementation approach:** Audit the 31 "Settings" mentions, group them by which specific settings screen they refer to, and add the most-referenced destinations to `RelatedLinkDestination`.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDED-05 — Stale help text references a settings screen that no longer exists in that form

- **Screen/component:** A specific help tip (unspecified article) referencing "Settings → Siri & Intelligence"
- **Severity:** P3
- **Category:** BUG
- **Evidence:** The tip text says "Settings → Siri & Intelligence," but no such combined screen exists — Siri and Intelligence are split into separate rows in the current Settings structure.
- **Current behavior:** A user following this exact instruction would look for a screen that doesn't exist under that name.
- **Recommended behavior:** Update the copy to reference the correct, current screen name(s).
- **Exact reason:** Stale copy referencing a pre-split screen structure — a straightforward content fix, but worth flagging since it directly misleads a user trying to follow explicit written instructions.
- **Suggested implementation approach:** Find and update the specific string in `HelpContent.swift`.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDED-06 — Real headings reliably marked across all 51 help articles via a typed content model (PASS)

- **Category:** PASS
- **Evidence:** `.isHeader` traits are reliably applied across all 51 help articles via a typed block model in `HelpContent.swift`, rather than ad hoc per-article markup.
- **Recommended behavior:** No change; a strong, systematic pattern that guarantees consistency at scale (51 articles) in a way per-article manual markup couldn't reliably achieve.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDED-07 — "Read Summary" custom rotor actions give fast structured orientation (PASS)

- **Category:** PASS
- **Evidence:** "Read Help/Article/Settings Summary" custom rotor actions let a VoiceOver user get fast structured orientation without a full swipe-through of a long article.
- **Recommended behavior:** No change; matches the audit package's "rotor opportunities" guidance ("consider custom rotors only when they save meaningful navigation") precisely — a good example of a rotor added because it genuinely helps, not just because SwiftUI supports it.
- **Manual verification required:** No. **Regression tests required:** No.

---

## GUIDED-08 — "Explain More" disclosure has no accessibility announcement when revealed

- **Screen/component:** Help article "Explain More" disclosure controls
- **Severity:** P4
- **Category:** MANUAL VERIFY
- **Evidence:** No accessibility announcement fires when "Explain More" content is revealed, unlike Contact's threshold-crossing announcement pattern elsewhere in the app (see the Submission Flows doc's `GuidelinesReminderView`/character-count patterns for the positive comparison).
- **Current behavior:** Newly revealed explanatory text is simply one swipe away rather than being proactively surfaced/announced.
- **Recommended behavior:** Consider a brief announcement or, at minimum, confirm VoiceOver focus naturally lands on the newly revealed content rather than requiring an extra swipe past where the disclosure control was.
- **Exact reason:** Low priority — the content is still reachable, just not proactively surfaced; worth fixing opportunistically rather than urgently.
- **Suggested implementation approach:** Add a lightweight announcement or focus-move on disclosure, if judged worth the minor added interruption.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## Guided Experience / Help summary

The content model itself is strong (GUIDED-06/07 are genuine systematic
wins, not just spot-fixes) — the real gaps are in *connecting* that content
to action: GUIDED-04's missing deep links mean well-written help content
routinely fails to save the user the exact navigation effort it describes.
GUIDED-01 is this document's most consequential finding architecturally,
since it establishes that the CARD-12/HOME-01 focus-delay pattern recurs far
more widely than Home alone — this should be folded into that same fix
rather than treated as a separate, smaller problem.
