# AppleVis iPadOS Upgrade — Codex Start Here

## Goal
Upgrade the existing universal AppleVis SwiftUI app into a polished adaptive iPadOS experience while preserving the current iPhone experience and the project's unusually mature accessibility behavior.

This is an incremental upgrade of the existing application, not a redesign and not a second iPad target.

## Read before editing
1. `AGENTS.md` — mandatory project rules.
2. `docs/APPLEVIS_2026_1_MASTER_SPEC.md`, especially **iPadOS Requirements**.
3. `docs/IPADOS_UPGRADE_IMPLEMENTATION_SPEC.md` — authoritative implementation plan for this upgrade.
4. `docs/IPADOS_UPGRADE_ACCEPTANCE_CHECKLIST.md` — definition of done.
5. `docs/IPADOS_UPGRADE_CODEX_PROMPTS.md` — ordered implementation prompts.
6. Existing source comments around accessibility/focus/navigation. Many document fixes for real reported regressions; do not remove or casually rewrite them.

`AGENTS.md` also points to local Claude project memory on the owner's development machine. If that file is available in the Codex environment, read it and relevant linked memories before changing code. If it is not available, do not block: follow `AGENTS.md`, the repository docs, source comments, and this package.

## Current state confirmed from repository
- Universal target: `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad).
- iPad supports portrait, upside-down, and both landscape orientations.
- SwiftUI application with three top-level tabs: Home, Discover, For You.
- `NavigationStack` is the current navigation model; there are currently no `NavigationSplitView` usages.
- `AppNavigationStack` owns a local `NavigationPath` and injects `openAtFirstNewComment`; preserve this behavior.
- Existing keyboard commands and substantial VoiceOver/focus-restoration work already exist.
- Master spec requires native iPad layout, master/detail split view, mini-player at bottom, keyboard navigation/shortcuts, pointer support, Stage Manager, portrait and landscape.

## Non-negotiable product decisions
- KEEP the three-tab Home / Discover / For You information architecture.
- DO NOT turn Forums, Podcasts, Apps, Resources into new top-level tabs/sidebar destinations. The master spec explicitly says its older sidebar list must be interpreted through the current three-tab/Discover-hub model.
- Adapt by available horizontal space / size class, not `UIDevice.current.userInterfaceIdiom == .pad` alone. Narrow iPad Split View or Stage Manager should be allowed to use compact stack navigation.
- Do not globally replace every `NavigationStack` with `NavigationSplitView`.
- Use split navigation only where persistent list/detail materially improves the experience.
- Preserve all current iPhone behavior unless a change is necessary to share safe adaptive infrastructure.
- Preserve deep links, first-new-comment navigation, search, refresh, sheets, authentication flows, playback, and focus restoration.
- Do not make automatic detail selection steal VoiceOver focus from the list/sidebar.
- Do not use fixed screen widths to identify iPad layouts.

## Recommended order
Implement one prompt/phase at a time from `docs/IPADOS_UPGRADE_CODEX_PROMPTS.md`. Build and test after each phase. Do not batch all phases into one unreviewable patch.

## Completion deliverable
The upgrade is complete only when the acceptance checklist passes in compact and regular layouts, including VoiceOver, Dynamic Type, external keyboard, pointer/trackpad, Split View and Stage Manager resizing.

## Important revision: Ask the Mouse and hardware keyboard support
This package supersedes earlier iPadOS-upgrade packages. Ask the Mouse is a first-class feature in this upgrade, not an optional follow-up. Complete Prompts 9–11 after the original adaptive-layout phases. The required new global shortcuts are Command-M for Ask the Mouse and Command-Shift-C for Contact AppleVis, alongside the expanded keyboard requirements in the implementation spec. Preserve existing Ask the Mouse and Contact AppleVis flows; do not duplicate them.

## DEFINITIVE PACKAGE NOTICE
For this package, begin with `CODEX_ADAPTIVE_EXPERIENCE_START_HERE.md`. The adaptive-experience document and Prompts 12–18 expand this work to iPhone Duo, system integration, state restoration and final cross-device certification. Widgets and Live Activities remain explicitly out of scope.
