# Behind-the-Scenes Engineering Audit — Architecture, Concurrency, Networking

Scope: `Networking/*`, `Stores/{AuthStore,PreferencesStore,DeepLinkRouter,ToastStore,TipStore,KeyCommandRouter}`,
`Services/*`, `App/*`. Excludes `PersistenceStore`, `ThemeColors`,
`HomeViewModel`, `PlayerStore`, `DownloadManager`, `RowViews`/`ContentActions`,
which are audited in `02_CROSS_APP_PATTERNS_AND_UNIFIED_CARD.md` and
`03_SCREEN_HOME.md`. Persistence/Performance/Security/Testing/Diagnostics
findings from the same audit pass are filed in
`17_ENGINEERING_PERSISTENCE_PERFORMANCE_SECURITY_TESTING.md`.

---

## Architecture

### ARCH-01 — Three independent network clients with inconsistent session configuration

- **Severity:** P2 · **Category:** ARCHITECTURE ISSUE
- **Evidence:** `APIClient`, `DrupalFormClient`, `ItunesAPI`/`ImageDescriber` all make network requests independently. Only `APIClient` has a configured `URLSessionConfiguration` (10s/30s timeouts, Cloudflare-bypass headers). `DrupalFormClient` re-declares its own copy of the same Cloudflare-bypass headers instead of reusing `APIClient`'s; `ItunesAPI`/`ImageDescriber` use bare `URLSession.shared`.
- **Current behavior:** Both `APIClient` and `DrupalFormClient` target `applevis.com`, yet duplicate header/timeout configuration independently rather than sharing one source of truth — a future change to the bypass headers or timeout policy has to be made in two places and could silently drift.
- **Recommended behavior:** Route `DrupalFormClient` through the same configured session `APIClient` uses (or extract the shared configuration into one place both reference); `ItunesAPI`/`ImageDescriber` targeting genuinely different hosts (Apple's iTunes API, on-device Vision) may be a legitimate exception, but that should be a documented decision, not an unexamined default.
- **Exact reason:** Configuration drift between two clients hitting the same host is a maintainability risk with no offsetting benefit.
- **Suggested implementation approach:** Extract a shared `URLSessionConfiguration` (or the header-building logic) used by both `APIClient` and `DrupalFormClient`.
- **Manual verification required:** No. **Regression tests required:** No.

### ARCH-02 — Push notifications may not functionally deliver at all (Expo/APNs token mismatch)

- **Severity:** P1 · **Category:** ARCHITECTURE ISSUE
- **Evidence:** `NotificationEndpoints.swift`/`PushNotificationManager.swift` — native registers a raw APNs device token where the legacy backend integration expected an Expo push token. The file's own doc comment states tokens registered this way "won't receive anything" unless Drupal's send logic is updated to call APNs directly.
- **Current behavior:** Push registration silently "succeeds" from the client's perspective (no error, no crash) while functionally delivering nothing, since the backend doesn't know how to route to a raw APNs token yet.
- **Recommended behavior:** Confirm with the backend/Drupal team whether APNs-direct sending has been implemented; if not, this is a cross-team blocker, not a client-only fix. Cross-references: this audit's parallel migration-parity pass and an App Store compliance pass independently identified the same root issue — three independent audits converging on the same finding is strong signal this is real and unresolved.
- **Exact reason:** Silent non-functional push notifications are a severe, hard-to-detect product gap — notifications are explicitly part of the app's engagement model (Home's "Notification summary" section, per the master spec), and a user who "successfully" enables them and then never receives any has no way to know the feature is broken.
- **Suggested implementation approach:** Coordinate with backend team on APNs-direct send implementation; add a client-side self-test (e.g. a test push on registration, or a visible "notifications not yet confirmed working" state) if backend work can't land immediately.
- **Manual verification required:** Yes — send a real test push through the production path and confirm delivery.
- **Regression tests required:** No practical client-only test; this is fundamentally a cross-system integration gap.

### ARCH-03 — Hardcoded secret duplicated across two files

- **Severity:** P3 · **Category:** ARCHITECTURE ISSUE (cross-reference SEC-06 in the companion doc)
- **Evidence:** A static `X-App-Auth` header value is duplicated as a string literal in both `APIClient.swift` and `DrupalFormClient.swift`.
- **Current behavior:** Two independent copies of the same secret string; a rotation requires editing both.
- **Recommended behavior:** Extract to a single shared constant.
- **Exact reason:** Basic duplication-avoidance; see the companion Security doc for the security-specific assessment of the secret itself.
- **Suggested implementation approach:** One-line consolidation.
- **Manual verification required:** No. **Regression tests required:** No.

