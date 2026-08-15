# Screen Audit — Submission Flows (App / Blog / Bug / Podcast / Contact)

Evidence files: `Sources/Views/Submit/WizardComponents.swift`,
`SubmitAppView.swift`, `SubmitBlogView.swift`, `SubmitBugView.swift`,
`SubmitPodcastView.swift`, `ContactView.swift`,
`Sources/Networking/DrupalFormClient.swift`.

---

## SUBMIT-01 — App submission has no review step; every other wizard does

- **Screen/component:** `SubmitAppView`
- **Severity:** P2
- **Category:** UX INCONSISTENCY
- **Evidence:** Blog, Bug, Podcast, and Contact all have an explicit `.review` step with read-back before final submission. `SubmitAppView` submits directly from one continuous `Form` with no equivalent step.
- **Current behavior:** A user submitting an App entry has no final chance to review everything they entered before it's sent, unlike every sibling wizard.
- **Recommended behavior:** Add a review step to `SubmitAppView`, matching the pattern already established (and presumably well-tested) in the other four wizards.
- **Exact reason:** Directly contradicts the audit package's explicit "Review step" requirement for submission flows, and is inconsistent with 4 of 5 sibling wizards that already do this correctly.
- **Suggested implementation approach:** Extract the review-step pattern from one of the working wizards (e.g. `SubmitBlogView`) and adapt it for `SubmitAppView`'s fields.
- **Manual verification required:** No. **Regression tests required:** Yes, once implemented.

---

## SUBMIT-02 — 4 of 5 wizards skip the `ThankYouView` component built specifically to fix this exact problem

