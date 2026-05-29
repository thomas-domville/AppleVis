# Implementation Notes

This ZIP is a buildable starter scaffold, not a finished production app.

Expo is useful for quickly developing the UI and core experience. The following require native iOS work or config plugins:

- Apple Watch app and complications
- Dynamic Island and Live Activities via ActivityKit
- Full Siri App Intents/App Shortcuts
- iCloud key-value store or CloudKit
- MPRemoteCommandCenter and Now Playing metadata beyond basic audio playback
- Smart Speed/silence trimming DSP
- Voice enhancement/EQ audio pipeline
- Home Screen/Lock Screen/StandBy widgets

Recommended production path:

1. Build and test the Expo UI.
2. Add real AppleVis Drupal API endpoints.
3. Implement local persistence for saved/read/list position.
4. Add account sync through AppleVis API.
5. Add native iOS modules for Apple ecosystem features.
6. Add watchOS target.
7. Add WidgetKit target.
8. Add ActivityKit Live Activity.
9. Complete App Store privacy/accessibility compliance checklist.
