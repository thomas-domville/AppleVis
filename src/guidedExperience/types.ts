import type { Ionicons } from '@expo/vector-icons';

export type GuidedExperienceType =
  | 'welcome'
  | 'quickStart'
  | 'tutorial'
  | 'spotlight'
  | 'accessibilityLesson'
  | 'whatsNew'
  | 'contextualHelp';

export type GuidedExperienceSecondaryActionKind = 'explainMore' | 'exploreScreen' | 'learnMore';

export type GuidedExperienceSecondaryAction = {
  label: string;
  kind: GuidedExperienceSecondaryActionKind;
  /** For kind: 'exploreScreen' — the route to open in Explore Mode. */
  route?: string;
  /** For kind: 'learnMore' — the Help article to open. */
  helpArticleId?: string;
};

export type GuidedExperienceStep = {
  id: string;
  title: string;
  shortText: string;
  /** Extra detail revealed only when the user taps "Explain More" — never auto-read. */
  explainMoreText?: string;
  /** Route this step is "about" — used by the default Explore This Screen action. */
  screenTarget?: string;
  /** Reserved for a future visual-highlight overlay; not required for VoiceOver users. */
  visualHighlightTarget?: string;
  /** Overrides the default "{title}. Step {n} of {total}." VoiceOver announcement. */
  voiceOverAnnouncement?: string;
  primaryActionLabel?: string;
  secondaryActions?: GuidedExperienceSecondaryAction[];
  relatedGuideIds?: string[];
  relatedTutorialIds?: string[];
  relatedFaqIds?: string[];
  icon?: React.ComponentProps<typeof Ionicons>['name'];
};

export type GuidedExperienceCompletionActionKind = 'finish' | 'openHelp' | 'replay' | 'route';

export type GuidedExperienceCompletionAction = {
  label: string;
  kind: GuidedExperienceCompletionActionKind;
  route?: string;
};

export type GuidedExperience = {
  id: string;
  title: string;
  estimatedTime?: string;
  type: GuidedExperienceType;
  steps: GuidedExperienceStep[];
  completionActions?: GuidedExperienceCompletionAction[];
  relatedHelpIds?: string[];
};

/** Persisted per-experience progress — see src/services/guidedExperienceStore.ts. */
export type GuidedExperienceProgress = {
  completed: boolean;
  skipped: boolean;
  dismissed: boolean;
  lastStepIndex: number;
  replayCount: number;
};
