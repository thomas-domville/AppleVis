# Project Structure

AppleVis is a native SwiftUI iOS app. The active Xcode project now lives at the repository root.

## Root Layout

- `AppleVis.xcodeproj/` - Xcode project. Open this file in Xcode.
- `AppleVis/` - Main app target.
- `AppleVis/Sources/` - App source code.
- `AppleVis/Sources/Resources/` - Runtime resources such as localized strings and bundled sounds.
- `AppleVis/Assets.xcassets/` - App icon and asset catalog used by the app target.
- `AppleVisShareExtension/` - Share Extension source.
- `AppleVisTests/` - Unit tests.
- `AppleVisUITests/` - UI tests.
- `assets/` - Source/reference assets used to create or mirror app resources.
- `docs/` - Active project documentation, implementation notes, release notes, audits, and asset manifest.
- `archive/` - Historical source material and temporary notes preserved for reference only.

## Naming Conventions

- Swift types use standard Swift naming: `UpperCamelCase` for types and `lowerCamelCase` for members.
- Runtime asset filenames use lowercase `snake_case`, with no spaces.
- User-facing labels can be natural title case even when the underlying file name is lowercase.
- Keep active app resources under `AppleVis/`; keep source/reference copies under `assets/`.

## Archive Policy

Files under `archive/` are not part of the app's runtime source. Do not add new implementation work there unless it is intentionally historical reference material.
