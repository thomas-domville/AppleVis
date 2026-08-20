# Asset Manifest

Asset filenames should use lowercase `snake_case` with no spaces. User-facing labels can stay title case in Swift; bundled file names should stay predictable for Xcode, push payloads, and code review.

## Runtime Sounds

Bundled in `AppleVis/Sources/Resources/Sounds/` and mirrored in `assets/sounds/`.

- `apple_crunch.wav`
- `article_open.wav`
- `bookmark_saved.wav`
- `download_complete.wav`
- `error.wav`
- `golden_retriever_bark.wav`
- `loading_start.wav`
- `mouse_squeak.wav`
- `offline.wav`
- `picker_tick.wav`
- `podcast_pause.wav`
- `podcast_play.wav`
- `refresh.wav`
- `reply.wav`
- `screen_close.wav`
- `search_complete.wav`
- `success.wav`
- `sync_complete.wav`
- `tab_change.wav`
- `tip_popup.wav`
- `welcome.wav`

The app loads these through `SoundPlayer` and `NotificationSound.pushSoundFile`.

## Icons

Reference copies live in `assets/icons/`. The app icon catalog lives in `AppleVis/Assets.xcassets/`.

- `app-icon.png`
- `app-icon-dark.png`
- `app-icon-tinted.png`

## Images

Reference images live in `assets/images/`.

- `applevis-logo.png`
- `applevis-logo-2026-black.png`
- `apps-card.png`
- `forums-card.png`
- `home-card.png`
- `podcasts-card.png`
- `resources-card.png`
- `splash.png`

## Animation

- `assets/animations/save-pulse.json`

## Original Archive

The `archive/original-assets/` folder preserves historical source material as received and is not the app's runtime asset source.
