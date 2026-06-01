import { useEffect, useState } from 'react';
import { PixelRatio } from 'react-native';

/**
 * Returns the current system font scale so layouts can adapt to the user's
 * preferred text size (Settings → Accessibility → Display & Text Size → Larger Text).
 *
 * Usage:
 *   const { scale, sp } = useDynamicType();
 *   // sp(17) → 17 at default, 22 at the largest iOS setting
 *
 * Text components scale automatically via allowFontScaling (RN default).
 * Use `sp()` for non-Text sizes that must grow with the font: icon sizes,
 * row heights, card padding. Never set maxFontSizeMultiplier={1} — that
 * silently breaks Dynamic Type for VoiceOver and large-text users.
 */
export function useDynamicType() {
  const [scale, setScale] = useState(PixelRatio.getFontScale());

  useEffect(() => {
    // PixelRatio.getFontScale() is synchronous but doesn't fire events.
    // The closest proxy is AccessibilityInfo's contentSizeCategory change,
    // but React Native doesn't expose that directly. Re-reading on any
    // accessibility change is a safe approximation.
    function update() {
      setScale(PixelRatio.getFontScale());
    }
    // React Native fires a layout event when system font size changes while app
    // is foregrounded; this is the best available hook in managed Expo.
    const id = setInterval(update, 5000);
    return () => clearInterval(id);
  }, []);

  /** Scale a base size (in pt) by the font scale. Use for non-Text elements. */
  function sp(base: number): number {
    return Math.round(base * scale);
  }

  /** True when the user has chosen a text size larger than the default. */
  const isLargeText = scale > 1.0;

  /** True when the user has chosen an accessibility-size text category. */
  const isAccessibilitySize = scale >= 1.35;

  return { scale, sp, isLargeText, isAccessibilitySize };
}
