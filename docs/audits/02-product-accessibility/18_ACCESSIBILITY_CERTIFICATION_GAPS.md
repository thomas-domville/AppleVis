# Accessibility Certification Gaps

This document answers a different question than the rest of the audit: not
"what's wrong with the code," but "what would it take to be able to say, with
confidence, that this app has been properly certified for VoiceOver, Braille,
Switch Control, Voice Control, hardware keyboard, and low vision?" Per the
audit package's own methodology (`04_VOICEOVER_BRAILLE_AUDIT.md`,
`05_LOW_VISION_VISUAL_AUDIT.md`, `10_MANUAL_ACCESSIBILITY_TEST_SCRIPT.md`),
static source inspection — everything this audit could do — is necessary but
not sufficient for certification. This document inventories what remains.

---

## 1. No manual accessibility test script currently exists in the repository

The audit package includes a template (`10_MANUAL_ACCESSIBILITY_TEST_SCRIPT.md`)
covering VoiceOver, Braille, low vision, and alternate-input passes per root
screen. Nothing equivalent exists in `docs/` today. Every "manual verification
required: yes" finding in this audit — there are well over 40 across all
documents — currently has no formal place to be tracked, executed, or signed
off. **Recommendation:** adopt a version of the package's template as a living
document (e.g. `docs/audits/02-product-accessibility/MANUAL_TEST_SCRIPT.md`
or a project-tracked checklist), pre-populated with every MANUAL VERIFY item
this audit identified, and run it before each release, not just once.

## 2. Braille has never been independently verified — every finding in this audit is VoiceOver-speech-inferred

Per the audit package's explicit instruction ("Explicitly test with a
refreshable Braille display... instead of assuming VoiceOver speech testing
covers Braille"), this audit's Braille-tagged findings (e.g. PODCAST-04,
PODCAST-11, GUIDES-02, the Unified Card Standard's Braille model section)
were derived from reading source code and reasoning about likely Braille
output, not from an actual connected display. **This is the single largest
category of unverifiable-by-audit-alone risk in this whole package.** No
finding in this audit should be treated as Braille-certified until confirmed
with a real display, specifically covering:
- Card output (titles fitting useful cells early, no duplicate state in
  label vs. value, concise action names) across every content kind.
- Multiline text entry (forum compose/reply, profile edit, all five
  submission wizards, search) — cursor movement, selection, autocorrect
  interaction, validation-after-input.
- Player elapsed/remaining position display (PODCAST-11 flagged this as
  inconsistent between screens; the underlying question of whether either
  wording is actually good on a real display is still open).
- Contracted/uncontracted Braille behavior as supplied by iOS, which no
  amount of source review can predict.

## 3. Switch Control has zero dedicated findings — this audit could not meaningfully evaluate it from source alone

Only one Switch-Control-specific concern surfaced across the whole audit
(DISCOVER-05, the ~23-row hub screen having no jump mechanism Switch Control
users can use). This near-absence is itself a gap, not a clean bill of
health: Switch Control's actual behavior — scan timing, group/item scanning
mode interaction with `.accessibilityElement(children: .combine)` groupings,
whether every custom `.accessibilityAction` is reachable via the Switch
Control menu the same way it's reachable via VoiceOver's rotor — is
fundamentally a runtime behavior that source inspection cannot reliably
predict. Every screen in this app needs a dedicated Switch Control pass
before any Switch-Control-related claim can be made with confidence.

## 4. Voice Control has exactly one confirmed real failure mode, found opportunistically

