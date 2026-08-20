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
            description: "A quick tour of AppleVis, the tabs, signing in, and where common tools live.",
            articles: [
                HelpArticle(
                    id: "start-what-is-applevis",
                    title: "What AppleVis Is",
                    summary: "AppleVis is a community, app directory, podcast, forum, and learning library for Apple accessibility.",
                    content: [
                        .body("AppleVis is a community for blind, DeafBlind, low-vision, and sighted people who care about accessibility on Apple platforms. The app brings community discussions, app accessibility reviews, podcasts, blogs, guides, and tutorials into a native iOS experience."),
                        .heading("What you can do"),
                        .bullets([
                            "Read what is new since your last visit from Home.",
                            "Browse Discover for forums, blogs, guides, podcasts, app directory content, site search, and the Bug Tracker.",
                            "Use For You to find saved items, following, downloads, queue, and personal activity.",
                            "Play podcasts with background audio, queue, chapters, speed controls, and Lock Screen controls.",
                            "Post topics, replies, comments, app comments, and app submissions when signed in.",
                        ]),
                        .note("Most browsing works without signing in. Posting, following, personalized notifications, and some account tools require an AppleVis account."),
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
                        .body("Home is your starting point. It welcomes you, restores focus to where you left off, and keeps the What is New area available near the top."),
                        .heading("Discover"),
                        .body("Discover is the app-wide browsing area. Use it to open Forums, AppleVis Blog, Guides, Podcasts, App Directory, search, and official AppleVis links."),
                        .heading("For You"),
                        .body("For You collects personal content: saved items, followed items, downloads, and your podcast queue."),
                        .heading("Profile and Settings"),
                        .body("Profile contains account tools, support information, legal links, credits, and a Contact App Support option. Settings controls appearance, accessibility, notifications, podcasts, privacy, storage, sync, and smart features."),
                    ]
                ),
                HelpArticle(
                    id: "start-sign-in",
                    title: "Signing In",
                    summary: "What signing in unlocks and where account tools live.",
                    content: [
                        .steps([
                            "Open Profile.",
                            "Choose Sign In.",
                            "Enter the same AppleVis account details you use on applevis.com.",
                            "After signing in, Profile shows account tools, saved information, and support options.",
                        ]),
                        .heading("Signing in unlocks"),
                        .bullets([
                            "Posting forum topics and replies.",
                            "Adding blog, guide, podcast, and app comments where supported.",
                            "Following items for quicker access.",
                            "Personalized notification categories.",
                        ]),
                        .note("Your password is not stored in the app. The app keeps a secure session token in the iOS Keychain."),
                    ]
                ),
                HelpArticle(
                    id: "start-faq",
                    title: "Frequently Asked Questions",
                    summary: "Quick answers to the questions members ask most.",
                    content: [
                        .faq(question: "How do I search AppleVis?", answer: "Open the Discover tab and use the search field (2 characters minimum). Results are grouped into Forum Topics, Apps, Guides, Blogs, Podcasts, and Bug Reports."),
                        .faq(question: "Where are my saved items?", answer: "Open For You and choose Saved Items."),
                        .faq(question: "What is the difference between Save and Follow?", answer: "Save bookmarks an item locally so you can find it again. Follow keeps it in For You > Following and notifies you when it has new activity."),
                        .faq(question: "How do I download podcast episodes?", answer: "Open the episode and choose Download. Downloaded episodes appear in For You > Downloads for offline listening."),
                        .faq(question: "How do I change my VoiceOver detail level?", answer: "Open Settings > Accessibility > VoiceOver Detail Level and choose Simple, Normal, or All."),
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
                    summary: "See what changed in the latest AppleVis app update.",
                    content: [
                        .body("The What's New screen lists recent AppleVis app updates — new features, improvements, and fixes — for each released version."),
                        .steps([
                            "Open Profile.",
                            "Scroll to What's New and tap it.",
                            "Review the release notes for the current and previous versions.",
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
                    summary: "A practical first-run path through the app.",
                    content: [
                        .steps([
                            "Open Home and listen to the welcome message.",
                            "Review the What is New area if you want to catch up.",
                            "Tap Customize Home in the top-left corner to choose which content types appear in your feed.",
                            "Open Discover and explore Forums, Blog, Guides, Podcasts, and App Directory.",
                            "Open For You to see saved, following, downloads, and queue areas.",
                            "Open Settings and review Appearance, Accessibility, Notifications, Podcasts, Saved and Sync, Privacy, Storage, and Apple Intelligence.",
                            "Open Profile and use Contact App Support if you need help.",
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
                            "Use Search when you know a keyword.",
                            "Open Forums, Blog, Guides, Podcasts, or App Directory when you want to browse.",
                            "Use the picker or filter controls to choose content type, tag, platform, category, or saved state.",
                            "When you reach the end of a list, more content loads automatically.",
                        ]),
                        .note("VoiceOver users can jump by headings in areas that support category or alphabetical navigation. Low-vision and sighted users can scan the same section headings visually."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-save-follow",
                    title: "Save, Follow, and Mark as Read",
                    summary: "Keep items for later and clear new activity when you are finished.",
                    content: [
                        .steps([
                            "Find a topic, app, blog, guide, podcast episode, or other content card.",
                            "Open the action menu or long press the card.",
                            "Choose Save to keep it in For You.",
                            "Choose Follow when you want to track future activity for that item.",
                            "Choose Mark as Read when you want to clear the new state without opening the item.",
                            "On Home, use Mark All as Read when you want a clean slate across new activity.",
                        ]),
                        .tip("VoiceOver users can use the Actions rotor on content cards. Sighted and low-vision users can long press supported cards to open the same actions."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-post",
                    title: "Post a Topic, Reply, or Comment",
                    summary: "Write, review, translate, and submit community posts.",
                    content: [
                        .steps([
                            "Sign in from Profile.",
                            "Open the forum topic, blog post, guide, podcast episode, or app page you want to respond to.",
                            "Choose Reply, Add Comment, or New Topic.",
                            "Write your draft.",
                            "Use Friendly Rewrite if you want help making the draft clearer and more personable.",
                            "Use Translate to English if your draft is not in English.",
                            "Review any guidelines reminder.",
                            "Submit your post.",
                        ]),
                        .warning("AppleVis posts should be in English. The app offers translation help when it detects non-English draft text."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-podcast",
                    title: "Play and Queue Podcasts",
                    summary: "Play episodes, use Dynamic Island, build a queue, and use AirPods.",
                    content: [
                        .steps([
                            "Open Podcasts.",
                            "Choose an episode and press Play.",
                            "Use the mini player at the bottom of any tab, the full player, Lock Screen, Dynamic Island, Control Center, or AirPods to control playback.",
                            "Use Add to Queue or Play Next to build a listening list. When an episode ends, the next item in your queue plays automatically.",
                            "To skip to the next queued episode, use the next-track button on the Lock Screen or the next-track AirPods gesture. To restart the current episode, use the previous-track button.",
                            "Use Downloads when you want offline listening.",
                            "Use Settings > Podcasts to adjust speed, skip intervals, sleep timer, voice boost, trim silence, and auto-play.",
                        ]),
                        .note("When a podcast is playing, the Dynamic Island and Lock Screen show the episode title, progress, and playback state on supported iPhone models."),
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
                            "The Active filter is selected by default — switch to All Bugs if you want to include resolved reports.",
                            "Scroll through the list or type a keyword in the Search field to narrow results.",
                            "Tap a bug card to read the full report: description, steps to reproduce, workaround, version information, and Apple Feedback ID.",
                            "On an active bug, tap Report to Apple to open Feedback Assistant and file your own report — the more reports Apple receives, the more likely a fix.",
                            "Tap Save in the toolbar to keep the report in For You for easy reference later.",
                            "Tap Share to send the bug report link to someone else.",
                            "To submit a new bug, return to Discover, scroll to Contribute, and tap Submit a Bug Report — a four-step wizard opens inside the app.",
                        ]),
                        .tip("Filing your own report in Apple Feedback Assistant for the same bug raises its priority. Always include your device model, iOS or macOS version, and exact steps to reproduce."),
                        .note("VoiceOver users: each bug card announces its severity, status, first-seen version, and fix version as a single accessibility label — no need to swipe through individual elements on the card."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-low-vision",
                    title: "Low Vision Setup",
                    summary: "A quick setup path for larger text, contrast, motion, and visual comfort.",
                    content: [
                        .steps([
                            "Open Settings > Appearance and choose a theme that is comfortable.",
                            "Use High Contrast Light or High Contrast Dark if you need maximum contrast.",
                            "Choose a comfortable card density.",
                            "Open iOS Settings > Display & Text Size to adjust Dynamic Type, Bold Text, Button Shapes, Reduce Transparency, and Increase Contrast.",
                            "Open Settings > Accessibility in AppleVis to review which iOS accessibility settings the app detects.",
                        ]),
                        .tip("Liquid Glass and blur effects are automatically reduced when Reduce Transparency or a high contrast theme is active."),
                    ]
                ),
                HelpArticle(
                    id: "tutorial-replay-welcome-tour",
                    title: "Replay the Welcome Tour",
                    summary: "Revisit the short guided tour of Home, Discover, For You, Search, Profile, and Settings.",
                    content: [
                        .body("The Welcome Tour is a short, optional walkthrough of the app shown after setup. You can replay it any time — it never repeats automatically once you have seen it."),
                        .steps([
                            "Open Profile.",
                            "Scroll to Replay Welcome Tour and tap it.",
                            "The tour restarts from the beginning. Use Skip Tour at any point to exit, or Back to revisit an earlier step.",
                        ]),
                        .tip("Choose Explore This Screen on any tour step to pause the tour and try the real screen — a Resume Tour button appears so you can pick up right where you left off."),
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
                    summary: "AppleVis is designed for multiple ways of using iPhone.",
                    content: [
                        .body("AppleVis is not only for one access method. It supports direct touch, VoiceOver, braille displays, Switch Control, Voice Control, Dynamic Type, high contrast themes, reduced motion, reduced transparency, and hardware keyboards."),
                        .heading("How instructions are written"),
                        .body("Most help articles first describe the general action. When an access method needs extra detail, the article includes a note such as \"VoiceOver users can...\" or \"Low-vision users may prefer...\" so the guide stays useful for everyone."),
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
                            "Double tap to activate the focused item.",
                            "Use headings to jump between major sections.",
                            "With VoiceOver focus on a content row, set the rotor to Actions and swipe up or down to reach Save, Follow, and Share, then double tap to activate one. (Sighted users can reach the same actions by swiping the row left or right, or with a long-press context menu.)",
                            "Use two-finger scrub to go back.",
                            "Use two-finger double tap to play or pause podcasts from anywhere.",
                        ]),
                        .note("Most list screens move VoiceOver focus to the first useful item after loading, so you do not have to hunt for the beginning of the list."),
                        .heading("VoiceOver Detail Level"),
                        .body("Settings > Accessibility > VoiceOver Detail Level controls how much detail cards announce when you navigate forum topics, apps, and podcast episodes."),
                        .bullets([
                            "Simple (Fastest) — title and content type only.",
                            "Normal (Recommended) — title plus author and comment count.",
                            "All (Most Detailed) — everything: title, author, comment count, posted date, and last comment time.",
                        ]),
                        .tip("Normal is the recommended default — switch to All if you want every detail read every time, or Simple if you prefer to scan quickly and check details only when you need them."),
                    ],
                    contentType: .accessibilityLesson
                ),
                HelpArticle(
                    id: "accessibility-braille",
                    title: "Braille Display Tips",
                    summary: "How braille users can move efficiently through Help and content.",
                    content: [
                        .bullets([
                            "Use headings to jump between sections in Help, Settings, Discover, and long articles.",
                            "Short article titles and concise summaries are designed to fit better on braille displays.",
                            "Step lists are structured so each step is a separate item.",
                            "When a label is long, look for the shorter heading or action name first, then read the hint if needed.",
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
                            "Use Appearance to choose System, Light, Dark, or high contrast themes.",
                            "Use Dynamic Type in iOS Settings to enlarge text throughout the app.",
                            "Use Reduce Motion to shorten animations.",
                            "Use Reduce Transparency to replace translucent surfaces with solid backgrounds.",
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
            description: "What is new, search, filters, tags, app directory, blogs, guides, podcasts, and forums.",
            articles: [
                HelpArticle(
                    id: "home-whats-new",
                    title: "Home and What Is New",
                    summary: "How AppleVis welcomes you and helps you catch up.",
                    content: [
                        .body("When the app opens, AppleVis welcomes you and restores focus to the last feed item you were using. The What is New area remains near the top so you can review it when you want."),
                        .bullets([
                            "Use the New filter to show new activity.",
                            "Open an item to read it.",
                            "Use Mark as Read to clear an item without opening it.",
                            "Use Mark All as Read when you have many new items and want to reset your Home view.",
                        ]),
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
                            "Podcasts: podcast feed with filters, tags, queue, download, and playback actions.",
                            "App Directory: platforms, categories, category counts, alphabetical headings, app pages, and accessibility reviews.",
                            "Bug Tracker: active and resolved iOS/iPadOS and macOS accessibility bugs reported by the community.",
                            "Be My Eyes: launch Call a Volunteer, Be My AI, or the Service Directory directly from within the app.",
                            "Search: site-wide search that can translate non-English queries into English.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "discover-bug-tracker",
                    title: "Bug Tracker",
                    summary: "Browse active and resolved accessibility bugs for iOS/iPadOS and macOS.",
                    content: [
                        .body("The Bug Tracker brings the AppleVis community bug database into the app. You can browse active and resolved accessibility bugs reported by the community, read full details, link directly to Apple Feedback Assistant to help get issues fixed, and submit new bugs using the in-app wizard."),
                        .heading("Opening the Bug Tracker"),
                        .steps([
                            "Open Discover.",
                            "Scroll to the Bug Tracker section.",
                            "Choose iOS / iPadOS Bugs or macOS Bugs.",
                        ]),
                        .heading("Browsing bugs"),
                        .bullets([
                            "The Active filter shows only open, unresolved bugs. All Bugs shows both active and fixed.",
                            "Each card shows the bug title, severity level (Low, Medium, or High), status (Active or Fixed), the iOS or macOS version the bug first appeared in, and the version it was fixed in when known.",
                            "Each card also shows when the bug was first reported and when it was last updated.",
                            "Use the search field to filter the current list by title keyword.",
                            "Scroll to the end of the list and more bug reports load automatically.",
                            "Pull down to refresh the list.",
                        ]),
                        .heading("Reading a bug report"),
                        .steps([
                            "Tap a bug card to open its full detail page.",
                            "Read the description, steps to reproduce, and any available workaround.",
                            "Check the Bug Details section for platform, first seen version, fixed-in version, device, how often the bug occurs, and Apple Feedback ID.",
                            "Use the Report to Apple button on active bugs to open Feedback Assistant and file your own report.",
                            "Use the Share button to share the bug report link.",
                            "Use the Save button to add the bug report to your For You saved items.",
                        ]),
                        .tip("VoiceOver users: the heading \"Bug Details\" is announced with accessibilityRole=\"header\" so you can jump to it with the headings rotor."),
                        .heading("Submitting a new bug"),
                        .steps([
                            "Return to Discover and scroll to the Contribute section.",
                            "Tap Submit a Bug Report.",
                            "You must be signed in — a sign-in prompt appears if you are not.",
                            "The four-step wizard opens inside the app. See \"Submitting a Bug Report\" in the Community and Posting section for full details.",
                        ]),
                        .heading("Severity levels"),
                        .bullets([
                            "High: the bug significantly affects core functionality or makes a feature completely inaccessible.",
                            "Medium: the bug impairs usability but a workaround exists or the impact is partial.",
                            "Low: the bug is minor and causes only cosmetic or infrequent issues.",
                        ]),
                        .note("The Bug Tracker content is served directly from the AppleVis API. The list is always up to date — no app update is needed when new bugs are added to the website."),
                    ]
                ),
                HelpArticle(
                    id: "discover-be-my-eyes",
                    title: "Be My Eyes",
                    summary: "Launch Call a Volunteer, Be My AI, or the Service Directory directly from AppleVis.",
                    content: [
                        .body("AppleVis is a Be My Eyes company. The Be My Eyes section in Discover gives you quick access to three free visual assistance services without leaving AppleVis to hunt for them."),
                        .heading("Available services"),
                        .bullets([
                            "Call a Volunteer: connects you by live video with a sighted volunteer who can see through your phone camera, available 24 hours a day in 185 languages.",
                            "Be My AI: an AI-powered assistant that describes images, reads text, and answers visual questions in 36 languages.",
                            "Service Directory: a searchable directory of accessible customer service channels at hundreds of companies and government departments worldwide.",
                        ]),
                        .heading("How to use it"),
                        .steps([
                            "Open Discover.",
                            "Scroll to the Be My Eyes section.",
                            "Tap the service you want — Call a Volunteer, Be My AI, or Service Directory.",
                            "If Be My Eyes is installed on your device, it opens directly at that feature.",
                            "If Be My Eyes is not installed, the App Store listing for Be My Eyes opens so you can download it.",
                        ]),
                        .note("All three services are completely free to use. Be My Eyes is a separate app — tapping any link will leave AppleVis and open the Be My Eyes app or the App Store."),
                        .tip("You can also find Be My Eyes in the AppleVis App Directory, where community accessibility reviews and ratings for the app are available."),
                    ]
                ),
                HelpArticle(
                    id: "discover-filters",
                    title: "Filters, Tags, Categories, and Headings",
                    summary: "How to narrow lists quickly.",
                    content: [
                        .body("Filters and pickers let you narrow large lists. Podcasts can be filtered by content type and tags. The App Directory can be filtered by platform and category, and categories announce counts such as \"Books, 26 apps.\""),
                        .note("VoiceOver users can navigate by headings where available. Sighted and low-vision users can scan the same headings visually."),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "foryou-search",
            title: "For You and Search",
            icon: "magnifyingglass",
            description: "Your personal hub — saved items, following, podcast queue, downloads — and how to search across AppleVis.",
            articles: [
                HelpArticle(
                    id: "foryou-overview",
                    title: "Using For You",
                    summary: "Your personal AppleVis hub: saved items, following, podcast queue, and downloads.",
                    content: [
                        .body("For You is your personal AppleVis hub — not a recommendation feed. It only shows content you chose to keep, continue, or follow."),
                        .heading("The four sections"),
                        .bullets([
                            "Saved Items — topics, apps, guides, blog posts, and episodes you bookmarked. Use the filter picker to show one content type.",
                            "Following — items you follow for easy access and, where supported, notifications when they update.",
                            "Podcast Queue — episodes lined up to play next, in order. Reorder or remove any episode.",
                            "Downloads — podcast episodes saved to this device for offline listening.",
                        ]),
                        .tip("Use the Section picker at the top of For You to switch between Saved Items, Following, Podcast Queue, and Downloads. VoiceOver announces which section is selected."),
                    ],
                    contentType: .guide,
                    relatedLinks: [
                        RelatedLink(label: "Save, Follow, and Download: What\u{2019}s the Difference?", type: .faq, destination: .article("foryou-save-follow-download-faq")),
                    ]
                ),
                HelpArticle(
                    id: "foryou-save-follow-download-faq",
                    title: "Save, Follow, and Download: What\u{2019}s the Difference?",
                    summary: "Three different ways to keep content close, and when to use each.",
                    content: [
                        .faq(question: "What does Save do?", answer: "Save bookmarks a topic, app, guide, blog post, or episode so you can find it again quickly in For You > Saved Items. It does not download anything or notify you of updates."),
                        .faq(question: "What does Follow do?", answer: "Follow keeps an item in For You > Following and, where supported, notifies you when it has new activity — for example, new replies on a forum topic. Use Follow for things you want to keep up with over time."),
                        .faq(question: "What does Download do?", answer: "Download applies to podcast episodes only. It saves the audio file to your device so you can listen without an internet connection. Downloaded episodes appear in For You > Downloads."),
                        .faq(question: "Can I do more than one at once?", answer: "Yes — a podcast episode can be saved, followed, and downloaded all at the same time. Each is independent, so removing one does not affect the others."),
                    ],
                    contentType: .faq
                ),
                HelpArticle(
                    id: "search-overview",
                    title: "Using Search",
                    summary: "Find discussions, apps, guides, podcast episodes, and help across AppleVis.",
                    content: [
                        .body("Search helps you find discussions, apps, guides, podcast episodes, and Help articles from one place — either the dedicated Search tab, or the embedded search at the top of Discover."),
                        .heading("Results are grouped"),
                        .bullets([
                            "Site Results — general AppleVis site content.",
                            "Forum Topics — community discussions.",
                            "Apps — App Directory entries.",
                            "Guides and Resources — tutorials and how-to articles.",
                        ]),
                        .tip("If your query looks like it is in a language other than English, AppleVis may offer to translate it — AppleVis search works best in English."),
                        .note("VoiceOver announces a concise result count and category breakdown, for example: \"12 results found in 4 categories.\" Each section heading gives more detail."),
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
                            "Use Forums in Discover to browse forum topics.",
                            "Use filters to narrow by type or status.",
                            "Follow a topic to track future replies.",
                            "Use For You > Following to find followed items quickly.",
                            "Use notifications to control which followed activity alerts you.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "community-writing-tools",
                    title: "Writing Help and Translation",
                    summary: "Friendly rewrite, translate to English, and guidelines reminders.",
                    content: [
                        .body("Before submitting a topic, reply, or comment, AppleVis can help rewrite your draft in a friendly style or translate it to English. The guidelines checker also gives friendly reminders when it detects common issues."),
                        .bullets([
                            "Friendly Rewrite preserves your meaning while improving clarity and tone.",
                            "Translate to English helps when your draft is not in English.",
                            "The guidelines checker is advisory and does not block posting.",
                            "If AI helped write your post, disclose that in the post.",
                        ]),
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
                            "Do not post personal email addresses, referral links, or advertisements.",
                            "Disclose conflicts of interest and AI assistance.",
                            "Avoid duplicate posts and one-word replies.",
                        ]),
                    ]
                ),
                HelpArticle(
                    id: "community-edit-post",
                    title: "Editing Your Posts and Replies",
                    summary: "How to change a forum reply, blog comment, app comment, or podcast comment after you have submitted it.",
                    content: [
                        .body("You can edit any post or comment you have written, directly inside the app. The edit option only appears on content you authored."),
                        .heading("Forum replies and topic comments"),
                        .steps([
                            "Open the forum topic or episode comments page.",
                            "Find your reply and hold down on it to open the action sheet.",
                            "Choose Edit Comment from the menu.",
                            "The Edit modal opens with your original text loaded.",
                            "Make your changes in the text field.",
                            "Tap Save in the top-right corner.",
                        ]),
                        .heading("App, blog, and guide comments"),
                        .steps([
                            "Open the app, blog post, or guide where you left a comment.",
                            "Long-press your comment to open the action sheet.",
                            "Choose Edit Comment.",
                            "Edit the text and tap Save.",
                        ]),
                        .note("Edits are applied immediately and reflected in the app without requiring a page reload."),
                        .tip("If you use VoiceOver, the Edit action is also available through accessibilityActions — swipe up or down to reach it without using the long-press menu."),
                    ]
                ),
                HelpArticle(
                    id: "community-delete-post",
                    title: "Deleting Your Posts and Comments",
                    summary: "How to permanently remove a forum reply, blog comment, app comment, or podcast comment you have written.",
                    content: [
                        .body("You can permanently delete any post or comment you have written. Deleted content is removed immediately and cannot be recovered."),
                        .steps([
                            "Find your post or comment in the relevant screen.",
                            "Hold down on it to open the action sheet.",
                            "Choose Delete Comment.",
                            "A confirmation dialog will appear. Tap Delete to confirm.",
                        ]),
                        .warning("Deletion is permanent. The content is removed from AppleVis and cannot be restored. If you just want to change the text, use Edit instead."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-bug",
                    title: "Submitting a Bug Report",
                    summary: "How to report a new accessibility bug using the four-step in-app wizard.",
                    content: [
                        .body("If you find an accessibility bug that is not already in the Bug Tracker, you can submit it to AppleVis using the native four-step wizard. You must be signed in. The report goes to the AppleVis team for review before it is published."),
                        .heading("Before you begin"),
                        .bullets([
                            "Search the Bug Tracker first to check the bug has not already been reported.",
                            "File your own report in Apple Feedback Assistant first — copy the FB number so you can include it in step two.",
                            "Sign in from Profile if you have not already done so.",
                        ]),
                        .heading("Step 1 — Platform and OS version"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit a Bug Report.",
                            "Choose the platform: iOS, iPadOS, or macOS.",
                            "Enter the operating system version where the bug occurs, for example \"iOS 18.4\" or \"macOS 15.2\".",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Bug details"),
                        .steps([
                            "Enter a short, specific bug title, for example \"VoiceOver skips toolbar buttons in Mail\".",
                            "Optionally enter your Apple Feedback number (FB followed by digits) if you have already filed this with Apple.",
                            "Choose how reliably you can reproduce the bug: Yes always, Yes sometimes, or No.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 3 — Description"),
                        .steps([
                            "Write a detailed description of the bug.",
                            "Include the exact steps to reproduce it, what you expected to happen, and what actually happened.",
                            "Mention your device model, the affected app name and version, and any partial workaround you have found.",
                            "Tap Continue when you have at least 30 characters.",
                        ]),
                        .tip("The description screen shows tips for a helpful bug report. The more detail you include, the more likely your report is to be published and to help Apple fix the issue."),
                        .heading("Step 4 — Recognition and submit"),
                        .steps([
                            "Review a summary of your report.",
                            "Choose how you would like to be credited if your report is featured: by your real name, by your AppleVis username, or anonymously.",
                            "Tap Submit Report.",
                            "A thank-you screen confirms your submission. The AppleVis team will evaluate and respond within two to three days.",
                        ]),
                        .note("Bug reports are moderated. Duplicate reports, vague descriptions, or bugs that cannot be reproduced may not be published."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-blog",
                    title: "Submitting a Blog Post",
                    summary: "How to submit a blog post for consideration using the three-step in-app wizard.",
                    content: [
                        .body("If you have something to share with the AppleVis community — a tip, review, personal experience, or accessibility story — you can submit a blog post directly from the app. Submissions go to the AppleVis Editorial Team for review. You must be signed in."),
                        .heading("Step 1 — Title and category"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit a Blog Post.",
                            "Enter a clear title for your post.",
                            "Choose the category that best fits your topic from the chip grid.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Your blog content"),
                        .steps([
                            "Choose how you want to provide your post: Write, Import file, or Paste.",
                            "Write: type directly into the text area. A minimum of 50 characters is required.",
                            "Import file: tap Browse Files and choose a .txt or .md file from Files, iCloud Drive, or any document provider.",
                            "Paste: tap Paste from Clipboard to pull text you copied from another app such as Notes or Pages.",
                            "Optionally add a note to editors to provide context or background about your post.",
                            "Optionally use Draft with Apple Intelligence to generate a short editor note from your content.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 3 — Review and submit"),
                        .steps([
                            "Review the summary card showing your title, category, and a preview of your post.",
                            "Tap Submit to AppleVis.",
                            "A thank-you screen confirms the submission.",
                        ]),
                        .note("The AppleVis Editorial Team will review your post and determine whether it will be published. They will reach out with their decision. Please allow two to three days for the review process."),
                        .tip("You can also share a blog post into AppleVis from other apps. In any app, use the Share menu and choose AppleVis — your text is passed directly into the blog submission wizard."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-podcast",
                    title: "Submitting a Podcast",
                    summary: "How to submit a podcast episode using the three-step in-app wizard.",
                    content: [
                        .body("If you produce a podcast related to accessibility, Apple products, or blindness, you can submit an episode to AppleVis for consideration. Submissions go to the AppleVis Editorial Team for review. You must be signed in."),
                        .heading("Step 1 — Podcast description"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit a Podcast.",
                            "Write a description of your podcast — what it covers, who it is for, and any relevant context.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Attach your audio"),
                        .steps([
                            "Tap Browse Files to open the document picker.",
                            "Choose your audio file from Files, iCloud Drive, or any connected storage provider.",
                            "Supported formats are MP3, AAC, M4A, WAV, and AIFF.",
                            "The selected file name and size are shown so you can confirm you picked the right file.",
                            "Tap Continue once a file is selected.",
                        ]),
                        .heading("Step 3 — Review and submit"),
                        .steps([
                            "Review the summary showing your audio file and description.",
                            "Tap Submit to AppleVis.",
                            "The audio file is uploaded. Keep the app open during upload.",
                            "A thank-you screen confirms the submission.",
                        ]),
                        .note("The AppleVis Editorial Team will review your podcast and reach out with their decision. Please allow two to three days."),
                        .tip("You can also share a podcast URL from apps like Podcasts, Overcast, or Spotify into AppleVis using the system Share menu. Choose AppleVis in the share sheet and the podcast submission wizard opens with the URL already included."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-app",
                    title: "Submitting an App Entry",
                    summary: "How to add an accessible app to the AppleVis App Directory using the five-step wizard.",
                    content: [
                        .body("Registered AppleVis members can submit new app entries to the App Directory. App entries are published immediately when submitted by a signed-in member, matching the behaviour on the AppleVis website. The wizard walks you through five steps."),
                        .heading("Before you begin"),
                        .bullets([
                            "Check the App Directory first to make sure the app is not already listed.",
                            "Sign in from Profile if you have not done so.",
                            "Have your accessibility assessment ready — VoiceOver performance, button labelling, and your usability rating.",
                        ]),
                        .heading("Step 1 — Accessibility declaration"),
                        .steps([
                            "Open Discover, scroll to Contribute, and tap Submit an App.",
                            "Read the accessibility guidelines reminder.",
                            "Check the declaration checkbox to confirm you have used the app and are reporting your genuine experience.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Platform"),
                        .steps([
                            "Choose the platform: iPhone and iPad (iOS), Mac (macOS), or Apple TV (tvOS).",
                            "Tap Continue.",
                        ]),
                        .heading("Step 3 — Find the app"),
                        .steps([
                            "Search by app name or paste an App Store URL.",
                            "The wizard searches iTunes and the AppleVis directory to find the app and check whether it already exists.",
                            "Select the correct result from the list.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 4 — Confirm app details"),
                        .steps([
                            "Review the app name, developer, category, price, and description pulled from the App Store.",
                            "Confirm the details are correct.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 5 — Accessibility notes and submit"),
                        .steps([
                            "Enter the iOS, macOS, or tvOS version you tested the app on.",
                            "Choose your VoiceOver Performance rating from the picker.",
                            "Choose your Button Labelling rating.",
                            "Choose your Usability rating.",
                            "Write your Accessibility Comments — a detailed description of the accessibility experience. Minimum 20 characters, but more detail is always better.",
                            "Optionally add Other Comments and a Short Summary.",
                            "Tap Submit App Entry.",
                            "A thank-you screen confirms the submission. The entry is published immediately to the App Directory.",
                        ]),
                        .tip("You can use Draft with Apple Intelligence to generate a short summary from your accessibility comments if Apple Intelligence is enabled on your device."),
                        .note("App entries submitted by signed-in members are published directly to the App Directory. This matches the behaviour on the AppleVis website."),
                    ]
                ),
                HelpArticle(
                    id: "community-edit-profile",
                    title: "Editing Your Profile",
                    summary: "Update your display name, bio, location, social links, and other profile details.",
                    content: [
                        .steps([
                            "Open the Profile tab.",
                            "Tap Edit Profile near the top of the Account section.",
                            "Update any fields you want to change: display name, real name, bio, location, website, and social handles.",
                            "Tap Save Profile at the bottom.",
                        ]),
                        .bullets([
                            "Display Name: what other members see on your posts.",
                            "Real Name: optional, shown on your public profile page.",
                            "Bio: a short description of yourself for the community.",
                            "Location: city, country, or region — entirely optional.",
                            "Interests: accessibility tools, Apple products, or anything you want to share.",
                            "Website, Twitter/X, Mastodon, Facebook: social and web links shown on your profile.",
                        ]),
                        .note("Changes are saved to your AppleVis account immediately. They will appear on the website and in the app for other members."),
                    ]
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
                    summary: "Browse apps by platform, category, heading, search, and accessibility information.",
                    content: [
                        .body("The App Directory helps you find apps and understand their accessibility. Browse by platform, then category. Category rows include counts, and app lists support headings for faster navigation."),
                        .bullets([
                            "Open an app page for description, developer, category, ratings, and accessibility notes.",
                            "Use Accessibility Consensus for a short summary of what reviewers report.",
                            "Save or follow apps to find them in For You.",
                            "Share an App Store link into AppleVis to look up or submit an app.",
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
                            "Navigate chapters using the chapter strip when the episode includes chapter markers.",
                            "Lock Screen shows the episode title, artwork, progress bar, and playback controls.",
                            "Dynamic Island shows the episode title and playback state on supported iPhone models while you use other apps.",
                            "AirPods: double tap to play or pause. On episodes with a queue, use the next-track gesture on AirPods or the next button on the Lock Screen to skip to the next queued episode. The previous-track gesture restarts the current episode from the beginning.",
                            "Control Center shows a Now Playing card with artwork, title, and controls.",
                        ]),
                        .tip("Use Settings > Podcasts to adjust speed, skip intervals, sleep timer, voice boost, trim silence, auto-play, resume rewind, and volume."),
                    ]
                ),
                HelpArticle(
                    id: "content-blog-guides",
                    title: "Blogs and Guides",
                    summary: "Read official updates, guides, tutorials, resources, and comments.",
                    content: [
                        .body("AppleVis Blog contains official posts and announcements. Guides contains tutorials, how-to articles, resources, events, and developer content. Both support reading, saving, sharing, comments, summaries, and discussion tools where available."),
                    ]
                ),
                HelpArticle(
                    id: "content-bugs",
                    title: "Bug Tracker",
                    summary: "How the AppleVis bug database works and what each field means.",
                    content: [
                        .body("The Bug Tracker is a community-maintained database of accessibility bugs on Apple platforms. Each report is reviewed and classified by the AppleVis team before being published."),
                        .heading("What each field means"),
                        .bullets([
                            "Title: a brief, descriptive name for the bug.",
                            "Platform: iOS/iPadOS or macOS.",
                            "Status — Active: the bug is present in the current release and not yet fixed.",
                            "Status — Fixed: Apple has released an update that resolves the bug.",
                            "Severity — High: the bug makes a key accessibility feature completely unavailable.",
                            "Severity — Medium: the bug impairs usability but a workaround exists.",
                            "Severity — Low: the bug is minor and only causes cosmetic or infrequent issues.",
                            "First Seen In: the iOS, iPadOS, or macOS version where the bug was first noticed.",
                            "Fixed In: the version where Apple shipped a fix, if known.",
                            "Steps to Reproduce: a numbered sequence to reliably trigger the bug.",
                            "Workaround: any known way to reduce the impact of the bug until Apple fixes it.",
                            "Apple Feedback ID: the reference number filed with Apple Feedback Assistant. Tapping it opens Feedback Assistant so you can file your own report for the same issue.",
                            "Device: the hardware used when the bug was first reported.",
                            "How Often: Rarely, Sometimes, or Always — how reliably the bug occurs.",
                        ]),
                        .heading("Why filing your own Apple report helps"),
                        .body("Apple uses the volume of Feedback Assistant reports as one signal of how widespread a bug is. When many users file reports for the same issue, it raises the priority. Use the Report to Apple button on any active bug to open Feedback Assistant and add your voice."),
                        .tip("Include your exact device model, iOS or macOS version, and the steps to reproduce from the bug report when filing with Apple. Copying the Apple Feedback ID and referencing existing reports also helps."),
                    ]
                ),
            ]
        ),
        HelpSection(
            id: "settings",
            title: "Settings and Personalization",
            icon: "gearshape",
            description: "Appearance, accessibility, notifications, podcasts, sync, privacy, storage, and support.",
            articles: [
                HelpArticle(
                    id: "settings-appearance",
                    title: "Appearance",
                    summary: "Themes, Liquid Glass, card density, contrast, and visual comfort.",
                    content: [
                        .body("Appearance controls how AppleVis looks. Use theme choices, density, and iOS display settings to make the app comfortable. Liquid Glass gives supported surfaces a modern translucent feel and automatically falls back to solid surfaces when Reduce Transparency or high contrast makes that better."),
                    ]
                ),
                HelpArticle(
                    id: "settings-notifications",
                    title: "Notifications",
                    summary: "Choose which AppleVis activity can alert you.",
                    content: [
                        .bullets([
                            "Forum replies.",
                            "Mentions.",
                            "New topics.",
                            "Followed items.",
                            "New podcast episodes.",
                            "App updates.",
                            "New resources.",
                            "Announcements.",
                        ]),
                        .note("Some notification categories require signing in. iOS notification permission is still controlled by iPhone Settings."),
                    ]
                ),
                HelpArticle(
                    id: "settings-privacy-sync",
                    title: "Privacy and Sync",
                    summary: "What syncs through iCloud, and how account and local data are handled.",
                    content: [
                        .bullets([
                            "Saved and Sync controls what goes through iCloud: saved items, following, podcast position, queue, and preferences.",
                            "Privacy explains account data, Keychain, iCloud, smart features, and local data — and what never leaves the device.",
                            "Clear Local Data signs out and removes AppleVis data stored on this device without deleting your applevis.com account.",
                        ]),
                        .note("Apple Intelligence features process everything on-device — no post, comment, or search text is sent to a server."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-storage-cache",
                    title: "Storage and Cache",
                    summary: "Manage downloaded audio, cached content, and free up space.",
                    content: [
                        .body("Storage and Cache shows how much space AppleVis is using on this device and lets you manage it."),
                        .bullets([
                            "Downloaded podcast episodes for offline listening.",
                            "Cached images and content for faster browsing.",
                            "Cache retention — how long cached content is kept before automatic cleanup.",
                        ]),
                        .steps([
                            "Open Settings > Storage and Cache.",
                            "Review the breakdown of downloads and cache size.",
                            "Use Clear Cache to remove cached content without affecting downloads or saved items.",
                            "Remove individual downloads from For You > Downloads if you only want to free up specific episodes.",
                        ]),
                        .tip("Clearing the cache does not delete downloaded episodes, saved items, or your account data — only temporary cached content."),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "settings-support",
                    title: "Profile and App Support",
                    summary: "Get app support using the in-app contact wizard.",
                    content: [
                        .body("Profile includes a Contact App Support button that opens the native in-app contact wizard. You can send a bug report, feedback, suggestion, or recommendation directly to the AppleVis team without leaving the app."),
                        .tip("Choosing Bug Report in the wizard adds a system information toggle. Turn it on to automatically append your app version and iOS version to the message — useful when reporting a crash or unexpected behaviour."),
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
                    summary: "Read Aloud, summaries, simplification, rewrite, and translation.",
                    content: [
                        .bullets([
                            "Read Aloud reads content out loud using device speech — available on any device.",
                            "Summarise condenses long posts, discussions, show notes, and app descriptions — requires Apple Intelligence.",
                            "Simplify rewrites complex text in plain language — requires Apple Intelligence.",
                            "Accessibility Consensus summarises community app accessibility feedback into a short paragraph — requires Apple Intelligence.",
                            "Friendly Rewrite polishes your draft before submitting — requires Apple Intelligence.",
                            "Translate to English helps with drafts and search queries — requires Apple Intelligence.",
                        ]),
                        .note("Apple Intelligence features require iPhone 15 Pro or later, iOS 26 or later, and Apple Intelligence enabled in iOS Settings. See Smart Features > Apple Intelligence Features for full details."),
                    ]
                ),
                HelpArticle(
                    id: "smart-siri-widgets",
                    title: "Siri and Spotlight",
                    summary: "Use AppleVis from system features outside the app.",
                    content: [
                        .heading("Siri phrases"),
                        .body("AppleVis registers voice shortcuts you can say to Siri at any time. You can also add them to your own phrases in Settings > Siri."),
                        .bullets([
                            "\"Open AppleVis Forums\" — opens the Forums tab.",
                            "\"Show unread AppleVis topics\" — opens Forums filtered to Unread.",
                            "\"Resume my AppleVis podcast\" — resumes the last episode you were listening to.",
                            "\"Play the latest AppleVis podcast\" — opens Podcasts and starts the newest episode.",
                            "\"Search AppleVis for [your query]\" — opens search with your words pre-filled.",
                            "\"Open my AppleVis saved items\" — opens Saved Items in For You.",
                        ]),
                        .heading("Spotlight"),
                        .body("Spotlight can find AppleVis topics, apps, podcasts, and resources from iOS Search. Items you open are indexed so they appear in future Spotlight results."),
                    ]
                ),
                HelpArticle(
                    id: "smart-apple-intelligence",
                    title: "Apple Intelligence Features",
                    summary: "What Apple Intelligence powers in AppleVis, which devices support it, and how to enable it.",
                    content: [
                        .body("AppleVis uses Apple Intelligence to power several on-device AI features. All processing happens on your device — no text or content is sent to a server."),
                        .heading("Requirements"),
                        .bullets([
                            "iPhone 15 Pro, iPhone 16, or later (Apple Intelligence requires the A17 Pro chip or M-series chip).",
                            "iOS 26 or later for the full feature set using the FoundationModels framework.",
                            "Apple Intelligence enabled in Settings > Apple Intelligence and Siri.",
                            "English language preferred in Settings > General > Language and Region.",
                        ]),
                        .heading("What Apple Intelligence powers in AppleVis"),
                        .bullets([
                            "Summarise — condenses long forum topics, blog posts, guides, and app descriptions.",
                            "Simplify — rewrites complex text in plain, easy-to-read language.",
                            "Accessibility Consensus — summarises community VoiceOver and usability feedback for an app into a short paragraph.",
                            "Friendly Rewrite — polishes your forum reply or comment draft before you post it.",
                            "Translate to English — translates your post or search query from another language.",
                            "Draft with Apple Intelligence — generates a short editor note or summary from your submission content in the blog and app submission wizards.",
                            "Guidelines Check — scans your draft for common posting issues and gives friendly advisory notes.",
                        ]),
                        .heading("When Apple Intelligence is not available"),
                        .body("On devices or iOS versions that do not support Apple Intelligence, these features are hidden automatically. The app works fully without them — they are enhancements, not requirements."),
                        .note("To check whether Apple Intelligence is active on your device, open Settings > Apple Intelligence and Siri. If the toggle is visible and on, AppleVis AI features are enabled."),
                        .tip("If you disclose AI assistance in a post, a brief note such as \"Polished with Friendly Rewrite\" is appreciated by the community."),
                    ]
                ),
                HelpArticle(
                    id: "smart-share",
                    title: "Share Into AppleVis",
                    summary: "Use the iOS Share Sheet to send App Store links, blog text, and podcast URLs into AppleVis.",
                    content: [
                        .body("The AppleVis Share Extension appears in the system share sheet across iOS. Depending on what you share, the app opens the appropriate wizard or screen automatically."),
                        .heading("App Store links"),
                        .steps([
                            "Find an app in the App Store or in Safari.",
                            "Tap Share and choose AppleVis from the share sheet.",
                            "The app submission wizard opens with that app pre-selected.",
                        ]),
                        .heading("Blog text or text files"),
                        .steps([
                            "Copy or highlight text in any app — Notes, Pages, Safari, Messages, or any other.",
                            "Tap Share and choose AppleVis.",
                            "The blog submission wizard opens with your text already loaded in the content step.",
                            "You can also share a .txt or .md file from Files or iCloud Drive the same way.",
                        ]),
                        .heading("Podcast URLs"),
                        .steps([
                            "Find a podcast episode in Podcasts, Overcast, Spotify, Pocket Casts, or any other podcast app.",
                            "Tap Share and choose AppleVis.",
                            "The podcast submission wizard opens.",
                        ]),
                        .note("You must have the AppleVis app installed for it to appear in your share sheet. Sharing opens AppleVis and dismisses the share sheet automatically."),
                        .tip("If AppleVis does not appear in your share sheet, scroll to the end of the app row and tap More to find and enable it."),
                    ]
                ),
                HelpArticle(
                    id: "smart-system-integrations",
                    title: "Handoff, Background Refresh, and AirPlay",
                    summary: "What each system integration does and how to turn it off if you prefer not to use it.",
                    content: [
                        .heading("Handoff"),
                        .body("AppleVis advertises the screen you are viewing (Home, Discover, a podcast episode, and similar) so you can pick up on a nearby Mac or iPad using the Handoff icon in the Dock or App Switcher. Only a screen name and, where relevant, a public content link are shared — no account details, tokens, or private data leave the device."),
                        .tip("To turn Handoff off entirely for all apps, use iOS Settings > General > AirPlay & Handoff > Handoff."),
                        .heading("Background Refresh"),
                        .body("AppleVis periodically refreshes downloaded episode metadata and checks for followed-topic activity while in the background, so content is current the next time you open the app."),
                        .tip("Turn this off in iOS Settings > General > Background App Refresh > AppleVis. Podcast playback itself keeps working in the background either way — only the periodic content refresh is affected."),
                        .heading("AirPlay and Route Picker"),
                        .body("The route picker in the podcast player lets you send audio to AirPlay speakers, HomePod, or Bluetooth devices, the same way any other audio app does."),
                        .heading("iCloud Sync"),
                        .body("Saved items, following, podcast position, queue, and preferences can sync through your private iCloud account. Each of these can be turned on or off individually in Settings > Saved and Sync."),
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
                    summary: "What to check when your AppleVis account does not sign in.",
                    content: [
                        .bullets([
                            "Use your applevis.com account credentials.",
                            "Check your connection.",
                            "Reset your password on applevis.com if needed.",
                            "If a session expires, sign in again from Profile.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-sync-notifications",
                    title: "Sync and Notification Problems",
                    summary: "Checks for iCloud sync and push notifications.",
                    content: [
                        .bullets([
                            "Confirm iCloud Sync is on in Settings > Saved and Sync.",
                            "Confirm both devices use the same Apple ID.",
                            "Confirm AppleVis notifications are allowed in iOS Settings.",
                            "Confirm the notification category is enabled in AppleVis Settings > Notifications.",
                            "Sign in for personalized notification categories.",
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
                            "If search results are poor, try fewer words or translate a non-English query to English.",
                            "If the app feels too bright, too dense, or too animated, review Appearance and iOS Display & Text Size.",
                            "If storage grows, use Settings > Storage and Cache.",
                            "If a download fails, check your connection and try again from the episode or Downloads list — partial downloads are removed automatically.",
                            "If content will not refresh, pull down to refresh, or check Settings > Saved and Sync if you expect it to sync from another device.",
                            "If you cannot find saved content, open For You > Saved Items and check the Show Saved Items picker — it may be set to a specific content type.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-contact",
                    title: "Contact App Support",
                    summary: "Send bugs, feedback, suggestions, and recommendations using the in-app contact wizard.",
                    content: [
                        .body("The in-app contact wizard sends your message directly to the AppleVis team. No email app needed. You can reach it from Profile or from Help. The wizard has three steps when signed in, or four steps when not signed in."),
                        .heading("Step 1 — Choose a type"),
                        .steps([
                            "Open Profile and tap Contact App Support, or open Help and scroll to the Contact section.",
                            "Choose what kind of message you are sending: App Bug Report, App Feedback, App Suggestion, or App Recommendation.",
                            "Tap the card for your chosen type. The subject is set automatically from the type you choose.",
                            "Tap Continue.",
                        ]),
                        .heading("Step 2 — Your contact details (not signed in only)"),
                        .body("If you are not signed in, this step appears before the message step. Enter your name and email address so the team can reply to you. If you are signed in, your name and email are already known and this step is skipped."),
                        .heading("Step 2 (signed in) or Step 3 (not signed in) — Write your message"),
                        .steps([
                            "Type your message in the large text area.",
                            "If you chose Bug Report, a toggle appears to include system information. Turn it on to append your app version and iOS version automatically.",
                            "Tap Continue.",
                        ]),
                        .heading("Final step — Review and send"),
                        .steps([
                            "Review the summary: your message type, subject, and message preview are shown.",
                            "Your name and email are shown in the From section. If you are signed in they are read-only. If you are not signed in they are editable here.",
                            "Check the declaration to confirm the message is genuine.",
                            "Tap Send Message.",
                            "A confirmation screen appears. The team will typically respond within two to three business days.",
                        ]),
                        .tip("The Help screen also has a Contact App Support button at the bottom if you find a relevant help article first and still need to get in touch."),
                        .note("You do not need to be signed in to use the contact wizard. Not signed in adds one extra step for your name and email."),
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
