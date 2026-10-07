# AppleVis Adaptive iPadOS Upgrade — Implementation Specification

## 1. Objective
Make AppleVis feel intentionally designed for iPadOS while keeping one SwiftUI codebase and preserving the existing iPhone UI/navigation behavior. The implementation must respond to the current window width/size class so it also behaves correctly in iPad Split View and Stage Manager.

## 2. Existing architecture that must be preserved

### Top-level navigation
`AppleVis/Sources/App/ContentView.swift` uses a three-tab `TabView`:
- Home
- Discover
- For You

This is the current product information architecture and must remain intact.

### Shared stack behavior
`AppleVis/Sources/Views/Shared/AppNavigationStack.swift` owns its own `NavigationPath` and provides `OpenAtFirstNewCommentAction` through the environment. This solved a real navigation inconsistency. Any adaptive navigation infrastructure must preserve equivalent behavior in the active navigation container.

### Discover routing
`DiscoverView.swift` owns `navigationPath` and destinations for hub areas and content. It also contains explicit VoiceOver focus-restoration logic based on whether the path is empty. Preserve these semantics when adapting the hub.

### Accessibility baseline
Source comments record fixes for reported VoiceOver focus, announcements, adjustable controls, navigation, mini-player positioning, etc. Treat those comments as regression tests in prose. Existing accessibility behavior takes precedence over aesthetic iPad polish.

## 3. Adaptive-layout rule
Use environment-driven adaptive presentation:
- Compact horizontal environment: existing `NavigationStack` push/pop behavior.
- Sufficiently wide/regular environment: `NavigationSplitView` only for master/detail workflows.
- Layout must react correctly when a Stage Manager or Split View window crosses compact/regular boundaries at runtime.
- State/selection should survive a width-class transition whenever practical.

Prefer `@Environment(\.horizontalSizeClass)` and SwiftUI adaptive containers. If actual width is needed for a specific component, use container-relative/layout APIs rather than device model checks.

Do not assume every `.regular` environment must show two columns. Content usefulness determines whether split presentation is appropriate.

## 4. Shared adaptive navigation infrastructure
Create small, comprehensible shared primitives rather than a giant generic router.

Recommended concepts (names may change to fit the codebase):
- `AdaptiveMasterDetailContainer` or domain-specific split wrappers.
- A consistent compact/regular selection model.
- Reusable empty-detail placeholder for wide layouts where nothing is selected.

Requirements:
- Preserve standard SwiftUI navigation semantics.
- Preserve `openAtFirstNewComment` behavior.
- Avoid nested `NavigationStack`s; existing Settings comments explicitly document why nested stacks caused failures.
- Avoid type-erasing more navigation state than necessary.
- Back behavior on compact widths must remain familiar and identical to current iPhone behavior.
- On wide layouts, selecting a row updates detail without unnecessary modal presentation.

## 5. Forums — highest-priority master/detail conversion
Files of interest:
- `Views/Forums/ForumsBrowseView.swift`
- `Views/Forums/ForumTopicDetailView.swift`
- `Views/Shared/RowViews.swift` (`ForumTopicRow`)
- related forum destinations/endpoints/models

### Compact
Preserve current list -> pushed topic detail navigation.

### Wide
Use a two-column split where the forum/topic list remains visible and selected `ForumTopicDetailView` appears in detail.

Requirements:
- A selected topic should remain selected across ordinary refreshes if it still exists.
- Deleting/unavailable content must clear or replace invalid selection safely.
- Filtering/searching must not leave an invalid invisible detail selection without sensible handling.
- Opening “first new comment” must still focus/scroll to the correct comment in the detail.
- Deep links to a forum topic must result in an intelligible wide layout and correct detail.
- Compose/filter/report sheets should remain appropriate modal flows.
- VoiceOver focus stays on the activated topic/list context unless the user explicitly navigates into detail; do not forcibly post screen-changed focus into detail merely because selection changed.
- Provide useful column titles/headings for VoiceOver.
- Test collapse from wide to compact with a selected topic; the selected topic should become the visible pushed/detail content rather than disappearing.

