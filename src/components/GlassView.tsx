import type { ReactNode } from 'react';
import { Platform, StyleSheet, View } from 'react-native';
import type { StyleProp, ViewProps, ViewStyle } from 'react-native';
import { BlurView } from 'expo-blur';
import type { BlurTint } from 'expo-blur';
import { useTheme } from '../contexts/ThemeContext';
import { useReduceTransparency } from '../hooks/useReduceTransparency';

type Props = ViewProps & {
  style?: StyleProp<ViewStyle>;
  /**
   * Blur intensity 1–100. Default 65 (suitable for cards and sheets).
   * Use 80+ for tab bars and persistent floating surfaces.
   */
  intensity?: number;
  /**
   * Override the blur tint. Defaults to systemMaterialLight/Dark based on
   * the current theme. Use systemThinMaterial variants for lighter surfaces.
   */
  tint?: BlurTint;
  children?: ReactNode;
};

/**
 * Drop-in replacement for View that applies a Liquid Glass blur effect on
 * iOS when conditions allow, and falls back to a plain View otherwise.
 *
 * Glass is disabled when any of the following is true:
 *   • Platform is not iOS
 *   • User has enabled "Reduce Transparency" in Accessibility settings
 *   • A High Contrast theme is active (contrast must not be diluted)
 *
 * Usage: pass exactly the same style you would pass to View. Any
 * `backgroundColor` in the style is stripped automatically — the blur
 * effect provides the visual fill. `overflow: 'hidden'` is added
 * automatically to clip content to the border radius.
 */
export function GlassView({ style, intensity = 65, tint, children, ...viewProps }: Props) {
  const { isDark, themeId }  = useTheme();
  const reduceTransparency   = useReduceTransparency();

  const isHighContrast = themeId === 'highContrastLight' || themeId === 'highContrastDark';
  const useGlass       = Platform.OS === 'ios' && !reduceTransparency && !isHighContrast;

  if (!useGlass) {
    return <View style={style} {...viewProps}>{children}</View>;
  }

  const resolvedTint: BlurTint =
    tint ?? (isDark ? 'systemMaterialDark' : 'systemMaterialLight');

  // Strip backgroundColor so the native blur surface is visible.
  const flat = StyleSheet.flatten(style) ?? {};
  const { backgroundColor: _stripped, ...rest } = flat as Record<string, unknown>;

  return (
    <BlurView
      intensity={intensity}
      tint={resolvedTint}
      style={[rest as StyleProp<ViewStyle>, { overflow: 'hidden' }]}
      {...viewProps}
    >
      {children}
    </BlurView>
  );
}
