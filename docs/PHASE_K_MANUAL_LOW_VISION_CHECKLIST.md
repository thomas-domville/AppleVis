# Phase K — Manual Low-Vision Certification Checklist

Everything in Phase K that isn't a MANUAL VERIFY item (semantic color tokens,
severity icon, Dynamic-Type font sweep) has been implemented in source. This
document covers the remainder: the settings-combination matrix the audit
calls out as needing an actual device and a pair of eyes on a screen — not
something that can be verified from source review alone. It's scoped to
low-vision/theme/text-size concerns only; VoiceOver, Braille display, and
App Store review-flow manual testing get their own script in Phase M.

Run this once on a real device (not Simulator — Simulator's Dynamic Type
rendering and true-black OLED contrast aren't representative) before
submission. Report failures with a screenshot; don't fix blind from this
list.

## 1. Theme × Dynamic Type matrix

Settings → Appearance → Theme, crossed with Settings app → Accessibility →
Display & Text Size → Larger Text.

For each of the 13 fixed palettes (`.light`, `.dark`, `.midnight`, `.warm`,
`.sepia`, `.applevisClassic`, `.mouseLight`, `.mouseDark`, `.orchard`,
`.goldenGate`, `.nebula`, `.highContrastLight`, `.highContrastDark`) — the
2 alias entries (`.system`, `.oppositeToSystem`) just resolve to `.light`/
`.dark` and don't need separate rows — check at three text sizes:
**default**, **Larger Accessibility Sizes (max slider)**, and **one step
above default** (the most common real-world setting):

- [ ] Home greeting card text doesn't clip or overlap the accent stripe
- [ ] Card titles in Home/Discover/For You feeds wrap instead of
      truncating destructively (no mid-word cut with no ellipsis)
- [ ] Bottom toolbar action buttons (Save/Download/Share/etc.) stay
      tappable and don't overlap each other at max text size
- [ ] Segmented pickers (New/All activity, etc.) don't clip their labels
- [ ] `NewCountBadge` ("N NEW") pill text stays inside its capsule
      background at all sizes tested

## 2. New semantic color tokens (CARD-07) — this session's addition

For each theme, confirm the four new tokens are visually distinct from
each other and from that theme's own `accent` color, and pass a basic
squint/contrast check against `background`:

- [ ] **Mouse Light / Mouse Dark** — `warning` (dark amber-brown) reads as
      clearly different from the theme's own amber `accent`, not just a
      shade of it
- [ ] **Orchard** — `error` (deep muted red) doesn't look identical to the
      theme's own red `accent` at a glance
- [ ] **Golden Gate** — `warning` (muted gold) doesn't look identical to
      the theme's own orange `accent`
- [ ] **High Contrast Dark** — `warning` (orange) is clearly distinguishable
      from the theme's own pure-yellow `accent`; this is the tightest case
      and the one most likely to need a follow-up hex adjustment
- [ ] **High Contrast Light / High Contrast Dark** (both) — `error` and
      `success` meet at least the same contrast bar the theme's existing
      text/border tokens meet against `background` (these two themes exist
      specifically for users who need maximum contrast, so this pair is
      the highest-stakes check in this whole document)
- [ ] Bug Tracker list (Views → Bugs) — severity icon+color (new this
      session) is distinguishable from the status dot next to it in every
      theme, not just readable in isolation

## 3. Card density × theme

Settings → Appearance → Card Density (`comfortable` / `compact`), each
against at least Light, Dark, and one high-contrast theme:

- [ ] `compact` density doesn't crush touch targets below a comfortably
      tappable size in any browse list (Forums/Podcasts/Apps/Guides/Blogs/
      Bugs)
- [ ] Card borders/dividers remain visible in `compact` density in both
      high-contrast themes specifically (thin dividers are the first thing
      to disappear when contrast is marginal)

## 4. Reduce Motion / Reduce Transparency / Bold Text (system-level)

Settings app → Accessibility, each toggle independently, app already
running:

- [ ] Reduce Motion — stagger animations (topic detail hero, badge pulses)
      degrade to instant/no-op rather than partially playing or glitching
- [ ] Reduce Transparency — any blurred/translucent surfaces (sheets,
      toolbars) fall back to a solid background, not a broken half-blur
- [ ] Bold Text — no truncation regressions introduced beyond what's
      already covered in section 1's Larger Text pass

## 5. Smart Invert / Classic Invert (iOS system-level)

- [ ] With the app's own theme set to `.light`, toggle iOS Smart Invert —
      images/icons shouldn't double-invert into something illegible
- [ ] Same check with the app's own `.dark`/`.midnight` theme active

---

Once this pass is done and any findings are fixed, Phase K is fully closed
out. Findings here should be filed as follow-up items rather than blocking
the rest of the phased implementation work, consistent with how other
MANUAL VERIFY items have been handled earlier in this audit.