## 6. Apps / App Directory — master/detail conversion
Files of interest:
- `Views/Apps/AppBrowseView.swift`
- `Views/Apps/AppDetailView.swift`
- `Views/Shared/RowViews.swift` (`AppListingRow`)
- Discover routing for app destinations

### Compact
Preserve current category/list -> pushed app detail behavior.

### Wide
Where an app list/search-result list is visible, allow selected app details in the detail column.

Do not force a split at the initial alphabetized category picker if it creates an empty/unhelpful detail experience. It is acceptable for category selection to establish the master list first, then use list/detail for actual apps.

Requirements:
- Platform picker remains fully accessible, including its current adjustable action and spoken value.
- Search result selection should work naturally in wide mode.
- Existing app deletion/removal callbacks continue to update selection safely.
- Detail actions, reviews, links, editing/reporting and first-new-comment behavior remain functional.
- No hard-coded iPad widths.

## 7. Discover hub — adaptive presentation without changing IA
File: `Views/Discover/DiscoverView.swift`

The Discover hub remains inside the Discover tab. Do not create a global app sidebar from the hub categories.

### Hub grid
Current hub uses a fixed two-column `LazyVGrid`. Make it adaptive so larger windows can use available width without producing overly wide cards. Compact widths should retain a comfortable two-column/appropriate compact experience.

Use an adaptive minimum card width chosen through testing with Dynamic Type. Do not optimize only for default text size.

### Search
Discover search currently routes to multiple content kinds. Preserve this. In wide layouts, search results may use detail presentation where the destination domain supports it, but do not create inconsistent routing merely for visual novelty.

### Focus
Preserve `navigationPath.isEmpty` logic and existing tab-return focus behavior. If routing changes make that exact check obsolete, replace it with an equivalent semantic condition and add tests/comments explaining why.

## 8. Podcasts — list/detail plus player behavior
Files of interest:
- `Views/Podcasts/PodcastBrowseView.swift`
- episode detail view(s)
- `Views/Podcasts/PlayerView.swift`
- `Views/Podcasts/QueueView.swift`
- `ContentView.swift` mini-player overlay

### Compact
Preserve current episode navigation and player behavior.

### Wide
Episode lists are a good candidate for master/detail: episodes on leading side, selected episode/show notes/detail on trailing side.

Requirements:
- Playback state is global and must not restart merely because layout changes.
- Mini-player remains pinned to the bottom of the actual app content/tab frame. Preserve the existing `ContentView` overlay fix; do not regress to independent Spacer/ZStack positioning.
- Existing keyboard playback commands continue to work.
- Scrubbers and playback-speed accessibility adjustable actions remain intact.
- 220x220 artwork is acceptable; make changes only if actual layout testing reveals a problem.
- Queue/player sheets should be tested in full-screen iPad and compact Stage Manager widths.

## 9. Settings / Profile
Files of interest:
- `Views/Profile/ProfileView.swift`
- `Views/Settings/SettingsView.swift`
- settings child views

Settings has explicit comments warning against nested `NavigationStack`s. Respect them.

### Compact
Preserve current Profile -> Settings -> settings-area navigation.

### Wide
A Settings list/detail split is desirable if it can be introduced without nested-stack or dismissal regressions:
- leading column: settings areas grouped by current sections
- detail: selected settings area

Requirements:
- Settings search filters the leading list and handles a selected destination that becomes filtered out.
- Done/dismiss semantics remain clear when Settings is presented modally from Profile/keyboard command.
- Account/sign-in remains Profile territory; do not move it into Settings.
- If split conversion would destabilize modal navigation, prioritize correctness and ship Settings as an adaptive-width list first; it is lower priority than Forums/Apps.

