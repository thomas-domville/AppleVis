# Cross-App Patterns & Unified Content Card Standard — Findings

Scope: shared card/action infrastructure used across Home, Forums, Podcasts,
Apps, Guides, Blogs, and (per other findings docs) partially reused/diverged
from in For You and Search.

Primary evidence files:
- `Sources/Views/Shared/RowViews.swift` (ForumTopicRow, PodcastEpisodeRow,
  AppListingRow, ResourceRow, BlogPostRow, `NewCountBadge`, `NowPlayingWaveform`,
  `detailLevelLabel`, `byAuthorAndCount`, `forumContentType`, `podcastContentType`)
- `Sources/Views/Shared/ContentActions.swift` (`ContentActionsModifier`,
  `ContentDetailActions`, `ConditionalAccessibilityAction`, `CardDensityPaddingModifier`)
- `Sources/Views/Shared/RelativeDateLabel.swift` (`ActivityCountLabel`, `unreadIndicator`)
- `Sources/Services/TextToSpeechReader.swift` (`readAloudAction`)
- `Sources/Models/User.swift` (`ContentKind`)
- `Sources/Models/FeedItem.swift`
- `Sources/Models/Forum.swift`
- `Sources/Views/Home/HomeView.swift` (`FeedRow`)
- `Sources/Stores/ThemeColors.swift`

This is the single most load-bearing part of the app for VoiceOver/Braille
quality: nearly every list on every tab renders through these shared types.
Findings here should be treated as the highest-leverage fixes in the whole
audit — a single change ripples across Home, Forums, Podcasts, Apps, Guides,
and Blogs simultaneously.

---

## CARD-01 — Context-menu items are not hidden from the VoiceOver Actions rotor, causing systemic duplicate custom actions

