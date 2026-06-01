import { useEffect } from 'react';
import { Dimensions, StyleSheet } from 'react-native';
import Animated, { cancelAnimation, Easing, useAnimatedStyle, useSharedValue, withRepeat, withSequence, withTiming } from 'react-native-reanimated';
import { useTheme } from '../contexts/ThemeContext';

const CONTENT_W = Dimensions.get('window').width - 36;
const BAR_W     = Math.round(CONTENT_W * 0.45);

type Props = { refreshing: boolean };

export function RefreshBar({ refreshing }: Props) {
  const { colors }  = useTheme();
  const translateX  = useSharedValue(-BAR_W);
  const opacity     = useSharedValue(0);

  useEffect(() => {
    if (refreshing) {
      opacity.value    = withTiming(1, { duration: 150 });
      translateX.value = withSequence(
        withTiming(-BAR_W, { duration: 0 }),
        withRepeat(withTiming(CONTENT_W, { duration: 1100, easing: Easing.inOut(Easing.ease) }), -1, false),
      );
    } else {
      cancelAnimation(translateX);
      translateX.value = withTiming(CONTENT_W + BAR_W, { duration: 250 });
      opacity.value    = withTiming(0, { duration: 350 });
    }
  }, [refreshing]); // eslint-disable-line react-hooks/exhaustive-deps

  const trackStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));
  const barStyle   = useAnimatedStyle(() => ({ transform: [{ translateX: translateX.value }] }));

  return (
    <Animated.View
      style={[staticStyles.track, { backgroundColor: colors.pill }, trackStyle]}
      accessible={false}
      importantForAccessibility="no-hide-descendants"
    >
      <Animated.View style={[staticStyles.bar, { backgroundColor: colors.accent }, barStyle]} />
    </Animated.View>
  );
}

const staticStyles = StyleSheet.create({
  track: { height: 3, borderRadius: 2, overflow: 'hidden', marginBottom: 8 },
  bar:   { height: 3, width: BAR_W, borderRadius: 2 },
});
