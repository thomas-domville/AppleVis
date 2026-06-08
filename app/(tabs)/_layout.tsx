import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Platform, Pressable, StyleSheet, View } from 'react-native';
import { BlurView } from 'expo-blur';
import { MiniPlayer } from '../../src/components/MiniPlayer';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useReduceTransparency } from '../../src/hooks/useReduceTransparency';

const iconMap: Record<string, string> = {
  index:    'home-outline',
  discover: 'compass-outline',
  foryou:   'heart-outline',
};

const tabLabels: Record<string, string> = {
  index:    'Home',
  discover: 'Discover',
  foryou:   'For You',
};

const TAB_ORDER = ['index', 'discover', 'foryou'];

function getTabAccessibilityLabel(routeName: string, selected = false, badge?: number) {
  const position = TAB_ORDER.indexOf(routeName) + 1;
  const label    = tabLabels[routeName] ?? routeName;
  const status   = selected ? ', selected' : '';
  const badgeStr = badge ? `, ${badge} notification${badge === 1 ? '' : 's'}` : '';
  return `${label} tab${badgeStr}, ${position} of ${TAB_ORDER.length}${status}`;
}

function AccessibleTabButton({
  routeName,
  badge,
  children,
  style,
  onPress,
  onLongPress,
  accessibilityState,
}: any) {
  const btnRef              = useRef<View>(null);
  const shouldFocusOnSelect = useRef(false);
  const selected            = Boolean(accessibilityState?.selected);

  useEffect(() => {
    if (!selected || !shouldFocusOnSelect.current) return;
    shouldFocusOnSelect.current = false;
    setTimeout(() => {
      const handle = findNodeHandle(btnRef.current);
      if (handle) AccessibilityInfo.setAccessibilityFocus(handle);
    }, 350);
  }, [selected]);

  return (
    <Pressable
      ref={btnRef}
      onPress={(event) => {
        if (!selected) shouldFocusOnSelect.current = true;
        onPress?.(event);
      }}
      onLongPress={onLongPress}
      style={style}
      accessible
      accessibilityRole="tab"
      accessibilityLabel={getTabAccessibilityLabel(routeName, selected, badge)}
      accessibilityState={accessibilityState}
    >
      {children}
    </Pressable>
  );
}

function ThemedTabs() {
  const { colors, isDark, themeId } = useTheme();
  const reduceTransparency          = useReduceTransparency();
  const player                      = usePlayer();
  const queueBadge                  = player.queue.length > 0 ? player.queue.length : undefined;

  const isHighContrast = themeId === 'highContrastLight' || themeId === 'highContrastDark';
  const useGlass       = Platform.OS === 'ios' && !reduceTransparency && !isHighContrast;

  return (
    <Tabs
      screenOptions={({ route }) => ({
        tabBarIcon: ({ color, size }) => (
          <Ionicons
            name={(iconMap[route.name] ?? 'ellipse-outline') as any}
            size={size}
            color={color}
          />
        ),
        tabBarLabelStyle: { fontSize: 12 },
        headerShown: false,
        tabBarButton: ({ children, style, onPress, onLongPress, accessibilityState }) => {
          const badge = route.name === 'foryou' ? queueBadge : undefined;
          return (
            <AccessibleTabButton
              routeName={route.name}
              badge={badge}
              style={style}
              onPress={onPress}
              onLongPress={onLongPress}
              accessibilityState={accessibilityState}
            >
              {children}
            </AccessibleTabButton>
          );
        },
        tabBarStyle: {
          position: 'absolute' as const,
          backgroundColor: useGlass ? 'transparent' : colors.card,
          borderTopColor:  useGlass ? 'transparent' : colors.border,
          elevation: 0,
        },
        tabBarBackground: useGlass
          ? () => (
              <BlurView
                intensity={80}
                tint={isDark ? 'systemMaterialDark' : 'systemMaterialLight'}
                style={StyleSheet.absoluteFill}
              />
            )
          : undefined,
        tabBarActiveTintColor:   colors.accent,
        tabBarInactiveTintColor: colors.textSecondary,
      })}
    >
      {/* ── Visible tabs ─────────────────────────────────── */}
      <Tabs.Screen name="index"    options={{ title: 'Home' }} />
      <Tabs.Screen name="discover" options={{ title: 'Discover' }} />
      <Tabs.Screen name="foryou"   options={{ title: 'For You', tabBarBadge: queueBadge }} />

      {/* ── Legacy tabs — hidden from tab bar, still navigable ── */}
      <Tabs.Screen name="forums"    options={{ href: null }} />
      <Tabs.Screen name="podcasts"  options={{ href: null }} />
      <Tabs.Screen name="apps"      options={{ href: null }} />
      <Tabs.Screen name="resources" options={{ href: null }} />
    </Tabs>
  );
}

export default function TabLayout() {
  return (
    <>
      <ThemedTabs />
      <MiniPlayer />
    </>
  );
}
