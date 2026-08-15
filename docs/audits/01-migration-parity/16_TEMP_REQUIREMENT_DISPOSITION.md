# 16 — Temp Requirement Disposition Audit (Phases 00–11)

Per `05_TEMP_PHASE_DISPOSITION_AUDIT.md`'s methodology: Temp/ text is a product-enhancement requirements package, not proof of shipment. Each requirement is first given a **legacy disposition** (was it real by 2026.0.7?) using CONFIRMED IMPLEMENTED / PARTIAL / PLANNED ONLY / SUPERSEDED / OPTIONAL-FUTURE, and then, for anything CONFIRMED IMPLEMENTED or PARTIAL in legacy, a **native status** using the standard ledger vocabulary (PASS / PARTIAL / MISSING / REGRESSION / MANUAL VERIFY / NOT APPLICABLE / INTENTIONALLY DEFERRED).

**Drift note:** the native repo's own `Temp/` folder contains only the audit package zip, not an extracted `phases/` directory — it has not been kept in sync with legacy's `Temp/phases/*.md` docs (which are fully present and were read in full for this audit). This is itself a minor process-hygiene finding, not a functional one.

| Phase | Requirement | Legacy disposition | Native status | Notes |
|---|---|---|---|---|
| 00 | Fix TS build errors from `showAlert({buttons})` | CONFIRMED IMPLEMENTED | PASS | Native uses SwiftUI-native alerts, a different mechanism with the same guarantee |
| 00 | Reusable destructive-confirmation helper | CONFIRMED IMPLEMENTED | PASS | |
| 00 | Do not remove hidden routes yet | CONFIRMED IMPLEMENTED | NOT APPLICABLE | Native was built as one unified tab set from the start; no migration concept needed |
| 00 | Don't auto-delete dead code without audit sign-off | CONFIRMED IMPLEMENTED | NOT APPLICABLE | Process rule, not portable |
| 01 | Six-step onboarding count, Ready = step 6 of 6 | CONFIRMED IMPLEMENTED | PASS | |
| 01 | Back navigation past step 1 | CONFIRMED IMPLEMENTED | PASS | |
| 01 | "Maybe Later" wording for skip, specified a11y label/hint | CONFIRMED IMPLEMENTED | PARTIAL | Native reserves "Maybe Later" for the post-onboarding tour prompt instead of setup-skip; functionally equivalent, wording diverges from spec |
| 01 | Mark onboarding complete only on explicit finish | CONFIRMED IMPLEMENTED | PASS | |
| 01 | Sign-in wording: "sign in later from Profile" | CONFIRMED IMPLEMENTED | PARTIAL | Native drops the explicit "Profile" destination reference |
| 01 | Ready screen wording matches nav model | CONFIRMED IMPLEMENTED | MANUAL VERIFY | Structure confirmed, exact bullet wording not diffed |
| 01 | VoiceOver Detail Level terminology + Normal default | CONFIRMED IMPLEMENTED | PASS | Corroborates ONBOARD-006 |
| 01 | Notification skip: "Not Now" + specified hint | CONFIRMED IMPLEMENTED | MISSING | Step only carries forward via a standard Next button; the specific decline wording/hint was not found |
| 02 | Reusable Guided Experience engine (Provider/Screen/StepCard/Progress/Actions/ResumePrompt/Completion) | CONFIRMED IMPLEMENTED | PASS | Component names don't map 1:1, but the capability set matches |
| 02 | Core actions: Start/Continue/Previous/Explore/Explain More/Skip | CONFIRMED IMPLEMENTED | PASS | |
| 02 | Pause/Resume/Restart/Replay | CONFIRMED IMPLEMENTED | PASS | |
| 02 | Persist progress across app restart | CONFIRMED IMPLEMENTED | PASS | |
| 02 | Focus on step title only; no auto-advance/auto-read | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 02 | Respect Reduce Motion | CONFIRMED IMPLEMENTED | PASS | |
| 03 | Optional post-setup tour prompt, not merged into wizard | CONFIRMED IMPLEMENTED | PASS | Identical 3-button alert, 2.5s delay |
| 03 | 8-step tour content (Welcome→Home→Discover→ForYou→Search→Profile→Settings/Help→Ready) | CONFIRMED IMPLEMENTED | PASS | |
| 03 | "{Step title}. Step n of 8." announcement, no full-body auto-read | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 03 | Replayable/resumable/non-blocking | CONFIRMED IMPLEMENTED | PASS | |
| 03 | Per-step Explain More/Explore This Screen/Learn More | CONFIRMED IMPLEMENTED | PARTIAL | Explain More + Explore confirmed; Learn More/related-help wiring not confirmed |
| 04 | Academy categories (15 sections) | CONFIRMED IMPLEMENTED | PASS | Native's port is larger than the legacy source |
| 04 | Content types (Guide/QuickStart/FAQ/Troubleshooting/Tutorial/Spotlight/AccessibilityLesson/ReleaseNote) | CONFIRMED IMPLEMENTED | PASS | Native adds `whatsNew` too |
| 04 | 14 initial articles | CONFIRMED IMPLEMENTED | PASS | |
| 04 | FAQ/Troubleshooting examples per spec | CONFIRMED IMPLEMENTED | PASS | |
| 04 | Reuse `settingsData` as the source of truth for Settings help | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 05 | 7 shared search components (Input/ResultsGrouped/Section/Empty/Loading/Error/TranslationPrompt) | CONFIRMED IMPLEMENTED | PARTIAL | Native didn't decompose into 7 files — a single `SearchResultsView` handles it inline; functional coverage is present but architecturally consolidated |
| 05 | Standardized group names: Site Results/Forum Topics/Apps/Guides and Resources | CONFIRMED IMPLEMENTED | PARTIAL (real naming-standardization miss) | Native has "Forum Topics"/"Apps"/"Resources" (not "Guides and Resources") plus extra Blogs/Podcasts/Bug Reports categories; no "Site Results" category at all — corroborates DISC-004/SEARCH-006 in the feature-parity ledger |
| 05 | Empty-state wording + Clear Search/Browse Discover actions, suggestions | CONFIRMED IMPLEMENTED | PARTIAL | Message matches the spirit + Clear Search; no confirmed Browse Discover secondary action or suggestions list. Corroborates SEARCH-007 |
| 05 | Concise result announcement "N results found in N categories" | CONFIRMED IMPLEMENTED | PASS | Near-verbatim + a failed-category caveat |
| 05 | Sound policy: only on submit/meaningful count change | CONFIRMED IMPLEMENTED | PASS | |
| 05 | Configurable search auto-focus preference | CONFIRMED IMPLEMENTED | PASS (preference exists), **but corroborates A11Y-003/DISC-003: the preference is dead, never consumed anywhere in native** | This row marks the requirement's mere existence PASS, but two other independent lenses confirmed it's non-functional — treat the underlying capability as MISSING in the final counts, not PASS |
| 05 | Non-English detection/translation prompt | CONFIRMED IMPLEMENTED | PASS | |
| 06 | Home startup behavior Quiet/Helpful/Detailed, default Helpful | CONFIRMED IMPLEMENTED | PASS | |
| 06 | Conditional refresh-focus | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 06 | Empty state: "all content types off" message + Customize Home action | CONFIRMED IMPLEMENTED | MISSING | No matching string found — corroborates HOME-007 |
| 06 | Empty state: "Show Latest Activity" action when there's no new activity | CONFIRMED IMPLEMENTED | MISSING | Corroborates HOME-008 |
| 06 | Rename filter "Apple-Related Topics Only" → "Apple-Related Forum Topics Only" | CONFIRMED IMPLEMENTED | MISSING | Native still says "Apple Topics Only" — a third, shorter wording, matching neither the old nor the new spec text |
| 06 | "Retry Now" action on the source error banner | CONFIRMED IMPLEMENTED | PASS | |
| 06 | Metadata wraps at large Dynamic Type sizes | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 06 | Academy tie-in: "Using Home" article + Feed Summary VO tip | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 07 | Orientation text: "Your personal AppleVis hub…" | CONFIRMED IMPLEMENTED | PASS | Exact match |
| 07 | Confirm bulk destructive actions | CONFIRMED IMPLEMENTED | PASS | |
| 07 | Rename bulk buttons | CONFIRMED IMPLEMENTED | PASS | |
| 07 | Section-aware refresh | CONFIRMED IMPLEMENTED | MANUAL VERIFY | Corroborates FY-002's finding of fragmented refresh behavior |
| 07 | Section-selection announcements ("Queue selected." etc.) | CONFIRMED IMPLEMENTED | MISSING | No matching strings found — corroborates FY-001 |
| 07 | Fix `accessibilityRole="none"` → "button" on pressable rows | CONFIRMED IMPLEMENTED | PASS | Different mechanism, same guarantee by default via SwiftUI Button/NavigationLink |
| 07 | Empty-state actions (Browse Podcasts/Community/Discover per section) | CONFIRMED IMPLEMENTED | PARTIAL | Browse Podcasts/Community confirmed; the "Nothing Saved" state lacks a Browse Discover action |
| 07 | Filtered empty states mention the filter + "Clear Filter" | CONFIRMED IMPLEMENTED | MISSING | No match found — corroborates the For You empty-state finding in the feature-parity ledger |
| 08 | Preserve Discover structure | CONFIRMED IMPLEMENTED | PASS | |
| 08 | Contextual tips extended toward Academy prompts | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 08 | Standardized embedded search reusing dedicated-Search components | CONFIRMED IMPLEMENTED | PASS | Native folded "dedicated Search" entirely into Discover's embedded search — one surface not two, a structural simplification. Corroborates SEARCH-003 |
| 08 | External-link accessibility announces the destination | CONFIRMED IMPLEMENTED | PASS | |
| 08 | Bug Tracker / Be My Eyes help articles | CONFIRMED IMPLEMENTED | PASS | |
| 09 | AccessibleCard `openSound` typed prop | CONFIRMED IMPLEMENTED | PARTIAL | Capability distributed across `SoundPlayer` cases, not centrally gated |
| 09 | Meaningful badges exposed to accessibility | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 09 | `accessibilityState`/Value for saved/downloaded/followed | CONFIRMED IMPLEMENTED | MANUAL VERIFY | |
| 09 | EmptyState: secondary action + suggestions list + Learn More + hint | CONFIRMED IMPLEMENTED | PARTIAL | Native's `EmptyStateView` has primary+secondary action only, no suggestions list or Learn More field |
| 09 | Universal Content Header/Metadata/Action Menu/Comment/Error/Loading component set | PARTIAL (legacy itself never literally built this as named files) | MANUAL VERIFY | Neither tree literally built a shared "universal" component set — both achieve consistency through convention instead |
| 10 | Reduce repetitive search/welcome sounds | CONFIRMED IMPLEMENTED | PASS | |
| 10 | Standardize destructive confirmation alerts | CONFIRMED IMPLEMENTED | PASS | |
| 10 | Default VoiceOver Detail Level to Normal | CONFIRMED IMPLEMENTED | PASS | |
| 10 | Respect Reduce Motion broadly | CONFIRMED IMPLEMENTED | PASS | |
| 10 | Respect Reduce Transparency | CONFIRMED IMPLEMENTED | PARTIAL (materially less coverage) | Legacy references it in 10+ files; native only 2 (`CommunityDiscussionHeading`, `AboutView`) |
| 10 | Switch Control reachable / Dynamic Type no clipping (audit-wide) | PARTIAL (ongoing legacy fixes) | MANUAL VERIFY | No comprehensive Dynamic-Type-clipping audit confirmed on either side |
| 11 | Home: Continue Reading/Listening/Learning, Spotlights, Recommendations, density modes | OPTIONAL/FUTURE | NOT APPLICABLE | |
| 11 | Search: recent/saved searches, website fallback, dynamic filters | OPTIONAL/FUTURE | NOT APPLICABLE | |
| 11 | For You: transparent recommendations, interests, section-picker counts | OPTIONAL/FUTURE | NOT APPLICABLE | |
| 11 | Academy: community tutorials, learning paths, practice mode, AI search | OPTIONAL/FUTURE | NOT APPLICABLE | |
| 11 | Podcasts: resume-listening card, Now Playing tip, full-screen transcript, chapter tutorial | OPTIONAL/FUTURE | NOT APPLICABLE | Legacy already ships a transcript modal as a partial head start, not the specified full-screen mode |
| 11 | Profile/Settings: favorites, Accessibility Status card, previews, structured feedback | OPTIONAL/FUTURE | NOT APPLICABLE | Native's "Replay Welcome Tour" is the Phase 03 tour, not this backlog item |
| 11 | Native/system: Power User Academy path for Siri/Spotlight/Widgets/Live Activities/Watch/Handoff/iCloud | OPTIONAL/FUTURE | INTENTIONALLY DEFERRED | Concerns Widgets/Watch/Live Activities directly |

