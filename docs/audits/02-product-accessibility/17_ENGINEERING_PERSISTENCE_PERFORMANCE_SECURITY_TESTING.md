# Behind-the-Scenes Engineering Audit — Persistence, Performance, Security/Privacy, Testing, Diagnostics

Continuation of `16_ENGINEERING_ARCHITECTURE_CONCURRENCY_NETWORKING.md` — same
scope and exclusions apply.

---

## Persistence

### PERS-01 — `ICloudSyncManager`'s shadow-based merge strategy is genuinely well-engineered (PASS)

- **Category:** PASS
- **Evidence:** The shadow-based merge strategy correctly distinguishes "changed here since last sync" from "untouched" and "removed here" from "never had it," with doc comments explicitly describing the exact bug class (full-blob-overwrite data loss between two active devices) this design was built to avoid.
- **Current behavior:** Non-trivial, well-reasoned engineering — one of the strongest pieces of infrastructure found in this audit.
- **Recommended behavior:** No change; use as the reference pattern for any future multi-device sync logic.
- **Manual verification required:** No (structural review only; see PERS-02 for the one remaining edge case needing a real device test). **Regression tests required:** No — already the strongest-reasoned code in scope, though see TEST-01 for its current lack of automated coverage despite that strength.

### PERS-02 — Object-content merge for the underlying Saved/Followed item payload is "first writer wins," not fully reconciled

- **Severity:** P3 · **Category:** MANUAL VERIFY
- **Evidence:** `ICloudSyncManager`'s push/pull for saved items — while presence (is this item saved or not) is correctly resolved by the shadow mechanism (PERS-01), the underlying `SavedItem`/`FollowedItem` object's own content merge is effectively "whichever copy syncs first wins."
- **Current behavior:** In the specific race of delete-on-device-A + independent-re-save-on-device-B, worst case observed from code review is a "deleted then reappeared" UX outcome, not actual data loss — but this needs a real two-device manual test to confirm the actual behavior matches this code-level analysis.
- **Recommended behavior:** Confirm behavior with a real two-device test; if the "reappeared" outcome is confirmed and judged surprising to users, consider adding last-write-wins-by-timestamp resolution for the object content specifically (distinct from the already-correct presence resolution).
- **Exact reason:** Multi-device race conditions are inherently hard to reason about from code alone; this is exactly the kind of edge case the audit package's edge-case matrix calls out ("iCloud unavailable," implicitly extending to multi-device races).
- **Suggested implementation approach:** Two-device manual test first; implement only if the observed behavior is worse than analyzed here.
- **Manual verification required:** Yes. **Regression tests required:** No until the manual test clarifies actual behavior.

### PERS-03 — Sync "shadow" checkpoint correctly kept local, not synced (PASS)

- **Category:** PASS
- **Evidence:** The sync shadow checkpoint (tracking "what does this device know to be in sync") is correctly stored in local, non-iCloud-synced `UserDefaults`, since its entire purpose — knowing this specific device's last-known-synced state — would be meaningless if shared across devices.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

### PERS-04 — Auth-sensitive values correctly stored in Keychain, not UserDefaults (PASS)

- **Category:** PASS
- **Evidence:** CSRF token, logout token, and the full session object are correctly stored in Keychain. No auth-sensitive value was found stored in `UserDefaults` anywhere in scope. (Cross-referenced as SEC-01 in the Security section below.)
- **Recommended behavior:** No change; correct baseline security hygiene.
- **Manual verification required:** No. **Regression tests required:** No.

### PERS-05 — Sign-out doesn't clear local state (duplicate of ARCH-04)

- **Severity:** P1–P2 · **Category:** BUG / ACCESSIBILITY DEFECT (privacy)
- **Evidence/current/recommended/reason/approach:** See ARCH-04 in the companion Architecture doc — same underlying issue, filed once in full there.
- **Manual verification required:** Yes. **Regression tests required:** Yes.

