# AppleVis iPadOS Upgrade — Acceptance Checklist

Use this as the release gate for the adaptive iPadOS work.

## Build / baseline
- [ ] Project builds with the repository's supported Xcode/SDK configuration.
- [ ] Existing unit/UI tests pass.
- [ ] iPhone target behavior remains functionally equivalent unless an intentional change is documented.
- [ ] Universal target still supports iPhone and iPad.

## Top-level app
- [ ] Home / Discover / For You remain the three top-level tabs.
- [ ] Tab keyboard shortcuts still work.
- [ ] Mini-player remains pinned above the tab bar and never jumps to the top during push/pop or resizing.
- [ ] Deep-link sheets/routes still open and dismiss correctly.
- [ ] Command-comma Settings remains functional.

## Adaptive behavior
- [ ] Compact widths use stack navigation where expected.
- [ ] Wide master/detail screens use split navigation where specified.
- [ ] No layout is selected solely because the hardware is an iPad.
- [ ] Resizing Stage Manager across compact/regular widths does not crash or strand navigation.
- [ ] Current selection/detail is preserved sensibly across width changes.
- [ ] No important view uses arbitrary iPad screen-width constants.

## Forums
- [ ] Compact: topic opens as normal pushed detail.
- [ ] Wide: topic list remains visible with selected topic in detail.
- [ ] First-new-comment action still lands/focuses correctly.
- [ ] Refresh preserves valid selection.
- [ ] Filter/search does not leave broken detail state.
- [ ] Deleted/unavailable selected topic is handled gracefully.
- [ ] Compose/report/filter presentations still work.
- [ ] VoiceOver focus is not stolen merely because selection updates.

## Apps
- [ ] Compact app navigation unchanged.
- [ ] Wide app list/search results can display selected app detail.
- [ ] Platform picker still announces current value and supports adjustable action.
- [ ] App removal/deletion updates detail selection safely.
- [ ] Reviews/actions/edit/report/link flows still work.
- [ ] First-new-comment behavior remains correct.

## Discover
- [ ] Hub retains current information architecture.
- [ ] Hub grid adapts gracefully to window width.
- [ ] Dynamic Type does not make grid cards unusable.
- [ ] Search continues to route all supported content types.
- [ ] Existing tab-return/search focus logic remains correct with VoiceOver.

## Podcasts
- [ ] Compact episode navigation unchanged.
- [ ] Wide episode list/detail works where implemented.
- [ ] Playback continues through resize/layout transitions.
- [ ] Mini-player remains correctly positioned.
- [ ] Player keyboard commands work.
- [ ] Scrubbers/playback speed retain accessibility adjustment behavior.
- [ ] Queue and player presentations work at narrow and wide iPad widths.

## Settings/Profile
- [ ] No nested NavigationStack regression.
- [ ] Compact Settings navigation works.
- [ ] Wide Settings split works if implemented.
- [ ] Settings search handles selected destinations correctly.
- [ ] Done/dismiss behavior is predictable.
- [ ] Profile/account/sign-in structure is unchanged.

## Accessibility
- [ ] VoiceOver can traverse list/sidebar and detail predictably.
- [ ] Selection does not unexpectedly move VoiceOver into detail.
- [ ] Explicit navigation into detail has logical focus.
- [ ] Back/collapse/expand maintains a coherent focus target.
- [ ] Braille labels remain meaningful.
- [ ] Switch Control can reach all interactive elements.
- [ ] Dynamic Type tested through accessibility sizes.
- [ ] No essential text is clipped at large sizes.
- [ ] Reduce Motion respected.
- [ ] Increase Contrast, Bold Text, Button Shapes and Reduce Transparency checked.
- [ ] Existing accessibility custom actions still work.

## iPadOS interaction
- [ ] Portrait full screen tested.
- [ ] Landscape full screen tested.
- [ ] Split View narrow/half/wide tested.
- [ ] Stage Manager small/medium/large tested.
- [ ] External keyboard navigation tested.
- [ ] Pointer/trackpad tested.
- [ ] No touch-only functionality.

## Localization / project process
- [ ] `tools/l10n_audit.py` passes.
- [ ] Any new user-facing strings translated for all supported languages.
- [ ] `WhatsNewView.swift` updated for visible/meaningful iPad changes.
- [ ] `HelpContent.swift` checked/updated.
- [ ] `GuidedExperience.swift` checked/updated.
- [ ] `TipStore.swift` checked/updated.
- [ ] New code follows `AGENTS.md` and relevant project memory when available.

