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

export const HELP_SECTIONS: HelpSection[] = [
  {
    id: 'start',
    title: 'Start Here',
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
            'Browse Discover for forums, blogs, guides, podcasts, app directory content, and site search.',
            'Use For You to find saved items, following, downloads, queue, and personal activity.',
            'Play podcasts with background audio, queue, chapters, speed controls, Live Activities, Dynamic Island, and CarPlay.',
            'Post topics, replies, comments, app reviews, and app submissions when signed in.',
          ] },
          { type: 'note', text: 'Most browsing works without signing in. Posting, following, personalized notifications, and some account tools require an AppleVis account.' },
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
          { type: 'body', text: 'Profile contains account tools, support information, legal links, credits, and app support email. Settings controls appearance, accessibility, notifications, podcasts, privacy, storage, sync, and smart features.' },
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
        content: [
          { type: 'steps', items: [
            'Open Home and listen to the welcome message.',
            'Review the What is New area if you want to catch up.',
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
        summary: 'Play episodes, use Dynamic Island, and build a queue.',
        content: [
          { type: 'steps', items: [
            'Open Podcasts.',
            'Choose an episode and press Play.',
            'Use the mini player, full player, Lock Screen, Dynamic Island, Control Center, AirPods, or CarPlay to control playback.',
            'Use Add to Queue or Play Next to build a listening list.',
            'Use Downloads when you want offline listening.',
            'Use Settings > Podcasts to adjust speed, skip times, sleep timer, voice boost, trim silence, and auto-delete.',
          ] },
          { type: 'note', text: 'When a podcast is playing, Live Activities and Dynamic Island show the episode title, progress, playback state, and chapter when available.' },
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
            'To submit a new bug you have found, return to Discover, scroll to Contribute, and tap Submit a Bug Report.',
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
        ],
      },
      {
        id: 'accessibility-braille',
        title: 'Braille Display Tips',
        summary: 'How braille users can move efficiently through Help and content.',
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
          { type: 'body', text: 'The Bug Tracker brings the AppleVis community bug database into the app. You can browse active and resolved accessibility bugs reported by the community, read full details, and link directly to Apple Feedback Assistant to help get issues fixed.' },
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
          { type: 'tip', text: 'VoiceOver users: the heading "Bug Details" divider is announced with accessibilityRole="header" so you can jump to it with the headings rotor.' },
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
          { type: 'body', text: 'AppleVis is a Be My Eyes company. The Be My Eyes section in Discover gives you quick access to three free visual assistance services without having to search for them separately.' },
          { type: 'heading', text: 'Available services' },
          { type: 'bullets', items: [
            'Call a Volunteer: connects you by live video with a sighted volunteer who can see through your phone camera, available 24 hours a day in 185 languages.',
            'Be My AI: an AI-powered assistant that describes images, reads text, and answers visual questions in 36 languages.',
            'Service Directory: a directory of accessible customer service channels at hundreds of companies and government departments.',
          ] },
          { type: 'steps', items: [
            'Open Discover.',
            'Scroll to the Be My Eyes section.',
            'Tap the service you want — Call a Volunteer, Be My AI, or Service Directory.',
            'The Be My Eyes app opens at the selected feature. If Be My Eyes is not installed, the App Store page opens instead.',
          ] },
          { type: 'note', text: 'All three services are free to use. Be My Eyes is a separate app from AppleVis. Tapping any of these links will leave the AppleVis app and open Be My Eyes.' },
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
        summary: 'How to report a new accessibility bug to the AppleVis community.',
        content: [
          { type: 'body', text: 'If you find an accessibility bug that is not already in the Bug Tracker, you can submit it to AppleVis. Community bug reports go through an editorial review before being published.' },
          { type: 'steps', items: [
            'Open Discover.',
            'Scroll to the Contribute section.',
            'Tap Submit a Bug Report.',
            'The community bug report form opens in your browser.',
            'Fill in the bug title, platform, iOS or macOS version, steps to reproduce, severity, and any available workaround.',
            'Include your Apple Feedback ID if you have already filed the bug with Apple.',
            'Submit the form. The AppleVis team will review and publish your report.',
          ] },
          { type: 'tip', text: 'Before submitting, search the Bug Tracker to check whether the bug has already been reported. You can also add your voice to an existing report by tapping Report to Apple on its detail page.' },
          { type: 'bullets', items: [
            'Severity — choose High if the bug makes a feature completely unusable for accessibility users, Medium if a workaround exists, or Low for minor cosmetic or infrequent issues.',
            'Steps to reproduce — be as specific as possible: include the app version, device model, and the exact sequence of actions that triggers the bug every time.',
            'Workaround — describe any partial workaround even if it is imperfect, so other users can reduce the impact while waiting for a fix.',
          ] },
          { type: 'note', text: 'Bug reports are moderated by the AppleVis team. Duplicate reports, vague descriptions, or reports that cannot be reproduced may not be published.' },
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
        summary: 'Playback, queue, chapters, downloads, Dynamic Island, CarPlay, and settings.',
        content: [
          { type: 'bullets', items: [
            'Play, pause, seek, skip, and change speed from the player.',
            'Use queue and Play Next to control what plays after the current episode.',
            'Download episodes for offline listening.',
            'Use chapters when available.',
            'Use Live Activities and Dynamic Island on supported iPhone models.',
            'Use Lock Screen, Control Center, AirPods, and CarPlay controls.',
          ] },
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
        id: 'settings-privacy-storage',
        title: 'Privacy, Sync, and Storage',
        summary: 'Control data sync, local storage, cache, downloads, and privacy.',
        content: [
          { type: 'bullets', items: [
            'Saved and Sync controls what goes through iCloud.',
            'Privacy explains account data, Keychain, iCloud, smart features, and local data.',
            'Storage and Cache manages downloaded audio, cached content, cache retention, and cleanup.',
            'Clear Local Data signs out and removes AppleVis data stored on this device without deleting your applevis.com account.',
          ] },
        ],
      },
      {
        id: 'settings-support',
        title: 'Profile and App Support',
        summary: 'Get app support and include useful device information.',
        content: [
          { type: 'body', text: 'Profile includes Copy Support Information and Contact App Support. Contact App Support opens Mail addressed to support@applevis.com with a subject and support details already filled in.' },
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
            'Read Aloud reads content using device speech.',
            'Summarise condenses long posts, discussions, show notes, and app information.',
            'Simplify rewrites complex text in plain language.',
            'Accessibility Consensus summarizes community app accessibility feedback.',
            'Friendly Rewrite helps polish posts before submitting.',
            'Translate to English helps with drafts and search queries.',
          ] },
        ],
      },
      {
        id: 'smart-siri-widgets',
        title: 'Siri, Widgets, Spotlight, and Focus',
        summary: 'Use AppleVis from system features outside the app.',
        content: [
          { type: 'bullets', items: [
            'Siri phrases can open AppleVis sections, play the latest podcast, continue playback, search apps, or show unread activity.',
            'Widgets can show unread counts, latest podcast information, saved counts, and what is new.',
            'Spotlight can find AppleVis topics, apps, podcasts, and resources from iOS Search.',
            'Focus Filters can control which AppleVis notification categories break through a Focus mode.',
          ] },
        ],
      },
      {
        id: 'smart-share',
        title: 'Share Into AppleVis',
        summary: 'Use the iOS Share Sheet to send useful content into AppleVis.',
        content: [
          { type: 'bullets', items: [
            'Share an App Store link to look up or submit an app.',
            'Share a web page to save, discuss, or turn it into a resource workflow.',
            'Share text to start a draft or discussion.',
          ] },
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
        content: [
          { type: 'bullets', items: [
            'If playback seems stuck, pause and play again, or open the episode page and press Play.',
            'If search results are poor, try fewer words or translate a non-English query to English.',
            'If the app feels too bright, too dense, or too animated, review Appearance and iOS Display & Text Size.',
            'If storage grows, use Settings > Storage and Cache.',
          ] },
        ],
      },
      {
        id: 'trouble-contact',
        title: 'Contact App Support',
        summary: 'Send bugs, feedback, suggestions, and recommendations.',
        content: [
          { type: 'steps', items: [
            'Open Profile.',
            'Choose Contact App Support.',
            'Mail opens addressed to support@applevis.com.',
            'Describe the bug, suggestion, recommendation, or feedback.',
            'Keep the included support information in the message when reporting a bug.',
          ] },
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
