# Contributing

Thanks for helping with AppleVis.

## Opening The Project

Open `AppleVis.xcodeproj` and build the `AppleVis` scheme.

## Before Changing Code

- Keep changes scoped to the feature or fix you are working on.
- Prefer existing app patterns in `AppleVis/Sources/Views`, `Stores`, `Services`, and `Networking`.
- Update or add tests in `AppleVisTests/` when changing shared logic, parsing, persistence, or network mapping.
- For UI behavior, also consider whether `AppleVisUITests/` should cover the flow.

## Assets

- Runtime assets belong in `AppleVis/Sources/Resources/` or `AppleVis/Assets.xcassets/`.
- Reference/source assets belong in `assets/`.
- Asset filenames should be lowercase `snake_case` with no spaces.
- Keep `docs/ASSET_MANIFEST.md` current when adding, renaming, or removing bundled assets.

## Documentation

- Use `PROJECT_STRUCTURE.md` for repository layout.
- Use `docs/IMPLEMENTATION_NOTES.md` for current implementation notes.
- Use `docs/APPLEVIS_2026_1_MASTER_SPEC.md` for product requirements and intent.
- Use `archive/` only for historical material that should not be treated as active implementation guidance.
