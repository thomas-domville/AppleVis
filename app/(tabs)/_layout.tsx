import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle, Platform, Pressable, StyleSheet, View } from 'react-native';
import { BlurView } from 'expo-blur';
import { MiniPlayer } from '../../src/components/MiniPlayer';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useReduceTransparency } from '../../src/hooks/useReduceTransparency';

const iconMap: Record<string, string> = {
  index:     'home-outline',
  forums:    'chatbubbles-outline',
  podcasts:  'radio-outline',
  apps:      'apps-outline',
  resources: 'library-outline',
};

const tabLabels: Record<string, string> = {
  index:     'Home',
  forums:    'Forums',
  podcasts:  'Podcasts',
  apps:      'Apps',
  resources: 'Resources',
};

const TAB_ORDER = ['index', 'forums', 'podcasts', 'apps', 'resources'];

function getTabAccessibilityLabel(routeName: string, selected = false) {
  const position = TAB_ORDER.indexOf(routeName) + 1;
  const label    = tabLabels[routeName] ?? routeName;
  const status   = selected ? ', selected' : '';

  return `${label} tab, ${position} of ${TAB_ORDER.length}${status}`;
}

function AccessibleTabButton({
  routeName,
  children,
  style,
  onPress,
  onLongPress,
  accessibilityState,
}: any) {
  const btnRef            = useRef<View>(null);
  const shouldFocusOnSelect = useRef(false);
  const selected          = Boolean(accessibilityState?.selected);

  // After navigation completes and this tab becomes selected, move VoiceOver
  // focus here so it reads "Forums tab, 2 of 5, selected" naturally.
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
      accessibilityLabel={getTabAccessibilityLabel(routeName, selected)}
      accessibilityState={accessibilityState}
    >
      {children}
    </Pressable>
  );
}

function ThemedTabs() {
  const { colors, isDark, themeId } = useTheme();
  const reduceTransparency          = useReduceTransparency();

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
        tabBarAccessibilityLabel: getTabAccessibilityLabel(route.name),
        tabBarButton: ({ children, style, onPress, onLongPress, accessibilityState }) => (
          <AccessibleTabButton
            routeName={route.name}
            style={style}
            onPress={onPress}
            onLongPress={onLongPress}
            accessibilityState={accessibilityState}
          >
            {children}
          </AccessibleTabButton>
        ),
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
      <Tabs.Screen name="index"     options={{ title: 'Home' }} />
      <Tabs.Screen name="forums"    options={{ title: 'Forums' }} />
      <Tabs.Screen name="podcasts"  options={{ title: 'Podcasts' }} />
      <Tabs.Screen name="apps"      options={{ title: 'Apps' }} />
      <Tabs.Screen name="resources" options={{ title: 'Resources' }} />
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
