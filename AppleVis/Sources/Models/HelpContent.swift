import Foundation

// Ported from src/data/helpContent.ts — the RN reference client's offline
// help center. Full 1:1 transcription: 10 sections, 51 articles. The
// block-based content model matches theirs exactly.

enum HelpContentBlock: Identifiable, Hashable {
    case heading(String)
    case body(String)
    case bullets([String])
    case steps([String])
    case tip(String)
    case note(String)
    case warning(String)
    case faq(question: String, answer: String)

    var id: String {
        switch self {
        case .heading(let t): return "h-\(t)"
        case .body(let t): return "b-\(t)"
        case .bullets(let items): return "bl-\(items.joined())"
        case .steps(let items): return "s-\(items.joined())"
        case .tip(let t): return "tip-\(t)"
        case .note(let t): return "note-\(t)"
        case .warning(let t): return "warn-\(t)"
        case .faq(let q, _): return "faq-\(q)"
        }
    }
}

/// What kind of help content this is — lets Help surface the right icon and
/// badge. Matches RN's `HelpContentType` / `HELP_CONTENT_TYPE_META`.
enum HelpContentType: String, Hashable {
    case guide, quickStart, tutorial, faq, troubleshooting, spotlight, accessibilityLesson, whatsNew, releaseNote

    var label: String {
        switch self {
        case .guide: return "Guide"
        case .quickStart: return "Quick Start"
        case .tutorial: return "Tutorial"
        case .faq: return "FAQ"
        case .troubleshooting: return "Troubleshooting"
        case .spotlight: return "Feature Spotlight"
        case .accessibilityLesson: return "Accessibility Lesson"
        case .whatsNew: return "What's New"
        case .releaseNote: return "Release Note"
        }
    }

    /// SF Symbol equivalents of RN's Ionicons.
    var icon: String {
        switch self {
        case .guide: return "book"
        case .quickStart: return "bolt"
        case .tutorial: return "figure.walk"
        case .faq: return "questionmark.circle"
        case .troubleshooting: return "wrench.and.screwdriver"
        case .spotlight: return "sparkles"
        case .accessibilityLesson: return "accessibility"
        case .whatsNew: return "megaphone"
        case .releaseNote: return "doc.text"
        }
    }
}

/// Where a related link goes. RN modelled this as a generic string route;
/// Swift has no generic router, so every route actually used in the RN data
/// (there are only 4) maps to a concrete destination instead.
enum RelatedLinkDestination: Hashable {
    case article(String)
    case guidedExperienceWelcome
    case whatsNew
    case savedSyncSettings
}

struct RelatedLink: Hashable {
    let label: String
    let type: HelpContentType
    let destination: RelatedLinkDestination
}

struct HelpArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let content: [HelpContentBlock]
    var contentType: HelpContentType? = nil
    var relatedLinks: [RelatedLink] = []
}

struct HelpSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let description: String
    let articles: [HelpArticle]
}

