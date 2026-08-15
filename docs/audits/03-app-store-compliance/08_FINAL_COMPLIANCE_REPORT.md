# AppleVis — Final App Store Compliance Report

Companion document: `01_APP_STORE_MASTER_AUDIT_RESULTS.md` (full item-by-item checklist with evidence). This report summarizes that audit in the shape of `08_FINAL_COMPLIANCE_REPORT_TEMPLATE.md`. Read-only audit — no project files were modified.

Build commit: current `master` branch working tree (`216829c` — "Restore long-press context menu for VoiceOver users"), clean status.
Xcode version: project metadata reports `CreatedOnToolsVersion = 26.6` / `LastSwiftUpdateCheck = 2660` (i.e., authored in Xcode 26.6); the actual toolchain used for the submission archive must still be confirmed at archive time.
iOS SDK: `SDKROOT = iphoneos` (resolves to whatever SDK the build machine's installed Xcode provides — confirm it is iOS 26 SDK+ at archive time, per Apple's April 28, 2026 requirement, verified live against `developer.apple.com/news/upcoming-requirements/` on 2026-08-13).
Deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (all targets, Debug and Release).
Marketing version: `MARKETING_VERSION = 1.0` (main app + Share Extension).
Build number: `CURRENT_PROJECT_VERSION = 1` (main app + Share Extension).
Bundle ID: `com.applevis.AppleVisSwift` (main app), `com.applevis.AppleVisSwift.ShareExtension` (Share Extension).

## Status summary

- **PASS:** 33
- **FAIL:** 11
- **NEEDS ATTENTION:** 9
- **MANUAL VERIFY:** 24
- **NOT APPLICABLE:** 7

(Full per-item breakdown in `01_APP_STORE_MASTER_AUDIT_RESULTS.md`.)

## Release blockers

Ranked by how certain and how severe:

