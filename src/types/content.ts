export type ContentKind = 'forumTopic' | 'podcastEpisode' | 'appListing' | 'resource';
export type SavedItem = { id: string; kind: ContentKind; title: string; savedAt: string; lastActivityAt?: string };
export type ListResumeState = { tab: 'Home' | 'Forums' | 'Podcasts' | 'Apps' | 'Resources'; filter?: string; itemId: string; itemTitle: string; timestamp: string };
