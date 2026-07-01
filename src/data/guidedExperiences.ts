import type { GuidedExperience } from '../guidedExperience/types';

/**
 * Registry of every guided experience the app can run through the engine.
 * Add future tutorials/spotlights/What's New walkthroughs/Academy lessons here —
 * the engine (app/guided-experience/[experienceId].tsx) is fully data-driven.
 */
export const GUIDED_EXPERIENCES: Record<string, GuidedExperience> = {
  welcome: {
    id: 'welcome',
    title: 'Welcome Tour',
    estimatedTime: '3-5 minutes',
    type: 'welcome',
    completionActions: [
      { label: 'Start Exploring', kind: 'finish' },
      { label: 'Open Help', kind: 'openHelp' },
      { label: 'Replay Tour', kind: 'replay' },
    ],
    steps: [
      {
        id: 'welcome-intro',
        title: 'Welcome to AppleVis',
        icon: 'sparkles-outline',
        shortText: 'AppleVis brings together community discussions, accessible app information, podcasts, guides, and Apple accessibility resources in one place.',
        explainMoreText: 'This quick tour will show you where to begin and where to find help when you need it.',
      },
      {
        id: 'welcome-home',
        title: 'Home',
        icon: 'home-outline',
        shortText: 'Home helps you catch up on the latest AppleVis activity.',
        explainMoreText: 'It brings together new topics, podcast activity, app entries, guides, and other updates so you know where to begin.',
        screenTarget: '/(tabs)',
        secondaryActions: [{ label: 'Explore This Screen', kind: 'exploreScreen', route: '/(tabs)' }],
      },
      {
        id: 'welcome-discover',
        title: 'Discover',
        icon: 'compass-outline',
        shortText: 'Discover is your gateway to the wider AppleVis community.',
        explainMoreText: 'Browse the App Directory, community areas, learning resources, the Bug Tracker, Be My Eyes tools, contribution options, and ways to connect.',
        screenTarget: '/(tabs)/discover',
        secondaryActions: [{ label: 'Explore This Screen', kind: 'exploreScreen', route: '/(tabs)/discover' }],
      },
      {
        id: 'welcome-foryou',
        title: 'For You',
        icon: 'star-outline',
        shortText: 'For You is your personal AppleVis hub.',
        explainMoreText: 'Return to your queue, downloads, saved items, and followed content whenever you want to continue where you left off.',
        screenTarget: '/(tabs)/foryou',
        secondaryActions: [{ label: 'Explore This Screen', kind: 'exploreScreen', route: '/(tabs)/foryou' }],
      },
      {
        id: 'welcome-search',
        title: 'Search',
        icon: 'search-outline',
        shortText: 'Search helps you find discussions, apps, guides, podcast episodes, and help across AppleVis.',
        explainMoreText: 'Results are grouped so you can quickly choose the kind of content you want.',
        screenTarget: '/search',
        secondaryActions: [{ label: 'Explore This Screen', kind: 'exploreScreen', route: '/search' }],
      },
      {
        id: 'welcome-profile',
        title: 'Profile',
        icon: 'person-circle-outline',
        shortText: 'Profile is where you sign in, view account tools, check support information, see saved item summaries, and access app information.',
        screenTarget: '/profile',
        secondaryActions: [{ label: 'Explore This Screen', kind: 'exploreScreen', route: '/profile' }],
      },
      {
        id: 'welcome-settings-help',
        title: 'Settings and Help',
        icon: 'options-outline',
        shortText: 'Settings lets you customize appearance, accessibility, notifications, podcasts, privacy, storage, and more.',
        explainMoreText: 'Help is always available when you want a guide, troubleshooting step, or refresher.',
        secondaryActions: [
          { label: 'Explore This Screen', kind: 'exploreScreen', route: '/settings' },
          { label: 'Learn More', kind: 'learnMore', helpArticleId: 'start-tabs' },
        ],
      },
      {
        id: 'welcome-ready',
        title: "You're Ready",
        icon: 'checkmark-circle-outline',
        shortText: "You're ready to explore AppleVis. You can replay this tour anytime from Help.",
        explainMoreText: 'Start with Home, browse Discover, or open For You to continue your personal AppleVis journey.',
      },
    ],
  },
};

export function findGuidedExperience(id: string): GuidedExperience | undefined {
  return GUIDED_EXPERIENCES[id];
}