### ARCH-04 — Sign-out never clears local saved/followed/read/notification-history state — shared-device privacy leak

- **Severity:** P1–P2 · **Category:** BUG / ACCESSIBILITY DEFECT (privacy)
- **Evidence:** `AuthStore.signOut()`/`handleSessionExpired()` clear Keychain, applevis.com cookies, and Spotlight index entries (each documented as a deliberate fix — see SEC-02 in the companion doc), but never call `PersistenceStore.clearAllLocalData()`. Saved items, followed topics, read/visited state, and notification history all survive sign-out fully intact. (Duplicate finding, filed once here: PERS-05 in the companion doc references the same issue.)
- **Current behavior:** On a shared household device, a second person signing in with their own account inherits the previous user's saved items, followed topics, read/visit history, and notification history — a real, concrete privacy leak, and inconsistent with the deliberate cleanup already implemented in the very same function for cookies/Keychain/Spotlight.
- **Recommended behavior:** Call `PersistenceStore.shared.clearAllLocalData()` (or a scoped subset of it, if some locally-saved content is intentionally meant to survive sign-out — e.g. if "Saved" items are considered device-local rather than account-scoped, that should be an explicit product decision, not an oversight) from `signOut()`/`handleSessionExpired()`.
- **Exact reason:** This is a genuine privacy gap on shared devices, directly analogous to the exact cookie-persistence bug the same function already fixed for cookies — the pattern was clearly understood once and not applied consistently to the rest of local state.
- **Suggested implementation approach:** Add the `clearAllLocalData()` call (or a scoped equivalent) to both `signOut()` and `handleSessionExpired()`, after confirming with product whether Saved/Following are meant to be account-scoped or device-scoped.
- **Manual verification required:** Yes — sign out, sign in as a different account, confirm no residual saved/followed/read state from the prior account.
- **Regression tests required:** Yes — a test asserting `PersistenceStore` state is empty after `signOut()`.

### ARCH-05 — Singleton audit: all 12 found singletons represent genuine shared state, none are singletons-of-convenience (PASS)