enum HelpContent {
    static let sections: [HelpSection] = [
        HelpSection(
            id: "start",
            title: "Getting Started",
            icon: "compass",
            description: "An introduction to AppleVis: the tabs, signing in, and where everything is.",
            articles: [
                HelpArticle(
                    id: "start-what-is-applevis",
                    title: "What AppleVis Is",
                    summary: "A community, app directory, podcast library, forums, and learning hub for blind, DeafBlind, and low vision Apple users.",
                    content: [
                        .body("AppleVis is a community of blind, DeafBlind, low vision, and sighted people who care about accessibility on Apple platforms. This app brings the whole community into one place: discussions, accessibility comments on apps, podcasts, blog posts, guides, and a bug tracker."),
                        .heading("What you can do here"),
                        .bullets([
                            "See what's new since your last visit on Home.",
                            "Browse Forums, the AppleVis Blog, Guides, Podcasts, the App Directory, the Bug Tracker, search, and Be My Eyes in Discover.",
                            "Keep track of saved items, topics you follow, apps you've recommended, your podcast queue, and downloads in For You.",
                            "Listen to podcasts with background audio, a queue, chapters, and speed controls. Playback also works from the Lock Screen and the Dynamic Island.",
                            "Post topics, replies, and comments, submit apps, bugs, blog posts, and podcasts, and message other members. These need you to be signed in.",
                        ]),
                        .note("You can browse almost everything without an account. Posting, following, recommending, messaging other members, and personalized notifications all need you to be signed in to AppleVis."),
                    ],
                    contentType: .guide,
                    relatedLinks: [
                        RelatedLink(label: "Take the Welcome Tour", type: .tutorial, destination: .guidedExperienceWelcome),
                    ]
                ),
                HelpArticle(
                    id: "start-tabs",
                    title: "Main Tabs and Navigation",
                    summary: "How Home, Discover, For You, and Profile fit together.",
                    content: [
                        .heading("Home"),
                        .body("Home is the first screen you see. It shows a welcome, a summary of what's happened since your last visit, and a shortcut back to where you left off. Customize Home, at the top left, lets you choose which content types appear in your feed. Add, at the top right, starts a new forum topic or app entry."),
                        .heading("Discover"),
                        .body("Discover contains the rest of AppleVis: Forums, the AppleVis Blog, Guides, Podcasts, the App Directory, the Bug Tracker, Be My Eyes, RSS Feeds, and search. The ways to contribute to AppleVis are here too."),
                        .heading("For You"),
                        .body("For You only shows what you've chosen to keep. It has five sections: Saved, Following, Recommended, Queue, and Downloads."),
                        .heading("Profile and Settings"),
                        .body("Profile and Settings isn't a separate tab. Use the Profile and Settings button in the toolbar on Home, Discover, or For You."),
                        .body("My Account is where you manage your sign-in. You can edit your profile and bio, change your password or email address, or sign out."),
                        .body("Settings controls how AppleVis looks, sounds, and behaves, including appearance, accessibility, sounds and haptics, notifications, podcasts, privacy, and Apple Intelligence features. Help and Contact AppleVis are also here."),
                        .body("To message another member, open their profile. Private messages aren't sent from your own account screen."),
                    ]
                ),
                HelpArticle(
                    id: "start-sign-in",
                    title: "Signing In",
                    summary: "What signing in lets you do, and how to manage your account from the app.",
                    content: [
                        .steps([
                            "Open Profile.",
                            "Choose Sign in to AppleVis.",
                            "Enter the same username and password you use on applevis.com.",
                            "Once you're signed in, Profile shows your account tools and a link to your public profile.",
                        ]),
                        .heading("What signing in lets you do"),
                        .bullets([
                            "Post forum topics, replies, and comments.",
                            "Follow topics and other content so they appear in For You.",
                            "Recommend apps.",
                            "Send a private message to another member.",
                            "Get notifications about the activity you care about.",
                        ]),
                        .heading("Changing your password or email"),
                        .body("You can update your account without leaving the app. In Profile, choose Change Password or Change Email Address. Each one is a short guided process: confirm your current password, enter the new value, and review it before saving."),
                        .note("The app never stores your password. AppleVis keeps a secure session token in the iOS Keychain instead."),
                    ]
                ),
                HelpArticle(
                    id: "start-faq",
                    title: "Frequently Asked Questions",
                    summary: "Short answers to the questions members ask most.",
                    content: [
                        .faq(question: "How do I search AppleVis?", answer: "Open Discover and use the search field. Type at least 2 characters. Results are grouped into Forum Topics, Apps, Guides, Blogs, Podcasts, and Bug Reports."),
                        .faq(question: "Where are my saved items?", answer: "Open For You and choose Saved."),
                        .faq(question: "What's the difference between Save and Follow?", answer: "Save is a bookmark, so you can find something again. Follow puts it in For You > Following and lets AppleVis notify you when there's new activity."),
                        .faq(question: "What's the difference between Recommend and Save?", answer: "Save is private and only for you. Recommend is a public thumbs-up on an app that tells other members you vouch for it. You can do both. Everything you've recommended is in For You > Recommended."),
                        .faq(question: "How do I download podcast episodes?", answer: "Open the episode and choose Download. Downloaded episodes appear in For You > Downloads for offline listening."),
                        .faq(question: "Can I message another AppleVis member?", answer: "Yes. Open their profile by choosing their name, which works almost anywhere it appears. If they allow messages, you'll see a Contact button. The message is sent through AppleVis, and your email address isn't shared unless they reply. You can turn messages off for yourself in Edit Profile."),
                        .faq(question: "How do I report a comment I think breaks the guidelines?", answer: "Touch and hold the comment, or use the Actions rotor with VoiceOver, and choose Report Comment. A short guided form sends the report to the editorial team."),
                        .faq(question: "How do I change my VoiceOver detail level?", answer: "Open Settings > Accessibility and choose VoiceOver Detail Level. The options are Simple, Normal, and All."),
                    ],
                    contentType: .faq,
                    relatedLinks: [
                        RelatedLink(label: "Using Search", type: .guide, destination: .article("search-overview")),
                        RelatedLink(label: "Submitting a Bug Report", type: .guide, destination: .article("community-submit-bug")),
                    ]
                ),
                HelpArticle(
                    id: "start-whats-new",
                    title: "What's New and Release Notes",
                    summary: "See what changed in the latest AppleVis update.",
                    content: [
                        .body("What's New lists the changes in each AppleVis app update, including new features, improvements, and fixes. It covers the current release and recent ones before it."),
                        .steps([
                            "Open Profile.",
                            "Choose What's New.",
                            "Read the changes in the current version, followed by earlier versions.",
                        ]),
                    ],
                    contentType: .whatsNew,
                    relatedLinks: [
                        RelatedLink(label: "Open What's New", type: .whatsNew, destination: .whatsNew),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "tutorials",
            title: "Tutorials and Walkthroughs",
            icon: "graduationcap",
            description: "Step-by-step lessons for common AppleVis tasks.",
            articles: [
                HelpArticle(
                    id: "tutorial-first-visit",
                    title: "First Visit Checklist",
                    summary: "A simple path through the app for your first visit.",
                    content: [
                        .steps([
                            "Open Home. The welcome is a little different depending on whether you're signed in.",
                            "Read the summary of what's new if you want to catch up.",
                            "Choose Customize Home, at the top left, to pick which content types appear in your feed.",
                            "Open Discover and look through Forums, the Blog, Guides, Podcasts, the App Directory, and the Bug Tracker.",
                            "Open For You to see the Saved, Following, Recommended, Queue, and Downloads sections. They're empty until you add something.",
                            "Open Settings and look through the groups: General, Customisation, Alerts, Content, Data & Privacy, and Storage & Cache.",
                            "Open Profile and sign in when you're ready. You can also use Contact AppleVis if you have a question first.",
                        ]),
                    ],
                    contentType: .quickStart
                ),
                HelpArticle(
                    id: "tutorial-find-content",
                    title: "Find Content in Discover",
                    summary: "Search, browse, filter, and use tags or categories.",
                    content: [
                        .steps([
                            "Open Discover.",
                            "Use Search when you know roughly what you're looking for.",
                            "Open Forums, the Blog, Guides, Podcasts, or the App Directory when you'd rather browse.",
                            "Use the pickers and filters to narrow the list by content type, tag, platform, category, or saved state.",
                            "When you reach the end of a list, more content loads automatically.",
                        ]),
                        .note("With VoiceOver, you can move by headings in areas that are grouped by category or letter. The same headings are shown on screen."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-save-follow",
                    title: "Save, Follow, Recommend, and Mark as Read",
                    summary: "Keep track of what matters to you, and clear the rest when you're done.",
                    content: [
                        .steps([
                            "Find a topic, app, blog post, guide, podcast episode, or anything else you want to keep track of.",
                            "Open its actions. Swipe on it, touch and hold it, or use the Actions rotor with VoiceOver.",
                            "Choose Save to keep it in For You > Saved.",
                            "Choose Follow to be notified about new activity.",
                            "On an app, choose Recommend to give it a public thumbs-up. It appears in For You > Recommended.",
                            "Choose Mark as Read to clear its new-activity badge without opening it.",
                            "On Home, choose Mark All as Read to clear every badge at once.",
                        ]),
                        .tip("The same actions are available on every topic, post, app, and episode, whichever way you open them."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-post",
                    title: "Post a Topic, Reply, or Comment",
                    summary: "Write, polish, translate, and send a community post.",
                    content: [
                        .steps([
                            "Sign in from Profile.",
                            "Open the forum topic, blog post, guide, podcast episode, or app page you want to respond to.",
                            "Choose Reply, Add Comment, or New Topic.",
                            "Write your draft.",
                            "Choose Rewrite if you'd like help with the wording or tone before you post.",
                            "If your draft isn't in English, AppleVis offers to translate it.",
                            "Read any guideline reminder that appears. Most are a friendly note, not a block.",
                            "Submit your post.",
                        ]),
                        .warning("AppleVis posts should be in English. If English isn't your first language, the app can translate your draft before you send it."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-podcast",
                    title: "Play and Queue Podcasts",
                    summary: "Play episodes, build a queue, and control playback from anywhere.",
                    content: [
                        .steps([
                            "Open Podcasts.",
                            "Choose an episode and choose Play.",
                            "Control playback from the mini player at the bottom of any tab, the full player, the Lock Screen, the Dynamic Island, Control Center, or AirPods.",
                            "Use Add to Queue or Play Next to choose what plays next. When an episode ends, the next one in your queue starts automatically.",
                            "Use the next-track control on the Lock Screen or AirPods to skip to the next episode. Use previous-track to go back to the start of the current one.",
                            "Download an episode to listen offline.",
                            "Open Settings > Podcasts to adjust speed, skip intervals, the sleep timer, Voice Boost, Trim Silence, and auto-play.",
                        ]),
                        .note("While a podcast is playing, the Dynamic Island and Lock Screen show the episode title, progress, and playback state on supported iPhone models."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-bug-tracker",
                    title: "Using the Bug Tracker",
                    summary: "Find active bugs, read full reports, and submit your own.",
                    content: [
                        .steps([
                            "Open Discover.",
                            "Go to Bug Tracker and choose iOS / iPadOS Bugs or macOS Bugs.",
                            "Active bugs are shown by default. Choose All Bugs to include ones that have been fixed.",
                            "Browse the list, or type a word in the search field to narrow it down.",
                            "Open a bug report to read the description, steps to reproduce, workaround, version information, and Apple Feedback ID.",
                            "On an active bug, choose Report to Apple to open Feedback Assistant and file your own report. The more reports Apple receives, the more likely a fix.",
                            "Choose Save to keep the report in For You.",
                            "Choose Share to send the report's link to someone.",
                            "To submit a new bug, go to Discover, find Contribute, and choose Submit a Bug Report. A guided form opens in the app.",
                        ]),
                        .tip("Filing your own report in Apple's Feedback Assistant for the same bug helps raise its priority. Include your device model, OS version, and the exact steps to reproduce."),
                        .note("With VoiceOver, each bug report in the list reads its severity, status, first-seen version, and fixed-in version together, so you don't need to swipe through each detail."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-low-vision",
                    title: "Low Vision Setup",
                    summary: "A short setup path for larger text, contrast, motion, and visual comfort.",
                    content: [
                        .steps([
                            "Open Settings > Appearance and choose a theme that's comfortable for you. High Contrast Light and High Contrast Dark give the most contrast.",
                            "Use Card Density to choose Comfortable or Compact spacing, depending on how much you want on screen at once.",
                            "Open iOS Settings > Display & Text Size to adjust text size, Bold Text, Button Shapes, Reduce Transparency, and Increase Contrast.",
                            "Open Settings > Accessibility in AppleVis to see which iOS accessibility settings the app is using.",
                        ]),
                        .tip("Glass and blur effects switch to solid backgrounds when Reduce Transparency or a high-contrast theme is on."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-replay-welcome-tour",
                    title: "Replay the Welcome Tour",
                    summary: "Go through the guided tour of Home, Discover, For You, and Profile & Settings again, one chapter at a time.",
                    content: [
                        .body("The Welcome Tour is an optional walkthrough shown after setup. It has one chapter for each tab, and each chapter is short enough to finish on its own."),
                        .body("You can replay it at any time. It doesn't start again by itself once you've seen it."),
                        .steps([
                            "Open Profile and Settings.",
                            "Choose Replay Welcome Tour.",
                            "The tour starts from the beginning. Use Back to return to a step, or Leave Tour to pause or skip it.",
                        ]),
                        .tip("Leave Tour is on every step. If you pause, a Resume Tour button lets you continue where you left off. At the end of each chapter, an Explore option takes you straight to that screen."),
                    ],
                    contentType: .tutorial,
                    relatedLinks: [
                        RelatedLink(label: "Take the Welcome Tour", type: .tutorial, destination: .guidedExperienceWelcome),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "accessibility",
            title: "Accessibility",
            icon: "accessibility",
            description: "VoiceOver, braille, low vision, Switch Control, Voice Control, keyboard, and visual accessibility.",
            articles: [
                HelpArticle(
                    id: "accessibility-everyone",
                    title: "Accessibility for Everyone",
                    summary: "AppleVis supports many ways of using an iPhone.",
                    content: [
                        .body("AppleVis works with direct touch, VoiceOver, braille displays, Switch Control, Voice Control, larger text sizes, high-contrast themes, Reduce Motion, Reduce Transparency, and hardware keyboards. The people who use it get around in many different ways."),
                        .heading("How instructions are written"),
                        .body("Most Help articles describe the general action first. Extra detail is added only where a particular access method needs it, for example \"With VoiceOver…\" or \"If you have low vision…\"."),
                        .heading("AppleVis's own accessibility controls"),
                        .body("Settings > Accessibility has VoiceOver Detail Level, which controls how much AppleVis reads as you move through forum topics, apps, and podcast episodes."),
                        .body("General settings that apply to everyone are in Settings > General. These include tips, how Home starts, search auto-focus, and how web links open."),
                        .heading("Small visual animations"),
                        .body("A few small animations are only visual. They don't change what VoiceOver, Switch Control, or a braille display reports, and they turn off when Reduce Motion is on."),
                        .bullets([
                            "The Save, Follow, and Recommend icons at the bottom of a topic, app, episode, or post bounce briefly when you use them, along with the confirmation sound.",
                            "Changing the theme, in Settings > Appearance or during setup, fades between the color schemes.",
                            "A \"NEW\" or \"3 NEW\" label appears with a small spring as you scroll to it.",
                        ]),
                    ],
                    contentType: .accessibilityLesson
                ),
                HelpArticle(
                    id: "accessibility-voiceover",
                    title: "VoiceOver Basics",
                    summary: "How to navigate, use actions, and control playback with VoiceOver.",
                    content: [
                        .bullets([
                            "Swipe right or left to move through controls and content.",
                            "Double-tap to activate the item in focus.",
                            "Use headings to move between sections.",
                            "On a content row, set the rotor to Actions and swipe up or down to reach Save, Follow, Share, and, on apps, Recommend. Double-tap to use one. Without VoiceOver, swipe on the row or touch and hold it to reach the same actions.",
                            "Scrub with two fingers to go back.",
                            "Double-tap with two fingers to play or pause podcasts from anywhere in the app.",
                        ]),
                        .note("Most lists move VoiceOver focus to the first useful item once they finish loading."),
                        .body("When you open a topic, post, or anything else with comments, VoiceOver reads a short summary: how many comments there are, and who commented most recently. Each comment starts with its number, like \"Comment 3 of 12\". All of this is spoken in your iPhone's language."),
                        .body("Anything on Home with new comments has a Jump to First New Comment action. It opens the item with VoiceOver on the first comment you haven't seen."),
                        .heading("VoiceOver Detail Level"),
                        .body("Settings > Accessibility > VoiceOver Detail Level controls how much AppleVis reads when you move through forum topics, apps, and podcast episodes."),
                        .bullets([
                            "Simple (Fastest): the title and content type.",
                            "Normal (Recommended): the title, author, and comment count.",
                            "All (Most Detailed): the title, author, comment count, posted date, and last comment time.",
                        ]),
                        .tip("Normal suits most people. Choose All to hear every detail each time, or Simple to move through lists quickly."),
                    ],
                    contentType: .accessibilityLesson
                ),
                HelpArticle(
                    id: "accessibility-braille",
                    title: "Braille Display Tips",
                    summary: "How to move efficiently through Help and content with a braille display.",
                    content: [
                        .bullets([
                            "Use headings to move between sections in Help, Settings, Discover, and longer articles.",
                            "Article titles and summaries are kept short so they fit better on a braille display.",
                            "Each step in a list is its own item.",
                            "When a label is long, look for a shorter heading or action name first, and read the hint only if you need it.",
                        ]),
                    ],
                    contentType: .accessibilityLesson
                ),
                HelpArticle(
                    id: "accessibility-low-vision",
                    title: "Low Vision and Visual Comfort",
                    summary: "Themes, contrast, text size, and motion settings.",
                    content: [
                        .bullets([
                            "Use Appearance to choose System, Light, Dark, or a high-contrast theme.",
                            "Use Card Density, Comfortable or Compact, to control how much fits on screen at once.",
                            "Use Dynamic Type in iOS Settings to make text larger throughout the app.",
                            "Use Reduce Motion to shorten or remove animations.",
                            "Use Reduce Transparency to replace see-through surfaces with solid backgrounds.",
                        ]),
                    ],
                    contentType: .accessibilityLesson
                ),
            ]
        ),
        HelpSection(
            id: "home-discover",
            title: "Home and Discover",
            icon: "safari",
            description: "What's new, search, filters, tags, the app directory, blogs, guides, podcasts, and forums.",
            articles: [
                HelpArticle(
                    id: "home-whats-new",
                    title: "Home and What's New",
                    summary: "How AppleVis welcomes you back and helps you catch up.",
                    content: [
                        .body("When you open AppleVis, Home greets you and returns you to where you left off. The greeting is a little different depending on whether you're signed in."),
                        .body("Near the top, a summary shows how much has happened since your last visit."),
                        .heading("Filtering the feed"),
                        .bullets([
                            "All shows everything your feed is set up to include.",
                            "New shows only what's happened since your last visit.",
                            "Mouse Recap is a weekly or monthly summary of new accessible apps, podcast episodes, popular discussions, guides, and blog posts. You can share it.",
                        ]),
                        .heading("Reading the badges"),
                        .bullets([
                            "NEW means the item itself was posted since your last visit.",
                            "A number, like 3 NEW, counts the comments added since you last opened the item. If you've never opened it, it counts from when it first appeared on Home.",
                            "A new topic that already has replies shows both.",
                            "Counts keep adding up across visits until you open the item or mark it as read.",
                        ]),
                        .heading("Keeping it tidy"),
                        .bullets([
                            "Mark as Read clears an item's new-activity badge without opening it.",
                            "Mark All as Read clears every badge at once.",
                            "Customize Home, at the top left, chooses which content types appear.",
                        ]),
                        .tip("Add, the plus button at the top right, starts a new forum topic or app entry without going to Discover first."),
                        .note("On the anniversary of the day you joined AppleVis, Home shows a short celebration. It appears once a year, around your join date."),
                    ]
                ),
                HelpArticle(
                    id: "discover-overview",
                    title: "Discover Overview",
                    summary: "The central place for browsing AppleVis content.",
                    content: [
                        .bullets([
                            "Forums: community topics and replies.",
                            "AppleVis Blog: official posts and announcements.",
                            "Guides: tutorials, resources, and how-to articles.",
                            "Podcasts: every AppleVis podcast, with filters, tags, a queue, downloads, and playback.",
                            "App Directory: apps by platform (iPhone and iPad, Mac, Apple Watch, or Apple TV) and category, with accessibility comments from members.",
                            "Community Picks: the apps members recommend, newest first or most recommended.",
                            "Bug Tracker: active and resolved accessibility bugs reported by the community.",
                            "Be My Eyes: open Call a Volunteer, Be My AI, or the Service Directory.",
                            "RSS Feeds: copy or share feed links to follow AppleVis outside the app.",
                            "Social links: follow AppleVis on Mastodon, Facebook, or X from the Stay Updated section.",
                            "Search: search all of AppleVis. It can translate a search that isn't in English.",
                            "Contribute: submit a bug, blog post, podcast, or app entry.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "discover-community-picks",
                    title: "Community Picks",
                    summary: "See which apps AppleVis members recommend.",
                    content: [
                        .body("Community Picks shows the apps that AppleVis members recommend. Each app appears once, with how many people recommended it and when it was last recommended."),
                        .heading("Choosing what to see"),
                        .bullets([
                            "Show: Latest lists apps by their newest recommendation. Most Recommended ranks apps by how many people recommend them.",
                            "Period: count recommendations from the past month, 3 months, 6 months, year, or all time.",
                            "Platform: show all apps, or only apps for iPhone and iPad, Mac, Apple Watch, or Apple TV.",
                        ]),
                        .tip("With VoiceOver, swipe up or down on a picker to change it."),
                        .body("Each app has the same actions as it does everywhere else, including Save, Follow, Share, and Recommend. To open Community Picks, go to Discover and find App Directory."),
                    ]
                ),
                HelpArticle(
                    id: "discover-bug-tracker",
                    title: "Bug Tracker",
                    summary: "Browse active and resolved accessibility bugs for iOS/iPadOS and macOS.",
                    content: [
                        .body("The Bug Tracker shows the AppleVis community's list of accessibility bugs. You can browse active and resolved bugs, read the full details, open Apple's Feedback Assistant to file your own report, and submit new bugs with a guided form."),
                        .heading("Opening the Bug Tracker"),
                        .steps([
                            "Open Discover.",
                            "Go to the Bug Tracker section.",
                            "Choose iOS / iPadOS Bugs or macOS Bugs.",
                        ]),
                        .heading("Browsing bugs"),
                        .bullets([
                            "Active shows only bugs that haven't been fixed. All Bugs shows both active and fixed ones.",
                            "Each bug report in the list shows its title, severity (Low, Medium, or High), status (Active or Fixed), the OS version it first appeared in, and the version it was fixed in, if known.",
                            "Each one also shows when the bug was first reported and last updated.",
                            "Use the search field to filter the list by a word.",
                            "When you reach the end, more bug reports load automatically.",
                            "Pull down to refresh the list.",
                        ]),
                        .heading("Reading a bug report"),
                        .steps([
                            "Open a bug report to see its full details.",
                            "Read the description, steps to reproduce, and any known workaround.",
                            "Check Bug Details for the platform, first-seen version, fixed-in version, device, how often it happens, and the Apple Feedback ID.",
                            "On an active bug, use Report to Apple to open Feedback Assistant and file your own report.",
                            "Use Share to send the report's link to someone.",
                            "Use Save to add it to For You > Saved.",
                        ]),
                        .tip("With VoiceOver, Bug Details is a heading, so you can move straight to it with the Headings rotor."),
                        .heading("Submitting a new bug"),
                        .steps([
                            "Go to Discover and find Contribute.",
                            "Choose Submit a Bug Report.",
                            "You need to be signed in. If you aren't, you're asked to sign in first.",
                            "A three-step guided form opens. \"Submitting a Bug Report\" in Community and Posting explains each step.",
                        ]),
                        .heading("Severity levels"),
                        .bullets([
                            "High: seriously affects core functionality, or makes a feature completely inaccessible.",
                            "Medium: makes something harder to use, but there's a workaround or the impact is partial.",
                            "Low: minor, with cosmetic or occasional problems.",
                        ]),
                        .note("The Bug Tracker loads directly from AppleVis, so it's always up to date. New bugs on the website appear without an app update."),
                    ]
                ),
                HelpArticle(
                    id: "discover-be-my-eyes",
                    title: "Be My Eyes",
                    summary: "Open Call a Volunteer, Be My AI, or the Service Directory from AppleVis.",
                    content: [
                        .body("AppleVis is a Be My Eyes company. The Be My Eyes section in Discover gives you quick access to three free visual assistance services."),
                        .heading("Available services"),
                        .bullets([
                            "Call a Volunteer: a live video call with a sighted volunteer who sees through your phone's camera. Available 24 hours a day in 185 languages.",
                            "Be My AI: an AI assistant that describes images, reads text, and answers visual questions in 36 languages.",
                            "Service Directory: a searchable list of accessible customer service contacts at hundreds of companies and government departments around the world.",
                        ]),
                        .heading("How to use it"),
                        .steps([
                            "Open Discover.",
                            "Go to the Be My Eyes section.",
                            "Choose Call a Volunteer, Be My AI, or Service Directory.",
                            "If Be My Eyes is installed, it opens to that feature.",
                            "If it isn't installed, its App Store page opens so you can download it.",
                        ]),
                        .note("All three services are free. Be My Eyes is a separate app, so these links leave AppleVis and open Be My Eyes or its App Store page."),
                        .tip("Be My Eyes also has an entry in the AppleVis App Directory, with community accessibility comments and ratings."),
                    ]
                ),
                HelpArticle(
                    id: "discover-filters",
                    title: "Filters, Tags, Categories, and Headings",
                    summary: "How to narrow down long lists.",
                    content: [
                        .body("Filters and pickers shorten long lists. Podcasts can be filtered by content type and tag. The App Directory can be filtered by platform and category, and each category reads its count, for example \"Books, 26 apps.\""),
                        .note("With VoiceOver, you can move by heading wherever headings are available. The same headings are shown on screen."),
                    ]
                ),
                HelpArticle(
                    id: "discover-rss-feeds",
                    title: "RSS Feeds",
                    summary: "Copy or share links to follow AppleVis outside the app.",
                    content: [
                        .body("If you use an RSS reader, Discover has an RSS Feeds page with links you can add to it."),
                        .bullets([
                            "Copy or share the main AppleVis feed, or a feed for just Apps, Blogs, Guides, Reviews, Forums, Apple-only forum posts, or Podcasts.",
                            "Every feed link works in any RSS reader.",
                        ]),
                        .steps([
                            "Open Discover.",
                            "Go to Stay Updated and choose RSS Feeds.",
                            "Choose Copy or Share next to the feed you want.",
                        ]),
                    ],
                    contentType: .guide
                ),
            ]
        ),
        HelpSection(
            id: "foryou-search",
            title: "For You and Search",
            icon: "magnifyingglass",
            description: "Saved items, following, recommended apps, your queue, and downloads, plus how to search AppleVis.",
            articles: [
                HelpArticle(
                    id: "foryou-overview",
                    title: "Using For You",
                    summary: "Saved items, following, recommended apps, your podcast queue, and downloads.",
                    content: [
                        .body("For You isn't a recommendation feed. It only shows things you chose to save, follow, recommend, queue, or download."),
                        .heading("The five sections"),
                        .bullets([
                            "Saved: topics, apps, guides, blog posts, and episodes you've bookmarked. You can filter by content type.",
                            "Following: items you're keeping up with. If notifications are on, you're told when there's new activity.",
                            "Recommended: apps you've given a public thumbs-up. Swipe on one to remove it.",
                            "Queue: podcast episodes lined up to play in order. You can reorder or remove them.",
                            "Downloads: episodes saved on this device so you can listen without a connection.",
                        ]),
                        .tip("Use the section picker at the top of For You to move between Saved, Following, Recommended, Queue, and Downloads. With VoiceOver, swipe up or down on the picker to change sections, and VoiceOver reads the one you've chosen."),
                    ],
                    contentType: .guide,
                    relatedLinks: [
                        RelatedLink(label: "Save, Follow, Download, and Recommend: What\u{2019}s the Difference?", type: .faq, destination: .article("foryou-save-follow-download-faq")),
                    ]
                ),
                HelpArticle(
                    id: "foryou-save-follow-download-faq",
                    title: "Save, Follow, Download, and Recommend: What\u{2019}s the Difference?",
                    summary: "Four ways to keep content close, and when to use each one.",
                    content: [
                        .faq(question: "What does Save do?", answer: "Save bookmarks a topic, app, guide, blog post, or episode so you can find it in For You > Saved. It doesn't download anything or notify you about updates."),
                        .faq(question: "What does Follow do?", answer: "Follow keeps an item in For You > Following and, where supported, notifies you when something changes, such as a new reply on a forum topic. Use Follow when you want to keep up with something over time."),
                        .faq(question: "What does Download do?", answer: "Download is only for podcast episodes. It saves the audio on your device so you can listen without a connection. Downloaded episodes are in For You > Downloads."),
                        .faq(question: "What does Recommend do?", answer: "Recommend is only for apps. It's a public thumbs-up that tells other members you vouch for an app. Everything you've recommended is in For You > Recommended, and you can remove a recommendation at any time."),
                        .faq(question: "Can I do more than one at once?", answer: "Yes. A podcast episode can be saved, followed, and downloaded at the same time, and an app can be saved and recommended. Each one is separate, so removing one doesn't affect the others."),
                    ],
                    contentType: .faq
                ),
                HelpArticle(
                    id: "search-overview",
                    title: "Using Search",
                    summary: "Find discussions, apps, guides, podcast episodes, bug reports, and Help from one place.",
                    content: [
                        .body("Search is the quickest way to find something when you know roughly what you're looking for. Use the search field at the top of Discover."),
                        .heading("How results are grouped"),
                        .bullets([
                            "Forum Topics: community discussions.",
                            "Apps: entries from the App Directory.",
                            "Guides: guides and tutorials.",
                            "Blogs: posts from the AppleVis Blog.",
                            "Podcasts: episodes from every AppleVis podcast.",
                            "Bug Reports: accessibility bugs in the tracker.",
                        ]),
                        .tip("If your search isn't in English, AppleVis may offer to translate it. Search works best in English."),
                        .note("VoiceOver first reads a short summary, such as \"12 results found in 4 categories.\" Each section heading gives more detail."),
                    ],
                    contentType: .guide
                ),
            ]
        ),
        HelpSection(
            id: "community",
            title: "Community and Posting",
            icon: "person.3",
            description: "Forums, following, comments, notifications, guidelines, and writing help.",
            articles: [
                HelpArticle(
                    id: "community-forums",
                    title: "Forums and Following",
                    summary: "Browse forum topics, follow activity, and manage replies.",
                    content: [
                        .bullets([
                            "Use Forums in Discover to browse topics.",
                            "Filter by Recent, New, Unread, Following, or Saved.",
                            "When you follow a topic, it appears in For You > Following, and you can be notified about new replies.",
                            "Your Home Feed settings control which content types appear on Home and whether they're limited to Apple topics.",
                            "Settings > Notifications controls which of these send you a notification.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "community-writing-tools",
                    title: "Writing Help and Translation",
                    summary: "Rewrite, translate to English, guideline reminders, and reading content in your own language.",
                    content: [
                        .heading("Writing in English"),
                        .body("Before you post a topic, reply, or comment, AppleVis can help. It can improve the tone of your draft, translate a draft that isn't in English, or point out something the guidelines checker thinks might cause a problem."),
                        .bullets([
                            "Rewrite makes your draft clearer and more polite without changing what you mean.",
                            "If your draft isn't in English, AppleVis offers to translate it.",
                            "Both are available wherever you write for the community or the team: topics, replies, comments, reviews, edits, Contact Us, every Submit form, and Report a Comment. On forms with more than one box, Translate translates every box that isn't in English.",
                            "Private messages to another member have Rewrite but no translation prompt. You're welcome to write to each other in any language you share.",
                            // Was "The guidelines checker is purely advisory — it never
                            // blocks you from posting," which isn't accurate:
                            // ContentSubmissionPolicy does block a small set of things
                            // (image links, strong vulgar language, a very hostile tone,
                            // non-English text) before they can be submitted at all —
                            // only GuidelinesChecker's broader, softer reminders are
                            // purely advisory. Flagged during the Community Agreement
                            // audit; corrected to describe both accurately.
                            "Most guideline reminders are a friendly note that you can dismiss. A few things must be fixed before you can post: image links, strong language, and posts that aren't in English.",
                            "If AI helped you write something, the community appreciates a short note saying so.",
                        ]),
                        .heading("Reading AppleVis in your own language"),
                        .body("AppleVis is written and moderated in English. It's the one shared language that lets the whole community talk in the same place, and lets the editorial team review everything that's posted."),
                        .body("You don't have to read it in English. Turn on Auto-Translate in Settings, and blog posts, forum topics, app entries, podcast episodes, guides, bug reports, comments, and Help can be translated into your language on your device."),
                        .bullets([
                            "Translation happens on your iPhone. Nothing you read is sent to an outside server.",
                            "Translation is automatic but not perfect. Look for the small \"Translated\" note, and choose Show Original to see the English text.",
                            "Links in translated text still go to the right place.",
                            "The app itself, including its buttons, headings, and everything VoiceOver reads, follows your iPhone's language in 22 languages, with or without Auto-Translate.",
                        ]),
                        .tip("With VoiceOver, translated text is spoken with the right voice and pronunciation for that language. You don't need to change your VoiceOver language."),
                    ]
                ),
                HelpArticle(
                    id: "community-guidelines",
                    title: "Community Guidelines",
                    summary: "The basics of posting respectfully and usefully.",
                    content: [
                        .bullets([
                            "Stay on topic.",
                            "Be respectful and constructive.",
                            "Use clear subject lines.",
                            "Don't post personal email addresses, referral links, or advertisements.",
                            "Disclose conflicts of interest and any AI assistance.",
                            "Avoid duplicate posts and one-word replies.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "community-language-filter",
                    title: "Filtering Language You See",
                    summary: "Why some words appear masked, what is always blocked from posting, and how to turn the filter off.",
                    content: [
                        .heading("Two separate things"),
                        .body("AppleVis has two separate systems. One controls what you're allowed to post. The other controls what you see. Changing one never changes the other."),
                        .heading("What you can post"),
                        .body("Strong or explicit language is never allowed in anything you post through the app, including comments, replies, topics, reviews, and messages. This applies to everyone, and Settings can't turn it off."),
                        .heading("What you see"),
                        .body("Settings > General has a Filter Profanity switch, which is on by default. When it's on, a wider range of language, including milder words the website allows, is masked, for example \"s***\". Turn it off if you'd rather see everything as written."),
                        .note("Turning the filter off only changes what you see. It never changes what you're allowed to post."),
                        .heading("Why this exists"),
                        .body("The community includes people of many ages and comfort levels, and the filter helps keep AppleVis welcoming."),
                        .body("Apple also limits how much strong language an app can contain for its age rating. Filtering by default helps AppleVis stay within those rules as the community grows."),
                        .heading("If something slips through"),
                        .body("No automatic filter catches everything. If you see language that shouldn't be there, use Report on that comment or post to let the editorial team know."),
                        .faq(
                            question: "Does turning the filter off let me post anything I want?",
                            answer: "No. This setting only affects what you see from other people. The posting rules stay the same."
                        ),
                    ],
                    relatedLinks: [
                        RelatedLink(label: "Community Guidelines", type: .guide, destination: .article("community-guidelines")),
                    ]
                ),
                HelpArticle(
                    id: "community-edit-post",
                    title: "Editing Your Posts and Replies",
                    summary: "How to change a forum reply, blog comment, app comment, or podcast comment after you've posted it.",
                    content: [
                        .body("You can edit anything you've written from inside the app. The Edit option only appears on content you wrote."),
                        .heading("Forum replies and topic comments"),
                        .steps([
                            "Open the forum topic or the episode's comments.",
                            "Find your reply and touch and hold it to open its actions.",
                            "Choose Edit Comment.",
                            "The Edit screen opens with your original text.",
                            "Make your changes.",
                            "Choose Save at the top right.",
                        ]),
                        .heading("App, blog, and guide comments"),
                        .steps([
                            "Open the app, blog post, or guide where you left a comment.",
                            "Touch and hold your comment to open its actions.",
                            "Choose Edit Comment.",
                            "Edit the text and choose Save.",
                        ]),
                        .note("Edits appear straight away. You don't need to reload the page."),
                        .tip("Choose Rewrite if you'd like help with the tone before you save your edit."),
                        .tip("With VoiceOver, you can also reach Edit from the Actions rotor."),
                    ]
                ),
                HelpArticle(
                    id: "community-delete-post",
                    title: "Deleting Your Posts and Comments",
                    summary: "How to permanently remove a forum reply, blog comment, app comment, or podcast comment you've written.",
                    content: [
                        .body("You can permanently delete anything you've written. Deleted content can't be recovered."),
                        .steps([
                            "Find your post or comment.",
                            "Touch and hold it to open its actions.",
                            "Choose Delete Comment.",
                            "Choose Delete to confirm.",
                        ]),
                        .warning("Deleting is permanent and can't be undone. If you only want to change the wording, use Edit instead."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-bug",
                    title: "Submitting a Bug Report",
                    summary: "How to report a new accessibility bug using the three-step guided form.",
                    content: [
                        .body("If you've found an accessibility bug that isn't in the tracker yet, you can report it from the app. You need to be signed in, and you need to have filed the bug with Apple's Feedback Assistant first. AppleVis doesn't accept reports without it."),
                        .heading("Before you start"),
                        .bullets([
                            "Check the Bug Tracker to make sure the bug isn't already reported.",
                            "File it with Apple's Feedback Assistant first, and keep the FB number. You'll need it.",
                            "Sign in from Profile if you haven't already.",
                        ]),
                        .heading("Step 1: Describe the Bug"),
                        .steps([
                            "Open Discover, go to Contribute, and choose Submit a Bug Report.",
                            "Give it a short, specific title, for example \"VoiceOver skips toolbar buttons in Mail.\"",
                            "Add your email address in case the team needs to follow up.",
                            "Write a description: what you expected, what happened, and how to reproduce it. The minimum is 30 characters, but more detail helps.",
                            "Choose Continue.",
                        ]),
                        .tip("Choose Rewrite on this step if you'd like help making your description clearer."),
                        .heading("Step 2: Environment"),
                        .steps([
                            "Choose the platform: iOS, iPadOS, or macOS.",
                            "Enter the software version where you saw the bug.",
                            "Say whether you can reproduce it reliably.",
                            "Enter your Apple Feedback number. It must start with \"FB\" and match the report you filed with Apple.",
                            "Choose how you'd like to be credited if the report helps lead to a fix: by name, by your AppleVis username, or anonymously.",
                            "Choose Continue.",
                        ]),
                        .heading("Step 3: Review and Submit"),
                        .body("Check everything, then choose Submit. A thank-you screen confirms it was sent, and the AppleVis team takes it from there."),
                        .note("Reports are reviewed before they're published. Duplicates, unclear descriptions, and reports without a valid Apple Feedback number aren't accepted."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-blog",
                    title: "Submitting a Blog Post",
                    summary: "How to send a blog post draft to the editorial team, using the three-step guided form.",
                    content: [
                        .body("If you have a tip, a review, a personal story, or something else to share with the AppleVis community, you can submit a blog post draft from the app. You need to be signed in."),
                        .body("The editorial team reviews every draft before anything is published, so submitting starts a conversation rather than posting straight away."),
                        .heading("Step 1: Title & Category"),
                        .steps([
                            "Open Discover, go to Contribute, and choose Submit a Blog Post.",
                            "Give your post a clear title.",
                            "Choose the category that fits best.",
                            "Choose Continue.",
                        ]),
                        .heading("Step 2: Your Content"),
                        .steps([
                            "Enter a valid email address. The editorial team may reply to follow up.",
                            "Write a few sentences on why this post would interest AppleVis readers. This is required, and it helps the editors understand your idea.",
                            "Write, import, or paste your draft. The minimum is 50 characters.",
                            "Use Import File to bring in a text or Markdown file from Files or iCloud Drive, or Paste to use what's on your clipboard.",
                            "Choose Continue.",
                        ]),
                        .heading("Step 3: Review and Submit"),
                        .body("Check the title, category, your reason, and your draft, then choose Submit. A thank-you screen confirms it was sent, and the editorial team will follow up with their decision."),
                        .note("The AppleVis editorial team reviews every submission and decides whether to publish it. They'll contact you either way."),
                        .tip("Cancel is available on every step. On step 2 or the review screen, use Back to return to the previous step without losing your draft."),
                        .tip("You can also share text into AppleVis from most other apps. Select the text, choose Share, then choose AppleVis, and the blog form opens with the text already added."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-podcast",
                    title: "Submitting a Podcast",
                    summary: "How to submit a podcast episode using the two-step guided form.",
                    content: [
                        .body("If you make a podcast about accessibility, Apple products, or blindness, you can submit an episode for the AppleVis team to consider. You need to be signed in."),
                        .heading("Step 1: Episode & Audio"),
                        .steps([
                            "Open Discover, go to Contribute, and choose Submit a Podcast.",
                            "Describe the episode: what it covers and who it's for. The minimum is 20 characters.",
                            "Use Choose Audio File to select your episode from Files, iCloud Drive, or another connected storage service.",
                            "Choose Rewrite if you'd like help with the description.",
                            "Choose Continue once you've written a description and selected a file.",
                        ]),
                        .heading("Step 2: Review and Submit"),
                        .body("Check your description and the file you selected, then choose Submit. Keep the app open while it uploads. A thank-you screen confirms it was sent, and the team will follow up."),
                        .note("The AppleVis editorial team reviews every submission and contacts you with their decision."),
                        .tip("You can also share an episode from apps like Podcasts, Overcast, or Spotify, or share an audio file from Files. Choose AppleVis in the share sheet, and it opens in this form."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-app",
                    title: "Submitting an App Entry",
                    summary: "How to add an app to the App Directory using the three-step guided form.",
                    content: [
                        .body("You can add an app to the App Directory if you've used it yourself, not just read about it. You can't submit an app you develop, publish, or are otherwise connected with. You need to be signed in."),
                        .heading("Before you begin"),
                        .bullets([
                            "Check the App Directory in case the app is already listed.",
                            "Make sure you've used the app yourself and can describe its accessibility.",
                            "Make sure you're not the developer or publisher, and aren't otherwise connected with it.",
                        ]),
                        .heading("Step 1: Find the App"),
                        .steps([
                            "Open Discover, go to Contribute, and choose Submit an App.",
                            "Confirm the two checkboxes on the Before You Begin screen.",
                            "Choose the platform: iPhone and iPad, Mac, Apple Watch, or Apple TV.",
                            "Search by name or paste an App Store link. If the app isn't on the App Store, which is the case for some Mac apps, choose Enter Details Manually.",
                            "Select the right result and choose Continue.",
                        ]),
                        .heading("Step 2: App Details"),
                        .body("What you fill in depends on the platform. Confirm the details taken from the App Store, then describe the app's accessibility."),
                        .bullets([
                            "iPhone and iPad apps: separate ratings for VoiceOver Performance, Button Labelling, and Usability, plus the devices the app supports. The devices are ticked for you from the App Store, and you can untick any the app doesn't really support.",
                            "Mac, Apple Watch, and Apple TV apps: one combined Usability rating.",
                            "Every platform asks for Accessibility Comments. The minimum is 20 characters, but the more you share, the more useful it is to the next person.",
                        ]),
                        .tip("Choose Rewrite under Accessibility Comments if you'd like help with what you've written."),
                        .heading("Step 3: Review and Submit"),
                        .body("Check everything, then choose Submit. A thank-you screen confirms it was sent. The AppleVis team reviews every submission before it appears in the directory."),
                    ]
                ),
                HelpArticle(
                    id: "community-edit-profile",
                    title: "Editing Your Profile",
                    summary: "Update your display name, bio, interests, links, and who can contact you.",
                    content: [
                        .steps([
                            "Open Profile and Settings.",
                            "Choose Edit Profile, near the top of the Account section.",
                            "Update any of these: display name, bio, location, interests, the Apple products you use, your links, time zone, and who can contact you.",
                            "Choose Save.",
                        ]),
                        .bullets([
                            "Display Name: what other members see on your posts.",
                            "Bio: a short description of yourself. If you're not sure what to write, choose Help Me Write This and answer a few questions to get a draft you can edit or keep.",
                            "Location: your country, chosen from a list.",
                            "Interests: accessibility tools, Apple products, or anything else you'd like to share.",
                            "Apple Products Owned: tick the devices you use. They're shown on your public profile.",
                            "Website, X/Twitter, Facebook, Mastodon: your links elsewhere.",
                            "Time Zone: choose it yourself, or use the one your device is set to.",
                            "Allow Other Members to Contact Me: lets signed-in members send you a private message without seeing your email address. You can turn this off at any time.",
                        ]),
                        .heading("Your account anniversary"),
                        .body("Once a year, around the day you joined, Home shows a short celebration with a note you can share if you like."),
                        .heading("Messaging another member"),
                        .body("Choose a member's name to open their profile. If they allow messages, you'll see a Contact button. The message is sent through AppleVis, and your email address isn't shared with them unless they reply."),
                        .note("Changes are saved to your AppleVis account straight away and appear on the website and to other members immediately."),
                    ]
                ),
                HelpArticle(
                    id: "community-report-comment",
                    title: "Reporting a Comment",
                    summary: "Report spam, harassment, or anything else that shouldn't be there.",
                    content: [
                        .body("If a comment or reply is spam, harassment, offensive, or misleading, you can report it to the editorial team from wherever you found it."),
                        .steps([
                            "Touch and hold the comment, or use the Actions rotor with VoiceOver, and choose Report Comment.",
                            "Choose the reason that fits best: Spam or Advertising, Harassment or Abuse, Inappropriate or Offensive Content, Off-Topic, Misinformation, or Something Else.",
                            "Add any details that would help the team review it. This is optional. Rewrite and Translate to English are available here too.",
                            "Confirm your email address in case the team needs to follow up. It's filled in if you're signed in.",
                            "Review everything and choose Send Report.",
                        ]),
                        .note("You don't need to be signed in to report a comment. If you are, your name is filled in for you."),
                        .tip("Reporting a comment doesn't remove it straight away. It asks the editorial team to review it."),
                    ],
                    contentType: .guide
                ),
            ]
        ),
        HelpSection(
            id: "content",
            title: "Apps, Podcasts, Blogs, and Guides",
            icon: "square.grid.2x2",
            description: "How each AppleVis content area works.",
            articles: [
                HelpArticle(
                    id: "content-apps",
                    title: "App Directory",
                    summary: "Browse apps by platform and category, search, and read accessibility comments.",
                    content: [
                        .body("In the App Directory, AppleVis members describe how well apps work with accessibility features such as VoiceOver, braille, and Switch Control. Browse by platform (iPhone and iPad, Mac, Apple Watch, or Apple TV), then by category."),
                        .bullets([
                            "Open an app's page to see its description, developer, category, ratings, and every accessibility comment members have left.",
                            "Accessibility Consensus is an AI-generated summary of what commenters report. It's useful before you read every comment.",
                            "Open in App Store takes you to the App Store to download or buy the app. Purchases are always handled by Apple, not AppleVis.",
                            "Save or Follow an app to find it again in For You. Recommend gives it a public thumbs-up, and everything you've recommended is in For You > Recommended.",
                            "Share an App Store link into AppleVis from any app to look up or submit that app.",
                            "If an app's App Store link stops working, its page tells you the listing may no longer be available.",
                            "If the App Store shows a newer version or a new name, the page mentions it. It also mentions when the App Store's description is different from the one on AppleVis.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "content-podcasts",
                    title: "Podcasts",
                    summary: "Playback, queue, chapters, downloads, the Dynamic Island, AirPods, and settings.",
                    content: [
                        .bullets([
                            "Play, pause, seek, skip forward and back, and change speed from the player or the mini player at the bottom of the screen.",
                            "Use Add to Queue or Play Next to choose what plays after the current episode.",
                            "Download episodes to listen offline.",
                            "AppleVis remembers where you stopped in each episode. To go back to the beginning, open the episode and use Start Over in Episode Tools.",
                            "Listened, in Episode Tools, is a switch you can turn on or off as a reminder that you've heard an episode. It turns on by itself when an episode plays to the end, and episode lists show a checkmark for it. It doesn't change your place in the episode.",
                            "When an episode has chapters, move between them from the chapter list.",
                            "The Lock Screen shows the episode title, artwork, progress, and playback controls.",
                            "On supported iPhone models, the Dynamic Island shows the episode title and playback state while you use other apps.",
                            "AirPods: double-tap to play or pause. With a queue, the next-track gesture skips to the next episode, and previous-track restarts the current one.",
                            "Control Center shows Now Playing, with artwork, title, and controls.",
                        ]),
                        .tip("Adjust playback in Settings > Podcasts: speed, skip intervals, auto-play, Trim Silence, Voice Boost, an equalizer (Flat, Speech, Bass Boost, or Treble Boost), a sleep timer, and resume rewind."),
                    ]
                ),
                HelpArticle(
                    id: "content-blog-guides",
                    title: "Blogs and Guides",
                    summary: "Read official updates, guides, tutorials, resources, and comments.",
                    content: [
                        .body("The AppleVis Blog has official posts and announcements. Guides has tutorials, how-to articles, resources, events, and developer content."),
                        .body("In both, you can read, save, share, comment, read summaries, and join the discussion."),
                    ]
                ),
                HelpArticle(
                    id: "content-bugs",
                    title: "Bug Tracker",
                    summary: "How the AppleVis bug database works, and what each field means.",
                    content: [
                        .body("The Bug Tracker is a community database of accessibility bugs on Apple platforms. The AppleVis team reviews and classifies every report before it's published."),
                        .heading("What each field means"),
                        .bullets([
                            "Title: a short, descriptive name for the bug.",
                            "Platform: iOS/iPadOS or macOS.",
                            "Status: Active means the bug is in the current release and not fixed yet.",
                            "Status: Fixed means Apple has released an update that fixes it.",
                            "Severity: High means a key accessibility feature is completely unavailable.",
                            "Severity: Medium means something is harder to use, but there's a workaround.",
                            "Severity: Low means a minor problem that is cosmetic or occasional.",
                            "First Seen In: the OS version where the bug was first noticed.",
                            "Fixed In: the version where Apple fixed it, if known.",
                            "Steps to Reproduce: numbered steps that reliably cause the bug.",
                            "Workaround: any known way to reduce the problem until Apple fixes it.",
                            "Apple Feedback ID: the number of the report filed with Apple. Choosing it opens Feedback Assistant so you can file your own report on the same issue.",
                            "Device: the hardware used when the bug was first reported.",
                            "How Often: Rarely, Sometimes, or Always.",
                        ]),
                        .heading("Why filing your own Apple report helps"),
                        .body("Apple uses the number of Feedback Assistant reports as one sign of how widespread a bug is. The more people report the same issue, the more it stands out. Use Report to Apple on any active bug to open Feedback Assistant and add your report."),
                        .tip("When you file with Apple, include your device model, OS version, and the steps to reproduce from the AppleVis report. Mentioning the Apple Feedback ID from the AppleVis report also helps."),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "settings",
            title: "Settings and Personalization",
            icon: "gearshape",
            description: "Appearance, accessibility, sounds and haptics, notifications, podcasts, sync, privacy, storage, and support.",
            articles: [
                HelpArticle(
                    id: "settings-appearance",
                    title: "Appearance",
                    summary: "Themes, Liquid Glass, spacing, contrast, and visual comfort.",
                    content: [
                        .body("Appearance controls how AppleVis looks. Choose a theme from the System, Light, Dark, or High Contrast groups."),
                        .body("Card Density sets Comfortable or Compact spacing, depending on how much you want on screen at once."),
                        .body("Liquid Glass gives supported surfaces a see-through look. It switches to solid backgrounds when Reduce Transparency or a high-contrast theme is on."),
                    ]
                ),
                HelpArticle(
                    id: "settings-general",
                    title: "General",
                    summary: "How Home welcomes you, tips, search auto-focus, and how web links open.",
                    content: [
                        .body("Settings > General contains everyday settings that apply to everyone, whichever way you use your iPhone."),
                        .bullets([
                            "Home Startup Behavior: how much Home says when you open it or return to it. Quiet says nothing, Helpful says a short welcome, and Detailed adds an AI-generated summary of what's new.",
                            "Welcome Summary: a separate switch for the short summary of what's new at the top of Home. It controls what's shown, not what's spoken, so you can turn it off and still hear the spoken welcome.",
                            "Auto-Focus Search Field: shows the keyboard as soon as you open Search, so you can start typing.",
                            "Web Links: choose In-App Browser to stay in AppleVis, or Default Browser to open links in Safari or your chosen browser. This applies to App Store pages, social links, legal pages, and Open in Browser actions. These links show a small arrow after their name, and VoiceOver says where they'll open.",
                            "Links in posts and comments to other AppleVis pages, such as a forum topic, app entry, guide, blog post, podcast episode, or bug report, open in the app instead of a browser.",
                            "AppleVis Tips: short tips that appear from time to time to save you a step.",
                        ]),
                        .tip("VoiceOver Detail Level is in Settings > Accessibility, because it controls how much VoiceOver reads."),
                    ]
                ),
                HelpArticle(
                    id: "settings-notifications",
                    title: "Notifications",
                    summary: "Choose which AppleVis activity sends you notifications.",
                    content: [
                        .bullets([
                            "Replies to My Posts: automatically follows new forum topics and app entries you post, so you're notified about replies. It applies to posts from now on. Signed in only.",
                            "Followed Topics: activity in anything you follow. Signed in only.",
                            "New Forum Topics: new discussions across the community.",
                            "New App Directory Entries: new or updated app entries.",
                            "New Podcast Episodes.",
                            "New Guides: new guides and tutorials.",
                            "New Comments: comments on everything, not only what you follow. This can send a lot of notifications.",
                        ]),
                        .note("You can also choose a notification sound and turn the app icon's badge on or off. Notifications must also be allowed for AppleVis in iPhone Settings. If they're off there, nothing arrives, whatever is turned on here."),
                    ]
                ),
                HelpArticle(
                    id: "settings-privacy-sync",
                    title: "Privacy and Sync",
                    summary: "What syncs through iCloud, and how your account and data on this device are handled.",
                    content: [
                        .bullets([
                            "Saved & Sync controls what syncs through iCloud: Saved Items, Following, Podcast Position, Podcast Queue, Read History, and Settings & Preferences. Each has its own switch.",
                            "Privacy explains what AppleVis collects (only your email address, username, and a push notification token) and how your session is secured. There's no advertising tracking.",
                            "Show What's New on Home controls whether Home shows the New view, the summary, and new-activity badges. Your reading history is still kept on your device, so turning this off only makes Home quieter.",
                            "Clear All Local Data removes cached content, downloads, saved items, and reading history from this device. Your account, iCloud data, and app settings aren't affected.",
                        ]),
                        .note("Apple Intelligence features work entirely on your device. No post, comment, or search text is sent to a server."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-storage-cache",
                    title: "Storage and Cache",
                    summary: "Manage downloaded audio and cached content, and free up space.",
                    content: [
                        .body("Storage and Cache shows how much space AppleVis is using on this device, and lets you manage it."),
                        .bullets([
                            "Downloaded podcast episodes kept for offline listening.",
                            "Cached images and content that make browsing faster.",
                            "Cache retention: 3, 6, or 12 months, or Keep Forever. This is how long cached content is kept before it's removed automatically.",
                        ]),
                        .steps([
                            "Open Settings > Storage and Cache.",
                            "Check how much space downloads and the cache are using.",
                            "Use Clear Cached Content to remove cached content. Downloads and saved items are kept.",
                            "Use Clear Downloaded Episodes to remove all downloads, or remove single episodes from For You > Downloads.",
                        ]),
                        .tip("Clearing the cache only removes temporary content. It never deletes downloaded episodes, saved items, or your account data."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-sounds-haptics",
                    title: "Sounds and Haptics",
                    summary: "Turn app sounds and vibration on or off separately.",
                    content: [
                        .body("Settings > Sounds & Haptics controls the sounds and vibrations AppleVis uses."),
                        .bullets([
                            "Confirmation Sounds: play for actions such as saving, finished downloads, and podcast play and pause.",
                            "Interface Sounds: play for switching tabs, changing pickers, opening screens, and refreshing lists. These are off by default.",
                            "Haptic Feedback: vibrates for the same moments as Confirmation Sounds, such as saving, signing in, and errors. Sounds and haptics are separate, so you can use either one on its own.",
                        ]),
                        .note("Sounds and haptics for errors and connection changes always play, whatever is turned on here, so you don't miss them."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-support",
                    title: "Profile and App Support",
                    summary: "Contact the AppleVis team using the guided contact form.",
                    content: [
                        .body("Profile has a Contact AppleVis button that opens a guided contact form. You can send a bug report, feedback, a suggestion, or a recommendation to the AppleVis team without leaving the app."),
                        .tip("When you choose Bug Report, a switch appears for including system information. Turn it on to add your app version and iOS version automatically. This helps when reporting a crash or something unexpected."),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "smart",
            title: "Smart Features and iOS Integrations",
            icon: "sparkles",
            description: "Apple Intelligence, translation, Siri phrases, Spotlight, the Share Extension, Focus Filters, and the Dynamic Island.",
            articles: [
                HelpArticle(
                    id: "smart-reading-writing",
                    title: "Reading, Writing, and Translation Tools",
                    summary: "Read Aloud, summaries, Rewrite, and translation.",
                    content: [
                        .bullets([
                            "Read Aloud reads content out loud using your device's built-in speech. It works on any device and doesn't need Apple Intelligence.",
                            "AI Summaries shorten long threads, show notes, and app descriptions to a couple of sentences. Needs Apple Intelligence.",
                            "Accessibility Consensus turns an app's accessibility comments into one short paragraph. Needs Apple Intelligence.",
                            "Rewrite improves your draft before you post it without changing what you mean. Needs Apple Intelligence.",
                            "Translate is offered when your draft or search isn't in English. Needs Apple Intelligence.",
                        ]),
                        .note("Apple Intelligence features need an iPhone 15 Pro or later, or any iPhone 16 model, with a recent version of iOS and Apple Intelligence turned on in iOS Settings. See Apple Intelligence Features for details."),
                    ]
                ),
                HelpArticle(
                    id: "smart-siri-widgets",
                    title: "Siri and Spotlight",
                    summary: "Use AppleVis from system features outside the app.",
                    content: [
                        .heading("Siri phrases"),
                        .body("AppleVis adds several phrases to Siri. You can say any of these at any time, or add your own phrases in the Shortcuts app."),
                        .bullets([
                            "\"Hey Siri, open AppleVis\" opens Home.",
                            "\"Hey Siri, open AppleVis Forums\" opens Forums.",
                            "\"Hey Siri, show unread AppleVis topics\" opens Forums filtered to Unread.",
                            "\"Hey Siri, resume AppleVis podcast\" continues your last episode where you left off.",
                            "\"Hey Siri, play latest AppleVis podcast\" plays the newest episode.",
                            "\"Hey Siri, search AppleVis\" opens search.",
                            "\"Hey Siri, open AppleVis saved items\" opens Saved in For You.",
                            "\"Hey Siri, what's new on AppleVis\" speaks a summary of what's new since your last visit.",
                            "\"Hey Siri, report a bug to AppleVis\" opens the accessibility bug report form.",
                        ]),
                        .body("If Siri uses another language, you can say these phrases in that language too."),
                        .heading("Spotlight"),
                        .body("Spotlight can find AppleVis topics, apps, podcasts, and guides from iOS Search. Anything you've opened is added, so it's easy to find again."),
                    ]
                ),
                HelpArticle(
                    id: "smart-apple-intelligence",
                    title: "Apple Intelligence Features",
                    summary: "What Apple Intelligence does in AppleVis, which devices support it, and how to turn it on.",
                    content: [
                        .body("AppleVis uses Apple Intelligence for several AI features. They all run on your device, and no text or content is sent to a server."),
                        .heading("Requirements"),
                        .bullets([
                            "iPhone 15 Pro or later, or any iPhone 16 model.",
                            "iOS 18.1 or later.",
                            "Apple Intelligence turned on in iOS Settings > Apple Intelligence & Siri.",
                        ]),
                        .heading("What it does in AppleVis"),
                        .bullets([
                            "AI Summaries: shortens long forum threads, blog posts, guides, and app descriptions.",
                            "Accessibility Consensus: turns an app's accessibility comments into one paragraph.",
                            "Rewrite: improves a reply, comment, or submission draft before you send it, and can draft a bio for your profile.",
                            "Translate: offered when your draft or search isn't in English.",
                            "Guidelines Check: checks your draft for common posting issues and gives friendly suggestions.",
                        ]),
                        .heading("Turning it on or off"),
                        .body("The main switch is in iOS Settings > Apple Intelligence & Siri. It turns Apple Intelligence on for the whole device."),
                        .body("Once it's on, Settings > Intelligence in AppleVis lets you turn each feature on or off, so you can keep only the ones you want."),
                        .body("On a device or iOS version without Apple Intelligence, these features aren't shown. The rest of the app works the same without them."),
                        .note("To check whether Apple Intelligence is on, open iOS Settings > Apple Intelligence & Siri. If the switch is there and on, the AppleVis AI features are ready."),
                        .tip("If AI helped with a post, the community appreciates a short note, such as \"Polished with Rewrite\"."),
                    ]
                ),
                HelpArticle(
                    id: "smart-share",
                    title: "Share Into AppleVis",
                    summary: "Use the iOS share sheet to send App Store links, blog text, and podcast content to AppleVis.",
                    content: [
                        .body("AppleVis appears in the share sheet across iOS. Depending on what you share, AppleVis opens the right form."),
                        .heading("App Store links"),
                        .steps([
                            "Find an app in the App Store or Safari.",
                            "Choose Share, then choose AppleVis.",
                            "The app submission form opens with that app selected.",
                        ]),
                        .heading("Blog text or text files"),
                        .steps([
                            "Select text in any app, such as Notes, Pages, Safari, or Messages.",
                            "Choose Share, then choose AppleVis.",
                            "The blog submission form opens with your text in the content step.",
                            "You can share a .txt or .md file from Files or iCloud Drive the same way.",
                        ]),
                        .heading("Podcasts and audio"),
                        .steps([
                            "Find an episode in Podcasts, Overcast, Spotify, Pocket Casts, or another podcast app, or an audio file in Files.",
                            "Choose Share, then choose AppleVis.",
                            "The podcast submission form opens with what you shared attached.",
                        ]),
                        .note("AppleVis must be installed to appear in the share sheet. Sharing usually opens AppleVis with the right form ready. A few apps, including the App Store, don't switch over automatically. In that case you'll see a short confirmation, and what you shared will be waiting the next time you open AppleVis."),
                        .tip("If AppleVis isn't in your share sheet, go to the end of the row of apps and choose More to find and turn it on."),
                    ]
                ),
                HelpArticle(
                    id: "smart-system-integrations",
                    title: "Handoff, Background Refresh, and AirPlay",
                    summary: "What each system feature does, and how to turn it off.",
                    content: [
                        .heading("Handoff"),
                        .body("AppleVis shares which screen you're on, such as Home, Discover, or a podcast episode, so you can continue on a nearby Mac or iPad with the Handoff icon in the Dock or App Switcher."),
                        .body("Only the screen name and, where relevant, a public link are shared. No account details, tokens, or private data leave your device."),
                        .tip("To turn Handoff off for every app, use iOS Settings > General > AirPlay & Handoff > Handoff."),
                        .heading("Background Refresh"),
                        .body("While it's in the background, AppleVis refreshes downloaded episode details and checks for activity in what you follow, so everything is current the next time you open it."),
                        .tip("Turn this off in iOS Settings > General > Background App Refresh > AppleVis. Podcasts still play in the background either way. Only the regular refresh stops."),
                        .heading("AirPlay and the Route Picker"),
                        .body("The route picker in the podcast player sends audio to AirPlay speakers, HomePod, or Bluetooth devices, like any other audio app."),
                        .heading("iCloud Sync"),
                        .body("Saved items, following, podcast position and queue, reading history, and settings can sync through your private iCloud account. Each one can be turned on or off in Settings > Saved & Sync."),
                    ],
                    contentType: .guide,
                    relatedLinks: [
                        RelatedLink(label: "Saved and Sync Settings", type: .guide, destination: .savedSyncSettings),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "troubleshooting",
            title: "Troubleshooting",
            icon: "wrench.and.screwdriver",
            description: "Fix common problems with sign-in, sync, notifications, search, playback, and display.",
            articles: [
                HelpArticle(
                    id: "trouble-sign-in",
                    title: "Sign-In Problems",
                    summary: "What to check when you can't sign in to your AppleVis account.",
                    content: [
                        .bullets([
                            "Make sure you're using your applevis.com username and password.",
                            "Check your internet connection.",
                            "If you need to, reset your password on applevis.com. Once you're signed in, you can also use Change Password in Profile.",
                            "If your session has expired, sign in again from Profile.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-sync-notifications",
                    title: "Sync and Notification Problems",
                    summary: "Quick checks for iCloud sync and push notifications.",
                    content: [
                        .bullets([
                            "Make sure iCloud Sync is on in Settings > Saved & Sync.",
                            "Make sure both devices are signed in with the same Apple Account.",
                            "Make sure notifications are allowed for AppleVis in iOS Settings.",
                            "Make sure the notification type you want is turned on in AppleVis Settings > Notifications.",
                            "Sign in to use the personal notification types.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-podcast-search",
                    title: "Podcast, Search, and Display Problems",
                    summary: "Quick fixes for playback, search results, and visual comfort.",
                    content: [
                        .bullets([
                            "If playback seems stuck, pause and play again, or open the episode page and choose Play.",
                            "If search results aren't what you expect, try fewer words. If your search isn't in English, let AppleVis translate it.",
                            "If the app is too bright, too crowded, or has too much movement, check Appearance and iOS Display & Text Size.",
                            "If AppleVis is using a lot of storage, check Settings > Storage and Cache.",
                            "If a download fails, check your connection and try again from the episode page or Downloads. Unfinished downloads are removed automatically.",
                            "If content isn't updating, pull down to refresh. If you expect it to sync from another device, check Settings > Saved & Sync.",
                            "If you can't find something you saved, open For You > Saved and check the Show picker. It may be filtered to one content type.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-contact",
                    title: "Contact App Support",
                    summary: "Send bugs, feedback, suggestions, and general questions using the guided contact form.",
                    content: [
                        .body("The guided contact form sends your message to the AppleVis team without an email app. Open it from Profile or from Help. It has three steps when you're signed in and four when you're not."),
                        .heading("Step 1: Choose a type"),
                        .steps([
                            "Open Profile and choose Contact AppleVis, or open Help and go to the Contact section.",
                            "Choose the kind of message: App Bug Report, App Feedback, App Suggestion, or App Enquiry. The subject is filled in for you.",
                            "Choose Continue.",
                        ]),
                        .heading("Step 2: Your contact details (only when signed out)"),
                        .body("If you're not signed in, enter your name and email address so the team can reply. If you're signed in, this step is skipped."),
                        .heading("Write your message"),
                        .body("This is step 2 when you're signed in, and step 3 when you're not."),
                        .steps([
                            "Type your message.",
                            "If you chose App Bug Report, a switch appears for including app and device information. Turn it on to add your app version, device model, and accessibility settings such as VoiceOver automatically.",
                            "Rewrite and Translate to English are available if you'd like help with your message.",
                            "Choose Continue.",
                        ]),
                        .heading("Final step: Review and send"),
                        .steps([
                            "Check the summary: the type of message, subject, and a preview of your message.",
                            "Check your name and email address in the From section. You can edit them only if you're signed out.",
                            "Confirm that the message is genuine.",
                            "Choose Send Message.",
                            "A confirmation screen appears. The team will reply as soon as they can.",
                        ]),
                        .tip("Help also has a Contact AppleVis button at the bottom, if you read a Help article first and still need to get in touch."),
                        .note("You don't need to be signed in to use the contact form. If you're signed out, there's one extra step for your name and email address."),
                    ],
                    contentType: .troubleshooting
                ),
            ]
        ),
    ]

    static func find(_ id: String) -> HelpArticle? {
        sections.flatMap(\.articles).first { $0.id == id }
    }
}
