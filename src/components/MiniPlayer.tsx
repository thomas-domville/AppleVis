import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { BlurView } from 'expo-blur';
import { usePlayer } from '../contexts/PlayerContext';
import { useTheme } from '../contexts/ThemeContext';
import { useReduceTransparency } from '../hooks/useReduceTransparency';

const TAB_BAR_HEIGHT = 49;
const MINI_HEIGHT    = 64;

const textCol = '#FFFFFF';
const metaCol = '#AEAEB2';
const barBg   = '#48484A';

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
  const pct            = `${Math.round(progress * 100)}%` as const;

  const containerStyle: object = {
    position: 'absolute',
    left: 0, right: 0,
    bottom: bottomOffset,
    height: MINI_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    overflow: 'hidden',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: useGlass ? 'rgba(255,255,255,0.15)' : colors.border,
    backgroundColor: useGlass ? 'transparent' : (isDark ? colors.card : '#1C1C1E'),
  };

  const inner = (
    <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center' }}
      accessible={false} importantForAccessibility="no-hide-descendants">

      {/* ── Body: tap to open full player ──────────────────────────── */}
      <Pressable
        onPress={() => router.push('/player')}
        accessible
        accessibilityRole="button"
        accessibilityLabel={[
          `Now playing: ${player.episode.title}`,
          `from ${player.episode.showTitle}`,
          `${Math.round(progress * 100)} percent complete`,
          player.isPlaying ? 'Playing' : 'Paused',
        ].join('. ')}
        accessibilityHint="Double tap to open full player controls."
        style={{ flex: 1, paddingLeft: 16, paddingRight: 8, paddingVertical: 10, justifyContent: 'center' }}
      >
        <Text numberOfLines={1} style={{ color: textCol, fontSize: 14, fontWeight: '600' }}>
          {player.episode.title}
        </Text>
        <Text numberOfLines={1} style={{ color: metaCol, fontSize: 12, marginTop: 1 }}>
          {player.episode.showTitle}
        </Text>
        <View style={{ height: 2, backgroundColor: barBg, borderRadius: 1, marginTop: 5 }}
          accessible={false}>
          <View style={{ height: 2, backgroundColor: colors.accent, borderRadius: 1, width: pct }} />
        </View>
      </Pressable>

      {/* ── Play / Pause ────────────────────────────────────────────── */}
      <Pressable
        onPress={player.isPlaying ? player.pause : player.play}
        accessible
        accessibilityRole="button"
        accessibilityLabel={player.isPlaying ? 'Pause' : 'Play'}
        hitSlop={8}
        style={{ padding: 12 }}
      >
        <Ionicons
          name={player.isPlaying ? 'pause' : 'play'}
          size={26}
          color={textCol}
          accessibilityElementsHidden
        />
      </Pressable>

      {/* ── Stop / dismiss player ────────────────────────────────────── */}
      <Pressable
        onPress={() => player.stop()}
        accessible
        accessibilityRole="button"
        accessibilityLabel="Stop and dismiss player"
        accessibilityHint="Stops playback and hides the player."
        hitSlop={8}
        style={{ padding: 12, paddingRight: 16 }}
      >
        <Ionicons name="close" size={22} color={metaCol} accessibilityElementsHidden />
      </Pressable>
    </View>
  );

  if (useGlass) {
    return (
      <BlurView intensity={85} tint="systemMaterialDark" style={containerStyle}>
        {inner}
      </BlurView>
    );
  }

  return <View style={containerStyle}>{inner}</View>;
}
