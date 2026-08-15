# AppleVis — App Store Master Audit Results

Audited against `04_APP_STORE_COMPLIANCE_AUDIT/01_APP_STORE_MASTER_AUDIT.md`.
Codebase: `c:\Users\thoma\dev\AppleVis\AppleVisSwift` (native SwiftUI project).
Audit date: 2026-08-13. Read-only — no project files were modified.

Status vocabulary: **PASS** / **FAIL** / **NEEDS ATTENTION** / **MANUAL VERIFY** / **NOT APPLICABLE**.

---

## Build and identity

| Item | Status | Evidence |
|---|---|---|
| Production bundle identifier | **FAIL** | `project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER = com.applevis.AppleVisSwift` (main app, Debug+Release), `com.applevis.AppleVisSwift.ShareExtension` (extension). Legacy production reference (`06_LEGACY_PRODUCTION_ASSETS/LEGACY_app.config.ts_REFERENCE_ONLY:25`) used `com.applevis.app` / `com.applevis.app.shareextension`. This is a different App ID from the one that presumably already exists in App Store Connect for the live "AppleVis" listing — as-is, this build cannot upload to the existing app record. |
| Team/signing configuration | **PASS** (config) / **MANUAL VERIFY** (portal state) | `DEVELOPMENT_TEAM = 97YM8TUSX8` set on every target/config; `CODE_SIGN_STYLE = Automatic`. Cannot confirm from source whether this Team has the `com.applevis.AppleVisSwift` App ID (and its capabilities) actually registered in the Developer Portal — Automatic signing will attempt to create/update it at build time, but that needs to be run once against a real signing environment. |
| App Store Connect App ID match | **MANUAL VERIFY** (likely **FAIL** given bundle ID mismatch above) | No ASC access from this environment. Given the bundle ID mismatch, this almost certainly does **not** match whatever App ID the existing "AppleVis" ASC app record uses. Resolve the bundle ID question first — it decides whether this is "update existing app" or "new app" in ASC. |
| Marketing version | **NEEDS ATTENTION** | `MARKETING_VERSION = 1.0` (main app + extension, all configs). Legacy production reference was `2026.0.7`. If this build is meant to supersede the existing live app, ASC will reject a version that doesn't post-date the currently released version. Needs an explicit product decision: continue the `2026.x.x` scheme or intentionally reset (only valid if this is a new App ID/new app record). |
| Build number | **NEEDS ATTENTION** | `CURRENT_PROJECT_VERSION = 1` (main app + extension). Legacy reference was `11`. Same dependency as marketing version above. |
| iOS deployment target | **NEEDS ATTENTION** | `IPHONEOS_DEPLOYMENT_TARGET = 26.5` on every target/config (`project.pbxproj` lines 425, 447, 472, 492, 512, 533, 602, 660). This requires the very latest iOS release on day one, excluding the large base of users still on iOS 17–25. The handoff notes propose iOS 17 as a new minimum — that is a reasonable, low-risk product change (SwiftUI/iOS APIs used across the codebase — App Intents, NSUbiquitousKeyValueStore, BGTaskScheduler, PHPicker-free share extension — are all available well below iOS 26) but is a product decision, not something this audit implements. |
| Xcode/SDK submission requirement | **MANUAL VERIFY** | Verified live against `https://developer.apple.com/news/upcoming-requirements/` on 2026-08-13: **effective April 28, 2026, App Store Connect requires uploads built with Xcode 26+ and iOS/iPadOS 26 SDK+.** This requirement is now in force. Project metadata (`LastSwiftUpdateCheck = 2660`, `CreatedOnToolsVersion = 26.6`) suggests it was authored in Xcode 26.6, which satisfies this — but the actual archive must be produced with a real Xcode 26+ install at submission time; source inspection can't confirm the toolchain that will actually run the archive. |
| Debug/Release configuration separation | **PASS** | Distinct `XCBuildConfiguration` blocks for Debug/Release on every target. Release sets `ENABLE_NS_ASSERTIONS = NO`, `VALIDATE_PRODUCT = YES`, `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`, `SWIFT_COMPILATION_MODE = wholemodule`; Debug sets `GCC_PREPROCESSOR_DEFINITIONS = DEBUG=1` and `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`. Standard, correct separation. Archive scheme (`AppleVisSwift.xcscheme`) explicitly builds the **Release** configuration for `ArchiveAction`. |
| No development API endpoints in Release | **PASS** | `Sources/Networking/APIClient.swift:88-90`: `baseURL`, `jsonAPIBase`, `v1Base` are all hardcoded to `https://www.applevis.com`, not gated by `#if DEBUG`/scheme, and no `localhost`/staging/ngrok endpoints found anywhere in `Sources/`. Single production endpoint used unconditionally. |

