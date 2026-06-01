import { useEffect, useState } from 'react';
import { AccessibilityInfo } from 'react-native';

export type AccessibilityPreferences = {
  reduceMotion: boolean;
  boldText: boolean;
  invertColors: boolean;
  reduceTransparency: boolean;
  screenReaderEnabled: boolean;
};

/**
 * Subscribes to iOS accessibility preferences and returns live values.
 *
 * reduceMotion        — skip or shorten animations (Settings → Accessibility → Motion)
 * boldText            — increase font weight in UI (Settings → Accessibility → Display & Text Size)
 * invertColors        — adapt image display (Smart Invert / Classic Invert active)
 * reduceTransparency  — avoid blur effects that become opaque when active
 * screenReaderEnabled — VoiceOver is active; use this to change interaction model
 *
 * Note: "Increase Contrast" (increaseContrast) is not exposed by React Native on iOS.
 * It requires a native module — the stub is documented in nativeModules.ts.
 */
export function useAccessibilityPreferences(): AccessibilityPreferences {
  const [reduceMotion,       setReduceMotion]       = useState(false);
  const [boldText,           setBoldText]           = useState(false);
  const [invertColors,       setInvertColors]       = useState(false);
  const [reduceTransparency, setReduceTransparency] = useState(false);
  const [screenReaderEnabled, setScreenReaderEnabled] = useState(false);

  useEffect(() => {
    // Read initial values
    AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion);
    AccessibilityInfo.isBoldTextEnabled().then(setBoldText);
    AccessibilityInfo.isInvertColorsEnabled().then(setInvertColors);
    AccessibilityInfo.isReduceTransparencyEnabled().then(setReduceTransparency);
    AccessibilityInfo.isScreenReaderEnabled().then(setScreenReaderEnabled);

    // Subscribe to changes
    const subs = [
      AccessibilityInfo.addEventListener('reduceMotionChanged',       setReduceMotion),
      AccessibilityInfo.addEventListener('boldTextChanged',           setBoldText),
      AccessibilityInfo.addEventListener('invertColorsChanged',       setInvertColors),
      AccessibilityInfo.addEventListener('reduceTransparencyChanged', setReduceTransparency),
      AccessibilityInfo.addEventListener('screenReaderChanged',       setScreenReaderEnabled),
    ];

    return () => subs.forEach((s) => s.remove());
  }, []);

  return { reduceMotion, boldText, invertColors, reduceTransparency, screenReaderEnabled };
}