- **Screen/component:** Every content row and every detail screen using `ContentActionsModifier` (Forums, Podcasts, Apps, Guides, Blogs; also `ContentDetailActions` variants on detail pages)
- **Severity:** P0
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Views/Shared/ContentActions.swift`, `ContentActionsModifier.body(content:)`, the `.contextMenu { ... }` block at lines 131–182, compared with the same file's `.accessibilityAction` calls at lines 183–212 (`Save/Unsave`, `Edit Topic`, `Delete Topic`, `Edit`, `Unpublish`, `Delete`, `Mark as Read`, Add Comment/Write a Review, `Open ... in Browser`, `Share ...`, `Follow/Unfollow`).
- **Current behavior:** `ContentActionsModifier` attaches a `.contextMenu` containing up to 11 `Button`s (Mark as Read, Add Comment/Write a Review, Save/Unsave, Follow/Unfollow, Open in Browser, Share, Edit Topic, Delete Topic, Edit, Unpublish, Delete) with **no** `.accessibilityHidden(true)` on any of them. On this SDK, `.contextMenu` items are automatically surfaced as VoiceOver custom actions on the underlying element (this is standard SwiftUI/UIKit behavior — it's exactly why the earlier code comment at lines 122–130 explains that gating the whole `.contextMenu` behind `!UIAccessibility.isVoiceOverRunning` broke long-press entirely and was reverted). The same modifier *also* explicitly declares nearly all of the same operations via `.accessibilityAction(named:)` / `ConditionalAccessibilityAction` immediately below. The result: most cards expose the **same operation twice** in the Actions rotor — once with the exact wording from the context menu Button's `Label`, once with the wording from the explicit `.accessibilityAction`. For Save/Unsave in particular the two wordings even differ (`.contextMenu` says `"Unsave \(kind.saveActionNoun)"`, the swipe action label — hidden — says plain `"Unsave"`), compounding the confusion documented in the source comment ("VoiceOver announced both 'Save' and 'Save Forum Topic' back to back").
- **Contrast with the correct pattern already in the codebase:** `PodcastEpisodeRow`'s `extraMenuItems` (`RowViews.swift` lines 282–293) puts `.accessibilityHidden(true)` on each individual `Button` it injects into the shared context menu (Play/Pause, Add/Remove Queue), specifically *because* those same operations already exist as explicit `.accessibilityAction`s above. The code comment there states this exact intent plainly: *"These already exist as VoiceOver-only .accessibilityActions above — .accessibilityHidden here keeps this purely a visual addition for sighted long-press users, not a second VoiceOver-announced action."* This is the fix pattern; it was applied to the two items each row type injects via `extraMenuItems`, but never to `ContentActionsModifier`'s own much larger internal `.contextMenu` block, which is the actual site of the majority of the duplication (Save, Follow, Add Comment, Open in Browser, Share, Edit, Unpublish, Delete, Mark as Read — up to 9 operations per card, not just the "Save/Share" pair called out in prior known-findings notes).
- **Recommended behavior:** Every `Button` inside `ContentActionsModifier`'s own `.contextMenu` block should get `.accessibilityHidden(true)`, exactly like the existing `extraMenuItems` pattern, since each of those operations already has (or should have) a corresponding explicit `.accessibilityAction`. The context menu remains fully functional and visible for sighted/Voice Control/Switch Control long-press users; VoiceOver users get exactly one, explicitly-ordered representation of each operation via the accessibility actions list.
- **Exact reason:** This is precisely the "one operation, one accessibility representation" north-star rule from the audit package, and it is the single largest concrete violation found in the codebase — it affects effectively every list row and every detail screen action bar in the app, not just Home. A VoiceOver user opening the Actions rotor on almost any card currently hears up to double the real number of operations, with inconsistent wording between the two copies of some of them (e.g., "Unsave" vs. "Unsave Forum Topic"), making the rotor slower to scan and eroding trust that the two "Save" entries do the same thing.
- **Suggested implementation approach:** Add `.accessibilityHidden(true)` to each `Button` inside `ContentActionsModifier`'s `.contextMenu` block (lines 133–181). Because `newCount`, `isOwnTopic`, `isAdmin`, `supportsFollow && auth.isSignedIn`, and `url != nil` already gate which buttons appear, the corresponding `ConditionalAccessibilityAction`/`.accessibilityAction` calls below already mirror that same gating — so hiding the menu duplicate should not lose any action, only remove the second (visually-invisible-anyway) VoiceOver announcement. Verify wording parity while doing this pass: standardize each operation's `.accessibilityAction` name and its (now VoiceOver-hidden) context-menu `Label` text to match exactly, since Braille/Voice Control users may still read menu titles in other contexts (e.g. Voice Control's "show numbers" overlay uses the *visible* label, not the accessibility action name — keep both human-readable and consistent). Also unify the Save wording specifically: swipe-action `Label` (currently plain "Save"/"Unsave"), context-menu `Label` (currently "Save \(kind.saveActionNoun)"), and `.accessibilityAction` name (currently "Save \(kind.saveActionNoun)") should all agree, or the visible swipe/menu button text will read differently than the spoken/rotor wording for sighted low-vision users switching between input modes.
- **Manual verification required:** Yes — must be confirmed on-device with VoiceOver, since context-menu-to-accessibility-action projection is SDK/OS-version behavior, not something a unit test can observe. Test on at least one card of each `ContentKind`, in both signed-in/admin and signed-out states (menu contents change size), and re-confirm long-press/Switch-Control/Voice-Control activation still opens the context menu correctly after adding `.accessibilityHidden(true)` to its children (hiding a menu item from the accessibility tree must not remove it from the menu itself — should not regress, but must be visually confirmed since `.contextMenu` accessibility behavior is not fully documented by Apple).
- **Regression tests required:** Yes — add/extend a semantic test (per `02_UNIFIED_CONTENT_CARD_STANDARD.md`'s own recommendation) that enumerates a rendered row's exposed `.accessibilityCustomActions` (or an equivalent snapshot/count) and asserts no operation name appears twice, across every `ContentKind` and every auth/ownership permutation (signed out, signed in non-owner, own topic, admin, own topic + admin). This is exactly the kind of regression a future contributor could reintroduce silently by adding a new context-menu item without hiding it.

---

## CARD-02 — `ContentDetailActions` (bottom detail-screen action bar) has the same latent risk, but currently has no context menu attached — confirm it stays that way

- **Screen/component:** `ContentDetailActions` (used at the bottom of detail screens for Follow/Save/Share/Browser)
- **Severity:** P3
- **Category:** ARCHITECTURE ISSUE / TEST GAP
- **Evidence:** `Sources/Views/Shared/ContentActions.swift`, `ContentDetailActions.body`, lines 543–580. No `.contextMenu` is attached here; each action is its own visible `Button`/`ShareLink` with an explicit `.accessibilityLabel`, so there is currently no CARD-01-style duplication on detail screens' bottom bar itself.
- **Current behavior:** Safe today, but the safety is incidental (no menu was added), not structurally enforced. If a future change adds a `.contextMenu` (e.g. to support long-press-for-more-options on this bar) without applying the CARD-01 fix pattern, the same duplication bug will reappear here.
- **Recommended behavior:** No code change required now. Document the rule (e.g., in a comment on `ContentActionsModifier`/`ContentDetailActions`, or in project accessibility guidelines) that any `.contextMenu` added to a shared content-action surface must `.accessibilityHidden(true)` each of its own `Button`s when the same operation already has an explicit `.accessibilityAction`.
- **Exact reason:** Prevents CARD-01 from being silently reintroduced once the primary fix lands — the failure mode is easy to reproduce by accident and easy to miss in code review without a stated rule.
- **Suggested implementation approach:** Add a short doc-comment rule directly above `ContentActionsModifier`'s `.contextMenu` block once CARD-01 is fixed, and add the CARD-01 regression test's coverage to include detail-screen action bars as they evolve.
- **Manual verification required:** No (nothing to verify today).
- **Regression tests required:** Covered by CARD-01's test if written generically enough to include future `.contextMenu` additions on this surface.

---

## CARD-03 — Proposed VoiceOver action ordering is not consistently followed; dangerous actions are not reliably ordered last

- **Screen/component:** `ContentActionsModifier` (all content kinds)
- **Severity:** P2
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Views/Shared/ContentActions.swift`, the `.accessibilityAction`/`ConditionalAccessibilityAction` chain, lines 183–212:
  1. Save/Unsave (183)
  2. Edit Topic (186), Delete Topic (187) — **destructive action placed second, immediately after Save**
  3. Edit (188), Unpublish (189), Delete (190) — admin destructive actions, still near the top
  4. Mark as Read (191–193)
  5. Add Comment/Write a Review (194)
  6. Open in Browser (195–200)
  7. Share (201–206)
  8. Follow/Unfollow (207–212)
