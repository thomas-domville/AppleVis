import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useEffect, useRef } from 'react';
import { AccessibilityInfo, Platform, Pressable, StyleSheet, View } from 'react-native';
import { useNavigationState } from '@react-navigation/native';
import { BlurView } from 'expo-blur';
import { useTheme } from '../../src/contexts/ThemeContext';
import { usePlayer } from '../../src/contexts/PlayerContext';
import { useReduceTransparency } from '../../src/hooks/useReduceTransparency';
import { sounds } from '../../src/services/sounds';

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
  const shouldAnnounce = useRef(false);
  const focusedIndex   = useNavigationState((state) => state.index);
  const selected       = TAB_ORDER.indexOf(routeName) === focusedIndex;

  useEffect(() => {
    if (!selected || !shouldAnnounce.current) return;
    shouldAnnounce.current = false;
    const label    = tabLabels[routeName] ?? routeName;
    const position = TAB_ORDER.indexOf(routeName) + 1;
    // Short delay lets the screen transition settle before speaking
    setTimeout(() => {
      AccessibilityInfo.announceForAccessibility(
        `${label}, tab ${position} of ${TAB_ORDER.length}, selected`,
      );
    }, 300);
  }, [selected, routeName]);

  return (
    <Pressable
      onPress={(event) => {
        if (!selected) {
          shouldAnnounce.current = true;
          sounds.tabChange().catch(() => {});
        }
        onPress?.(event);
      }}
      onLongPress={onLongPress}
      style={style}
      accessible
      accessibilityRole="tab"
      accessibilityLabel={getTabAccessibilityLabel(routeName, selected, badge)}
      accessibilityState={{ ...accessibilityState, selected }}
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
  return <ThemedTabs />;
}