### PERS-06 — Tip-dismissal state bypasses the iCloud sync opt-out toggle

- **Severity:** P3 · **Category:** UX INCONSISTENCY
- **Evidence:** `TipStore.isSeen()`/`markSeen()` write directly to `NSUbiquitousKeyValueStore` unconditionally, bypassing the sync-toggle gating `ICloudSyncManager` otherwise carefully respects for every other synced value.
- **Current behavior:** A user who explicitly disables iCloud sync in Settings would reasonably expect nothing new to sync afterward — but tip-seen state quietly continues syncing regardless of that preference.
- **Recommended behavior:** Gate `TipStore`'s iCloud writes behind the same sync-enabled check `ICloudSyncManager` uses for everything else.
- **Exact reason:** A user's explicit "stop syncing my data" choice should be honored uniformly; a silent, narrow exception undermines trust in that setting even though the data involved (which tips have been dismissed) is low-stakes.
- **Suggested implementation approach:** Route `TipStore`'s persistence through the same sync-enabled gate `ICloudSyncManager` exposes to other consumers.
- **Manual verification required:** No. **Regression tests required:** Yes.

### PERS-07 — Two-tier stale/expire TTL policy per content group mirrors deliberate prior tuning (PASS)

- **Category:** PASS
- **Evidence:** `ContentCache`'s two-tier stale/expire TTL policy, varied per content group rather than one flat TTL, mirrors deliberate tuning from the prior implementation rather than an arbitrary default.
- **Recommended behavior:** No change; see PERF-01 for the one caveat (eviction only runs at launch, not on a rolling basis).
- **Manual verification required:** No. **Regression tests required:** No.

---

## Performance

### PERF-01 — Cache eviction only runs once per cold launch; no size-bound/LRU eviction

- **Severity:** P3 · **Category:** PERFORMANCE ISSUE
- **Evidence:** `ContentCache.swift`'s `sweepExpired()` runs exactly once, at first access per cold launch, in `init()` — there is no size-bound or LRU eviction policy at all.
- **Current behavior:** A long-lived multitasking session (app kept alive in the background/foreground for a long period without a cold relaunch) or a power user browsing thousands of items could accumulate unbounded disk cache usage between cold launches.
- **Recommended behavior:** Add a size-bound or periodic (not just launch-time) sweep, and/or an LRU eviction policy once the cache exceeds a reasonable size threshold.
- **Exact reason:** Unbounded disk growth is a real, if slow-building, storage-usage and potentially performance concern, particularly relevant to users on storage-constrained older devices.
- **Suggested implementation approach:** Add a periodic sweep trigger (e.g. on background/foreground transition, not only cold launch) and/or a total-size cap with LRU eviction.
- **Manual verification required:** Yes — verify with a long-running session and heavy browsing that cache size stays bounded.
- **Regression tests required:** Yes — a test asserting cache size stays under a configured cap after simulated heavy use.

### PERF-02 — Regex/date-formatter instances correctly compiled once as static lets (PASS)

- **Category:** PASS
- **Evidence:** `NSRegularExpression` and `ISO8601DateFormatter` instances are compiled/configured once as static `let`s, with explicit comments confirming this was a deliberate fix for prior per-call recompilation cost.
- **Recommended behavior:** No change; good pattern already applied deliberately.
- **Manual verification required:** No. **Regression tests required:** No.

### PERF-03 — Three separate near-identical `ISO8601DateFormatter` pairs exist independently

- **Severity:** P4 · **Category:** IMPROVEMENT
- **Evidence:** Three separate, near-identical `ISO8601DateFormatter` pairs exist independently across `APIClient`, `JSONAPI`, and `AppEndpoints`.
- **Current behavior:** Each is individually a fine micro-optimization (per PERF-02), but having three independent sources of truth for "how AppleVis parses a Drupal timestamp" is a minor maintainability smell — a future date-format edge case fix would need to be applied in three places.
- **Recommended behavior:** Consolidate into one shared date-formatting utility.
- **Exact reason:** Low-severity but easy consolidation opportunity.
- **Suggested implementation approach:** Extract one shared formatter pair, used by all three call sites.
- **Manual verification required:** No. **Regression tests required:** No.

