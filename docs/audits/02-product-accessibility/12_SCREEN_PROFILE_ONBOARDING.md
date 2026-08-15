# Screen Audit — Profile / Account & Onboarding

Evidence files: `Sources/Views/Profile/ProfileView.swift`,
`Sources/Views/Profile/EditProfileView.swift`,
`Sources/Views/Profile/DeleteAccountView.swift`,
`Sources/Views/Auth/SignInView.swift`, `Sources/Views/Auth/OnboardingView.swift`,
`Sources/Stores/AuthStore.swift`, `Sources/Views/Shared/AuthorProfileButton.swift`.

---

## Profile / Account

### PROFILE-01 — `EditProfileView` error message has no VoiceOver focus binding

- **Severity:** P2 · **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `EditProfileView`'s error message (on load or save failure) has no `@AccessibilityFocusState` binding, unlike `SignInView` and Onboarding's `SignInStep`, which both correctly move focus to their own error text on failure.
- **Current behavior:** A VoiceOver user who taps Save and receives an error has no way to discover the failure short of manually swiping back through the entire form to find where the error text appeared.
- **Recommended behavior:** Add `@AccessibilityFocusState` and move focus to the error message on failure, matching the pattern already correctly implemented in `SignInView`.
- **Exact reason:** This is a direct violation of the audit package's explicit "errors adjacent + announced" requirement, made more notable because the correct pattern already exists elsewhere in the same codebase (`SignInView`) — this isn't a case of the pattern being unknown, just not applied consistently.
- **Suggested implementation approach:** Copy `SignInView`'s error-focus pattern into `EditProfileView`.
- **Manual verification required:** Yes. **Regression tests required:** Yes.

### PROFILE-02 — `DeleteAccountView` has the same missing error-focus gap — arguably worse given the stakes

- **Severity:** P2 · **Category:** ACCESSIBILITY DEFECT
- **Evidence:** Same gap as PROFILE-01, in `DeleteAccountView`.
- **Current behavior:** A failed account-deletion attempt could go silently undiscovered by a VoiceOver user, since there's no focus movement to the error.
- **Recommended behavior:** Same fix as PROFILE-01, applied here.
- **Exact reason:** This is the highest-consequence form in the entire app (irreversible account deletion); a silent failure here is worse than the equivalent gap anywhere else, since the user may believe deletion succeeded, or may be confused about whether to retry an irreversible action.
- **Suggested implementation approach:** Same as PROFILE-01.
- **Manual verification required:** Yes. **Regression tests required:** Yes.

### PROFILE-03 — Fabricated "Member since [distant-past date]" when the API omits the creation date

