import { useEffect, useState } from 'react';
import { AccessibilityInfo } from 'react-native';

export type AccessibilityPreferences = {
  reduceMotion: boolean;
  boldText: boolean;
  invertColors: boolean;
  reduceTransparency: boolean;
  screenReaderEnabled: boolean;
  switchControlEnabled: boolean;
  grayscaleEnabled: boolean;
};

/**
 * Subscribes to iOS accessibility preferences and returns live values.
 *
 * reduceMotion        — skip or shorten animations (Settings → Accessibility → Motion)
 * boldText            — increase font weight in UI (Settings → Accessibility → Display & Text Size)
 * invertColors        — adapt image display (Smart Invert / Classic Invert active)
 * reduceTransparency  — avoid blur effects that become opaque when active
 * screenReaderEnabled — VoiceOver is active; use this to change interaction model
 * switchControlEnabled — Switch Control is active; affects interaction model
 * grayscaleEnabled    — display is in grayscale; avoid colour-only meaning
 *
 * Note: "Increase Contrast" (increaseContrast) is not exposed by React Native on iOS.
 * It requires a native module — the stub is documented in nativeModules.ts.
 */
export function useAccessibilityPreferences(): AccessibilityPreferences {
  const [reduceMotion,         setReduceMotion]         = useState(false);
  const [boldText,             setBoldText]             = useState(false);
  const [invertColors,         setInvertColors]         = useState(false);
  const [reduceTransparency,   setReduceTransparency]   = useState(false);
  const [screenReaderEnabled,  setScreenReaderEnabled]  = useState(false);
  const [switchControlEnabled, setSwitchControlEnabled] = useState(false);
  const [grayscaleEnabled,     setGrayscaleEnabled]     = useState(false);

  useEffect(() => {
    // Read initial values
    AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion);
    AccessibilityInfo.isBoldTextEnabled().then(setBoldText);
    AccessibilityInfo.isInvertColorsEnabled().then(setInvertColors);
    AccessibilityInfo.isReduceTransparencyEnabled().then(setReduceTransparency);
    AccessibilityInfo.isScreenReaderEnabled().then(setScreenReaderEnabled);
    // Guard with optional chaining: these APIs may be absent in older Expo Go RN bundles.
    // A regular .catch() won't help when the function itself is undefined (synchronous throw).
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (AccessibilityInfo as any).isSwitchControlEnabled?.()?.then(setSwitchControlEnabled)?.catch(() => {});
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (AccessibilityInfo as any).isGrayscaleEnabled?.()?.then(setGrayscaleEnabled)?.catch(() => {});

    // Subscribe to changes
    const subs = [
      AccessibilityInfo.addEventListener('reduceMotionChanged',       setReduceMotion),
      AccessibilityInfo.addEventListener('boldTextChanged',           setBoldText),
      AccessibilityInfo.addEventListener('invertColorsChanged',       setInvertColors),
      AccessibilityInfo.addEventListener('reduceTransparencyChanged', setReduceTransparency),
      AccessibilityInfo.addEventListener('screenReaderChanged',       setScreenReaderEnabled),
      AccessibilityInfo.addEventListener('grayscaleChanged',          setGrayscaleEnabled),
    ];

    return () => subs.forEach((s) => s.remove());
  }, []);

  return {
    reduceMotion, boldText, invertColors, reduceTransparency,
    screenReaderEnabled, switchControlEnabled, grayscaleEnabled,
  };
}
