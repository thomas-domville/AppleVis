import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { BlurView } from 'expo-blur';
import { usePlayer } from '../contexts/PlayerContext';
import { useTheme } from '../contexts/ThemeContext';
import { useReduceTransparency } from '../hooks/useReduceTransparency';

const TAB_BAR_HEIGHT = 49;
const MINI_HEIGHT    = 68;

const containerStyle = {
  position: 'absolute' as const,
  left: 0, right: 0,
  height: MINI_HEIGHT,
  flexDirection: 'row' as const,
  alignItems: 'center' as const,
  paddingHorizontal: 16,
  gap: 12,
  overflow: 'hidden' as const,
};

export function MiniPlayer() {
  const player             = usePlayer();
  const insets             = useSafeAreaInsets();
  const { colors, isDark, themeId } = useTheme();
  const reduceTransparency = useReduceTransparency();

  if (!player.episode) return null;

  const bottomOffset   = TAB_BAR_HEIGHT + insets.bottom;
  const progress       = player.duration > 0 ? player.position / player.duration : 0;
  const isHighContrast = themeId === 'highContrastLight' || themeId === 'highContrastDark';
  const useGlass       = !reduceTransparency && !isHighContrast;

  const textCol = '#FFFFFF';
  const metaCol = '#AEAEB2';
  const barBg   = '#48484A';

  const content = (
    <Pressable
      style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 12, height: MINI_HEIGHT,
        paddingHorizontal: 16 }}
      onPress={() => router.push('/(tabs)/podcasts')}
      accessible
      accessibilityRole="button"
      accessibilityLabel={`Now playing: ${player.episode.title} from ${player.episode.showTitle}. ${player.isPlaying ? 'Playing' : 'Paused'}. ${Math.round(progress * 100)} percent complete.`}
      accessibilityHint="Double tap to open the full podcast player."
      accessibilityActions={[
        { name: 'play',         label: 'Play' },
        { name: 'pause',        label: 'Pause' },
        { name: 'skip_forward', label: `Skip forward ${player.skipForwardSeconds} seconds` },
      ]}
      onAccessibilityAction={(e) => {
        const name = e.nativeEvent.actionName;
        if (name === 'play') player.play();
        else if (name === 'pause') player.pause();
        else if (name === 'skip_forward') player.skipForward();
      }}
    >
      <View style={{ flex: 1 }}>
        <Text numberOfLines={1} style={{ color: textCol, fontSize: 15, fontWeight: '600' }}>
          {player.episode.title}
        </Text>
        <Text numberOfLines={1} style={{ color: metaCol, fontSize: 13, marginTop: 1 }}>
          {player.episode.showTitle}
        </Text>
        <View style={{ height: 2, backgroundColor: barBg, borderRadius: 1, marginTop: 6 }} accessible={false}>
          <View style={{ height: 2, backgroundColor: colors.accent, borderRadius: 1,
            width: `${Math.round(progress * 100)}%` }} />
        </View>
      </View>

      <Pressable onPress={player.isPlaying ? player.pause : player.play}
        accessible accessibilityRole="button" accessibilityLabel={player.isPlaying ? 'Pause' : 'Play'}
        style={{ padding: 8 }} hitSlop={8}>
        <Ionicons name={player.isPlaying ? 'pause' : 'play'} size={26} color={textCol} />
      </Pressable>

      <Pressable onPress={player.skipForward}
        accessible accessibilityRole="button"
        accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`}
        style={{ padding: 8 }} hitSlop={8}>
        <Ionicons name="play-skip-forward" size={24} color={textCol} />
      </Pressable>
    </Pressable>
  );

  if (useGlass) {
    return (
      <BlurView
        intensity={85}
        tint="systemMaterialDark"
        style={[containerStyle, { bottom: bottomOffset,
          borderTopWidth: StyleSheet.hairlineWidth,
          borderTopColor: 'rgba(255,255,255,0.15)' }]}
      >
        {content}
      </BlurView>
    );
  }

  // Solid fallback: dark surface so the player is always legible above light content.
  const bg = isDark ? colors.card : '#1C1C1E';
  return (
    <View style={[containerStyle, { bottom: bottomOffset, backgroundColor: bg,
      borderTopWidth: 1, borderTopColor: colors.border }]}>
      {content}
    </View>
  );
}
