/**
 * AppleVis In-App Help Centre
 * 9 sections — fully offline, VoiceOver-optimised structured content.
 *
 * Content types:
 *   heading — bold section break within an article
 *   body    — standard paragraph
 *   bullets — unordered list of short items
 *   steps   — numbered tutorial steps
 *   tip     — highlighted AppleVis Tip (green tint)
 *   note    — informational aside (blue tint)
 *   warning — caution notice (amber tint)
 */

export type ContentBlock =
  | { type: 'heading'; text: string }
  | { type: 'body'; text: string }
  | { type: 'bullets'; items: string[] }
  | { type: 'steps'; items: string[] }
  | { type: 'tip'; text: string }
  | { type: 'note'; text: string }
  | { type: 'warning'; text: string };

export type HelpArticle = {
  id: string;
  title: string;
  summary: string;
  content: ContentBlock[];
};

export type HelpSection = {
  id: string;
  title: string;
  icon: string;
  description: string;
  articles: HelpArticle[];
};

// ─────────────────────────────────────────────────────────────────────────────

export const HELP_SECTIONS: HelpSection[] = [

  // ── 1. Getting Started ───────────────────────────────────────────────────────
  {
    id: 'gettingStarted',
    title: 'Getting Started',
    icon: '🚀',
    description: 'Your first steps with AppleVis — navigating the app, signing in, and the key features at a glance.',
    articles: [
      {
        id: 'gs-what-is-applevis',
        title: 'What is AppleVis?',
        summary: 'An introduction to the AppleVis community and what you can do with this app.',
        content: [
          { type: 'body', text: 'AppleVis is the largest community on the internet for blind, low-vision, and sighted users of Apple products. Founded in 2009, it is run by and for people who rely on accessibility features like VoiceOver, Switch Control, and Voice Control every day.' },
          { type: 'body', text: 'The AppleVis app gives you access to the full community — forum discussions, a directory of app accessibility reviews, podcast episodes, and guides — all in a fully accessible native iOS experience.' },
          { type: 'heading', text: 'The five tabs' },
          { type: 'bullets', items: [
            'Home — your personal dashboard, saved items, and recent activity',
            'Forums — community discussions on every Apple accessibility topic',
            'Apps — thousands of app accessibility reviews, searchable by name or category',
            'Podcasts — the AppleVis podcast, with full player, chapters, and queue',
            'Resources — guides, tutorials, how-to articles, events, and developer resources',
          ]},
          { type: 'tip', text: 'Everything in the app works without signing in. An account unlocks posting, following topics, push notifications, and iCloud sync.' },
        ],
      },
      {
        id: 'gs-signing-in',
        title: 'Signing In',
        summary: 'How to sign in and what your account unlocks.',
        content: [
          { type: 'body', text: 'Sign in with the same email address and password you use on applevis.com. If you do not have an account, visit applevis.com on the web to register — it is free.' },
          { type: 'heading', text: 'How to sign in' },
          { type: 'steps', items: [
            'Tap the Settings link in the top-right corner of any tab.',
            'Tap "Sign In" at the top of the Settings screen.',
            'Enter your AppleVis email address and password.',
            'Tap "Sign In". A welcome message confirms success.',
          ]},
          { type: 'heading', text: 'What signing in unlocks' },
          { type: 'bullets', items: [
            'Post and reply in the forums',
            'Follow topics and receive push notifications when they get new replies',
            'Sync saved items, reading positions, and your podcast queue across all your Apple devices via iCloud',
            'Receive personalised push notifications for mentions, replies, and new content',
          ]},
          { type: 'note', text: 'Your password is never stored on the device. Only an encrypted session token is kept in the iOS Keychain.' },
        ],
      },
      {
        id: 'gs-navigation',
        title: 'Navigating the App',
        summary: 'How to move between sections, use the tab bar, and go back.',
        content: [
          { type: 'body', text: 'The bottom tab bar provides access to all five main areas. Tap any tab icon to switch sections. The current tab is indicated visually and announced by VoiceOver.' },
          { type: 'heading', text: 'iPadOS hardware keyboard shortcuts' },
          { type: 'bullets', items: [
            '⌘1 — Forums',
            '⌘2 — Apps',
            '⌘3 — Podcasts',
            '⌘4 — Resources',
            '⌘F — Search',
            '⌘R — Refresh',
            '⌘, — Settings',
          ]},
          { type: 'heading', text: 'Going back' },
          { type: 'body', text: 'On any detail screen, tap the back button or use the two-finger scrub (draw a Z shape with two fingers) to return to the previous screen. VoiceOver focus is restored to the item you came from.' },
          { type: 'tip', text: 'Pull down on any list screen to refresh its content. After refreshing, VoiceOver focus moves to the first item automatically.' },
        ],
      },
    ],
  },

  // ── 2. VoiceOver User Guide ───────────────────────────────────────────────────
  {
    id: 'voiceover',
    title: 'VoiceOver User Guide',
    icon: '👁',
    description: 'A complete guide for VoiceOver users — gestures, the rotor, custom actions, magic tap, and step-by-step tutorials.',
    articles: [
      {
        id: 'vo-gestures',
        title: 'Essential VoiceOver Gestures',
        summary: 'The key gestures for navigating AppleVis with VoiceOver.',
        content: [
          { type: 'body', text: 'AppleVis is fully optimised for VoiceOver. Every element has an accessibility label, hint, and role. Here are the gestures you will use most.' },
          { type: 'heading', text: 'Navigation' },
          { type: 'bullets', items: [
            'Swipe right — move to the next element',
            'Swipe left — move to the previous element',
            'Double tap — activate the selected element (open, toggle, press)',
            'Swipe up or down — use the current rotor setting',
            'Two-finger swipe up — read all from current position',
            'Two-finger scrub (Z shape) — go back to the previous screen',
            'Two-finger double tap — magic tap (play/pause podcast from anywhere)',
          ]},
          { type: 'heading', text: 'The Rotor' },
          { type: 'body', text: 'Rotate two fingers on the screen (like turning a dial) to choose a rotor setting. Then swipe up or down to use it. In AppleVis, the Actions rotor setting is the most important.' },
          { type: 'tip', text: 'If VoiceOver is reading too much or too little, go to Settings → Accessibility → VoiceOver Detail Level and choose Simple, Normal, or All.' },
        ],
      },
      {
        id: 'vo-custom-actions',
        title: 'Custom Actions on Content Cards',
        summary: 'How to use the VoiceOver Actions rotor to interact with forum topics, apps, and episodes.',
        content: [
          { type: 'body', text: 'Every content card in AppleVis exposes a set of custom actions in the VoiceOver Actions rotor. These let you perform common tasks without leaving the list.' },
          { type: 'heading', text: 'How to use custom actions' },
          { type: 'steps', items: [
            'Navigate to a content card (forum topic, app, podcast episode, or resource).',
            'Rotate the VoiceOver rotor to "Actions".',
            'Swipe up or down to cycle through the available actions.',
            'Double tap to perform the selected action.',
          ]},
          { type: 'heading', text: 'Actions on a forum topic' },
          { type: 'bullets', items: [
            'Open — opens the full topic',
            'Save Topic / Unsave Topic — adds or removes from your Saved list',
            'Follow Topic / Unfollow Topic — subscribe to notifications for this thread',
            'Mark as Read — marks the topic read without opening it',
            'Read Aloud — reads title and preview aloud using TTS',
            'Translate — opens the iOS Translate sheet',
            'Summarise — condenses the topic (requires Apple Intelligence)',
            'Share — opens the iOS Share sheet',
          ]},
          { type: 'note', text: 'Long-pressing any card with a sighted finger shows the same actions in a native iOS action sheet.' },
        ],
      },
      {
        id: 'vo-magic-tap',
        title: 'Magic Tap — Play and Pause Anywhere',
        summary: 'Use a two-finger double tap to control podcast playback from anywhere in the app.',
        content: [
          { type: 'body', text: 'Magic tap is a VoiceOver gesture (two-finger double tap) that performs the most relevant action for the current app context. In AppleVis, magic tap plays or pauses the podcast player from any screen — you do not need to navigate to the Podcasts tab.' },
          { type: 'heading', text: 'Using magic tap' },
          { type: 'steps', items: [
            'Start playing a podcast episode from the Podcasts tab.',
            'Navigate to any other tab — Forums, Apps, Resources.',
            'Double tap with two fingers. Playback pauses.',
            'Double tap with two fingers again. Playback resumes.',
          ]},
          { type: 'tip', text: 'Magic tap also works from the Lock Screen when a podcast is playing, without unlocking your phone.' },
        ],
      },
      {
        id: 'vo-announcement-levels',
        title: 'VoiceOver Detail Levels Explained',
        summary: 'Understanding Simple, Normal, and All — and which to choose.',
        content: [
          { type: 'body', text: 'AppleVis offers three levels of detail for what VoiceOver reads when it lands on a content card. You set this in Settings → Accessibility → VoiceOver Detail Level.' },
          { type: 'heading', text: 'Simple' },
          { type: 'body', text: 'VoiceOver reads only the title. "iOS 18 VoiceOver Tips." Use this if you want to scan a long list quickly and look up details for specific items manually.' },
          { type: 'heading', text: 'Normal' },
          { type: 'body', text: 'Title plus the most useful context — unread state and reply count. "iOS 18 VoiceOver Tips. Unread. 14 replies." Good for users who want the key facts without verbosity.' },
          { type: 'heading', text: 'All (Recommended)' },
          { type: 'body', text: 'Everything at once — title, status, counts, follow and save state, author, and date. "iOS 18 VoiceOver Tips. Unread. 14 replies. Following. Saved. Posted by JaneD, 2 days ago." The richest experience — the default for new users.' },
          { type: 'tip', text: 'You can change this setting at any time. Many users start with All and switch to Normal once they are familiar with the app.' },
        ],
      },
      {
        id: 'vo-tutorial-forums',
        title: 'Tutorial: Reading a Forum Topic with VoiceOver',
        summary: 'Step-by-step: browse, read, and interact with a forum thread using VoiceOver.',
        content: [
          { type: 'steps', items: [
            'Tap the Forums tab in the bottom tab bar.',
            'Swipe right to move through the filter bar at the top (Recent, Unread, Since Last Visit, Following, Saved). Double tap a filter to apply it.',
            'Swipe right past the filter bar to reach the first topic card. VoiceOver reads the title and meta (unread state, reply count, author) depending on your detail level.',
            'To read the topic, double tap. The topic detail screen opens.',
            'Swipe right to read each reply in sequence. Use "Read All" (two-finger swipe up) to have VoiceOver read all replies automatically.',
            'To go back to the list, draw a Z shape with two fingers (two-finger scrub). VoiceOver focus returns to the topic card you came from.',
          ]},
          { type: 'tip', text: 'While on a topic card, rotate the rotor to Actions and swipe down to see Save, Follow, Read Aloud, and other options — without opening the topic.' },
        ],
      },
    ],
  },

  // ── 3. Forums ─────────────────────────────────────────────────────────────────
  {
    id: 'forums',
    title: 'Forums',
    icon: '💬',
    description: 'Browsing discussions, using filters, following topics, posting, and managing notifications.',
    articles: [
      {
        id: 'forums-filters',
        title: 'Understanding the Forum Filters',
        summary: 'What each filter shows and when to use it.',
        content: [
          { type: 'body', text: 'The Forums tab has a horizontal filter bar at the top. Swipe through it to see the options and double tap to apply one.' },
          { type: 'heading', text: 'Recent' },
          { type: 'body', text: 'Shows all recent forum activity in reverse chronological order — the most recently replied-to topics appear first, regardless of whether you have read them.' },
          { type: 'heading', text: 'Since Last Visit' },
          { type: 'body', text: 'Shows every topic that received a new post since the last time you opened AppleVis. Perfect for catching up — nothing is missed and nothing repeats.' },
          { type: 'heading', text: 'Unread' },
          { type: 'body', text: 'Shows only topics you have never opened. Reading position syncs across your devices via iCloud when iCloud Sync is enabled.' },
          { type: 'heading', text: 'Following' },
          { type: 'body', text: 'Shows topics you have chosen to follow. Following a topic means you receive a push notification whenever a new reply is added.' },
          { type: 'heading', text: 'Saved' },
          { type: 'body', text: 'Topics you have explicitly saved for later reading. Saved items sync via iCloud across all your devices.' },
          { type: 'tip', text: '"Since Last Visit" is the best filter for daily use — it is a clean slate every time you open the app.' },
        ],
      },
      {
        id: 'forums-following',
        title: 'Following Topics',
        summary: 'How to subscribe to a discussion and manage your notifications.',
        content: [
          { type: 'body', text: 'Following a topic subscribes you to push notifications for all new replies, even replies not directed at you. This is different from a mention (which notifies you when someone specifically tags you).' },
          { type: 'heading', text: 'How to follow a topic' },
          { type: 'steps', items: [
            'Navigate to a topic card in the Forums list.',
            'Use the VoiceOver Actions rotor and choose "Follow Topic".',
            'Or: open the topic and tap "Follow" from the topic toolbar.',
            'A confirmation toast appears: "Now following this topic."',
          ]},
          { type: 'heading', text: 'Managing followed topics' },
          { type: 'body', text: 'Switch to the Following filter in the Forums tab to see all topics you are following. To unfollow, use the Actions rotor and choose "Unfollow Topic".' },
          { type: 'note', text: 'You must be signed in to follow topics. Following is synced via iCloud across your devices.' },
        ],
      },
      {
        id: 'forums-posting',
        title: 'Posting and Replying',
        summary: 'How to start a new topic or reply to an existing one.',
        content: [
          { type: 'body', text: 'Posting in the forums requires a signed-in AppleVis account. Guest browsing is always available.' },
          { type: 'heading', text: 'Replying to a topic' },
          { type: 'steps', items: [
            'Open a forum topic.',
            'Scroll to the bottom of the replies.',
            'Tap "Reply" or the compose button.',
            'Type your reply in the text field.',
            'The posting guidelines checker reviews your draft as you type — a reminder banner appears if something might need attention. It never blocks you from posting.',
            'Tap "Post Reply" to submit.',
          ]},
          { type: 'heading', text: 'Before you post' },
          { type: 'bullets', items: [
            'Stay on topic — reply only to the subject of the thread',
            'Keep it constructive — criticism should be specific and helpful',
            'Do not share contact details or referral links',
            'Disclose if AI tools helped you write your post',
            'See the full Posting Guidelines in the Help section for more',
          ]},
          { type: 'tip', text: 'The built-in guidelines checker flags common issues (all caps, off-topic, self-promotion) as you type, so you can fix them before submitting.' },
        ],
      },
    ],
  },

  // ── 4. Apps Directory ────────────────────────────────────────────────────────
  {
    id: 'apps',
    title: 'Apps Directory',
    icon: '📱',
    description: 'Finding apps, reading accessibility reviews, the Accessibility Consensus, and saving listings.',
    articles: [
      {
        id: 'apps-browsing',
        title: 'Browsing and Searching the Directory',
        summary: 'How to find app listings by name, category, or developer.',
        content: [
          { type: 'body', text: 'The Apps tab lists thousands of app accessibility reviews submitted by the AppleVis community. Each listing focuses on how well the app works with VoiceOver and other accessibility features.' },
          { type: 'heading', text: 'Searching for an app' },
          { type: 'steps', items: [
            'Tap "Search" in the top-right corner of the Apps tab.',
            'Type the app name, developer name, or a keyword like "navigation" or "banking".',
            'Results appear as you type, grouped into Apps, Forum Topics, and Resources.',
            'Tap any result to open it.',
          ]},
          { type: 'heading', text: 'What each listing shows' },
          { type: 'bullets', items: [
            'App name and developer',
            'Category (e.g. Navigation, Banking, Social)',
            'Number of reviews and overall accessibility rating',
            'Last updated date',
            'Community reviews describing VoiceOver compatibility',
          ]},
        ],
      },
      {
        id: 'apps-consensus',
        title: 'Accessibility Consensus',
        summary: 'What the Accessibility Consensus summary means and how it is generated.',
        content: [
          { type: 'body', text: 'The Accessibility Consensus is a one or two sentence summary of what the community says about an app\'s accessibility. It aggregates multiple user reviews into a single clear statement.' },
          { type: 'body', text: 'Example: "Most reviewers say this app works well with VoiceOver for its core features. Some users note that the in-app purchase screen is not fully labelled."' },
          { type: 'note', text: 'When Apple Intelligence Foundation Models support is added, the Consensus will be generated on-device using AI. Until then, it is created editorially by the AppleVis team.' },
          { type: 'tip', text: 'You can access the Consensus via the VoiceOver Actions rotor on any app card — look for "Accessibility Consensus".' },
        ],
      },
    ],
  },

  // ── 5. Podcasts ───────────────────────────────────────────────────────────────
  {
    id: 'podcasts',
    title: 'Podcast Player',
    icon: '🎙️',
    description: 'Playing episodes, the queue, chapters, speed, sleep timer, and background playback.',
    articles: [
      {
        id: 'podcasts-playing',
        title: 'Playing an Episode',
        summary: 'How to load and play a podcast episode.',
        content: [
          { type: 'heading', text: 'Starting playback' },
          { type: 'steps', items: [
            'Open the Podcasts tab.',
            'Swipe to an episode in the list.',
            'Double tap the episode card or use the Actions rotor and choose "Play".',
            'The player appears at the top of the screen with transport controls.',
          ]},
          { type: 'heading', text: 'Transport controls' },
          { type: 'bullets', items: [
            'Play / Pause — the large central button',
            'Skip back — rewinds by your skip-back setting (default 10 seconds)',
            'Skip forward — jumps ahead by your skip-forward setting (default 30 seconds)',
            'Speed — choose from 0.5× to 3.0×',
            'Sleep timer — auto-pause after a set time',
            'Chapters — jump to any chapter within the episode',
          ]},
          { type: 'heading', text: 'VoiceOver scrubber control' },
          { type: 'body', text: 'The progress bar is an adjustable VoiceOver element. Navigate to it, then swipe up to skip forward 10 seconds or swipe down to rewind 10 seconds. The current and total times are read aloud.' },
          { type: 'tip', text: 'Magic tap (two-finger double tap) plays or pauses the current episode from anywhere in the app — you do not need to be on the Podcasts tab.' },
        ],
      },
      {
        id: 'podcasts-queue',
        title: 'The Play Queue',
        summary: 'How to build and manage your episode queue.',
        content: [
          { type: 'body', text: 'The queue lets you line up episodes to play one after another. When the current episode finishes, the next one in the queue starts automatically (if Auto-Play Next is enabled in Podcast Settings).' },
          { type: 'heading', text: 'Adding to the queue' },
          { type: 'bullets', items: [
            'Use the Actions rotor on any episode card and choose "Add to Queue".',
            'Choose "Play Next" to move an episode to the front of the queue.',
          ]},
          { type: 'heading', text: 'Queue sync' },
          { type: 'body', text: 'Your queue is saved and synced via iCloud when Queue Sync is enabled in Saved & Sync settings. Switch devices and your queue is waiting.' },
        ],
      },
      {
        id: 'podcasts-defaults',
        title: 'Setting Your Podcast Defaults',
        summary: 'How your preferred speed, skip times, and other options are saved and synced.',
        content: [
          { type: 'body', text: 'Go to Settings → Podcasts to set your default playback preferences. These are applied every time you start a new episode and synced to all your devices via iCloud.' },
          { type: 'heading', text: 'Available defaults' },
          { type: 'bullets', items: [
            'Default Playback Speed — 0.5× to 3.0×',
            'Skip Back Time — 5, 10, 15, or 30 seconds',
            'Skip Forward Time — 15, 30, 45, or 60 seconds',
            'Auto-Play Next Episode — on/off',
            'Default Sleep Timer — off, 15m, 30m, 45m, 60m',
            'Voice Enhancement — boost speech clarity',
            'EQ Preset — Flat, Speech, Bass Boost, Treble Boost',
            'Auto-Download — off, Wi-Fi Only, Always',
            'Auto-Delete Played — off, after 1 day, after 1 week',
          ]},
          { type: 'note', text: 'You can override speed and sleep timer per-session in the player. Your defaults restore when you start the next episode.' },
        ],
      },
    ],
  },

  // ── 6. Resources ─────────────────────────────────────────────────────────────
  {
    id: 'resources',
    title: 'Resources & Guides',
    icon: '📖',
    description: 'What types of content appear in Resources, how to filter, save, and share articles.',
    articles: [
      {
        id: 'resources-types',
        title: 'Types of Content in Resources',
        summary: 'What you will find in the Resources tab.',
        content: [
          { type: 'body', text: 'The Resources tab is a curated library of educational content covering every aspect of Apple accessibility.' },
          { type: 'heading', text: 'Content categories' },
          { type: 'bullets', items: [
            'Guides — detailed how-to articles for specific features or workflows',
            'Tutorials — step-by-step walkthroughs for learning a new skill',
            'News & Features — editorial coverage of Apple accessibility announcements',
            'Events — conferences, webinars, and community events',
            'Developer Resources — accessibility APIs, SwiftUI tips, and WWDC session notes',
            'Getting Started — beginner-friendly introductions for new Apple users',
          ]},
          { type: 'tip', text: 'Use the Search button at the top of the Resources tab to search by keyword across all content types.' },
        ],
      },
      {
        id: 'resources-saving',
        title: 'Saving and Sharing Resources',
        summary: 'How to save articles for offline reading and share them.',
        content: [
          { type: 'steps', items: [
            'Navigate to a resource card.',
            'Use the VoiceOver Actions rotor and choose "Save".',
            'The article appears in your Saved filter and syncs via iCloud.',
            'To share: choose "Share" in the Actions rotor. The iOS Share sheet opens with the article title and link ready to send.',
            'To copy the link directly: choose "Copy Link" in the Actions rotor.',
          ]},
        ],
      },
    ],
  },

  // ── 7. Apple Intelligence ─────────────────────────────────────────────────────
  {
    id: 'intelligence',
    title: 'Apple Intelligence & Siri',
    icon: '✨',
    description: 'Every AI feature — what works now, what is coming, and how to use each one.',
    articles: [
      {
        id: 'ai-works-now',
        title: 'Features That Work Right Now',
        summary: 'AI and Siri features available today without any native module.',
        content: [
          { type: 'heading', text: 'Read Aloud' },
          { type: 'body', text: 'Uses your device\'s on-device text-to-speech to read any content card aloud. Works without VoiceOver and without internet. Available in the Actions rotor on every content type.' },
          { type: 'heading', text: 'Translate' },
          { type: 'body', text: 'Opens the iOS Translate app with content pre-filled. Supports all languages iOS Translate supports — no API key or subscription needed.' },
          { type: 'heading', text: 'Non-English Detection' },
          { type: 'body', text: 'When you type in a non-English language in the search bar or compose area, a banner appears offering to translate your query before submitting. Uses a Unicode-range heuristic — works offline, processes nothing on a server.' },
          { type: 'heading', text: 'Posting Guidelines Checker' },
          { type: 'body', text: 'A rule-based checker reviews your draft as you type and flags common issues — all-caps, referral links, email addresses, self-promotion, and more. A banner appears with a friendly reminder. It never blocks you from posting.' },
        ],
      },
      {
        id: 'ai-coming',
        title: 'Features Coming with Apple Intelligence',
        summary: 'On-device AI features that require Foundation Models — iOS 18.2 or later.',
        content: [
          { type: 'note', text: 'The features below require Apple\'s Foundation Models (on-device LLM). They are fully designed and stubbed in the app — they become active once the native Swift module is built.' },
          { type: 'heading', text: 'Summarise' },
          { type: 'body', text: 'Condenses any forum thread or resource article to 2–3 sentences using Apple\'s on-device Foundation Models. Private — no text leaves your device.' },
          { type: 'heading', text: 'Simplify' },
          { type: 'body', text: 'Rewrites technical content in plain, simple language. Useful for complex developer discussions or medical/legal accessibility content.' },
          { type: 'heading', text: 'Accessibility Consensus' },
          { type: 'body', text: 'Aggregates multiple app reviews into a single clear sentence describing the community\'s overall accessibility verdict.' },
          { type: 'heading', text: 'Siri App Intents' },
          { type: 'body', text: 'Voice commands: "Open AppleVis Forums", "Play the latest AppleVis podcast", "Show what\'s new on AppleVis since my last visit". Requires the Swift AppIntent native module.' },
          { type: 'heading', text: 'Live Activities & Dynamic Island' },
          { type: 'body', text: 'Podcast playback controls on your Lock Screen and Dynamic Island. Requires ActivityKit native module.' },
          { type: 'heading', text: 'Spotlight Search' },
          { type: 'body', text: 'Forum topics, podcast episodes, and app listings appear in the system-wide iOS Search. Requires CoreSpotlight native module.' },
        ],
      },
    ],
  },

  // ── 8. FAQ ────────────────────────────────────────────────────────────────────
  {
    id: 'faq',
    title: 'Frequently Asked Questions',
    icon: '❓',
    description: 'Answers to the 30 most common questions from AppleVis users.',
    articles: [
      {
        id: 'faq-account',
        title: 'Account Questions',
        summary: 'Sign-in, registration, passwords, and account management.',
        content: [
          { type: 'heading', text: 'Why can\'t I sign in?' },
          { type: 'body', text: 'Make sure you are using your applevis.com email address and password — not a social login. If you have forgotten your password, tap "Change Password" in Settings → Account and reset it on the website.' },
          { type: 'heading', text: 'How do I create an account?' },
          { type: 'body', text: 'Open Safari and visit applevis.com. Tap "Register" and complete the form. Once registered, sign in within the app using Settings → Account → Sign In.' },
          { type: 'heading', text: 'Can I use the app without an account?' },
          { type: 'body', text: 'Yes. Browsing forums, apps, podcasts, and resources is fully available without signing in. An account is only required for posting, following, and iCloud sync.' },
          { type: 'heading', text: 'My session expired — what happened?' },
          { type: 'body', text: 'For security, sessions expire after a period of inactivity. Sign in again from Settings → Account. Your saved items in iCloud are safe and will re-sync automatically.' },
        ],
      },
      {
        id: 'faq-sync',
        title: 'Sync and iCloud Questions',
        summary: 'Why items are not syncing and how to fix it.',
        content: [
          { type: 'heading', text: 'My saved items are not syncing between devices.' },
          { type: 'body', text: 'Check that both devices are signed in to the same Apple ID and that iCloud Sync is enabled in Settings → Saved & Sync. Also check iPhone Settings → Apple ID → iCloud → AppleVis is toggled on.' },
          { type: 'heading', text: 'How much iCloud storage does AppleVis use?' },
          { type: 'body', text: 'Very little — typically under 1 MB. AppleVis stores structured data (saved item IDs, reading positions, preferences), not full article content.' },
          { type: 'heading', text: 'My reading position is wrong on my second device.' },
          { type: 'body', text: 'Reading positions sync when you open a topic and when the app backgrounds. If you close the app immediately after reading, the position may not have synced yet. Give it a few seconds before switching devices.' },
        ],
      },
      {
        id: 'faq-voiceover',
        title: 'VoiceOver Questions',
        summary: 'Common VoiceOver usage questions specific to AppleVis.',
        content: [
          { type: 'heading', text: 'How do I access the custom actions on a card?' },
          { type: 'body', text: 'Navigate to a content card with VoiceOver. Rotate the rotor to "Actions". Swipe up or down to cycle through the actions and double tap to activate the one you want.' },
          { type: 'heading', text: 'VoiceOver is reading too much information on each card.' },
          { type: 'body', text: 'Go to Settings → Accessibility → VoiceOver Detail Level and choose "Simple" (title only) or "Normal" (title + key status). The default "All" reads everything.' },
          { type: 'heading', text: 'How do I go back to the previous screen with VoiceOver?' },
          { type: 'body', text: 'Draw a Z shape with two fingers — this is the standard VoiceOver escape gesture. You can also use the two-finger scrub. The app implements this on every screen.' },
          { type: 'heading', text: 'How do I play or pause the podcast without going to the Podcasts tab?' },
          { type: 'body', text: 'Double tap with two fingers — this is the magic tap gesture. It plays or pauses the current episode from anywhere in the app.' },
          { type: 'heading', text: 'The podcast scrubber is hard to use with VoiceOver.' },
          { type: 'body', text: 'Navigate to the progress bar. VoiceOver treats it as an adjustable element. Swipe up to skip forward 10 seconds; swipe down to rewind 10 seconds. The current position is announced.' },
        ],
      },
      {
        id: 'faq-notifications',
        title: 'Notification Questions',
        summary: 'Setting up, enabling, and troubleshooting push notifications.',
        content: [
          { type: 'heading', text: 'I am not receiving notifications.' },
          { type: 'body', text: 'Check three places: (1) Settings → Notifications — make sure the categories you want are toggled on. (2) iPhone Settings → Notifications → AppleVis — make sure notifications are allowed. (3) You must be signed in to receive personalised notifications like forum replies.' },
          { type: 'heading', text: 'How do I change my notification sound?' },
          { type: 'body', text: 'Go to Settings → Notifications → Alert Sound. Choose between Mouse Squeak, Apple Crunch, or System Default. Tap a sound to preview it.' },
          { type: 'heading', text: 'Can I get notifications for just one specific topic?' },
          { type: 'body', text: 'Yes. Use the Actions rotor on a forum topic card and choose "Follow Topic". Whenever anyone posts a new reply to that topic, you receive a notification — regardless of the global "New Topics" or "Forum Replies" toggles.' },
        ],
      },
      {
        id: 'faq-podcasts',
        title: 'Podcast Questions',
        summary: 'Common questions about the podcast player.',
        content: [
          { type: 'heading', text: 'Where is my podcast queue?' },
          { type: 'body', text: 'The queue is managed within the Podcasts tab. Add episodes via the Actions rotor ("Add to Queue" or "Play Next"). The next queued episode starts automatically when the current one finishes, if Auto-Play Next is enabled.' },
          { type: 'heading', text: 'My playback position was lost after I switched apps.' },
          { type: 'body', text: 'The app saves your position when you pause or when it backgrounds. Make sure you tap Pause before switching apps. If the system terminates the app in the background (rare on modern iPhones with sufficient memory), the last saved position restores on next launch.' },
          { type: 'heading', text: 'How do I set a permanent default speed?' },
          { type: 'body', text: 'Go to Settings → Podcasts → Default Playback Speed. Choose your preferred speed. This applies to every new episode you play. You can still change speed per-session in the player.' },
          { type: 'heading', text: 'Does the player support background audio?' },
          { type: 'body', text: 'Yes. Podcast audio continues playing when you switch apps, lock the screen, or use other iOS features. The system Controls on the Lock Screen and Control Center control the player.' },
        ],
      },
      {
        id: 'faq-themes',
        title: 'Theme Questions',
        summary: 'Changing themes, what each theme looks like, and Dark Mode.',
        content: [
          { type: 'heading', text: 'How do I change the theme?' },
          { type: 'body', text: 'Go to Settings → Appearance → Theme. Choose from 13 themes. The entire app re-themes instantly as you select each one, so you can preview before confirming.' },
          { type: 'heading', text: 'The app is not following my iPhone Dark Mode setting.' },
          { type: 'body', text: 'Make sure your Theme is set to "System" (the default). If you have chosen a specific theme like "Light" or "Mouse Dark", it will not automatically follow iOS Dark Mode — only "System" does that.' },
          { type: 'heading', text: 'What is the Mouse theme?' },
          { type: 'body', text: 'Mouse is a warm, golden-accented theme inspired by AppleVis\'s beloved AnonyMouse community persona. Available in both Light (cream and gold) and Dark (charcoal and gold) variants.' },
          { type: 'heading', text: 'Which theme is best for low vision?' },
          { type: 'body', text: 'High Contrast Light and High Contrast Dark both meet WCAG AAA contrast requirements — the highest standard. High Contrast Light uses pure white, pure black, and vivid blue. High Contrast Dark uses pure black, pure white, and vivid yellow. Choose based on whether you prefer a light or dark environment.' },
        ],
      },
    ],
  },

  // ── 9. Posting Guidelines ─────────────────────────────────────────────────────
  {
    id: 'guidelines',
    title: 'Posting Guidelines',
    icon: '📋',
    description: 'The full AppleVis community guidelines — what is and is not allowed in the forums.',
    articles: [
      {
        id: 'guidelines-overview',
        title: 'Community Standards Overview',
        summary: 'The principles behind the AppleVis forum rules.',
        content: [
          { type: 'body', text: 'AppleVis is a constructive, welcoming community for people who rely on accessibility features. The guidelines exist to keep discussions focused, respectful, and genuinely useful.' },
          { type: 'body', text: 'The in-app guidelines checker flags common issues as you type — it is a helpful reminder, not a gatekeeper. You can always post even if a reminder appears.' },
          { type: 'heading', text: 'Core principles' },
          { type: 'bullets', items: [
            'Be constructive — share knowledge, not just opinions',
            'Stay on topic — posts should relate to Apple accessibility',
            'Be respectful — critique ideas, not people',
            'Be honest — disclose AI assistance, affiliations, and conflicts of interest',
            'Keep it tidy — one topic per post, no duplicate threads',
          ]},
        ],
      },
      {
        id: 'guidelines-rules',
        title: 'Specific Rules',
        summary: 'Detailed rules with examples of what is and is not allowed.',
        content: [
          { type: 'heading', text: 'Formatting' },
          { type: 'bullets', items: [
            'Do not write in ALL CAPS — it is interpreted as shouting and is harder to read with VoiceOver',
            'Use clear, descriptive subject lines when starting a new thread',
          ]},
          { type: 'heading', text: 'Content restrictions' },
          { type: 'bullets', items: [
            'Do not include your email address in posts — use private messaging',
            'Do not share referral or affiliate links',
            'Do not post commercial advertisements or promotions',
            'Do not post the same content to multiple threads (cross-posting)',
            'Do not start topics on non-Apple platforms (Android, Windows) — there are other communities for those',
          ]},
          { type: 'heading', text: 'Self-promotion' },
          { type: 'body', text: 'Developers may post about their own apps if: the app is directly relevant to Apple accessibility, the post is factual (not promotional in tone), and they disclose they are the developer.' },
          { type: 'heading', text: 'AI-generated content' },
          { type: 'body', text: 'If you use AI tools to help write a post, disclose this at the start. For example: "I used AI to help draft this." AI-generated content posted without disclosure may be removed.' },
          { type: 'heading', text: 'Announcements requiring prior approval' },
          { type: 'body', text: 'Fundraisers, surveys, research studies, and prize competitions require prior approval from the AppleVis team before posting. Contact the team via Help → Contact AppleVis.' },
          { type: 'warning', text: 'Repeated guideline violations may result in moderation action on your account. If you are unsure whether something is appropriate, ask the team before posting.' },
        ],
      },
      {
        id: 'guidelines-checker',
        title: 'The In-App Guidelines Checker',
        summary: 'How the automatic checker works and what it checks.',
        content: [
          { type: 'body', text: 'As you write a post or reply, the app checks your draft against the guidelines in real time. A banner appears if something might be an issue.' },
          { type: 'heading', text: 'What the checker detects' },
          { type: 'bullets', items: [
            'All-caps text',
            'Email addresses in the body',
            'Referral or affiliate link patterns',
            'Self-promotion language ("my app", "check out my")',
            'Advertising phrases ("buy now", "limited time offer")',
            'AI content without disclosure ("ChatGPT", "AI generated")',
            'Low-value reply patterns ("great post!", "thanks for sharing")',
            'Multiple distinct topics in one post',
            'Duplicate or repetitive content',
          ]},
          { type: 'heading', text: 'Responding to a reminder' },
          { type: 'bullets', items: [
            'Tap "Got It" to dismiss the banner and post as-is',
            'Tap "View Guidelines" to read the full rule for context',
            'Or edit your draft to address the suggestion',
          ]},
          { type: 'tip', text: 'The checker never blocks you from posting. All reminders are advisory — you always decide whether to act on them.' },
        ],
      },
    ],
  },
];

/** Find a help section by id */
export function findHelpSection(id: string): HelpSection | undefined {
  return HELP_SECTIONS.find((s) => s.id === id);
}

/** Find an article across all sections by id */
export function findHelpArticle(articleId: string): HelpArticle | undefined {
  for (const section of HELP_SECTIONS) {
    const article = section.articles.find((a) => a.id === articleId);
    if (article) return article;
  }
  return undefined;
}
