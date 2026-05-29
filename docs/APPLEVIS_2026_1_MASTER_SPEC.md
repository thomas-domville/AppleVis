# AppleVis iOS/iPadOS App Master Spec — 2026.1

## Final Navigation

Bottom tab bar on iPhone must have exactly five tabs to avoid iOS creating a More tab:

1. Home
2. Forums
3. Podcasts
4. Apps
5. Resources

Profile and Settings are not bottom tabs. They live behind a top-right Settings/Profile button, available from Home and optionally from each main tab.

## Naming Decisions

- Community becomes Forums.
- Explore becomes Resources.
- Bookmark becomes Save.
- Bookmarked becomes Saved.
- Saved content is available locally within each content area and globally from Home.

## Home

Home is a personalized dashboard.

Required sections:

- Since Last Visit
- Resume Where You Left Off
- Saved
- Continue Listening
- New forum activity
- New podcast episodes
- Recently updated apps
- New resources and guides
- Notification summary

## Forums

Forums should feel like AppleVis.com but optimized for native iOS.

Required filters:

- Recent: all active topics, sorted by latest activity.
- New: newly created topics, sorted by creation date/time.
- Unread: topics with activity after the user's last-read point, sorted by latest unread activity.
- Since Last Visit: all forum changes since the user's last visit.
- Following: topics the user follows, sorted by latest activity.
- Saved: topics saved for later.

The app must remember forum list position by content ID, not only by scroll offset. New activity may reorder the list, but Resume Where You Left Off should restore the relevant item.

## Podcasts

Podcasts are a flagship feature.

Required player features:

- Background audio playback
- Lock Screen controls
- Control Center controls
- AirPlay
- Bluetooth/headphone controls
- Playback speed: 0.5x through 3.0x
- Adjustable skip back and skip forward times
- Smart Speed / silence trimming
- Voice enhancement
- EQ presets
- Chapters
- Sleep timer
- Queue management
- Downloads
- Saved episodes
- Continue Listening
- Transcript support when available
- iCloud sync for playback position, queue, saved episodes, and settings

Apple ecosystem features:

- Home Screen widgets
- Lock Screen widgets
- StandBy widgets
- Dynamic Island / Live Activities
- Apple Watch app
- Apple Watch complications
- Siri Shortcuts / App Intents

Note: Dynamic Island, Live Activities, Apple Watch, advanced App Intents, iCloud key-value store, CloudKit, Smart Speed DSP, and MPRemoteCommandCenter require native iOS work beyond a basic Expo managed app.

## Apps

Apps tab includes:

- App directory
- App reviews
- App updates
- New apps
- Saved apps
- Followed apps
- Search and filters
- App icons and rich visual cards

## Resources

Resources is the knowledge center.

Includes:

- Guides
- Tutorials
- How-to articles
- Accessibility resources
- Events
- Developer resources
- Getting Started content
- News and educational content

## Saved Model

Saved items live in two places:

- Local filters: Forums Saved, Podcasts Saved, Apps Saved, Resources Saved.
- Global Home Saved hub: Saved Topics, Saved Podcasts, Saved Apps, Saved Resources.

Saved is not account/profile-only because users expect saved content where they use content.

## Settings Model

Settings home should remain short and clean:

1. Account & Profile
2. Notifications
3. Appearance
4. Accessibility
5. Podcasts
6. Sounds & Haptics
7. Saved & Sync
8. Siri & Shortcuts
9. Help & Support
10. About AppleVis

Include a Settings search field in production.

## Sounds & Haptics

Built-in notification sounds from original ZIP:

- Apple Crunch.wav
- Mouse Squeak.wav

Generated placeholder app sounds included in this project:

- tab-change.wav
- open-section.wav
- picker-change.wav
- save-confirm.wav
- download-complete.wav
- error-soft.wav
- podcast-play.wav
- podcast-pause.wav

All app sounds must be optional. Default on: notification, save confirmation, download complete, and podcast actions. Default off: tab switching, picker changes, opening screens, and list refresh sounds.

## VoiceOver Requirements

- Group related card content into one useful accessibility element.
- Avoid making users swipe through every visual label.
- Use custom actions for Save, Follow, Share, Download, Mark Read, Play Next, etc.
- Never require drag-only interactions.
- Scrubbers must support swipe up/down adjustment.
- Announce playback progress clearly.
- Announce chapter title and chapter number.
- Respect Dynamic Type, Reduce Motion, Reduce Transparency, Bold Text, Button Shapes, and Increase Contrast.
- Provide Accessibility Preview mode.

## iPadOS Requirements

- Native iPad layout, not a stretched iPhone layout.
- Sidebar navigation with Home, Forums, Podcasts, Apps, Resources.
- Split view: list on left, detail on right.
- Podcast mini-player pinned at bottom.
- Full keyboard navigation.
- External keyboard shortcuts.
- Pointer support.
- Stage Manager support.
- Landscape and portrait support.

## Apple App Review / Compliance

Required before App Store submission:

- Privacy policy URL
- Terms of use URL if needed
- App Store privacy nutrition details
- Accessibility Nutrition Label details
- Account deletion initiation inside app if account creation is supported
- Working support link
- Working privacy link
- Proper notification permission prompt
- Accurate background audio usage
- No misleading tracking declarations
- License review for all bundled sounds/images/icons