- **Current behavior:** VoiceOver actions are exposed in the literal order they are attached via modifier chaining, which SwiftUI generally preserves as rotor order. Today that order is: Save → Edit Topic → Delete Topic → Edit → Unpublish → Delete → Mark as Read → Add Comment → Open in Browser → Share → Follow. This puts the two most dangerous, least-frequently-used actions (topic/content deletion, unpublish) in positions 2–6 of a roughly 9–11 item list, ahead of common actions like Mark as Read, Add Comment, and Follow.
- **Recommended behavior:** Reorder to match the audit package's proposed universal ordering: Primary action (n/a for most kinds) → Mark as Read → Save/Unsave → Follow/Unfollow → Add Comment/Write Review → Queue/Download (kind-specific, injected via `extraMenuItems`) → Share → Open in Browser → Edit → Unpublish/Delete last, with dangerous/admin actions always at the very end regardless of ownership vs. admin status.
- **Exact reason:** A Braille or VoiceOver user relying on the Actions rotor should encounter routine, safe actions first and destructive/administrative actions last, so that habitual "activate current action" gestures are never one accidental swipe away from Delete. This exact principle is stated explicitly in the audit package's north-star rules and proposed ordering.
- **Suggested implementation approach:** Reorder the modifier chain in `ContentActionsModifier.body` (and the matching, currently-hidden `.contextMenu` items once CARD-01 is fixed) to: Mark as Read → Save/Unsave → Follow/Unfollow → Add Comment/Write Review → Open in Browser → Share → Edit (topic-owner) → Edit (admin) → Unpublish (admin) → Delete Topic (owner) → Delete (admin). Apply the same order to `PodcastEpisodeRow`'s injected Play/Add-to-Queue actions (they should land before Save, as the "primary immediate action" per the proposed standard) and to `ContentDetailActions`'s bar ordering, which currently orders Follow → Save → Share → Browser (no Edit/Delete on that bar today, so lower risk, but Follow-before-Save also doesn't match the proposed Save-before-Follow ordering — worth reconciling in the same pass for consistency between row actions and detail-page actions).
- **Manual verification required:** Yes — VoiceOver rotor order should be spot-checked on-device after reordering, since SwiftUI's mapping from modifier-attachment-order to rotor-announcement-order is not formally guaranteed by Apple and can shift between OS versions.
- **Regression tests required:** Yes — extend the CARD-01 duplication test to also assert relative ordering (e.g., index of "Delete ..." action must be greater than index of "Save ..." action) for every `ContentKind`/permission permutation.

---

## CARD-04 — `ContentKind.displayName` does not disambiguate podcast "show" vs. "episode" in generic action wording

- **Screen/component:** `PodcastEpisodeRow`, `EpisodeDetailView`'s use of `ContentDetailActions`/`ContentActionsModifier`
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** `Sources/Models/User.swift`, `ContentKind.displayName` (lines 54–63): `.podcastEpisode` maps to `"Podcast"`, not `"Episode"`. `saveActionNoun` (lines 72–74) was specifically patched to override this to `"Episode"` for Save/Unsave only, per its own comment explaining that "Save Podcast" read as ambiguous. The same ambiguity was not corrected for the other generic actions built from `kind.displayName`: `"Follow Podcast"`, `"Unfollow Podcast"`, `"Open Podcast in Browser"`, `"Share Podcast"` (`ContentActions.swift` lines 150, 155, 160) all still read as if they apply to the whole show, even when triggered from a single-episode row/detail screen.
- **Current behavior:** Follow/Unfollow genuinely does apply to the show (per `nodeType` mapping to `node--podcast`), so "Follow Podcast" is arguably correct — but "Share Podcast" and "Open Podcast in Browser," which use the episode's own `url`, are ambiguous about whether they'll open/share the show page or this specific episode.
- **Recommended behavior:** Either (a) introduce a second, share/browser-specific noun (mirroring the existing `saveActionNoun` pattern) that says "Episode" for Share/Open-in-Browser wording while leaving Follow as "Podcast," or (b) confirm intentionally that Share/Open-in-Browser always target the show-level URL (in which case the current wording is correct and this becomes a PASS) — the current code doesn't make the intent legible either way.
- **Exact reason:** Ambiguous action names slow down VoiceOver/Braille scanning and can lead to an unintended share/open action (e.g., a user meaning to share this specific episode instead shares the whole show).
- **Suggested implementation approach:** Check what `url` actually resolves to for a `PodcastEpisode` (episode-level page vs. show-level page) and pick wording that matches the true destination; if it's episode-level, add a `shareActionNoun`/`browserActionNoun` alongside the existing `saveActionNoun`.
- **Manual verification required:** Yes — confirm what the actual Share/Open in Browser destination URL is for a podcast episode row on-device or via a quick fixture check.
- **Regression tests required:** Yes — once resolved, add a wording assertion to the semantic action-name test suite.

---

## CARD-05 — `ForumTopic.isUnread` and the `unreadIndicator` visual affordance are permanently dead: always constructed as `false`

- **Screen/component:** Home `FeedRow` (unread dot), `ForumTopic` model, everywhere `ForumTopic` values are constructed
- **Severity:** P2
- **Category:** BUG
- **Evidence:**
  - `Sources/Models/Forum.swift` line 14: `var isUnread: Bool` — declared as a real, presumably server- or locally-driven field.
  - `Sources/Networking/Mappers.swift` lines 45 and 98: `isUnread: false` — hardcoded at every construction site from API responses.
  - `Sources/Views/Forums/ForumsBrowseView.swift` line 121: `isUnread: false` — hardcoded again.
  - `Sources/Views/Forums/ForumTopicDetailView.swift` line 344: `isUnread: false` — hardcoded a third time.
  - `Sources/Models/FeedItem.swift` lines 66–71: `FeedItem.isUnread` returns `t.isUnread` for forum topics and `false` for every other kind.
  - `Sources/Views/Home/HomeView.swift` line 605: `.unreadIndicator(item.isUnread)` — the only call site that actually renders the dot.
  - A code comment at `HomeView.swift` line 221 already half-acknowledges this: *"ForumTopic.isUnread is hardcoded false server-side and never set."*
- **Current behavior:** `isUnread` is `false` at every single construction site in the codebase (four of them, independently). `FeedRow`'s `.unreadIndicator(item.isUnread)` therefore can never render its dot for any content, on any screen, under any real-world condition — it is unreachable code disguised as a working feature. Meanwhile, real per-topic unread tracking *does* exist and *does* work correctly elsewhere: `PersistenceStore.isTopicSeen(id:)` backs the Forums "Unread" filter (`Forum.swift`'s `ForumFilter.apply`, `.unread` case) — it's simply never connected to this model field or this visual indicator.
- **Recommended behavior:** Either wire `isUnread` to the same `PersistenceStore.isTopicSeen` signal already used by the Forums Unread filter (so the dot reflects real per-topic state on Home too), or remove the dead field and the `unreadIndicator` call entirely and rely solely on the existing, working "NEW"/"N NEW" badges (`NewCountBadge`, `FeedRow`'s "NEW" overlay) that already correctly reflect real state.
- **Exact reason:** Dead model fields that look real invite future bugs (a contributor may reasonably assume `isUnread` does something and build new logic on top of it), and a permanently-`false` visual affordance is effectively silent scope creep — code exists that looks like it does something for low-vision users (a colored dot) but never fires. Fixing this either restores a genuinely useful redundant-but-cheap low-vision cue, or removes confusing dead weight — either outcome is better than the current silent no-op.
- **Suggested implementation approach:** Prefer wiring it live: replace each hardcoded `isUnread: false` with `!PersistenceStore.shared.isTopicSeen(id: topic.id)` (or equivalent) at construction time, consistent with how the Unread forum filter already computes the same fact. If instead removing it, delete the field from `ForumTopic`, `FeedItem.isUnread`, and the `unreadIndicator` view modifier/call site, and confirm nothing else depends on it.
- **Manual verification required:** No for the code-level fix; a light manual check afterward confirms the dot now appears/disappears as expected for a real unread/seen topic.
- **Regression tests required:** Yes — a small unit test asserting `FeedItem.isUnread` reflects `PersistenceStore.isTopicSeen` for a fixture topic, so this can't silently regress to a hardcoded `false` again.

---

## CARD-06 — `isVoiceOverRunning` is read as a one-time snapshot in `readAloudAction`, not observed reactively

- **Screen/component:** `readAloudAction` (used by every unified row type)
- **Severity:** P3
- **Category:** ACCESSIBILITY DEFECT
- **Evidence:** `Sources/Services/TextToSpeechReader.swift`, `ReadAloudAction.body(content:)` lines 30–38: `if UIAccessibility.isVoiceOverRunning { content } else { content.accessibilityAction(named: Text("Read Aloud")) { ... } }`.
- **Current behavior:** This check runs whenever SwiftUI happens to re-evaluate the view's body, not in response to a VoiceOver-status-changed notification. If a user toggles VoiceOver on/off (e.g., via the Accessibility Shortcut) while a list is already on screen and nothing else causes that row to re-render, the "Read Aloud" action's presence can be stale until an unrelated state change forces a re-render.
- **Recommended behavior:** Observe `UIAccessibility.voiceOverStatusDidChangeNotification` (e.g., via a small `@Published`-backed observable, similar to how `NetworkStatusStore`/`ToastStore` already centralize other ambient state in this codebase) and drive `readAloudAction`'s branch from that, so the action's presence updates immediately when VoiceOver's state changes, not opportunistically.
- **Exact reason:** A stale "Read Aloud" action either (a) lingers uselessly once VoiceOver turns on, adding one more rotor entry that duplicates the row's own spoken label, or (b) fails to appear promptly once VoiceOver turns off, removing a convenience feature for sighted/low-vision users until something else causes a re-render.
- **Suggested implementation approach:** Add a small shared `@MainActor` `AccessibilityStatusStore` (or extend an existing ambient store) publishing `isVoiceOverRunning`, subscribe to `UIAccessibility.voiceOverStatusDidChangeNotification` in its initializer, and have `ReadAloudAction` (and any other `isVoiceOverRunning`-snapshotting call site found elsewhere in the app — worth a broader grep) read from it via `@EnvironmentObject`/`@ObservedObject` instead of the static property.
- **Manual verification required:** Yes — toggle VoiceOver via the Accessibility Shortcut while a list is visible and confirm the Read Aloud action's rotor presence updates without needing to scroll/navigate away and back.
- **Regression tests required:** No dedicated automated test is practical for OS-level VoiceOver toggling; note as MANUAL VERIFY only.

---

## CARD-07 — No semantic design tokens for "unread/new," "warning/error/success," or a divider distinct from `border` in `ThemeColors`

- **Screen/component:** `ThemeColors` (all 15 themes; only 13 are defined in this file — see CARD-08)
- **Severity:** P2
- **Category:** ARCHITECTURE ISSUE / VISUAL-LOW-VISION ISSUE
- **Evidence:** `Sources/Stores/ThemeColors.swift`, the `ThemeColors` struct definition (lines 24–36): fields are `background, card, text, textSecondary, border, accent, accentText, pill, pillText, inputBackground, inputBorder, isStatusBarLight`. There is no `warning`, `error`/`destructive`, `success`, or `unread`/`newIndicator` token. Every "new"/error/success color used across the app instead falls back to hardcoded system colors (e.g., `Color.orange`, `Color.red`, `Color.accentColor` used directly in `HomeView.swift`'s `SourceErrorBanner`, and `Color.accentColor` used for the "NEW" badge background in `RowViews.swift`'s `NewCountBadge`) rather than a theme-aware semantic token, so these colors do not shift with the user's selected theme (e.g., a theme built around a red accent color would visually collide with an error banner also using red).
- **Current behavior:** State/semantic colors (new, warning, error, success) are ad hoc per-call-site system colors, independent of the active one of 15 themes, rather than theme-defined tokens.
- **Recommended behavior:** Add `warning`, `error`, `success`, and `newIndicator`/`unread` fields to `ThemeColors`, defined per-theme (so, e.g., `highContrastLight`/`highContrastDark` can pick maximally distinct values, and `nebula`/`midnight` dark themes can pick colors that don't collide with their own dark backgrounds), and route every ad hoc `Color.orange`/`Color.red`/`Color.accentColor`-for-state-meaning call site through the new tokens.
- **Exact reason:** The low-vision audit dimension explicitly calls for semantic design tokens covering "destructive/warning/success" and "unread indicator," and for contrast to be verified per-theme rather than assumed; hardcoded system colors bypass per-theme contrast tuning entirely, which is a real risk across 15 themes including two dedicated high-contrast themes.
- **Suggested implementation approach:** Extend `ThemeColors` with the new semantic fields, populate them per existing theme (including `highContrastLight`/`highContrastDark`, which should pick colors that pass WCAG-equivalent contrast against both `background` and `card`), then do a grep-driven sweep replacing direct `Color.orange`/`Color.red`/state-styled `Color.accentColor` usages with `preferences.colors.warning`/`.error`/`.success`/`.newIndicator` at each call site (`SourceErrorBanner`, `NewCountBadge`, offline/error banners, destructive confirmation dialogs, etc.).
- **Manual verification required:** Yes — contrast must be visually verified per theme, especially the two high-contrast themes and the darkest themes (`midnight`, `nebula`), per the Low Vision audit's explicit requirement to verify High Contrast Light/Dark separately.
- **Regression tests required:** No automated contrast test is practical without a dedicated contrast-checking utility; consider adding one only if this becomes a recurring regression source.

---

## CARD-08 — `ThemeColors.swift` defines 13 palettes, not the "all 15 authoritative themes" the audit package's starting assumption expects

- **Screen/component:** `ThemeColors`
- **Severity:** P3
- **Category:** MANUAL VERIFY
- **Evidence:** `Sources/Stores/ThemeColors.swift` defines exactly 13 static palettes: `light, dark, midnight, warm, sepia, applevisClassic, mouseLight, mouseDark, orchard, goldenGate, nebula, highContrastLight, highContrastDark`. The audit package's executive summary (`01_EXECUTIVE_AUDIT_AND_RECOMMENDATIONS.md`) states "all 15 authoritative themes" as a confirmed current strength.
- **Current behavior:** Only 13 palettes are visible in this file. It's possible 2 more themes are defined elsewhere (e.g., derived/computed rather than static, or defined in `PreferencesStore.swift` which enumerates theme selection) — this was not confirmed within this file alone.
- **Recommended behavior:** Confirm the true theme count against `PreferencesStore.swift`'s theme enum/picker and either update the audit package's own count or locate the missing 2 palettes if they exist in another file.
- **Exact reason:** Getting the actual inventory right matters before any low-vision certification pass (Phase 8) — you can't certify contrast for themes you haven't located.
- **Suggested implementation approach:** Grep `PreferencesStore.swift` and any `Theme`-named enum for the full canonical theme list and reconcile against this 13-palette file.
- **Manual verification required:** No — this is a static code reconciliation, not a device-dependent check.
- **Regression tests required:** No.

---

## CARD-09 — `NewCountBadge` / "NEW" pill / saved-following suffixes are well-designed for low vision (PASS)

- **Screen/component:** `RowViews.swift` (`NewCountBadge`), `RelativeDateLabel.swift` (`unreadIndicator`), `HomeView.swift` (`FeedRow`'s "NEW" overlay)
- **Severity:** n/a
- **Category:** PASS
- **Evidence:** `NewCountBadge` (RowViews.swift lines 94–106) renders visible text ("N NEW") rather than relying on color/icon alone, and is `.accessibilityHidden(true)` because the same information is already spoken via the row's combined accessibility label (`detailLevelLabel`'s `alwaysAppend` parameter) — this is exactly the "no state may be conveyed only by color" and "don't duplicate state in label and a separate visual element" balance the unified card standard asks for.
- **Current behavior:** Correct as implemented.
- **Recommended behavior:** No change; worth preserving explicitly as the reference pattern when auditing/fixing other visual-state indicators (e.g., Saved/Following bookmark and bell glyphs at `RowViews.swift` lines 143–148, which are icon-only + `.accessibilityHidden(true)` and rely on the spoken `savedFollowingLabel` for VoiceOver — also correct, but note under CARD-10 a low-vision-only gap).
- **Exact reason:** n/a (documenting a good pattern to keep).
- **Suggested implementation approach:** n/a.
- **Manual verification required:** No.
- **Regression tests required:** No, though this is a good target for the "state wording" semantic tests recommended elsewhere.

---

## CARD-10 — Saved/Following/Queued/Downloaded state icons are icon-only for sighted low-vision users (color+shape but no text label visible on the card itself)

- **Screen/component:** `ForumTopicRow`, `PodcastEpisodeRow`, `AppListingRow`, `ResourceRow`, `BlogPostRow` — the small `bookmark.fill`/`bell.fill`/`text.badge.plus` glyphs
- **Severity:** P3
- **Category:** VISUAL-LOW-VISION ISSUE
- **Evidence:** `Sources/Views/Shared/RowViews.swift`, e.g. lines 143–148 (`ForumTopicRow`): `Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)` with no adjacent visible text label — the glyph alone must communicate "Saved" to a sighted low-vision user scanning the list; VoiceOver users get the real information via the spoken label, but a low-vision (not blind) user who can see the icon but has difficulty distinguishing small SF Symbols at a glance, especially at default `.caption2` size, has only the glyph shape to go on.
- **Current behavior:** State icons are small (`.caption2`/`.title2` scale, not affected by Dynamic Type in most cases — see CARD-11), monochrome (`.foregroundStyle(.secondary)`), and unlabeled visually.
- **Recommended behavior:** Per the Low Vision audit's explicit requirement ("New/unread needs text, shape, weight, icon or border in addition to color" and the Unified Card Standard's "State icons ... may be shown visually but should not rely on icon/color alone"), consider either (a) a compact text abbreviation alongside the icon at larger Dynamic Type sizes, or (b) confirm that icon shape alone (bookmark vs. bell vs. plus-badge) is sufficiently distinguishable — these are visually distinct enough shapes that this may be an acceptable PASS once deliberately reviewed, but it has not been explicitly certified against the "Differentiate Without Color"/low-vision requirement, only against VoiceOver.
- **Exact reason:** The existing analysis (CARD-09) is strong for blind VoiceOver users; this specific finding is about the separate low-vision (sighted, partial vision) persona the audit package explicitly calls out as distinct from VoiceOver ("Low vision means more than color themes").
- **Suggested implementation approach:** Manual low-vision review pass (simulated via Larger Text + Increase Contrast + Differentiate Without Color in Simulator/device) to confirm the existing icon shapes remain distinguishable; if not, consider scaling these icons with Dynamic Type (see CARD-11) or adding a one-word text chip at larger accessibility sizes.
- **Manual verification required:** Yes — this is fundamentally a visual-scanning judgment call that needs an on-device/simulator low-vision settings pass.
- **Regression tests required:** No.

---

## CARD-11 — Row-level fixed-size text and icons do not consistently scale with Dynamic Type

- **Screen/component:** All unified rows (`RowViews.swift`), `HomeView.swift`'s greeting card and section headers
- **Severity:** P2
- **Category:** VISUAL-LOW-VISION ISSUE
- **Evidence:** Multiple `.font(.system(size: N, weight: ...))` call sites that bypass Dynamic Type scaling entirely, e.g. `HomeView.swift` lines 194/196 (`greetingCard`: `.font(.system(size: 20, weight: .light))`, `.font(.system(size: 26, weight: .bold))`), lines 346 (`"New Activity"/"Latest Activity"` header: `.font(.system(size: 13, weight: .bold))`), 358 ("Mark All Read" button: `.font(.system(size: 12, weight: .bold))`); `ContentActions.swift`'s `DetailActionButtonLabel` (lines 639–654) uses `.font(.system(size: 20))` for its icon. `.font(.caption)`/`.font(.caption2)`/`.font(.body)` elsewhere in `RowViews.swift` *do* use semantic (scalable) text styles correctly — the issue is specifically the `.system(size:)` call sites, which is exactly the pattern the audit package's known-findings list (#11) and `07_BUGS_WEIRDNESS_AND_EDGE_CASE_AUDIT.md` flag for classification.
- **Current behavior:** Mixed — most row body text uses semantic styles (`.caption`, `.body`) and scales correctly; a specific, identifiable subset of header/greeting/button text uses fixed point sizes and will not grow at larger accessibility Dynamic Type sizes (AX1–AX5), risking illegible or disproportionately small text exactly where the audit package's Low Vision section calls out "toolbars must remain understandable" and "buttons must wrap."
- **Recommended behavior:** Replace `.font(.system(size: N, weight: W))` with the nearest semantic equivalent (`.title3`, `.subheadline`, `.footnote`, etc., each with `.fontWeight(...)` applied on top if a specific weight is still wanted) wherever the intent is "normal scalable UI text," reserving true fixed-size fonts only for cases with a specific, deliberate design reason (rare, and should be commented as such).
- **Exact reason:** At AX5 Dynamic Type, fixed-size text stays pinned to its base size while everything around it grows, producing visually broken layouts (disproportionately tiny headings next to huge body text) and, in the greeting card's case, text that may not meet minimum legible size for the very users Dynamic Type exists to serve.
- **Suggested implementation approach:** Grep the full `Sources/Views` tree for `.font(.system(size:` (this audit found the Home/ContentActions instances directly; a full sweep should catalog every occurrence app-wide, as `07_BUGS_WEIRDNESS_AND_EDGE_CASE_AUDIT.md` recommends, classifying each as semantic-safe, decorative, or a genuine Dynamic Type risk) and convert the "genuine risk" bucket to semantic text styles with `.dynamicTypeSize` testing at AX5.
- **Manual verification required:** Yes — visually confirm layout at AX5 + Bold Text on at least the Home greeting card, section headers, and detail-page bottom action bar.
- **Regression tests required:** No automated layout-at-AX5 test is practical here without UI snapshot testing infrastructure; flag as MANUAL VERIFY going forward each release.

---

## CARD-12 — Timed VoiceOver focus retries (hardcoded delay arrays) are a fragile, undocumented-as-such pattern repeated across the app

- **Screen/component:** `HomeView.swift` — `announceWelcomeIfNeeded()` (lines 176–184) and the `WhatsNewCard.onTap` handler (lines 306–312)
- **Severity:** P2
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** Two near-identical patterns in the same file:
  ```
  Task {
      for delayMs in [300, 550, 850] {
          try? await Task.sleep(for: .milliseconds(delayMs))
          focusTarget = nil
          focusTarget = target
      }
  }
  ```
  and
  ```
  Task {
      for delayMs in [150, 350, 600, 900] {
          try? await Task.sleep(for: .milliseconds(delayMs))
          focusTarget = nil
          focusTarget = .item(first.id)
      }
  }
  ```
  Both are already carefully commented explaining *why* (List only instantiates far-off rows once scroll reaches them; a single guessed delay isn't reliable on slower devices; `@AccessibilityFocusState` needs a real value change to re-trigger). This is honest, deliberate defensive code — not an oversight — but it is exactly the pattern `07_BUGS_WEIRDNESS_AND_EDGE_CASE_AUDIT.md` calls out by name as deserving audit: *"timing-based focus can be flaky and can produce unexpected focus jumps on slower/faster devices."*
- **Current behavior:** Focus is reassigned up to 3–4 times over roughly a second, regardless of how quickly the target view actually finished laying out — on a fast device this could cause a visible/audible "flicker" of focus jumping to the target multiple times in quick succession (each reassignment can produce a VoiceOver re-announcement); on a slow device the last retry (850ms/900ms) might still be too early for a very long list.
- **Recommended behavior:** Replace the fixed-delay-array retry with a mechanism that reacts to the actual completion of the layout/scroll operation where possible — e.g., trigger focus assignment from `ScrollViewReader`'s completion, or from a `.onAppear` callback on the specific target row (which only fires once that row actually exists in the view hierarchy), falling back to a single bounded retry only if that proves insufficient. At minimum, consolidate the two duplicated retry blocks into one shared, named helper (e.g. `retryAccessibilityFocus(target:delays:)`) so the "why" comment and tuning live in one place instead of two independent copies that could drift out of sync.
- **Exact reason:** Time-based focus retries are inherently a race against unknown device/OS layout timing; the two duplicated implementations already show independent, slightly different delay schedules, suggesting the constants were tuned by feel rather than derived from an actual layout-completion signal, and any future similar need elsewhere in the app is likely to copy-paste a third slightly-different variant rather than reuse a shared one.
- **Suggested implementation approach:** Investigate whether `List`'s row `.onAppear` (scoped to the specific target id) or `ScrollViewReader`'s `scrollTo` completion can serve as the actual "now it's safe to focus" signal instead of guessed delays; if a reactive signal isn't reliably available on this SDK, at minimum extract a single shared, documented `retryAccessibilityFocus` utility function used by both call sites (and any future ones) so behavior and tuning stay consistent app-wide.
- **Manual verification required:** Yes — test on both a fast current-generation device/simulator and, if available, an older minimum-supported device, with a long feed (to stress the "far down the list" case) and VoiceOver running, watching for double-announcement or focus landing too early/late.
- **Regression tests required:** No practical automated test for real focus timing; keep as a MANUAL VERIFY item for future regression passes, but a unit test could at least assert the delay arrays match if the two are consolidated into one shared constant (preventing silent re-divergence).

---

## CARD-13 — Shared `LoadingView`/`ErrorView`/`EmptyStateView` correctly announce state changes to VoiceOver (PASS) — but per-screen adoption must be verified

- **Screen/component:** `Sources/Views/Shared/LoadingView.swift` (`LoadingView`, `ErrorView`, `EmptyStateView`)
- **Severity:** n/a (PASS) / P2 for the verification gap noted below
- **Category:** PASS, with an attached TEST GAP
- **Evidence:** All three shared state views post `UIAccessibility.post(notification: .screenChanged, argument: ...)` in `.onAppear` (lines 29, 53, 90), with a code comment explicitly documenting the reasoning: *"None of these three shared states ever told VoiceOver anything changed — a user pulling to refresh into an error or empty state ... got no signal short of re-swiping to discover it."* `LoadingView`/`ErrorView`/`EmptyStateView` also route free-text `String` parameters through a `localized(_:)` helper specifically so runtime strings localize the same way a `Text("...")` literal would.
- **Current behavior:** This is a strong, already-fixed shared primitive — exactly the "standardize empty/loading/error/offline states" goal called out repeatedly in the audit package (Executive Audit recommendation #8, Home/Forums/Podcasts/Discover/Search/For You screen-by-screen checklists). The open question this audit could not fully close screen-by-screen is **adoption**: whether every browse/detail screen actually reuses these three shared views for its loading/error/empty states, or whether some screens (particularly ones built later, or ones with more custom layouts like Podcasts/For You/Search) have their own bespoke loading/error/empty implementations that don't get this `.screenChanged` announcement for free. Each screen-specific findings doc notes explicitly where a screen was found using a bespoke state view instead of these shared ones.
- **Recommended behavior:** Audit (see each screen doc for screen-specific confirmation/exceptions) that every top-level browse/detail screen's loading, error, and empty states route through `LoadingView`/`ErrorView`/`EmptyStateView` rather than ad hoc `ProgressView()`/`Text("No results")` constructions that would silently lack the `.screenChanged` announcement.
- **Exact reason:** A silent state transition (spinner → content, spinner → error, spinner → empty) with no VoiceOver announcement is a well-documented, high-friction accessibility gap — exactly the bug this shared component was already built to fix once. Any screen bypassing it regresses back to that exact bug for itself alone.
- **Suggested implementation approach:** Grep the `Views` tree for bespoke `ProgressView()`/empty-message `Text` constructions used as a screen's primary loading/empty state (outside of small inline list-pagination spinners, which are a different, lower-stakes case) and migrate them to the shared views where feasible.
- **Manual verification required:** Yes, per screen, to confirm the announcement actually fires (shared-component correctness doesn't guarantee call-site adoption).
- **Regression tests required:** Yes — a lightweight test (or lint/grep-based CI check) flagging new `ProgressView()`/raw empty-text usage outside the shared components would prevent silent regressions to the old un-announced pattern.

---

## Cross-app pattern summary

| Pattern | Where it recurs | Status |
|---|---|---|
| Context-menu items not hidden from VoiceOver rotor | Every `ContentActionsModifier` user: Forums, Podcasts, Apps, Guides, Blogs, Home (via shared rows) | **P0 bug (CARD-01)** — highest-leverage single fix in the app |
| VoiceOver action ordering (dangerous actions not last) | Same surfaces as above | P2 (CARD-03) |
| `isVoiceOverRunning` read as a snapshot, not observed | `readAloudAction`; worth a full-app grep for other snapshot reads of this property | P3 (CARD-06) |
| Hardcoded `.font(.system(size:))` bypassing Dynamic Type | Home greeting/header/button text, `ContentDetailActions` icon size; likely elsewhere per-screen (see individual screen docs) | P2 (CARD-11), tracked further per-screen |
| Timed multi-retry VoiceOver focus assignment | Home (2 independent copies); check other screens' docs for further instances | P2 (CARD-12) |
| Dead/always-false model fields presented as real state | `ForumTopic.isUnread` | P2 (CARD-05) |
| Missing semantic tokens for state colors (warning/error/success/unread) in `ThemeColors` | App-wide, wherever `Color.red`/`Color.orange`/state-styled `Color.accentColor` are used directly | P2 (CARD-07) |
| Shared `LoadingView`/`ErrorView`/`EmptyStateView` correctly announce `.screenChanged` — but per-screen adoption unverified | App-wide; see each screen doc for confirmed exceptions | PASS + TEST GAP (CARD-13) |

These cross-app patterns should be read alongside `01_TOP_20_FINDINGS.md` (CARD-01 through CARD-03 and CARD-05/07/11/12 are strong Top-20 candidates by reach) and the per-screen docs, which note where each pattern recurs locally (e.g., additional `.font(.system(size:))` instances or additional context-menu duplication specific to a screen's own bespoke rows, such as For You's or Search's, if those diverge from the shared `RowViews.swift` types).