- **Screen/component:** `SubmitAppView`, `SubmitBlogView`, `SubmitBugView`, `SubmitPodcastView`
- **Severity:** P1
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `ThankYouView` exists specifically — per its own code comment — because wizards used to "just toast and dismiss immediately, giving VoiceOver users no confirmation focus point." Despite this documented history and fix, `ThankYouView` is only actually used by `ContactView` today. App, Blog, Bug, and Podcast submission all still toast-and-dismiss directly — the exact anti-pattern the shared component was built to eliminate.
- **Current behavior:** A VoiceOver user who submits an App, Blog, Bug report, or Podcast gets a toast (which, per the app's own established pattern elsewhere, is not guaranteed to land reliably in the VoiceOver announcement queue — toasts are transient by nature) and an immediate dismiss, with no dedicated, focus-guaranteed confirmation screen — precisely the failure mode `ThankYouView` was purpose-built to solve.
- **Recommended behavior:** Route all five submission wizards through `ThankYouView`, not just Contact.
- **Exact reason:** This is a regression of a previously-identified-and-fixed bug, just scoped to 4 of 5 call sites instead of all 5 — exactly the kind of "fixed once, not propagated" pattern found repeatedly throughout this audit (see CARD-01, ONBOARD-05), here with the added weight that the component exists *specifically* to solve this exact problem and yet 80% of its intended call sites don't use it.
- **Suggested implementation approach:** Replace each of the 4 wizards' toast-and-dismiss submission-success handling with a transition to `ThankYouView`, matching `ContactView`'s existing implementation.
- **Manual verification required:** Yes — submit through each of the 4 affected wizards with VoiceOver running and confirm a proper confirmation focus point now exists.
- **Regression tests required:** Yes — a test (or a shared component contract) asserting every submission wizard's success path routes through `ThankYouView`.

---

## SUBMIT-03 — Every failure branch across all 5 wizards is silent to VoiceOver — no announcement, no focus movement

- **Screen/component:** All 5 submission wizards
- **Severity:** P1
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** Every failure branch across all 5 wizards sets a plain red `Text` error with no `UIAccessibility.post(.announcement, ...)` and no focus movement — unlike the success paths (per SUBMIT-02, at least Contact does this correctly) and unlike search-result-loading paths elsewhere in the app that do announce state changes.
- **Current behavior:** A VoiceOver user whose submission fails gets literally no signal that anything happened — no announcement, no focus change, nothing distinguishing "still processing" from "failed silently" from "succeeded and dismissed." This is the worst-case screen-reader outcome the audit package's whole methodology exists to catch: an interaction that appears to do nothing.
- **Recommended behavior:** Add `UIAccessibility.post(.announcement, ...)` plus `@AccessibilityFocusState` movement to the error text, on every failure branch across all 5 wizards, consistent with the app's own well-established pattern for this elsewhere (e.g. `EditProfileView`'s recommended fix in PROFILE-01, `SignInView`'s already-correct implementation).
- **Exact reason:** This is one of the most severe accessibility findings in the entire audit by a strict reading of "does the app tell a screen-reader user what just happened" — five separate user-facing flows, all sharing the identical silent-failure defect, on forms that represent meaningful user effort (a submitted app entry, blog post, bug report, or podcast).
- **Suggested implementation approach:** Given the shared `WizardComponents.swift` scaffold, add one shared error-announcement helper (mirroring `ThankYouView`'s shared-component approach for success) rather than patching each of the 5 wizards' failure branches independently — this both fixes the bug and prevents the same "fixed in one place, not propagated" pattern from recurring for this specific fix.
- **Manual verification required:** Yes — trigger a failure (e.g. by disabling network) in each of the 5 wizards with VoiceOver running, confirm the failure is announced and focus moves to the error.
- **Regression tests required:** Yes — a test confirming each wizard's failure path posts an announcement and sets focus, ideally via the shared helper's own test rather than 5 independent tests.

---

## SUBMIT-04 — Podcast audio files picked from iCloud Drive/Files are silently omitted from submission — real data loss

- **Screen/component:** `SubmitPodcastView`, `DrupalFormClient.swift`
- **Severity:** P1
- **Category:** BUG (real data loss)
- **Evidence:** `SubmitPodcastView` never calls `startAccessingSecurityScopedResource()` for files picked via `fileImporter` from iCloud Drive/Files — unlike `SubmitBlogView`'s file-picking path, which does this correctly. `DrupalFormClient.swift` then reads the picked file via `try? Data(contentsOf:)`, which silently swallows the resulting permission failure (a security-scoped resource accessed without first calling `startAccessingSecurityScopedResource()` will fail to read). The multipart audio part is then simply **omitted** from the submission request, with no error surfaced anywhere in the chain.
- **Current behavior:** A user who picks their podcast's audio file from iCloud Drive or Files (rather than, presumably, a local/on-device source that doesn't require security-scoped access) can have their entire podcast submission "succeed" server-side — no error, no failed-state UI — with the actual audio file silently missing from what was submitted. This directly affects the exact workflow the app's own What's New changelog advertises: *"upload your audio file directly from Files or iCloud Drive."*
- **Recommended behavior:** Call `startAccessingSecurityScopedResource()` (and the matching `stopAccessingSecurityScopedResource()`) around the file read in `SubmitPodcastView`'s picker handling, matching `SubmitBlogView`'s already-correct pattern; separately, harden `DrupalFormClient` so a failed file read produces an explicit, surfaced failure rather than being silently swallowed by `try?` — a missing audio file should never be able to result in an apparently-successful submission.
- **Exact reason:** This is the single most severe correctness bug found in this entire audit pass: **real, silent data loss on a flagship, actively-advertised feature**, with a compounding accessibility dimension since SUBMIT-03 means even a *loud* version of this failure would currently go unannounced to VoiceOver users — meaning a user has essentially no way to discover their podcast submission is incomplete until someone else notices the missing audio after the fact.
- **Suggested implementation approach:** Fix at both ends: (1) add the missing `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()` pair in `SubmitPodcastView`, mirroring `SubmitBlogView`; (2) change `DrupalFormClient`'s `try? Data(contentsOf:)` to a `do`/`catch` that surfaces the read failure as an explicit thrown error, so the caller can show a real error state (which, once SUBMIT-03 is fixed, will actually be announced to VoiceOver users) rather than proceeding with a request that's missing its most important part.
- **Manual verification required:** Yes — pick a podcast audio file specifically from iCloud Drive (not a local source), submit, and confirm server-side that the audio file is actually present and correct, not silently missing.
- **Regression tests required:** Yes — a test confirming that a simulated file-read failure during podcast submission surfaces as an explicit, visible error rather than proceeding to a "successful" submission.

---

## SUBMIT-05 — Cancel correctly checks for entered progress before discarding, across all 5 wizards (PASS)

- **Category:** PASS
- **Evidence:** Cancel across all 5 wizards checks for entered progress and confirms via a dialog before discarding, with developer comments explicitly citing a prior data-loss regression this pattern was built to prevent.
- **Recommended behavior:** No change; a well-reasoned, consistently-applied protection against accidental data loss on Cancel.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-06 — Submit trigger is disabled during submission across all 5 wizards, preventing double-submission (PASS)

- **Category:** PASS
- **Evidence:** All 5 wizards disable their submit control while a submission is in flight.
- **Recommended behavior:** No change; correct, consistent protection against double-submission.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-07 — `WizardStepIndicator` correctly announces "Step X of N: Title" as a heading (PASS)

- **Category:** PASS
- **Evidence:** `WizardStepIndicator` combines a hidden visual progress bar with a combined "Step X of N: Title" spoken label plus `.isHeader`.
- **Recommended behavior:** No change; directly satisfies the audit package's explicit "progress semantics" requirement ("announced step count, not just visual"), matching Onboarding's equally-correct ONBOARD-01 pattern.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-08 — Required fields have no "(required)" label/hint anywhere except Contact

- **Screen/component:** `SubmitAppView`, `SubmitBlogView`, `SubmitBugView`, `SubmitPodcastView`
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** Only `ContactView` marks required fields with an explicit "(required)" label/hint; the other 4 wizards' only signal that a field is required is an implicitly-disabled Next/Submit button.
- **Current behavior:** A user filling out App/Blog/Bug/Podcast submission has no way to know *which specific field* is blocking progress without trial and error, since the disabled-button state doesn't identify the cause.
- **Recommended behavior:** Add explicit "(required)" labeling/hints to required fields across all 4 wizards, matching Contact's already-correct pattern.
- **Exact reason:** Directly matches the audit package's explicit "required/optional indication" requirement for submission flows.
- **Suggested implementation approach:** Reuse Contact's required-field labeling approach across the other 4 wizards.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-09 — Only Contact gives live character-count/threshold feedback; the other 4 wizards give none

- **Screen/component:** `SubmitAppView`, `SubmitBlogView`, `SubmitBugView`, `SubmitPodcastView`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Only `ContactView` has live character-count plus threshold-crossing announcements; the other 4 wizards give zero as-you-type feedback about why the wizard can't continue (compounding SUBMIT-08's related gap).
- **Current behavior:** A user typing a too-short description in, say, Bug submission gets no feedback until they try to advance and find the button disabled, with no indication of what "long enough" means.
- **Recommended behavior:** Extend Contact's live character-count/threshold pattern to the other 4 wizards wherever a minimum-length field exists.
- **Exact reason:** Same category as SUBMIT-08 — validation feedback that exists once, correctly, but isn't propagated to sibling screens with the same underlying need.
- **Suggested implementation approach:** Reuse Contact's character-count component across the other wizards' equivalent fields.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-10 — All body/description fields use native `TextEditor`, preserving standard Braille multiline editing (PASS)

