/**
 * AppleVis In-App Help Center
 *
 * Fully offline user guide for sighted, low-vision, braille, VoiceOver,
 * Switch Control, Voice Control, and keyboard users.
 */

export type ContentBlock =
  | { type: 'heading'; text: string }
  | { type: 'body'; text: string }
  | { type: 'bullets'; items: string[] }
  | { type: 'steps'; items: string[] }
  | { type: 'tip'; text: string }
  | { type: 'note'; text: string }
  | { type: 'warning'; text: string }
  | { type: 'faq'; question: string; answer: string };

/** What kind of help content this is — lets Help/Discover surface the right icon and filter by type. */
export type HelpContentType =
  | 'guide'
  | 'quickStart'
  | 'tutorial'
  | 'faq'
  | 'troubleshooting'
  | 'spotlight'
  | 'accessibilityLesson'
  | 'whatsNew'
  | 'releaseNote';

/** Display label and icon for each content type — shared by the Help list and article screens. */
export const HELP_CONTENT_TYPE_META: Record<HelpContentType, { label: string; icon: string }> = {
  guide: { label: 'Guide', icon: 'book-outline' },
  quickStart: { label: 'Quick Start', icon: 'flash-outline' },
  tutorial: { label: 'Tutorial', icon: 'walk-outline' },
  faq: { label: 'FAQ', icon: 'help-circle-outline' },
  troubleshooting: { label: 'Troubleshooting', icon: 'construct-outline' },
  spotlight: { label: 'Feature Spotlight', icon: 'sparkles-outline' },
  accessibilityLesson: { label: 'Accessibility Lesson', icon: 'accessibility-outline' },
  whatsNew: { label: "What's New", icon: 'megaphone-outline' },
  releaseNote: { label: 'Release Note', icon: 'document-text-outline' },
};

export type RelatedLinkType = HelpContentType | 'forum' | 'podcast';

export type RelatedLink = {
  label: string;
  type: RelatedLinkType;
  /** Link to another Help article by id. */
  helpArticleId?: string;
  /** Link to any other in-app route (forum topic, podcast episode, etc). */
  route?: string;
  params?: Record<string, string>;
};

export type HelpArticle = {
  id: string;
  title: string;
  summary: string;
  content: ContentBlock[];
  contentType?: HelpContentType;
  relatedLinks?: RelatedLink[];
};

export type HelpSection = {
  id: string;
  title: string;
  icon: string;
  description: string;
  articles: HelpArticle[];
};

