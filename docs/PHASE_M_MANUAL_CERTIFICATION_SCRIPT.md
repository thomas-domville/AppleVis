# Phase M — Manual Certification Script

Nothing in this document is verifiable from source alone — it exists
because Phases D through L (this release audit's implementation work)
fixed everything that source review and careful cross-referencing could
find and verify without a compiler, but VoiceOver swipe order, Braille
efficiency, Switch/Voice Control, hardware-keyboard behavior, and actual
on-screen rendering can only be confirmed on a real device. This is the
"living manual test script" Phase M of
`docs/audits/00_MASTER_SYNTHESIS_AND_IMPLEMENTATION_PLAN.md` calls for.

## Part 1 — The 74-item test list (base)

The full table lives at
`docs/audits/01-migration-parity/12_MANUAL_REAL_DEVICE_TEST_LIST.md`
(MT-001 through MT-074) — run it in full. It wasn't duplicated here since
it's actively maintained at that path; this document adds to it rather
than replacing it.

**That list predates this session's Phases D–L implementation work.**
A meaningful number of the findings it cites have since been addressed in
source — re-confirm these ones first, since they're the most likely to
have flipped from fail to pass:

| Test ID | What changed since the list was written |
|---|---|
| MT-036 | Forums' "Jump to First New Reply" now exists (`ForumTopicDetailView`'s `newReplyCountForHeading`/`jumpToFirstNewReply`, Phase E/H — ALL-01). Confirm the pill appears and actually scrolls/focuses correctly; the equivalent was added to Podcasts/Apps/Guides/Blogs/Bugs too via the shared `CommunityDiscussionHeading` component — worth spot-checking one of those as well. |
| MT-048, MT-049 | Not fixed — still genuinely blocked on backend confirmation. See `docs/PUSH_NOTIFICATION_BACKEND_COORDINATION.md` (Phase J) instead of treating this as resolved. |
| MT-069 | Still open — `aps-environment` is `development` in checked-in source by design; this test is specifically about the *exported signed archive*, which nobody has produced yet. |
| MT-013 | Still open by the original list's own note ("expect this to still fail") — Phase K added semantic warning/error/success/unread color *tokens* (CARD-07) and one paired icon+text instance (bug severity, BUGS-06), but did not do the full Differentiate-Without-Color sweep across every color-coded indicator in the app. Confirm it's no worse than before, not that it's fixed. |
| MT-009, MT-010 | Phase K (CARD-07/CARD-11) added the semantic color tokens referenced by MT-010 and fixed several fixed-point fonts relevant to MT-009 (Home greeting, activity header, Mark All Read button, detail-action icons) — but neither was a full app-wide sweep. Re-run both; expect fewer but not zero findings. |

Everything else in the 74-item list should be treated as still open and
run as originally written.

## Part 2 — Broader certification gaps (not individual bug repros)

From `docs/audits/02-product-accessibility/18_ACCESSIBILITY_CERTIFICATION_GAPS.md`.
These are process/coverage gaps, not point fixes — no amount of source-level
work in Phases D–L could close them:

1. **Independent Braille-display pass.** Every Braille-related finding
   across all three audits is VoiceOver-speech-inferred, never confirmed
   against a real Braille display. Needs a dedicated pass, ideally
   covering the same screens as MT-022/MT-023 plus general navigation.
2. **Dedicated Switch Control pass.** Essentially unaudited from source —
   run a full scanning session across Forums, Podcasts, Apps, Settings,
   and at least one submission wizard (see MT-024, but don't stop there).
3. **Dedicated Voice Control pass.** Only one failure mode was found
   opportunistically; needs an exhaustive pass checking that every
   visible-label ↔ spoken-command pairing actually works, app-wide.
4. **Hardware-keyboard / iPad pass.** Split-view, pointer support, and
   Stage Manager have not been verified at all; MT-025/MT-026 cover only
   the specific shortcuts already known about.
5. **Full device/OS matrix.** Zero device testing has been performed by
   any audit in this package. Minimum bar: smallest and largest current
   iPhone, an iPad, the minimum-supported iOS version, and the current
   iOS version.
6. **Recurring process decision.** Several findings across this audit
   package describe their own history as "fixed once, then regressed"
   (`ContentActions.swift`'s own code comments on the Save/Share
   duplication issue are a named example). Whether to formalize this
   script as a per-release requirement, rather than a one-time exercise,
   is a product/process decision — not one this implementation pass can
   make on its own.

## Part 3 — New items from this session's Phase L work

Not in the original 74-item list (that list predates Phase L). Both have
an automated regression test as well (`ToastStoreTests`,
`PersistenceStoreClearAllLocalDataTests`), but the audit that raised each
one explicitly called for manual confirmation too:

| Test ID | Workflow | Expected | Source finding |
|---|---|---|---|
| MT-075 | Sign out on a shared/borrowed device, sign in as a different account | No saved items, followed topics, read/visited state, or notification history from the first account is visible to the second | ARCH-04/PERS-05 |
| MT-076 | Trigger two toasts within 3 seconds (e.g. Save immediately followed by Follow) | Both toasts display their full ~3-second duration; the first toast's dismissal timer does not cut the second one short | CONC-02 |

## Mandatory configurations (unchanged from the base list)

Run representative core screens through each:

- VoiceOver on, default text · VoiceOver on, largest accessibility text
- High Contrast Light · High Contrast Dark
- System Light / System Dark · System Inverted in both system appearances
- Bold Text · Increase Contrast · Reduce Motion · Reduce Transparency
- Button Shapes
- Hardware keyboard on iPad · Offline/airplane mode
- Background playback + locked screen

Core screens: Home, Discover, For You, Search, Forums, Topic Detail, Apps,
App Detail, Podcasts, Episode/Player, Resources, Settings, Help,
Onboarding, and at least one submission flow.

For the low-vision-specific theme × Dynamic Type × Card Density matrix
(13 palettes, this session's new semantic color tokens), use
`docs/PHASE_K_MANUAL_LOW_VISION_CHECKLIST.md` instead of re-deriving it
here — it was written for exactly that slice of this script.

---

Nothing above has been executed — this is the script to run, not a report
of results. Record device, iOS version, app build, and configuration for
each session, same as the base list's own instruction.