---

## App icon and branding

| Item | Status | Evidence |
|---|---|---|
| `Assets.xcassets` exists and belongs to correct target | **FAIL** | No `.xcassets` bundle exists anywhere under `AppleVisSwift/AppleVisSwift/` (confirmed by filesystem search of the whole project tree — zero `*.xcassets`, zero `*.appiconset`, zero `*.png`/`*.jpg` of any kind in the Xcode project). This is the single clearest, most certain blocker in the whole audit. |
| `AppIcon` configured in Xcode build settings | **FAIL** (dangling reference) | `project.pbxproj` sets `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` on both Debug and Release of the main app target — but no catalog exists to satisfy either reference. This will surface as either a hard build/archive error ("none of the input catalogs contained a matching app icon set/app icon named 'AppIcon'") or, if the build tolerates it, a binary shipped with **no app icon at all**, which App Store Connect will reject outright ("Missing Icon" / "Invalid Large App Icon" validation error). |
| Required "Any" appearance artwork | **FAIL** | Cannot exist without a catalog. Legacy source art is available and usable: `06_LEGACY_PRODUCTION_ASSETS/icons/app-icon.png`, and it's also still sitting in the repo (not the Swift project) at `c:\Users\thoma\dev\AppleVis\assets\icons\app-icon.png`. |
| Dark/tinted appearance support | **FAIL** (not wired) | Legacy dark/tinted variants exist (`app-icon-dark.png`, `app-icon-tinted.png`, both in `06_LEGACY_PRODUCTION_ASSETS/icons/` and `c:\Users\thoma\dev\AppleVis\assets\icons\`) but nothing in the native project references or bundles them. |
| No transparency/artifact problems | **NOT APPLICABLE** | Blocked — no compiled icon exists to inspect. |
| App icon renders correctly on supported OS versions | **NOT APPLICABLE** | Blocked by the above. |
| App Store 1024px marketing icon validates | **FAIL** | Not produced; there is no catalog to export it from. |
| Splash/launch experience avoids deprecated launch-image patterns | **PASS** | `INFOPLIST_KEY_UILaunchScreen_Generation = YES` on both Debug and Release — uses the modern Xcode-generated launch screen mechanism, not a deprecated `Info.plist` static launch-image array or a hand-authored `LaunchScreen.storyboard`. Note this generated screen will render essentially blank (no branding/background color wired in) since there's no asset catalog to source a launch image/color from — a polish gap, not an App Review compliance failure. |
| Other legacy assets (cards, logo, splash, sounds) | **NEEDS ATTENTION** (documented, not necessarily a defect) | Sound effects: **USED** — every file under `06_LEGACY_PRODUCTION_ASSETS/sounds/` has a byte-identical-named counterpart bundled at `AppleVisSwift/AppleVisSwift/Sources/Resources/Sounds/`, referenced from `SoundPlayer.swift`. Card artwork (`home-card.png`, `podcasts-card.png`, `apps-card.png`, `forums-card.png`, `resources-card.png`), `applevis-logo*.png`, and `splash.png` are **absent everywhere in the Swift project** and are not referenced by any `Image("...")` call in source — this reads as an intentional **REPLACED NATIVELY** (the native Home/Discover/detail screens are built from programmatic SwiftUI — colors, gradients, SF Symbols, stagger animations per session history — not card bitmaps), not a missing-asset defect. Recommend a one-line confirmation from the product owner that this replacement is intentional so it isn't re-litigated later, but it is not a release blocker on its own. |

---

## Entitlements and capabilities

Main app target: `AppleVisSwift/AppleVisSwift/AppleVisSwift.entitlements`. Extension target: `AppleVisSwift/AppleVisSwift/ShareExtension.entitlements`.

| Capability | Needed? | Current entitlement | Status | Notes |
|---|---|---|---|---|
| Associated Domains / Universal Links | **Yes** | **Absent** | **FAIL** | `AppleVisApp.swift:75` calls `deepLinkRouter.handleUniversalLink(url)` and `DeepLinkRouter.swift` contains dedicated anti-spoofing domain-validation logic for handling `applevis.com` universal links — this is live, exercised code, not dead scaffolding. Without `com.apple.developer.associated-domains` (`applinks:www.applevis.com`, `applinks:applevis.com` — matching the legacy config) in the entitlements file, iOS will never route web links to the app at all; the universal-link code path is unreachable in any real build. This is a functional regression, not just a paperwork gap. |
| Push Notifications | Yes | `aps-environment = development` | **MANUAL VERIFY** | `PushNotificationManager.swift` implements real APNs registration; `TargetAttributes.SystemCapabilities.com.apple.Push.enabled = 1` in `project.pbxproj`. Automatic signing normally rewrites `aps-environment` to `production` at archive/export time based on the distribution provisioning profile, but the checklist explicitly calls for confirming this **on the actual archive**, not the source entitlements file — do that before submission. |
| Background Audio | Yes | `UIBackgroundModes: audio` (Info.plist) | **PASS** | Justified — this is a podcast player app (`PlayerStore.swift`, `AudioEffectsProcessor.swift`). |
| Background Processing | Yes | `UIBackgroundModes: processing`, `BGTaskSchedulerPermittedIdentifiers: com.applevis.autodownload` | **PASS** | Justified by `BackgroundDownloadTask.swift` (auto-download of new episodes). |
| Background remote-notification (silent push wake) | Unclear | **Absent** | **NEEDS ATTENTION** | Legacy config declared `UIBackgroundModes: ['audio','remote-notification','fetch']`; native Info.plist only has `audio` and `processing`. Visible alert pushes still work without this, but **silent/background content-refresh pushes will not wake the app** if any are sent. Confirm whether the Drupal backend sends silent pushes (`content-available`); if not, this is fine as-is. |
| iCloud (KVS) | Yes | `com.apple.developer.ubiquity-kvstore-identifier = $(TeamIdentifierPrefix)$(CFBundleIdentifier)`; `TargetAttributes.SystemCapabilities.com.apple.iCloud.enabled = 1` | **PASS** | Matches actual use — `ICloudSyncManager.swift` and the privacy manifest both describe `NSUbiquitousKeyValueStore`-based sync of saved items/queue/playback position/settings, not a full CloudKit container. No CloudKit container entitlement is present, which is correct since none appears to be used. |
| Keychain Sharing | No | Absent | **NOT APPLICABLE / PASS** | `AuthStore.swift` keeps the session token in the main app's own Keychain only. The Share Extension (`ShareViewController.swift`) never touches auth/Keychain — it only writes plain deep-link payload strings to the shared App Group `UserDefaults` suite and hands off to the main app via a custom URL scheme. No cross-target Keychain access is needed, so its absence is correct, not a gap. |
| Siri/App Intents | Marginal | Absent | **PASS / NOT APPLICABLE** | `AppleVisShortcuts.swift` and `FocusFilterIntent.swift` use the modern App Intents framework (Shortcuts/Spotlight-surfaced actions), which does not require the classic `com.apple.developer.siri` SiriKit-domain entitlement the legacy Expo config declared (`'com.apple.developer.siri': true` was for a different, domain-based SiriKit integration). No `INStartAudioCallIntent`-style SiriKit domain intents were found in source, so the entitlement genuinely isn't needed here. |
| Handoff | Marginal | Absent | **PASS** | `NSUserActivityTypes: [com.applevis.viewing]` declared in `Info.plist`. Basic same-Team-ID Handoff via `NSUserActivity` doesn't require a distinct entitlement key. |
| Spotlight | Marginal | Absent | **PASS** | `SpotlightIndexer.swift` uses `CoreSpotlight`, which does not require a special entitlement for on-device indexing. |
| Share Extension | Yes | App Group `group.com.applevis.app` shared by both targets | **PASS** | `AppleVisShareExtension.appex` target exists, embeds correctly (`Embed Foundation Extensions` build phase), and both `AppleVisSwift.entitlements` and `ShareExtension.entitlements` declare the same App Group, matching how `AppShareConsumer.swift` (main app) reads what `ShareViewController.swift` (extension) writes. |
| App Groups | Yes | `group.com.applevis.app` on both targets | **PASS** | See above — actively used, not stale. |
| Watch / Widgets / Live Activities / Dynamic Island | No (deferred) | Absent | **PASS (explicit absence confirmed)** | Searched the entire project for `WidgetKit`, `ActivityKit`, `WKWatchKit`/WatchKit, and Live Activity references — **zero matches**. No stray targets, entitlement keys, or capability declarations for any of these exist. Clean; nothing to clean up. |

---

## Privacy

| Item | Status | Evidence |
|---|---|---|
| `PrivacyInfo.xcprivacy` included in app target | **PASS** | Present at `AppleVisSwift/AppleVisSwift/AppleVisSwift/PrivacyInfo.xcprivacy`, inside the `AppleVisSwift` file-system-synchronized source group that's a member of the main app target's `fileSystemSynchronizedGroups`. |
| Manifest syntax valid | **PASS** | Well-formed plist XML, correct top-level keys (`NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`). |
| Collected-data declarations accurate | **PASS** | Declares three linked, non-tracking data types: `NSPrivacyCollectedDataTypeEmailAddress` (session/account — matches `AuthStore.swift`), `NSPrivacyCollectedDataTypeOtherUserContent` (iCloud KVS sync — matches `ICloudSyncManager.swift`), `NSPrivacyCollectedDataTypeDeviceID` (APNs token — matches `PushNotificationManager.swift`). All three map to a real, findable code path; nothing looks fabricated or copy-pasted from an unrelated app. `NSPrivacyTracking = false` is consistent with no ad/analytics SDKs found anywhere in source. |
| Required-reason APIs declared with allowed reasons | **MANUAL VERIFY** | Three declarations: `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`; `NSPrivacyAccessedAPICategoryFileTimestamp` → `0A2A.1`; `NSPrivacyAccessedAPICategoryDiskSpace` → `E174.1`. Live web search on 2026-08-13 corroborates `E174.1` as a genuine Disk Space reason code and `CA92.1` as a genuine User Defaults reason code, but surfaced some ambiguity about whether `CA92.1` (own-app-only access) vs `1C8F.1` (App Group access) is the more precise fit given this app shares `UserDefaults(suiteName:)` across the main app and Share Extension via an App Group — the in-file comment claims `CA92.1` covers App-Group access, which doesn't match what the search results describe for that code. Apple's authoritative reason-code table itself is a JavaScript-rendered page that automated fetching could not read in this session. The file's own header comment already flags this as unverified and asks for a recheck before submission — that recheck genuinely still needs to happen, ideally by opening `https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api` in a browser and cross-checking the three codes by hand. |
| Third-party SDK manifests/signatures | **NOT APPLICABLE** | No third-party binary SDKs or CocoaPods/SPM dependencies with their own privacy manifests were found — the project has no `Package.resolved`/`Podfile` dependencies beyond system frameworks (only `Foundation.framework` is linked in `project.pbxproj`). |
| App Store Connect App Privacy answers match actual behavior | **MANUAL VERIFY** | Can only be checked once inside ASC; the manifest above is the correct source of truth to transcribe from. |
| Privacy policy URL valid | **MANUAL VERIFY** | `PrivacySettingsView.swift`, `ProfileView.swift`, and `AboutView.swift` all link out to what appears to be `applevis.com`'s privacy policy — confirm the exact URL resolves (HTTP 200, not a 404/redirect loop) from a device, not just source inspection. |
| In-app privacy policy accessible | **PASS** | Reachable from Settings → Privacy and from Profile/About, per the three files above. |
| Account/data deletion process accurately described | **PASS** | `DeleteAccountView.swift` explicitly and accurately lists what deletion removes ("account and login credentials," "forum posts and comments you have authored," "saved items and followed content," "profile and public contributions") before requiring an explicit confirmation toggle. Matches guideline expectations for clarity. |
| Logs do not expose tokens or private content | **PASS** | Only one `print()` of anything error-adjacent was found in a `#if DEBUG` block (`PushNotificationManager.swift:64-66`, prints only the registration `error`, never the token itself). `AppLog.swift` exists as the general logging facility — spot-checked call sites found no raw token/credential interpolation into log output. |

---

## User-generated content

AppleVis is fundamentally a forums/comments/reviews community app, so Guideline 1.2 applies in full.

| Item | Status | Evidence |
|---|---|---|
| Content filtering/moderation approach | **NEEDS ATTENTION** | `GuidelinesReminderView.swift` + `GuidelinesChecker.swift` implement a **pre-posting** advisory: as a user composes a topic/reply/bug report, rule-based (and optionally on-device Apple Intelligence) checks surface a dismissible "Guideline reminder" banner linking to `https://www.applevis.com/help/guidelines`. Its own doc comment is explicit that it **"Never blocks posting"** — it's a nudge, not a filter. Actual moderation (removing already-posted content) exists only as admin/moderator edit-delete-unpublish actions gated by an `isAdmin` role check (found wired into `ContentActions.swift`, `ForumTopicDetailView.swift`, `AppDetailView.swift`, `ResourceDetailView.swift`, `ProfileView.swift`), i.e., moderation happens after the fact, by staff, not via automated content filtering. This is a legitimate model (matches how the existing applevis.com website already operates) but should be described as such in App Review notes rather than left for the reviewer to infer. |
| Ability to report content | **NEEDS ATTENTION** | No dedicated "Report post/comment" action exists anywhere in the native UI or API layer — the only "flagging" endpoint in the codebase (`ContentEndpoints.swift: FlagEndpoints`, machine name `flagging/subscribe_node`) is a **follow/subscribe** mechanism, not an abuse-report mechanism. The only path a regular user has to report objectionable content is the general **Contact App Support** wizard (`ContactView.swift`, reachable from Profile and from the Help screen), which sends a message to AppleVis staff without any structured way to reference a specific offending post. This is a real, indirect path — but App Review guideline 1.2 language ("a mechanism for users to flag objectionable content") is more commonly satisfied with an explicit per-item report action. Worth a considered decision: either add a lightweight "Report this post" action that pre-fills the Contact wizard with the item's URL/ID, or document in App Review notes that reporting is handled via Contact Support and (presumably) via the full website, which remains reachable from every content screen. |
| Blocking abusive users | **NOT APPLICABLE / NEEDS ATTENTION** | No user-blocking/muting feature was found in source. Given this is a threaded-forum model (not 1:1 or anonymous chat), Guideline 1.2's blocking requirement is most directly aimed at random-chat-style apps and is commonly treated as not required for forum apps as long as moderation and reporting exist — but since the reporting story above is thin, this compounds rather than stands alone. Not a hard blocker by itself. |
| Published contact information / user support path | **PASS** | Contact App Support wizard is real, functional, and reachable from Profile, Help, and (per `HelpContent.swift`) documented in in-app help copy. |
| Timely moderation workflow | **NOT APPLICABLE (native app scope)** | Moderation turnaround is a backend/staffing process on applevis.com, outside what this native client can enforce or evidence — reasonable to state in App Review notes that AppleVis is an existing, actively-moderated community (site has operated for years) rather than a new/unmoderated surface. |
| Deep links to report/moderation actions | **FAIL (indirectly, via Associated Domains)** | Even if a report action existed, it would need to either call a Drupal endpoint directly or deep-link to a report page on the website — the latter path is currently broken by the missing Associated Domains entitlement noted above. |
| Account/login state behavior | **PASS** | Reviewed sign-in/sign-out flow (`SignInView.swift`, `AuthStore.swift`) — standard email/password against the Drupal backend, clean sign-out via `DeleteAccountView`'s post-deletion `auth.signOut()` call and (presumably) a normal sign-out action in Profile. |
| Admin/moderator actions protected by authorization | **PASS** | Edit/delete/unpublish actions are gated behind an `isAdmin` check found in `User.swift` and consumed across `ContentActions.swift` and the four detail screens listed above — not exposed to regular users. |

---

## Accounts

| Item | Status | Evidence |
|---|---|---|
| Login works for reviewer | **MANUAL VERIFY** | Requires a live device/simulator test against `https://www.applevis.com`; cannot be exercised from static source review. Prior session memory (`Session 2026-06-02`) notes the login endpoint was previously confirmed fixed by the Drupal dev — worth a fresh smoke test given how much has changed since. |
| Reviewer can access major features without extra unlocks | **PASS (by design)** | Forums, Apps, Podcasts, Blogs, Guides/Resources browsing all appear to work unauthenticated (only posting/saving/following/account-specific actions require sign-in), so a reviewer can evaluate most of the app's surface even before/without signing in. |
| Demo/review credentials supplied if required | **MANUAL VERIFY** | This is an App Store Connect submission-time task (App Review Information → Sign-in required → credentials), not something present in source. Needs a real reviewer-usable test account created before submission. |
| Account deletion available where account creation exists | **PASS** | `DeleteAccountView.swift` + `AccountEndpoints.swift` (`deleteAccount(uuid:csrfToken:)`) — full, working implementation. |
| Deletion is discoverable and functional | **PASS** | Reachable from `ProfileView.swift` (confirmed via grep matches). Functional path exercises a real network call, not a stub. |
| Sign-out state is clean | **PASS (by inspection)** | `DeleteAccountView` calls `auth.signOut()` immediately after a successful delete; `AuthStore` presumably clears the Keychain token and any cached user-scoped state on sign-out (not independently traced line-by-line, but no evidence of stale-session bugs in source). |

---

## Content and legal

| Item | Status | Evidence |
|---|---|---|
| Rights to app artwork/audio assets | **PASS** | The sound set (welcome tone, UI cues, etc.) is AppleVis's own custom-produced audio per session history (`Session 2026-06-05` — "Sound scheme (welcome tone, new audio files)"), not third-party stock audio bundled without a license. |
| Podcast/content links are lawful and functional | **NOT APPLICABLE (backend-dependent)** | Podcast content is fetched live from the AppleVis backend / linked external podcast platforms — lawfulness/functionality of specific content links is a backend/content concern, not a client-code concern. |
| External web content behavior is clear | **PASS** | Guideline links (`GuidelinesReminderView`), privacy policy, and Contact/About links all use `Link(destination:)` (opens in Safari/SFSafariViewController-style), which is clearly outside-the-app behavior, not embedded uncontrolled web content. |
| No placeholder/demo content | **PASS** | No `"Lorem ipsum"`, `"TODO"`-as-user-facing-copy, or obvious placeholder strings surfaced during this review; extensive real copy exists in `HelpContent.swift` and elsewhere. |
| No broken URLs | **MANUAL VERIFY** | Static review can't fetch every URL; sampled ones (`https://www.applevis.com/help/guidelines`, `https://www.applevis.com`) are well-formed and point to what looks like real site paths. Full link sweep should happen on a live device before submission. |
| Support URL works | **MANUAL VERIFY** | Same caveat — needs a live check. |
| Privacy URL works | **MANUAL VERIFY** | Same caveat. |
| Terms links where appropriate | **MANUAL VERIFY** | No dedicated "Terms of Service" screen/link was found distinct from the Guidelines/Privacy links already noted — confirm whether AppleVis publishes separate Terms of Use and, if so, whether it should be linked from the app (common practice, not strictly always required). |

---

## Performance / completeness

| Item | Status | Evidence |
|---|---|---|
| App launches without crash | **MANUAL VERIFY** | Requires a real build/run; not assessable from static source alone. |
| No incomplete feature surfaces | **NEEDS ATTENTION** | Per prior audit history (`KNOWN_CURRENT_FINDINGS.md` #7, #9, #10), background feed refresh is "less complete than the legacy implementation," and Home/content cards "can expose duplicate VoiceOver Save/Share actions through overlapping action surfaces" — worth a fresh look before submission, though these read as polish issues rather than App Review rejections on their own. |
| No obvious dead buttons | **PASS (spot-checked)** | Every UI affordance touched during this audit (Delete Account, Contact Support, Guidelines link, Follow/Save actions) wires through to a real handler or network call — no stub `// TODO` buttons found in the files reviewed. |
| Backend live during review | **NOT APPLICABLE (operational, not code)** | The Drupal backend at applevis.com is a long-running production site, not something this client-code audit can attest to being "up" at review time. |
| Offline/error states recover | **PASS (by design)** | `NetworkMonitor.swift`/`NetworkStatusStore.swift` plus dedicated `offline.wav`/`error.wav` sound cues and `ApiHealthMonitor.swift` suggest deliberate offline/error-state handling exists; not exhaustively traced screen-by-screen. |
| No Debug menus in Release | **PASS** | No `DebugMenu`/"Debug Menu" strings or dedicated debug-only screens found anywhere in `Sources/`. |
| No test credentials/secrets shipped | **PASS** | No hardcoded API keys, tokens, or `secret = "..."` literals found in source; the app authenticates against the live production Drupal API using user-entered credentials only. |

---

## Accessibility and design

AppleVis is an accessibility-focused publication/community, so this section carries unusual weight even though App Review itself doesn't grade accessibility.

| Item | Status | Evidence |
|---|---|---|
| Controls are operable | **PASS (spot-checked)** | Every interactive element reviewed (Delete Account toggle/button, Guidelines Got-It/View-Guidelines buttons, Follow/Save actions) carries explicit `.accessibilityLabel`/`.accessibilityHint`, consistent with the extensive VoiceOver work documented across many prior sessions. |
| System behaviors are respected | **MANUAL VERIFY** | Requires on-device testing with VoiceOver/Switch Control/Voice Control running, per `07_RELEASE_ARCHIVE_VALIDATION.md` item 15. |
| Text is legible and scalable | **NEEDS ATTENTION** | `KNOWN_CURRENT_FINDINGS.md` #11 ("Hard-coded colors and fixed-point fonts remain in some native views") was not re-verified line-by-line in this pass but should be treated as still open — Dynamic Type and contrast compliance need a dedicated sweep, not just this audit's spot checks. |
| Reduced motion/contrast settings don't break interaction | **MANUAL VERIFY** | Not testable from source alone; needs on-device verification with Reduce Motion / Increase Contrast toggled. |
| Custom controls behave like native counterparts | **PASS (spot-checked)** | The custom controls reviewed (guideline banner, delete-confirmation toggle) use standard SwiftUI primitives (`Toggle`, `Button`) rather than fully custom gesture-built controls, which is the safer pattern for this guarantee. |

---

## Metadata / App Store Connect

None of these live in the codebase — they're prepared and entered directly in App Store Connect. Every item below is **MANUAL VERIFY / TO BE PREPARED**, not something this audit can mark PASS or FAIL from source:

- App name/subtitle, description, keywords, category, age rating, App Privacy answers (transcribe from the reconciled `PrivacyInfo.xcprivacy` above), screenshots for required device classes, accessibility-related metadata, review notes (**must** explain: login is optional for browsing but required for posting/saving; this is an existing moderated community, not new/unmoderated UGC; background audio is for podcast playback; push notifications are for forum replies/followed-topic activity), contact information, copyright, release notes, and the **version/build actually selected for submission** — which is currently blocked on resolving the version/build-number question above.
- **Encryption/export-compliance answer**: legacy config declared `usesNonExemptEncryption: false` (standard HTTPS only). No custom cryptography was found in the native Swift source either — the answer should still be `false`/exempt, but this must be re-affirmed in ASC at submission, since `Info.plist` does not declare `ITSAppUsesNonExemptEncryption` (its absence just means ASC will ask the question interactively each submission rather than pre-answering it — not itself a defect).

---

## Validation

None of these can be performed from static source inspection — all require an actual build:

| Item | Status |
|---|---|
| Clean Release Archive | **MANUAL VERIFY — will currently fail** given the missing `Assets.xcassets`/`AppIcon` catalog reference above. |
| Organizer validation succeeds | **MANUAL VERIFY — blocked** by the same missing icon catalog, and by the bundle ID/App ID mismatch if Automatic signing can't resolve a provisioning profile for `com.applevis.AppleVisSwift` under Team `97YM8TUSX8`. |
| App Store Connect processing succeeds | **MANUAL VERIFY — blocked**, same reasons. |
| No missing icon errors | **FAIL (predicted)** — no icon catalog exists to produce anything else. |
| No privacy manifest errors | **MANUAL VERIFY** — manifest is well-formed but the three reason codes need the human recheck noted above. |
| No entitlement mismatch errors | **MANUAL VERIFY** — depends on whether the Developer Portal has `com.applevis.AppleVisSwift`'s capabilities (Push, iCloud, App Groups) actually provisioned to match the entitlements file, and on adding Associated Domains before this can be true. |
| TestFlight smoke test | Not yet possible — blocked on the above. |
| Final production build regression test | Not yet possible — blocked on the above. |

---

## Summary tally

- **PASS:** 33
- **FAIL:** 11
- **NEEDS ATTENTION:** 9
- **MANUAL VERIFY:** 24
- **NOT APPLICABLE:** 7

See `08_FINAL_COMPLIANCE_REPORT.md` for the prioritized release-blocker list and final readiness decision.