## Final release gate
- [ ] No known P0/P1 accessibility regression.
- [ ] No navigation state loss during normal iPad resize transitions.
- [ ] iPhone experience remains polished.
- [ ] iPad experience no longer feels like a stretched iPhone layout in master/detail areas.

## Ask the Mouse
- [ ] Existing Ask the Mouse entry points still work; no duplicate competing flow was introduced.
- [ ] Command-M opens the existing Ask the Mouse experience from each top-level tab.
- [ ] Ask the Mouse adapts cleanly between compact and wide iPad windows.
- [ ] Resizing does not lose an in-progress question or completed answer.
- [ ] Long answers remain comfortably readable on large iPads and at large Dynamic Type sizes.
- [ ] Question input, answer content, links, follow-ups, save/share and relevant history controls are keyboard reachable.
- [ ] VoiceOver focus remains predictable when an answer appears.
- [ ] VoiceOver + hardware keyboard can complete the core Ask the Mouse workflow.

## Contact AppleVis
- [ ] Existing Profile entry point remains unchanged.
- [ ] Command-Shift-C opens the existing Contact AppleVis flow.
- [ ] Command-C remains standard Copy and is not intercepted.
- [ ] Contact form fields, validation, writing/translation tools, submission and dismissal still work.
- [ ] Shortcut presentation is safe from Home, Discover and For You and does not create invalid stacked modals.

## Expanded keyboard support
- [ ] Command-1/2/3 continue to select Home/Discover/For You.
- [ ] Command-R retains correct refresh semantics.
- [ ] Command-comma opens Settings and returns to the prior context on dismissal.
- [ ] Command-M opens Ask the Mouse.
- [ ] Command-Shift-C opens Contact AppleVis.
- [ ] Command-F focuses/opens search in searchable contexts without interfering with text editing.
- [ ] Command-N creates a new forum topic only in appropriate forum contexts.
- [ ] Command-Shift-S saves/unsaves only where semantically appropriate and conflict-free.
- [ ] Existing podcast keyboard playback controls still work and do not steal keys during text entry.
- [ ] Explicit shortcuts have localized human-readable command titles/discoverability.
- [ ] Full Keyboard Access can reach all major controls and destinations without touch.
- [ ] Keyboard focus and VoiceOver focus remain coherent in master/detail layouts.
- [ ] Global commands do not break standard text-field/text-editor shortcuts.

# Adaptive Experience Addendum — iPhone Duo + System Integration

- [ ] One universal adaptive architecture serves iPhone, iPhone Duo and iPad; no separate Duo/iPad target.
- [ ] No layout decision relies on interface orientation or hard-coded Duo/iPad screen dimensions when size class/available space is appropriate.
- [ ] iPhone Duo tested in Device Hub across opened, closed, rotated/folded supported poses and Split View configurations.
- [ ] Interactive UI respects potentially asymmetric safe areas and margins on every Duo configuration.
- [ ] Compact↔regular transitions preserve current tab and meaningful content selection without navigation resets.
- [ ] Podcast playback continues uninterrupted through resizing/pose transitions.
- [ ] Ask the Mouse conversation/draft state survives layout transitions where reasonable.
- [ ] VoiceOver focus remains predictable across fold/unfold and compact↔regular transitions.
- [ ] Typed/deep routes exist and are tested for Ask the Mouse, Contact AppleVis, major tabs, Forums/topics, Podcasts/episodes, Apps/details, Saved Items, Profile and Settings.
- [ ] Stale/invalid deep links fail safely and accessibly.
- [ ] App Intents use shared routing/business logic and include the approved high-value actions.
- [ ] Siri/Shortcuts/App Intent titles, dialogs and parameter strings are localized and accessible.
- [ ] Command-M opens Ask the Mouse globally and Command-Shift-C opens Contact AppleVis globally.
- [ ] Command-F invokes appropriate contextual search; existing shortcuts continue to work.
- [ ] Holding Command presents meaningful discoverable shortcut names where supported.
- [ ] Major workflows are operable with Full Keyboard Access without touch.
- [ ] Pointer/trackpad operation is complete; no essential action is pointer-only.
- [ ] Share sheet works for appropriate forum, app and podcast content; drag/drop, if added, has a non-drag alternative.
- [ ] Geometry changes do not trigger unnecessary duplicate network/content loads.
- [ ] Automated tests cover routing, restoration/adaptive decisions, shortcut routing and App Intent integration where practical.
- [ ] TestFlight matrix includes representative iPhone, iPhone Duo and iPad configurations plus VoiceOver/Dynamic Type/Reduce Motion.
- [ ] Current iPhone Duo App Store screenshot/assets are prepared and previewed in App Store Connect before release.
- [ ] Widgets and Live Activities have NOT been added as part of this upgrade.