- **Category:** PASS
- **Evidence:** 12 singletons identified (`ICloudSyncManager`, `AudioEffectsProcessor`, `NetworkMonitor`, `SoundPlayer`, `ContentCache`, `TextToSpeechReader`, `ApiHealthMonitor`, `APIClient`, `PersistenceStore`, `DownloadManager`, `HomeBadgeStore`, `NetworkStatusStore`) — each represents genuine app-wide shared state or a stateless system wrapper; none appear to be singletons adopted purely for convenience where dependency injection would have been more appropriate.
- **Recommended behavior:** No change; reasonable given the app has no formal DI container. Worth revisiting only if testability becomes a blocker (singletons are harder to substitute in unit tests than injected dependencies — see the Testing findings in the companion doc for where this already bites, e.g. `AuthStore`'s Keychain dependency).
- **Manual verification required:** No. **Regression tests required:** No.

### ARCH-06 — App-submission category taxonomy hardcoded, not fetched live

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** `AppEndpoints.swift`'s `categoryUUIDs` hardcodes 27 category entries rather than fetching them live (with hardcoded values only as fallback).
- **Current behavior:** A backend taxonomy change requires an app release to fix, with no detectable failure mode in the meantime — submission "succeeds" with a wrong or missing category, silently.
- **Recommended behavior:** Fetch categories live where possible, keeping the hardcoded list only as an offline/failure fallback.
- **Exact reason:** Silent miscategorization on submission is a real (if low-frequency) correctness risk with no user-visible signal.
- **Suggested implementation approach:** Add a live category-fetch call, falling back to the existing hardcoded list on failure.
- **Manual verification required:** No. **Regression tests required:** No.

### ARCH-07 — Forum category assignment on submit is unconfirmed

- **Severity:** P4 · **Category:** IMPROVEMENT
- **Evidence:** `ForumEndpoints.swift`'s `submitTopic` accepts a `categoryTid` parameter but a code comment notes it's unused, since "Drupal appears to accept forum nodes without one."
- **Current behavior:** Unconfirmed whether submitted topics actually land in the category the user selected.
- **Recommended behavior:** Confirm with a live test submission whether category assignment works correctly end-to-end.
- **Exact reason:** A topic silently landing in the wrong (or no) category would be a real, if minor, correctness issue for the person submitting it.
- **Suggested implementation approach:** Manual live-submission test.
- **Manual verification required:** Yes. **Regression tests required:** No.

### ARCH-08 — One clear navigation/deep-link authority (PASS)

- **Category:** PASS
- **Evidence:** `DeepLinkRouter` handles Spotlight, universal links, the custom URL scheme, Siri, and the Share Extension hand-off in one place; `KeyCommandRouter` is a narrowly-scoped second authority specifically for hardware-keyboard `.commands` (a SwiftUI-imposed structural split, not competing ownership). No competing navigation authorities found.
- **Recommended behavior:** No change; good architectural discipline.
- **Manual verification required:** No. **Regression tests required:** No.

### ARCH-09 — One consistent caching/circuit-breaker/offline-fallback authority (PASS)

- **Category:** PASS
- **Evidence:** `fetchWithCache` is applied uniformly across all 6 content groups via the same function — one consistent implementation, not six ad hoc reimplementations.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

### ARCH-10 — Three incompatible pagination idioms coexist across content types

- **Severity:** P2 · **Category:** UX INCONSISTENCY / ARCHITECTURE ISSUE
- **Evidence:** Three distinct pagination conventions coexist across endpoint files: JSON:API `page[limit]/offset` with a client-side "got a full page" heuristic for `hasMore`; a custom REST `?page=N` (0-based) using the same full-page heuristic; and a custom REST `?page=N+1&limit=N` (1-based) with a server-provided `hasMore` boolean.
- **Current behavior:** Three different page-numbering conventions and two different sources of truth for "is there more content" across content types that all look identical to the end user — the risk surface (off-by-one errors, incorrect "you've reached the end" states) differs invisibly per content type.
- **Recommended behavior:** Converge on the server-provided `hasMore` boolean wherever the backend supports it, since it's strictly more reliable than the "got a full page" heuristic (which is wrong whenever a page happens to be exactly full but no more data actually exists).
- **Exact reason:** Inconsistent pagination reliability across content types means bugs like "list says 'reached the end' but more content actually exists" (or vice versa) are more likely in some content types than others, for no product reason — directly connects to FORUM-02's concrete real-world manifestation of exactly this class of bug.
- **Suggested implementation approach:** Standardize on server-`hasMore` where available; for endpoints lacking it, consider requesting the backend add it rather than perpetuating the heuristic.
- **Manual verification required:** No. **Regression tests required:** Yes (see TEST-05 in the companion doc).

### ARCH-11 — Bug report detail always tries iOS platform first, guaranteeing a wasted round trip for every macOS bug

- **Severity:** P3 · **Category:** PERFORMANCE ISSUE / ARCHITECTURE ISSUE
- **Evidence:** `ContentEndpoints.swift`'s `BugReportEndpoints.detail(id:)` tries `.ios` platform first via `try?`, silently discards a failure, and only then fetches `.macos`.
- **Current behavior:** Every macOS bug detail open costs two round trips (one guaranteed to fail) instead of one; if both fail, the user only sees the macOS-path error, which could be misleading about the actual cause.
- **Recommended behavior:** Thread the already-known platform through from the list view (which already knows which platform's bug was tapped) instead of guessing at the detail layer.
- **Exact reason:** Avoidable network waste and a misleading error path on failure.
- **Suggested implementation approach:** Pass `platform` as a parameter to `detail(id:)` from the calling list view, removing the guess-then-fallback logic entirely.
- **Manual verification required:** No. **Regression tests required:** Yes — a test asserting only one request fires when platform is known.

---

## Swift Concurrency

### CONC-01 — Default MainActor isolation may put JSON decoding and HTML regex scraping on the main thread for every network response

- **Severity:** P2 · **Category:** PERFORMANCE ISSUE / ARCHITECTURE ISSUE
- **Evidence:** The Xcode project sets `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, and zero `nonisolated` annotations were found anywhere in scope. Under this setting, `APIClient` (a plain class, not an actor), `Mappers`, and HTML-text-handling code are implicitly MainActor-isolated. `APIClient.perform`/`performRaw` decode JSON synchronously inline; `Mappers.bug`/`bugDetail` run several `NSRegularExpression` passes synchronously inline.
- **Current behavior:** If this code actually executes on the main thread (not independently confirmed here — needs Instruments), JSON decoding and HTML scraping compete with UI rendering for every network response, which is particularly relevant for a screen-reader-heavy audience where main-thread stalls visibly delay VoiceOver announcements (VoiceOver speech and focus updates are themselves main-thread-dependent).
- **Recommended behavior:** Confirm with Instruments Time Profiler against a large payload (e.g. a 100-reply forum topic, matching FORUM-05's performance concern) whether this decode/regex work genuinely executes on the main thread and causes measurable stalls; if confirmed, mark the pure-computation types (`Mappers`, regex-heavy parsing) `nonisolated` or move the work explicitly off-main.
- **Exact reason:** "Performance is accessibility" — main-thread contention has an outsized, specific cost for VoiceOver users beyond the general UI-jank cost every user experiences.
- **Suggested implementation approach:** Instruments profiling first (this is a MANUAL VERIFY-gated finding, not a confirmed bug); if confirmed, mark `Mappers` and similar pure-computation types `nonisolated`, or explicitly dispatch decode/regex work to a background task.
- **Manual verification required:** Yes — Instruments Time Profiler pass, ideally on the same 100+ reply thread flagged in FORUM-05.
- **Regression tests required:** No formal automated test; a performance benchmark test could be added if this proves to be a real, recurring regression risk.

### CONC-02 — Toast dismissal race: rapid consecutive toasts can have their VoiceOver-announced duration cut short

- **Severity:** P3 · **Category:** BUG (concrete, reproducible)
- **Evidence:** `ToastStore.show()` spawns an untracked `Task` per call that unconditionally nils `current` after 3 seconds, regardless of whether `current` still refers to *that specific* toast.
- **Current behavior:** Calling `show()` twice within 3 seconds (a realistic scenario — e.g. a quick Save immediately followed by a Follow) means the first toast's timer fires and clears the *second* toast early, cutting its VoiceOver-announced duration short before the user has necessarily had time to hear/process it.
- **Recommended behavior:** Capture the specific toast's own identity in the timer closure, and only clear `current` if it still matches that same toast (`current?.id == toast.id`).
- **Exact reason:** A concrete, reproducible race with a direct accessibility consequence — a toast's spoken confirmation being cut short is exactly the kind of subtle timing bug that's easy to miss in casual testing but real in daily use (save-then-follow is a very ordinary sequence).
- **Suggested implementation approach:** Give each toast a stable identifier, capture it in the dismissal `Task`'s closure, and compare before clearing.
- **Manual verification required:** Yes — trigger two toasts within 3 seconds and confirm both display their full duration.
- **Regression tests required:** Yes — a `ToastStore` unit test simulating two rapid `show()` calls and asserting the second toast isn't cleared prematurely.

### CONC-03 — `ApiHealthMonitor` correctly implemented as an actor (PASS)

- **Category:** PASS
- **Evidence:** `ApiHealthMonitor` is a proper Swift `actor`, correctly isolating circuit-breaker state that's accessed concurrently — idiomatic design for session-scoped shared mutable state.
- **Recommended behavior:** No change; good reference pattern.
- **Manual verification required:** No. **Regression tests required:** No.

### CONC-04 — Consistent, idiomatic structured concurrency for concurrent independent fetches (PASS)

- **Category:** PASS
- **Evidence:** `async let` used consistently and correctly for concurrent independent fetches (e.g. Search's multi-way fan-out across content types, detail+comments pairs), with correct structured-concurrency cancellation propagation.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

### CONC-05 — No concurrency-suppression annotations found (PASS, with a caveat)

- **Category:** PASS
- **Evidence:** No `@unchecked Sendable` or other concurrency-checking-suppression annotations found anywhere in scope.
- **Current behavior:** Clean baseline — but this partly reflects Swift 5 mode's more lenient concurrency checking rather than proof of full data-race-safety.
- **Recommended behavior:** Re-verify if/when the project migrates to Swift 6's strict concurrency checking mode, since stricter checking may surface real issues this pass, under Swift 5 mode, cannot detect.
- **Manual verification required:** No now; yes at Swift 6 migration time. **Regression tests required:** No.

### CONC-06 — Synchronous Keychain read on main actor at launch

- **Severity:** P4 · **Category:** PERFORMANCE ISSUE
- **Evidence:** `AuthStore.init()` performs a synchronous Keychain read on the main actor during app launch.
- **Current behavior:** Likely negligible in practice, but not independently measured.
- **Recommended behavior:** Worth confirming launch-time impact specifically on the oldest supported device if the proposed iOS 17 minimum-target decision (per `KNOWN_CURRENT_FINDINGS.md` item 3) goes forward, since older/slower hardware makes launch-time synchronous I/O more visible.
- **Exact reason:** Launch time is a first-impression metric and, again, "performance is accessibility."
- **Suggested implementation approach:** Measure on a real older device before deciding whether to move this off the launch-critical path.
- **Manual verification required:** Yes, contingent on the minimum-iOS-version decision. **Regression tests required:** No.

### CONC-07 — `ContentCache` correctly offloads disk I/O off the main thread (PASS)

- **Category:** PASS
- **Evidence:** `ContentCache` offloads all disk I/O to its own serial background `DispatchQueue` and bridges back to callers via `withCheckedContinuation` rather than blocking `queue.sync` — the file's own comment explicitly documents why blocking sync was rejected. This is the one place in scope where main-thread-safety was clearly, deliberately reasoned about in writing.
- **Recommended behavior:** No change; use as the reference pattern for any future disk-I/O-heavy code (and for evaluating whether CONC-01's decode work, if confirmed to be on main, should adopt a similar background-queue-plus-continuation pattern).
- **Manual verification required:** No. **Regression tests required:** No.

---

## Networking

### NET-01 — No in-flight request deduplication

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** `CachedFetch.swift`/`ApiHealthMonitor.swift` — two concurrent cache misses for the same key both independently fire network requests; there's no in-flight-request coalescing.
- **Current behavior:** A screen that triggers the same fetch from two places nearly simultaneously (e.g. a fast double-tap, or two views both wanting the same data on appear) pays the network cost twice.
- **Recommended behavior:** Add in-flight request deduplication keyed by the same cache key, so a second caller awaits the first's in-progress request rather than starting a redundant one.
- **Exact reason:** Wasted network/battery cost with no user-visible benefit; a well-understood, standard caching-layer improvement.
- **Suggested implementation approach:** Track in-flight `Task`s keyed by request identity in `CachedFetch`/`ApiHealthMonitor`, returning the existing task's result to a second concurrent caller instead of starting a new request.
- **Manual verification required:** No. **Regression tests required:** Yes — a test asserting two concurrent identical fetches result in exactly one network call.

### NET-02 — No retry-with-backoff for transient failures

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** `APIClient.swift` — a single timeout/network error surfaces immediately (or falls back to cache) with no automatic retry.
- **Current behavior:** A single transient network blip (common on cellular) surfaces as a full failure rather than being silently retried.
- **Recommended behavior:** Add a bounded retry-with-backoff for clearly transient error classes (timeouts, connection resets), not for definite failures like 404/401.
- **Exact reason:** Reduces user-visible failures from what are often momentary network conditions, particularly relevant to mobile users on variable connections.
- **Suggested implementation approach:** Add a small retry wrapper in `APIClient` for the specific transient-error subset.
- **Manual verification required:** No. **Regression tests required:** Yes.

### NET-03 — `Retry-After` header on 429 responses is ignored

- **Severity:** P3 · **Category:** IMPROVEMENT
- **Evidence:** `APIClient.swift`'s `validateStatus()` (429 case) and `ApiHealthMonitor.swift` never read the `Retry-After` header; rate-limiting is treated identically to any other failure, marking the whole content group down for a flat 60 seconds regardless of what the server actually requested.
- **Current behavior:** A server-specified shorter or longer backoff window is ignored in favor of a fixed 60s.
- **Recommended behavior:** Read `Retry-After` when present and use it to inform the circuit-breaker's cooldown duration for that specific failure.
- **Exact reason:** Respecting server-specified backoff is both more correct (potentially faster recovery) and better API citizenship (avoiding hammering a server that's asked for more time).
- **Suggested implementation approach:** Parse `Retry-After` in the 429 handling path and pass it to `ApiHealthMonitor`'s cooldown logic.
- **Manual verification required:** No. **Regression tests required:** Yes.

### NET-04 — Newly-created content may not appear in its own list immediately due to page-0 caching

- **Severity:** P3 · **Category:** UX INCONSISTENCY
- **Evidence:** `CachedFetch.swift` + each content type's `list()` methods cache page-0 results; newly created content (a submitted topic/app/blog post) isn't reflected in the cached first page until the TTL naturally expires (5–30 minutes depending on content type).
- **Current behavior:** A user who just submitted a topic/post may not see it in the relevant list immediately upon returning to it, with no visible indication the list is being served from a cached snapshot rather than live data.
- **Recommended behavior:** Invalidate the relevant content group's page-0 cache immediately after a successful submission from within the same app session.
- **Exact reason:** "Did my post actually go through?" is a natural, anxiety-provoking question right after submitting; not seeing your own new content in the list (even though it did submit successfully) undermines confidence in the action having worked.
- **Suggested implementation approach:** After a successful submission, explicitly invalidate/bypass the cache for that content type's page-0 fetch on next load.
- **Manual verification required:** Yes — submit a topic/post, return to its list, confirm it appears immediately.
- **Regression tests required:** Yes.

### NET-05 — 401 handling correctly bypasses stale-cache fallback (PASS)

- **Category:** PASS
- **Evidence:** `fetchWithCache` explicitly re-throws `.unauthorized` without falling back to stale cache, correctly preventing an expired session from being masked by cached content — so 401 → session-expiry handling (per `IMPLEMENTATION_NOTES.md`'s "Accessible Alerts" guidance) always fires promptly rather than being silently swallowed by a cache hit.
- **Recommended behavior:** No change.
- **Manual verification required:** No. **Regression tests required:** No.

### NET-06 — Comprehensive defensive parsing throughout the JSON:API layer (PASS)

- **Category:** PASS
- **Evidence:** `JSONAPI.swift`/`Mappers.swift` degrade gracefully rather than throwing on malformed live data: `JSONValue` falls back to `.null`, `parseDrupalDate` falls back to `.distantPast` (explicitly reasoned in its own doc comment about live production data being frequently malformed), and every `Mappers` function uses `?? ""`/`?? 0` defaults rather than force-unwraps.
- **Recommended behavior:** No change; this is a strong, deliberate resilience pattern. Note: `parseDrupalDate`'s `.distantPast` fallback is exactly the mechanism behind PROFILE-03's fabricated "Member since January 1, 1" bug — the *parsing* resilience is correct and worth keeping, but consumers of a `.distantPast`-sentineled date need to check for the sentinel before rendering it as if it were real data (see PROFILE-03 in `12_SCREEN_PROFILE_ONBOARDING.md`).
- **Manual verification required:** No. **Regression tests required:** No (already a good pattern; the gap is in the sentinel *not being checked* downstream, tracked separately as PROFILE-03).

### NET-07 — `forumFromRecent()` has dedicated, well-reasoned validation with regression-test coverage (PASS)

- **Category:** PASS
- **Evidence:** `Mappers.forumFromRecent()` specifically validates UUID format and confirms the item's URL is actually a forum-topic path before accepting it, with doc comments citing two distinct live-production bug repros this hardening was built against. This is the one mapper function with dedicated regression test coverage (see TEST-03).
- **Recommended behavior:** No change; use as the template for hardening the other 8 (currently untested — see TEST-03) mapper functions.
- **Manual verification required:** No. **Regression tests required:** Already covered; extend the same pattern elsewhere.

### NET-08 — Cloudflare-bypass mechanism is fragile by design, with no failure-mode signal

- **Severity:** P3 · **Category:** MANUAL VERIFY (cross-reference SEC-06/ARCH-03 in the companion doc)
- **Evidence:** `APIClient.swift`/`DrupalFormClient.swift` use a spoofed User-Agent plus a static header to bypass Cloudflare.
- **Current behavior:** Any Cloudflare rule change could silently break all API access, with no client-side signal distinguishing "got an HTML challenge page" from "got a generic decode error" — both would likely surface identically to the user as an unexplained failure.
- **Recommended behavior:** Add a specific check for Cloudflare challenge-page markers in a failed decode, surfacing a distinct, more actionable error message ("AppleVis.com's security check is blocking the app — please try again later" vs. a generic error) rather than the same generic failure as any other decode error.
- **Exact reason:** This entire mechanism is inherently fragile and outside the app's control; at minimum, failures should be diagnosable rather than indistinguishable from unrelated errors.
- **Suggested implementation approach:** Detect HTML-challenge-page content in a failed JSON decode and surface a distinct error/log entry.
- **Manual verification required:** Yes — periodic real-world confirmation this still works, since it depends on external infrastructure the app doesn't control.
- **Regression tests required:** No practical automated test for external service behavior; add the distinct-error-detection logic and log it (see DIAG-02 in the companion doc).

### NET-09 — Submission forms depend entirely on regex-scraping raw HTML for tokens, with no diagnostic trail on failure

- **Severity:** P2 · **Category:** TEST GAP / ARCHITECTURE ISSUE
- **Evidence:** `DrupalFormClient.swift`'s `fetchTokens()` — Blog/Bug/Podcast/Contact submission entirely depends on regex-scraping form tokens out of raw HTML, with zero structural HTML parsing. The failure path has no `AppLog` call at all.
- **Current behavior:** Any Drupal theme/markup change silently breaks all four submission forms simultaneously, surfacing only a generic error with zero device-side diagnostic trail distinguishing "network failure" from "not authenticated" from "markup changed under us."
- **Recommended behavior:** Add `AppLog` calls at each failure branch in `fetchTokens()`, distinguishing the failure cause where possible, so a future regression is diagnosable via sysdiagnose rather than requiring code archaeology.
- **Exact reason:** Regex-scraping HTML is inherently the most fragile integration point in the app (more fragile than the JSON:API endpoints, which have real structure); the complete absence of any diagnostic trail on this specific fragile path compounds the risk.
- **Suggested implementation approach:** Add `AppLog.network` (or equivalent — see DIAG-02) calls at each failure branch; consider a lightweight structural check (e.g. confirming the response actually looks like the expected form page) before attempting regex extraction, to fail fast with a clearer signal.
- **Manual verification required:** No. **Regression tests required:** Yes — see TEST-01/NET-09 cross-reference in the companion doc; a fixture-based test of `fetchTokens()` against a captured real HTML sample would catch a real regression immediately rather than only in production.

### NET-10 — `ItunesAPI` uses raw `JSONSerialization` instead of the app's own established parsing conventions

- **Severity:** P3 · **Category:** ARCHITECTURE ISSUE
- **Evidence:** `ItunesAPI.swift` parses responses via raw `JSONSerialization` + `as?` casts rather than the `JSONValue`/`Decodable` conventions used consistently everywhere else in `Networking/`.
- **Current behavior:** One inconsistent parsing style in an otherwise-consistent codebase.
- **Recommended behavior:** Migrate to the same `JSONValue`/`Decodable` pattern used elsewhere, gaining the same defensive-parsing benefits documented in NET-06.
- **Exact reason:** Consistency and defensive-parsing parity — `JSONSerialization` + `as?` casts don't get the same graceful-degradation behavior the rest of the app has deliberately built.
- **Suggested implementation approach:** Refactor `ItunesAPI`'s response parsing to match the rest of `Networking/`.
- **Manual verification required:** No. **Regression tests required:** Yes, once refactored.

### NET-11 — Two network clients use system-default timeouts instead of the app's explicit fast-fail policy

- **Severity:** P3 · **Category:** UX INCONSISTENCY
- **Evidence:** `DrupalFormClient.swift`/`ItunesAPI.swift` use `URLSession.shared`'s system-default timeouts (60s request / 7-day resource) instead of `APIClient`'s explicit 10s/30s configuration.
- **Current behavior:** A hung Drupal form-token fetch (feeding into NET-09's fragile scraping path) could leave a compose screen stuck loading for up to a full minute instead of failing fast with a retry option, unlike every other network operation in the app.
- **Recommended behavior:** Apply the same explicit timeout configuration `APIClient` already uses to these two clients (this overlaps with ARCH-01's broader recommendation to share one configured session).
- **Exact reason:** A minute-long hang on a compose screen (already one of the more failure-prone paths per NET-09) is a materially worse experience than the fast, clear failure the rest of the app provides.
- **Suggested implementation approach:** Fold into the ARCH-01 fix (shared session configuration).
- **Manual verification required:** No. **Regression tests required:** No.
