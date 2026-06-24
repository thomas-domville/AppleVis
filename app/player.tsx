import { useCallback, useEffect, useState } from 'react';
import { AccessibilityInfo, Image, Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { usePlayer } from '../src/contexts/PlayerContext';
import { useTheme } from '../src/contexts/ThemeContext';
import { useTip, TIP_KEYS, TIPS } from '../src/contexts/ContextualTipContext';
import { SPEED_OPTIONS } from '../src/hooks/usePodcastPlayer';

function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function PlayerScreen() {
  const router             = useRouter();
  const { colors }         = useTheme();
  const player             = usePlayer();
  const { showTip }        = useTip();
  const [barWidth, setBarWidth] = useState(0);

  // Show magic-tap tip the first time the player is opened.
  useEffect(() => {
    const t = setTimeout(() => showTip(TIP_KEYS.playerMagicTap, TIPS.playerMagicTap), 1500);
    return () => clearTimeout(t);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const onMagicTap = useCallback(() => {
    if (player.isPlaying) player.pause();
    else player.play();
  }, [player]);

  if (!player.episode) {
    router.back();
    return null;
  }

  const progress  = player.duration > 0 ? player.position / player.duration : 0;
  const remaining = Math.max(0, player.duration - player.position);

  const speedIndex = SPEED_OPTIONS.indexOf(player.speed);
  const nextSpeed  = SPEED_OPTIONS[(speedIndex + 1) % SPEED_OPTIONS.length];

  function seekToX(locationX: number) {
    if (barWidth <= 0 || player.duration <= 0) return;
    const ratio = Math.max(0, Math.min(1, locationX / barWidth));
    player.seekTo(ratio * player.duration);
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: colors.background }}
      onAccessibilityTap={onMagicTap}
      onAccessibilityEscape={() => router.back()}
    >

      {/* ── Header ──────────────────────────────────────────────────── */}
      <View style={{ flexDirection: 'row', alignItems: 'center',
        paddingHorizontal: 20, paddingTop: 12, paddingBottom: 8 }}>
        <View style={{ flex: 1 }}>
          <Text style={{ fontSize: 12, fontWeight: '700', color: colors.textSecondary,
            textTransform: 'uppercase', letterSpacing: 0.8, textAlign: 'center' }}>
            Now Playing
          </Text>
        </View>
        <Pressable
          onPress={() => router.back()}
          accessible
          accessibilityRole="button"
          accessibilityLabel="Close player"
          accessibilityHint="Returns to the app. Playback continues in the background."
          hitSlop={12}
          style={{ position: 'absolute', right: 20, padding: 8 }}
        >
          <Ionicons name="chevron-down" size={28} color={colors.textSecondary}
            accessibilityElementsHidden />
        </Pressable>
      </View>

      {/* ── Artwork ─────────────────────────────────────────────────── */}
      <View style={{ alignItems: 'center', marginTop: 16, marginBottom: 28 }}
        accessibilityElementsHidden>
        <View style={{ width: 220, height: 220, borderRadius: 16,
          backgroundColor: colors.card, overflow: 'hidden',
          alignItems: 'center', justifyContent: 'center',
          shadowColor: '#000', shadowOpacity: 0.3, shadowRadius: 20, shadowOffset: { width: 0, height: 8 } }}>
          {player.episode.artworkUrl ? (
            <Image source={{ uri: player.episode.artworkUrl }}
              style={{ width: 220, height: 220 }} resizeMode="cover" />
          ) : (
            <Ionicons name="radio-outline" size={72} color={colors.textSecondary} />
          )}
        </View>
      </View>

      {/* ── Episode info ─────────────────────────────────────────────── */}
      <View style={{ paddingHorizontal: 28, marginBottom: 24 }}>
        {player.currentChapter?.title && (
          <Text style={{ fontSize: 12, color: colors.accent, fontWeight: '600',
            textAlign: 'center', marginBottom: 4 }}>
            {player.currentChapter.title}
          </Text>
        )}
        <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text,
          textAlign: 'center', marginBottom: 4 }} numberOfLines={2}>
          {player.episode.title}
        </Text>
        <Text style={{ fontSize: 14, color: colors.textSecondary, textAlign: 'center' }}
          numberOfLines={1}>
          {player.episode.showTitle}
        </Text>
      </View>

      {/* ── Scrubber ─────────────────────────────────────────────────── */}
      <View style={{ paddingHorizontal: 28, marginBottom: 4 }}>
        {/* Accessible adjustable — VoiceOver swipe up/down to skip */}
        <View
          accessible
          accessibilityRole="adjustable"
          accessibilityLabel={`Playback position. ${formatTime(player.position)} of ${formatTime(player.duration)}.`}
          accessibilityValue={{
            min: 0,
            max: Math.round(player.duration),
            now: Math.round(player.position),
            text: `${formatTime(player.position)} of ${formatTime(player.duration)}`,
          }}
          onAccessibilityAction={(e) => {
            if (e.nativeEvent.actionName === 'increment') player.skipForward();
            if (e.nativeEvent.actionName === 'decrement') player.skipBack();
          }}
          onLayout={(e) => setBarWidth(e.nativeEvent.layout.width)}
        >
          <Pressable
            accessible={false}
            onPress={(e) => seekToX(e.nativeEvent.locationX)}
            style={{ paddingVertical: 14 }}
          >
            <View style={{ height: 4, backgroundColor: colors.border, borderRadius: 2 }}>
              <View style={{ height: 4, backgroundColor: colors.accent, borderRadius: 2,
                width: `${Math.round(progress * 100)}%` }} />
            </View>
          </Pressable>
        </View>

        {/* Time labels */}
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}
          accessibilityElementsHidden>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>
            {formatTime(player.position)}
          </Text>
          <Text style={{ fontSize: 12, color: colors.textSecondary }}>
            -{formatTime(remaining)}
          </Text>
        </View>
      </View>

      {/* ── Transport controls ───────────────────────────────────────── */}
      <View style={{ flexDirection: 'row', alignItems: 'center',
        justifyContent: 'space-evenly', paddingHorizontal: 24,
        marginTop: 20, marginBottom: 24 }}>

        <Pressable
          onPress={player.skipBack}
          accessible
          accessibilityRole="button"
          accessibilityLabel={`Skip back ${player.skipBackSeconds} seconds`}
          hitSlop={12}
          style={{ padding: 12 }}
        >
          <Ionicons name="play-back" size={34} color={colors.text} accessibilityElementsHidden />
        </Pressable>

        <Pressable
          onPress={player.isPlaying ? player.pause : player.play}
          accessible
          accessibilityRole="button"
          accessibilityLabel={player.isPlaying ? 'Pause' : 'Play'}
          style={{ width: 76, height: 76, borderRadius: 38,
            backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center',
            shadowColor: colors.accent, shadowOpacity: 0.4,
            shadowRadius: 12, shadowOffset: { width: 0, height: 4 } }}
        >
          <Ionicons
            name={player.isPlaying ? 'pause' : 'play'}
            size={36}
            color="#FFF"
            accessibilityElementsHidden
          />
        </Pressable>

        <Pressable
          onPress={player.skipForward}
          accessible
          accessibilityRole="button"
          accessibilityLabel={`Skip forward ${player.skipForwardSeconds} seconds`}
          hitSlop={12}
          style={{ padding: 12 }}
        >
          <Ionicons name="play-forward" size={34} color={colors.text} accessibilityElementsHidden />
        </Pressable>
      </View>

      {/* ── Speed + sleep timer ──────────────────────────────────────── */}
      <View style={{ flexDirection: 'row', alignItems: 'center',
        justifyContent: 'center', gap: 16, paddingHorizontal: 28 }}>

        <Pressable
          onPress={() => {
            player.setSpeed(nextSpeed);
            AccessibilityInfo.announceForAccessibility(`Speed ${nextSpeed}×`);
          }}
          onAccessibilityAction={({ nativeEvent }) => {
            const idx = SPEED_OPTIONS.indexOf(player.speed);
            if (nativeEvent.actionName === 'increment' && idx < SPEED_OPTIONS.length - 1) {
              const next = SPEED_OPTIONS[idx + 1];
              player.setSpeed(next);
              AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
            }
            if (nativeEvent.actionName === 'decrement' && idx > 0) {
              const next = SPEED_OPTIONS[idx - 1];
              player.setSpeed(next);
              AccessibilityInfo.announceForAccessibility(`Speed ${next}×`);
            }
          }}
          accessible
          accessibilityRole="adjustable"
          accessibilityLabel="Speed"
          accessibilityValue={{ text: `${player.speed}×` }}
          accessibilityHint="Double tap to cycle forward. Swipe up to increase, swipe down to decrease."
          style={{ backgroundColor: colors.pill, borderRadius: 20,
            paddingHorizontal: 18, paddingVertical: 8 }}
        >
          <Text style={{ fontSize: 14, fontWeight: '700', color: colors.text }}>
            {player.speed}×
          </Text>
        </Pressable>

        {player.sleepTimerRemaining !== null && (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6,
            backgroundColor: colors.pill, borderRadius: 20,
            paddingHorizontal: 14, paddingVertical: 8 }}>
            <Ionicons name="moon-outline" size={14} color={colors.textSecondary}
              accessibilityElementsHidden />
            <Text
              style={{ fontSize: 13, color: colors.textSecondary }}
              accessible
              accessibilityLabel={`Sleep timer: ${formatTime(player.sleepTimerRemaining)} remaining`}
            >
              {formatTime(player.sleepTimerRemaining)}
            </Text>
          </View>
        )}
      </View>

    </SafeAreaView>
  );
}
