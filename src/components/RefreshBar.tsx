import { useEffect } from 'react';
import { Dimensions, StyleSheet } from 'react-native';
import Animated, {
  cancelAnimation,
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { colors } from '../theme/styles';

// Match the horizontal padding of Screen's content view (18px each side).
const CONTENT_W = Dimensions.get('window').width - 36;
const BAR_W     = Math.round(CONTENT_W * 0.45);

type Props = { refreshing: boolean };

export function RefreshBar({ refreshing }: Props) {
  const translateX = useSharedValue(-BAR_W);
  const opacity    = useSharedValue(0);

  useEffect(() => {
    if (refreshing) {
      // Fade track in, then sweep bar left → right on repeat.
      opacity.value = withTiming(1, { duration: 150 });
      translateX.value = withSequence(
        withTiming(-BAR_W, { duration: 0 }),
        withRepeat(
          withTiming(CONTENT_W, {
            duration: 1100,
            easing: Easing.inOut(Easing.ease),
          }),
          -1,
          false,
        ),
      );
    } else {
      // Slide bar off the right edge, then fade track out.
      cancelAnimation(translateX);
      translateX.value = withTiming(CONTENT_W + BAR_W, { duration: 250 });
      opacity.value    = withTiming(0, { duration: 350 });
    }
  }, [refreshing]); // eslint-disable-line react-hooks/exhaustive-deps

  const trackStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));
  const barStyle   = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return (
    <Animated.View
      style={[styles.track, trackStyle]}
      accessible={false}
      importantForAccessibility="no-hide-descendants"
    >
      <Animated.View style={[styles.bar, barStyle]} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  track: {
    height: 3,
    borderRadius: 2,
    backgroundColor: '#D6E8FF',
    overflow: 'hidden',
    marginBottom: 8,
  },
  bar: {
    height: 3,
    width: BAR_W,
    backgroundColor: colors.appleVisBlue,
    borderRadius: 2,
  },
});