FORYOU-03 (the "Delete"/"Remove Download"/"Remove Downloads" three-way
wording split) is a genuine, source-verifiable Voice Control failure — Voice
Control's "tap X" command matches visible labels, and this app has several
places (per CARD-01/CARD-03's broader findings) where VoiceOver wording and
visible label wording diverge. This single finding was found because the
wording mismatch happened to be large enough to notice in source; smaller
mismatches of the same kind are very plausible elsewhere and were not
exhaustively checked. **Recommendation:** once CARD-01's wording
standardization (item #12 in the Top 20) is complete, do a dedicated pass
confirming visible label text and VoiceOver action names agree everywhere,
specifically with Voice Control's exact-match requirement in mind — this is
a stricter bar than "sounds similar to a human."

## 5. Hardware keyboard / iPad certification is incomplete by the master spec's own stated bar

The master spec requires "Full keyboard navigation," "External keyboard
shortcuts," "Pointer support," and "Stage Manager support" on iPad. This
audit found:
- Only 2 of 5 primary content destinations (Home, plus Discover as a proxy)
  are reachable via a direct `CommandMenu` shortcut (ALL-06, FORUM-15) —
  Forums, Apps, and Resources require multi-step navigation first.
- No hardware shortcut to dismiss the podcast full-player sheet (PODCAST-16).
- No confirmed testing of pointer support or Stage Manager anywhere in this
  audit — neither was checked, since neither is verifiable from source
  review alone.
- iPad's split-view (list-left, detail-right) layout, explicitly required by
  the master spec, was not independently confirmed to exist or function
  correctly in this pass — worth a dedicated iPad-specific review, since
  every screen audited in this package was reviewed from source, not from a
  running iPad layout.

## 6. Low vision certification needs a dedicated settings-combination pass, not just theme review

This audit reviewed `ThemeColors`' 13 (see CARD-08 — possibly 15, unconfirmed)
static palettes structurally, and found real gaps (CARD-07's missing
semantic tokens, CARD-11's fixed-point fonts, SEARCH-09's untheme'd shared
state views, BUGS-06's color-only severity). None of this substitutes for
the audit package's explicitly required settings-combination pass:
- High Contrast Light and High Contrast Dark, verified **separately** (not
  assumed identical in reverse).
- AX5 Dynamic Type simultaneously with VoiceOver running (not just AX5 alone,
  and not just VoiceOver alone — the combination is explicitly called out as
  a distinct edge case in the audit package's edge-case matrix).
- Bold Text, Increase Contrast, Differentiate Without Color, Button Shapes,
  Reduce Transparency — none of these were checked in this audit; all were
  out of scope for static source review since they primarily depend on
  system-level rendering behavior this pass cannot observe.
- Reduce Motion was spot-checked in a few places (PODCAST-P1's `NowPlayingWaveform`
  correctly respects it) but not exhaustively across every animated element
  in the app.

## 7. No device/OS matrix has been exercised

The audit package requires testing on at least one smaller iPhone, one
current large iPhone, iPad, the current minimum-supported iOS, and the
current iOS. This audit was conducted entirely via static source review with
no device testing of any kind — every "manual verification required: yes"
finding in this package implicitly needs to be run across that matrix, not
just once on whatever device happens to be convenient. This matters
concretely for at least two findings already identified: CONC-01's
main-thread decode/regex question (may only be measurably slow on older
hardware) and CONC-06's launch-time Keychain read (same concern).

## 8. Certification is not a one-time event — no recurring process exists

Nothing in the current engineering setup (per the Engineering audit,
`16_ENGINEERING_ARCHITECTURE_CONCURRENCY_NETWORKING.md`/
`17_ENGINEERING_PERSISTENCE_PERFORMANCE_SECURITY_TESTING.md`) establishes a
recurring accessibility regression process — TEST-01 through TEST-08
document a near-total absence of automated accessibility-adjacent tests
(action de-duplication, wording consistency, focus behavior), and item #1
above notes there's no manual test script to run repeatedly either. Even
after this audit's findings are fixed, without either (a) meaningful
automated coverage of action lists/wording/focus state, or (b) a
recurring manual test script executed each release, regressions in exactly
these areas are likely to reappear silently — which is precisely how several
of this audit's own findings describe their own history (e.g. `ContentActions.swift`'s
code comments document at least two rounds of "fixed, then partially
regressed" on the Save/Share duplication issue).

---

## Certification readiness summary

| Dimension | Status |
|---|---|
| VoiceOver | Extensively reviewed via source; many concrete findings (CARD-01 etc.) confirmed at the code level, but **no on-device confirmation pass has been done for any of them yet** |
| Braille | **Not independently verified anywhere in this audit** — all Braille findings are inferred, not confirmed |
| Low vision (themes/contrast) | Structural review done (CARD-07/08, SEARCH-09); **no settings-combination pass done** |
| Dynamic Type | Specific violations found (CARD-11 and per-screen instances); **not verified at AX5 combined with VoiceOver** |
| Switch Control | **Essentially unaudited** — one incidental finding, no dedicated pass |
| Voice Control | **One confirmed failure mode found opportunistically; no exhaustive pass done** |
| Hardware keyboard / iPad | Partial gaps identified (ALL-06, PODCAST-16); **iPad split-view, pointer, Stage Manager not verified at all** |
| Device/OS matrix | **Not exercised — zero device testing performed in this audit** |
| Regression process | **Does not exist** — no automated wording/de-duplication tests, no recurring manual script |

**Bottom line:** this audit provides a strong, evidence-based map of *where*
to look and *what* is very likely wrong, verified as deeply as static source
review allows. It is not, and cannot be, a substitute for the on-device
VoiceOver/Braille/Switch Control/Voice Control/low-vision passes the audit
package's own methodology requires before anything in this app can be
described as accessibility-certified. Phase 10 of the implementation roadmap
(`19_IMPLEMENTATION_ROADMAP.md`) is dedicated to closing exactly this gap.
