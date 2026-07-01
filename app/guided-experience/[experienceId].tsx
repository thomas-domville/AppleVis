import { useEffect, useRef } from 'react';
import { AccessibilityInfo, Animated, findNodeHandle, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router, useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../src/contexts/ThemeContext';
import { useAccessibilityPreferences } from '../../src/hooks/useAccessibilityPreferences';
import { useGuidedExperiencePause } from '../../src/contexts/GuidedExperienceContext';
import { useGuidedExperienceRuntime } from '../../src/guidedExperience/useGuidedExperienceRuntime';
import { findGuidedExperience } from '../../src/data/guidedExperiences';
import { GuidedExperienceProgress } from '../../src/components/guidedExperience/GuidedExperienceProgress';
import { GuidedExperienceStepCard } from '../../src/components/guidedExperience/GuidedExperienceStepCard';
import { GuidedExperienceActions } from '../../src/components/guidedExperience/GuidedExperienceActions';
import { GuidedExperienceCompletion } from '../../src/components/guidedExperience/GuidedExperienceCompletion';

/**
 * Generic renderer for any entry in src/data/guidedExperiences.ts — the Welcome
 * Tour today, and future tutorials/spotlights/What's New walkthroughs/Academy
 * lessons without a new screen per experience.
 */
export default function GuidedExperienceScreen() {
  const { experienceId } = useLocalSearchParams<{ experienceId: string }>();
  const experience = findGuidedExperience(experienceId ?? '');
  const { colors } = useTheme();
  const { reduceMotion } = useAccessibilityPreferences();
  const { pauseForExplore, clearPaused } = useGuidedExperiencePause();
  const headingRef = useRef<Text>(null);
  const entranceOpacity = useRef(new Animated.Value(0)).current;
  const entranceTranslateY = useRef(new Animated.Value(10)).current;

  const runtime = useGuidedExperienceRuntime(experience);
  const { loaded, step, stepIndex, totalSteps, isFirstStep, isLastStep, next, previous, complete, skip, pauseAt, restart } = runtime;

  useEffect(() => {
    if (!loaded) return;
    const timer = setTimeout(() => {
      const node = headingRef.current ? findNodeHandle(headingRef.current) : null;
      if (node) AccessibilityInfo.setAccessibilityFocus(node);
    }, 350);
    return () => clearTimeout(timer);
  }, [loaded, stepIndex]);

  useEffect(() => {
    if (reduceMotion) {
      entranceOpacity.setValue(1);
      entranceTranslateY.setValue(0);
      return;
    }
    entranceOpacity.setValue(0);
    entranceTranslateY.setValue(10);
    Animated.parallel([
      Animated.timing(entranceOpacity, { toValue: 1, duration: 300, useNativeDriver: true }),
      Animated.timing(entranceTranslateY, { toValue: 0, duration: 300, useNativeDriver: true }),
    ]).start();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stepIndex, reduceMotion]);

  if (!experience || !loaded || !step) return null;

  function handleExploreScreen(route: string) {
    pauseAt(stepIndex).catch(() => {});
    pauseForExplore(experience!.id, experience!.title, stepIndex);
    router.push(route as any);
  }

  function handleLearnMore(helpArticleId: string) {
    router.push({ pathname: '/help-article', params: { articleId: helpArticleId } });
  }

  async function handleSkip() {
    await skip();
    clearPaused();
    AccessibilityInfo.announceForAccessibility(`${experience!.title} skipped.`);
    router.replace('/(tabs)');
  }

  async function handleFinish() {
    await complete();
    clearPaused();
    router.replace('/(tabs)');
  }

  async function handleOpenHelp() {
    await complete();
    clearPaused();
    router.replace('/help' as any);
  }

  async function handleReplay() {
    await restart();
    AccessibilityInfo.announceForAccessibility(`${experience!.title} restarted.`);
  }

  function handleRoute(route: string) {
    complete().catch(() => {});
    clearPaused();
    router.replace(route as any);
  }

  return (
    <SafeAreaView
      style={{ flex: 1, backgroundColor: colors.background }}
      onAccessibilityEscape={() => { if (router.canGoBack()) router.back(); }}
    >
      {!isFirstStep && (
        <View style={{ paddingHorizontal: 16, paddingTop: 12, paddingBottom: 4 }}>
          <Pressable
            onPress={previous}
            accessible
            accessibilityRole="button"
            accessibilityLabel="Back"
            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
            style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', opacity: pressed ? 0.6 : 1 })}
          >
            <Ionicons name="chevron-back" size={22} color={colors.accent} accessibilityElementsHidden />
            <Text style={{ color: colors.accent, fontSize: 17 }} accessibilityElementsHidden>Back</Text>
          </Pressable>
        </View>
      )}

      <ScrollView
        contentContainerStyle={{ flexGrow: 1, paddingHorizontal: 24, paddingTop: 16, paddingBottom: 48 }}
        showsVerticalScrollIndicator={false}
      >
        <GuidedExperienceProgress stepIndex={stepIndex} totalSteps={totalSteps} />

        <Animated.View style={{ flex: 1, opacity: entranceOpacity, transform: [{ translateY: entranceTranslateY }] }}>
          <GuidedExperienceStepCard step={step} stepIndex={stepIndex} totalSteps={totalSteps} headingRef={headingRef} />

          {isLastStep ? (
            <GuidedExperienceCompletion
              actions={experience.completionActions ?? [{ label: 'Done', kind: 'finish' }]}
              onFinish={handleFinish}
              onOpenHelp={handleOpenHelp}
              onReplay={handleReplay}
              onRoute={handleRoute}
            />
          ) : (
            <GuidedExperienceActions
              primaryLabel={step.primaryActionLabel ?? 'Continue'}
              onPrimary={next}
              showBack={false}
              onBack={previous}
              secondaryActions={step.secondaryActions}
              onExploreScreen={handleExploreScreen}
              onLearnMore={handleLearnMore}
              showSkip
              onSkip={handleSkip}
            />
          )}
        </Animated.View>
      </ScrollView>
    </SafeAreaView>
  );
}
