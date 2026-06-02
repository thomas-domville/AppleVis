/**
 * Structured settings data — 10 sections.
 * Every item carries a label, description, and concrete example so users
 * (especially VoiceOver users) understand exactly what each setting does
 * before they interact with it.
 *
 * Types:
 *   toggle   — on/off switch
 *   picker   — choose from a list of options
 *   action   — button that does something immediately
 *   info     — read-only information, no interaction
 *   link     — navigates to a sub-screen or external URL
 *   nav      — navigates to another in-app screen
 */

export type SettingType = 'toggle' | 'picker' | 'action' | 'info' | 'link' | 'nav';
export type SettingStatus = 'live' | 'coming' | 'ios';

export type SettingItem = {
  id: string;
  label: string;
  description: string;
  example: string;
  type: SettingType;
  status?: SettingStatus;
  destructive?: boolean;
  route?: string;
};

export type SettingsSection = {
  id: string;
  title: string;
  description: string;
  icon: string;
  items: SettingItem[];
};

export const SETTINGS_SECTIONS: SettingsSection[] = [

  // ── 1. Account ───────────────────────────────────────────────────────────────
  {
    id: 'account',
    title: 'Account',
    description: 'Sign in, your profile, password, and account management.',
    icon: 'person-circle-outline',
    items: [
      {
        id: 'signIn',
        label: 'Sign In or Sign Out',
        description: 'Sign in with your AppleVis website email and password, or sign out of your current session.',
        example: 'Sign in to post replies in the forums, follow topics, and receive push notifications when someone replies to you.',
        type: 'action',
        status: 'live',
      },
      {
        id: 'displayName',
        label: 'Display Name',
        description: 'Your AppleVis username — the name other members see when you post.',
        example: 'If your username on applevis.com is "JaneD", that is what appears here and on all your forum posts.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'emailAddress',
        label: 'Email Address',
        description: 'The email address linked to your AppleVis account, used for sign-in and notifications.',
        example: 'example@email.com — this is the address you registered with on applevis.com.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'changePassword',
        label: 'Change Password',
        description: 'Opens the AppleVis website in Safari so you can update your password.',
        example: 'Tap this if you have forgotten your password or want to make it more secure. Changes on the website apply immediately when you next sign in.',
        type: 'link',
        status: 'live',
      },
      {
        id: 'deleteAccount',
        label: 'Delete Account',
        description: 'Permanently deletes your AppleVis account and all associated data from the server.',
        example: 'This removes your profile, posts, and forum history from applevis.com. This action cannot be undone. Your locally saved items on this device are deleted separately via Saved & Sync.',
        type: 'action',
        status: 'live',
        destructive: true,
      },
    ],
  },

  // ── 2. Appearance ─────────────────────────────────────────────────────────────
  {
    id: 'appearance',
    title: 'Appearance',
    description: 'Theme, card density, and how the app looks.',
    icon: 'color-palette-outline',
    items: [
      {
        id: 'theme',
        label: 'Theme',
        description: 'Choose the colour scheme for the entire app. System follows your iOS Light or Dark Mode setting automatically. Thirteen themes are available across Standard, AppleVis, and Accessibility groups.',
        example: 'Mouse Dark gives warm charcoal backgrounds with golden accents. High Contrast Light uses pure white and black for maximum legibility. Nebula uses deep indigo and lavender for a calm evening look.',
        type: 'nav',
        status: 'live',
        route: '/onboarding/theme',
      },
      {
        id: 'cardDensity',
        label: 'Card Density',
        description: 'Controls how much padding surrounds each content card. Comfortable has more breathing room; Compact fits more items on screen at once.',
        example: 'Comfortable is the default — cards have generous padding and spacing. Compact reduces that padding so you can see more topics before scrolling, useful on smaller screens.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'darkMode',
        label: 'Dark Mode (iOS Setting)',
        description: 'Dark Mode is controlled by iOS Settings. When your Theme is set to System, AppleVis follows your device automatically.',
        example: 'To change Dark Mode, go to iPhone Settings → Display & Brightness → Light or Dark. AppleVis updates instantly.',
        type: 'info',
        status: 'ios',
      },
    ],
  },

  // ── 3. Accessibility ──────────────────────────────────────────────────────────
  {
    id: 'accessibility',
    title: 'Accessibility',
    description: 'VoiceOver, announcement detail, motion, contrast, and system accessibility integration.',
    icon: 'accessibility-outline',
    items: [
      {
        id: 'announcementLevel',
        label: 'VoiceOver Detail Level',
        description: 'Controls how much information VoiceOver reads when it lands on a forum topic, app listing, podcast episode, or resource card.',
        example: 'Simple reads just the title: "iOS 18 Tips". Normal adds key status: "iOS 18 Tips. Unread. 14 replies." All (the default) includes everything: "iOS 18 Tips. Unread. 14 replies. Following. Saved. Posted by JaneD, 2 days ago."',
        type: 'picker',
        status: 'live',
        route: '/onboarding/announcement',
      },
      {
        id: 'focusRestoration',
        label: 'Focus Restoration',
        description: 'After loading new content, VoiceOver focus moves to the first item automatically so you can start reading straight away without swiping past the header.',
        example: 'You pull to refresh the Forums tab. When the new topics load, VoiceOver announces "Forums refreshed" and jumps to the first topic — you do not need to swipe back from the top.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'accessibilityEscape',
        label: 'Two-Finger Scrub to Go Back',
        description: 'Draw a Z shape with two fingers to go back on any screen — the standard VoiceOver escape gesture. This is always on.',
        example: 'On a settings detail screen, scrub a Z with two fingers and you return to the main Settings list — same as tapping Back in a sighted interface.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'customActions',
        label: 'Custom Actions Rotor',
        description: 'Every content card exposes actions (Save, Follow, Read Aloud, Translate, Share) in the VoiceOver Actions rotor. Rotate two fingers on the screen to access them.',
        example: 'Land on a forum topic with VoiceOver. Rotate the rotor to Actions. Swipe down to cycle through: Open, Save Topic, Follow Topic, Read Aloud, Translate, Summarise, Share.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'reduceMotion',
        label: 'Reduce Motion (iOS Setting)',
        description: 'When Reduce Motion is enabled in iOS Settings, all animations in AppleVis are shortened or removed automatically.',
        example: 'To enable, go to iPhone Settings → Accessibility → Motion → Reduce Motion. The app loading bar, card press animations, and theme transitions all simplify immediately.',
        type: 'info',
        status: 'ios',
      },
      {
        id: 'boldText',
        label: 'Bold Text (iOS Setting)',
        description: 'When Bold Text is enabled in iOS Settings, all text in AppleVis becomes bolder automatically.',
        example: 'iPhone Settings → Accessibility → Display & Text Size → Bold Text. Applies instantly to every label in the app.',
        type: 'info',
        status: 'ios',
      },
      {
        id: 'dynamicType',
        label: 'Larger Text / Dynamic Type (iOS Setting)',
        description: 'When you increase your text size in iOS Settings, all text in AppleVis scales up automatically. No separate app setting needed.',
        example: 'iPhone Settings → Accessibility → Display & Text Size → Larger Text. Drag the slider right for larger text. Every headline, body text, and button label in AppleVis grows with it.',
        type: 'info',
        status: 'ios',
      },
      {
        id: 'increaseContrast',
        label: 'Increase Contrast (iOS Setting)',
        description: 'When Increase Contrast is active, AppleVis automatically suggests the High Contrast theme on launch. You can also choose it manually from the Theme picker.',
        example: 'iPhone Settings → Accessibility → Display & Text Size → Increase Contrast. On next launch, AppleVis offers to switch to High Contrast Light or High Contrast Dark.',
        type: 'info',
        status: 'ios',
      },
    ],
  },

  // ── 4. Notifications ──────────────────────────────────────────────────────────
  {
    id: 'notifications',
    title: 'Notifications',
    description: 'Which alerts you receive, how they sound, and when.',
    icon: 'notifications-outline',
    items: [
      {
        id: 'notifForumReplies',
        label: 'Forum Replies',
        description: 'Get notified when someone replies directly to one of your forum posts.',
        example: 'You post a question in the Forums tab. Twenty minutes later someone answers — you get a notification with a Reply button that takes you straight back to the thread.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifMentions',
        label: 'Mentions',
        description: 'Get notified when another member @-mentions your username in a post.',
        example: 'Another member writes "@JaneD I think you might find this useful" — you receive a notification so you can respond.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifNewTopics',
        label: 'New Topics',
        description: 'Get notified when new forum discussions are started.',
        example: 'Someone opens a new thread: "iOS 19 Beta — VoiceOver Findings" — you receive an alert so you can jump in early.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifFollowedTopics',
        label: 'Followed Topic Activity',
        description: 'Get notified when new replies appear in topics you are following.',
        example: 'You followed "Best VoiceOver apps of 2026". When a new reply is added, you get a notification — even if the reply is not directed at you.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifNewEpisodes',
        label: 'New Podcast Episodes',
        description: 'Get notified when a new AppleVis podcast episode is published.',
        example: 'A new episode drops every week. When it appears, you receive a notification with a Play button — tap it and playback begins without opening the app.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifAppUpdates',
        label: 'App Updates & New Listings',
        description: 'Get notified when an app in the AppleVis directory is updated or a new app listing is added.',
        example: 'A major app like Be My Eyes releases an accessibility update. AppleVis publishes a review of the changes and you get notified.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifNewResources',
        label: 'New Resources & Guides',
        description: 'Get notified when new articles, tutorials, or guides are published on AppleVis.',
        example: '"Complete Guide to VoiceOver Gestures in iOS 19" is published — you receive an alert with a Read button.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifAnnouncements',
        label: 'AppleVis Announcements',
        description: 'Important news and updates from the AppleVis team — new features, community events, or policy changes.',
        example: 'The AppleVis team announces a new podcast series. This is the notification type for that kind of site-wide news.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'notifSound',
        label: 'Alert Sound',
        description: 'The sound played when an AppleVis notification arrives. Preview each option by selecting it.',
        example: 'Mouse Squeak is the AppleVis signature sound — soft and distinctive. Apple Crunch is crisp. System Default uses your iPhone\'s standard notification tone.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'notifBadge',
        label: 'Badge Count',
        description: 'Shows a number on the AppleVis icon on your Home Screen indicating how many unread notifications you have.',
        example: 'If you have three new forum replies and one new episode, the app icon shows "4". Tap the app and the badge clears.',
        type: 'toggle',
        status: 'live',
      },
    ],
  },

  // ── 5. Podcasts ───────────────────────────────────────────────────────────────
  {
    id: 'podcasts',
    title: 'Podcasts',
    description: 'Default playback speed, skip times, auto-play, sleep timer, EQ, and download behaviour.',
    icon: 'radio-outline',
    items: [
      {
        id: 'podcastSpeed',
        label: 'Default Playback Speed',
        description: 'The speed at which every episode starts playing. You can change speed per-session in the player.',
        example: '1.0× is normal speed. 1.25× or 1.5× is popular for regular listeners — speech is faster but still clear. 0.75× slows things down if you find the hosts speak quickly.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'podcastSkipBack',
        label: 'Skip Back Time',
        description: 'How many seconds the skip-back button rewinds. Useful when you miss something.',
        example: 'Default is 10 seconds. Tap skip-back once in the player and you hear the last 10 seconds again. Set to 30 seconds if you often need to rewind a full thought.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'podcastSkipForward',
        label: 'Skip Forward Time',
        description: 'How many seconds the skip-forward button jumps ahead.',
        example: 'Default is 30 seconds — useful for skipping sponsor reads. Set to 45 or 60 seconds for longer sponsorships.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'podcastAutoPlay',
        label: 'Auto-Play Next Episode',
        description: 'When an episode finishes, automatically start the next one in your queue.',
        example: 'You are listening to a three-part series. When Part 1 finishes, Part 2 begins immediately without any action from you.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'podcastSleepTimer',
        label: 'Default Sleep Timer',
        description: 'Automatically pause playback after a set time. Great for listening at bedtime.',
        example: 'Set to 30 minutes: playback pauses after half an hour regardless of where you are in the episode. Your position is saved so you can resume the next morning.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'podcastVoiceBoost',
        label: 'Voice Enhancement',
        description: 'Boosts the speech frequencies of podcast audio, making voices clearer without increasing overall volume.',
        example: 'Useful if podcast hosts have quiet voices or if you are listening in a noisy environment. Turn on and the dialogue immediately sounds more forward and distinct.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'podcastEQ',
        label: 'EQ Preset',
        description: 'Adjusts the audio equaliser to suit different content or headphones.',
        example: 'Flat keeps audio as recorded (default). Speech boosts mid-range for clarity in talk shows. Bass Boost adds warmth — good with over-ear headphones. Treble Boost adds airiness — good with earbuds.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'podcastAutoDownload',
        label: 'Auto-Download New Episodes',
        description: 'Automatically downloads new episodes to your device so they are available offline.',
        example: 'Set to Wi-Fi Only: whenever a new episode is published and your phone is on Wi-Fi, it downloads in the background. Open the Podcasts tab and the episode is already there, ready to play without buffering.',
        type: 'picker',
        status: 'live',
      },
      {
        id: 'podcastAutoDelete',
        label: 'Auto-Delete Played Episodes',
        description: 'Automatically removes downloaded episodes from your device after you finish them.',
        example: 'Set to After 1 Week: episodes you have fully listened to are deleted seven days later, keeping your storage usage low without you having to manage files.',
        type: 'picker',
        status: 'live',
      },
    ],
  },

  // ── 6. Saved & Sync ───────────────────────────────────────────────────────────
  {
    id: 'savedSync',
    title: 'Saved & Sync',
    description: 'iCloud sync, reading position, podcast queue, and your saved collections.',
    icon: 'cloud-outline',
    items: [
      {
        id: 'icloudSync',
        label: 'iCloud Sync',
        description: 'Syncs your saved items, followed topics, reading positions, and podcast queue across all your Apple devices signed in to the same Apple ID.',
        example: 'Save a forum topic on your iPhone. Open AppleVis on your iPad — the saved topic appears there too. Your podcast position is also synced, so you can pick up exactly where you left off.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'readingPosition',
        label: 'Reading Position Sync',
        description: 'Remembers which topics you have read so the Unread and Since Last Visit filters stay accurate across all your devices.',
        example: 'You read 10 forum topics on your iPhone. Open AppleVis on your Mac — those same topics are already marked as read and do not appear in Unread.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'podcastPositionSync',
        label: 'Podcast Position Sync',
        description: 'Saves and syncs your playback position so you can resume any episode on any device.',
        example: 'You listen to 20 minutes of an episode on your iPhone. Open AppleVis on your iPad and hit Play — it resumes from exactly 20 minutes in.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'queueSync',
        label: 'Queue Sync',
        description: 'Your podcast play queue is saved and synced across devices.',
        example: 'You add three episodes to your queue on iPhone before heading out. Later on iPad, the same three episodes are queued and ready.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'savedTopics',
        label: 'Saved Topics',
        description: 'Forum topics you have saved for later reading. Tap the Forums tab and switch to the Saved filter to see them.',
        example: 'You find a long how-to thread but do not have time to read it now. Tap Save Topic — it appears in your Saved list, synced to iCloud, until you remove it.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'savedApps',
        label: 'Saved Apps',
        description: 'App listings you have saved. Access them from the Apps tab.',
        example: 'You find a promising accessibility app but want to research it further. Save it — it stays in your list, synced across devices, ready when you are.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'savedResources',
        label: 'Saved Resources',
        description: 'Guides, tutorials, and articles you have saved for later.',
        example: 'A comprehensive VoiceOver guide appears in Resources. Save it — find it again quickly any time by going to Resources and switching to the Saved filter.',
        type: 'info',
        status: 'live',
      },
    ],
  },

  // ── 7. Intelligence & Siri ────────────────────────────────────────────────────
  {
    id: 'intelligence',
    title: 'Intelligence & Siri',
    description: 'On-device AI features, Siri voice commands, Spotlight search, widgets, and shortcuts.',
    icon: 'sparkles-outline',
    items: [
      {
        id: 'readAloud',
        label: 'Read Aloud',
        description: 'Reads the title and description of any content card aloud using your device\'s text-to-speech voice. Works without VoiceOver and without internet. Available on every forum topic, app, resource, and podcast episode.',
        example: 'In the VoiceOver actions rotor, swipe to "Read Aloud" on a forum topic. The device voice reads the title and preview text. Useful for hands-free browsing while doing something else.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'translate',
        label: 'Translate',
        description: 'Opens the iOS Translate sheet with the content pre-filled. Any language iOS supports can be translated — no extra setup needed.',
        example: 'A forum post appears to be in Spanish. Tap Translate in the actions rotor — the iOS Translate app opens with the text ready. Choose your target language and read the translation.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'nonEnglishDetection',
        label: 'Non-English Text Detection',
        description: 'When you type or paste non-English text in the search bar or compose screen, a banner appears offering to translate it before you search or post.',
        example: 'You paste a Japanese phrase into the search bar. A banner appears: "This looks like Japanese — translate before searching?" Tap Translate and your query becomes English.',
        type: 'toggle',
        status: 'live',
      },
      {
        id: 'summarise',
        label: 'Summarise',
        description: 'Condenses long forum threads and resource articles to 2–3 sentences using Apple\'s on-device Foundation Models. Requires iOS 18.2 or later and Apple Intelligence to be enabled on your device.',
        example: 'A forum thread has 40 replies. Tap Summarise — within seconds you get: "Most replies recommend enabling VoiceOver Quick Nav. Three users note issues with third-party keyboard compatibility. The thread was resolved." Coming when the native module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'simplify',
        label: 'Simplify',
        description: 'Rewrites technical content in plain, simple language using Foundation Models. Useful for complex accessibility discussions.',
        example: 'A resource article describes ARIA roles and VoiceOver interaction modes in developer terms. Tap Simplify — you get a plain-English version anyone can understand. Coming when the native module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'consensus',
        label: 'Accessibility Consensus',
        description: 'Aggregates multiple app reviews into a single clear sentence: "Most reviewers say this app works well with VoiceOver, though some note issues with the settings screen."',
        example: 'An app has 12 reviews. Tap Accessibility Consensus and get an instant overview without reading all 12. Coming when the native module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'siriForums',
        label: 'Say "Open AppleVis Forums"',
        description: 'Ask Siri to open specific sections of the app by voice. Requires the Siri App Intents native module.',
        example: 'Lock screen, then say "Hey Siri, open AppleVis Forums" — the app opens directly on the Forums tab. Coming when the native Siri App Intents module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'siriPodcast',
        label: 'Say "Play the Latest AppleVis Podcast"',
        description: 'Ask Siri to play the most recent podcast episode hands-free.',
        example: '"Hey Siri, play the latest AppleVis podcast." Playback begins immediately even with the phone in your pocket. Coming when the native module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'liveActivities',
        label: 'Live Activities & Dynamic Island',
        description: 'While a podcast is playing, a Live Activity shows playback progress on your Lock Screen and in the Dynamic Island on iPhone 14 Pro and later.',
        example: 'You start an episode, lock your phone, and glance at the screen — the episode title, progress bar, and pause button appear without unlocking. Coming when the ActivityKit native module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'widgets',
        label: 'Home Screen Widgets',
        description: 'Add AppleVis widgets to your Home Screen or Lock Screen showing unread topic count, the latest podcast episode, or your "what\'s new" digest.',
        example: 'A small widget on your Home Screen shows "12 unread topics" — tap it to open the Forums tab filtered to Unread. Coming when the WidgetKit native module is built.',
        type: 'info',
        status: 'coming',
      },
      {
        id: 'spotlight',
        label: 'Spotlight Search',
        description: 'Forum topics, podcast episodes, and app listings appear in the iOS system Search (swipe down from the Home Screen) so you can find AppleVis content without opening the app.',
        example: 'Swipe down from your Home Screen and type "VoiceOver tips" — AppleVis forum topics matching that phrase appear in results alongside web results. Coming when the CoreSpotlight native module is built.',
        type: 'info',
        status: 'coming',
      },
    ],
  },

  // ── 8. Privacy ────────────────────────────────────────────────────────────────
  {
    id: 'privacy',
    title: 'Privacy',
    description: 'What data AppleVis stores, how it is used, and your controls over it.',
    icon: 'shield-checkmark-outline',
    items: [
      {
        id: 'dataCollected',
        label: 'What Data We Collect',
        description: 'AppleVis collects your email address and username for your account, and a device push token to send you notifications. No tracking, no advertising data, no third-party analytics.',
        example: 'Your saved items and reading positions are stored in your personal iCloud account — AppleVis never sees them. Your push token is only used to send the notification types you have enabled.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'icloudStorage',
        label: 'iCloud Storage',
        description: 'Saved items, reading positions, and preferences are stored in your private iCloud account using Apple\'s CloudKit. Apple\'s privacy practices apply.',
        example: 'Your saved forum topics live in your iCloud under AppleVis\'s container — only your devices signed in to your Apple ID can access them.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'keychainStorage',
        label: 'Keychain (Sign-In)',
        description: 'Your sign-in session token is stored in the iOS Keychain — Apple\'s encrypted, hardware-protected credential store.',
        example: 'Your password is never stored on the device. Only a session token is kept, encrypted by the Secure Enclave. Even if someone extracts your phone\'s storage, they cannot read your credentials.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'onDeviceAI',
        label: 'On-Device AI Processing',
        description: 'All AI features (Summarise, Simplify, Image Descriptions) use Apple\'s Foundation Models which run entirely on your device. No content is sent to any server for AI processing.',
        example: 'When you tap Summarise on a forum post, the text is processed on your iPhone by Apple\'s on-device model. It never leaves your device.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'privacyPolicy',
        label: 'Privacy Policy',
        description: 'Read the full AppleVis privacy policy on the website.',
        example: 'Tap to open applevis.com/privacy in Safari.',
        type: 'link',
        status: 'live',
      },
      {
        id: 'clearLocalData',
        label: 'Clear All Local Data',
        description: 'Removes all locally stored data from this device: saved items, cached content, reading positions, preferences, and your sign-in session. Does not delete your applevis.com account.',
        example: 'Use this if you are giving away your phone or if you want to start fresh. Your saved items in iCloud are preserved — they will re-sync when you sign back in.',
        type: 'action',
        status: 'live',
        destructive: true,
      },
    ],
  },

  // ── 9. Help ───────────────────────────────────────────────────────────────────
  {
    id: 'help',
    title: 'Help & Support',
    description: 'User guide, VoiceOver tutorials, FAQ, posting guidelines, and contact.',
    icon: 'help-circle-outline',
    items: [
      { id: 'helpGettingStarted', label: 'Getting Started',          description: 'Your first steps with AppleVis — navigating the five tabs, signing in, and the key features at a glance.',         example: 'Start here if this is your first time using AppleVis.',                               type: 'nav', status: 'live' },
      { id: 'helpVoiceOver',      label: 'VoiceOver User Guide',     description: 'A complete guide for blind and low-vision users: gestures, the rotor, custom actions, magic tap, and tips.',       example: 'Includes step-by-step tutorials for every major feature.',                           type: 'nav', status: 'live' },
      { id: 'helpForums',         label: 'Forums Guide',             description: 'How to browse topics, use the filters, follow discussions, post replies, and manage notifications.',                 example: 'Covers Since Last Visit, Unread, Following, and Saved filters.',                      type: 'nav', status: 'live' },
      { id: 'helpApps',           label: 'Apps Directory Guide',     description: 'Finding apps, reading accessibility reviews, understanding the Accessibility Consensus, and saving app listings.',   example: 'Explains what each section of an app review means.',                                  type: 'nav', status: 'live' },
      { id: 'helpPodcasts',       label: 'Podcast Player Guide',     description: 'Playing episodes, controlling the queue, chapters, speed, sleep timer, skip times, and background playback.',        example: 'Includes VoiceOver-specific playback tips.',                                          type: 'nav', status: 'live' },
      { id: 'helpResources',      label: 'Resources Guide',          description: 'What types of content appear in Resources, how to filter by kind, save articles, and share them.',                   example: 'Guides, tutorials, how-to articles, events, and developer resources.',                 type: 'nav', status: 'live' },
      { id: 'helpIntelligence',   label: 'Apple Intelligence Guide', description: 'Every AI feature in the app — what works now, what is coming, and how to use each one.',                            example: 'Covers Read Aloud, Translate, Summarise, Siri commands, and Spotlight.',              type: 'nav', status: 'live' },
      { id: 'helpFAQ',            label: 'Frequently Asked Questions', description: 'Answers to the 30 most common questions from AppleVis users.',                                                    example: '"Why can\'t I post?" "How do I sync my saved items?" "Where is the podcast queue?"',  type: 'nav', status: 'live' },
      { id: 'helpGuidelines',     label: 'Posting Guidelines',       description: 'The full AppleVis community guidelines — what is and is not allowed in the forums.',                                 example: 'Read before posting to understand the community standards.',                           type: 'nav', status: 'live' },
      { id: 'contactAppleVis',    label: 'Contact AppleVis',         description: 'Reach the AppleVis team directly via the website contact form.',                                                     example: 'For account issues, accessibility concerns, or general questions.',                    type: 'link', status: 'live' },
      { id: 'reportBug',          label: 'Report a Bug',             description: 'Tell us about something that is not working correctly in the app.',                                                  example: 'Include what you were doing, what you expected, and what happened instead.',           type: 'link', status: 'live' },
      { id: 'sendFeedback',       label: 'Send Feedback',            description: 'Suggest a feature, share your experience, or tell us what you love.',                                                example: 'All feedback is read by the team.',                                                   type: 'link', status: 'live' },
    ],
  },

  // ── 10. About ─────────────────────────────────────────────────────────────────
  {
    id: 'about',
    title: 'About AppleVis',
    description: 'Version, credits, licences, and what\'s new.',
    icon: 'information-circle-outline',
    items: [
      {
        id: 'version',
        label: 'Version',
        description: 'The current version of the AppleVis app installed on this device.',
        example: 'Version 2026.0.1 — beta series. 2026.0.x = beta builds; 2026.1.x = public release.',
        type: 'info',
        status: 'live',
      },
      {
        id: 'whatsNew',
        label: "What's New",
        description: 'A summary of what was added or improved in the current version.',
        example: 'Lists features added in this release: new themes, the onboarding wizard, expanded notifications, Help centre, podcast defaults.',
        type: 'nav',
        status: 'live',
      },
      {
        id: 'credits',
        label: 'Credits',
        description: 'The people and contributors behind AppleVis.',
        example: 'The AppleVis community, the editorial team, and the developers who built the app.',
        type: 'nav',
        status: 'live',
      },
      {
        id: 'privacyPolicyAbout',
        label: 'Privacy Policy',
        description: 'The full AppleVis privacy policy.',
        example: 'Opens applevis.com/privacy in Safari.',
        type: 'link',
        status: 'live',
      },
      {
        id: 'termsOfUse',
        label: 'Terms of Use',
        description: 'The terms governing use of the AppleVis website and app.',
        example: 'Opens applevis.com/terms in Safari.',
        type: 'link',
        status: 'live',
      },
      {
        id: 'openSource',
        label: 'Open Source Licences',
        description: 'Acknowledges the open source libraries used in the app and their licences.',
        example: 'Lists Expo, React Native, i18next, react-native-reanimated, and other dependencies with their licence types.',
        type: 'nav',
        status: 'live',
      },
    ],
  },
];

/** Quick lookup by section id */
export function findSection(id: string): SettingsSection | undefined {
  return SETTINGS_SECTIONS.find((s) => s.id === id);
}

/** Quick lookup by item id across all sections */
export function findSettingItem(itemId: string): SettingItem | undefined {
  for (const section of SETTINGS_SECTIONS) {
    const item = section.items.find((i) => i.id === itemId);
    if (item) return item;
  }
  return undefined;
}
