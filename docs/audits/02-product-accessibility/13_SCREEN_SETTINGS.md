# Screen Audit — Settings

Per `APPLEVIS_2026_1_MASTER_SPEC.md`'s Settings Model: a flat 10-item list
(Account & Profile, Notifications, Appearance, Accessibility, Podcasts,
Sounds & Haptics, Saved & Sync, Siri & Shortcuts, Help & Support, About
AppleVis), plus a required Settings search field.

Evidence files: `Sources/Views/Settings/*.swift` (all 11 screens),
`Sources/Stores/PreferencesStore.swift`, `Sources/Stores/TipStore.swift`.

---

## SETTINGS-01 — Shipped information architecture diverges from the master spec's flat 10-item model

- **Screen/component:** `SettingsView`
- **Severity:** P2
- **Category:** UX INCONSISTENCY
- **Evidence:** The shipped Settings screen groups items as Customisation/Alerts/Content/Data & Privacy/Storage & Cache/Support, not the spec's flat 10-item list. "Account & Profile" is absent from Settings entirely (relocated to Profile, per an in-code comment). Extra items exist beyond the spec's list (Forums, Privacy, Intelligence, Storage & Cache).
- **Current behavior:** A meaningful IA divergence from the written spec, similar in kind to DISCOVER-03's tab-structure divergence — plausibly a deliberate later product decision, but undocumented as such in the spec itself.
- **Recommended behavior:** Reconcile the spec document against the shipped IA, explicitly documenting the Account & Profile relocation and the additional sections, so the spec remains a trustworthy reference rather than silently stale.
- **Exact reason:** Same rationale as DISCOVER-03 — every audit finding that cites "the master spec" for Settings structure should be read against the actual current IA, and that's only possible if the divergence is documented rather than implicit.
- **Suggested implementation approach:** Documentation-only reconciliation; no code change required unless the divergence is judged unintentional.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-02 — The "AppleVis Tips" toggle has zero effect — tips show regardless of the setting

- **Screen/component:** `TipStore.show(_:)`
- **Severity:** P1
- **Category:** BUG (violates documented intent)
- **Evidence:** `TipStore.show(_:)` never reads `preferences.helpfulTipsEnabled`. `docs/IMPLEMENTATION_NOTES.md`'s "AppleVis Tips Pattern" section explicitly requires: *"Respect the global AppleVis Tips switch in Accessibility settings by using the shared component."*
- **Current behavior:** Turning the "AppleVis Tips" toggle off in Settings has **zero effect** — tips continue showing on every trigger exactly as if the toggle were on.
- **Recommended behavior:** Guard `show(_:)` on `preferences.helpfulTipsEnabled`, so disabling the setting actually suppresses tips app-wide.
- **Exact reason:** This is a direct, demonstrable violation of the app's own written accessibility convention — a user who explicitly disables tips (a reasonable choice for an experienced user who finds them repetitive) gets no actual change in behavior, which is exactly the kind of "the setting doesn't do what it says" bug that erodes trust in every other setting in the app once discovered.
- **Suggested implementation approach:** Add a check for `preferences.helpfulTipsEnabled` at the top of `TipStore.show(_:)`, returning early if disabled.
- **Manual verification required:** Yes — toggle the setting off, trigger a known tip condition, confirm it no longer appears.
- **Regression tests required:** Yes — a `TipStore` unit test asserting `show(_:)` is a no-op when the preference is disabled.

---

## SETTINGS-03 — Notification toggles stay fully interactive regardless of actual system push-permission status

- **Screen/component:** `NotificationSettingsView`
- **Severity:** P2
- **Category:** ACCESSIBILITY DEFECT / UX INCONSISTENCY
- **Evidence:** "My Activity"/"Community" toggles have no `.disabled()` tie-in to the actual system push-permission status, and no inline explanation of the relationship.
- **Current behavior:** A user can enable "Forum Replies" while push notifications are denied at the system level and get nothing — with no way to correlate the setting's apparent "on" state with the actual reason nothing arrives.
- **Recommended behavior:** Either disable these toggles (with an explanatory hint) when system push permission is denied, or add inline explanatory text clarifying that these settings only take effect once system permission is granted, with a direct link/action to the system Settings app.
- **Exact reason:** A toggle that appears "on" but produces no actual effect, with no explanation, is confusing for any user and especially costly for a screen-reader user who can't visually cross-reference the system's notification settings the way a sighted user might more readily investigate.
- **Suggested implementation approach:** Check `UNUserNotificationCenter`'s authorization status and reflect it in this screen's UI state and copy.
- **Manual verification required:** Yes — deny push permission at the system level, confirm the in-app toggles now clearly communicate the mismatch.
- **Regression tests required:** No practical automated test for system permission state; MANUAL VERIFY.

