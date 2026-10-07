# AppleVis Adaptive Experience Upgrade — Codex Start Here

This is the definitive upgrade package. It supersedes the earlier iPadOS-only framing.

## Mission
Upgrade the existing AppleVis universal SwiftUI app into one polished adaptive experience spanning iPhone, iPhone Duo and iPad, while preserving the current iPhone experience and the project's mature accessibility behavior.

## Required reading, in order
1. `AGENTS.md`
2. `CODEX_IPADOS_UPGRADE_START_HERE.md` (existing project-specific baseline; interpret its iPad wording through this document)
3. `docs/APPLEVIS_2026_1_MASTER_SPEC.md`
4. `docs/IPADOS_UPGRADE_IMPLEMENTATION_SPEC.md` including the Adaptive Experience Expansion
5. `docs/IPADOS_UPGRADE_ACCEPTANCE_CHECKLIST.md` including the Duo/System Integration addendum
6. `docs/IPADOS_UPGRADE_CODEX_PROMPTS.md`, completing all prompts through Prompt 18

## Non-negotiable scope
- One universal app and adaptive architecture; no separate iPad or Duo target.
- Preserve Home / Discover / For You.
- Ask the Mouse is first-class, with Command-M.
- Contact AppleVis remains in Profile and is globally reachable with Command-Shift-C.
- Include expanded keyboard support, Full Keyboard Access, pointer/trackpad, state restoration, typed deep links, App Intents/Siri/Shortcuts/Spotlight integration, sharing review, adaptive performance work, automated tests and release readiness.
- Use size classes/available space, not device-name or orientation assumptions, for layout.
- Treat VoiceOver focus continuity through layout/pose transitions as a release requirement.
- Widgets and Live Activities are explicitly OUT OF SCOPE. Do not add them.

## Current Apple requirements to validate against during implementation
The planning package was updated October 6, 2026 based on Apple's current iPhone Duo guidance: use Xcode 27.1/Device Hub, design for dynamic resizing and all poses, use size classes instead of orientation assumptions, respect asymmetric safe areas, and prepare Duo App Store assets. Before release, re-check current Apple documentation because submission requirements can change.

## Execution
Work phase-by-phase and keep patches reviewable. Build/test after each phase. Earlier phases may be refactored when later Duo/system-integration work reveals a cleaner shared architecture; do not accumulate parallel iPad and Duo code paths.

## Definition of done
The complete acceptance checklist passes across representative iPhone, iPhone Duo and iPad configurations, including VoiceOver and keyboard/pointer testing, and project documentation/localization obligations in AGENTS.md are satisfied.