1. **No `Assets.xcassets` / `AppIcon` catalog exists anywhere in the Xcode project**, yet `project.pbxproj` sets `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` and `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` on the main app target. This is a dangling reference to a catalog that doesn't exist — the Release archive will either fail to build/validate outright, or ship with no app icon, which App Store Connect rejects unconditionally. **This is the single most important blocker before this app can go to the App Store.** Legacy source art (`app-icon.png`, `app-icon-dark.png`, `app-icon-tinted.png`) is available at `c:\Users\thoma\dev\AppleVis\assets\icons\` and in the audit package's `06_LEGACY_PRODUCTION_ASSETS\icons\` to build the catalog from.
2. **Production bundle identifier mismatch**: native project uses `com.applevis.AppleVisSwift`; the legacy production reference used `com.applevis.app`. Whichever App Store Connect app record already exists for AppleVis almost certainly uses the old ID — this build cannot upload against that existing listing as-is. Needs a decision: revert the bundle ID to match the existing ASC app, or deliberately register a new App ID/app record (with everything that implies for reviews, ratings, and existing users' continuity).
3. **Associated Domains entitlement is absent** despite active, exercised universal-link handling code (`AppleVisApp.swift` → `DeepLinkRouter.handleUniversalLink`). Web links to applevis.com content will never route into the app in production until `com.apple.developer.associated-domains` (`applinks:www.applevis.com`, `applinks:applevis.com`) is added — a functional regression, not just a checklist gap.
4. **Marketing version (`1.0`) and build number (`1`) regress behind the legacy production reference (`2026.0.7` / `11`)**. If this native build is meant to replace the currently-live app, App Store Connect will reject a version/build that doesn't post-date the live one. Resolve alongside the bundle ID decision above — the two are the same underlying question ("is this an update to the existing app, or a new one?").
5. **iOS 26.5 minimum deployment target** excludes the entire user base still on iOS 17–25 on day one. Not a submission blocker by itself (Apple allows any deployment target ≥ the SDK's floor), but almost certainly not the intended product outcome. The handoff notes' proposed iOS 17 minimum is a reasonable fix and appears technically supportable by everything used in the codebase — this is flagged here as a decision to make before submission, not something this audit changed.
6. **User-generated-content reporting is thin**: no per-post "Report" action exists; the only "flag" endpoint in the app is follow/subscribe, not abuse-reporting. The sole path is the general Contact App Support wizard. Given Guideline 1.2 applies directly (forums/comments/reviews), this is worth either a small feature addition (report action that pre-fills Contact Support with the item reference) or explicit App Review notes explaining the existing moderation model (admin-gated edit/delete/unpublish already exists and is authorization-protected).

## App icon/assets

No asset catalog exists in the project at all (confirmed by exhaustive filesystem search — zero `.xcassets`, zero `.appiconset`, zero raster images of any kind under `AppleVisSwift/AppleVisSwift/`). Build settings reference `AppIcon` and `AccentColor` that don't exist. Sound effects were fully carried over from the legacy app (byte-for-byte filename match in `Sources/Resources/Sounds/`). Legacy card/logo/splash imagery was not carried over and isn't referenced anywhere in source — this reads as an intentional move to a fully SwiftUI-drawn UI (colors/gradients/SF Symbols) rather than a missing-asset defect, consistent with the extensive custom-card work documented across prior sessions, but worth a one-line confirmation from the product owner. See `01_APP_STORE_MASTER_AUDIT_RESULTS.md` § "App icon and branding" for the full item list.

## Privacy manifest / required reason APIs

`PrivacyInfo.xcprivacy` is present, in-target, well-formed, and its three collected-data declarations (email/account, iCloud KVS "other user content," APNs device ID) all map to real, findable code — no fabricated or copy-pasted-from-elsewhere entries. `NSPrivacyTracking = false` is consistent with no ad/analytics SDKs anywhere in source. The three required-reason API declarations (`CA92.1` for UserDefaults, `0A2A.1` for File Timestamp, `E174.1` for Disk Space) could not be fully authoritatively re-verified against Apple's official reason-code table in this session (it's a JavaScript-rendered page automated fetch tools couldn't read); a live web search corroborated `E174.1` and `CA92.1` as genuine codes for their categories but surfaced ambiguity around whether `CA92.1` (own-app-only) or `1C8F.1` (App Group) is the technically precise choice given this app's `UserDefaults(suiteName:)` App Group sharing between the main app and Share Extension. The file's own header comment already flags this as unverified — that recheck still needs a human pass against the live Apple doc before submission.

## User-generated content / moderation

Pre-posting guideline nudges exist (`GuidelinesReminderView`/`GuidelinesChecker`) but explicitly never block posting. Post-hoc moderation exists via admin-gated edit/delete/unpublish, properly authorization-checked. No dedicated per-item "Report" action exists; the only in-app path to flag content is the general Contact App Support wizard. No user-blocking feature exists (likely acceptable for a threaded-forum model, not a random-chat model). Public support contact is real and functional. See release blocker #6.

## Entitlements/capabilities

Full capability-by-capability matrix in `01_APP_STORE_MASTER_AUDIT_RESULTS.md` § "Entitlements and capabilities." Summary: iCloud KVS, Push, App Groups, and the Share Extension are all correctly present and match real usage. Associated Domains is the one missing entitlement that matters (blocker #3 above). Keychain Sharing, Siri (SiriKit-style), Handoff, and Spotlight entitlements are correctly absent — nothing in source needs them (App Intents/CoreSpotlight/NSUserActivity don't require these specific entitlement keys). Watch/Widget/Live Activity/Dynamic Island entitlements and code are confirmed completely absent — clean, nothing stale to remove. `aps-environment = development` in the source entitlements file needs confirming as `production` on the actual signed archive (Automatic signing typically handles this at export time, but it must be checked on the real archive, not assumed from source).

## App Privacy / privacy policy

Privacy policy is linked from Settings, Profile, and About. Account/data deletion is described accurately and in detail before the user confirms (`DeleteAccountView.swift`). Logging hygiene is clean — the one debug-only `print()` found logs only an error object, never a token. Live-URL validation (privacy policy, support, guidelines links actually resolving) needs a device-based check before submission — not verifiable from static source alone.

## Account deletion

Fully implemented and functional: `DeleteAccountView.swift` requires an explicit confirmation toggle, clearly lists what's removed, calls a real API (`AccountEndpoints.deleteAccount(uuid:csrfToken:)`), and signs the user out immediately on success. This is one of the strongest sections of the audit — no gaps found.

## App Store Connect metadata

Entirely outside the codebase; nothing here can be marked PASS/FAIL from source. All items (name/subtitle/description/keywords/category/age rating/screenshots/review notes/contact/copyright/release notes/encryption answer) are MANUAL VERIFY / TO BE PREPARED, and the version/build to submit is itself blocked on resolving release blockers #2 and #4 above. Review notes in particular should explicitly explain: browsing works without sign-in but posting/saving requires it; this is an existing, already-moderated community (not new/unmoderated UGC); background audio is for podcast playback; push notifications are for forum-reply/followed-topic alerts.

## Archive validation

Not performed in this audit (source-inspection only, per instructions — no build/archive was run). Based on source inspection, a Release archive attempt today would very likely fail or be rejected at Organizer/App Store Connect validation because of blocker #1 (missing icon catalog) at minimum, and possibly blocker #2 (bundle ID/provisioning mismatch) depending on what's actually registered in the Developer Portal for Team `97YM8TUSX8`. The Xcode scheme correctly builds the Release configuration for `ArchiveAction`, so once the blockers above are fixed, the mechanics of archiving should be straightforward.

## TestFlight certification

Not started — blocked on producing a clean archive first (blockers #1–#3).

## Final decision

**NOT READY.**

The app has a strong technical and privacy foundation (production-only API endpoints, clean Debug/Release separation, accurate and functional account deletion, a well-formed and largely accurate privacy manifest, properly authorization-gated moderation actions, and clean absence of any stale Watch/Widget/Live Activity cruft) — but it cannot currently produce a submittable archive. The missing app icon asset catalog is the fastest, most certain thing to fix and should be resolved first; the bundle ID / version-number question is a product decision that determines whether this is "update the existing AppleVis app" or "launch a new one," and needs to be settled before anything is archived, since it changes what "correct" looks like for blockers #2 and #4.
