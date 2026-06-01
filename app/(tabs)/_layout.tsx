import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Platform } from 'react-native';
import { PlayerProvider } from '../../src/contexts/PlayerContext';
import { MiniPlayer } from '../../src/components/MiniPlayer';
import { useTheme } from '../../src/contexts/ThemeContext';

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

function ThemedTabs() {
  const { colors, isDark } = useTheme();

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
        tabBarAccessibilityLabel: `${tabLabels[route.name] ?? route.name} tab`,
        tabBarStyle: {
          ...(Platform.OS === 'ios' ? { position: 'absolute' as const } : {}),
          backgroundColor: colors.card,
          borderTopColor: colors.border,
        },
        tabBarActiveTintColor: colors.accent,
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
    <PlayerProvider>
      <ThemedTabs />
      <MiniPlayer />
    </PlayerProvider>
  );
}
