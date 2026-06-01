import { Pressable, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { usePlayer } from '../contexts/PlayerContext';
import { useTheme } from '../contexts/ThemeContext';

const TAB_BAR_HEIGHT = 49;
const MINI_HEIGHT    = 68;

export function MiniPlayer() {
  const player = usePlayer();
  const insets = useSafeAreaInsets();
  const { colors, isDark } = useTheme();

  if (!player.episode) return null;

  const bottomOffset = TAB_BAR_HEIGHT + insets.bottom;
  const progress = player.duration > 0 ? player.position / player.duration : 0;

  // Always use a dark surface so the mini-player floats above light content;
  // in already-dark themes use the card colour to stay consistent.
  const bg = isDark ? colors.card : '#1C1C1E';
  const textCol  = '#FFFFFF';
  const metaCol  = '#8E8E93';
  const barBg    = '#48484A';

  return (
    <Pressable
      style={{ position: 'absolute', bottom: bottomOffset, left: 0, right: 0, height: MINI_HEIGHT,
        backgroundColor: bg, flexDirection: 'row', alignItems: 'center',
        paddingHorizontal: 16, gap: 12, borderTopWidth: 1, borderTopColor: colors.border }}
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
          <View style={{ height: 2, backgroundColor: colors.accent, borderRadius: 1, width: `${Math.round(progress * 100)}%` }} />
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
}