## 10. Home and For You
Do not add split view simply because iPad has space.

Audit for:
- excessive line lengths/card widths on very large iPads
- Dynamic Type
- landscape
- Stage Manager narrow/wide windows
- mini-player overlap

Use readable content-width constraints only where long-form text becomes genuinely difficult to read. Do not globally clamp all lists to an iPhone-like column.

## 11. Sheets, popovers, and inspectors
Do not mechanically convert `.sheet` to `.popover`.

For small transient choices (filters, sort menus, compact controls), a popover may be more iPad-native if:
- it remains discoverable with VoiceOver,
- dismissal is predictable,
- compact-width fallback remains appropriate.

Keep compose, authentication, complex forms, guided experiences, and other substantial workflows as sheets/full presentations where appropriate.

## 12. Pointer and trackpad
Standard SwiftUI buttons, links, lists, menus and controls already provide much behavior automatically. Audit custom tappable rows/cards to ensure:
- clear hit targets,
- no touch-only gestures without an alternative,
- hover effects only when they add useful affordance and do not become visual noise,
- context menus remain keyboard/VoiceOver accessible where applicable.

Do not add pointer-only functionality.

## 13. Hardware keyboard
Preserve existing commands. Audit:
- Command-1/2/3 tab switching
- Command-R refresh
- Command-comma Settings
- podcast playback commands
- Escape/dismiss behavior where SwiftUI supplies it
- tab/arrow focus through important controls

New shortcuts are optional; do not create conflicts with text editing or VoiceOver commands.

## 14. VoiceOver and assistive technology requirements
Every phase must preserve:
- VoiceOver labels, values, hints, traits and custom actions
- Braille-friendly meaningful labels
- Switch Control reachability
- Dynamic Type without clipping/truncation of essential information
- Reduce Motion/Transparency, Bold Text, Button Shapes, Increase Contrast behavior
- focus restoration after sheets, filters, deletion, refresh and back navigation

Specific split-view rules:
- Selection changing detail must not automatically steal VoiceOver focus.
- Sidebar/list and detail each need meaningful navigation context/headings.
- On explicit activation where moving to detail is necessary, use the least disruptive standard SwiftUI focus behavior; only post UIAccessibility notifications when needed and documented.
- When collapsing wide -> compact, preserve selected detail and a logical back path.
- When expanding compact -> wide, preserve current content/selection.

## 15. Localization and documentation
Per `AGENTS.md`, for every user-facing change:
- run `tools/l10n_audit.py`
- add/translate strings across all supported languages in the same pass
- add an appropriately tagged `ChangeItem` in `WhatsNewView.swift` for visible/meaningful changes
- check `HelpContent.swift`, `GuidedExperience.swift`, and `TipStore.swift`

Avoid new strings where standard navigation behavior can communicate the same thing.

## 16. Tests to add
Add focused tests where architecture permits. UI tests are particularly valuable for navigation transitions.

Minimum automated coverage goals:
- compact forum topic opens as pushed detail
- wide forum topic selection produces detail
- selected forum topic survives width/layout transition where feasible
- app list/detail equivalent behavior
- Discover hub routing still works
- deep link / first-new-comment routing remains correct
- Settings does not create nested navigation containers

Do not make tests depend on a specific physical iPad model unless necessary.

## 17. Manual device/simulator matrix
At minimum test:
- iPhone compact portrait
- iPhone landscape where supported
- 11-inch iPad portrait and landscape full screen
- 13-inch iPad portrait and landscape full screen
- iPad Split View approximately 1/3, 1/2, 2/3
- Stage Manager small, medium and large windows
- external keyboard
- pointer/trackpad
- VoiceOver ON
- largest practical Dynamic Type/accessibility sizes
- Reduce Motion ON
- Increase Contrast / Button Shapes checks