export const HELP_SECTIONS: HelpSection[] = [
  {
    id: 'start',
    title: 'Getting Started',
    icon: 'compass-outline',
    description: 'A quick tour of AppleVis, the tabs, signing in, and where common tools live.',
    articles: [
      {
        id: 'start-what-is-applevis',
        title: 'What AppleVis Is',
        summary: 'AppleVis is a community, app directory, podcast, forum, and learning library for Apple accessibility.',
        content: [
          { type: 'body', text: 'AppleVis is a community for blind, DeafBlind, low-vision, and sighted people who care about accessibility on Apple platforms. The app brings community discussions, app accessibility reviews, podcasts, blogs, guides, and tutorials into a native iOS experience.' },
          { type: 'heading', text: 'What you can do' },
          { type: 'bullets', items: [
            'Read what is new since your last visit from Home.',
            'Browse Discover for forums, blogs, guides, podcasts, app directory content, site search, and the Bug Tracker.',
            'Use For You to find saved items, following, downloads, queue, and personal activity.',
            'Play podcasts with background audio, queue, chapters, speed controls, Live Activities, Dynamic Island, CarPlay, and AirPods gestures.',
            'Post topics, replies, comments, app reviews, and app submissions when signed in.',
            'Use Apple Intelligence features — summaries, rewrite, translate, and accessibility consensus — on supported devices.',
          ] },
          { type: 'note', text: 'Most browsing works without signing in. Posting, following, personalized notifications, and some account tools require an AppleVis account.' },
        ],
        contentType: 'guide',
        relatedLinks: [
          { label: 'Take the Welcome Tour', type: 'tutorial', route: '/guided-experience/welcome' },
        ],
      },
      {
        id: 'start-tabs',
        title: 'Main Tabs and Navigation',
        summary: 'How Home, Discover, For You, Podcasts, and Profile fit together.',
        content: [
          { type: 'heading', text: 'Home' },
          { type: 'body', text: 'Home is your starting point. It welcomes you, restores focus to where you left off, and keeps the What is New area available near the top without forcing VoiceOver to read the whole summary every time.' },
          { type: 'heading', text: 'Discover' },
          { type: 'body', text: 'Discover is the app-wide browsing area. Use it to open Forums, AppleVis Blog, Guides, Podcasts, App Directory, search, and official AppleVis links.' },
          { type: 'heading', text: 'For You' },
          { type: 'body', text: 'For You collects personal content: saved items, followed items, downloads, podcast queue, and other items you chose to keep close.' },
          { type: 'heading', text: 'Podcasts' },
          { type: 'body', text: 'Podcasts gives you the full AppleVis podcast experience, including playback controls, queue, downloads, chapters, speed, sleep timer, Dynamic Island, Lock Screen controls, and CarPlay.' },
          { type: 'heading', text: 'Profile and Settings' },
          { type: 'body', text: 'Profile contains account tools, support information, legal links, credits, and a Contact App Support button that opens the in-app contact wizard. Settings controls appearance, accessibility, notifications, podcasts, privacy, storage, sync, and smart features.' },
        ],
      },
      {
        id: 'start-sign-in',
        title: 'Signing In',
        summary: 'What signing in unlocks and where account tools live.',
        content: [
          { type: 'steps', items: [
            'Open Profile.',
            'Choose Sign In.',
            'Enter the same AppleVis account details you use on applevis.com.',
            'After signing in, Profile shows account tools, saved information, and support options.',
          ] },
          { type: 'heading', text: 'Signing in unlocks' },
          { type: 'bullets', items: [
            'Posting forum topics and replies.',
            'Adding blog, guide, podcast, and app comments where supported.',
            'Following items for quicker access and notifications.',
            'Personalized notification categories.',
            'Syncing saved items, following, queue, reading progress, and settings through iCloud.',
          ] },
          { type: 'note', text: 'Your password is not stored in the app. The app keeps a secure session token in the iOS Keychain.' },
        ],
      },
      {
        id: 'start-faq',
        title: 'Frequently Asked Questions',
        summary: 'Quick answers to the questions members ask most.',
        contentType: 'faq',
        content: [
          { type: 'faq', question: 'How do I search AppleVis?', answer: 'Open the Search tab, or use the embedded search at the top of Discover. Results are grouped into Site Results, Forum Topics, Apps, and Guides and Resources.' },
          { type: 'faq', question: 'Where are my saved items?', answer: 'Open For You and choose the Saved section. Use the kind filter to narrow by content type if you have saved a lot of items.' },
          { type: 'faq', question: 'What is the difference between Save and Follow?', answer: 'Save bookmarks an item so you can find it again. Follow keeps it in For You > Following and, where supported, notifies you when it has new activity. See Save, Follow, and Download: What’s the Difference? for the full comparison.' },
          { type: 'faq', question: 'How do I download podcast episodes?', answer: 'Open the episode and choose Download, or use the download action on an episode card. Downloaded episodes appear in For You > Downloads for offline listening.' },
          { type: 'faq', question: 'How do I change my VoiceOver detail level?', answer: 'Open Settings > Accessibility > VoiceOver Detail Level and choose Simple, Normal, or All.' },
          { type: 'faq', question: 'Why am I not receiving notifications?', answer: 'Check that AppleVis notifications are allowed in iOS Settings, that the specific category is enabled in AppleVis Settings > Notifications, and that you are signed in for personalized categories.' },
          { type: 'faq', question: 'How do I report a bug?', answer: 'Open Discover, scroll to Contribute, and tap Submit a Bug Report. You must be signed in. See Submitting a Bug Report for the full four-step walkthrough.' },
        ],
        relatedLinks: [
          { label: 'Using Search', type: 'guide', helpArticleId: 'search-overview' },
          { label: 'Submitting a Bug Report', type: 'guide', helpArticleId: 'community-submit-bug' },
        ],
      },
      {
        id: 'start-whats-new',
        title: "What's New and Release Notes",
        summary: 'See what changed in the latest AppleVis app update.',
        contentType: 'whatsNew',
        content: [
          { type: 'body', text: 'The What\'s New screen lists recent AppleVis app updates — new features, improvements, and fixes — for each released version.' },
          { type: 'steps', items: [
            'Open Profile.',
            'Scroll to What\'s New and tap it.',
            'Review the release notes for the current and previous versions.',
          ] },
        ],
        relatedLinks: [
          { label: "Open What's New", type: 'whatsNew', route: '/whats-new' },
        ],
      },
    ],
  },
  {
    id: 'tutorials',
    title: 'Tutorials and Walkthroughs',
    icon: 'walk-outline',
    description: 'Step-by-step lessons for common AppleVis tasks.',
    articles: [
      {
        id: 'tutorial-first-visit',
        title: 'First Visit Checklist',
        summary: 'A practical first-run path through the app.',
        contentType: 'quickStart',
        content: [
          { type: 'steps', items: [
            'Open Home and listen to the welcome message.',
            'Review the What is New area if you want to catch up.',
            'Tap Customize Home in the top-left corner to choose which content types appear in your feed.',
            'Open Discover and explore Forums, Blog, Guides, Podcasts, and App Directory.',
            'Open For You to see saved, following, downloads, and queue areas.',
            'Open Settings and review Appearance, Accessibility, Notifications, Podcasts, Saved and Sync, Privacy, Storage, and Apple Intelligence.',
            'Open Profile and use Contact App Support if you need help.',
          ] },
        ],
      },
      {
        id: 'tutorial-find-content',
        title: 'Find Content in Discover',
        summary: 'Search, browse, filter, and use tags or categories.',
        content: [
          { type: 'steps', items: [
            'Open Discover.',
            'Use Search when you know a keyword.',
            'Open Forums, Blog, Guides, Podcasts, or App Directory when you want to browse.',
            'Use the picker or filter controls to choose content type, tag, platform, category, or saved state.',
            'When you reach the end of a list, more content loads automatically.',
          ] },
          { type: 'note', text: 'VoiceOver users can jump by headings in areas that support category or alphabetical navigation. Low-vision and sighted users can scan the same section headings visually.' },
        ],
      },
      {
        id: 'tutorial-save-follow',
        title: 'Save, Follow, and Mark as Read',
        summary: 'Keep items for later and clear new activity when you are finished.',
        content: [
          { type: 'steps', items: [
            'Find a topic, app, blog, guide, podcast episode, or other content card.',
            'Open the action menu or long press the card.',
            'Choose Save to keep it in For You.',
            'Choose Follow when you want to track future activity for that item.',
            'Choose Mark as Read when you want to clear the new state without opening the item.',
            'On Home, use Mark All as Read when you want a clean slate across new activity.',
          ] },
          { type: 'tip', text: 'VoiceOver users can use the Actions rotor on content cards. Sighted and low-vision users can long press supported cards to open the same actions.' },
        ],
      },
      {
        id: 'tutorial-post',
        title: 'Post a Topic, Reply, or Comment',
        summary: 'Write, review, translate, and submit community posts.',
        content: [
          { type: 'steps', items: [
            'Sign in from Profile.',
            'Open the forum topic, blog post, guide, podcast episode, or app page you want to respond to.',
            'Choose Reply, Add Comment, or New Topic.',
            'Write your draft.',
            'Use Friendly Rewrite if you want help making the draft clearer and more personable.',
            'Use Translate to English if your draft is not in English.',
            'Review any guidelines reminder.',
            'Submit your post.',
          ] },
          { type: 'warning', text: 'AppleVis posts should be in English. The app offers translation help when it detects non-English draft text.' },
        ],
      },
      {
        id: 'tutorial-podcast',
        title: 'Play and Queue Podcasts',
        summary: 'Play episodes, use Dynamic Island, build a queue, and use AirPods and CarPlay.',
        content: [
          { type: 'steps', items: [
            'Open Podcasts.',
            'Choose an episode and press Play.',
            'Use the mini player at the bottom of any tab, the full player, Lock Screen, Dynamic Island, Control Center, AirPods, or CarPlay to control playback.',
            'Use Add to Queue or Play Next to build a listening list. When an episode ends, the next item in your queue plays automatically.',
            'To skip to the next queued episode, use the next-track button on the Lock Screen or the next-track AirPods gesture. To restart the current episode, use the previous-track button.',
            'Use Downloads when you want offline listening.',
            'Use Settings > Podcasts to adjust speed, skip intervals, sleep timer, voice boost, trim silence, and auto-play.',
          ] },
          { type: 'note', text: 'When a podcast is playing, Live Activities and Dynamic Island show the episode title, progress, playback state, and chapter name on supported iPhone models.' },
        ],
      },
      {
        id: 'tutorial-bug-tracker',
        title: 'Using the Bug Tracker',
        summary: 'Find active bugs, read full reports, and submit your own.',
        content: [
          { type: 'steps', items: [
            'Open Discover.',
            'Scroll to Bug Tracker and choose iOS / iPadOS Bugs or macOS Bugs.',
            'The Active filter is selected by default — switch to All Bugs if you want to include resolved reports.',
            'Scroll through the list or type a keyword in the Search field to narrow results.',
            'Tap a bug card to read the full report: description, steps to reproduce, workaround, version information, and Apple Feedback ID.',
            'On an active bug, tap Report to Apple to open Feedback Assistant and file your own report — the more reports Apple receives, the more likely a fix.',
            'Tap Save in the toolbar to keep the report in For You for easy reference later.',
            'Tap Share to send the bug report link to someone else.',
            'To submit a new bug, return to Discover, scroll to Contribute, and tap Submit a Bug Report — a four-step wizard opens inside the app.',
          ] },
          { type: 'tip', text: 'Filing your own report in Apple Feedback Assistant for the same bug raises its priority. Always include your device model, iOS or macOS version, and exact steps to reproduce.' },
          { type: 'note', text: 'VoiceOver users: each bug card announces its severity, status, first-seen version, and fix version as a single accessibility label — no need to swipe through individual elements on the card.' },
        ],
      },
      {
        id: 'tutorial-low-vision',
        title: 'Low Vision Setup',
        summary: 'A quick setup path for larger text, contrast, motion, and visual comfort.',
        content: [
          { type: 'steps', items: [
            'Open Settings > Appearance and choose a theme that is comfortable.',
            'Use High Contrast Light or High Contrast Dark if you need maximum contrast.',
            'Choose a comfortable card density.',
            'Open iOS Settings > Display & Text Size to adjust Dynamic Type, Bold Text, Button Shapes, Reduce Transparency, and Increase Contrast.',
            'Open Settings > Accessibility in AppleVis to review which iOS accessibility settings the app detects.',
          ] },
          { type: 'tip', text: 'Liquid Glass and blur effects are automatically reduced when Reduce Transparency or a high contrast theme is active.' },
        ],
      },
      {
        id: 'tutorial-replay-welcome-tour',
        title: 'Replay the Welcome Tour',
        summary: 'Revisit the short guided tour of Home, Discover, For You, Search, Profile, and Settings.',
        contentType: 'tutorial',
        content: [
          { type: 'body', text: 'The Welcome Tour is a short, optional walkthrough of the app shown after setup. You can replay it any time — it never repeats automatically once you have seen it.' },
          { type: 'steps', items: [
            'Open Profile.',
            'Scroll to Replay Welcome Tour and tap it.',
            'The tour restarts from the beginning. Use Skip Tour at any point to exit, or Back to revisit an earlier step.',
          ] },
          { type: 'tip', text: 'Choose Explore This Screen on any tour step to pause the tour and try the real screen — a Resume Tour button appears so you can pick up right where you left off.' },
        ],
        relatedLinks: [
          { label: 'Take the Welcome Tour', type: 'tutorial', route: '/guided-experience/welcome' },
        ],
      },
    ],
  },
  {
    id: 'accessibility',
    title: 'Accessibility',
    icon: 'accessibility-outline',
    description: 'VoiceOver, braille, low vision, Switch Control, Voice Control, keyboard, and visual accessibility.',
    articles: [
      {
        id: 'accessibility-everyone',
        title: 'Accessibility for Everyone',
        summary: 'AppleVis is designed for multiple ways of using iPhone.',
        contentType: 'accessibilityLesson',
        content: [
          { type: 'body', text: 'AppleVis is not only for one access method. It supports direct touch, VoiceOver, braille displays, Switch Control, Voice Control, Dynamic Type, high contrast themes, reduced motion, reduced transparency, and hardware keyboards.' },
          { type: 'heading', text: 'How instructions are written' },
          { type: 'body', text: 'Most help articles first describe the general action. When an access method needs extra detail, the article includes a note such as "VoiceOver users can..." or "Low-vision users may prefer..." so the guide stays useful for everyone.' },
        ],
      },
      {
        id: 'accessibility-voiceover',
        title: 'VoiceOver Basics',
        summary: 'How to navigate, use actions, and control playback with VoiceOver.',
        contentType: 'accessibilityLesson',
        content: [
          { type: 'bullets', items: [
            'Swipe right or left to move through controls and content.',
            'Double tap to activate the focused item.',
            'Use headings to jump between major sections.',
            'Use the Actions rotor on content cards for Save, Follow, Mark as Read, Share, Read Aloud, Translate, and more.',
            'Use two-finger scrub to go back.',
            'Use two-finger double tap to play or pause podcasts from anywhere.',
          ] },
          { type: 'note', text: 'Most list screens move VoiceOver focus to the first useful item after loading, so you do not have to hunt for the beginning of the list.' },
          { type: 'heading', text: 'VoiceOver Detail Level' },
          { type: 'body', text: 'Settings > Accessibility > VoiceOver Detail Level controls how much detail cards announce when you navigate forum topics, apps, and podcast episodes.' },
          { type: 'bullets', items: [
            'Simple (Fastest) — title and content type only.',
            'Normal (Recommended) — title plus author and comment count.',
            'All (Most Detailed) — everything: title, author, comment count, posted date, and last comment time.',
          ] },
          { type: 'tip', text: 'Normal is the recommended default — switch to All if you want every detail read every time, or Simple if you prefer to scan quickly and check details only when you need them.' },
        ],
      },
      {
        id: 'accessibility-braille',
        title: 'Braille Display Tips',
        summary: 'How braille users can move efficiently through Help and content.',
        contentType: 'accessibilityLesson',
        content: [
          { type: 'bullets', items: [
            'Use headings to jump between sections in Help, Settings, Discover, and long articles.',
            'Short article titles and concise summaries are designed to fit better on braille displays.',
            'Step lists are structured so each step is a separate item.',
            'Use card actions from the rotor or your display command for custom actions.',
            'When a label is long, look for the shorter heading or action name first, then read the hint if needed.',
          ] },
        ],
      },
      {
        id: 'accessibility-low-vision',
        title: 'Low Vision and Visual Comfort',
        summary: 'Themes, contrast, Liquid Glass, Dynamic Type, and motion settings.',
        contentType: 'accessibilityLesson',
        content: [
          { type: 'bullets', items: [
            'Use Appearance to choose System, Light, Dark, or high contrast themes.',
            'Use Dynamic Type in iOS Settings to enlarge text throughout the app.',
            'Use Reduce Motion to shorten animations.',
            'Use Reduce Transparency to replace Liquid Glass and blur surfaces with solid backgrounds.',
            'Use the compact or comfortable layout depending on whether you prefer density or breathing room.',
          ] },
        ],
      },
    ],
  },
  {
    id: 'home-discover',
    title: 'Home and Discover',
    icon: 'home-outline',
    description: 'What is new, search, filters, tags, app directory, blogs, guides, podcasts, and forums.',
    articles: [
      {
        id: 'home-whats-new',
        title: 'Home and What Is New',
        summary: 'How AppleVis welcomes you and helps you catch up.',
        content: [
          { type: 'body', text: 'When the app opens, AppleVis welcomes you and restores focus to the last feed item you were using. The What is New area remains near the top so you can review it when you want.' },
          { type: 'bullets', items: [
            'Use the New filter to show new activity.',
            'Open an item to read it.',
            'Use Mark as Read to clear an item without opening it.',
            'Use Mark All as Read when you have many new items and want to reset your Home view.',
          ] },
        ],
      },
      {
        id: 'discover-overview',
        title: 'Discover Overview',
        summary: 'The central place for browsing AppleVis content.',
        content: [
          { type: 'bullets', items: [
            'Forums: community topics and replies.',
            'AppleVis Blog: official posts and announcements.',
            'Guides: tutorials, resources, and how-to articles.',
            'Podcasts: podcast feed with filters, tags, queue, download, and playback actions.',
            'App Directory: platforms, categories, category counts, alphabetical headings, app pages, and accessibility reviews.',
            'Bug Tracker: active and resolved iOS/iPadOS and macOS accessibility bugs reported by the community.',
            'Be My Eyes: launch Call a Volunteer, Be My AI, or the Service Directory directly from within the app.',
            'Search: site-wide search that can translate non-English queries into English.',
          ] },
        ],
      },
      {
        id: 'discover-bug-tracker',
        title: 'Bug Tracker',
        summary: 'Browse active and resolved accessibility bugs for iOS/iPadOS and macOS.',
        content: [
          { type: 'body', text: 'The Bug Tracker brings the AppleVis community bug database into the app. You can browse active and resolved accessibility bugs reported by the community, read full details, link directly to Apple Feedback Assistant to help get issues fixed, and submit new bugs using the in-app wizard.' },
          { type: 'heading', text: 'Opening the Bug Tracker' },
          { type: 'steps', items: [
            'Open Discover.',
            'Scroll to the Bug Tracker section.',
            'Choose iOS / iPadOS Bugs or macOS Bugs.',
          ] },
          { type: 'heading', text: 'Browsing bugs' },
          { type: 'bullets', items: [
            'The Active filter shows only open, unresolved bugs. All Bugs shows both active and fixed.',
            'Each card shows the bug title, severity level (Low, Medium, or High), status (Active or Fixed), the iOS or macOS version the bug first appeared in, and the version it was fixed in when known.',
            'Each card also shows when the bug was first reported and when it was last updated.',
            'Use the search field to filter the current list by title keyword.',
            'Scroll to the end of the list and more bug reports load automatically.',
            'Pull down to refresh the list.',
          ] },
          { type: 'heading', text: 'Reading a bug report' },
          { type: 'steps', items: [
            'Tap a bug card to open its full detail page.',
            'Read the description, steps to reproduce, and any available workaround.',
            'Check the Bug Details section for platform, first seen version, fixed-in version, device, how often the bug occurs, and Apple Feedback ID.',
            'Use the Report to Apple button on active bugs to open Feedback Assistant and file your own report.',
            'Use the Share button to share the bug report link.',
            'Use the Save button to add the bug report to your For You saved items.',
          ] },
          { type: 'tip', text: 'VoiceOver users: the heading "Bug Details" is announced with accessibilityRole="header" so you can jump to it with the headings rotor.' },
          { type: 'heading', text: 'Submitting a new bug' },
          { type: 'steps', items: [
            'Return to Discover and scroll to the Contribute section.',
            'Tap Submit a Bug Report.',
            'You must be signed in — a sign-in prompt appears if you are not.',
            'The four-step wizard opens inside the app. See "Submitting a Bug Report" in the Community and Posting section for full details.',
          ] },
          { type: 'heading', text: 'Severity levels' },
          { type: 'bullets', items: [
            'High: the bug significantly affects core functionality or makes a feature completely inaccessible.',
            'Medium: the bug impairs usability but a workaround exists or the impact is partial.',
            'Low: the bug is minor and causes only cosmetic or infrequent issues.',
          ] },
          { type: 'note', text: 'The Bug Tracker content is served directly from the AppleVis API. The list is always up to date — no app update is needed when new bugs are added to the website.' },
        ],
      },
      {
        id: 'discover-be-my-eyes',
        title: 'Be My Eyes',
        summary: 'Launch Call a Volunteer, Be My AI, or the Service Directory directly from AppleVis.',
        content: [
          { type: 'body', text: 'AppleVis is a Be My Eyes company. The Be My Eyes section in Discover gives you quick access to three free visual assistance services without leaving AppleVis to hunt for them.' },
          { type: 'heading', text: 'Available services' },
          { type: 'bullets', items: [
            'Call a Volunteer: connects you by live video with a sighted volunteer who can see through your phone camera, available 24 hours a day in 185 languages.',
            'Be My AI: an AI-powered assistant that describes images, reads text, and answers visual questions in 36 languages.',
            'Service Directory: a searchable directory of accessible customer service channels at hundreds of companies and government departments worldwide.',
          ] },
          { type: 'heading', text: 'How to use it' },
          { type: 'steps', items: [
            'Open Discover.',
            'Scroll to the Be My Eyes section.',
            'Tap the service you want — Call a Volunteer, Be My AI, or Service Directory.',
            'If Be My Eyes is installed on your device, it opens directly at that feature.',
            'If Be My Eyes is not installed, the App Store listing for Be My Eyes opens so you can download it.',
          ] },
          { type: 'note', text: 'All three services are completely free to use. Be My Eyes is a separate app — tapping any link will leave AppleVis and open the Be My Eyes app or the App Store.' },
          { type: 'tip', text: 'You can also find Be My Eyes in the AppleVis App Directory, where community accessibility reviews and ratings for the app are available.' },
        ],
      },
      {
        id: 'discover-filters',
        title: 'Filters, Tags, Categories, and Headings',
        summary: 'How to narrow lists quickly.',
        content: [
          { type: 'body', text: 'Filters and pickers let you narrow large lists. Podcasts can be filtered by content type and tags. The App Directory can be filtered by platform and category, and categories announce counts such as "Books, 26 apps."' },
          { type: 'note', text: 'VoiceOver users can navigate by headings where available. Sighted and low-vision users can scan the same headings visually.' },
        ],
      },
    ],
  },
  {
    id: 'foryou-search',
    title: 'For You and Search',
    icon: 'star-outline',
    description: 'Your personal hub — queue, downloads, saved items, following — and how to search across AppleVis.',
    articles: [
      {
        id: 'foryou-overview',
        title: 'Using For You',
        summary: 'Your personal AppleVis hub: queue, downloads, saved items, and following.',
        contentType: 'guide',
        content: [
          { type: 'body', text: 'For You is your personal AppleVis hub — not a recommendation feed. It only shows content you chose to keep, continue, or follow.' },
          { type: 'heading', text: 'The four sections' },
          { type: 'bullets', items: [
            'Queue — episodes lined up to play next, in order. Reorder or remove any episode.',
            'Downloads — episodes saved to this device for offline listening.',
            'Saved — topics, apps, guides, blog posts, and episodes you bookmarked. Filter by content type.',
            'Following — items you follow for easy access and, where supported, notifications when they update.',
          ] },
          { type: 'tip', text: 'Use the Section picker at the top of For You to switch between Queue, Downloads, Saved, and Following. VoiceOver announces which section is selected.' },
        ],
        relatedLinks: [
          { label: 'Save, Follow, and Download: What’s the Difference?', type: 'faq', helpArticleId: 'foryou-save-follow-download-faq' },
        ],
      },
      {
        id: 'foryou-save-follow-download-faq',
        title: 'Save, Follow, and Download: What’s the Difference?',
        summary: 'Three different ways to keep content close, and when to use each.',
        contentType: 'faq',
        content: [
          { type: 'faq', question: 'What does Save do?', answer: 'Save bookmarks a topic, app, guide, blog post, or episode so you can find it again quickly in For You > Saved. It does not download anything or notify you of updates.' },
          { type: 'faq', question: 'What does Follow do?', answer: 'Follow keeps an item in For You > Following and, where supported, notifies you when it has new activity — for example, new replies on a forum topic. Use Follow for things you want to keep up with over time.' },
          { type: 'faq', question: 'What does Download do?', answer: 'Download applies to podcast episodes only. It saves the audio file to your device so you can listen without an internet connection. Downloaded episodes appear in For You > Downloads.' },
          { type: 'faq', question: 'Can I do more than one at once?', answer: 'Yes — a podcast episode can be saved, followed, and downloaded all at the same time. Each is independent, so removing one does not affect the others.' },
        ],
      },
      {
        id: 'search-overview',
        title: 'Using Search',
        summary: 'Find discussions, apps, guides, podcast episodes, and help across AppleVis.',
        contentType: 'guide',
        content: [
          { type: 'body', text: 'Search helps you find discussions, apps, guides, podcast episodes, and Help articles from one place — either the dedicated Search tab, or the embedded search at the top of Discover.' },
          { type: 'heading', text: 'Results are grouped' },
          { type: 'bullets', items: [
            'Site Results — general AppleVis site content.',
            'Forum Topics — community discussions.',
            'Apps — App Directory entries.',
            'Guides and Resources — tutorials and how-to articles.',
          ] },
          { type: 'tip', text: 'If your query looks like it is in a language other than English, AppleVis may offer to translate it — AppleVis search works best in English.' },
          { type: 'note', text: 'VoiceOver announces a concise result count and category breakdown, for example: "12 results found in 4 categories." Each section heading gives more detail.' },
        ],
      },
    ],
  },
  {
    id: 'community',
    title: 'Community and Posting',
    icon: 'chatbubbles-outline',
    description: 'Forums, following, comments, notifications, guidelines, and writing help.',
    articles: [
      {
        id: 'community-forums',
        title: 'Forums and Following',
        summary: 'Browse forum topics, follow activity, and manage replies.',
        content: [
          { type: 'bullets', items: [
            'Use Forums in Discover to browse forum topics.',
            'Use filters to narrow by type or status.',
            'Follow a topic to track future replies.',
            'Use For You > Following to find followed items quickly.',
            'Use notifications to control which followed activity alerts you.',
          ] },
        ],
      },
      {
        id: 'community-writing-tools',
        title: 'Writing Help and Translation',
        summary: 'Friendly rewrite, translate to English, and guidelines reminders.',
        content: [
          { type: 'body', text: 'Before submitting a topic, reply, or comment, AppleVis can help rewrite your draft in a friendly style or translate it to English. The guidelines checker also gives friendly reminders when it detects common issues.' },
          { type: 'bullets', items: [
            'Friendly Rewrite preserves your meaning while improving clarity and tone.',
            'Translate to English helps when your draft is not in English.',
            'The guidelines checker is advisory and does not block posting.',
            'If AI helped write your post, disclose that in the post.',
          ] },
        ],
      },
      {
        id: 'community-guidelines',
        title: 'Community Guidelines',
        summary: 'The basics of posting respectfully and usefully.',
        content: [
          { type: 'bullets', items: [
            'Stay on topic.',
            'Be respectful and constructive.',
            'Use clear subject lines.',
            'Do not post personal email addresses, referral links, or advertisements.',
            'Disclose conflicts of interest and AI assistance.',
            'Avoid duplicate posts and one-word replies.',
          ] },
        ],
      },
      {
        id: 'community-edit-post',
        title: 'Editing Your Posts and Replies',
        summary: 'How to change a forum reply, blog comment, app review, or podcast comment after you have submitted it.',
        content: [
          { type: 'body', text: 'You can edit any post or comment you have written, directly inside the app. The edit option only appears on content you authored.' },
          { type: 'heading', text: 'Forum replies and topic comments' },
          { type: 'steps', items: [
            'Open the forum topic or episode comments page.',
            'Find your reply and hold down on it to open the action sheet.',
            'Choose Edit Comment from the menu.',
            'The Edit modal opens with your original text loaded.',
            'Make your changes in the text field.',
            'Tap Save in the top-right corner.',
          ] },
          { type: 'heading', text: 'App reviews, blog comments, and guide comments' },
          { type: 'steps', items: [
            'Open the app, blog post, or guide where you left a review or comment.',
            'Long-press your review or comment to open the action sheet.',
            'Choose Edit Review or Edit Comment.',
            'Edit the text and tap Save.',
          ] },
          { type: 'note', text: 'Edits are applied immediately and reflected in the app without requiring a page reload.' },
          { type: 'tip', text: 'If you use VoiceOver, the Edit action is also available through accessibilityActions — swipe up or down to reach it without using the long-press menu.' },
        ],
      },
      {
        id: 'community-delete-post',
        title: 'Deleting Your Posts and Comments',
        summary: 'How to permanently remove a forum reply, blog comment, app review, or podcast comment you have written.',
        content: [
          { type: 'body', text: 'You can permanently delete any post or comment you have written. Deleted content is removed immediately and cannot be recovered.' },
          { type: 'steps', items: [
            'Find your post or comment in the relevant screen.',
            'Hold down on it to open the action sheet.',
            'Choose Delete Comment or Delete Review.',
            'A confirmation dialog will appear. Tap Delete to confirm.',
          ] },
          { type: 'warning', text: 'Deletion is permanent. The content is removed from AppleVis and cannot be restored. If you just want to change the text, use Edit instead.' },
        ],
      },
      {
        id: 'community-submit-bug',
        title: 'Submitting a Bug Report',
        summary: 'How to report a new accessibility bug using the four-step in-app wizard.',
        content: [
          { type: 'body', text: 'If you find an accessibility bug that is not already in the Bug Tracker, you can submit it to AppleVis using the native four-step wizard. You must be signed in. The report goes to the AppleVis team for review before it is published.' },
          { type: 'heading', text: 'Before you begin' },
          { type: 'bullets', items: [
            'Search the Bug Tracker first to check the bug has not already been reported.',
            'File your own report in Apple Feedback Assistant first — copy the FB number so you can include it in step two.',
            'Sign in from Profile if you have not already done so.',
          ] },
          { type: 'heading', text: 'Step 1 — Platform and OS version' },
          { type: 'steps', items: [
            'Open Discover, scroll to Contribute, and tap Submit a Bug Report.',
            'Choose the platform: iOS, iPadOS, or macOS.',
            'Enter the operating system version where the bug occurs, for example "iOS 18.4" or "macOS 15.2".',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 2 — Bug details' },
          { type: 'steps', items: [
            'Enter a short, specific bug title, for example "VoiceOver skips toolbar buttons in Mail".',
            'Optionally enter your Apple Feedback number (FB followed by digits) if you have already filed this with Apple.',
            'Choose how reliably you can reproduce the bug: Yes always, Yes sometimes, or No.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 3 — Description' },
          { type: 'steps', items: [
            'Write a detailed description of the bug.',
            'Include the exact steps to reproduce it, what you expected to happen, and what actually happened.',
            'Mention your device model, the affected app name and version, and any partial workaround you have found.',
            'Tap Continue when you have at least 30 characters.',
          ] },
          { type: 'tip', text: 'The description screen shows tips for a helpful bug report. The more detail you include, the more likely your report is to be published and to help Apple fix the issue.' },
          { type: 'heading', text: 'Step 4 — Recognition and submit' },
          { type: 'steps', items: [
            'Review a summary of your report.',
            'Choose how you would like to be credited if your report is featured: by your real name, by your AppleVis username, or anonymously.',
            'Tap Submit Report.',
            'A thank-you screen confirms your submission. The AppleVis team will evaluate and respond within two to three days.',
          ] },
          { type: 'note', text: 'Bug reports are moderated. Duplicate reports, vague descriptions, or bugs that cannot be reproduced may not be published.' },
        ],
      },
      {
        id: 'community-submit-blog',
        title: 'Submitting a Blog Post',
        summary: 'How to submit a blog post for consideration using the three-step in-app wizard.',
        content: [
          { type: 'body', text: 'If you have something to share with the AppleVis community — a tip, review, personal experience, or accessibility story — you can submit a blog post directly from the app. Submissions go to the AppleVis Editorial Team for review. You must be signed in.' },
          { type: 'heading', text: 'Step 1 — Title and category' },
          { type: 'steps', items: [
            'Open Discover, scroll to Contribute, and tap Submit a Blog Post.',
            'Enter a clear title for your post.',
            'Choose the category that best fits your topic from the chip grid.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 2 — Your blog content' },
          { type: 'steps', items: [
            'Choose how you want to provide your post: Write, Import file, or Paste.',
            'Write: type directly into the text area. A minimum of 50 characters is required.',
            'Import file: tap Browse Files and choose a .txt or .md file from Files, iCloud Drive, or any document provider.',
            'Paste: tap Paste from Clipboard to pull text you copied from another app such as Notes or Pages.',
            'Optionally add a note to editors to provide context or background about your post.',
            'Optionally use Draft with Apple Intelligence to generate a short editor note from your content.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 3 — Review and submit' },
          { type: 'steps', items: [
            'Review the summary card showing your title, category, and a preview of your post.',
            'Tap Submit to AppleVis.',
            'A thank-you screen confirms the submission.',
          ] },
          { type: 'note', text: 'The AppleVis Editorial Team will review your post and determine whether it will be published. They will reach out with their decision. Please allow two to three days for the review process.' },
          { type: 'tip', text: 'You can also share a blog post into AppleVis from other apps. In any app, use the Share menu and choose AppleVis — your text is passed directly into the blog submission wizard.' },
        ],
      },
      {
        id: 'community-submit-podcast',
        title: 'Submitting a Podcast',
        summary: 'How to submit a podcast episode using the three-step in-app wizard.',
        content: [
          { type: 'body', text: 'If you produce a podcast related to accessibility, Apple products, or blindness, you can submit an episode to AppleVis for consideration. Submissions go to the AppleVis Editorial Team for review. You must be signed in.' },
          { type: 'heading', text: 'Step 1 — Podcast description' },
          { type: 'steps', items: [
            'Open Discover, scroll to Contribute, and tap Submit a Podcast.',
            'Write a description of your podcast — what it covers, who it is for, and any relevant context.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 2 — Attach your audio' },
          { type: 'steps', items: [
            'Tap Browse Files to open the document picker.',
            'Choose your audio file from Files, iCloud Drive, or any connected storage provider.',
            'Supported formats are MP3, AAC, M4A, WAV, and AIFF.',
            'The selected file name and size are shown so you can confirm you picked the right file.',
            'Tap Continue once a file is selected.',
          ] },
          { type: 'heading', text: 'Step 3 — Review and submit' },
          { type: 'steps', items: [
            'Review the summary showing your audio file and description.',
            'Tap Submit to AppleVis.',
            'The audio file is uploaded. Keep the app open during upload.',
            'A thank-you screen confirms the submission.',
          ] },
          { type: 'note', text: 'The AppleVis Editorial Team will review your podcast and reach out with their decision. Please allow two to three days.' },
          { type: 'tip', text: 'You can also share a podcast URL from apps like Podcasts, Overcast, or Spotify into AppleVis using the system Share menu. Choose AppleVis in the share sheet and the podcast submission wizard opens with the URL already included.' },
        ],
      },
      {
        id: 'community-submit-app',
        title: 'Submitting an App Entry',
        summary: 'How to add an accessible app to the AppleVis App Directory using the five-step wizard.',
        content: [
          { type: 'body', text: 'Registered AppleVis members can submit new app entries to the App Directory. App entries are published immediately when submitted by a signed-in member, matching the behaviour on the AppleVis website. The wizard walks you through five steps.' },
          { type: 'heading', text: 'Before you begin' },
          { type: 'bullets', items: [
            'Check the App Directory first to make sure the app is not already listed.',
            'Sign in from Profile if you have not done so.',
            'Have your accessibility assessment ready — VoiceOver performance, button labelling, and your usability rating.',
          ] },
          { type: 'heading', text: 'Step 1 — Accessibility declaration' },
          { type: 'steps', items: [
            'Open Discover, scroll to Contribute, and tap Submit an App.',
            'Read the accessibility guidelines reminder.',
            'Check the declaration checkbox to confirm you have used the app and are reporting your genuine experience.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 2 — Platform' },
          { type: 'steps', items: [
            'Choose the platform: iPhone and iPad (iOS), Mac (macOS), or Apple TV (tvOS).',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 3 — Find the app' },
          { type: 'steps', items: [
            'Search by app name or paste an App Store URL.',
            'The wizard searches iTunes and the AppleVis directory to find the app and check whether it already exists.',
            'Select the correct result from the list.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 4 — Confirm app details' },
          { type: 'steps', items: [
            'Review the app name, developer, category, price, and description pulled from the App Store.',
            'Confirm the details are correct.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 5 — Accessibility notes and submit' },
          { type: 'steps', items: [
            'Enter the iOS, macOS, or tvOS version you tested the app on.',
            'Choose your VoiceOver Performance rating from the picker.',
            'Choose your Button Labelling rating.',
            'Choose your Usability rating.',
            'Write your Accessibility Comments — a detailed description of the accessibility experience. Minimum 20 characters, but more detail is always better.',
            'Optionally add Other Comments and a Short Summary.',
            'Tap Submit App Entry.',
            'A thank-you screen confirms the submission. The entry is published immediately to the App Directory.',
          ] },
          { type: 'tip', text: 'You can use Draft with Apple Intelligence to generate a short summary from your accessibility comments if Apple Intelligence is enabled on your device.' },
          { type: 'note', text: 'App entries submitted by signed-in members are published directly to the App Directory. This matches the behaviour on the AppleVis website.' },
        ],
      },
      {
        id: 'community-edit-profile',
        title: 'Editing Your Profile',
        summary: 'Update your display name, bio, location, social links, and other profile details.',
        content: [
          { type: 'steps', items: [
            'Open the Profile tab.',
            'Tap Edit Profile near the top of the Account section.',
            'Update any fields you want to change: display name, real name, bio, location, website, and social handles.',
            'Tap Save Profile at the bottom.',
          ] },
          { type: 'bullets', items: [
            'Display Name: what other members see on your posts.',
            'Real Name: optional, shown on your public profile page.',
            'Bio: a short description of yourself for the community.',
            'Location: city, country, or region — entirely optional.',
            'Interests: accessibility tools, Apple products, or anything you want to share.',
            'Website, Twitter/X, Mastodon, Facebook: social and web links shown on your profile.',
          ] },
          { type: 'note', text: 'Changes are saved to your AppleVis account immediately. They will appear on the website and in the app for other members.' },
        ],
      },
    ],
  },
  {
    id: 'content',
    title: 'Apps, Podcasts, Blogs, and Guides',
    icon: 'library-outline',
    description: 'How each AppleVis content area works.',
    articles: [
      {
        id: 'content-apps',
        title: 'App Directory',
        summary: 'Browse apps by platform, category, heading, search, and accessibility information.',
        content: [
          { type: 'body', text: 'The App Directory helps you find apps and understand their accessibility. Browse by platform, then category. Category rows include counts, and app lists support headings for faster navigation.' },
          { type: 'bullets', items: [
            'Open an app page for description, developer, category, ratings, and accessibility notes.',
            'Use Accessibility Consensus for a short summary of what reviewers report.',
            'Save or follow apps to find them in For You.',
            'Share an App Store link into AppleVis to look up or submit an app.',
          ] },
        ],
      },
      {
        id: 'content-podcasts',
        title: 'Podcasts',
        summary: 'Playback, queue, chapters, downloads, Dynamic Island, CarPlay, AirPods, and settings.',
        content: [
          { type: 'bullets', items: [
            'Play, pause, seek, skip forward and back, and change speed from the player or the mini player at the bottom of the screen.',
            'Use Add to Queue or Play Next to control what plays after the current episode.',
            'Download episodes for offline listening.',
            'Navigate chapters using the chapter strip when the episode includes chapter markers.',
            'Lock Screen shows the episode title, artwork, progress bar, and playback controls.',
            'Dynamic Island and Live Activities show the episode title and chapter on supported iPhone models while you use other apps.',
            'CarPlay displays the podcast episode list and allows playback from the car.',
            'AirPods: double tap to play or pause. On episodes with a queue, use the next-track gesture on AirPods or the next button on the Lock Screen to skip to the next queued episode. The previous-track gesture restarts the current episode from the beginning.',
            'Control Center shows a Now Playing card with artwork, title, and controls.',
          ] },
          { type: 'tip', text: 'Use Settings > Podcasts to adjust speed, skip intervals, sleep timer, voice boost, trim silence, auto-play, resume rewind, and volume.' },
        ],
      },
      {
        id: 'content-blog-guides',
        title: 'Blogs and Guides',
        summary: 'Read official updates, guides, tutorials, resources, and comments.',
        content: [
          { type: 'body', text: 'AppleVis Blog contains official posts and announcements. Guides contains tutorials, how-to articles, resources, events, and developer content. Both support reading, saving, sharing, comments, summaries, and discussion tools where available.' },
        ],
      },
      {
        id: 'content-bugs',
        title: 'Bug Tracker',
        summary: 'How the AppleVis bug database works and what each field means.',
        content: [
          { type: 'body', text: 'The Bug Tracker is a community-maintained database of accessibility bugs on Apple platforms. Each report is reviewed and classified by the AppleVis team before being published.' },
          { type: 'heading', text: 'What each field means' },
          { type: 'bullets', items: [
            'Title: a brief, descriptive name for the bug.',
            'Platform: iOS/iPadOS or macOS.',
            'Status — Active: the bug is present in the current release and not yet fixed.',
            'Status — Fixed: Apple has released an update that resolves the bug.',
            'Severity — High: the bug makes a key accessibility feature completely unavailable.',
            'Severity — Medium: the bug impairs usability but a workaround exists.',
            'Severity — Low: the bug is minor and only causes cosmetic or infrequent issues.',
            'First Seen In: the iOS, iPadOS, or macOS version where the bug was first noticed.',
            'Fixed In: the version where Apple shipped a fix, if known.',
            'Steps to Reproduce: a numbered sequence to reliably trigger the bug.',
            'Workaround: any known way to reduce the impact of the bug until Apple fixes it.',
            'Apple Feedback ID: the reference number filed with Apple Feedback Assistant. Tapping it opens Feedback Assistant so you can file your own report for the same issue.',
            'Device: the hardware used when the bug was first reported.',
            'How Often: Rarely, Sometimes, or Always — how reliably the bug occurs.',
          ] },
          { type: 'heading', text: 'Why filing your own Apple report helps' },
          { type: 'body', text: 'Apple uses the volume of Feedback Assistant reports as one signal of how widespread a bug is. When many users file reports for the same issue, it raises the priority. Use the Report to Apple button on any active bug to open Feedback Assistant and add your voice.' },
          { type: 'tip', text: 'Include your exact device model, iOS or macOS version, and the steps to reproduce from the bug report when filing with Apple. Copying the Apple Feedback ID and referencing existing reports also helps.' },
        ],
      },
    ],
  },
  {
    id: 'settings',
    title: 'Settings and Personalization',
    icon: 'options-outline',
    description: 'Appearance, accessibility, notifications, podcasts, sync, privacy, storage, and support.',
    articles: [
      {
        id: 'settings-appearance',
        title: 'Appearance',
        summary: 'Themes, Liquid Glass, card density, contrast, and visual comfort.',
        content: [
          { type: 'body', text: 'Appearance controls how AppleVis looks. Use theme choices, density, and iOS display settings to make the app comfortable. Liquid Glass gives supported surfaces a modern translucent feel and automatically falls back to solid surfaces when Reduce Transparency or high contrast makes that better.' },
        ],
      },
      {
        id: 'settings-notifications',
        title: 'Notifications',
        summary: 'Choose which AppleVis activity can alert you.',
        content: [
          { type: 'bullets', items: [
            'Forum replies.',
            'Mentions.',
            'New topics.',
            'Followed items.',
            'New podcast episodes.',
            'App updates.',
            'New resources.',
            'Announcements.',
          ] },
          { type: 'note', text: 'Some notification categories require signing in. iOS notification permission is still controlled by iPhone Settings.' },
        ],
      },
      {
        id: 'settings-privacy-sync',
        title: 'Privacy and Sync',
        summary: 'What syncs through iCloud, and how account and local data are handled.',
        contentType: 'guide',
        content: [
          { type: 'bullets', items: [
            'Saved and Sync controls what goes through iCloud: saved items, following, reading position, podcast position, queue, and preferences.',
            'Privacy explains account data, Keychain, iCloud, smart features, and local data — and what never leaves the device.',
            'Clear Local Data signs out and removes AppleVis data stored on this device without deleting your applevis.com account.',
          ] },
          { type: 'note', text: 'Apple Intelligence features process everything on-device — no post, comment, or search text is sent to a server.' },
        ],
      },
      {
        id: 'settings-storage-cache',
        title: 'Storage and Cache',
        summary: 'Manage downloaded audio, cached content, and free up space.',
        contentType: 'guide',
        content: [
          { type: 'body', text: 'Storage and Cache shows how much space AppleVis is using on this device and lets you manage it.' },
          { type: 'bullets', items: [
            'Downloaded podcast episodes for offline listening.',
            'Cached images and content for faster browsing.',
            'Cache retention — how long cached content is kept before automatic cleanup.',
          ] },
          { type: 'steps', items: [
            'Open Settings > Storage and Cache.',
            'Review the breakdown of downloads and cache size.',
            'Use Clear Cache to remove cached content without affecting downloads or saved items.',
            'Remove individual downloads from For You > Downloads if you only want to free up specific episodes.',
          ] },
          { type: 'tip', text: 'Clearing the cache does not delete downloaded episodes, saved items, or your account data — only temporary cached content.' },
        ],
      },
      {
        id: 'settings-support',
        title: 'Profile and App Support',
        summary: 'Get app support using the in-app contact wizard.',
        content: [
          { type: 'body', text: 'Profile includes a Contact App Support button that opens the native in-app contact wizard. You can send a bug report, feedback, suggestion, or recommendation directly to the AppleVis team without leaving the app.' },
          { type: 'tip', text: 'Choosing Bug Report in the wizard adds a system information toggle. Turn it on to automatically append your app version and iOS version to the message — useful when reporting a crash or unexpected behaviour.' },
        ],
      },
    ],
  },
  {
    id: 'smart',
    title: 'Smart Features and iOS Integrations',
    icon: 'sparkles-outline',
    description: 'Apple Intelligence, translation, Siri phrases, widgets, Spotlight, Share Extension, Focus Filters, and Dynamic Island.',
    articles: [
      {
        id: 'smart-reading-writing',
        title: 'Reading, Writing, and Translation Tools',
        summary: 'Read Aloud, summaries, simplification, rewrite, and translation.',
        content: [
          { type: 'bullets', items: [
            'Read Aloud reads content out loud using device speech — available on any device.',
            'Summarise condenses long posts, discussions, show notes, and app descriptions — requires Apple Intelligence.',
            'Simplify rewrites complex text in plain language — requires Apple Intelligence.',
            'Accessibility Consensus summarises community app accessibility feedback into a short paragraph — requires Apple Intelligence.',
            'Friendly Rewrite polishes your draft before submitting — requires Apple Intelligence.',
            'Translate to English helps with drafts and search queries — requires Apple Intelligence.',
          ] },
          { type: 'note', text: 'Apple Intelligence features require iPhone 15 Pro or later, iOS 26 or later, and Apple Intelligence enabled in iOS Settings. See Smart Features > Apple Intelligence Features for full details.' },
        ],
      },
      {
        id: 'smart-siri-widgets',
        title: 'Siri, Widgets, Control Center, and Spotlight',
        summary: 'Use AppleVis from system features outside the app.',
        content: [
          { type: 'heading', text: 'Siri phrases' },
          { type: 'body', text: 'AppleVis registers voice shortcuts you can say to Siri at any time. You can also add them to your own phrases in Settings > Siri.' },
          { type: 'bullets', items: [
            '"Open AppleVis Forums" — opens the Forums tab.',
            '"Show unread AppleVis topics" — opens Forums filtered to Unread.',
            '"Resume my AppleVis podcast" — resumes the last episode you were listening to.',
            '"Play the latest AppleVis podcast" — opens Podcasts and starts the newest episode.',
            '"Search AppleVis for [your query]" — opens search with your words pre-filled.',
            '"Open my AppleVis saved items" — opens the Saved section in For You.',
          ] },
          { type: 'heading', text: 'Widgets' },
          { type: 'body', text: 'AppleVis widgets can be added to your Home Screen, Today View, Lock Screen, or StandBy display.' },
          { type: 'bullets', items: [
            'Continue Listening — shows the title, show, and progress of the current podcast episode with a play or pause button. Available in small, medium, accessory rectangular, accessory circular, and accessory inline sizes.',
            'Unread Forums — shows your unread topic count with a direct tap to the Unread filter. Available in small, accessory circular, and accessory inline sizes.',
          ] },
          { type: 'heading', text: 'Control Center (iOS 18 and later)' },
          { type: 'bullets', items: [
            'AppleVis Podcast toggle — play or pause the current AppleVis podcast episode from Control Center without unlocking your phone.',
            'AppleVis Forums button — open unread forum topics directly from Control Center.',
            'Add these from iOS Settings > Control Center.',
          ] },
          { type: 'heading', text: 'Spotlight' },
          { type: 'body', text: 'Spotlight can find AppleVis topics, apps, podcasts, and resources from iOS Search. Items you open are indexed so they appear in future Spotlight results.' },
        ],
      },
      {
        id: 'smart-apple-intelligence',
        title: 'Apple Intelligence Features',
        summary: 'What Apple Intelligence powers in AppleVis, which devices support it, and how to enable it.',
        content: [
          { type: 'body', text: 'AppleVis uses Apple Intelligence to power several on-device AI features. All processing happens on your device — no text or content is sent to a server.' },
          { type: 'heading', text: 'Requirements' },
          { type: 'bullets', items: [
            'iPhone 15 Pro, iPhone 16, or later (Apple Intelligence requires the A17 Pro chip or M-series chip).',
            'iOS 26 or later for the full feature set using the FoundationModels framework.',
            'Apple Intelligence enabled in Settings > Apple Intelligence and Siri.',
            'English language preferred in Settings > General > Language and Region.',
          ] },
          { type: 'heading', text: 'What Apple Intelligence powers in AppleVis' },
          { type: 'bullets', items: [
            'Summarise — condenses long forum topics, blog posts, guides, and app descriptions.',
            'Simplify — rewrites complex text in plain, easy-to-read language.',
            'Accessibility Consensus — summarises community VoiceOver and usability feedback for an app into a short paragraph.',
            'Friendly Rewrite — polishes your forum reply or comment draft before you post it.',
            'Translate to English — translates your post or search query from another language.',
            'Draft with Apple Intelligence — generates a short editor note or summary from your submission content in the blog and app submission wizards.',
            'Guidelines Check — scans your draft for common posting issues and gives friendly advisory notes.',
          ] },
          { type: 'heading', text: 'When Apple Intelligence is not available' },
          { type: 'body', text: 'On devices or iOS versions that do not support Apple Intelligence, these features are hidden automatically. The app works fully without them — they are enhancements, not requirements.' },
          { type: 'note', text: 'To check whether Apple Intelligence is active on your device, open Settings > Apple Intelligence and Siri. If the toggle is visible and on, AppleVis AI features are enabled.' },
          { type: 'tip', text: 'If you disclose AI assistance in a post, a brief note such as "Polished with Friendly Rewrite" is appreciated by the community.' },
        ],
      },
      {
        id: 'smart-share',
        title: 'Share Into AppleVis',
        summary: 'Use the iOS Share Sheet to send App Store links, blog text, and podcast URLs into AppleVis.',
        content: [
          { type: 'body', text: 'The AppleVis Share Extension appears in the system share sheet across iOS. Depending on what you share, the app opens the appropriate wizard or screen automatically.' },
          { type: 'heading', text: 'App Store links' },
          { type: 'steps', items: [
            'Find an app in the App Store or in Safari.',
            'Tap Share and choose AppleVis from the share sheet.',
            'The app submission wizard opens with that app pre-selected.',
          ] },
          { type: 'heading', text: 'Blog text or text files' },
          { type: 'steps', items: [
            'Copy or highlight text in any app — Notes, Pages, Safari, Messages, or any other.',
            'Tap Share and choose AppleVis.',
            'The blog submission wizard opens with your text already loaded in the content step.',
            'You can also share a .txt or .md file from Files or iCloud Drive the same way.',
          ] },
          { type: 'heading', text: 'Podcast URLs' },
          { type: 'steps', items: [
            'Find a podcast episode in Podcasts, Overcast, Spotify, Pocket Casts, or any other podcast app.',
            'Tap Share and choose AppleVis.',
            'The podcast submission wizard opens.',
          ] },
          { type: 'note', text: 'You must have the AppleVis app installed for it to appear in your share sheet. Sharing opens AppleVis and dismisses the share sheet automatically.' },
          { type: 'tip', text: 'If AppleVis does not appear in your share sheet, scroll to the end of the app row and tap More to find and enable it.' },
        ],
      },
      {
        id: 'smart-system-integrations',
        title: 'Handoff, Apple Watch, Background Refresh, and AirPlay',
        summary: 'What each system integration does and how to turn it off if you prefer not to use it.',
        contentType: 'guide',
        content: [
          { type: 'heading', text: 'Handoff' },
          { type: 'body', text: 'AppleVis advertises the screen you are viewing (Home, Discover, a podcast episode, and similar) so you can pick up on a nearby Mac or iPad using the Handoff icon in the Dock or App Switcher. Only a screen name and, where relevant, a public content link are shared — no account details, tokens, or private data leave the device.' },
          { type: 'tip', text: 'To turn Handoff off entirely for all apps, use iOS Settings > General > AirPlay & Handoff > Handoff.' },
          { type: 'heading', text: 'Apple Watch' },
          { type: 'body', text: 'When a companion watch app is installed, it mirrors Now Playing controls for AppleVis podcasts — play, pause, and skip — from your wrist.' },
          { type: 'note', text: 'Remove the AppleVis Watch app from the Watch app on iPhone if you do not want this mirroring.' },
          { type: 'heading', text: 'Background Refresh' },
          { type: 'body', text: 'AppleVis periodically refreshes downloaded episode metadata and checks for followed-topic activity while in the background, so content is current the next time you open the app.' },
          { type: 'tip', text: 'Turn this off in iOS Settings > General > Background App Refresh > AppleVis. Podcast playback itself keeps working in the background either way — only the periodic content refresh is affected.' },
          { type: 'heading', text: 'AirPlay and Route Picker' },
          { type: 'body', text: 'The route picker in the podcast player lets you send audio to AirPlay speakers, HomePod, or Bluetooth devices, the same way any other audio app does.' },
          { type: 'heading', text: 'iCloud Sync' },
          { type: 'body', text: 'Saved items, following, reading position, podcast position, queue, and preferences can sync through your private iCloud account. Each of these can be turned on or off individually in Settings > Saved and Sync.' },
        ],
        relatedLinks: [
          { label: 'Saved and Sync Settings', type: 'guide', route: '/settings-saved-sync' },
        ],
      },
    ],
  },
  {
    id: 'troubleshooting',
    title: 'Troubleshooting',
    icon: 'construct-outline',
    description: 'Fix common problems with sign-in, sync, notifications, search, playback, and display.',
    articles: [
      {
        id: 'trouble-sign-in',
        title: 'Sign-In Problems',
        summary: 'What to check when your AppleVis account does not sign in.',
        contentType: 'troubleshooting',
        content: [
          { type: 'bullets', items: [
            'Use your applevis.com account credentials.',
            'Check your connection.',
            'Reset your password on applevis.com if needed.',
            'If a session expires, sign in again from Profile.',
          ] },
        ],
      },
      {
        id: 'trouble-sync-notifications',
        title: 'Sync and Notification Problems',
        summary: 'Checks for iCloud sync and push notifications.',
        contentType: 'troubleshooting',
        content: [
          { type: 'bullets', items: [
            'Confirm iCloud Sync is on in Settings > Saved and Sync.',
            'Confirm both devices use the same Apple ID.',
            'Confirm AppleVis notifications are allowed in iOS Settings.',
            'Confirm the notification category is enabled in AppleVis Settings > Notifications.',
            'Sign in for personalized notification categories.',
          ] },
        ],
      },
      {
        id: 'trouble-podcast-search',
        title: 'Podcast, Search, and Display Problems',
        summary: 'Quick fixes for playback, search results, and visual comfort.',
        contentType: 'troubleshooting',
        content: [
          { type: 'bullets', items: [
            'If playback seems stuck, pause and play again, or open the episode page and press Play.',
            'If search results are poor, try fewer words or translate a non-English query to English.',
            'If the app feels too bright, too dense, or too animated, review Appearance and iOS Display & Text Size.',
            'If storage grows, use Settings > Storage and Cache.',
            'If a download fails, check your connection and try again from the episode or Downloads list — partial downloads are removed automatically.',
            'If content will not refresh, pull down to refresh, or check Settings > Saved and Sync if you expect it to sync from another device.',
            'If you cannot find saved content, open For You > Saved and check the kind filter — it may be set to a specific content type. Use Clear Filter to see everything again.',
          ] },
        ],
      },
      {
        id: 'trouble-contact',
        title: 'Contact App Support',
        summary: 'Send bugs, feedback, suggestions, and recommendations using the in-app contact wizard.',
        contentType: 'troubleshooting',
        content: [
          { type: 'body', text: 'The in-app contact wizard sends your message directly to the AppleVis team. No email app needed. You can reach it from Profile or from Help. The wizard has three steps when signed in, or four steps when not signed in.' },
          { type: 'heading', text: 'Step 1 — Choose a type' },
          { type: 'steps', items: [
            'Open Profile and tap Contact App Support, or open Help and scroll to the Contact section.',
            'Choose what kind of message you are sending: App Bug Report, App Feedback, App Suggestion, or App Recommendation.',
            'Tap the card for your chosen type. The subject is set automatically from the type you choose.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Step 2 — Your contact details (not signed in only)' },
          { type: 'body', text: 'If you are not signed in, this step appears before the message step. Enter your name and email address so the team can reply to you. If you are signed in, your name and email are already known and this step is skipped.' },
          { type: 'heading', text: 'Step 2 (signed in) or Step 3 (not signed in) — Write your message' },
          { type: 'steps', items: [
            'Type your message in the large text area.',
            'If you chose Bug Report, a toggle appears to include system information. Turn it on to append your app version and iOS version automatically.',
            'Tap Continue.',
          ] },
          { type: 'heading', text: 'Final step — Review and send' },
          { type: 'steps', items: [
            'Review the summary: your message type, subject, and message preview are shown.',
            'Your name and email are shown in the From section. If you are signed in they are read-only. If you are not signed in they are editable here.',
            'Check the declaration to confirm the message is genuine.',
            'Tap Send Message.',
            'A confirmation screen appears. The team will typically respond within two to three business days.',
          ] },
          { type: 'tip', text: 'The Help screen also has a Contact App Support button at the bottom if you find a relevant help article first and still need to get in touch.' },
          { type: 'note', text: 'You do not need to be signed in to use the contact wizard. Not signed in adds one extra step for your name and email.' },
        ],
      },
    ],
  },
];

export function findHelpSection(id: string): HelpSection | undefined {
  return HELP_SECTIONS.find((s) => s.id === id);
}

export function findHelpArticle(articleId: string): HelpArticle | undefined {
  for (const section of HELP_SECTIONS) {
    const article = section.articles.find((a) => a.id === articleId);
    if (article) return article;
  }
  return undefined;
}