### PERF-04 — Every cache read re-pays a full disk read + decode, even for a "fresh" hit

- **Severity:** P3–P4 · **Category:** IMPROVEMENT
- **Evidence:** `ContentCache.get()`/`getSync()` — every cache read, even a fresh/valid hit, performs a full disk read plus a `JSONDecoder` pass; there's no in-memory tier above disk.
- **Current behavior:** Revisiting the same screen repeatedly within a single session re-pays the full disk-read-plus-decode cost each time, rather than serving from memory after the first read.
- **Recommended behavior:** Add a lightweight in-memory cache tier (e.g. an `NSCache` or simple dictionary with the same TTL semantics) above the disk tier for the current session's lifetime.
- **Exact reason:** A cheap, standard caching-layer improvement with a direct performance (and thus accessibility, per the north-star rule) benefit for any screen visited more than once per session.
- **Suggested implementation approach:** Add an in-memory tier checked before the disk read, populated on disk read and invalidated on write, scoped to the process lifetime.
- **Manual verification required:** No. **Regression tests required:** Yes — a test confirming a second read within the same session doesn't re-hit disk (if practically testable given current architecture).

### PERF-05 — Network path monitoring correctly hops to `@MainActor` with no retain cycle (PASS)

- **Category:** PASS
- **Evidence:** `NWPathMonitor`'s callback correctly hops to `@MainActor` via `Task { @MainActor [weak self] in ... }` — no retain cycle, appropriate for an app-lifetime singleton.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Security / Privacy

### SEC-01 — Duplicate reference to PERS-04 (Keychain, not UserDefaults) — PASS

- **Category:** PASS. See PERS-04 above for full detail.

### SEC-02 — Sign-out correctly purges applevis.com cookies, with a documented prior-bug fix (PASS)

- **Category:** PASS
- **Evidence:** `AuthStore` explicitly purges applevis.com-domain cookies on sign-out/session-expiry, with a code comment documenting the exact prior bug this fixed: an offline sign-out previously left a valid session cookie sitting in the shared cookie jar indefinitely.
- **Recommended behavior:** No change; the exact pattern that should also be applied to local saved/followed/read state per ARCH-04.
- **Manual verification required:** No. **Regression tests required:** No.

### SEC-03 — Deep-link host validation correctly avoids a real spoofing vector (PASS)

- **Category:** PASS
- **Evidence:** `DeepLinkRouter` validates `host == "applevis.com" || host.hasSuffix(".applevis.com")` rather than a naive `.contains()` check, with an explicit comment reasoning through the exact spoofing vector avoided — `applevis.com.attacker.com` would pass a naive `.contains()` check but correctly fails the `.hasSuffix` check used here.
- **Recommended behavior:** No change; genuinely careful, security-aware code.
- **Manual verification required:** No. **Regression tests required:** No.

### SEC-04 — Custom URL scheme accepts any caller with no origin/signature verification

- **Severity:** P3 · **Category:** MANUAL VERIFY
- **Evidence:** `DeepLinkRouter.handleCustomScheme()` acts on any `applevis://` URL from any app on the device, with zero origin or signature verification beyond the scheme itself.
- **Current behavior:** Impact is assessed as low from code review — no destructive/mutating action fires purely from the URL; the router only navigates or pre-fills forms, with actual submission still requiring explicit user action — but this assessment should be confirmed with a real cross-app test rather than relying solely on code-reading.
- **Recommended behavior:** Confirm the actual worst-case reachable behavior via a real cross-app test (e.g. a test harness app sending crafted `applevis://` URLs) covering every recognized custom-scheme route.
- **Exact reason:** Custom URL schemes are a well-known, broadly-applicable attack surface class on iOS; even a low-assessed-risk implementation benefits from an explicit verification pass rather than an assumption.
- **Suggested implementation approach:** Build or reuse a simple test harness to fire every known custom-scheme route and confirm none triggers a destructive/mutating side effect without explicit subsequent user action.
- **Manual verification required:** Yes. **Regression tests required:** Could be automated as a UI/integration test enumerating known routes, if judged worth the investment given the low assessed risk.