## 18. Performance and state
Avoid duplicating network fetches merely because both split columns exist. Selection/detail construction should not trigger unnecessary refetch loops during resizing. Playback must remain uninterrupted. Preserve cache and refresh semantics documented in source comments.

## 19. Definition of done
See `IPADOS_UPGRADE_ACCEPTANCE_CHECKLIST.md`. Passing compilation is not sufficient. The feature is done when both compact and wide navigation are coherent, accessibility is preserved, and resize transitions do not lose state or strand the user.

## 17. Ask the Mouse — first-class iPad and keyboard feature
Ask the Mouse is a major AppleVis feature and must be treated as part of the iPadOS upgrade, not as incidental Home/Search content.

Preserve every existing Ask the Mouse entry point and behavior, including Home, Discover/Search integration, saved Mouse answers, recent questions/memory where applicable, and existing Help/Guided Experience documentation. Do not create a second competing Ask the Mouse navigation model.

### Global keyboard access
- Add **Command-M** as the global shortcut for **Ask the Mouse**.
- The command must work from any normal top-level app context where presenting Ask the Mouse is safe.
- If a modal workflow makes immediate presentation unsafe, use standard SwiftUI command/presentation semantics rather than stacking an invalid modal.
- The shortcut title exposed to keyboard discoverability must be exactly/localizably meaningful as “Ask the Mouse.”

### iPad presentation
- Audit the existing Ask the Mouse view hierarchy and make it comfortable at compact and wide iPad window sizes.
- Prefer adaptive content width and use of available space over device checks.
- Do not make long answer text span an unreadably wide iPad Pro screen; constrain long-form reading width where testing shows it improves readability.
- Question input, suggested/recent questions, answer content, links, follow-up actions, save/share actions, and history/memory controls must remain reachable with touch, VoiceOver, Full Keyboard Access, and pointer/trackpad.
- Stage Manager resize must not discard an in-progress question or completed answer.
- VoiceOver focus must remain predictable when an answer arrives. Do not force focus away from the user's current context without a clear existing product reason.
- Test long answers and large Dynamic Type, including links and actionable citations/resources in answers.

## 18. Contact AppleVis — global keyboard access
Preserve Contact AppleVis in Profile and all existing guided contact-form behavior.

Add **Command-Shift-C** as a global shortcut titled **Contact AppleVis**. Never use Command-C because Copy must retain the system-standard shortcut.

Requirements:
- Shortcut opens the existing Contact AppleVis experience; do not create a duplicate form.
- Existing form categories, validation, translation/writing tools, submission behavior, dismissal, and accessibility must remain intact.
- Test presentation from each top-level tab and from wide/compact iPad layouts.
- If another modal is active, avoid invalid double presentation and preserve the user's work.

## 19. Expanded hardware keyboard strategy
Keyboard support is a first-class iPad accessibility/input mode. Keep global shortcuts intentionally small and memorable; use contextual shortcuts for domain-specific actions.

### Required global shortcuts
- Command-1: Home (existing)
- Command-2: Discover (existing)
- Command-3: For You (existing)
- Command-R: Refresh current refreshable context (existing semantics)
- Command-comma: Settings (existing)
- Command-M: Ask the Mouse (new)
- Command-Shift-C: Contact AppleVis (new)
- Command-F: Search the current searchable context, when applicable

### Contextual shortcuts to implement where they map cleanly to an existing action
- Command-N: New Topic in a forum context where creating a topic is available.
- Command-Shift-S: Save/Unsave current saveable AppleVis item, only where conflict-free and semantically clear.
- Escape: dismiss active transient search/popover/sheet/menu where SwiftUI/system behavior does not already provide it.
- Return: activate/open the keyboard-selected list/sidebar item where standard controls do not already do so.
- Arrow keys: use standard list/sidebar navigation; do not replace native keyboard navigation with custom key handling unless needed.
- Podcast Space/arrow playback controls: preserve existing behavior and avoid conflicts when text entry or another control owns those keys.

