import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { guidedExperienceStore } from '../services/guidedExperienceStore';
import { GUIDED_EXPERIENCES } from '../data/guidedExperiences';

type PausedExperience = {
  experienceId: string;
  experienceTitle: string;
  stepIndex: number;
} | null;

type GuidedExperienceContextValue = {
  paused: PausedExperience;
  /** Called by the guided-experience screen right before navigating away for Explore This Screen. */
  pauseForExplore: (experienceId: string, experienceTitle: string, stepIndex: number) => void;
  /** Called once the user has resumed (or explicitly dismissed) the paused tour. */
  clearPaused: () => void;
};

const GuidedExperienceContext = createContext<GuidedExperienceContextValue | null>(null);

/**
 * Tracks at most one "paused mid-tour" guided experience at a time, so a small
 * Resume Tour affordance can be shown from anywhere in the app while the user
 * explores a screen the tour pointed them at. The actual step-by-step engine
 * state (current step, progress persistence) lives in useGuidedExperienceRuntime,
 * scoped to the guided-experience screen itself — this context only needs to
 * answer "is there something to resume, and what/where."
 */
export function GuidedExperienceProvider({ children }: { children: ReactNode }) {
  const [paused, setPaused] = useState<PausedExperience>(null);

  // On launch, restore the Resume Tour affordance if the app was closed while
  // a guided experience was paused for Explore This Screen — the in-memory
  // `paused` state above doesn't survive a restart, but the persisted
  // dismissed/lastStepIndex progress does.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      for (const experience of Object.values(GUIDED_EXPERIENCES)) {
        const progress = await guidedExperienceStore.getProgress(experience.id);
        if (progress.dismissed && !progress.completed && !progress.skipped) {
          if (!cancelled) {
            setPaused({ experienceId: experience.id, experienceTitle: experience.title, stepIndex: progress.lastStepIndex });
          }
          return;
        }
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const pauseForExplore = useCallback((experienceId: string, experienceTitle: string, stepIndex: number) => {
    setPaused({ experienceId, experienceTitle, stepIndex });
  }, []);

  const clearPaused = useCallback(() => setPaused(null), []);

  const value = useMemo(() => ({ paused, pauseForExplore, clearPaused }), [paused, pauseForExplore, clearPaused]);

  return <GuidedExperienceContext.Provider value={value}>{children}</GuidedExperienceContext.Provider>;
}

export function useGuidedExperiencePause(): GuidedExperienceContextValue {
  const ctx = useContext(GuidedExperienceContext);
  if (!ctx) throw new Error('useGuidedExperiencePause must be used within GuidedExperienceProvider');
  return ctx;
}
