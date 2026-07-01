import { useCallback, useEffect, useState } from 'react';
import { guidedExperienceStore } from '../services/guidedExperienceStore';
import type { GuidedExperience } from './types';

/**
 * Step-by-step engine state for a single guided experience, backed by
 * guidedExperienceStore so progress survives an app restart (Resume).
 *
 * Accepts `experience: undefined` so callers can call this hook unconditionally
 * (Rules of Hooks) even before an experienceId route param has resolved to a
 * known experience — `loaded` stays false and all actions become no-ops.
 */
export function useGuidedExperienceRuntime(experience: GuidedExperience | undefined) {
  const [stepIndex, setStepIndex] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const [resumedFromDismissed, setResumedFromDismissed] = useState(false);

  useEffect(() => {
    if (!experience) return;
    let mounted = true;
    guidedExperienceStore.getProgress(experience.id).then((progress) => {
      if (!mounted) return;
      const startIndex = progress.dismissed
        ? Math.min(progress.lastStepIndex, experience.steps.length - 1)
        : 0;
      setStepIndex(Math.max(0, startIndex));
      setResumedFromDismissed(progress.dismissed && startIndex > 0);
      setLoaded(true);
    });
    return () => { mounted = false; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [experience?.id]);

  const totalSteps = experience?.steps.length ?? 0;
  const isFirstStep = stepIndex === 0;
  const isLastStep = stepIndex === totalSteps - 1;
  const step = experience?.steps[stepIndex];

  const goToStep = useCallback((index: number) => {
    if (!experience) return;
    const clamped = Math.max(0, Math.min(experience.steps.length - 1, index));
    setStepIndex(clamped);
    guidedExperienceStore.markStep(experience.id, clamped).catch(() => {});
  }, [experience]);

  const next = useCallback(() => {
    if (isLastStep) return;
    goToStep(stepIndex + 1);
  }, [isLastStep, stepIndex, goToStep]);

  const previous = useCallback(() => {
    if (isFirstStep) return;
    goToStep(stepIndex - 1);
  }, [isFirstStep, stepIndex, goToStep]);

  const complete = useCallback(async () => {
    if (!experience) return;
    await guidedExperienceStore.markCompleted(experience.id);
  }, [experience]);

  const skip = useCallback(async () => {
    if (!experience) return;
    await guidedExperienceStore.markSkipped(experience.id);
  }, [experience]);

  /** Called right before navigating away for "Explore This Screen." */
  const pauseAt = useCallback(async (index: number) => {
    if (!experience) return;
    await guidedExperienceStore.markDismissedForNow(experience.id, index);
  }, [experience]);

  const restart = useCallback(async () => {
    if (!experience) return;
    await guidedExperienceStore.restart(experience.id);
    setStepIndex(0);
    setResumedFromDismissed(false);
  }, [experience]);

  return {
    loaded: loaded && !!experience && !!step,
    stepIndex,
    step,
    isFirstStep,
    isLastStep,
    totalSteps,
    resumedFromDismissed,
    goToStep,
    next,
    previous,
    complete,
    skip,
    pauseAt,
    restart,
  };
}
