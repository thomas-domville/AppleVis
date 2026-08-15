# AppleVis Native Product & Accessibility Improvement Audit — Index

Audit of `AppleVisSwift` (native Swift/SwiftUI, current live app) as the product
baseline, per `09_MASTER_CODEX_IMPROVEMENT_AUDIT_PROMPT.md` and the accompanying
audit package. Read-only audit — no source files were modified. Legacy Expo app
consulted for product intent only, not parity.

Status vocabulary: BUG / ACCESSIBILITY DEFECT / UX INCONSISTENCY /
VISUAL-LOW-VISION ISSUE / BRAILLE ISSUE / PERFORMANCE ISSUE / ARCHITECTURE ISSUE /
TEST GAP / IMPROVEMENT / FUTURE IDEA / MANUAL VERIFY / PASS.

Priority: P0 Release/data/severe accessibility blocker · P1 High-impact daily
experience · P2 Important consistency/usability · P3 Polish · P4 Future
enhancement.

## Documents

1. `01_TOP_20_FINDINGS.md` — highest-impact findings across the whole app
2. `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` — the shared card/action system (CARD-01…13); read this first, most other docs reference it
3. `03_SCREEN_HOME.md`
4. `04_SCREEN_FORUMS.md`
5. `05_SCREEN_PODCASTS.md`
6. `06_SCREEN_APPS.md`
7. `07_SCREEN_GUIDES_RESOURCES.md`
8. `08_SCREEN_BLOGS.md`
9. `09_SCREEN_BUG_TRACKER.md`
10. `10_SCREEN_DISCOVER_SEARCH.md`
11. `11_SCREEN_FOR_YOU.md`
12. `12_SCREEN_PROFILE_ONBOARDING.md`
13. `13_SCREEN_SETTINGS.md`
14. `14_SCREEN_GUIDED_EXPERIENCE_HELP.md`
15. `15_SCREEN_SUBMISSION_FLOWS.md`
16. `16_ENGINEERING_ARCHITECTURE_CONCURRENCY_NETWORKING.md`
17. `17_ENGINEERING_PERSISTENCE_PERFORMANCE_SECURITY_TESTING.md`
18. `18_ACCESSIBILITY_CERTIFICATION_GAPS.md`
19. `19_IMPLEMENTATION_ROADMAP.md`

## Methodology

Findings were gathered by direct source inspection of
`AppleVisSwift/AppleVisSwift/AppleVisSwift/Sources` (132 Swift files, ~25.6k
lines), cross-referenced against `docs/IMPLEMENTATION_NOTES.md` and
`docs/APPLEVIS_2026_1_MASTER_SPEC.md` for stated product intent and existing
accessibility conventions, and against the `KNOWN_CURRENT_FINDINGS.md` starter
list (each item independently re-verified against current source, not assumed).
Six parallel research passes covered Forums; Podcasts; Apps/Guides/Blogs/Bugs;
Discover/Search/For You/Profile/Onboarding; Settings/Guided Experience/Help/
Submission flows; and Engineering (architecture, concurrency, networking,
persistence, performance, security, testing). The shared card/action system and
Home were audited directly by the lead pass, since they are the highest-leverage
and most cross-cutting surfaces in the app.

This index is updated as each document is finalized.