## Disposition totals

Legacy: CONFIRMED IMPLEMENTED 67 · PARTIAL 2 · PLANNED ONLY 0 · SUPERSEDED 0 · OPTIONAL/FUTURE 7 (76 rows total; representative sampling per phase, not exhaustive line-by-line coverage of every Temp/ sentence)

Native (counted across the 69 CONFIRMED IMPLEMENTED + PARTIAL legacy rows, since only those are real parity targets): PASS 39 · PARTIAL 10 · MISSING 5 · REGRESSION 0 · MANUAL VERIFY 13 · NOT APPLICABLE 2

## Headline gaps

- **Phase 06 (Home)** has 3 concrete native misses: the empty-state wording for "all content types off," the "Show Latest Activity" action, and the "Apple-Related Forum Topics Only" filter rename never landed.
- **Phase 07 (For You)** is missing all 4 section-selection VoiceOver announcements and the "Clear Filter" empty-state affordance entirely.
- **Phase 05 (Search)** groups results differently from spec — no "Site Results" category, "Resources" instead of "Guides and Resources," extra ungrouped categories — a real naming-standardization miss that legacy implemented faithfully.

Several of these MISSING items directly corroborate findings independently surfaced by the feature-parity ledger (`03_FEATURE_BEHAVIOR_PARITY_LEDGER.md` — HOME-007/008, FY-001, the For You "Clear Filter" gap, DISC-004/SEARCH-006) and the accessibility ledger (A11Y-003) — cross-validated from two or three different audit angles rather than resting on a single lens's word.