---

## SETTINGS-04 — No "Reset to Defaults" anywhere across 11 Settings screens

- **Screen/component:** All Settings screens
- **Severity:** P3
- **Category:** IMPROVEMENT
- **Evidence:** No reset-to-defaults control found anywhere, despite `PreferencesStore` already centralizing default values that such a control could target.
- **Current behavior:** A user who has changed many settings and wants to start over must manually revert each one individually.
- **Recommended behavior:** Add a "Reset to Defaults" action, at minimum per-screen (and optionally app-wide), sourced from `PreferencesStore`'s existing default values.
- **Exact reason:** Especially valuable for Switch Control/Voice Control users, for whom individually reverting many controls is proportionally more costly than for a sighted touch user.
- **Suggested implementation approach:** Add a destructive-styled (but non-catastrophic, so a light confirmation is sufficient) "Reset to Defaults" button per settings screen, resetting only that screen's own settings to `PreferencesStore`'s documented defaults.
- **Manual verification required:** No. **Regression tests required:** Yes, once implemented.

---

## SETTINGS-05 — Some manual selection-state Buttons don't get native Picker/radio VoiceOver semantics

- **Screen/component:** Several Settings screens (specific ones using manual `.accessibilityAddTraits(.isSelected)` Buttons rather than a native `Picker`/`List` selection)
- **Severity:** P3
- **Category:** MANUAL VERIFY
- **Evidence:** Several settings screens implement option selection via manual Buttons carrying `.accessibilityAddTraits(.isSelected)`, rather than a native `Picker` or `List` selection binding.
- **Current behavior:** Functionally correct (the selected state is announced), but VoiceOver announces "Selected, button" rather than native radio-button or Adjustable-control semantics a `Picker` would provide — and the actual on-device behavior (including how Switch Control's scanning menu treats these vs. a native control) needs confirmation, not just source-level reasoning.
- **Recommended behavior:** Where feasible, prefer native `Picker`/selection-list controls for genuinely single-choice settings, reserving manual Button-based selection for cases where the native control's visual/interaction model genuinely doesn't fit.
- **Exact reason:** Native controls get correct semantics "for free" across every assistive technology (VoiceOver, Switch Control, Voice Control) simultaneously; manual reimplementations only get whatever specific traits were explicitly added, and can silently diverge from native behavior in ways not obvious from a source read alone.
- **Suggested implementation approach:** Audit each manual-Button-selection instance and migrate to a native control where the visual design allows; where a custom visual treatment is genuinely required, do a dedicated on-device VoiceOver + Switch Control pass to confirm equivalent behavior.
- **Manual verification required:** Yes. **Regression tests required:** No.

---

## SETTINGS-06 — "Sounds & Haptics" has literally zero haptics controls, despite haptics being used elsewhere unconditionally

- **Screen/component:** `SoundsHapticsSettingsView`, `TipOverlay.swift`
- **Severity:** P4
- **Category:** FUTURE IDEA
- **Evidence:** The "Sounds & Haptics" screen has zero haptics controls — its own in-code comment admits this — yet `TipOverlay.swift` calls `UIImpactFeedbackGenerator` unconditionally, with no setting governing it at all.
- **Current behavior:** The screen's name promises haptics control that doesn't exist; the one haptic feedback call site in the app is entirely ungoverned by any user preference.
- **Recommended behavior:** Either add a haptics toggle governing `TipOverlay`'s feedback generator call, or rename the screen if haptics genuinely aren't meant to be user-configurable yet.
- **Exact reason:** Low priority, but a misleading screen name is a small trust/clarity issue worth eventually resolving.
- **Suggested implementation approach:** Add a `hapticsEnabled` preference and gate the `UIImpactFeedbackGenerator` call behind it.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-07 — `cardDensity` `@AppStorage` key independently declared twice, undocumented as intentional

- **Screen/component:** Cross-reference to `CardDensityPaddingModifier` in `Sources/Views/Shared/ContentActions.swift`
- **Severity:** P4
- **Category:** ARCHITECTURE ISSUE
- **Evidence:** `@AppStorage("appearance.cardDensity")` is independently declared in two separate files with two separate default literals, bound to the same underlying key.
- **Current behavior:** Works correctly today (both declarations resolve to the same stored value once either is set), but reads as an unintentional duplication rather than a deliberate, documented pattern — unlike, for comparison, `SoundPlayer`'s similarly-shaped duplication elsewhere in the app, which carries an explanatory comment making its intentionality clear.
- **Recommended behavior:** Either consolidate to one declaration (referenced from both sites) or, if duplication is genuinely preferred for some reason (e.g. avoiding a shared-module dependency), add the same kind of explanatory comment the `SoundPlayer` pattern already uses, so a future reader doesn't mistake it for an accidental copy-paste.
- **Exact reason:** Low severity, but exactly the kind of small drift-risk this audit found repeatedly (two independent copies of the same fact, one gets updated, the other doesn't).
- **Suggested implementation approach:** Consolidate or document.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-08 — All 11 screens bind directly to `@AppStorage` — no hidden Save button anywhere (PASS)

- **Category:** PASS
- **Evidence:** Every one of the 11 Settings screens binds directly to `@AppStorage`/`PreferencesStore` — a fully predictable, instant-apply model with no screen requiring an extra "Save" step some other screen might not need.
- **Recommended behavior:** No change; this consistency is explicitly valuable for screen-reader and Switch Control users, who benefit from not having to remember whether a given screen needs an extra confirmation step.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-09 — Real, accessible Settings search satisfies the master spec's explicit requirement (PASS)

- **Category:** PASS
- **Evidence:** Settings has a genuine `.searchable` search with client-side filtering and an accessible "No Results" state.
- **Recommended behavior:** No change; directly satisfies `APPLEVIS_2026_1_MASTER_SPEC.md`'s explicit "Include a Settings search field in production" requirement — worth noting as a positive contrast to APPS-01, which found the identical requirement missing for the App Directory.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-10 — Trim Silence/Voice Boost/EQ toggles are genuinely wired into the audio render path (PASS)

- **Category:** PASS
- **Evidence:** These toggles are genuinely consumed by `AudioEffectsProcessor`'s render path — not dead switches, unlike the RN-era gaps `docs/IMPLEMENTATION_NOTES.md` explicitly flags as historically having existed for these exact features.
- **Recommended behavior:** No change; directly corroborates PODCAST-05's finding that `IMPLEMENTATION_NOTES.md`'s "still needs native work" list is stale — this is further confirmation these features are fully wired, not placeholder UI.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-11 — iCloud Sync's dependent toggles show explanatory text, not silent graying, when the master switch is off (PASS)

- **Category:** PASS
- **Evidence:** When the iCloud Sync master switch is off, dependent toggles are replaced with clear explanatory text rather than simply grayed out with no explanation.
- **Recommended behavior:** No change; this is exactly the "dependency relationships" / "disabled-state explanation" pattern the audit package's Settings checklist calls for, and a good contrast case against SETTINGS-03's push-permission gap, which doesn't yet do this.
- **Manual verification required:** No. **Regression tests required:** No.

---

## SETTINGS-12 — Two similarly-worded "Clear All..." buttons in different Settings screens have different actual scope

- **Screen/component:** `PrivacySettingsView` ("Clear All Local Data") vs. `StorageView` ("Clear All Storage")
- **Severity:** P3
- **Category:** UX INCONSISTENCY
- **Evidence:** Privacy's "Clear All Local Data" calls `PersistenceStore.clearAllLocalData()`, which also clears saved items and read/visit state. Storage's near-identically-worded "Clear All Storage" does **not** clear that same data — it's scoped differently.
- **Current behavior:** Two destructive buttons with very similar names and very different actual scope, in two different screens a user might reasonably confuse or not remember the distinction between.
- **Recommended behavior:** Differentiate the wording more clearly (e.g. "Clear Saved Items & Read History" vs. "Clear Downloaded Files & Cache"), and/or add explicit scope-reassurance text to each confirmation dialog (matching the pattern already used correctly elsewhere — see FORYOU-06, SETTINGS-11).
- **Exact reason:** A user intending only to free up storage space (tapping "Clear All Storage") shouldn't risk accidentally believing they've also cleared their saved items, or vice versa — ambiguous naming on destructive actions is a real risk of unexpected data loss from simple scope confusion.
- **Suggested implementation approach:** Rename both buttons to be scope-explicit, and/or expand their confirmation dialogs with explicit scope text.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Settings summary

The strongest finding here is **SETTINGS-02** — a user-facing toggle that
has been completely non-functional, contradicting the app's own written
accessibility convention. This should be treated with similar urgency to the
Top 20's other P1 correctness bugs, since a demonstrably broken toggle (once
noticed) undermines confidence in every other toggle on the screen. Settings
otherwise shows strong baseline discipline (SETTINGS-08/09/10/11 are all
genuine PASSes, and SETTINGS-10 further confirms `IMPLEMENTATION_NOTES.md`'s
stale "still needs native work" claims first identified in PODCAST-05). The
remaining findings are consistency/clarity gaps (SETTINGS-01, SETTINGS-03,
SETTINGS-12) rather than functional breaks.
