export type ContentKind = 'forumTopic' | 'podcastEpisode' | 'appListing' | 'resource' | 'blogPost';

export type PaginatedResult<T> = { items: T[]; hasMore: boolean };

export type SavedItem = {
  id: string;
  kind: ContentKind;
  title: string;
  savedAt: string;
  lastActivityAt?: string;
};


// ─── Home feed ────────────────────────────────────────────────────────────────

export type FeedPrefs = {
  topics: boolean;
  podcasts: boolean;
  apps: boolean;
  guides: boolean;
  blogs: boolean;    // gate: pending Drupal blog content type name
  appleOnly: boolean; // gate: pending taxonomy field name for Apple-related filter
};

export type FeedItem =
  | { kind: 'topic';   data: ForumTopic;      activityAt: string }
  | { kind: 'podcast'; data: PodcastEpisode;  activityAt: string }
  | { kind: 'app';     data: AppListing;      activityAt: string }
  | { kind: 'guide';   data: Resource;        activityAt: string }
  | { kind: 'blog';    data: BlogPost;        activityAt: string };

// ─── Blog posts (Phase 4 gate) ────────────────────────────────────────────────
// Enabled once Drupal dev confirms the blog content type name.

export type BlogPost = {
  id: string;
  title: string;
  authorName: string;
  publishedAt: string;
  lastActivityAt?: string;
  summary: string;
  commentCount: number;
  url: string;
};

// ─── Full-text search results ─────────────────────────────────────────────────

export type SearchResult = {
  id: string;
  contentType: 'topic' | 'podcast' | 'app' | 'guide' | 'blog';
  title: string;
  summary?: string;
  url: string;
  updatedAt: string;
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
  lastActivityAt?: string;
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

export type ForumReply = {
  id: string;
  authorName: string;
  authorId: string;
  body: string;
  createdAt: string;
  isNew?: boolean;
};

export type ForumTopicDetail = ForumTopic & {
  body: string;
  replies: ForumReply[];
  url: string;
};

export type AppReview = {
  id: string;
  authorName: string;
  rating?: number;
  body: string;
  createdAt: string;
  appVersion?: string;
  platform?: string;
};

export type AppDetail = AppListing & {
  body: string;
  reviews: AppReview[];
  accessibilityRating?: number;
};

export type ResourceDetail = Resource & {
  body: string;
  authorName?: string;
};

export type UserProfile = {
  uid: string;
  name: string;
  email: string;
  memberSince: string;
  postCount: number;
  profileUrl: string;
};
