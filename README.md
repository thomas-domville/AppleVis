# AppleVis Expo React Native Starter

Version: 2026.1.0

This package contains a starter Expo React Native project plus updated specs, user guide, accessibility notes, generated placeholder assets, and the two notification sounds from the original AppleVis ZIP.

## Start

```bash
npm install
npx expo start
```

For native iOS background audio and deeper Apple ecosystem features, use a development build:

```bash
npx expo prebuild
npx expo run:ios
```

## Included

- Five-tab navigation: Home, Forums, Podcasts, Apps, Resources
- Settings/Profile moved out of the bottom tab bar
- Saved hub concept
- Forums filters: Recent, New, Unread, Since Last Visit, Following, Saved
- Podcast player UI scaffold
- Background audio configuration placeholder
- VoiceOver-first grouped cards and custom action strategy
- iPad layout notes
- Apple Watch, widgets, Live Activities, Dynamic Island, Siri/App Intents requirements in docs

## Important implementation notes

Expo can scaffold the iPhone/iPad app quickly. Apple Watch, Dynamic Island/Live Activities, advanced App Intents, and some iCloud syncing pieces require native iOS code, EAS development builds, config plugins, or custom Swift modules. The docs folder includes those requirements so the native layer can be added intentionally.