### SEC-05 — Spotlight identifiers are entirely app-generated, no untrusted external input crosses this boundary (PASS)

- **Category:** PASS
- **Evidence:** Spotlight search identifiers are entirely self-generated and self-round-tripped by the app; no untrusted external input crosses this boundary.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

### SEC-06 — Static shared secret embedded in the compiled binary

- **Severity:** P3 · **Category:** MANUAL VERIFY (cross-reference ARCH-03)
- **Evidence:** A static secret (`X-App-Auth`) is embedded as a plain string literal in the compiled binary, trivially extractable via `strings` or a MITM proxy.
- **Current behavior:** Likely a known, low-rotation, shared-across-all-installs credential (matches the legacy React Native client's equivalent header, per the code comment) rather than a genuinely per-user secret — so the *storage location* is largely moot if that assessment is correct, since the value is meant to be the same for every install anyway.
- **Recommended behavior:** Confirm with the backend/ops team whether this token is meant to gate anything genuinely security-sensitive (e.g. rate-limit bypass, privileged access) or is purely a client-identification convenience; if the former, it needs a different distribution mechanism than a compiled-in literal.
- **Exact reason:** Worth an explicit confirmation rather than an assumption, since the security implications differ significantly depending on what this token actually gates.
- **Suggested implementation approach:** Ask backend/ops directly what this header is meant to prevent/gate.
- **Manual verification required:** Yes (a conversation with the backend team, not a device test). **Regression tests required:** No.

### SEC-07 — Five error-logging sites mark potentially token-adjacent data `.public`

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** 5 `AppLog.*.error(...)` call sites mark the interpolated `Error` value `privacy: .public`. None currently log a raw secret directly, but `AuthStore.swift` specifically logs the decode failure of the Keychain-stored `AuthUser` blob (which contains `csrfToken`/`logoutToken`) — a narrow but non-zero chance exists of a token fragment surfacing in a `DecodingError`'s `debugDescription` if a Keychain entry is ever corrupted.
- **Current behavior:** Low but non-zero risk of sensitive fragments leaking into device logs (which are collectible via sysdiagnose and could be shared inadvertently, e.g. in a bug report).
- **Recommended behavior:** Change these 5 sites to `privacy: .private` as the safer default — a zero-cost fix given there's no legitimate need for these specific values to be public in logs.
- **Exact reason:** Defense in depth; the actual risk is narrow (only triggers on Keychain corruption) but the fix costs nothing.
- **Suggested implementation approach:** Change `privacy: .public` to `privacy: .private` (or omit the privacy parameter, defaulting to private) at these 5 sites.
- **Manual verification required:** No. **Regression tests required:** No.

### SEC-08 — Push notification history stores full content with no visible expiry/cap or confirmed sign-out clearing

- **Severity:** P3 · **Category:** MANUAL VERIFY / TEST GAP
- **Evidence:** `PushNotificationManager.recordHistory()` stores the full title/body of every received push in on-device history, with no visible expiry/cap logic, and no confirmed coverage by `clearAllLocalData()` (which per ARCH-04 isn't even called on sign-out currently) — separately, `PersistenceStore`'s `notificationHistoryLimit` (per `03_SCREEN_HOME.md`'s evidence) does cap history at 20 items, so this may already be partially mitigated; worth reconciling which store this specific finding refers to.
- **Current behavior:** Notification content — potentially containing details about forum replies, follows, etc. — persists on-device indefinitely (or up to whatever cap exists) and its interaction with sign-out/data-clearing is unconfirmed.
- **Recommended behavior:** Confirm notification history is included in the ARCH-04 sign-out fix once implemented, and confirm the existing 20-item cap (if this is the same store) is the intended behavior.
- **Exact reason:** Notification content can reveal social/activity information (e.g. "someone replied to your topic about X") that a shared-device scenario shouldn't leak to a subsequent user, same underlying concern as ARCH-04.
- **Suggested implementation approach:** Ensure the ARCH-04 fix explicitly covers notification history; confirm cap behavior matches the `PersistenceStore.notificationHistoryLimit` constant found elsewhere in this audit.
- **Manual verification required:** Yes. **Regression tests required:** Yes, as part of the ARCH-04 fix's test coverage.

### SEC-09 — No ATS exceptions found in Info.plist (PASS)

- **Category:** PASS
- **Evidence:** No `NSAppTransportSecurity`/`NSAllowsArbitraryLoads` exceptions found in `Info.plist` — the app relies on default ATS behavior (HTTPS-only, modern TLS).
- **Recommended behavior:** No change; correct default security posture.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Testing

### TEST-01 — Automated test coverage is 4 unit-test files plus 1 explicitly-skipped-by-default UI test

- **Severity:** P1–P2 · **Category:** TEST GAP
- **Evidence:** The complete automated suite in scope is 4 unit-test files plus 1 UI test that is explicitly documented as skipped by default (with a comment noting the Simulator's accessibility stack doesn't reliably reflect `@AccessibilityFocusState`). This directly confirms `KNOWN_CURRENT_FINDINGS.md` item #12 ("Automated test coverage is modest relative to app breadth").
- **Current behavior:** Highest-risk untested areas, in priority order:
  1. `ICloudSyncManager`'s shadow merge logic — zero coverage, and per PERS-01 this is the single most algorithmically complex, highest-regression-risk code in scope.
  2. `Mappers`' JSON:API → model translation layer — only 1 of ~9 functions tested (see TEST-03), despite an extensive documented history of live production bugs in exactly this layer.
  3. `ContentCache`/`CachedFetch`/`ApiHealthMonitor`'s TTL/staleness/circuit-breaker/offline-fallback behavior — zero coverage.
  4. `AuthStore`'s Keychain round-trip and session-expiry local-state clearing — zero coverage, and per ARCH-04 this specific area has a confirmed real gap.
  5. `PreferencesStore`/theme persistence — zero coverage.
  6. `DeepLinkRouter`'s host-validation/scheme-dispatch — zero coverage despite being security-adjacent (per SEC-03/SEC-04).
  7. `GuidelinesChecker`'s ~14 regex rules — 0% covered, despite being pure, deterministic, and cheap to test.
  8. Pagination consistency across the three idioms (ARCH-10) — zero coverage.
  9. Submission payload construction and Drupal-form-scraping regexes (NET-09) — zero coverage.
- **Recommended behavior:** Prioritize new test coverage in the order above — the shadow-merge logic and the Mappers layer are both the highest-complexity and highest-real-world-bug-history code in the app, making them the best return on testing investment.
- **Exact reason:** Matches the audit package's explicit "Testing" and "maintainability" audit dimensions directly; this is likely the single highest-leverage non-UI investment area in the whole engineering audit, given how much of the app's correctness depends on exactly these untested layers.
- **Suggested implementation approach:** Start with `Mappers` (extend the existing `MappersTests.swift`, which already has 1 well-targeted test as a template — see TEST-03/NET-07) and `ICloudSyncManager`'s merge logic (likely needs fixture-based tests simulating shadow states across simulated sync cycles).
- **Manual verification required:** No (this finding is itself about closing a testing gap). **Regression tests required:** Yes — this entire finding *is* the regression-test recommendation.

### TEST-02 — `APIClientTests.swift` covers a narrow slice of `APIClient`'s actual behavior

- **Severity:** P2 · **Category:** TEST GAP
- **Evidence:** Only covers `.notFound`'s message and the 400→`.notFound` status remapping.
- **Current behavior:** Untested: `buildURL`'s query encoding, the 3-way date-decoding fallback chain, `validateStatus`'s full status-to-error mapping — and specifically, 401 handling's `AuthStore`/`ToastStore` side effects (session-expiry alert flow) are entirely unverified by any automated test.
- **Recommended behavior:** Extend `APIClientTests` to cover the full `validateStatus` mapping and, ideally, the 401 → session-expiry side-effect chain (may require injecting fakes for `AuthStore`/`ToastStore`).
- **Exact reason:** Session-expiry handling is a critical, user-visible flow (per `IMPLEMENTATION_NOTES.md`'s "Accessible Alerts" guidance) that currently has zero automated verification of its trigger condition.
- **Suggested implementation approach:** Add test cases for each `validateStatus` branch; consider a lightweight fake/mock for `AuthStore`/`ToastStore` to verify the 401 side-effect chain in isolation.
- **Manual verification required:** No. **Regression tests required:** Yes (this finding is itself the recommendation).

### TEST-03 — `Mappers.swift` has 8 of 9 functions completely untested despite documented live-bug history

- **Severity:** P1–P2 · **Category:** TEST GAP
- **Evidence:** `MappersTests.swift` covers exactly 1 of ~9 mapper functions (`forumFromRecent`, per NET-07). The remaining 8 have zero coverage, despite this being the layer most directly exposed to live-backend field changes, with an extensive "confirmed via live repro" comment trail throughout `Mappers.swift` documenting real past production bugs in exactly this layer.
- **Current behavior:** The single highest-real-world-risk untested code area identified in this audit, given the documented history of actual bugs here.
- **Recommended behavior:** Extend `MappersTests.swift` to cover the remaining 8 functions, using `forumFromRecent`'s existing test as a template.
- **Exact reason:** This layer has the most concrete evidence of any area in the codebase that it *will* have real bugs when live data doesn't match assumptions — the existing test for `forumFromRecent` already proves this is worth doing (it was written specifically because of two live-production bug repros).
- **Suggested implementation approach:** Mirror `forumFromRecent`'s test structure for each remaining mapper function.
- **Manual verification required:** No. **Regression tests required:** Yes (this finding is the recommendation).

### TEST-04 — All mutation endpoints (submit/edit/delete/follow/register) have zero unit coverage

- **Severity:** P2 · **Category:** TEST GAP
- **Evidence:** `ContentActionEndpoints`/`AccountEndpoints`/`NotificationEndpoints`/`FlagEndpoints` — all mutation paths currently only exercisable end-to-end against a live authenticated session, which per `DrupalFormClient`'s own comments wasn't even fully possible during original development for some paths.
- **Current behavior:** No automated safety net for any content-mutating operation.
- **Recommended behavior:** Add request-construction/payload-shape tests (not requiring a live server) for each mutation endpoint, verifying the outgoing request is built correctly even without executing it against a real backend.
- **Exact reason:** Mutation paths are inherently higher-stakes than read paths (a bug here can corrupt or lose user data/content, not just display it wrong); zero coverage here is a meaningful gap.
- **Suggested implementation approach:** Test request/payload construction in isolation (e.g. verifying the correct HTTP method, headers, and body shape are produced for a given input), without needing a live server round-trip.
- **Manual verification required:** No. **Regression tests required:** Yes (this finding is the recommendation).

### TEST-05 — No test coverage for any of the three pagination idioms

- **Severity:** P2 · **Category:** TEST GAP
- **Evidence:** Cross-references ARCH-10 — none of the three pagination conventions has any test coverage.
- **Current behavior:** An off-by-one or `hasMore` edge case in any of the three idioms would only surface via manual QA, not CI.
- **Recommended behavior:** Add tests for each pagination idiom's boundary conditions (exactly-full page, empty page, last partial page).
- **Exact reason:** Pagination bugs are exactly the class of issue that's easy to miss in casual manual testing (they require specific data-size conditions to trigger) but simple to verify with a targeted unit test.
- **Suggested implementation approach:** Add fixture-based tests per pagination idiom.
- **Manual verification required:** No. **Regression tests required:** Yes (this finding is the recommendation).

### TEST-06 — The one existing UI test is Simulator-unreliable and skipped by default; state restoration has zero coverage

- **Severity:** P2 · **Category:** TEST GAP
- **Evidence:** `WhatsNewFocusUITests.swift` is explicitly Simulator-unreliable and skipped by default (per its own documentation, referenced in the Home audit's HOME-01/CARD-12 focus-retry findings as the same general area of fragility). This means CI-run automated coverage for the entire app is effectively just the 4 unit-test files. State restoration (app backgrounded mid-scroll/mid-playback/mid-compose) has zero automated coverage and is not flagged as manually-verified in any known test script either.
- **Current behavior:** A significant testing gap at the UI/integration level, not just unit level.
- **Recommended behavior:** Investigate whether a more Simulator-reliable UI test strategy exists (e.g. testing observable state changes rather than literal accessibility focus, which is the specific thing noted as unreliable), and explicitly add state-restoration scenarios to the manual test script (see `18_ACCESSIBILITY_CERTIFICATION_GAPS.md`) if automated coverage isn't practical.
- **Exact reason:** State restoration is explicitly named in the audit package's edge-case matrix ("app backgrounded mid-operation") and currently has no coverage of any kind, automated or manually-documented.
- **Suggested implementation approach:** Short-term: add state restoration to the manual test script. Longer-term: investigate a more reliable UI testing approach for focus-dependent scenarios.
- **Manual verification required:** Yes. **Regression tests required:** Yes, ideally, though acknowledged as difficult given the Simulator limitation already documented in the codebase.

### TEST-07 — Share Extension → main app hand-off has no test coverage

- **Severity:** P3 · **Category:** TEST GAP
- **Evidence:** `DeepLinkRouter.checkPendingShareExtensionContent()` ↔ `AppShareConsumer.swift` — the cross-process hand-off fallback path has no test coverage; this is inherently timing-sensitive and easy to silently regress.
- **Current behavior:** No automated safety net for this specific cross-process interaction.
- **Recommended behavior:** Add a test (likely requiring some form of integration/UI test given the cross-process nature) covering the hand-off path.
- **Exact reason:** Cross-process timing bugs are notoriously easy to introduce without noticing, since they often only manifest under specific timing conditions not exercised by casual manual testing.
- **Suggested implementation approach:** Investigate feasibility of a targeted integration test; if impractical, add to the manual test script explicitly.
- **Manual verification required:** Yes. **Regression tests required:** Preferred if feasible.

### TEST-08 — Existing 4 test files are well-targeted at genuinely regression-prone logic (PASS)

- **Category:** PASS
- **Evidence:** The existing tests are not trivial getter/setter tests — they target genuinely regression-prone, previously-live-bugged logic (e.g. `forumFromRecent`'s validation, per NET-07), using the modern Swift Testing style.
- **Recommended behavior:** No change; good foundation and good template to extend from for TEST-01 through TEST-07's recommendations.
- **Manual verification required:** No. **Regression tests required:** No (this is the positive baseline the other TEST findings build on).

---

## Diagnostics

### DIAG-01 — One remaining bare `print()` for push-registration failure

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** `PushNotificationManager.swift` has one remaining bare, DEBUG-gated `print()` call for push-registration failure.
- **Current behavior:** This failure only leaves a trace in DEBUG builds, not in Release/TestFlight, where it would actually matter for diagnosing a real user's report of "notifications don't work" (which, per ARCH-02, may be a widespread real issue right now).
- **Recommended behavior:** Move to `AppLog` so the failure leaves a trace in Release/TestFlight builds too.
- **Exact reason:** Directly relevant to diagnosing ARCH-02 in the field — a push-registration failure trace would be valuable exactly when investigating why notifications aren't arriving.
- **Suggested implementation approach:** Replace the `print()` with an `AppLog` call.
- **Manual verification required:** No. **Regression tests required:** No.

### DIAG-02 — No `network`/`api` AppLog category exists anywhere in the networking layer

- **Severity:** P2 · **Category:** IMPROVEMENT
- **Evidence:** No `network`/`api` `AppLog` category exists; nothing in `APIClient`/`CachedFetch`/`ApiHealthMonitor`/any Endpoints file logs anything, not even at circuit-breaker state transitions — the exact "we just started serving stale content because live fetches are failing" moments the entire caching layer exists to survive gracefully.
- **Current behavior:** This is precisely the intermittent, hard-to-reproduce-on-demand issue class `AppLog` exists to help diagnose after the fact via sysdiagnose, and it's the one major subsystem in the app missing it entirely.
- **Recommended behavior:** Add an `AppLog.network` category and log at minimum: circuit-breaker open/close transitions, cache-fallback-to-stale events, and the NET-09 submission-token-fetch failure branches.
- **Exact reason:** Without this, a user reporting "the app feels broken/slow/stale sometimes" is essentially undiagnosable after the fact — exactly the scenario `AppLog`'s existing disciplined use elsewhere (per DIAG-04) was built to prevent, but the networking layer is the one place that discipline wasn't extended to.
- **Suggested implementation approach:** Add the category to `AppLog.swift`; add log calls at the specific transition points named above.
- **Manual verification required:** No. **Regression tests required:** No.

### DIAG-03 — Unrecognized custom-scheme routes fail silently with no log trace

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** `DeepLinkRouter.handleCustomScheme()`'s default case silently returns `false` with no log trace for an unrecognized host.
- **Current behavior:** Makes "a Siri Shortcut/notification tap/Share link didn't do anything" field reports hard to diagnose after the fact.
- **Recommended behavior:** Add a log call in the default case.
- **Exact reason:** Same diagnosability rationale as DIAG-02, applied to deep linking specifically.
- **Suggested implementation approach:** One log call addition.
- **Manual verification required:** No. **Regression tests required:** No.

### DIAG-04 — Existing `AppLog` usage has good signal-to-noise discipline (PASS)

- **Category:** PASS
- **Evidence:** Everywhere `AppLog` is already used, call sites are consistently genuine failure/error paths, not noisy verbose logging.
- **Recommended behavior:** No change; extend this same discipline to the networking layer per DIAG-02.
- **Manual verification required:** No. **Regression tests required:** No.

---

## Engineering summary

Two P1 findings stand out as needing prompt attention independent of
accessibility work specifically: **ARCH-02** (push notifications likely
non-functional due to an Expo/APNs token mismatch — corroborated by two other
independent audit passes) and **ARCH-04/PERS-05** (sign-out doesn't clear
local saved/followed/read state — a real shared-device privacy leak). The
single highest-leverage investment for long-term app health is closing
**TEST-01/TEST-03**'s coverage gap on `Mappers` and `ICloudSyncManager`'s
merge logic — both are simultaneously the most complex, most
previously-bug-prone, and least-tested code in the app. **CONC-01** (main-thread
decode/regex work) and **CONC-02** (toast dismissal race) are both concrete,
verifiable, low-risk-to-fix findings with direct accessibility relevance.
The architecture overall shows real engineering discipline in specific
places (ARCH-08/09, PERS-01, NET-05/06/07, CONC-03/04/07) — the gaps found
are consistently in the *edges* of otherwise well-designed systems (a secret
duplicated instead of shared, one function's `.public` logging, one code
path missing a log category) rather than fundamental design flaws.