- **Category:** PASS
- **Evidence:** All body/description fields across all 5 wizards use native `TextEditor` rather than a custom text-input reimplementation.
- **Recommended behavior:** No change; preserves standard Braille-display multiline editing behavior "for free," matching the audit package's Braille-input guidance.
- **Manual verification required:** No (structurally correct; still subject to the general Braille-display confirmation gap noted in `18_ACCESSIBILITY_CERTIFICATION_GAPS.md`). **Regression tests required:** No.

---

## SUBMIT-11 — One picker style inconsistency on the Bug submission wizard

- **Screen/component:** `SubmitBugView`
- **Severity:** P4
- **Category:** UX INCONSISTENCY
- **Evidence:** One picker on `SubmitBugView` uses `.pickerStyle(.navigationLink)` while sibling pickers on the same step use inline style.
- **Current behavior:** Minor visual/interaction inconsistency within a single step.
- **Recommended behavior:** Standardize on one picker style per step, or document why the one exception is intentional.
- **Exact reason:** Low priority; small visual consistency nit.
- **Suggested implementation approach:** One-line style change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-12 — No offline pre-check in 4 of 5 wizards; combined with SUBMIT-03, long-form effort can be lost to a silent failure discovered only at final Submit

- **Screen/component:** `SubmitAppView`, `SubmitBlogView`, `SubmitBugView`, `SubmitPodcastView`
- **Severity:** P3
- **Category:** IMPROVEMENT
- **Evidence:** None of these 4 wizards checks `NetworkMonitor` proactively; only Contact appears to have this check.
- **Current behavior:** A user can fill out an entire multi-step wizard while offline (or with a connection that drops partway through), only discovering the problem at the final Submit step — and, per SUBMIT-03, discovering it *silently*, with no announcement at all.
- **Recommended behavior:** Add an early, non-blocking offline warning (consistent with `OfflineBanner`'s existing pattern used elsewhere in the app) at wizard entry, so a user knows before investing significant time filling out a long form.
- **Exact reason:** This compounds directly with SUBMIT-03 — fixing the silent-failure announcement helps, but preventing the wasted effort in the first place (by warning early) is a stronger fix for the underlying user harm (lost time and typed content).
- **Suggested implementation approach:** Reuse the existing `OfflineBanner` component at each wizard's entry point, gated on `NetworkMonitor.isConnected`.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-13 — `GuidelinesReminderView`'s debounced, non-repetitive warning pattern is used consistently (PASS)

- **Category:** PASS
- **Evidence:** `GuidelinesReminderView`'s debounced, per-session-dismissed, announce-only-on-new-warning behavior is applied consistently across all 5 wizards.
- **Recommended behavior:** No change; matches the audit package's explicit "contextual tips that are not repetitive" guidance well.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SUBMIT-14 — App submission's intro step has no heading and no proactive VoiceOver focus, unlike every `WizardStepIndicator`-driven step

- **Screen/component:** `SubmitAppView`'s "before you begin" intro step
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** This intro step has no `.isHeader` heading and no proactive VoiceOver focus on appear, unlike every step in sibling wizards that goes through `WizardStepIndicator` (see SUBMIT-07's correct pattern).
- **Current behavior:** This specific step falls outside the otherwise-consistent step-focus pattern the rest of the wizard family follows.
- **Recommended behavior:** Bring this intro step into the same `WizardStepIndicator`-driven pattern (heading + proactive focus) as every other step.
- **Exact reason:** Consistency with the wizard family's own established, correct pattern.
- **Suggested implementation approach:** Restructure the intro step to use the same step-indicator/focus scaffold as the rest of `SubmitAppView`'s steps.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## SUBMIT-15 — Consistent toolbar action naming family-wide; initial-focus order needs an on-device pass

- **Screen/component:** All 5 wizards
- **Severity:** P4
- **Category:** MANUAL VERIFY (mostly PASS)
- **Evidence:** Toolbar action placement and naming are consistent across the whole wizard family — a genuinely good predictability pattern.
- **Current behavior:** Good baseline; the one open question is whether initial VoiceOver focus order on first appearance is reliable, given GUIDED-01's finding that the shared focus-delay pattern (duplicated across these same wizards) may not reliably land on slower devices.
- **Recommended behavior:** Confirm on-device as part of the GUIDED-01 fix verification, not as a separate pass.
- **Exact reason:** Directly tied to GUIDED-01's broader finding.
- **Suggested implementation approach:** Covered by GUIDED-01's fix.
- **Manual verification required:** Yes, as part of GUIDED-01. **Regression tests required:** No.

---

## Submission Flows summary

This is the highest-severity individual document in the whole audit by
concentration of P1 findings: **SUBMIT-04** is very likely the single worst
correctness bug found anywhere in this codebase (silent, real data loss on
an actively-advertised feature), and **SUBMIT-02/SUBMIT-03** together mean
that even once SUBMIT-04 is fixed, a user has no reliable way to know
whether *any* of the 5 submission flows succeeded or failed via VoiceOver —
success confirmation is missing from 4 of 5 wizards, and failure
announcement is missing from all 5. These three findings should be treated
as a single coordinated fix effort (submission reliability + submission
accessibility feedback), not three independent backlog items, since SUBMIT-04's
silent failure mode is only fully solved once SUBMIT-03's error-announcement
fix is also in place. The wizard family otherwise shows strong shared-
component discipline (SUBMIT-05/06/07/10/13 are all genuine PASSes) — the
gaps are concentrated specifically in the success/failure feedback loop, not
the form-filling experience itself.
