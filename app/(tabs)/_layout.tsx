import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Platform, Pressable, StyleSheet } from 'react-native';
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
        tabBarAccessibilityLabel: `${tabLabels[route.name] ?? route.name}, ${TAB_ORDER.indexOf(route.name) + 1} of ${TAB_ORDER.length}`,
        tabBarButton: ({ children, style, onPress, onLongPress, accessibilityLabel, accessibilityState }) => (
          <Pressable
            onPress={onPress}
            onLongPress={onLongPress}
            style={style}
            accessible
            accessibilityRole="tab"
            accessibilityLabel={accessibilityLabel}
            accessibilityState={accessibilityState}
          >
            {children}
          </Pressable>
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
