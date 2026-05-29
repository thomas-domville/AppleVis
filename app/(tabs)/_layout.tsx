import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Platform } from 'react-native';
import { PlayerProvider } from '../../src/contexts/PlayerContext';
import { MiniPlayer } from '../../src/components/MiniPlayer';

const iconMap: Record<string, string> = {
  index: 'home-outline',
  forums: 'chatbubbles-outline',
  podcasts: 'radio-outline',
  apps: 'apps-outline',
  resources: 'library-outline',
};

export default function TabLayout() {
  return (
    <PlayerProvider>
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
          tabBarAccessibilityLabel: `${route.name === 'index' ? 'Home' : route.name} tab`,
          tabBarStyle: Platform.select({ ios: { position: 'absolute' }, default: {} }),
        })}
      >
        <Tabs.Screen name="index" options={{ title: 'Home' }} />
        <Tabs.Screen name="forums" options={{ title: 'Forums' }} />
        <Tabs.Screen name="podcasts" options={{ title: 'Podcasts' }} />
        <Tabs.Screen name="apps" options={{ title: 'Apps' }} />
        <Tabs.Screen name="resources" options={{ title: 'Resources' }} />
      </Tabs>
      <MiniPlayer />
    </PlayerProvider>
  );
}
