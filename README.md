# AppleVis (Native Swift)

A native SwiftUI iOS app for AppleVis — an accessibility-focused community for blind and low-vision Apple device users (forums, podcasts, an app directory, and accessibility guides).

This replaced an earlier Expo/React Native prototype; that codebase has been fully removed.

## Open the project

```bash
open AppleVisSwift/AppleVisSwift/AppleVisSwift.xcodeproj
```

Build and run the `AppleVisSwift` scheme in Xcode. The project targets iOS 26.5+ and uses Xcode 16's file-system-synchronized groups, so new files added under `AppleVisSwift/AppleVisSwift/AppleVisSwift/Sources/` are picked up automatically — no manual project-file editing needed for ordinary source changes.

Two additional targets are embedded in the app:

- **AppleVisShareExtension** — handles sharing App Store URLs, podcast links, and blog drafts into AppleVis via the system share sheet.

Both the main app and the Share Extension use the App Group `group.com.applevis.app`, which needs to be enabled on the App ID in your Apple Developer account for local signing to succeed.

## Structure

- `AppleVisSwift/AppleVisSwift/AppleVisSwift/Sources/` — the app: `App/`, `Views/`, `Stores/` (ObservableObjects), `Services/`, `Networking/` (JSON:API client against the AppleVis Drupal backend), `Models/`, `Resources/` (sounds, localized strings).
- `AppleVisSwift/AppleVisSwift/ShareExtension/` — the Share Extension's source.
- `docs/` — implementation notes and the original feature spec; `docs/IMPLEMENTATION_NOTES.md` tracks what's been ported/built vs. still open.
- `assets/` — original reference assets (images, sounds, icons) from the pre-Swift era.

## Included

- Three-tab navigation: Home, Discover (Forums/Podcasts/Apps/Guides/Blogs/Bug Reports hub + search), For You (Queue/Downloads/Saved/Following)
- Podcast player with background audio, Now Playing/lock-screen controls, AirPlay, sleep timer, Voice Boost/Equaliser/Trim Silence audio processing
- iCloud key-value sync (saved items, queue, playback positions, settings)
- Push notifications, Spotlight indexing, Handoff, Focus Filters, Siri/App Intents, hardware keyboard shortcuts
- On-device Apple Intelligence features (rewrite/translate/summarize, guidelines checking) via FoundationModels
- Multi-step submission wizards (App, Blog, Podcast, Bug Report)

## Out of scope for now

Apple Watch app, Home/Lock Screen/StandBy widgets, and Dynamic Island/Live Activities — see `docs/IMPLEMENTATION_NOTES.md` for status and rationale.