Do not add Command-[ or other browser-like shortcuts merely for completeness if native SwiftUI navigation already provides the expected behavior. Prefer system conventions and avoid shortcut collisions with text editing, VoiceOver, Full Keyboard Access, or macOS-style standard commands.

### Discoverability
All explicit commands must have localized, human-readable command titles so the iPad hardware-keyboard shortcut overlay/menus can explain them. Do not require memorization of key combinations.

### Focus and accessibility
- Full Keyboard Access users must be able to reach and activate every major app function without touch.
- Hardware keyboard focus and VoiceOver focus must remain coherent, but do not artificially force them to mirror one another.
- Master/detail selection must not automatically throw VoiceOver into detail.
- Test keyboard operation with VoiceOver enabled, including Ask the Mouse question entry and Contact AppleVis forms.
- Test text fields/text editors so global shortcuts do not steal normal editing commands.

## 20. Keyboard and major-destination QA matrix
At minimum manually test these combinations:
- Full-screen iPad portrait: touch; hardware keyboard; VoiceOver + keyboard.
- Full-screen iPad landscape: hardware keyboard; VoiceOver + keyboard.
- Stage Manager narrow and wide: global commands and contextual commands.
- Forums wide split: list navigation, open topic, New Topic, Search, Save where supported.
- Apps wide split: list navigation, Search, Save where supported.
- Podcasts: browse plus existing playback keys.
- Ask the Mouse: Command-M, type question, submit, navigate answer, follow links/actions, save/share, dismiss/return.
- Contact AppleVis: Command-Shift-C, complete fields, validation, submit/dismiss without losing unrelated navigation state.
- Settings: Command-comma and dismissal back to prior context.

# 2026 Adaptive Experience Expansion — iPhone, iPhone Duo, and iPad

This section supersedes any iPad-only framing elsewhere in this document. The implementation remains one universal SwiftUI app and one adaptive architecture.

## Platform goal
Support compact iPhone, iPhone Duo outer display, iPhone Duo inner display and all supported poses, iPad full screen, iPad Split View, Stage Manager, and other resizable windows without device-model-specific UI forks. Prefer SwiftUI size classes, scene/window geometry, standard navigation, safe areas, and adaptive presentations. Do not make layout decisions from interface orientation or a hard-coded `isPad`/Duo check when available space is the real requirement.

## iPhone Duo requirements
- Build/test with Xcode 27.1 SDK and iPhone Duo Device Hub/simulator support.
- Audit every major destination in opened, closed, rotated, folded/tent-like poses and Split View configurations.
- Use horizontal/vertical size classes for compact vs expanded experience. A regular-width Duo inner display may use the same master/detail concepts as a wide iPad window.
- `NavigationSplitView` must collapse cleanly to stack navigation when space becomes compact and expand without losing the current logical selection.
- Never assume opposing safe-area or layout-margin insets are equal. Audit custom bars, overlays, mini-player, floating controls, artwork, search UI, Ask the Mouse composer, and bottom controls for asymmetric insets.
- Avoid `UIScreen.main` and screen-size assumptions. Prefer local SwiftUI environment/geometry and scene bounds only where needed.
- Preserve current tab, navigation selection, forum/topic, app, episode, Ask the Mouse conversation, search/filter state where reasonable, and uninterrupted podcast playback through geometry/pose changes.
- Test VoiceOver focus across compact↔regular transitions. Layout changes must not dump focus to the first element or unexpectedly move it from list/sidebar to detail.
- Respect standard safe areas for interactive foreground controls; full-bleed backgrounds may extend appropriately.
- Review custom edge UI for iOS 27.1 `ReservedRegion` only when standard bars/safe areas cannot express the desired result; do not introduce custom geometry merely to use the API.

## Deep-link and routing architecture
Create or consolidate a typed, testable internal routing layer so major destinations can be reached consistently from UI, keyboard commands, notifications, App Intents, Spotlight/Siri/Shortcuts, and future integrations. Preserve existing deep links and add routes only where missing. Required routable destinations include Ask the Mouse, Contact AppleVis, Home, Discover, For You, Forums/forum/topic, Podcasts/episode/player, Apps/app detail, Saved Items, Profile and Settings. Invalid/stale routes must fail safely and accessibly.

## State restoration and continuity
Define lightweight restorable navigation state separate from transient view state. Restore the selected top-level tab and meaningful content selection after scene recreation where appropriate. Geometry changes alone must not reset navigation. Do not persist sensitive/transient authentication data. Podcast playback remains owned by the existing playback architecture and must not restart because a layout changes.

## App Intents, Siri, Shortcuts and Spotlight
Add a focused App Intents layer for high-value, stable actions; do not expose every button. Candidate intents: Ask the Mouse, Search AppleVis, Open Saved Items, Open Forums, Open latest/selected podcast experience, and Contact AppleVis. Reuse the typed routing layer rather than duplicating navigation logic. Provide concise localized titles/descriptions and useful parameters only where they improve the action. Ensure VoiceOver-friendly result/dialog text. If an intent requires app UI, open the correct route predictably. Keep privacy/authentication boundaries intact.

## Keyboard, Full Keyboard Access and pointer
Retain existing shortcuts and add Command-M (Ask the Mouse), Command-Shift-C (Contact AppleVis), Command-F (contextual search), plus approved contextual actions such as New Topic and Save/Unsave. Preserve standard system shortcuts such as Command-C. All commands need discoverable localized names. Certify Full Keyboard Access for major workflows: tabs, sidebars/lists, detail views, search, dialogs/sheets, Ask the Mouse, Contact AppleVis and podcast playback. Add pointer/trackpad polish using standard controls/hover/context-menu behavior where useful; no required action may be pointer-only or touch-only.

## Ask the Mouse
Treat Ask the Mouse as a first-class adaptive destination. Preserve all existing entry points and saved-answer behavior. Optimize its conversation/history, suggestions and composer for compact and regular widths without creating a separate iPad/Duo implementation. Preserve conversation and draft where reasonable through resizing/pose changes. Verify VoiceOver reading order, focus after sending/receiving, keyboard focus, Dynamic Type, Reduce Motion, safe-area handling and Command-M routing.

## Sharing, drag and drop
Audit forum links/topics, AppleVis app entries, podcast episodes and other shareable content for standard ShareLink/share-sheet behavior. Add drag-and-drop only where it is natural and low-risk, using system representations and accessible alternatives. Sharing must remain available without drag gestures.

## Performance during resizing
Audit for expensive network fetches, parsing, image work or state resets triggered by geometry/size-class changes. A resize/fold/unfold event must not cause duplicate content loads solely because the view changed presentation. Profile list/detail transitions and Ask the Mouse/podcast continuity where practical.

## Automated tests
Add focused tests for typed routes/deep links, state restoration serialization where applicable, compact/regular adaptive decisions, keyboard command routing, and App Intent routing/business logic. Add UI tests for representative compact and regular navigation paths where stable. Accessibility identifiers may be added when they improve reliable testing, but visible labels must remain human-friendly and localized.

## Release readiness
Before release, test representative iPhones, iPhone Duo across Device Hub poses/orientations, and iPads in portrait/landscape, Split View and Stage Manager. Run VoiceOver, Full Keyboard Access, Dynamic Type, Reduce Motion, pointer/trackpad, light/dark and localization checks. Prepare iPhone Duo App Store screenshots/assets according to current App Store Connect requirements and preview them in the Duo product-page preview. Record any device-specific known limitations before TestFlight/App Review.

## Explicitly out of scope
Do NOT add Widgets, Live Activities, watchOS, visionOS, a separate iPad target, or a separate iPhone Duo target as part of this upgrade. Do not redesign the three-tab information architecture.
