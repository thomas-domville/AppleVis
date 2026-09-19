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
            description: "A friendly quick tour of AppleVis — the tabs, signing in, and where everything lives.",
            articles: [
                HelpArticle(
                    id: "start-what-is-applevis",
                    title: "What AppleVis Is",
                    summary: "A community, app directory, podcast library, forums, and learning hub — built for blind, DeafBlind, and low-vision Apple users.",
                    content: [
                        .body("AppleVis is a community built by and for blind, DeafBlind, low-vision, and sighted people who care about accessibility on Apple platforms. This app brings that whole community — discussions, app accessibility comments, podcasts, blog posts, guides, and a live bug tracker — into one native, VoiceOver-friendly home."),
                        .heading("What you can do here"),
                        .bullets([
                            "Catch up on what's new since your last visit, right from Home.",
                            "Browse Discover for Forums, the AppleVis Blog, Guides, Podcasts, the App Directory, the Bug Tracker, site search, and Be My Eyes.",
                            "Keep track of what matters to you in For You — saved items, topics you follow, apps you've recommended, your podcast queue, and downloads.",
                            "Listen to podcasts with background audio, a queue, chapters, speed controls, and full Lock Screen and Dynamic Island support.",
                            "Post topics, replies, and comments, submit apps, bugs, blog posts, and podcasts, and message other members — once you're signed in.",
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
                        .body("Home is where you land first — a warm welcome, a quick catch-up on what's happened since you were last here, and a shortcut back to wherever you left off. Tap Customize Home (top-left) to choose which content types show up in your feed, or the Add button (top-right) to start a new forum topic or app entry on the spot."),
                        .heading("Discover"),
                        .body("Discover is where the rest of AppleVis lives. Open Forums, the AppleVis Blog, Guides, Podcasts, the App Directory, the Bug Tracker, Be My Eyes, RSS Feeds, or search — and if you want to contribute something yourself, that lives here too."),
                        .heading("For You"),
                        .body("For You is your own corner of the app — nothing shows up here unless you put it there. Saved items, things you follow, apps you've recommended, your podcast queue, and your downloads all live in one place, split across five simple sections."),
                        .heading("Profile and Settings"),
                        .body("Profile and Settings aren't a tab of their own — look for the Profile and Settings icon in the toolbar, available from Home, Discover, and For You alike. My Account is home base for your sign-in: edit your profile and bio, change your password or email, or sign out. Settings is where you shape how AppleVis looks, sounds, and behaves — appearance, accessibility, sounds and haptics, notifications, podcasts, privacy, intelligence, and more — with Help and Contact AppleVis tucked inside too. Want to message another member directly? That happens from their own profile, not yours."),
                    ]
                ),
                HelpArticle(
                    id: "start-sign-in",
                    title: "Signing In",
                    summary: "What signing in unlocks, and how to manage your account right from the app.",
                    content: [
                        .steps([
                            "Open Profile.",
                            "Tap Sign in to AppleVis.",
                            "Enter the same username and password you use on applevis.com.",
                            "Once you're in, Profile shows your account tools and a shortcut to your public profile.",
                        ]),
                        .heading("What signing in gets you"),
                        .bullets([
                            "Posting forum topics, replies, and comments.",
                            "Following topics and content so they show up in For You.",
                            "Recommending apps you love.",
                            "Sending a private message to another member.",
                            "Personalized notifications for the activity you actually care about.",
                        ]),
                        .heading("Changing your password or email"),
                        .body("You don't need to leave the app or open a browser to update your account. From Profile, tap Change Password or Change Email Address — each opens a short, guided flow: confirm your current password, enter the new value, and review before saving."),
                        .note("Your password itself is never stored in the app. AppleVis keeps a secure session token in the iOS Keychain instead."),
                    ]
                ),
                HelpArticle(
                    id: "start-faq",
                    title: "Frequently Asked Questions",
                    summary: "Quick answers to the questions members ask most.",
                    content: [
                        .faq(question: "How do I search AppleVis?", answer: "Open the Discover tab and use the search field (2 characters minimum). Results come back grouped into Forum Topics, Apps, Resources, Blogs, Podcasts, and Bug Reports."),
                        .faq(question: "Where are my saved items?", answer: "Open For You and choose Saved."),
                        .faq(question: "What's the difference between Save and Follow?", answer: "Save just bookmarks something so you can find it again — Follow keeps it in For You > Following and lets AppleVis notify you when it has new activity."),
                        .faq(question: "What's the difference between Recommend and Save?", answer: "Save is private — it's just for you. Recommend is a public thumbs-up on an app, telling other members you vouch for it. You can do both, and see everything you've recommended in For You > Recommended."),
                        .faq(question: "How do I download podcast episodes?", answer: "Open the episode and choose Download. Downloaded episodes appear in For You > Downloads for offline listening."),
                        .faq(question: "Can I message another AppleVis member?", answer: "Yes — open their profile (tap their name almost anywhere you see it) and, if they've left that turned on, you'll see a Contact button. It sends a private message through AppleVis; your email address isn't shared unless they choose to reply. You can turn this off for yourself in Edit Profile."),
                        .faq(question: "How do I report a comment I think breaks the guidelines?", answer: "Long-press the comment (or use the VoiceOver rotor's Actions) and choose Report Comment. A short guided form walks you through it and sends the report straight to the editorial team."),
                        .faq(question: "How do I change my VoiceOver detail level?", answer: "Open Settings > Accessibility and look for VoiceOver Detail Level — choose Simple, Normal, or All."),
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
                    summary: "See what's changed in the latest AppleVis update.",
                    content: [
                        .body("The What's New screen keeps a running log of AppleVis app updates — new features, improvements, and fixes — for the current release and everything before it."),
                        .steps([
                            "Open Profile.",
                            "Scroll to What's New and tap it.",
                            "Browse what changed in the current version, and everything that came before.",
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
                    summary: "A practical, no-pressure first-run path through the app.",
                    content: [
                        .steps([
                            "Open Home and take in the welcome — it greets you a little differently depending on whether you're signed in.",
                            "Skim the What's New area if you want to catch up on anything.",
                            "Tap Customize Home (top-left) to choose which content types show up in your feed.",
                            "Open Discover and poke around Forums, the Blog, Guides, Podcasts, the App Directory, and the Bug Tracker.",
                            "Open For You to see your Saved, Following, Recommended, Queue, and Downloads sections — all empty for now, but they won't stay that way.",
                            "Open Settings and glance through Appearance, Accessibility, Sounds & Haptics, Notifications, Podcasts, Saved & Sync, Privacy, Intelligence, and Siri & Shortcuts.",
                            "Open Profile and sign in when you're ready — or use Contact AppleVis if you just want to say hello or ask a question first.",
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
                            "Use Search when you already know roughly what you're after.",
                            "Open Forums, the Blog, Guides, Podcasts, or the App Directory when you'd rather just browse.",
                            "Use the pickers and filters to narrow by content type, tag, platform, category, or saved state.",
                            "Scroll to the end of a list and more content loads automatically — no need to tap anything.",
                        ]),
                        .note("VoiceOver users can jump by headings in areas that support category or alphabetical navigation. Low-vision and sighted users can scan the same section headings visually."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-save-follow",
                    title: "Save, Follow, Recommend, and Mark as Read",
                    summary: "Keep track of what matters to you, and clear the rest when you're done with it.",
                    content: [
                        .steps([
                            "Find a topic, app, blog post, guide, podcast episode, or other card you want to keep track of.",
                            "Open its action menu, or long-press the card.",
                            "Choose Save to keep it in For You > Saved.",
                            "Choose Follow if you'd like to hear about future activity.",
                            "On an app, choose Recommend if you want to give it a public thumbs-up — it'll show up in For You > Recommended.",
                            "Choose Mark as Read to clear the new-activity flag without opening the item.",
                            "On Home, use Mark All as Read when you'd rather just reset everything at once.",
                        ]),
                        .tip("VoiceOver users can reach these through the Actions rotor on any content card. Sighted and low-vision users can long-press the same cards to open the same menu."),
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
                            "Tap Rewrite if you'd like a hand smoothing out the tone before you post.",
                            "If AppleVis notices your draft isn't in English, it'll offer to translate it for you.",
                            "Glance at any guideline reminder that pops up — it's a friendly heads-up, not a roadblock.",
                            "Submit your post.",
                        ]),
                        .warning("AppleVis posts should be in English — but don't worry if that's not your first language. The app can help translate your draft before you send it."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-podcast",
                    title: "Play and Queue Podcasts",
                    summary: "Play episodes, build a queue, and control playback from anywhere.",
                    content: [
                        .steps([
                            "Open Podcasts.",
                            "Choose an episode and press Play.",
                            "Control playback from the mini player at the bottom of any tab, the full player, the Lock Screen, Dynamic Island, Control Center, or AirPods.",
                            "Use Add to Queue or Play Next to line up what plays next — once an episode ends, the next one in your queue starts automatically.",
                            "Skip ahead with the next-track button on the Lock Screen or your AirPods; go back to the start of the current episode with previous-track.",
                            "Download an episode when you want to listen offline.",
                            "Head to Settings > Podcasts to fine-tune speed, skip intervals, sleep timer, voice boost, trim silence, and auto-play.",
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
                            "Scroll to Bug Tracker and choose iOS / iPadOS Bugs or macOS Bugs.",
                            "Active is selected by default — switch to All Bugs to include ones that have already been fixed.",
                            "Scroll through the list, or type a keyword in the search field to narrow it down.",
                            "Tap a bug card to read the full report: description, steps to reproduce, workaround, version information, and Apple Feedback ID.",
                            "On an active bug, tap Report to Apple to open Feedback Assistant and add your own report — the more reports Apple sees, the more likely a fix.",
                            "Tap Save to keep the report in For You for easy reference.",
                            "Tap Share to send the report link to someone else.",
                            "To submit a new bug, head back to Discover, scroll to Contribute, and tap Submit a Bug Report — a guided wizard opens right inside the app.",
                        ]),
                        .tip("Filing your own report in Apple's Feedback Assistant for the same bug helps raise its priority. Always include your device model, OS version, and exact steps to reproduce."),
                        .note("VoiceOver users: each bug card announces its severity, status, first-seen version, and fix version as a single accessibility label, so there's no need to swipe through individual elements on the card."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-low-vision",
                    title: "Low Vision Setup",
                    summary: "A quick setup path for larger text, contrast, motion, and visual comfort.",
                    content: [
                        .steps([
                            "Open Settings > Appearance and pick a theme that feels comfortable — including High Contrast Light or High Contrast Dark, if you want the most contrast available.",
                            "Choose a Comfortable or Compact card density, depending on how much you like fitting on a screen at once.",
                            "Open iOS Settings > Display & Text Size to adjust Dynamic Type, Bold Text, Button Shapes, Reduce Transparency, and Increase Contrast.",
                            "Open Settings > Accessibility in AppleVis to see which iOS accessibility settings the app is already picking up on.",
                        ]),
                        .tip("Liquid Glass and blur effects automatically step back to solid surfaces when Reduce Transparency or a high-contrast theme is on."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-replay-welcome-tour",
                    title: "Replay the Welcome Tour",
                    summary: "Revisit the guided tour of Home, Discover, For You, and Profile & Settings, organized chapter by chapter.",
                    content: [
                        .body("The Welcome Tour is an optional, chapter-by-chapter walkthrough shown after setup — one chapter per tab, each short enough to finish on its own. You can replay it whenever you like — it never repeats on its own once you've seen it."),
                        .steps([
                            "Open Profile and Settings.",
                            "Scroll to Replay Welcome Tour and tap it.",
                            "The tour starts fresh from the beginning. Use Leave Tour to pause and resume later or skip it completely, or Back to revisit a step.",
                        ]),
                        .tip("Leave Tour is available on every step and lets you pause — a Resume Tour button then appears so you can pick up right where you left off — or skip the tour completely if you're done with it. At the end of each chapter, an Explore option also takes you to the real screen right away."),
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
                    summary: "AppleVis is built for more than one way of using an iPhone.",
                    content: [
                        .body("AppleVis isn't built around just one way of getting around. It supports direct touch, VoiceOver, braille displays, Switch Control, Voice Control, Dynamic Type, high-contrast themes, reduced motion, reduced transparency, and hardware keyboards — because the people who use it don't all get around the same way."),
                        .heading("How instructions are written"),
                        .body("Most Help articles describe the general action first, and add extra detail only where an access method genuinely needs it — a note like \"VoiceOver users can...\" or \"Low-vision users may prefer...\" so the guide stays useful for everyone, not just one group."),
                        .heading("AppleVis's own accessibility controls"),
                        .body("Beyond what iOS already gives you, Settings > Accessibility has VoiceOver Detail Level — how much AppleVis announces as you navigate forum topics, apps, and podcast episodes. Everyday behavior settings that aren't specific to any access method — tips, Home's startup behavior, search auto-focus, and how web links open — moved to Settings > General, since a sighted user is just as likely to want those adjusted."),
                        .heading("A few purely visual touches"),
                        .body("A handful of small animations exist only for sighted and low-vision users glancing at the screen — nothing about them changes what VoiceOver, Switch Control, or a braille display report, and all of them turn off automatically if Reduce Motion is on. If you notice one of these and wondered whether something glitched, it didn't:"),
                        .bullets([
                            "The Save, Follow, and Recommend icons at the bottom of a topic, app, episode, or post give a small bounce the moment you tap them, alongside the confirmation sound.",
                            "Switching themes — in Settings > Appearance, or during setup — crossfades between color schemes instead of snapping instantly.",
                            "A small \"NEW\" or \"N NEW\" badge on a card pops in with a little spring as you scroll to it, rather than just appearing flat.",
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
                            "Double-tap to activate whatever's in focus.",
                            "Use headings to jump between major sections.",
                            "With focus on a content row, set the rotor to Actions and swipe up or down to reach things like Save, Follow, Share, and (on apps) Recommend, then double-tap to activate one. Sighted users can reach the same actions by swiping the row, or with a long-press menu.",
                            "Two-finger scrub to go back.",
                            "Two-finger double-tap to play or pause podcasts from anywhere in the app.",
                        ]),
                        .note("Most list screens move VoiceOver focus to the first useful item once they've finished loading, so you're not left hunting for the start of the list."),
                        .heading("VoiceOver Detail Level"),
                        .body("Settings > Accessibility > VoiceOver Detail Level controls how much AppleVis announces when you navigate forum topics, apps, and podcast episodes."),
                        .bullets([
                            "Simple (Fastest) — just the title and content type.",
                            "Normal (Recommended) — title, plus author and comment count.",
                            "All (Most Detailed) — everything: title, author, comment count, posted date, and last comment time.",
                        ]),
                        .tip("Normal is a solid default — try All if you want every detail read every time, or Simple if you'd rather scan quickly and only check details when you actually need them."),
                    ],
                    contentType: .accessibilityLesson
                ),
                HelpArticle(
                    id: "accessibility-braille",
                    title: "Braille Display Tips",
                    summary: "How braille users can move efficiently through Help and content.",
                    content: [
                        .bullets([
                            "Use headings to jump between sections in Help, Settings, Discover, and longer articles.",
                            "Article titles and summaries are kept short on purpose, so they fit better on a braille display.",
                            "Step lists are structured so each step lands as its own separate item.",
                            "When a label runs long, check for a shorter heading or action name first, and read the hint only if you need more.",
                        ]),
                    ],
                    contentType: .accessibilityLesson
                ),
                HelpArticle(
                    id: "accessibility-low-vision",
                    title: "Low Vision and Visual Comfort",
                    summary: "Themes, contrast, Dynamic Type, and motion settings.",
                    content: [
                        .bullets([
                            "Use Appearance to choose System, Light, Dark, or a high-contrast theme.",
                            "Use Card Density (Comfortable or Compact) to control how much fits on screen at once.",
                            "Use Dynamic Type in iOS Settings to enlarge text throughout the app.",
                            "Use Reduce Motion to shorten or remove animations.",
                            "Use Reduce Transparency to swap translucent surfaces for solid backgrounds.",
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
                        .body("When you open AppleVis, Home greets you — a little differently depending on whether you're signed in — and settles you back right where you left off. The What's New area near the top keeps a running tally of what's happened since your last visit."),
                        .heading("Filtering the feed"),
                        .bullets([
                            "All shows everything your feed is set up to include.",
                            "New narrows it down to just what's happened since you were last here.",
                            "Mouse Recap gives you a shareable weekly or monthly digest of new accessible apps, podcast episodes, popular discussions, guides, and blog posts.",
                        ]),
                        .heading("Keeping it tidy"),
                        .bullets([
                            "Mark as Read clears an item's new-activity flag without opening it.",
                            "Mark All as Read resets everything at once.",
                            "Customize Home (top-left) lets you choose which content types appear at all.",
                        ]),
                        .tip("Tap the Add button (top-right, the plus icon) to jump straight into starting a new forum topic or app entry — no need to go find Discover first."),
                        .note("If it's the anniversary of the day you joined AppleVis, Home will let you know with a little celebration. It only shows up once a year, right around your join date."),
                    ]
                ),
                HelpArticle(
                    id: "discover-overview",
                    title: "Discover Overview",
                    summary: "The central place for browsing AppleVis content.",
                    content: [
                        .bullets([
                            "Forums — community topics and replies.",
                            "AppleVis Blog — official posts and announcements.",
                            "Guides — tutorials, resources, and how-to articles.",
                            "Podcasts — the podcast feed, with filters, tags, queue, download, and playback all built in.",
                            "App Directory — apps by platform (iPhone and iPad, Mac, Apple Watch, or Apple TV) and category, with real accessibility comments from real members.",
                            "Bug Tracker — active and resolved accessibility bugs reported by the community.",
                            "Be My Eyes — launch Call a Volunteer, Be My AI, or the Service Directory without leaving the app.",
                            "RSS Feeds — copy or share feed links to follow AppleVis outside the app.",
                            "Social links — follow AppleVis on Mastodon, Facebook, or X from the Stay Updated section.",
                            "Search — site-wide search that can even translate a non-English query for you.",
                            "Contribute — submit a bug, blog post, podcast, or app entry, whenever you've got something to share.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "discover-bug-tracker",
                    title: "Bug Tracker",
                    summary: "Browse active and resolved accessibility bugs for iOS/iPadOS and macOS.",
                    content: [
                        .body("The Bug Tracker brings the AppleVis community bug database right into the app. Browse active and resolved accessibility bugs, read the full details, jump straight to Apple Feedback Assistant to help get issues fixed, and submit new bugs of your own using the in-app wizard."),
                        .heading("Opening the Bug Tracker"),
                        .steps([
                            "Open Discover.",
                            "Scroll to the Bug Tracker section.",
                            "Choose iOS / iPadOS Bugs or macOS Bugs.",
                        ]),
                        .heading("Browsing bugs"),
                        .bullets([
                            "Active shows only open, unresolved bugs. All Bugs shows both active and fixed ones.",
                            "Each card shows the bug title, severity (Low, Medium, or High), status (Active or Fixed), the OS version it first appeared in, and the version it was fixed in, if known.",
                            "Each card also shows when the bug was first reported and last updated.",
                            "Use the search field to filter the current list by keyword.",
                            "Scroll to the end and more bug reports load automatically.",
                            "Pull down to refresh the list.",
                        ]),
                        .heading("Reading a bug report"),
                        .steps([
                            "Tap a bug card to open its full detail page.",
                            "Read the description, steps to reproduce, and any known workaround.",
                            "Check Bug Details for platform, first-seen version, fixed-in version, device, how often it happens, and the Apple Feedback ID.",
                            "Use Report to Apple on active bugs to open Feedback Assistant and file your own report.",
                            "Use Share to send the report link along.",
                            "Use Save to add it to your For You saved items.",
                        ]),
                        .tip("VoiceOver users: the \"Bug Details\" heading is announced as a real header, so you can jump straight to it with the headings rotor."),
                        .heading("Submitting a new bug"),
                        .steps([
                            "Head back to Discover and scroll to Contribute.",
                            "Tap Submit a Bug Report.",
                            "You'll need to be signed in — a sign-in prompt appears if you're not.",
                            "A three-step guided wizard opens inside the app. See \"Submitting a Bug Report\" in Community and Posting for the full walkthrough.",
                        ]),
                        .heading("Severity levels"),
                        .bullets([
                            "High — significantly affects core functionality, or makes a feature completely inaccessible.",
                            "Medium — impairs usability, but a workaround exists or the impact is partial.",
                            "Low — minor, causing only cosmetic or infrequent issues.",
                        ]),
                        .note("The Bug Tracker is served live from the AppleVis API, so the list is always up to date — no app update needed when new bugs get added to the website."),
                    ]
                ),
                HelpArticle(
                    id: "discover-be-my-eyes",
                    title: "Be My Eyes",
                    summary: "Launch Call a Volunteer, Be My AI, or the Service Directory directly from AppleVis.",
                    content: [
                        .body("AppleVis is a Be My Eyes company, so the Be My Eyes section in Discover gives you quick access to three free visual-assistance services without having to hunt them down yourself."),
                        .heading("Available services"),
                        .bullets([
                            "Call a Volunteer — connects you by live video with a sighted volunteer who can see through your phone camera, 24 hours a day, in 185 languages.",
                            "Be My AI — an AI assistant that describes images, reads text, and answers visual questions in 36 languages.",
                            "Service Directory — a searchable directory of accessible customer service channels at hundreds of companies and government departments worldwide.",
                        ]),
                        .heading("How to use it"),
                        .steps([
                            "Open Discover.",
                            "Scroll to the Be My Eyes section.",
                            "Tap the service you want — Call a Volunteer, Be My AI, or Service Directory.",
                            "If Be My Eyes is already installed, it opens straight to that feature.",
                            "If it's not installed, the App Store listing opens instead so you can download it.",
                        ]),
                        .note("All three services are completely free. Be My Eyes is a separate app, so tapping any of these links leaves AppleVis and opens the Be My Eyes app (or its App Store page)."),
                        .tip("You'll also find Be My Eyes in the AppleVis App Directory, complete with community accessibility comments and ratings."),
                    ]
                ),
                HelpArticle(
                    id: "discover-filters",
                    title: "Filters, Tags, Categories, and Headings",
                    summary: "How to narrow lists down quickly.",
                    content: [
                        .body("Filters and pickers help you cut a long list down to size. Podcasts can be filtered by content type and tags. The App Directory can be filtered by platform and category, and categories announce their counts, like \"Books, 26 apps.\""),
                        .note("VoiceOver users can navigate by heading wherever it's available. Sighted and low-vision users can scan the same headings visually."),
                    ]
                ),
                HelpArticle(
                    id: "discover-rss-feeds",
                    title: "RSS Feeds",
                    summary: "Copy or share links to follow AppleVis outside the app.",
                    content: [
                        .body("If you like keeping up through an RSS reader instead of (or alongside) the app, Discover has a dedicated RSS Feeds page just for that."),
                        .bullets([
                            "Copy or share the main AppleVis feed, or narrow it down to just Apps, Blogs, Guides, Reviews, Forums, Apple-only forum posts, or Podcasts.",
                            "Every feed link works in any RSS reader you already use.",
                        ]),
                        .steps([
                            "Open Discover.",
                            "Scroll to Stay Updated and tap RSS Feeds.",
                            "Tap Copy or Share next to whichever feed you'd like.",
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
            description: "Your personal hub — saved items, following, recommended apps, queue, and downloads — plus how to search across AppleVis.",
            articles: [
                HelpArticle(
                    id: "foryou-overview",
                    title: "Using For You",
                    summary: "Your personal AppleVis hub: saved items, following, recommended apps, podcast queue, and downloads.",
                    content: [
                        .body("For You is your own corner of AppleVis — not a recommendation feed, not an algorithm guessing at what you might like. It only ever shows you things you chose to keep, follow, recommend, queue, or download."),
                        .heading("The five sections"),
                        .bullets([
                            "Saved — topics, apps, guides, blog posts, and episodes you've bookmarked. Filter by content type if you're after something specific.",
                            "Following — things you're keeping an eye on, with a notification when there's new activity, if you've turned those on.",
                            "Recommended — apps you've given a public thumbs-up. Changed your mind about one? Swipe to remove it.",
                            "Queue — podcast episodes lined up to play next, in order. Reorder or remove anything you like.",
                            "Downloads — episodes saved to this device so you can listen without a connection.",
                        ]),
                        .tip("Use the Section picker at the top of For You to jump between Saved, Following, Recommended, Queue, and Downloads. VoiceOver announces which one's selected, and you can also swipe up or down on the picker to move between them."),
                    ],
                    contentType: .guide,
                    relatedLinks: [
                        RelatedLink(label: "Save, Follow, Download, and Recommend: What\u{2019}s the Difference?", type: .faq, destination: .article("foryou-save-follow-download-faq")),
                    ]
                ),
                HelpArticle(
                    id: "foryou-save-follow-download-faq",
                    title: "Save, Follow, Download, and Recommend: What\u{2019}s the Difference?",
                    summary: "Four different ways to keep content close, and when to reach for each one.",
                    content: [
                        .faq(question: "What does Save do?", answer: "Save bookmarks a topic, app, guide, blog post, or episode so you can find it again quickly in For You > Saved. It won't download anything or notify you of updates — it's just a bookmark."),
                        .faq(question: "What does Follow do?", answer: "Follow keeps an item in For You > Following and, where it's supported, notifies you when something changes — a new reply on a forum topic, for example. Reach for Follow when you want to keep up with something over time."),
                        .faq(question: "What does Download do?", answer: "Download is for podcast episodes only — it saves the audio to your device so you can listen without a connection. Downloaded episodes show up in For You > Downloads."),
                        .faq(question: "What does Recommend do?", answer: "Recommend is specifically for apps — a public thumbs-up that tells other members you'd genuinely vouch for one. You'll find everything you've recommended in For You > Recommended, and you can take it back any time."),
                        .faq(question: "Can I do more than one at once?", answer: "Absolutely — a podcast episode can be saved, followed, and downloaded all at the same time, and an app can be saved and recommended together. Each one's independent, so removing one doesn't touch the others."),
                    ],
                    contentType: .faq
                ),
                HelpArticle(
                    id: "search-overview",
                    title: "Using Search",
                    summary: "Find discussions, apps, guides, podcast episodes, bug reports, and Help — all from one place.",
                    content: [
                        .body("Search is the fastest way to find something when you already have a rough idea what you're after — discussions, apps, guides, podcast episodes, bug reports, or Help articles, all from one place: the Search tab, or the search field built into the top of Discover."),
                        .heading("Results come grouped"),
                        .bullets([
                            "Forum Topics — community discussions.",
                            "Apps — entries from the App Directory.",
                            "Resources — guides and tutorials.",
                            "Blogs — posts from the AppleVis Blog.",
                            "Podcasts — episodes from any AppleVis podcast.",
                            "Bug Reports — accessibility bugs in the tracker.",
                        ]),
                        .tip("If your query looks like it's in a language other than English, AppleVis may offer to translate it for you — search works best in English."),
                        .note("VoiceOver announces a concise result count and category breakdown up front, like \"12 results found in 4 categories,\" and each section heading gives you more detail from there."),
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
                            "Use the filters — Recent, New, Unread, Since Last Visit, Following, or Saved — to narrow things down.",
                            "Follow a topic and it lands in For You > Following, with a nudge when there's a new reply, if you want one.",
                            "Settings > Home Feed controls which content types show up in your Home feed by default and whether it's limited to Apple-only topics.",
                            "Head to Settings > Notifications to fine-tune which of this actually pings you.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "community-writing-tools",
                    title: "Writing Help and Translation",
                    summary: "Rewrite, translate to English, guideline reminders, and reading content in your own language.",
                    content: [
                        .heading("Writing in English"),
                        .body("Before you post a topic, reply, or comment, AppleVis can lend a hand — smoothing out your tone, translating a draft that isn't in English, or gently flagging something the guidelines checker thinks might cause trouble."),
                        .bullets([
                            "Rewrite polishes your draft's clarity and tone, without changing what you're actually trying to say.",
                            "If your draft looks like it's not in English, AppleVis offers to translate it for you.",
                            // Was "The guidelines checker is purely advisory — it never
                            // blocks you from posting," which isn't accurate:
                            // ContentSubmissionPolicy does block a small set of things
                            // (image links, strong vulgar language, a very hostile tone,
                            // non-English text) before they can be submitted at all —
                            // only GuidelinesChecker's broader, softer reminders are
                            // purely advisory. Flagged during the Community Agreement
                            // audit; corrected to describe both accurately.
                            "Most guideline reminders are just a friendly heads-up you can dismiss and keep writing. A few things — like image links, strong language, or posting in a language other than English — do need to be fixed before you can post.",
                            "If AI helped you write something, a quick note saying so is appreciated by the community.",
                        ]),
                        .heading("Reading AppleVis in your own language"),
                        .body("AppleVis is written and moderated entirely in English — it's the one shared language that lets our whole community read and reply to each other in the same place, and lets our editorial team review everything that's posted. But you don't have to read it in English: turn on Auto-Translate in Settings, and blog posts, forum topics, app entries, podcast episodes, guides, bug reports, comments, and this Help section itself can all be translated into your language automatically, right on your device."),
                        .bullets([
                            "Translation happens on your iPhone — nothing you read is sent to an outside server.",
                            "It's automatic, but never perfect — look for the small \"Translated\" note, and tap Show Original any time to see the exact English text.",
                            "Links inside translated text still go exactly where they're supposed to.",
                        ]),
                        .tip("If you use VoiceOver, translated text is automatically spoken in the correct voice and pronunciation for that language — you don't need to change your VoiceOver language setting yourself just to read translated AppleVis content."),
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
                    summary: "Why some words show up masked, what always gets blocked from posting, and how to turn it off.",
                    content: [
                        .heading("Two separate things"),
                        .body("AppleVis has two separate systems for keeping the community welcoming: one controls what you're allowed to post, the other controls what you see. They work independently — changing one never changes the other."),
                        .heading("What you can post"),
                        .body("Strong or explicit language is never allowed in anything you post through the app — a comment, a reply, a topic, a review, a message, anything. That's true for everyone, all the time, and it isn't something Settings can turn off."),
                        .heading("What you see"),
                        .body("Settings > General has a Filter Profanity toggle, on by default. When it's on, a wider range of language — including milder words the site itself allows — shows up masked, like \"s***\", instead of spelled out. Turn it off any time if you'd rather see everything exactly as written."),
                        .note("Turning this off only changes what you see. It never changes what you're allowed to post — that rule applies no matter what."),
                        .heading("Why this exists"),
                        .body("Partly, it's simply about keeping AppleVis feeling welcoming, since this community spans a wide range of ages and comfort levels. But there's a bigger reason too: Apple sets specific rules about how much strong language an app can contain for the age rating it's listed under, and filtering by default helps AppleVis stay compliant with those rules as the community keeps growing — not something we want to take a chance on."),
                        .heading("If something slips through"),
                        .body("No automatic filter catches everything perfectly. If you ever come across language that shouldn't be there, use Report on that comment or post to let our editorial team know — that's exactly what it's there for."),
                        .faq(
                            question: "Does turning the filter off let me post anything I want?",
                            answer: "No. Posting rules never change based on this setting — it only affects what you see from other people, never what you're allowed to write yourself."
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
                        .body("You can edit anything you've written, right inside the app — the Edit option only ever shows up on content you actually authored."),
                        .heading("Forum replies and topic comments"),
                        .steps([
                            "Open the forum topic or episode comments page.",
                            "Find your reply and hold down on it to open the action sheet.",
                            "Choose Edit Comment.",
                            "The Edit screen opens with your original text loaded.",
                            "Make your changes.",
                            "Tap Save in the top-right corner.",
                        ]),
                        .heading("App, blog, and guide comments"),
                        .steps([
                            "Open the app, blog post, or guide where you left a comment.",
                            "Long-press your comment to open the action sheet.",
                            "Choose Edit Comment.",
                            "Edit the text and tap Save.",
                        ]),
                        .note("Edits apply immediately — no need to reload the page to see them reflected."),
                        .tip("VoiceOver users can also reach Edit through the rotor's Actions, without ever opening the long-press menu."),
                    ]
                ),
                HelpArticle(
                    id: "community-delete-post",
                    title: "Deleting Your Posts and Comments",
                    summary: "How to permanently remove a forum reply, blog comment, app comment, or podcast comment you've written.",
                    content: [
                        .body("You can permanently delete anything you've written. Once it's gone, it's gone — deleted content can't be recovered."),
                        .steps([
                            "Find your post or comment.",
                            "Hold down on it to open the action sheet.",
                            "Choose Delete Comment.",
                            "Confirm by tapping Delete.",
                        ]),
                        .warning("Deletion is permanent — there's no undo. If you just want to fix the wording, use Edit instead."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-bug",
                    title: "Submitting a Bug Report",
                    summary: "How to report a new accessibility bug using the three-step in-app wizard.",
                    content: [
                        .body("Found an accessibility bug that's not already in the tracker? You can report it right from the app — you'll just need to be signed in, and you'll need to have already filed it with Apple's Feedback Assistant first. AppleVis doesn't accept reports that skip that step."),
                        .heading("Before you start"),
                        .bullets([
                            "Check the Bug Tracker to make sure it isn't already reported.",
                            "File it with Apple's Feedback Assistant first, and keep the FB number handy — you'll need it.",
                            "Sign in from Profile if you haven't already.",
                        ]),
                        .heading("Step 1 — Describe the Bug"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit a Bug Report.",
                            "Give it a short, specific title — something like \"VoiceOver skips toolbar buttons in Mail.\"",
                            "Add your email address, in case the team needs to follow up.",
                            "Write a description: what you expected, what actually happened, and how to reproduce it. Thirty characters minimum, but more detail always helps.",
                            "Tap Continue.",
                        ]),
                        .tip("Tap Rewrite on this step if you'd like a hand tightening up your description."),
                        .heading("Step 2 — Environment"),
                        .steps([
                            "Choose the platform — iOS, iPadOS, or macOS.",
                            "Enter the software version where you saw the bug.",
                            "Say whether you can reliably reproduce it.",
                            "Enter your Apple Feedback number — it needs to start with \"FB\" and match the report you already filed with Apple.",
                            "Choose how you'd like to be credited if the report helps lead to a fix: by name, by your AppleVis username, or anonymously.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 3 — Review and Submit"),
                        .body("Look everything over, then tap Submit. A thank-you screen confirms it went through, and the AppleVis team takes it from there."),
                        .note("Reports are reviewed before they're published — duplicates, vague descriptions, or reports missing a valid Apple Feedback number won't make it through."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-blog",
                    title: "Submitting a Blog Post",
                    summary: "How to submit a blog post draft for the editorial team to consider, using the three-step in-app wizard.",
                    content: [
                        .body("Got a tip, a review, a personal story, or something else worth sharing with the AppleVis community? You can submit a blog post draft right from the app — the editorial team reviews it before anything's published, so this starts a conversation rather than posting instantly. You'll need to be signed in."),
                        .heading("Step 1 — Title & Category"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit a Blog Post.",
                            "Give your post a clear title.",
                            "Pick the category that fits best.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Your Content"),
                        .steps([
                            "Enter a valid email address — the editorial team may reply to follow up.",
                            "Write a few sentences on why this post would interest AppleVis readers — this one's required; it's how editors get a feel for your pitch.",
                            "Write, import, or paste your actual draft — minimum 50 characters.",
                            "Use Import File to pull in a text or Markdown file from Files or iCloud Drive, or Paste to grab whatever's already on your clipboard.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 3 — Review and Submit"),
                        .body("Check everything over — title, category, your pitch, and your draft — then tap Submit. A thank-you screen confirms it's on its way, and the editorial team will follow up with their decision."),
                        .note("The AppleVis Editorial Team reviews every submission and decides whether it gets published — they'll reach out either way."),
                        .tip("Cancel is available from any step if you decide not to submit. On step 2 or the review screen, use Back to return to the previous step without discarding your draft."),
                        .tip("You can also share text straight into AppleVis from almost any other app. Select some text, tap Share, choose AppleVis, and the blog wizard opens with it already loaded."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-podcast",
                    title: "Submitting a Podcast",
                    summary: "How to submit a podcast episode using the two-step in-app wizard.",
                    content: [
                        .body("Make a podcast about accessibility, Apple products, or blindness? You can submit an episode for the AppleVis team to consider — you'll just need to be signed in."),
                        .heading("Step 1 — Episode & Audio"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit a Podcast.",
                            "Write a description of the episode — what it covers, who it's for. Twenty characters minimum.",
                            "Tap Choose Audio File and pick your episode from Files, iCloud Drive, or any connected storage provider.",
                            "Tap Rewrite if you'd like a hand polishing the description.",
                            "Tap Continue once you've got both a description and a file selected.",
                        ]),
                        .heading("Step 2 — Review and Submit"),
                        .body("Double-check your description and the file you picked, then tap Submit. Keep the app open while it uploads. A thank-you screen confirms it's on its way, and the team will follow up."),
                        .note("The AppleVis Editorial Team reviews every submission and reaches out with their decision."),
                        .tip("You can also share a podcast episode straight from apps like Podcasts, Overcast, or Spotify — or share an audio file itself from Files. Choose AppleVis in the share sheet, and it lands right in this wizard."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-app",
                    title: "Submitting an App Entry",
                    summary: "How to add an accessible app to the App Directory using the three-step wizard.",
                    content: [
                        .body("Want to add an app to the App Directory? Just two ground rules first: you need to have actually used the app yourself, not just read about it — and you can't submit an app you develop, publish, or are otherwise affiliated with. You'll need to be signed in."),
                        .heading("Before you begin"),
                        .bullets([
                            "Check the App Directory first, in case it's already listed.",
                            "Confirm you've personally used the app and can speak to its accessibility.",
                            "Confirm you're not the developer, publisher, or otherwise affiliated with it.",
                        ]),
                        .heading("Step 1 — Find the App"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit an App.",
                            "Confirm the two checkboxes on the Before You Begin screen.",
                            "Choose the platform: iPhone and iPad, Mac, Apple Watch, or Apple TV.",
                            "Search by name, or paste an App Store URL — or tap Enter Details Manually if the app isn't on the App Store (some Mac apps genuinely aren't).",
                            "Select the right result and tap Continue.",
                        ]),
                        .heading("Step 2 — App Details"),
                        .body("What you'll fill in here depends on the platform. Confirm the details pulled from the App Store, then share your accessibility assessment."),
                        .bullets([
                            "For iPhone and iPad apps: separate ratings for VoiceOver Performance, Button Labelling, and Usability, plus the devices the app supports.",
                            "For Mac, Apple Watch, and Apple TV apps: a single combined Usability rating.",
                            "Every platform asks for detailed Accessibility Comments — twenty characters minimum, but the more you share, the more useful it is to the next person reading it.",
                        ]),
                        .tip("Tap Rewrite on the Accessibility Comments field if you'd like a hand polishing what you've written."),
                        .heading("Step 3 — Review and Submit"),
                        .body("Look everything over, then tap Submit. A thank-you screen confirms it went through — the AppleVis team reviews every submission before it appears in the directory."),
                    ]
                ),
                HelpArticle(
                    id: "community-edit-profile",
                    title: "Editing Your Profile",
                    summary: "Update your display name, bio, interests, links, and who can reach you — plus a few nice surprises along the way.",
                    content: [
                        .steps([
                            "Open the Profile tab.",
                            "Tap Edit Profile near the top of the Account section.",
                            "Update whatever you'd like: display name, bio, location, interests, the Apple products you use, your links, time zone, and who's allowed to contact you.",
                            "Tap Save.",
                        ]),
                        .bullets([
                            "Display Name — what other members see on your posts.",
                            "Bio — a short description of yourself. Not sure where to start? Tap Help Me Write This and answer a couple of quick questions for a draft you can edit or use as-is.",
                            "Location — just your country now, picked from a list, rather than a free-text city.",
                            "Interests — accessibility tools, Apple products, whatever you'd like to share.",
                            "Apple Products Owned — check off the devices you use from a simple list, shown on your public profile.",
                            "Website, X/Twitter, Facebook, Mastodon — your links elsewhere.",
                            "Time Zone — pick it manually, or let AppleVis suggest the one your device is already set to.",
                            "Allow Other Members to Contact Me — lets other signed-in members message you privately without ever seeing your email address. You can turn this off any time.",
                        ]),
                        .heading("Your account anniversary"),
                        .body("Once a year, right around the day you joined, Home marks the occasion with a small celebration — a little confetti and a friendly note you can share if you'd like."),
                        .heading("Messaging another member"),
                        .body("Tap anyone's name to open their profile. If they've left contacting them turned on, you'll see a Contact button — it sends a private message through AppleVis without ever revealing your email address to them, unless they choose to reply."),
                        .note("Changes save to your AppleVis account right away, and show up on the website and for other members immediately."),
                    ]
                ),
                HelpArticle(
                    id: "community-report-comment",
                    title: "Reporting a Comment",
                    summary: "Flag spam, harassment, or anything else that shouldn't be there.",
                    content: [
                        .body("See a comment or reply that crosses a line — spam, harassment, something offensive, or just plain wrong? You can report it straight to the editorial team, right from wherever you found it."),
                        .steps([
                            "Long-press the comment (or use the VoiceOver rotor's Actions) and choose Report Comment.",
                            "Pick the reason that fits best: Spam or Advertising, Harassment or Abuse, Inappropriate or Offensive Content, Off-Topic, Misinformation, or Something Else.",
                            "Add any extra details that might help the team review it — optional, but appreciated.",
                            "Confirm your email (already filled in if you're signed in), in case the team needs to follow up.",
                            "Review everything and tap Send Report.",
                        ]),
                        .note("You don't need to be signed in to report a comment — though if you are, your name is filled in automatically."),
                        .tip("Reporting a comment doesn't remove it right away — it just lets the editorial team know to take a look."),
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
                    summary: "Browse apps by platform, category, search, and real accessibility comments.",
                    content: [
                        .body("The App Directory is where AppleVis members document how well apps actually work with accessibility tools — VoiceOver, braille, Switch Control, and beyond. Browse by platform (iPhone and iPad, Mac, Apple Watch, or Apple TV), then by category."),
                        .bullets([
                            "Open an app's page for its description, developer, category, ratings, and every accessibility comment members have left.",
                            "Accessibility Consensus gives you a quick, AI-generated summary of what commenters report — handy before reading every comment yourself.",
                            "Tap Open in App Store to download or buy it — that part's always handled by Apple, never inside AppleVis.",
                            "Save or Follow an app to find it again in For You, or Recommend it to give it a public thumbs-up — everything you've recommended lives in For You > Recommended.",
                            "Share an App Store link into AppleVis from anywhere to look up, or submit, an app.",
                            "If an app's App Store link stops working, its page lets you know the listing may no longer be available.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "content-podcasts",
                    title: "Podcasts",
                    summary: "Playback, queue, chapters, downloads, Dynamic Island, AirPods, and settings.",
                    content: [
                        .bullets([
                            "Play, pause, seek, skip forward and back, and change speed from the player or the mini player at the bottom of the screen.",
                            "Use Add to Queue or Play Next to control what plays after the current episode.",
                            "Download episodes for offline listening.",
                            "Navigate chapters from the chapter strip when an episode has chapter markers.",
                            "The Lock Screen shows the episode title, artwork, progress bar, and playback controls.",
                            "Dynamic Island shows the episode title and playback state on supported iPhone models while you use other apps.",
                            "AirPods: double-tap to play or pause. With a queue going, the next-track gesture skips to the next episode, and previous-track restarts the current one from the beginning.",
                            "Control Center shows a Now Playing card with artwork, title, and controls.",
                        ]),
                        .tip("Fine-tune playback in Settings > Podcasts: speed, skip intervals, auto-play, Trim Silence, Voice Boost, an equalizer (Flat, Speech, Bass Boost, or Treble Boost), a sleep timer, and resume rewind."),
                    ]
                ),
                HelpArticle(
                    id: "content-blog-guides",
                    title: "Blogs and Guides",
                    summary: "Read official updates, guides, tutorials, resources, and comments.",
                    content: [
                        .body("The AppleVis Blog carries official posts and announcements. Guides holds tutorials, how-to articles, resources, events, and developer content. Both support reading, saving, sharing, comments, summaries, and discussion tools right inside the app."),
                    ]
                ),
                HelpArticle(
                    id: "content-bugs",
                    title: "Bug Tracker",
                    summary: "How the AppleVis bug database works, and what each field means.",
                    content: [
                        .body("The Bug Tracker is a community-maintained database of accessibility bugs on Apple platforms. Every report is reviewed and classified by the AppleVis team before it's published."),
                        .heading("What each field means"),
                        .bullets([
                            "Title — a brief, descriptive name for the bug.",
                            "Platform — iOS/iPadOS or macOS.",
                            "Status: Active — present in the current release and not yet fixed.",
                            "Status: Fixed — Apple has released an update that resolves it.",
                            "Severity: High — makes a key accessibility feature completely unavailable.",
                            "Severity: Medium — impairs usability, but a workaround exists.",
                            "Severity: Low — minor, and only causes cosmetic or infrequent issues.",
                            "First Seen In — the OS version where the bug was first noticed.",
                            "Fixed In — the version where Apple shipped a fix, if known.",
                            "Steps to Reproduce — a numbered sequence to reliably trigger the bug.",
                            "Workaround — any known way to reduce the impact until Apple fixes it.",
                            "Apple Feedback ID — the reference number filed with Apple Feedback Assistant. Tapping it opens Feedback Assistant so you can file your own report on the same issue.",
                            "Device — the hardware used when the bug was first reported.",
                            "How Often — Rarely, Sometimes, or Always.",
                        ]),
                        .heading("Why filing your own Apple report helps"),
                        .body("Apple uses the volume of Feedback Assistant reports as one signal of how widespread a bug is. The more people who file a report on the same issue, the more it stands out. Use Report to Apple on any active bug to open Feedback Assistant and add your voice."),
                        .tip("Include your exact device model, OS version, and the steps to reproduce from the report when filing with Apple. Referencing the Apple Feedback ID from an existing AppleVis report helps too."),
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
                    summary: "Themes, Liquid Glass, card density, contrast, and visual comfort.",
                    content: [
                        .body("Appearance is where AppleVis starts to feel like yours. Pick a theme grouped by System, Light, Dark, or High Contrast, and choose a Comfortable or Compact card density depending on how much you like fitting on a screen. Liquid Glass gives supported surfaces a soft, modern translucency, and steps back automatically to solid backgrounds when Reduce Transparency or a high-contrast theme is on."),
                    ]
                ),
                HelpArticle(
                    id: "settings-general",
                    title: "General",
                    summary: "Home's welcome behavior, tips, search auto-focus, and how web links open.",
                    content: [
                        .body("Settings > General holds everyday AppleVis behavior that isn't tied to any particular access method — a sighted user is just as likely to want these adjusted as anyone else."),
                        .bullets([
                            "Home Startup Behavior — how much Home says out loud when you open or return to it: Quiet (nothing spoken), Helpful (a short spoken welcome), or Detailed (that welcome plus an AI-generated summary of what's new).",
                            "Welcome Summary — a separate switch for the dismissable card on Home listing what's new since your last visit. This is about what's shown, not what's spoken — turn it off and Home stays visually quieter even if Home Startup Behavior is still speaking a welcome.",
                            "Auto-Focus Search Field — raises the keyboard the moment you open Search, so you can start typing right away.",
                            "Web Links — choose In-App Browser (stay inside AppleVis) or Default Browser (hand links to Safari or whatever browser you've set as default) for App Store pages, social links, legal pages, and Open in Browser actions throughout the app.",
                            "AppleVis Tips — short, friendly tips that pop up here and there, timed to save you a step.",
                        ]),
                        .tip("VoiceOver Detail Level is the one AppleVis-specific control that stayed in Settings > Accessibility, since it's genuinely about how much VoiceOver announces."),
                    ]
                ),
                HelpArticle(
                    id: "settings-notifications",
                    title: "Notifications",
                    summary: "Choose which AppleVis activity can reach you.",
                    content: [
                        .bullets([
                            "Replies to My Posts — automatically follows new forum topics and app entries you post, so replies notify you without following them yourself. Only applies going forward. Signed in only.",
                            "Mentions — someone mentions you by name. Signed in only.",
                            "Followed Topics — activity in anything you follow. Signed in only.",
                            "New Forum Topics — fresh discussions across the community.",
                            "New App Directory Entries — new or updated app listings.",
                            "New Podcast Episodes.",
                            "New Resources — new guides and tutorials.",
                            "New Comments — comments on anything, anywhere, not just things you follow. This one can get chatty.",
                        ]),
                        .note("You can also pick a notification sound and turn the app icon's badge count on or off. iOS notification permission is still controlled separately in iPhone Settings — if it's off there, nothing arrives no matter what's toggled here."),
                    ]
                ),
                HelpArticle(
                    id: "settings-privacy-sync",
                    title: "Privacy and Sync",
                    summary: "What syncs through iCloud, and how your account and local data are handled.",
                    content: [
                        .bullets([
                            "Saved & Sync controls what travels through iCloud: Saved Items, Following, Podcast Position, Podcast Queue, Read History, and Settings & Preferences — each is an independent toggle.",
                            "Privacy walks through exactly what AppleVis collects (just your email, username, and a push token), how your session is secured, and confirms there's no ad tracking.",
                            "Show What's New on Home controls whether Home displays a New view, a quick summary, and new-activity badges — reading history itself is always tracked on-device, so turning this off just keeps Home quieter without erasing anything.",
                            "Clear All Local Data wipes cached content, downloads, saved items, and local read history from this device — your account, cloud data, and app preferences aren't affected.",
                        ]),
                        .note("Apple Intelligence features process everything on-device — no post, comment, or search text is ever sent to a server."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-storage-cache",
                    title: "Storage and Cache",
                    summary: "Manage downloaded audio, cached content, and free up space.",
                    content: [
                        .body("Storage and Cache shows how much space AppleVis is using on this device, and gives you a few ways to manage it."),
                        .bullets([
                            "Downloaded podcast episodes kept for offline listening.",
                            "Cached images and content that make browsing faster.",
                            "Cache retention — 3, 6, or 12 months, or Keep Forever — how long cached content sticks around before it's cleaned up automatically.",
                        ]),
                        .steps([
                            "Open Settings > Storage and Cache.",
                            "Review the breakdown of downloads and cache size.",
                            "Use Clear Cached Content to remove cached content without touching downloads or saved items.",
                            "Use Clear Downloaded Episodes, or remove individual downloads from For You > Downloads, if you only want to free up specific ones.",
                        ]),
                        .tip("Clearing the cache never deletes downloaded episodes, saved items, or your account data — only temporary cached content."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-sounds-haptics",
                    title: "Sounds and Haptics",
                    summary: "Turn app sounds and vibration on or off, independently of each other.",
                    content: [
                        .body("Settings > Sounds & Haptics is where you decide how much AppleVis nudges you with sound and touch."),
                        .bullets([
                            "Confirmation Sounds — plays for things like saving, downloads finishing, and podcast play and pause.",
                            "Interface Sounds — plays for tab switching, picker changes, opening screens, and list refreshes. Off by default.",
                            "Haptic Feedback — vibrates for the same moments Confirmation Sounds covers, like saving, signing in, and errors. You can keep this on with sounds off, or the other way around — they're independent.",
                        ]),
                        .note("Sounds and haptics for errors and connectivity changes always play, no matter what's toggled here — those are important enough that AppleVis doesn't let you miss them."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-support",
                    title: "Profile and App Support",
                    summary: "Get in touch with the AppleVis team using the in-app contact wizard.",
                    content: [
                        .body("Profile includes a Contact AppleVis button that opens a native in-app contact wizard. Send a bug report, feedback, a suggestion, or a recommendation straight to the AppleVis team, without ever leaving the app."),
                        .tip("Choosing Bug Report in the wizard adds a system-information toggle. Turn it on to automatically include your app version and iOS version — handy when reporting a crash or something unexpected."),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "smart",
            title: "Smart Features and iOS Integrations",
            icon: "sparkles",
            description: "Apple Intelligence, translation, Siri phrases, Spotlight, Share Extension, Focus Filters, and Dynamic Island.",
            articles: [
                HelpArticle(
                    id: "smart-reading-writing",
                    title: "Reading, Writing, and Translation Tools",
                    summary: "Read Aloud, summaries, rewrite, and translation.",
                    content: [
                        .bullets([
                            "Read Aloud reads content out loud using your device's own speech — works on any device, no Apple Intelligence needed.",
                            "AI Summaries condense long threads, show notes, and app descriptions down to a couple of sentences — needs Apple Intelligence.",
                            "Accessibility Consensus turns an app's accessibility comments into one short, honest paragraph — needs Apple Intelligence.",
                            "Rewrite polishes your draft before you post it, without changing what you're trying to say — needs Apple Intelligence.",
                            "Translate steps in automatically when AppleVis notices your draft or search query isn't in English — needs Apple Intelligence.",
                        ]),
                        .note("Apple Intelligence features need iPhone 15 Pro or later (or any iPhone 16 model), running a recent iOS, with Apple Intelligence turned on in iOS Settings. See Apple Intelligence Features below for the full picture."),
                    ]
                ),
                HelpArticle(
                    id: "smart-siri-widgets",
                    title: "Siri and Spotlight",
                    summary: "Use AppleVis from system features outside the app.",
                    content: [
                        .heading("Siri phrases"),
                        .body("AppleVis registers a handful of voice shortcuts with Siri — say any of these any time, or add your own custom phrases from the Shortcuts app."),
                        .bullets([
                            "\"Hey Siri, open AppleVis\" — opens Home.",
                            "\"Hey Siri, open AppleVis Forums\" — opens Forums.",
                            "\"Hey Siri, show unread AppleVis topics\" — opens Forums filtered to Unread.",
                            "\"Hey Siri, resume AppleVis podcast\" — picks up your last episode right where you left off.",
                            "\"Hey Siri, play latest AppleVis podcast\" — starts the newest episode.",
                            "\"Hey Siri, search AppleVis\" — opens search.",
                            "\"Hey Siri, open AppleVis saved items\" — opens Saved in For You.",
                            "\"Hey Siri, what's new on AppleVis\" — speaks a summary of what's new since your last visit.",
                            "\"Hey Siri, report a bug to AppleVis\" — opens straight to the accessibility bug report form.",
                        ]),
                        .heading("Spotlight"),
                        .body("Spotlight can surface AppleVis topics, apps, podcasts, and resources right from iOS Search — anything you've opened gets indexed, so it's easy to find again later."),
                    ]
                ),
                HelpArticle(
                    id: "smart-apple-intelligence",
                    title: "Apple Intelligence Features",
                    summary: "What Apple Intelligence powers in AppleVis, which devices support it, and how to turn it on.",
                    content: [
                        .body("AppleVis uses Apple Intelligence to power several on-device AI features. Everything happens on your device — no text or content is ever sent to a server."),
                        .heading("Requirements"),
                        .bullets([
                            "iPhone 15 Pro or later, or any iPhone 16 model.",
                            "iOS 18.1 or later.",
                            "Apple Intelligence turned on in iOS Settings > Apple Intelligence & Siri.",
                        ]),
                        .heading("What it powers in AppleVis"),
                        .bullets([
                            "AI Summaries — condenses long forum threads, blog posts, guides, and app descriptions.",
                            "Accessibility Consensus — turns an app's accessibility comments into one honest paragraph.",
                            "Rewrite — polishes a reply, comment, or submission draft before you post it, and can even draft a starting-point bio for your profile.",
                            "Translate — steps in when AppleVis notices your draft or search isn't in English.",
                            "Guidelines Check — a friendly, advisory scan for common posting issues.",
                        ]),
                        .heading("Turning it on or off"),
                        .body("The device-level switch lives in iOS Settings > Apple Intelligence & Siri — that's what actually turns the underlying model on. Once that's on, AppleVis's own Settings > Intelligence lets you turn each feature on or off individually, so you can keep the ones you like and skip the rest."),
                        .body("On a device or iOS version that doesn't support Apple Intelligence, these features just quietly step aside. The app works exactly the same without them — they're a bonus, never a requirement."),
                        .note("To check whether Apple Intelligence is active on your device, open iOS Settings > Apple Intelligence & Siri. If the toggle is there and on, AppleVis's AI features are ready to go."),
                        .tip("If you disclose AI help in a post, a short note like \"Polished with Rewrite\" is appreciated by the community."),
                    ]
                ),
                HelpArticle(
                    id: "smart-share",
                    title: "Share Into AppleVis",
                    summary: "Use the iOS Share Sheet to send App Store links, blog text, and podcast content into AppleVis.",
                    content: [
                        .body("The AppleVis Share Extension shows up in the system share sheet across iOS. Depending on what you share, AppleVis opens the right wizard automatically."),
                        .heading("App Store links"),
                        .steps([
                            "Find an app in the App Store or Safari.",
                            "Tap Share and choose AppleVis.",
                            "The app submission wizard opens with that app already selected.",
                        ]),
                        .heading("Blog text or text files"),
                        .steps([
                            "Copy or highlight text in any app — Notes, Pages, Safari, Messages, wherever.",
                            "Tap Share and choose AppleVis.",
                            "The blog submission wizard opens with your text already loaded in the content step.",
                            "You can share a .txt or .md file from Files or iCloud Drive the same way.",
                        ]),
                        .heading("Podcasts and audio"),
                        .steps([
                            "Find an episode in Podcasts, Overcast, Spotify, Pocket Casts, or any podcast app — or an audio file in Files.",
                            "Tap Share and choose AppleVis.",
                            "The podcast submission wizard opens with what you shared already attached.",
                        ]),
                        .note("You'll need AppleVis installed for it to appear in your share sheet. Sharing usually switches straight to AppleVis with the right wizard already open — but a few apps (including the App Store) don't hand off automatically. If that happens, you'll see a quick confirmation instead, and your share will be waiting the next time you open AppleVis yourself."),
                        .tip("If AppleVis isn't showing up in your share sheet, scroll to the end of the app row and tap More to find and enable it."),
                    ]
                ),
                HelpArticle(
                    id: "smart-system-integrations",
                    title: "Handoff, Background Refresh, and AirPlay",
                    summary: "What each system integration does, and how to turn it off if you'd rather not use it.",
                    content: [
                        .heading("Handoff"),
                        .body("AppleVis advertises whatever screen you're viewing (Home, Discover, a podcast episode, and so on), so you can pick up right where you left off on a nearby Mac or iPad using the Handoff icon in the Dock or App Switcher. Only a screen name and, where relevant, a public content link are shared — no account details, tokens, or private data ever leave the device."),
                        .tip("To turn Handoff off entirely, across every app, use iOS Settings > General > AirPlay & Handoff > Handoff."),
                        .heading("Background Refresh"),
                        .body("AppleVis periodically refreshes downloaded episode metadata and checks for activity in what you follow while it's in the background, so things are current the next time you open the app."),
                        .tip("Turn this off in iOS Settings > General > Background App Refresh > AppleVis. Podcast playback itself keeps working in the background either way — only the periodic content refresh is affected."),
                        .heading("AirPlay and Route Picker"),
                        .body("The route picker in the podcast player lets you send audio to AirPlay speakers, HomePod, or Bluetooth devices, the same way any other audio app does."),
                        .heading("iCloud Sync"),
                        .body("Saved items, following, podcast position and queue, read history, and settings can all sync through your private iCloud account, and each can be turned on or off individually in Settings > Saved & Sync."),
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
                    summary: "What to check when your AppleVis account won't sign in.",
                    content: [
                        .bullets([
                            "Make sure you're using your applevis.com account details.",
                            "Check your connection.",
                            "Reset your password on applevis.com if you need to — or use Change Password right from Profile once you're back in.",
                            "If your session has expired, just sign in again from Profile.",
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
                            "Confirm iCloud Sync is on in Settings > Saved & Sync.",
                            "Confirm both devices are signed into the same Apple ID.",
                            "Confirm AppleVis notifications are allowed in iOS Settings.",
                            "Confirm the specific notification category is turned on in AppleVis's own Settings > Notifications.",
                            "Sign in to unlock personalized notification categories.",
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
                            "If playback seems stuck, pause and play again, or open the episode page and press Play.",
                            "If search results seem off, try fewer words, or let AppleVis translate a non-English query.",
                            "If the app feels too bright, too dense, or too animated, check Appearance and iOS Display & Text Size.",
                            "If storage's creeping up, check Settings > Storage and Cache.",
                            "If a download fails, check your connection and try again from the episode page or Downloads — partial downloads clean themselves up automatically.",
                            "If content isn't refreshing, pull down to refresh, or check Settings > Saved & Sync if you expect it to sync from another device.",
                            "If you can't find something you saved, open For You > Saved and check the Show picker — it may be filtered down to a specific content type.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-contact",
                    title: "Contact App Support",
                    summary: "Send bugs, feedback, suggestions, and general enquiries using the in-app contact wizard.",
                    content: [
                        .body("The in-app contact wizard sends your message straight to the AppleVis team — no email app needed. Reach it from Profile or from Help. It's three steps when you're signed in, or four when you're not."),
                        .heading("Step 1 — Choose a type"),
                        .steps([
                            "Open Profile and tap Contact AppleVis, or open Help and scroll to the Contact section.",
                            "Choose what kind of message you're sending: App Bug Report, App Feedback, App Suggestion, or App Enquiry.",
                            "Tap the card for your chosen type — the subject fills in automatically.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Your contact details (not signed in only)"),
                        .body("If you're not signed in, this step comes before the message step: enter your name and email so the team can reply. Already signed in? This step is skipped entirely — AppleVis already knows who you are."),
                        .heading("Step 2 (signed in) or Step 3 (not signed in) — Write your message"),
                        .steps([
                            "Type your message in the text area.",
                            "If you chose Bug Report, a toggle appears to include app and device info — turn it on to append your app version, device model, and accessibility settings like VoiceOver automatically.",
                            "Tap Continue.",
                        ]),
                        .heading("Final step — Review and send"),
                        .steps([
                            "Review the summary: your message type, subject, and message preview.",
                            "Check your name and email in the From section — read-only if you're signed in, editable if you're not.",
                            "Confirm the declaration that the message is genuine.",
                            "Tap Send Message.",
                            "A confirmation screen appears — the team will get back to you as soon as they can.",
                        ]),
                        .tip("Help also has a Contact AppleVis button at the bottom, in case you check a help article first and still need to reach out."),
                        .note("You don't need to be signed in to use the contact wizard — being signed out just adds one extra step for your name and email."),
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