- **Severity:** P2 · **Category:** BUG
- **Evidence:** `AuthorProfileSheet` unconditionally renders "Member since [date]" even when `Mappers.parseDrupalDate` has fallen back to `.distantPast` because the `"created"` attribute was missing from the API response (see NET-06 in `17_ENGINEERING_PERSISTENCE_PERFORMANCE_SECURITY_TESTING.md` — this fallback is a deliberate, well-reasoned resilience mechanism in the parser itself; the bug is that this specific consumer doesn't check for the sentinel value before rendering it as real data). `docs/IMPLEMENTATION_NOTES.md` itself states member-since should render "only when the API returns them."
- **Current behavior:** Produces a nonsensical fabricated date like "Member since January 1, 1" with no way for a screen-reader user to sanity-check it the way a sighted user might immediately notice something's visually wrong with "year 1."
- **Recommended behavior:** Make `memberSince` optional at the point of consumption, gating the `Text` behind `if let`, so a missing/sentinel date simply omits the line entirely rather than rendering a fabricated one — exactly matching the documented rule.
- **Exact reason:** This is a direct, confirmable violation of the app's own written accessibility convention, and a genuinely nonsensical piece of fabricated data being presented as fact — worse for VoiceOver users specifically because there's no visual "this looks wrong" cue to prompt suspicion the way an obviously-broken-looking date might for a sighted user.
- **Suggested implementation approach:** Check the date against the known `.distantPast` sentinel (or better, have `Mappers` surface `nil` instead of a sentinel date to callers that need to distinguish "missing" from "genuinely very old," if that distinction matters elsewhere) before rendering; gate the `Text` behind `if let`.
- **Manual verification required:** No — reproducible directly against a fixture/account missing the `created` field. **Regression tests required:** Yes — a test asserting a missing `created` field results in no "Member since" line being rendered.

### PROFILE-04 — Member name in the profile popup is missing the heading trait its own documentation requires

- **Severity:** P2 · **Category:** ACCESSIBILITY DEFECT
- **Evidence:** The member display-name `Text` in `AuthorProfileSheet` lacks `.accessibilityAddTraits(.isHeader)`, though `docs/IMPLEMENTATION_NOTES.md` explicitly requires "the member name should be the heading" for this exact component.
- **Current behavior:** A VoiceOver user navigating by headings (rotor) won't land on the member name as expected, contradicting the documented design intent.
- **Recommended behavior:** Add `.accessibilityAddTraits(.isHeader)` to the member name text.
- **Exact reason:** Direct, confirmable gap between documented requirement and actual implementation.
- **Suggested implementation approach:** One-line modifier addition.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-05 — Documentation names a component that doesn't exist under that name, which likely contributed to PROFILE-03/04 going unnoticed

- **Severity:** P3 · **Category:** ARCHITECTURE ISSUE / TEST GAP
- **Evidence:** `docs/IMPLEMENTATION_NOTES.md` references a component named `AuthorProfileModal`, which doesn't exist anywhere in source under that name; the actual types are `AuthorProfileButton`/`private struct AuthorProfileSheet`. (Same drift independently noted as GUIDES-07 in `07_SCREEN_GUIDES_RESOURCES.md`.)
- **Current behavior:** This naming mismatch plausibly contributed directly to PROFILE-03 and PROFILE-04 going unenforced — a future reviewer trying to verify the documented contract ("member name should be the heading," "render member-since only when returned") against the real symbol would have difficulty finding it by name, since the documented name doesn't match anything searchable in source.
- **Recommended behavior:** Rename the type to match the documentation, or update the documentation to match the type — either resolves the drift, but the type rename is probably preferable since `AuthorProfileSheet`/`AuthorProfileButton` are arguably clearer names than `AuthorProfileModal` (it's presented as a sheet, and the entry point is a button) — a documentation update should also then explicitly cross-reference PROFILE-03/04 as known-required fixes to make the connection concrete.
- **Exact reason:** Documentation that can't be traced to its actual implementation is documentation that will silently drift from reality, exactly as happened here.
- **Suggested implementation approach:** Reconcile the name (either direction); use the opportunity to also verify the rest of that documentation section's claims against current code.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-06 — Sign Out confirmation is clear and correctly distinguished from Delete Account (PASS)

- **Category:** PASS
- **Evidence:** Sign Out's `.confirmationDialog` is explicit that the action is local/device-only, and is clearly visually distinguished from the much more severe Delete Account flow positioned right above it.
- **Recommended behavior:** No change; this exact pattern (explicit `.confirmationDialog` with scope-reassurance text) is precisely what PROFILE-07 finds missing from the far more consequential Delete Account flow.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-07 — Delete Account's only gate is a single Toggle — no second-stage confirmation dialog, unlike every other destructive action in the app

- **Severity:** P2 · **Category:** UX INCONSISTENCY / IMPROVEMENT
- **Evidence:** Delete Account's only gate before the irreversible network call is a single `Toggle`. There is no `.confirmationDialog` step, unlike every other destructive action found elsewhere in the app: Sign Out, Remove Downloads, Unsave All, and Clear Queue all use `.confirmationDialog` (see FORYOU-06, PROFILE-06).
- **Current behavior:** A single accidental activation after the toggle is already on (a slipped VoiceOver double-tap, a Switch Control double-scan landing on the wrong element, an absent-minded tap) immediately and irreversibly deletes the user's account, with no second confirmation step to catch the mistake.
- **Recommended behavior:** Add a `.confirmationDialog` step after the toggle (or in place of it), matching the pattern already used correctly for every less-consequential destructive action in the app.
- **Exact reason:** This is the single most consequential action anywhere in the app — full, irreversible account deletion — and currently has the *weakest* confirmation pattern of any destructive action found in this entire audit, an inversion of what risk-proportionate confirmation design would suggest. This is very plausibly the single highest-severity individual UX finding in the whole audit given the combination of (a) total irreversibility and (b) weaker-than-average protection against accidental activation for exactly the input modalities (Switch Control, VoiceOver) this app's core audience relies on.
- **Suggested implementation approach:** Add a `.confirmationDialog` with explicit, unambiguous destructive-action wording (e.g. "This permanently deletes your account and cannot be undone.") as a required second step before the network call fires, mirroring `FORYOU-06`'s bulk-destructive-action pattern.
- **Manual verification required:** Yes — confirm the new confirmation step is itself fully accessible (reachable, escapable, clearly worded) via VoiceOver and Switch Control.
- **Regression tests required:** Yes — a test confirming the delete network call cannot fire without passing through the confirmation step.

### PROFILE-08 — No password/credential fields in the profile-editing form (PASS)

- **Category:** PASS
- **Evidence:** `EditProfileView` correctly has no password/credential fields — scope is limited to non-sensitive profile data.
- **Recommended behavior:** No change; correct scoping decision.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-09 — Sign-in fields correctly declare content type for AutoFill/password-manager support (PASS)

- **Category:** PASS
- **Evidence:** Sign-in fields correctly set `.textContentType(.username)`/`.textContentType(.password)`, enabling AutoFill/password-manager (and Keychain Strong Password) support — but see ONBOARD-05 below for a case where this correct pattern isn't applied consistently.
- **Recommended behavior:** No change on `SignInView` itself; see ONBOARD-05 for where the same fix needs to be replicated.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-10 — Saved-count rows each independently filter the full saved-items collection inline on every render

- **Severity:** P4 · **Category:** PERFORMANCE ISSUE
- **Evidence:** `ProfileView`'s 3 saved-count rows (presumably per content-kind counts) each independently filter the full saved-items collection inline on every render, rather than computing the breakdown once.
- **Current behavior:** Minor, repeated redundant work on every render of this screen — low severity given the likely small size of the saved-items collection for most users, but a pattern worth avoiding.
- **Recommended behavior:** Compute the per-kind counts once (e.g. via a single `Dictionary(grouping:by:)` pass) rather than three independent filter passes.
- **Exact reason:** Cheap, low-risk cleanup; a similar single-pass counting pattern already exists elsewhere in the codebase (e.g. `HomeView.feedSummary`) that could be reused as a template.
- **Suggested implementation approach:** Replace three independent `.filter { }.count` calls with one grouped computation.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-11 — Correct heading hierarchy throughout Profile (PASS)

- **Category:** PASS
- **Evidence:** Correct heading hierarchy is maintained throughout `ProfileView` via native `Section` titles plus an explicit `.isHeader` trait on the one section that isn't a native `Section`.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

### PROFILE-12 — Delete Account's warning text is correctly separated from its interactive control (PASS)

- **Category:** PASS
- **Evidence:** Delete Account's long warning text is rendered as one combined accessibility element, separate from the interactive confirmation `Toggle` — the warning doesn't bury the control inside a wall of text a VoiceOver user would have to swipe through entirely before reaching the actual interactive element.
- **Recommended behavior:** No change to this specific structural aspect — the fix needed here is PROFILE-07's missing second confirmation step, not this text/control separation, which is already correct.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Onboarding

### ONBOARD-01 — Step-progress dots correctly speak "Step X of Y" (PASS)

- **Category:** PASS
- **Evidence:** Step-progress dots are combined into one non-decorative element with a real spoken "Step X of Y" label, not just a visual dot indicator.
- **Recommended behavior:** No change; matches the audit package's explicit "progress semantics" requirement exactly.
- **Manual verification required:** No. **Regression tests required:** No.

### ONBOARD-02 — VoiceOver focus explicitly moves to each step's header on transition, documented as a deliberate regression fix (PASS)

- **Category:** PASS
- **Evidence:** VoiceOver focus explicitly moves to each new step's header on every transition, documented in-code as a deliberate fix for a real regression: collapsing what were 6 separate pushed screens in the legacy React Native app into a single SwiftUI view lost the "free" per-screen VoiceOver focus reset that pushed navigation provides automatically.
- **Recommended behavior:** No change; a good example of a genuine architectural tradeoff (simpler single-view SwiftUI structure) being correctly compensated for rather than silently accepted as a regression.
- **Manual verification required:** No. **Regression tests required:** No.

### ONBOARD-03 — Persistent, reassuring Cancel plus a per-step Skip (PASS)

- **Category:** PASS
- **Evidence:** A persistent Cancel control with a reassuring confirmation dialog is available throughout onboarding, plus a per-step "Skip for Now" specifically on the Sign In step.
- **Recommended behavior:** No change; matches the audit package's explicit "optional/skip ability" requirement.
- **Manual verification required:** No. **Regression tests required:** No.

### ONBOARD-04 — Push-permission request is contextual, not cold (PASS)

- **Category:** PASS
- **Evidence:** Push-notification permission is requested at step 5 of 6, with context/explanation preceding the system prompt, not immediately on cold first launch with no framing.
- **Recommended behavior:** No change; matches the audit package's explicit "notifications request timing" requirement and standard iOS permission-priming best practice.
- **Manual verification required:** No. **Regression tests required:** No.

### ONBOARD-05 — Onboarding's own Sign In step is missing the AutoFill content-type hints the standalone Sign In screen has

- **Severity:** P2 · **Category:** ACCESSIBILITY DEFECT / BUG
- **Evidence:** Onboarding's `SignInStep` username/password fields are missing `.textContentType(.username)`/`.textContentType(.password)`, which are present correctly on the standalone `SignInView` used from Profile (see PROFILE-09). The two forms don't share code, which is how this drift happened.
- **Current behavior:** AutoFill, Strong Password suggestions, and Keychain credential offers won't appear during onboarding's sign-in step specifically — which is the very first sign-in experience most users have with the app, arguably the moment this convenience matters most.
- **Recommended behavior:** Add the same `.textContentType` modifiers to onboarding's `SignInStep` fields; better yet, extract a single shared credentials-form subview used by both `SignInView` and `SignInStep`, so this specific class of drift (two independent implementations of "the same form") can't recur.
- **Exact reason:** This is a real, concrete usability regression at the single most important sign-in moment (first impression), and the root cause (code duplication rather than shared component reuse) is exactly the kind of structural issue that predictably produces this class of bug repeatedly if not addressed at the architecture level, not just patched at this one call site.
- **Suggested implementation approach:** Short-term: add the missing modifiers directly to `SignInStep`. Better: extract a shared `CredentialsFormView` (or similar) used by both `SignInView` and Onboarding's `SignInStep`, eliminating the duplication at its root.
- **Manual verification required:** Yes — confirm AutoFill/Strong Password prompts appear during onboarding sign-in after the fix.
- **Regression tests required:** Yes, if a shared component is extracted (test the shared component once, rather than needing to separately verify two independent implementations).

### ONBOARD-06 — Unclear whether users can revisit the FULL onboarding flow, or only a lighter "Welcome Tour"

- **Severity:** P3 · **Category:** IMPROVEMENT / MANUAL VERIFY
- **Evidence:** "Replay Welcome Tour" in Profile restarts a separate, lighter tour component, not the full multi-step `OnboardingView` (which covers theme selection, VoiceOver detail level, and notification categories) — `OnboardingView`'s only call site appears to be the initial launch gate.
- **Current behavior:** Unconfirmed whether a user who wants to intentionally revisit the full setup flow (e.g. to reconsider their initial theme/accessibility choices as a guided walkthrough, rather than hunting through Settings individually) has any way to do so — only the shorter tour is reachable post-launch.
- **Recommended behavior:** Confirm this is an intentional product decision; if not, consider surfacing a path to the full `OnboardingView` flow from Settings/Help, distinct from the lighter tour.
- **Exact reason:** The audit package's methodology explicitly calls out an onboarding "replay path" as something to check — this finding records that a replay path exists but may not be the *complete* one a user might expect.
- **Suggested implementation approach:** Product decision first; if desired, add a "Redo full setup" entry point distinct from "Replay Welcome Tour."
- **Manual verification required:** Yes — confirm actual on-device behavior of both replay entry points side by side.
- **Regression tests required:** No, pending the product decision.

---

## Profile & Onboarding summary

**PROFILE-07 (Delete Account's weak confirmation) is very likely the single
highest-severity individual UX finding across this entire audit** — it
combines total irreversibility with the weakest protection against
accidental activation of any destructive action in the app, for exactly the
input modalities (VoiceOver, Switch Control) this app's core audience relies
on most. PROFILE-03 (fabricated "Member since" date) is a concrete,
reproducible bug directly contradicting the app's own written documentation.
PROFILE-01/02 and ONBOARD-05 all share the same shape: a correct pattern
exists once, elsewhere in the same codebase, and simply wasn't applied
consistently to a sibling screen — suggesting a shared-component extraction
(explicitly recommended for ONBOARD-05) would prevent this whole class of
drift more durably than patching each instance individually. Onboarding
itself (ONBOARD-01 through 04) is genuinely strong, accessibility-first
design with documented evidence of deliberate, reasoned engineering
decisions — a high bar the rest of the app's forms (Profile, Delete Account)
should be brought up to match.
