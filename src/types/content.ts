export type ContentKind = 'forumTopic' | 'podcastEpisode' | 'appListing' | 'resource';

export type PaginatedResult<T> = { items: T[]; hasMore: boolean };

export type SavedItem = {
  id: string;
  kind: ContentKind;
  title: string;
  savedAt: string;
  lastActivityAt?: string;
};

export type ListResumeState = {
  tab: 'Home' | 'Forums' | 'Podcasts' | 'Apps' | 'Resources';
  filter?: string;
  itemId: string;
  itemTitle: string;
  timestamp: string;
};

export type ForumTopic = {
  id: string;
  title: string;
  meta: string;
  authorName: string;
  createdAt: string;
  lastActivityAt: string;
  replyCount: number;
  isUnread: boolean;
  isFollowing: boolean;
  isSaved: boolean;
};

export type Chapter = {
  title: string;
  startTime: number;
  endTime?: number;
};

export type PodcastEpisode = {
  id: string;
  title: string;
  showTitle: string;
  audioUrl: string;
  duration: number;
  publishedAt: string;
  description: string;
  artworkUrl?: string;
  transcriptUrl?: string;
  chapters?: Chapter[];
};

export type AppListing = {
  id: string;
  name: string;
  developer: string;
  platform: string;
  category: string;
  reviewCount: number;
  lastUpdatedAt: string;
  appStoreUrl: string;
  iconUrl?: string;
  summary: string;
};

export type Resource = {
  id: string;
  title: string;
  kind: 'guide' | 'tutorial' | 'article' | 'event' | 'developer';
  summary: string;
  updatedAt: string;
  url: string;
};
