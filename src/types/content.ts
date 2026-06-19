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
  blogs: boolean;    // always mirrors guides; fetched together under the guides toggle
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
  authorId?: string;
  publishedAt: string;
  lastActivityAt?: string;
  summary: string;
  commentCount: number;
  url: string;
};

export type BlogPostDetail = BlogPost & {
  body: string;
};

// ─── Full-text search results ─────────────────────────────────────────────────

export type SearchResult = {
  id: string;
  contentType: 'topic' | 'podcast' | 'app' | 'guide' | 'blog' | 'bug' | 'review' | 'page' | 'unknown';
  title: string;
  summary?: string;
  url: string;
  updatedAt: string;
  source?: 'api' | 'public';
};

export type ForumTopic = {
  id: string;
  title: string;
  meta: string;
  authorName: string;
  authorId?: string;   // JSON:API user UUID — used to fetch author profile
  createdAt: string;
  lastActivityAt: string;
  replyCount: number;
  isUnread: boolean;
  isFollowing: boolean;
  isSaved: boolean;
  category?: string;
  url?: string;
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
  url?: string;
  authorName?: string;
};

export type AppListing = {
  id: string;
  name: string;
  developer: string;
  platform: string;
  category: string;
  reviewCount: number;
  lastUpdatedAt: string;
  createdAt?: string;      // original submission date (Drupal 'created')
  submittedBy?: string;    // submitter display_name from uid relationship
  appStoreUrl: string;
  iconUrl?: string;
  summary: string;
  url?: string;
};

export type AppPlatform = {
  id: string;
  name: string;
};

export type AppCategory = {
  name: string;
  slug: string;
  count?: number;
};

export type AppCategoryProbe = {
  category: string;
  fieldName: string;
  attemptedFields: string[];
  source?: 'api' | 'jsonapi' | 'public';
};

export type Resource = {
  id: string;
  title: string;
  kind: 'guide' | 'tutorial' | 'article' | 'event' | 'developer';
  summary: string;
  createdAt?: string;
  updatedAt: string;
  commentCount: number;
  url: string;
};

export type ForumReply = {
  id: string;
  subject?: string;
  authorName: string;
  authorId: string;
  body: string;
  createdAt: string;
  isNew?: boolean;
  loveCount?: number;
};

export type ForumTopicDetail = ForumTopic & {
  body: string;
  replies: ForumReply[];
  url: string;
  category?: string;   // pending: confirm taxonomy field name with Drupal dev
  viewCount?: number;  // pending: confirm view count field name with Drupal dev
};

export type AppReview = {
  id: string;
  subject?: string;
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
  submitterUid?: string;            // Drupal user UUID — used to open author profile modal
  reviewedVersion?: string;         // field_version — version on AppleVis at time of submission
  testedOnIOS?: string;             // field_ios_version (raw value; may be taxonomy term ID)
  accessibilityComments?: string;   // field_comments — submitter's accessibility evaluation
  voiceOverPerformance?: string;    // field_voiceover
  buttonLabelling?: string;         // field_labelling
  usabilityNotes?: string;          // field_usability
  otherComments?: string;           // field_other_comments
};

export type ResourceDetail = Resource & {
  body: string;
  authorName?: string;
  authorId?: string;
};

export type UserProfile = {
  uid: string;
  name: string;
  email: string;
  memberSince: string;
  postCount: number;
  profileUrl: string;
};
