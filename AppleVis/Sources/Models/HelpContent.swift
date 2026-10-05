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
    /// Where a Quick Reference article was checked, such as an Apple
    /// Support page. Shown as a link that opens the way Web Links is set.
    case source(label: String, url: String)

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
        case .source(_, let url): return "src-\(url)"
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

extension HelpArticle {
    /// The article as plain text, for Share or Print: something to send to
    /// a braille embosser, a note taker, or another device, so the steps
    /// are at hand when the device they're about won't respond. Requested
    /// directly (2026-10-05).
    var plainText: String {
        var lines = [title, summary, ""]
        for block in content {
            switch block {
            case .heading(let text):
                lines += ["", text]
            case .body(let text):
                lines.append(text)
            case .bullets(let items):
                lines += items.map { "- \($0)" }
            case .steps(let items):
                lines += items.enumerated().map { "\($0.offset + 1). \($0.element)" }
            case .tip(let text), .note(let text), .warning(let text):
                lines.append(text)
            case .faq(let question, let answer):
                lines += [question, answer]
            case .source(let label, let url):
                lines.append("\(label): \(url)")
            }
        }
        lines += ["", String(localized: "From AppleVis Help.")]
        return lines.joined(separator: "\n")
    }
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
                            "See what's new on Home that you haven't read yet.",
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
                        .body("Home is the first screen you see. It shows a welcome, a summary of what's new that you haven't read yet, and a shortcut back to where you left off. Customize Home, at the top left, lets you choose which content types appear in your feed. Post, at the top right, starts a new forum topic or app entry, and Ask the Mouse, next to it, answers questions in your own words."),
                        .body("Home has four views: All, New, Fetch, and Nibbles. Choose one at the top of Home."),
                        .heading("Discover"),
                        .body("Discover contains the rest of AppleVis: Forums, the AppleVis Blog, Guides, Podcasts, the App Directory, the Bug Tracker, Be My Eyes, RSS Feeds, and search. The ways to contribute to AppleVis are here too."),
                        .heading("For You"),
                        .body("For You only shows what you've chosen to keep. It has five sections: Saved, Following, Recommended, Queue, and Downloads."),
                        .heading("Profile and Settings"),
                        .body("Profile and Settings isn't a separate tab. Use the Profile and Settings button in the toolbar on Home, Discover, or For You."),
                        .body("Settings opens on top of Profile. When you've finished, choose Done at the top right of any Settings screen to go back to what you were doing."),
                        .body("Choose your name at the top of Profile to open My Account. There you can edit your profile and bio, change your password or email address, or sign out."),
                        .body("Settings controls how AppleVis looks, sounds, and behaves, including appearance, accessibility, sounds and haptics, notifications, podcasts, privacy, and Apple Intelligence features."),
                        .body("Help, What's New, Replay Welcome Tour, and Contact AppleVis are in the About AppleVis section of Profile and Settings."),
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
                        .note("For your security, the AppleVis website signs you out about every three weeks. Turn on Remember me when you sign in, and the app signs you back in for you. Without it, the app asks you to sign in again, and anything you were posting goes through once you have, so nothing you wrote is lost."),
                        .heading("What signing in lets you do"),
                        .bullets([
                            "Post forum topics, replies, and comments.",
                            "Follow topics and other content so they appear in For You.",
                            "Recommend apps.",
                            "Send a private message to another member.",
                            "Get notifications about the activity you care about.",
                        ]),
                        .heading("Changing your password or email"),
                        .body("You can update your account without leaving the app. In Profile, choose your name to open My Account, then choose Change Password or Change Email Address. Each one is a short guided process: confirm your current password, enter the new value, and review it before saving."),
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
                            "Choose Reply or Comment. To start a new topic, choose Post on Home. If nobody has commented yet, choose Be the First to Comment, or Be the First to Reply on a forum topic.",
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
                            "To open the full player, choose the episode title in the mini player. To open it each time you play an episode from a list, turn on Open Player on Play in Settings > Podcasts.",
                            "Use Add to Queue or Play Next to choose what plays next. When an episode ends, the next one in your queue starts automatically.",
                            "On AirPods, a double press skips forward and a triple press skips back. To make them play the next episode and go back to the start instead, change Headphone Controls in Settings > Podcasts.",
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
                        .body("Anything on Home with new comments has a Jump to First New Comment action. It opens the item the same way as choosing it, with VoiceOver on the first comment you haven't seen. Back returns you to where you were."),
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
                    id: "home-fetch",
                    title: "Fetch",
                    summary: "Read everything new, each post with its new comments.",
                    content: [
                        .body("Fetch is one of the views at the top of Home, after New. It shows the same new items as New, but grouped for reading. Goldie the golden retriever fetches them for you."),
                        .body("Each item starts with a heading. A new post comes next, then each new comment in full, oldest first. Swipe through to read everything without opening anything."),
                        .bullets([
                            "Forum topics show the whole post. Guides, blog posts, and podcast episodes show the first paragraph. App entries show a short accessibility summary.",
                            "For an older post with new comments, you hear who posted it and when. Use the Read Original Post action to hear the post itself.",
                            "Double-tap a comment to open it in its thread. Double-tap a heading to open the item.",
                            "On screen, a long post or comment shows its first few lines. Choose Show Full Post or Show Full Comment to see the rest. VoiceOver and braille always get the whole text.",
                            "With VoiceOver, set the rotor to Headings to jump from item to item.",
                        ]),
                        .heading("Listen to Fetch"),
                        .body("Listen to Fetch reads everything aloud, item by item. Use the buttons to pause, skip a comment, or move to the next or previous item. With VoiceOver, a two-finger double tap plays and pauses."),
                        .body("Listening Speed, just below, sets how fast it reads. My Settings, the first choice, uses the voice and speed you chose for VoiceOver, or for Spoken Content in Settings > Accessibility if you don't use VoiceOver. You can also choose Slow, Normal, Fast, Faster, or Fastest. With VoiceOver, swipe up or down on Listening Speed to change it. If you change it while listening, the current sentence starts again at the new speed."),
                        .heading("Marking items as read"),
                        .bullets([
                            "Mark This Group as Read, on an item's heading, marks the post and all its new comments as read. The whole group leaves Fetch, and VoiceOver moves to the next item's heading.",
                            "In Fetch, Mark This Group as Read is available on every comment and on the group heading. It marks the post and all its comments as read, matching the website.",
                            "When a group is marked as read, VoiceOver says Group marked as read, then moves to the next group's heading.",
                            "Mark All as Read, at the top of Fetch, clears everything.",
                        ]),
                        .body("With VoiceOver, use the Actions rotor. You can also touch and hold a group heading or comment, or swipe right on a comment, to choose Mark This Group as Read."),
                        .body("If you turn on Mark as Read When Finished, items you've read to the end are marked as read when you leave Fetch. What you've read is kept on this device."),
                        .note("When signed in and online, Mark as Read and Mark All as Read also update your read history on the website."),
                    ]
                ),
                HelpArticle(
                    id: "home-whats-new",
                    title: "Home and What's New",
                    summary: "How AppleVis welcomes you back and helps you catch up.",
                    content: [
                        .body("When you open AppleVis, Home greets you and returns you to where you left off. The greeting is a little different depending on whether you're signed in."),
                        .body("Near the top, a summary shows how much is new that you haven't read yet."),
                        .body("Activate the summary to move through the feed. In All, it takes you to the item you last opened, so you can move back up through what's newer. In New, it goes to the first unread item. In Fetch, it goes to the first post. In Nibbles, it goes to the start of Nibbles."),
                        .body("If you leave AppleVis for more than five minutes, Home refreshes when you come back. VoiceOver stays where you were and says Home updated, followed by what's new."),
                        .heading("Filtering the feed"),
                        .bullets([
                            "All shows everything your feed is set up to include.",
                            "New shows only new posts and comments that you haven't read yet. An item stays in New until you open it or mark it as read.",
                            "Fetch shows the same new items, grouped for reading: each post, then its new comments in full. Listen to Fetch reads it all aloud.",
                            "Nibbles is a weekly or monthly summary of new accessible apps, podcast episodes, popular discussions, guides, and blog posts. You can share it.",
                            "Popular discussions are the forum topics with the most new comments during that week or month, not the most comments ever.",
                        ]),
                        .heading("Reading the badges"),
                        .bullets([
                            "NEW means the item itself is new, and you haven't opened it yet.",
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
                        .tip("Post, the plus button at the top right, starts a new forum topic or app entry without going to Discover first. Ask the Mouse, next to it, answers questions in your own words."),
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
                            "Saved: topics, apps, guides, blog posts, and episodes you've bookmarked, and answers you've saved from Ask the Mouse. You can filter by content type, including Mouse Answers.",
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
                    summary: "Find discussions, apps, guides, blog posts, podcast episodes, and bug reports from one place.",
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
                        .body("A search can be up to 150 characters, which is plenty for a few words. Short searches find the most. Searching the App Directory has the same limit. When you're close to it, VoiceOver says how many characters are left. Anything longer is shortened, and AppleVis tells you."),
                        .note("VoiceOver first reads a short summary, such as \"12 results found in 4 categories.\" Each section heading gives more detail."),
                        .body("With Apple Intelligence, Ask the Mouse appears above the results. Choose it to ask your search as a question and get an answer."),
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
                        .note("When signed in and online, Mark as Read and Mark All as Read also update your read history on the website."),
                        .note("Topics pinned on the website always appear at the top of Forums, and they update when you refresh. When signed in, Home and Forums recognize items you read on the website."),
                        .bullets([
                            "Use Forums in Discover to browse topics.",
                            "Use the filter menu to show Recent, New, Unread, Since Last Visit, Following, or Saved topics.",
                            "For Recent, New, Unread, and Since Last Visit, you can also choose Apple Related or Non-Apple Related topics, and a category.",
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
                            "Milder crude words, and put-downs aimed at another member, get a friendly reminder. You can still post, but it's worth rewording. Disagreeing strongly about an app or a product is fine.",
                            "If AI helped you write something, the community appreciates a short note saying so.",
                            "With Apple Intelligence, Smarter Guideline Reminders reads your whole draft and skips a reminder that clearly doesn't fit. Turn it off in Settings > Intelligence.",
                            "If a reminder seems wrong, choose This Doesn't Seem Right to tell the editorial team, so the checker can improve. This needs you to be signed in.",
                        ]),
                        .heading("Reading AppleVis in your own language"),
                        .body("AppleVis is written and moderated in English. It's the one shared language that lets the whole community talk in the same place, and lets the editorial team review everything that's posted."),
                        .body("You don't have to read it in English. Turn on Auto-Translate Content in Settings > Content Translation, and blog posts, forum topics, app entries, podcast episodes, guides, bug reports, comments, and Help can be translated into your language on your device."),
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
                        .heading("Topics and entries you posted"),
                        .body("To edit a forum topic, blog post, or other item you posted, open it and choose the actions menu at the top right. Choose Edit, for example Edit Forum Topic."),
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
                        .body("To delete a forum topic or other item you posted, open it, choose the actions menu at the top right, and choose Delete."),
                        .warning("Deleting is permanent and can't be undone. If you only want to change the wording, use Edit instead."),
                    ]
                ),
                HelpArticle(
                    id: "community-submit-bug",
                    title: "Submitting a Bug Report",
                    summary: "How to report a new accessibility bug using the three-step guided form.",
                    content: [
                        .body("If you've found an accessibility bug that isn't in the tracker yet, you can report it from the app. You need to be signed in. You also need to report the bug to Apple first, using Feedback Assistant. AppleVis only accepts bugs that have already been reported to Apple."),
                        .heading("Before you start"),
                        .bullets([
                            "Check the Bug Tracker to make sure the bug isn't already reported.",
                            "Report it to Apple first using Feedback Assistant, at feedbackassistant.apple.com. Apple gives your report a number that starts with FB. Keep that number, because you'll need it.",
                            "Sign in from Profile if you haven't already.",
                        ]),
                        .heading("Step 1: Describe the Bug"),
                        .steps([
                            "Open Discover, go to Contribute, and choose Submit a Bug Report.",
                            "Give it a short, specific title, for example \"VoiceOver skips toolbar buttons in Mail.\"",
                            "Write a description: what you expected, what happened, and how to reproduce it. The minimum is 30 characters, but more detail helps.",
                            "Add your email address in case the team needs to follow up.",
                            "Choose Next.",
                        ]),
                        .tip("Choose Rewrite on this step if you'd like help making your description clearer."),
                        .heading("Step 2: Environment"),
                        .steps([
                            "Choose the platform: iOS, iPadOS, or macOS.",
                            "Enter the software version where you saw the bug.",
                            "Say whether you can reproduce it reliably.",
                            "Enter the number Apple gave your report. It starts with FB, for example FB12345678. You can find it next to your report in Feedback Assistant. If you haven't reported the bug to Apple yet, choose Open Feedback Assistant on this step.",
                            "Choose how you'd like to be credited if the report helps lead to a fix: by name, by your AppleVis username, or anonymously.",
                            "Choose Next.",
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
                            "Choose Next.",
                        ]),
                        .heading("Step 2: Your Content"),
                        .steps([
                            "Enter a valid email address. The editorial team may reply to follow up.",
                            "Write a few sentences on why this post would interest AppleVis readers. This is required, and it helps the editors understand your idea.",
                            "Write, import, or paste your draft. The minimum is 50 characters.",
                            "Use Import File to bring in a plain text, Markdown, Rich Text, or web page file from Files or iCloud Drive, or Paste to use what's on your clipboard.",
                            "Choose Next.",
                        ]),
                        .note("Your draft is sent to the editors as plain text. A Markdown file comes in exactly as written, with its marks such as # for headings, and the editors read it that way. Rich Text and web page files come in as their words only. Paragraphs and lists stay, and each link keeps its address after the link text."),
                        .tip("Word and Pages documents can't be imported directly. In Word or Pages, export the document as Rich Text and import that, or copy the text and use Paste."),
                        .heading("Step 3: Review and Submit"),
                        .body("Check the title, category, your reason, and your draft, then choose Submit. A thank-you screen confirms it was sent, and the editorial team will follow up with their decision."),
                        .note("The AppleVis editorial team reviews every submission and decides whether to publish it. They'll contact you either way."),
                        .tip("Cancel is at the top left on every step. From step 2, Back is right next to it. Use Back to return to the previous step without losing your draft."),
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
                            "Use Choose Audio File to select your episode from Files, iCloud Drive, or another connected storage service. AppleVis accepts one MP3, M4A, or WAV file, up to 200 MB. For a larger file, share it with a service like Dropbox, then send the link using Contact AppleVis.",
                            "Choose Rewrite if you'd like help with the description.",
                            "Choose Next once you've written a description and selected a file.",
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
                            "Confirm the two checkboxes on the Before You Begin screen, then choose Continue.",
                            "Choose the platform: iPhone and iPad, Mac, Apple Watch, or Apple TV.",
                            "Search by name or paste an App Store link. If the app isn't on the App Store, which is the case for some Mac apps, choose Enter Details Manually.",
                            "Select the right result and choose Next.",
                        ]),
                        .heading("Step 2: App Details"),
                        .body("What you fill in depends on the platform. Confirm the details taken from the App Store, then describe the app's accessibility."),
                        .bullets([
                            "iPhone and iPad apps: separate ratings for VoiceOver Performance, Button Labelling, and Usability, plus the devices the app supports. The devices are ticked for you from the App Store, and you can untick any the app doesn't really support.",
                            "iPhone and iPad apps also ask for the iOS Version Tested. It's filled in with your device's iOS version. Change it if you tested the app on another device. Enter just the number, such as 26.0.1.",
                            "The description comes from the App Store, in English when the developer provides it. If it's only in another language, AppleVis translates it into English on your device and adds a line saying it was translated.",
                            "Mac, Apple Watch, and Apple TV apps: one combined Usability rating.",
                            "Every platform asks for Accessibility Comments. The minimum is 20 characters, but the more you share, the more useful it is to the next person.",
                        ]),
                        .tip("Choose Rewrite under Accessibility Comments if you'd like help with what you've written."),
                        .body("When you're done, choose Next. Nothing is sent yet. Next takes you to step 3, where you can check everything first."),
                        .heading("Step 3: Review and Submit"),
                        .body("Check everything, then choose Submit. A thank-you screen confirms it was sent. The AppleVis team reviews every submission before it appears in the directory."),
                        .note("If the app looks like it's already in the App Directory, a warning lists the matching app entries. Choose one to open its page and check. When you go back, your submission is still there."),
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
                        .body("To report a whole forum topic, app entry, blog post, guide, bug report, or podcast episode, open it, choose the actions menu at the top right, and choose Report. The same form opens."),
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
                            "The mini player stays at the bottom of the screen while an episode is loaded. Choose the episode title in it to open the full player. Open Player on Play, in Settings > Podcasts, opens the full player each time you play an episode from a list.",
                            "Use Add to Queue or Play Next to choose what plays after the current episode.",
                            "Download episodes to listen offline.",
                            "AppleVis remembers where you stopped in each episode. To go back to the beginning, open the episode and use Start Over in Episode Tools.",
                            "Listened, in Episode Tools, is a switch you can turn on or off as a reminder that you've heard an episode. It turns on by itself when an episode plays to the end, and episode lists show a checkmark for it. It doesn't change your place in the episode.",
                            "When an episode has chapters, move between them from the chapter list.",
                            "The Lock Screen shows the episode title, artwork, progress, and playback controls.",
                            "On supported iPhone models, the Dynamic Island shows the episode title and playback state while you use other apps.",
                            "AirPods: press once to play or pause. A double press skips forward and a triple press skips back, by your skip intervals. Headphone Controls, in Settings > Podcasts, can make them play the next episode in your queue and go back to the start of the episode instead.",
                            "Control Center shows Now Playing, with artwork, title, and controls.",
                        ]),
                        .tip("Adjust playback in Settings > Podcasts: speed, skip intervals, auto-play, Trim Silence, Voice Boost, an equaliser (Flat, Speech Clarity, Bass Boost, or Treble Boost), a sleep timer, resume rewind, and Auto-Download and Auto-Delete for downloads."),
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
                            "Web Search: the search engine Search the Web uses in Ask the Mouse. Choose DuckDuckGo, Google, Bing, or Ecosia. Results open the way Web Links is set.",
                            "Links in posts and comments to other AppleVis pages, such as a forum topic, app entry, guide, blog post, podcast episode, or bug report, open in the app instead of a browser.",
                            "AppleVis Tips: short tips that appear from time to time to save you a step.",
                            "Show What's New on Home: whether Home shows the New view, the summary, and new-activity badges.",
                            "Filter Profanity: masks milder crude words in what you read. It's on by default. See Filtering Language You See.",
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
                            "Saved & Sync controls what syncs through iCloud. Turn on Enable iCloud Sync, then choose what to sync: Saved Items, Following, Podcast Position, Podcast Queue, Read History, and Settings & Preferences. Saved Items includes your saved Mouse answers and recent questions for Ask the Mouse.",
                            "Privacy explains the account, profile, community, support, and notification information AppleVis handles, what stays on this device, and what can sync through your private iCloud account. The app has no advertising or third-party analytics SDKs.",
                            "Show What's New on Home, in Settings > General, controls whether Home shows the New view, the summary, and new-activity badges. Your reading history is still kept on your device, so turning this off only makes Home quieter.",
                            "Clear All Local Data removes cached content, downloads, saved items, and reading history from this device. Your account, iCloud data, and app settings aren't affected.",
                        ]),
                        .note("The app's Apple Intelligence features work on your device. Anything you choose to publish, report, or send to the editorial team still goes to AppleVis servers to complete that request."),
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
                            "Open Settings > Storage & Cache.",
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
                            "Smarter Guideline Reminders skips a guideline reminder that clearly doesn't fit your draft. It never adds one. Needs Apple Intelligence.",
                        ]),
                        .note("Apple Intelligence features need an iPhone 15 Pro, iPhone 15 Pro Max, or any iPhone 16 or iPhone 17 model, with iOS 26 or later and Apple Intelligence turned on in iOS Settings. See Apple Intelligence Features for details."),
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
                            "\"Hey Siri, what's new on AppleVis\" speaks a summary of what's new that you haven't read yet.",
                            "\"Hey Siri, report a bug to AppleVis\" opens the accessibility bug report form.",
                            "\"Hey Siri, ask the AppleVis Mouse\" asks for your question, then opens Ask the Mouse with the answer. This needs Apple Intelligence.",
                        ]),
                        .body("If Siri uses another language, you can say these phrases in that language too. Settings > Siri & Shortcuts lists every phrase."),
                        .heading("Spotlight"),
                        .body("Spotlight can find AppleVis topics, apps, podcasts, and guides from iOS Search. Anything you've opened is added, so it's easy to find again."),
                        .body("Everything you've saved or followed is added too, even if you saved it on another device. So are the Help articles, so searching iOS for a setting such as Trim Silence finds the article that explains it."),
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
                            "iPhone 15 Pro, iPhone 15 Pro Max, or any iPhone 16 or iPhone 17 model.",
                            "iOS 26 or later.",
                            "Apple Intelligence turned on in iOS Settings > Apple Intelligence & Siri.",
                        ]),
                        .heading("What it does in AppleVis"),
                        .bullets([
                            "AI Summaries: shortens long forum threads, blog posts, guides, and app descriptions.",
                            "Accessibility Consensus: turns an app's accessibility comments into one paragraph.",
                            "Rewrite: improves a reply, comment, or submission draft before you send it, and can draft a bio for your profile.",
                            "Translate: offered when your draft or search isn't in English.",
                            "Guidelines Check: checks your draft for common posting issues and gives friendly suggestions.",
                            "Smarter Guideline Reminders: reads your whole draft and skips a guideline reminder that clearly doesn't fit, like one for a friendly thank-you. It never adds reminders.",
                            "Ask the Mouse: answers questions in your own words from Help, guides, the App Directory, and the rest of AppleVis.",
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
                    id: "smart-ask-the-mouse",
                    title: "Ask the Mouse",
                    summary: "Ask a question in your own words, and get an answer from Help, guides, the App Directory, and the rest of AppleVis.",
                    content: [
                        .body("Ask the Mouse lets you ask a question in your own words. The Mouse searches Help, AppleVis guides, the App Directory, forums, podcasts, blog posts, bug reports, What's New, and your saved items. Then it answers from what it found."),
                        .body("With VoiceOver, you hear a soft patter and feel a light tap every second while the Mouse is searching. If it takes a while, VoiceOver says Still searching. Swipe to the searching row to hear what the Mouse is doing and how long it has been searching."),
                        .body("It needs Apple Intelligence. On a device without it, Ask the Mouse isn't shown, and search works as before."),
                        .heading("Where to find it"),
                        .bullets([
                            "On Home, choose Ask the Mouse at the top right, next to Post. It's shown visually as the Mouse's face.",
                            "In Help, choose Ask the Mouse at the top of the screen.",
                            "In Discover, start a search, then choose Ask the Mouse above the results.",
                            "With Siri, say \"Ask the AppleVis Mouse\", then say your question.",
                        ]),
                        .heading("Asking a question"),
                        .steps([
                            "Type your question, or choose one of the suggestions.",
                            "Choose Ask. While the Mouse searches, it shows what it's looking through. With VoiceOver, you hear this if the search takes more than a few seconds.",
                            "When the answer is ready, you hear a sound and VoiceOver moves to it.",
                        ]),
                        .body("A question can be up to 300 characters, which is plenty for a detailed question. When you're close, a line under the question field says how many characters are left, and VoiceOver says it once. A longer question, typed or pasted, is shortened, and the Mouse tells you. Shorter questions get the best answers, because the Mouse has more room to read what it found."),
                        .body("On screen, the answer appears as the Mouse writes it. VoiceOver waits for the finished answer, so it never reads half a sentence."),
                        .body("If the best parts of a guide don't answer your question, the Mouse takes a closer look. It reads the rest of the guide, its members' comments, and any matching forum discussion a part at a time, and answers from the parts that help. This can take a little longer, and you can choose Stop at any time."),
                        .heading("What an answer includes"),
                        .bullets([
                            "A short answer, and where it came from, such as a Help article or a guide, with when it was posted. Choose the source to read all of it.",
                            "Other Sources, Newest First: other pages that answer your question, each saying whether it agrees with the answer or says something different, and when it was posted.",
                            "Known bugs from the AppleVis Bug Tracker, when your question is about something not working. The Mouse says whether the bug is still active or fixed, and gives any workaround.",
                            "What members say about an app you name, such as \"Is the Starbucks app accessible?\", from the newest comments on its app entry.",
                            "Podcast episodes, when an episode's notes or transcript explain the answer.",
                            "AppleVis blog posts, for news such as what's new in the latest iOS for VoiceOver users.",
                            "A forum discussion members have replied to, rather than an unanswered one, when both match your question.",
                            "Tips from members, when they help. The Mouse also reads members' comments on the guides it uses, and for questions about Apple devices or other people's experiences, a matching forum discussion. When part of the answer comes from members, the Mouse says so, and the source says From members' comments on a guide or From a forum discussion.",
                            "Take Me There, when a screen can help. It opens that screen.",
                            "For some settings, an offer to change it for you. Nothing changes until you choose Yes, and you can undo it.",
                            "Apps it found, for iPhone and iPad, Mac, Apple Watch, or Apple TV, depending on the device you ask about, grouped by how well they match what you asked, with a line about each. Apps that won, were runners-up, or were nominated in the AppleVis Golden Apple Awards say so and come first among equally good matches, followed by apps members have commented on most. Each app says how many member comments it has.",
                            "More From AppleVis: related guides, forum topics, podcast episodes, blog posts, and bug reports. The Mouse reads the best few, and those that answer your question move to Other Sources. A page that doesn't answer it is left out, and pages that say the same thing are listed together. While it reads, the heading says The Mouse is reading these. When it's done, the heading says Not Checked, because the results still listed there haven't been read.",
                        ]),
                        .note("Guides and app entries that haven't been updated for a few years are marked, so you know to check that they're still current. A guide written for an older iOS than yours says so, such as Written for iOS 17."),
                        .body("For a question about how AppleVis is working for you, such as Why don't I get notifications?, the Mouse looks at your AppleVis settings on that screen. If a setting explains it, the answer says which one and where to change it. The Mouse only looks. It never changes a setting unless you ask it to. The answer then shows I checked your app settings, which opens that screen."),
                        .body("Commands, gestures, and setting names are given exactly as the source writes them. When you open a guide from an answer, it opens at the paragraph the answer came from, with VoiceOver on it."),
                        .body("After an answer, the Mouse asks Did this answer your question? Your Yes or No stays on this device and helps the Mouse read the most useful kinds of source first. It also remembers which guides and forum discussions helped with which kinds of question. A guide that answered a similar question is read first next time, and one that didn't is passed over. If you ask the same question again within an hour, the answer appears straight away."),
                        .heading("Doing more with an answer"),
                        .body("With VoiceOver, swipe up or down on the answer for its actions. Without VoiceOver, touch and hold the answer."),
                        .bullets([
                            "Copy Answer copies just the answer.",
                            "Copy Answer with Sources copies your question, the answer, and where it came from, with links.",
                            "Share Answer sends the same text through the share sheet.",
                            "Open Source opens the Help article, guide, or discussion the answer came from.",
                            "Save Answer keeps it in For You > Saved, under Mouse Answers. Saved answers sync with iCloud like your other saved items.",
                            "Ask a Follow-Up moves you to the question field.",
                        ]),
                        .body("When the answer is steps to follow, each step is numbered and read on its own, so you can follow along as you try each one. To hear all the steps as one item, swipe up or down on a step to Group Answer."),
                        .body("A long answer, such as the answer to What's new?, is read as one item at first. To read it a paragraph or sentence at a time, which is easier on a braille display, swipe up or down on it to Ungroup Answer. Group Answer joins it back together."),
                        .body("Apps in an answer have the same Save and Share actions as anywhere else in AppleVis."),
                        .heading("Follow-up questions"),
                        .body("Under the latest answer, You Might Also Ask suggests two or three questions to ask next. Choose one to ask it as a follow-up, with nothing to type."),
                        .body("You can keep asking. The Mouse remembers your earlier questions, so a follow-up such as \"And how do I stop it?\" makes sense. To begin again, choose Start Over, just after Ask. It clears the answers on screen, and your saved answers and recent questions are kept."),
                        .body("If a question doesn't say what it's about, such as How do I turn it off?, the Mouse asks what you mean. It offers two or three questions to choose from, and choosing one asks it."),
                        .heading("About Me"),
                        .body("About Me tells the Mouse which devices you use and how you use them, such as VoiceOver, a braille display, or Zoom. When a question doesn't say, the Mouse leads with the answer for your setup. A question that names a device or method is always answered for that one."),
                        .steps([
                            "In Ask the Mouse, choose About Me.",
                            "Choose Fill In from This Device to start from this device and the features it's using now, or turn on each device and feature yourself.",
                            "Changes are saved straight away. Clear About Me turns everything off.",
                        ]),
                        .heading("Past Conversations"),
                        .body("Past Conversations keeps your last 10 conversations with the Mouse, with their answers and sources. It appears in Ask the Mouse once you've had a conversation."),
                        .body("Open a conversation to read it again. Choose Continue This Conversation to reopen it in Ask the Mouse, so your next question follows on from it. To delete one, swipe on it, or with VoiceOver use the Actions rotor. Clear Past Conversations deletes them all, and your saved answers are kept."),
                        .heading("When the Mouse can't find it"),
                        .body("Under each answer, Need More Help? is a heading, so the Headings rotor takes you straight to Ask in the Forums and Search the Web."),
                        .body("The Mouse only answers from AppleVis, so it tells you when it can't find something rather than guessing."),
                        .body("For common subjects, such as VoiceOver gestures, braille, keyboards, the rotor, or VoiceOver on the Mac, the Mouse always reads AppleVis's essential guide on that subject, even when the search doesn't put it first."),
                        .body("The Mouse checks that a source is about the same device and the same way of using it as your question, such as a braille display on an iPhone rather than a keyboard on a Mac. When it finds only something close, it says so, and the source is marked Closest match."),
                        .body("Sometimes Apple Intelligence itself can't answer. The Mouse tells you why. It may not support your language yet, it may be busy, or its safety check may have stopped the answer, which sometimes happens by mistake. Try asking another way, or try again in a moment."),
                        .body("Choose Ask in the Forums to start a forum topic with your question filled in, so the community can help. Search the Web opens a web search, using DuckDuckGo unless you choose another search engine in Settings > General > Web Search. The Mouse words the search for you, naming the device and feature, and shows what it will search for. Those results aren't from AppleVis."),
                        .body("When Apple has a page on the subject, such as Apple's list of braille display commands or VoiceOver gestures, Need More Help? also offers Apple's Guide. It opens Apple's own page. When no specific page fits, it offers the user guide for your device, such as the iPhone or Apple Watch User Guide. For Be My Eyes questions it can offer a Be My Eyes help page, and for learning VoiceOver from the beginning, Hadley's free lessons. The Mouse doesn't read these pages for you, so you always get their exact words."),
                        .body("For any question about an Apple device, Need More Help? also offers Search Apple Support, which searches Apple's own help site. And when no hand-picked page fits, the Mouse can choose a page from Apple's user guides for iPhone, iPad, Apple Watch, Mac, AirPods, and Apple TV."),
                        .body("If the Mouse couldn't answer, found only something close, or you said the answer didn't help, Suggest This Topic to AppleVis sends your question to the editorial team, so they know a guide is needed. It's sent only if you choose it, and only your question, name, and email go with it. You need to be signed in."),
                        .body("The Mouse sticks to Apple devices, accessibility, apps, and AppleVis. If you ask about something else, such as cars or recipes, it says so kindly and doesn't search."),
                        .heading("Privacy"),
                        .body("Apple Intelligence runs on your device. To search AppleVis, the Mouse sends a few search words to the AppleVis website, like any search. Your full question and the answer stay on your device."),
                        .body("Recent Questions keeps your last 8 questions, not the answers. Choose one to ask it again, and use Save Answer on the answer to keep it. To remove one question, swipe on it, or with VoiceOver use the Actions rotor. Clear Recent Questions removes them all."),
                        .body("Recent questions, past conversations, and saved answers sync with your other devices through iCloud when Saved Items sync is on in Settings > Saved & Sync. They are never sent to AppleVis."),
                        .body("About Me, and what the Mouse learns from your Yes and No, stay on this device. They're only used by Apple Intelligence on your device."),
                        .body("A saved answer keeps the words it had when you saved it. When you open it, it checks whether a guide it came from has been updated, or a forum discussion has new replies. If so, it says what changed and offers Ask the Mouse Again."),
                        .tip("Ask the way you'd ask a friend, such as \"Find me a fully accessible dice game\" or \"How do I turn off the sounds?\""),
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
        // Quick Reference: commands, gestures, and button steps for Apple
        // devices, written by AppleVis in its own words and checked against
        // Apple's guides. Apple's own pages can't be copied into the app,
        // or read by it (App Review 5.2.1 and 4.5.1), but the facts in them
        // can be written up here and linked back to. Checked against iOS 27,
        // iPadOS 27, macOS 27, and watchOS 27 on 2026-10-04. Re-check each
        // article against its source after every major Apple release.
        // Requested directly (2026-10-04).
        HelpSection(
            id: "reference",
            title: "Quick Reference",
            icon: "list.bullet.rectangle",
            description: "VoiceOver and braille on every Apple device, typing, low vision, recognition, the web, everyday tasks, fixing problems, updates, getting help, and a glossary of terms.",
            articles: [
                HelpArticle(
                    id: "ref-voiceover-gestures",
                    title: "VoiceOver Gestures on iPhone and iPad",
                    summary: "The touchscreen gestures for moving around, taking action, and controlling VoiceOver.",
                    content: [
                        .body("These gestures work when VoiceOver is on. They're the same on iPhone and iPad unless noted."),
                        .body("You can make a two-finger gesture with two fingers on one hand, one finger on each hand, or both thumbs. Instead of selecting an item and double-tapping, you can touch and hold the item with one finger, then tap the screen with another. This is called a split tap."),
                        .heading("Move around the screen"),
                        .bullets([
                            "Hear an item: touch it, or drag one finger around the screen.",
                            "Next item: swipe right.",
                            "Previous item: swipe left.",
                            "Move into a group of items: two-finger swipe right.",
                            "Move out of a group: two-finger swipe left.",
                            "First item on the screen: four-finger tap near the top of the screen.",
                            "Last item on the screen: four-finger tap near the bottom of the screen.",
                            "Read the whole screen from the top: two-finger swipe up.",
                            "Read from the current item onward: two-finger swipe down.",
                            "Pause or continue reading: two-finger tap.",
                            "Hear more detail, such as your position in a list: three-finger tap.",
                        ]),
                        .heading("Scroll"),
                        .bullets([
                            "Scroll down one page: three-finger swipe up.",
                            "Scroll up one page: three-finger swipe down.",
                            "Scroll right one page: three-finger swipe left.",
                            "Scroll left one page: three-finger swipe right.",
                        ]),
                        .heading("Take action"),
                        .bullets([
                            "Activate the selected item: double-tap.",
                            "Touch and hold the selected item: triple-tap.",
                            "Adjust a slider: select it, then swipe up or down with one finger.",
                            "Play or pause, take a photo, or start or stop a recording or timer: two-finger double-tap. This is called the Magic Tap.",
                            "Go back or dismiss an alert: two-finger scrub. Move two fingers back and forth three times quickly, like drawing the letter z.",
                            "Rename an item's label: two-finger double-tap and hold.",
                            "Use a standard gesture once: double-tap and hold until you hear three rising tones, then make the gesture. VoiceOver gestures come back when you lift your finger.",
                            "On iPhone, bring the top half of the screen within reach: swipe up from the bottom edge with one finger, then swipe down without lifting.",
                        ]),
                        .heading("Control VoiceOver"),
                        .bullets([
                            "Mute or unmute speech: three-finger double-tap. If Zoom is also on, three-finger triple-tap.",
                            "Turn Screen Curtain on or off: three-finger triple-tap. If Zoom is also on, three-finger quadruple-tap. With Screen Curtain on, the display is dark but everything still works.",
                            "Open the Item Chooser, a list of everything on the screen: two-finger triple-tap.",
                            "Open VoiceOver quick settings: two-finger quadruple-tap.",
                            "Start or stop Live Recognition: four-finger triple-tap.",
                        ]),
                        .heading("The rotor"),
                        .bullets([
                            "Choose a rotor setting: turn two fingers on the screen, like turning a dial.",
                            "Move to the previous item of that kind, or increase a value: swipe up.",
                            "Move to the next item of that kind, or decrease a value: swipe down.",
                        ]),
                        .note("Checked against Apple's iPhone and iPad User Guides for iOS 27 and iPadOS 27, in October 2026. Gestures can change with new software."),
                        .source(label: "Apple Support: Use VoiceOver gestures on iPhone", url: "https://support.apple.com/guide/iphone/use-voiceover-gestures-iph3e2e2281/ios"),
                        .source(label: "Apple Support: Use VoiceOver gestures on iPad", url: "https://support.apple.com/guide/ipad/use-voiceover-gestures-ipad9a246584/ipados"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-voiceover-keyboard-ios",
                    title: "VoiceOver Keyboard Commands on iPhone and iPad",
                    summary: "Commands for using VoiceOver with a Magic Keyboard or other external keyboard.",
                    content: [
                        .body("VO stands for the VoiceOver modifier. It's either Caps Lock, or Control and Option pressed together. Choose which in Settings > Accessibility > VoiceOver > Typing > Modifier Keys."),
                        .body("For example, VO-Right Arrow means hold the modifier, then press Right Arrow."),
                        .heading("Get around"),
                        .bullets([
                            "Next or previous item: VO-Right Arrow or VO-Left Arrow.",
                            "Activate the selected item: VO-Space bar.",
                            "Touch and hold the selected item: VO-Shift-M.",
                            "Go to the Home Screen: VO-H.",
                            "Open the App Switcher: VO-H, pressed twice.",
                            "Go to the status bar: VO-M.",
                            "Open Notification Center: VO-M, then Option-Up Arrow.",
                            "Open Control Center: VO-M, then Option-Down Arrow.",
                            "Open Search: Option-Up Arrow.",
                            "Open the Item Chooser: VO-I.",
                            "Go back: Escape.",
                        ]),
                        .heading("Read and find"),
                        .bullets([
                            "Read from the current item: VO-A.",
                            "Read from the top: VO-B.",
                            "Pause or resume speech: Control.",
                            "Copy the last thing spoken: VO-Shift-C.",
                            "Find text: VO-F.",
                        ]),
                        .heading("Control VoiceOver"),
                        .bullets([
                            "Turn on VoiceOver Help, which names keys without doing anything: VO-K. Press Escape to leave it.",
                            "Mute or unmute speech: VO-S.",
                            "Turn Screen Curtain on or off: VO-Fn-Hyphen, or VO-Globe-Hyphen on some keyboards.",
                            "Play or pause, or start or stop an action: VO-Hyphen.",
                            "Rename an item's label: VO-Slash.",
                            "Swipe up or down: VO-Up Arrow or VO-Down Arrow.",
                            "Turn the rotor: VO-Command-Left Arrow or VO-Command-Right Arrow.",
                            "Change the rotor setting's value: VO-Command-Up Arrow or VO-Command-Down Arrow.",
                        ]),
                        .heading("Quick Nav"),
                        .body("Quick Nav lets you move with the arrow keys alone. Turn it on or off by pressing Left Arrow and Right Arrow together."),
                        .bullets([
                            "Next or previous item: Right Arrow or Left Arrow.",
                            "Next or previous item of the rotor's kind: Up Arrow or Down Arrow.",
                            "First or last item: Control-Up Arrow or Control-Down Arrow.",
                            "Activate an item: Up Arrow and Down Arrow together.",
                            "Turn the rotor: Up Arrow with Left Arrow, or Up Arrow with Right Arrow.",
                            "Scroll: Option with an arrow key.",
                        ]),
                        .heading("Single-key Quick Nav on webpages"),
                        .body("Turn on Quick Nav with VO-Q, then press a single key to jump to the next item of a kind. Add Shift to go to the previous one."),
                        .bullets([
                            "Heading: H. A heading of a given level: 1 to 6.",
                            "Link: L.",
                            "Text field: R.",
                            "Button: B.",
                            "Form control: C.",
                            "Image: I.",
                            "Table: T.",
                            "Static text: S.",
                            "Landmark: W.",
                            "List: X.",
                            "Next item of the same type as the current one: M.",
                        ]),
                        .heading("Edit text"),
                        .body("These work with Quick Nav off. VoiceOver reads the text as the insertion point moves."),
                        .bullets([
                            "By character: Left Arrow or Right Arrow.",
                            "By word: Option-Left Arrow or Option-Right Arrow.",
                            "By line: Up Arrow or Down Arrow.",
                            "Start or end of the line: Command-Left Arrow or Command-Right Arrow.",
                            "Previous or next paragraph: Option-Up Arrow or Option-Down Arrow.",
                            "Top or bottom of the text: Command-Up Arrow or Command-Down Arrow.",
                            "Select as you move: add Shift to any of these.",
                            "Select all: Command-A.",
                            "Copy, cut, or paste: Command-C, Command-X, or Command-V.",
                            "Undo or redo: Command-Z or Shift-Command-Z.",
                        ]),
                        .note("Checked against Apple's iPhone User Guide for iOS 27, in October 2026. Commands can change with new software."),
                        .source(label: "Apple Support: Use VoiceOver on iPhone with an Apple external keyboard", url: "https://support.apple.com/guide/iphone/use-voiceover-with-an-external-keyboard-iph6c494dc6/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-braille-display",
                    title: "Braille Display Commands on iPhone and iPad",
                    summary: "Common commands for a braille display with a Perkins-style keyboard.",
                    content: [
                        .body("These commands are for braille displays with a Perkins-style keyboard. Each one is the Space bar pressed together with the dots listed. For example, Space with dots 2-5 means press Space, dot 2, and dot 5 at the same time."),
                        .body("You can change or add commands in Settings > Accessibility > VoiceOver > Braille. Choose your display, then More Info, then Braille Commands."),
                        .heading("Get around"),
                        .bullets([
                            "Previous item: Space with dot 1.",
                            "Next item: Space with dot 4.",
                            "First item: Space with dots 1-2-3.",
                            "Last item: Space with dots 4-5-6.",
                            "Go back, or leave the current context: Space with dots 1-2.",
                            "Home button: Space with dots 1-2-5.",
                            "App Switcher: Space with dots 1-2-5, pressed twice.",
                            "Control Center: Space with dots 2-5.",
                            "Notification Center: Space with dots 4-6.",
                            "Status bar: Space with dots 2-3-4.",
                            "Item Chooser: Space with dots 2-4.",
                            "On iPad, left Split View app: Space with dots 3-5.",
                            "On iPad, right Split View app: Space with dots 2-6.",
                        ]),
                        .heading("Scroll"),
                        .bullets([
                            "Up one page: Space with dots 3-4-5-6.",
                            "Down one page: Space with dots 1-4-5-6.",
                            "Left one page: Space with dots 2-4-6.",
                            "Right one page: Space with dots 1-3-5.",
                            "Hear the page number or rows shown: Space with dots 3-4.",
                        ]),
                        .heading("Rotor"),
                        .bullets([
                            "Previous rotor setting: Space with dots 2-3.",
                            "Next rotor setting: Space with dots 5-6.",
                            "Previous item of the rotor's kind: Space with dot 3.",
                            "Next item of the rotor's kind: Space with dot 6.",
                        ]),
                        .heading("Take action and read"),
                        .bullets([
                            "Activate the selected item: Space with dots 3-6.",
                            "3D Touch on the selected item: Space with dots 3-5-6.",
                            "Volume up: Space with dots 3-4-5.",
                            "Volume down: Space with dots 1-2-6.",
                            "Show or hide the onscreen keyboard: Space with dots 1-4-6.",
                            "Read from the selected item: Space with dots 1-2-3-5.",
                            "Read from the top: Space with dots 2-4-5-6.",
                        ]),
                        .heading("Edit text"),
                        .bullets([
                            "Delete: Space with dots 1-4-5.",
                            "Return: Space with dots 1-5.",
                            "Tab: Space with dots 2-3-4-5.",
                            "Shift-Tab: Space with dots 1-2-5-6.",
                            "Select all: Space with dots 2-3-5-6.",
                            "Select to the left: Space with dots 2-3-5.",
                            "Select to the right: Space with dots 2-5-6.",
                            "Copy: Space with dots 1-4.",
                            "Cut: Space with dots 1-3-4-6.",
                            "Paste: Space with dots 1-2-3-6.",
                            "Undo: Space with dots 1-3-5-6.",
                            "Redo: Space with dots 2-3-4-6.",
                            "Find text: Space with dots 1-2-4.",
                            "Start dictation in a text field: Space with dots 1-5-6. Outside a text field, the same keys play or pause audio.",
                        ]),
                        .heading("Control VoiceOver"),
                        .bullets([
                            "Pause or continue speech: Space with dots 1-2-3-4.",
                            "Speech on or off: Space with dots 1-3-4.",
                            "Screen Curtain on or off: Space with all six dots, 1 to 6.",
                            "Quick Nav on or off: Space with dots 1-2-3-4-5.",
                            "Rename an item's label: Space with dots 1-2-3-4-6.",
                            "VoiceOver Help: Space with dots 1-3.",
                        ]),
                        .heading("Braille"),
                        .bullets([
                            "Pan left: Space with dot 2.",
                            "Pan right: Space with dot 5.",
                            "Switch braille output, such as contracted or uncontracted: Space with dots 1-2-4-5.",
                            "Switch braille input: Space with dots 2-3-6.",
                            "Translate what you've typed: Space with dots 4-5.",
                            "Show or hide announcement history: Space with dots 1-3-4-5.",
                        ]),
                        .heading("Extra commands on 8-dot displays"),
                        .bullets([
                            "Delete: Space with dot 7.",
                            "Return: Space with dot 8.",
                            "Previous container: Space with dots 1-7.",
                            "Next container: Space with dots 4-7.",
                            "Touch and hold: Space with dots 3-6-7-8.",
                            "Mute: Space with dots 1-3-4-7.",
                        ]),
                        .tip("If a command does nothing, check Braille Commands for your display in VoiceOver settings. Some displays assign their own keys, and you may have changed one."),
                        .note("Checked against Apple's list of common braille commands in October 2026. Commands can change with new software."),
                        .source(label: "Apple Support: Common braille commands for VoiceOver on iPhone and iPad", url: "https://support.apple.com/en-us/118665"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-voiceover-keyboard-mac",
                    title: "VoiceOver Keyboard Commands on Mac",
                    summary: "The most-used VoiceOver keys for getting around a Mac.",
                    content: [
                        .body("VO stands for the VoiceOver modifier: Control and Option pressed together, or Caps Lock. For example, VO-Right Arrow means hold the modifier, then press Right Arrow."),
                        .body("Commands that use a function key, such as F8, also need the Fn key unless you've changed that setting. You can use a number key instead of the function key, so VO-Fn-8 works the same as VO-Fn-F8."),
                        .heading("Start and get help"),
                        .bullets([
                            "Turn VoiceOver on or off: Command-F5. On a Mac or keyboard with Touch ID, hold Command and quickly press Touch ID three times.",
                            "Lock or unlock the VO modifier, so you don't have to hold it: VO-Semicolon.",
                            "Keyboard help, which names keys as you press them: VO-K.",
                            "VoiceOver Help menu: VO-H.",
                            "Commands menu: VO-H, pressed twice.",
                            "VoiceOver Utility, for settings: VO-Fn-F8.",
                            "VoiceOver Tutorial: VO-Fn-Command-F8.",
                            "Stop an action, or close a menu or the rotor: Escape.",
                        ]),
                        .heading("Get around"),
                        .bullets([
                            "Move the VoiceOver cursor: VO with an arrow key.",
                            "Click the item: VO-Space bar.",
                            "Double-click: VO-Space bar, then Space bar again.",
                            "Open a shortcut menu, like a right-click: VO-Shift-M.",
                            "Go into a group, such as a list or toolbar: VO-Shift-Down Arrow.",
                            "Leave the group: VO-Shift-Up Arrow.",
                            "Back to the top level of the app: VO-Shift-Escape.",
                            "Select or deselect an item: VO-Command-Return.",
                            "Open the rotor: VO-U.",
                            "Open the Item Chooser: VO-I.",
                            "Go to the Dock: VO-D.",
                            "Go to the desktop: VO-Shift-D.",
                            "Go to the menu bar: VO-M. Press VO-M twice for the status menus.",
                            "Open or close Notification Center: VO-O.",
                            "Open or close Control Center: VO-Shift-O.",
                            "Find text: VO-F.",
                        ]),
                        .heading("Read and hear status"),
                        .bullets([
                            "Read what's in the VoiceOver cursor: VO-A.",
                            "Read the line, sentence, or paragraph: VO-L, VO-S, or VO-P.",
                            "Read the word: VO-W. Press W again to spell it.",
                            "Hear the item's hint: VO-Shift-N.",
                            "Hear the date and time: VO-Fn-F7.",
                            "Hear the battery status: VO-Fn-F7, pressing F7 twice.",
                            "Open the Notifications menu: VO-N.",
                            "Change how much VoiceOver says: VO-V, then use the arrow keys.",
                        ]),
                        .heading("Quick Nav and screen"),
                        .bullets([
                            "Single-key Quick Nav on or off: VO-Q.",
                            "Arrow-key Quick Nav on or off: VO-Shift-Q.",
                            "Screen Curtain on or off: VO-Shift-Fn-F11.",
                            "Move the VoiceOver cursor to the keyboard focus: VO-Shift-Fn-F4.",
                        ]),
                        .note("Checked against Apple's VoiceOver User Guide for macOS 27, in October 2026. Commands can change with new software. Apple's guide lists every command, by category."),
                        .source(label: "Apple Support: VoiceOver general commands on Mac", url: "https://support.apple.com/guide/voiceover/general-commands-cpvokys01/mac"),
                        .source(label: "Apple Support: VoiceOver navigation commands on Mac", url: "https://support.apple.com/guide/voiceover/navigation-commands-cpvokys04/mac"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-voiceover-trackpad-mac",
                    title: "VoiceOver Trackpad Gestures on Mac",
                    summary: "Trackpad gestures for VoiceOver on a Mac with a trackpad.",
                    content: [
                        .body("To use these, turn on trackpad gestures first. Hold the VO modifier and turn two fingers clockwise on the trackpad. Turn them counterclockwise to switch gestures off. A gesture uses one finger unless it says otherwise."),
                        .heading("Get around"),
                        .bullets([
                            "Hear what's under your finger: touch or drag on the trackpad.",
                            "Next item: flick right.",
                            "Previous item: flick left.",
                            "Go into an item or group: two-finger flick right.",
                            "Leave it: two-finger flick left.",
                            "Scroll a page up or down: three-finger flick up or down.",
                            "Go to the Dock: two-finger double-tap near the bottom of the trackpad.",
                            "Go to the menu bar: two-finger double-tap near the top of the trackpad.",
                            "Choose an app: two-finger double-tap on the left side of the trackpad.",
                            "Choose a window: two-finger double-tap on the right side of the trackpad.",
                        ]),
                        .heading("Take action"),
                        .bullets([
                            "Select or click an item: double-tap anywhere, or split-tap with a second finger.",
                            "Close a menu without choosing: two-finger scrub back and forth.",
                            "Change a slider or other value: flick up to increase, or down to decrease.",
                        ]),
                        .heading("Read"),
                        .bullets([
                            "Read the page from the top: two-finger flick up.",
                            "Read from the VoiceOver cursor onward: two-finger flick down.",
                            "Pause or resume speech: two-finger tap.",
                            "Read the part of the page that's showing: three-finger tap.",
                            "Describe the current item: triple-tap.",
                        ]),
                        .heading("Control VoiceOver"),
                        .bullets([
                            "Mute or unmute speech: three-finger double-tap.",
                            "Screen Curtain on or off: three-finger triple-tap.",
                            "Choose a rotor setting: turn two fingers on the trackpad.",
                            "Previous or next item of the rotor's kind: flick up or flick down.",
                        ]),
                        .note("Checked against Apple's VoiceOver User Guide for macOS 27, in October 2026. Gestures can change with new software."),
                        .source(label: "Apple Support: Standard trackpad gestures for VoiceOver on Mac", url: "https://support.apple.com/guide/voiceover/standard-trackpad-gestures-vo27992/mac"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-restart-iphone-ipad",
                    title: "Restart, Force Restart, and Recovery Mode on iPhone and iPad",
                    summary: "The button steps to turn off, force restart, or put an iPhone or iPad in recovery mode.",
                    content: [
                        .body("Try these in order. A normal restart fixes most problems. Force restart is for a device that isn't responding. Recovery mode is a last resort, used with a computer."),
                        .heading("Turn iPhone or iPad off and on"),
                        .bullets([
                            "iPhone with Face ID: press and hold the side button and either volume button until the sliders appear, then drag Power Off.",
                            "iPhone with a Home button: press and hold the side button, then drag Power Off.",
                            "iPad without a Home button: press and hold the top button and either volume button until the sliders appear, then drag Power Off.",
                            "iPad with a Home button: press and hold the top button, then drag Power Off.",
                            "Any iPhone or iPad: go to Settings > General > Shut Down, then drag the slider.",
                            "To turn it back on: press and hold the side button, or the top button on iPad, until the Apple logo appears.",
                        ]),
                        .tip("With VoiceOver, you don't need to drag. Swipe to Slide to Power Off, then double-tap. The sliders also include Emergency SOS, so make sure you're on Power Off before you double-tap."),
                        .heading("Force restart iPhone"),
                        .body("These steps are for iPhone 8 and later, including iPhone SE (2nd generation and later)."),
                        .steps([
                            "Press and quickly release volume up.",
                            "Press and quickly release volume down.",
                            "Press and hold the side button.",
                            "When the Apple logo appears, let go.",
                        ]),
                        .heading("Force restart iPad without a Home button"),
                        .steps([
                            "Press and quickly release the volume button nearest the top button.",
                            "Press and quickly release the volume button farthest from the top button.",
                            "Press and hold the top button.",
                            "When the Apple logo appears, let go.",
                        ]),
                        .heading("Force restart iPad with a Home button"),
                        .body("Press and hold the top button and the Home button together. Let go when the Apple logo appears."),
                        .heading("Recovery mode"),
                        .body("Use recovery mode when the device is stuck on the Apple logo for several minutes, shows a Connect to computer screen, or your computer doesn't recognize it. You'll need a Mac with Finder, or a Windows PC with the Apple Devices app."),
                        .steps([
                            "Connect the device to the computer with a USB cable.",
                            "Open Finder on a Mac, or the Apple Devices app on a PC.",
                            "Keep the device connected and do the button steps below for your model.",
                            "Keep holding until you see the recovery screen, which asks you to connect to a computer.",
                            "On the computer, choose Update first. Choose Restore only if updating doesn't help.",
                        ]),
                        .bullets([
                            "iPhone 8 and later: press and release volume up, press and release volume down, then press and hold the side button.",
                            "iPhone 7: press and hold the side button and volume down together.",
                            "iPhone 6s and earlier, and iPhone SE (1st generation): press and hold the Home button and the side or top button together.",
                            "iPad without a Home button: press and release the volume button nearest the top button, press and release the one farthest from it, then press and hold the top button.",
                            "iPad with a Home button: press and hold the Home and top buttons together. When the iPad turns off, let go of the top button but keep holding Home.",
                        ]),
                        .warning("Restore erases everything on the device and reinstalls the software. Make sure you have a backup first. If the download takes more than 15 minutes, the device may leave recovery mode. Let the download finish, then do the button steps again."),
                        .note("Checked against Apple's guides and support articles in October 2026."),
                        .source(label: "Apple Support: Force restart iPhone", url: "https://support.apple.com/guide/iphone/force-restart-iphone-iph8903c3ee6/ios"),
                        .source(label: "Apple Support: Force restart iPad", url: "https://support.apple.com/guide/ipad/force-restart-ipad-ipad9955c007/ipados"),
                        .source(label: "Apple Support: If you can't update or restore your iPhone", url: "https://support.apple.com/en-us/118106"),
                        .source(label: "Apple Support: If you can't update or restore your iPad", url: "https://support.apple.com/en-us/108925"),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "ref-restart-mac",
                    title: "Restart, Force Shut Down, and macOS Recovery on Mac",
                    summary: "How to restart a Mac, force it to shut down, and start it in macOS Recovery.",
                    content: [
                        .heading("Restart or shut down"),
                        .bullets([
                            "Restart: Apple menu > Restart.",
                            "Shut down: Apple menu > Shut Down.",
                            "Force a shutdown when the Mac isn't responding: press and hold the power button until it turns off. On a laptop with Touch ID, the Touch ID button is the power button. Anything not saved may be lost.",
                        ]),
                        .tip("To reach the Apple menu with VoiceOver, press VO-M for the menu bar. The Apple menu is the first item."),
                        .heading("Start up in macOS Recovery"),
                        .body("macOS Recovery has tools to reinstall macOS, repair or erase the startup disk, and restore from a Time Machine backup. The steps depend on your Mac."),
                        .heading("macOS Recovery on a Mac with Apple silicon"),
                        .steps([
                            "Turn the Mac off. If it won't shut down, press and hold the power button for up to 10 seconds.",
                            "Press and hold the power button again. Keep holding while the Mac turns on.",
                            "When Loading startup options or the Options icon appears, let go.",
                            "Choose Options, then Continue.",
                        ]),
                        .heading("macOS Recovery on an Intel-based Mac"),
                        .steps([
                            "Turn the Mac off.",
                            "Press and release the power button, then right away press and hold Command and R.",
                            "Keep holding until you see an Apple logo or a spinning globe.",
                        ]),
                        .body("If you're asked, choose your startup disk, then sign in as a user whose password you know. To leave Recovery, choose Restart or Shut Down from the Apple menu."),
                        .note("VoiceOver works in macOS Recovery. Press Command-F5 to turn it on. It can take a minute or two after Recovery starts before it responds."),
                        .note("Checked against Apple's guides and support articles in October 2026."),
                        .source(label: "Apple Support: Shut down or restart your Mac", url: "https://support.apple.com/guide/mac-help/shut-down-or-restart-your-mac-mchlp2522/mac"),
                        .source(label: "Apple Support: How to start up from macOS Recovery", url: "https://support.apple.com/en-us/102518"),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "ref-restart-watch-airpods-tv",
                    title: "Restart or Reset Apple Watch, AirPods, and Apple TV",
                    summary: "Restart, force restart, and reset steps for Apple Watch, AirPods, and Apple TV 4K.",
                    content: [
                        .heading("Apple Watch"),
                        .bullets([
                            "Turn off: press and hold the side button until the sliders appear, choose the power button, then drag Power Off. With VoiceOver, swipe to Power Off and double-tap instead of dragging.",
                            "Turn on: press and hold the side button until the Apple logo appears.",
                            "Force restart, only if a normal restart doesn't work: press and hold the side button and the Digital Crown together for at least 10 seconds, until the Apple logo appears.",
                            "You can't restart Apple Watch while it's charging.",
                        ]),
                        .heading("AirPods and AirPods Pro"),
                        .bullets([
                            "Restart: put them in the case and close the lid for at least 10 seconds.",
                            "Reset AirPods (1st to 3rd generation) or AirPods Pro (1st or 2nd generation): put them in the case, close the lid, and wait 30 seconds. Open the lid, then press and hold the setup button on the back of the case for about 15 seconds, until the light flashes amber, then white.",
                            "Reset AirPods 4 or later, or AirPods Pro 3: put them in the case, close the lid, and wait 30 seconds. Open the lid, then double-tap the front of the case three times.",
                            "After a reset, pair them again from a device signed in to your Apple Account.",
                        ]),
                        .heading("AirPods Max"),
                        .bullets([
                            "Restart: on the right ear cup, press and hold the Digital Crown and the listening mode button together until the light flashes amber, about 10 seconds. Let go right away.",
                            "Reset: keep holding both buttons until the light changes from flashing amber to flashing white, about 15 seconds.",
                        ]),
                        .warning("On AirPods Max, holding the buttons past about 10 seconds resets them to factory settings."),
                        .heading("Apple TV 4K"),
                        .bullets([
                            "From the remote: press and hold the TV button together with the Back button, or the Menu button on older remotes, until the status light blinks quickly.",
                            "From Settings: go to Settings > System > Restart.",
                            "Or unplug Apple TV, wait five seconds, and plug it back in.",
                        ]),
                        .note("Checked against Apple's guides in October 2026."),
                        .source(label: "Apple Support: Restart Apple Watch", url: "https://support.apple.com/guide/watch/restart-applewatch-apd521a8a902/watchos"),
                        .source(label: "Apple Support: Restart, unpair, or reset AirPods", url: "https://support.apple.com/guide/airpods/restart-unpair-or-reset-airpods-iph561965261/web"),
                        .source(label: "Apple Support: Restart Apple TV 4K", url: "https://support.apple.com/guide/tv/restart-apple-tv-4k-atvbb8553426/tvos"),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "ref-voiceover-watch",
                    title: "VoiceOver on Apple Watch",
                    summary: "Turning VoiceOver on, and the gestures and buttons for using Apple Watch with it.",
                    content: [
                        .heading("Turn VoiceOver on or off"),
                        .bullets([
                            "Ask Siri: Turn on VoiceOver.",
                            "On the watch: go to Settings > Accessibility > VoiceOver.",
                            "From your iPhone: open the Apple Watch app, choose My Watch, then Accessibility > VoiceOver.",
                            "With the Accessibility Shortcut: press the Digital Crown three times quickly, once it's set up for VoiceOver.",
                        ]),
                        .heading("Move around"),
                        .bullets([
                            "Hear an item: touch it, or drag one finger around the display.",
                            "Next or previous item: swipe right or left with one finger.",
                            "Another page: swipe left, right, up, or down with two fingers.",
                            "Go back: two-finger scrub, like drawing the letter z.",
                            "Move with the Digital Crown: triple-tap with two fingers to turn this on, then turn the Digital Crown. Triple-tap with two fingers again to turn it off.",
                        ]),
                        .heading("Take action"),
                        .bullets([
                            "Activate the selected item: double-tap anywhere on the display.",
                            "More actions: when you hear actions available, swipe up or down to choose one, then double-tap.",
                            "Pause or resume reading: two-finger tap.",
                            "VoiceOver volume: two-finger double-tap and hold, then slide up or down.",
                        ]),
                        .heading("Get around the watch"),
                        .bullets([
                            "Notifications: from the watch face, swipe down with two fingers.",
                            "Control Center: from the watch face, press the side button.",
                            "Widgets: from the watch face, turn the Digital Crown down or swipe up with two fingers.",
                            "App Switcher: double-click the Digital Crown, turn it to choose an app, then double-tap.",
                            "Home Screen: press the Digital Crown once.",
                            "Change the watch face: triple-tap the display, turn the Digital Crown to choose, then press the Digital Crown.",
                        ]),
                        .heading("The rotor"),
                        .bullets([
                            "Choose a rotor setting: turn two fingers on the display, like turning a dial. Settings include Words, Characters, Actions, Headings, Volume, and Speaking Rate.",
                            "Previous item, or increase: swipe up.",
                            "Next item, or decrease: swipe down.",
                        ]),
                        .tip("Hand Gestures let you control VoiceOver with clench and tap hand movements instead of touching the display. Turn them on in the Apple Watch app on iPhone, under Accessibility > VoiceOver > Hand Gestures."),
                        .note("Checked against Apple's Apple Watch User Guide for watchOS 27, in October 2026."),
                        .source(label: "Apple Support: Use VoiceOver on Apple Watch", url: "https://support.apple.com/guide/watch/use-voiceover-apdaabc79d3b/watchos"),
                        .source(label: "Apple Support: Apple Watch basics with VoiceOver", url: "https://support.apple.com/guide/watch/applewatch-basics-with-voiceover-apde8185443e/watchos"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-voiceover-tv",
                    title: "VoiceOver on Apple TV",
                    summary: "Turning VoiceOver on, and using the Apple TV remote with it.",
                    content: [
                        .heading("Turn VoiceOver on or off"),
                        .bullets([
                            "Go to Settings > Accessibility > VoiceOver.",
                            "Or press the Back button three times quickly, or Menu on older remotes. This uses the Accessibility Shortcut. During setup, it turns on VoiceOver.",
                        ]),
                        .heading("Two modes"),
                        .body("VoiceOver on Apple TV has two modes. Navigation mode speaks each item as you move to it. Exploration mode keeps the current item selected while you look around the rest of the screen. To switch modes, tap three times with two fingers on the remote's clickpad or touch surface."),
                        .heading("Navigation mode"),
                        .bullets([
                            "Move to another item: swipe or press up, down, left, or right.",
                            "Select the item: press the center of the clickpad or the touch surface.",
                            "Open an item's menu, when it has one: press and hold the center.",
                            "Go back: press the Back button, or Menu on older remotes.",
                        ]),
                        .heading("Exploration mode"),
                        .bullets([
                            "Hear the next or previous item: swipe right or left.",
                            "Select the highlighted item: press the center.",
                            "Read from the current item to the bottom: swipe down with two fingers.",
                            "Read from the top: swipe up with two fingers.",
                            "Pause or resume speech: tap with two fingers.",
                        ]),
                        .heading("The rotor"),
                        .bullets([
                            "Open the rotor: turn two fingers around a point on the clickpad or touch surface.",
                            "Switch to another rotor control: keep turning two fingers.",
                            "Change the value, such as speaking rate: swipe up or down.",
                            "Close the rotor: swipe left or right, or wait about three seconds.",
                        ]),
                        .tip("Press and hold the TV button to open Control Center, which has an Accessibility Shortcut control."),
                        .note("Checked against Apple's Apple TV 4K User Guide for tvOS 27, in October 2026."),
                        .source(label: "Apple Support: Use VoiceOver on Apple TV 4K", url: "https://support.apple.com/guide/tv/use-voiceover-atvbfa4ff6cd/tvos"),
                        .source(label: "Apple Support: Add an accessibility shortcut to Apple TV 4K", url: "https://support.apple.com/guide/tv/add-an-accessibility-shortcut-atvb0a315d10/tvos"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-braille-display-mac",
                    title: "Braille Display Commands on Mac",
                    summary: "Common VoiceOver commands for a braille display with a Perkins-style keyboard on Mac.",
                    content: [
                        .body("Each command is the Space bar pressed together with the dots listed. Many match the iPhone and iPad commands, but not all. To see or change them, open VoiceOver Utility, choose Braille, then the Displays tab."),
                        .heading("Get around"),
                        .bullets([
                            "Previous item: Space with dot 1.",
                            "Next item: Space with dot 4.",
                            "Move up: Space with dot 3.",
                            "Move down: Space with dot 6.",
                            "First item: Space with dots 1-2-3.",
                            "Last item: Space with dots 4-5-6.",
                            "Start interacting with an item: Space with dots 2-3-6.",
                            "Stop interacting: Space with dots 3-5-6.",
                            "Menu bar: Space with dots 2-3-4.",
                            "Shortcut menu: Space with dots 2-5.",
                            "Item Chooser: Space with dots 2-4.",
                            "Find: Space with dots 1-2-4.",
                            "Escape: Space with dots 1-2.",
                        ]),
                        .heading("Scroll and rotor"),
                        .bullets([
                            "Up one page: Space with dots 3-4-5-6.",
                            "Down one page: Space with dots 1-4-5-6.",
                            "Left one page: Space with dots 2-4-6.",
                            "Right one page: Space with dots 1-3-5.",
                            "Previous rotor setting: Space with dots 2-3.",
                            "Next rotor setting: Space with dots 5-6.",
                        ]),
                        .heading("Take action and read"),
                        .bullets([
                            "Do the item's action, like clicking: Space with dots 3-6.",
                            "Volume up: Space with dots 3-4-5.",
                            "Volume down: Space with dots 1-2-6.",
                            "Read from the top: Space with dots 2-4-5-6.",
                            "Read what's in the VoiceOver cursor: Space with dots 1-2-3-5.",
                            "Read text attributes: Space with dots 2-3-4-5-6.",
                        ]),
                        .heading("Edit text"),
                        .bullets([
                            "Delete: Space with dots 1-4-5.",
                            "Return: Space with dots 1-5.",
                            "Tab: Space with dots 2-3-4-5.",
                            "Select all: Space with dots 2-3-5-6.",
                            "Select to the left: Space with dots 2-3-5.",
                            "Select to the right: Space with dots 2-5-6.",
                        ]),
                        .heading("Control VoiceOver"),
                        .bullets([
                            "VoiceOver Utility: Space with dots 1-3-6.",
                            "VoiceOver Help: Space with dots 1-2-5.",
                            "Keyboard Help: Space with dots 1-3.",
                            "Pause or continue speech: Space with dots 1-2-3-4.",
                            "Speech on or off: Space with dots 1-3-4.",
                            "Screen Curtain on or off: Space with all six dots, 1 to 6.",
                            "Quick Nav on or off: Space with dots 1-2-3-4-5.",
                            "Add a custom label: Space with dots 1-2-3-4-6.",
                        ]),
                        .heading("Braille"),
                        .bullets([
                            "Pan left: Space with dot 2.",
                            "Pan right: Space with dot 5.",
                            "Switch between contracted and uncontracted braille: Space with dots 1-2-4-5.",
                            "Translate what you've typed: Space with dots 4-5.",
                            "Announcement history: Space with dots 1-3-4-5.",
                        ]),
                        .heading("Extra commands on 8-dot displays"),
                        .bullets([
                            "Go to the desktop: Space with dots 2-5-6-7.",
                            "Delete: dot 7, alone or with Space.",
                            "Return: dot 8, alone or with Space.",
                            "Hold a modifier for the next key: Space with dots 4-7 for Shift, 1-7 for Command, 3-7 for Control, 2-7 for Option, or 5-7 for Fn.",
                            "Lock a modifier on until pressed again: the same dots with dot 8 instead of dot 7.",
                        ]),
                        .note("Checked against Apple's list of common braille commands for Mac in October 2026. Commands can change with new software."),
                        .source(label: "Apple Support: Common braille commands for VoiceOver on Mac", url: "https://support.apple.com/en-us/103560"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-accessibility-shortcut",
                    title: "Accessibility Shortcut and Siri",
                    summary: "Quick ways to turn VoiceOver and other features on or off on every Apple device.",
                    content: [
                        .body("The Accessibility Shortcut turns a feature on or off with a quick button press. Choose which features it controls in Accessibility settings, under Accessibility Shortcut. If you choose more than one, you're asked which one each time."),
                        .heading("The shortcut on each device"),
                        .bullets([
                            "iPhone with Face ID: press the side button three times quickly.",
                            "iPhone with a Home button: press the Home button three times quickly.",
                            "iPad: press the top button three times quickly, or the Home button on an iPad that has one.",
                            "Mac: press Option-Command-F5, or press Touch ID three times quickly. This opens the Accessibility Shortcuts panel.",
                            "Apple Watch: press the Digital Crown three times quickly.",
                            "Apple TV: press the Back button three times quickly, or Menu on older remotes.",
                        ]),
                        .tip("On Mac, Command-F5 turns VoiceOver on or off directly. On a Mac with Touch ID, hold Command and press Touch ID three times."),
                        .heading("Siri"),
                        .body("On every device, you can ask Siri to turn on VoiceOver, or another feature such as Zoom or Voice Control. For example, say: Turn on VoiceOver. This is useful if a gesture or button isn't working, or someone else's device needs VoiceOver."),
                        .heading("Other quick ways on iPhone"),
                        .bullets([
                            "Back Tap: double- or triple-tap the back of iPhone to run a feature you choose. Set it up in Settings > Accessibility > Touch > Back Tap.",
                            "Action button: on models that have one, set it to open Magnifier or an accessibility feature.",
                            "Control Center: add accessibility controls, including VoiceOver, to Control Center.",
                            "Vocal Shortcuts: teach iPhone a word or sound that turns a feature on.",
                        ]),
                        .note("Checked against Apple's guides for iOS 27, macOS 27, watchOS 27, and tvOS 27, in October 2026."),
                        .source(label: "Apple Support: Quickly turn accessibility features on or off on iPhone", url: "https://support.apple.com/guide/iphone/quickly-turn-accessibility-features-on-or-off-iph3e2e31a5/ios"),
                        .source(label: "Apple Support: Quickly turn accessibility features on or off on Mac", url: "https://support.apple.com/guide/mac-help/quickly-turn-accessibility-features-on-or-off-mchlp2975/mac"),
                        .source(label: "Apple Support: Use the Accessibility Shortcut on Apple Watch", url: "https://support.apple.com/guide/watch/use-the-accessibility-shortcut-apda74993b58/watchos"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-setup-voiceover",
                    title: "Turn On VoiceOver When Setting Up a Device",
                    summary: "How to set up a new or reset Apple device with VoiceOver from the very first screen.",
                    content: [
                        .body("You don't need sighted help to set up an Apple device. Turn on VoiceOver at the first screen, then follow the spoken steps."),
                        .heading("iPhone and iPad"),
                        .bullets([
                            "Turn the device on by pressing and holding the side or top button until the Apple logo appears.",
                            "Turn on VoiceOver: press the side button three times quickly. On a device with a Home button, press the Home button three times instead.",
                            "After setup, practice gestures in Settings > Accessibility > VoiceOver, with VoiceOver Tutorial or VoiceOver Practice.",
                        ]),
                        .heading("Mac"),
                        .bullets([
                            "Turn on VoiceOver: press Command-F5. On a Mac or keyboard with Touch ID, hold Command and press Touch ID three times.",
                            "When VoiceOver starts, press Space for the interactive tutorial, or Return to carry on.",
                            "Later, VO-Fn-Command-F8 opens the VoiceOver Tutorial.",
                        ]),
                        .heading("Apple Watch"),
                        .bullets([
                            "Turn the watch on by holding the side button.",
                            "Turn on VoiceOver: press the Digital Crown three times quickly.",
                            "Bring your iPhone near the watch and follow the spoken steps. If automatic pairing doesn't work, choose Pair Apple Watch Manually. The watch can read out its name and a six-digit code to enter on iPhone.",
                        ]),
                        .heading("Apple TV"),
                        .bullets([
                            "Turn on VoiceOver: press the Back button three times quickly, or Menu on older remotes.",
                            "You can also set up Apple TV from your iPhone or iPad when it offers Set Up with iPhone or iPad.",
                        ]),
                        .note("Checked against Apple's guides in October 2026."),
                        .source(label: "Apple Support: Turn on and set up iPhone", url: "https://support.apple.com/guide/iphone/turn-on-and-set-up-iphone-iph1fd7e482f/ios"),
                        .source(label: "Apple Support: Get started with VoiceOver on Mac", url: "https://support.apple.com/guide/voiceover/vo4be8816d70/mac"),
                        .source(label: "Apple Support: Set up Apple Watch using VoiceOver", url: "https://support.apple.com/guide/watch/set-up-applewatch-using-voiceover-apd2442c5704/watchos"),
                        .source(label: "Apple Support: Set up Apple TV 4K", url: "https://support.apple.com/guide/tv/set-up-apple-tv-4k-atvb73e46488/tvos"),
                    ],
                    contentType: .quickStart
                ),
                HelpArticle(
                    id: "ref-glossary",
                    title: "Accessibility Terms Glossary",
                    summary: "Plain explanations of words you'll hear in VoiceOver, braille, and AppleVis discussions.",
                    content: [
                        .body("These are the terms that come up most in guides, podcasts, and the forums. Each one is explained in a sentence or two."),
                        .heading("VoiceOver"),
                        .bullets([
                            "VoiceOver: Apple's built-in screen reader. It speaks what's on the screen and changes how gestures work.",
                            "VoiceOver cursor: the item VoiceOver is on. On screen, it's shown visually as a box around the item.",
                            "VO modifier, or VO keys: the keys you hold for VoiceOver keyboard commands. That's Caps Lock, or Control and Option together.",
                            "Rotor: a dial you turn with two fingers to choose how up and down swipes move, such as by heading, link, word, or character. It also changes settings like speaking rate.",
                            "Magic Tap: a two-finger double-tap that does the main action wherever you are, such as play or pause, or answer a call.",
                            "Scrub: a quick back-and-forth with two fingers, like drawing a z, that goes back or closes something.",
                            "Split tap: touch an item with one finger and tap with another to activate it, instead of double-tapping.",
                            "Item Chooser: a searchable list of everything on the screen. Use it to jump straight to an item.",
                            "Screen Curtain: turns the display dark for privacy and battery life while everything keeps working.",
                            "Hints: short spoken tips after an item, such as double-tap to open. You can turn them off in VoiceOver settings.",
                            "Verbosity: how much VoiceOver says about each item, such as punctuation and extra details.",
                            "Quick Nav: a keyboard mode for moving with arrow keys or single letters, without the VO keys.",
                            "Interacting: on Mac, going inside a group, such as a list or toolbar, to reach its items.",
                            "Live Recognition: VoiceOver describes your surroundings through the camera as you move.",
                        ]),
                        .heading("Braille"),
                        .bullets([
                            "Braille display: a device with a row of cells whose pins rise to show braille, often with a braille keyboard.",
                            "Perkins-style keyboard: a braille keyboard with six or eight keys, one for each dot, plus Space.",
                            "8-dot braille: braille with two extra dots per cell, often used for computer text and extra commands.",
                            "Contracted braille: braille that uses short forms for common words and letter groups. It's sometimes called Grade 2.",
                            "Uncontracted braille: braille written letter by letter. It's sometimes called Grade 1.",
                            "Panning: moving the braille display to the next or previous part of the text.",
                            "Braille Screen Input: typing braille directly on the iPhone or iPad screen, without a display.",
                            "Braille Access: a mode that turns iPhone, iPad, or Mac into a note taker for braille display users.",
                        ]),
                        .heading("Apple devices"),
                        .bullets([
                            "Accessibility Shortcut: a triple press of a button that turns a chosen feature on or off.",
                            "Force restart: a button sequence that restarts a device that isn't responding.",
                            "Recovery mode: a state for reinstalling the software on iPhone or iPad from a computer.",
                            "macOS Recovery: a built-in set of tools on Mac for reinstalling macOS or repairing the disk.",
                            "Digital Crown: the dial on the side of Apple Watch and AirPods Max.",
                            "Clickpad: the touch-sensitive top of the Apple TV remote.",
                        ]),
                        .heading("On AppleVis"),
                        .bullets([
                            "VoiceOver performance: in the App Directory, how well an app works with VoiceOver, from fully accessible to inaccessible, as described by members.",
                            "Golden Apples: AppleVis's yearly awards for the most accessible apps and developers, voted for by the community.",
                        ]),
                    ],
                    contentType: .guide,
                    relatedLinks: [
                        RelatedLink(label: "VoiceOver Gestures on iPhone and iPad", type: .guide, destination: .article("ref-voiceover-gestures")),
                        RelatedLink(label: "Braille Display Commands on iPhone and iPad", type: .guide, destination: .article("ref-braille-display")),
                        RelatedLink(label: "Accessibility Shortcut and Siri", type: .guide, destination: .article("ref-accessibility-shortcut")),
                    ]
                ),
                HelpArticle(
                    id: "ref-voiceover-silent",
                    title: "When VoiceOver Stops Talking",
                    summary: "What to try when VoiceOver goes quiet, says everything twice, the screen goes dark, or gestures stop working.",
                    content: [
                        .body("Try these in order. Most of the time, speech was muted or turned down by a gesture made by accident."),
                        .heading("If VoiceOver is silent"),
                        .steps([
                            "Unmute speech: three-finger double-tap. If Zoom is also on, three-finger triple-tap.",
                            "Turn up the volume with the volume buttons. They change VoiceOver speech along with other sound.",
                            "Check the rotor. Turn two fingers to find Volume or Speaking Rate, then swipe up to raise it.",
                            "Check whether VoiceOver is on at all. Ask Siri: Turn on VoiceOver. Or press the side or Home button three times quickly, if your Accessibility Shortcut is set to VoiceOver.",
                            "Check that audio isn't going somewhere else, such as AirPods or a Bluetooth speaker that's still connected. Open Control Center and check the audio output.",
                            "Turn VoiceOver off and on again with Siri or the Accessibility Shortcut.",
                            "Restart the device. If it won't respond, force restart it. See Restart, Force Restart, and Recovery Mode on iPhone and iPad.",
                        ]),
                        .heading("If the screen is black but VoiceOver talks"),
                        .body("Screen Curtain is probably on. It darkens the display while everything keeps working. To turn it off, three-finger triple-tap. If Zoom is also on, three-finger quadruple-tap."),
                        .heading("If VoiceOver says everything twice"),
                        .bullets([
                            "Turn VoiceOver off and on again with the Accessibility Shortcut or Siri. This usually fixes it.",
                            "It often starts after a phone call. If it keeps happening, check the AppleVis Bug Tracker for a current report.",
                            "If a Bluetooth speaker or headphones are connected, disconnect them and see whether it stops. Members have reported doubled speech with some Bluetooth audio.",
                            "If it continues, restart the device.",
                        ]),
                        .heading("If VoiceOver talks over other sound, or other sound is too quiet"),
                        .body("Go to Settings > Accessibility > VoiceOver > Audio > Audio Ducking. Choose when other audio gets quieter while VoiceOver speaks, and by how much."),
                        .heading("If VoiceOver says too much, or too little"),
                        .bullets([
                            "Hints, punctuation, and other details: Settings > Accessibility > VoiceOver > Verbosity.",
                            "Notifications read aloud while locked: Settings > Accessibility > VoiceOver > Verbosity > System Notifications.",
                            "A different voice or speed: Settings > Accessibility > VoiceOver > Speech, and the Speaking Rate slider.",
                        ]),
                        .heading("If gestures do odd things"),
                        .bullets([
                            "Swipes move into and out of groups instead of item by item: check Navigation Style in VoiceOver settings. Flat moves through every item. Grouped needs a two-finger swipe to enter a group.",
                            "Touches select items too easily: increase Delay before Selection in VoiceOver settings.",
                            "Nothing helps: Settings > Accessibility > VoiceOver > Reset VoiceOver Settings. If you customized gestures or keys, Commands > Reset VoiceOver Commands puts those back too.",
                        ]),
                        .note("On Mac, Command-F5 turns VoiceOver off and on, and pressing Control pauses or resumes speech. On Apple Watch, three-finger double-tap mutes and unmutes VoiceOver as well."),
                        .note("Checked against Apple's iPhone User Guide for iOS 27, in October 2026."),
                        .source(label: "Apple Support: Change your VoiceOver settings on iPhone", url: "https://support.apple.com/guide/iphone/change-your-voiceover-settings-iphfa3d32c50/ios"),
                        .source(label: "Apple Support: Turn on and practice VoiceOver on iPhone", url: "https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios"),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "ref-low-vision",
                    title: "Low Vision Quick Reference",
                    summary: "Magnify the screen, hear text read aloud, and make things easier to see on iPhone and iPad.",
                    content: [
                        .heading("Zoom"),
                        .body("Turn it on in Settings > Accessibility > Zoom. Choose Full Screen Zoom or Window Zoom, a movable lens."),
                        .bullets([
                            "Turn Zoom on or off: double-tap with three fingers.",
                            "Change how much it magnifies: double-tap with three fingers, keep the fingers down after the second tap, then drag up or down.",
                            "Move around when zoomed in: drag with three fingers.",
                            "Zoom menu, for region, filters, and the controller: triple-tap with three fingers.",
                            "Follow Focus keeps the zoomed area on what you select and type.",
                            "Zoom filters include Inverted, Grayscale, and Low Light.",
                        ]),
                        .heading("Hear text read aloud"),
                        .body("You don't need VoiceOver to hear text. In iOS 27, these settings are in Settings > Accessibility > Read & Speak."),
                        .bullets([
                            "Speak Screen: swipe down with two fingers from the top of the screen to hear everything on it. Or ask Siri: Speak screen.",
                            "Speak Selection: select text, then choose Speak.",
                            "Accessibility Reader: shows text full screen with your choice of font, layout, and colors, and can read it aloud.",
                            "Speak on Touch: tap the text you want read, using the Speak Screen controls.",
                            "Choose the voice and speaking rate in the same settings.",
                        ]),
                        .heading("Make things easier to see"),
                        .bullets([
                            "Larger text, bold text, and higher contrast: Settings > Accessibility > Display & Text Size.",
                            "Magnifier app: uses the camera as a magnifying glass, with zoom, light, and filters.",
                            "With VoiceOver, Large Cursor makes the outline around the selected item thicker, and Caption Panel shows what VoiceOver says at the bottom of the screen. Both are in VoiceOver settings.",
                        ]),
                        .tip("Add Zoom to the Accessibility Shortcut, then press the side or Home button three times to turn it on or off."),
                        .note("Checked against Apple's iPhone User Guide for iOS 27, in October 2026."),
                        .source(label: "Apple Support: Zoom in on the iPhone screen", url: "https://support.apple.com/guide/iphone/zoom-in-iph3e2e367e/ios"),
                        .source(label: "Apple Support: Hear iPhone speak the screen, selected text, and typing feedback", url: "https://support.apple.com/guide/iphone/hear-whats-on-the-screen-or-typed-iph96b214f0/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-typing-voiceover",
                    title: "Typing with VoiceOver",
                    summary: "Typing styles, Braille Screen Input gestures, dictation commands, and editing text on iPhone and iPad.",
                    content: [
                        .heading("Typing styles"),
                        .body("Choose a style in Settings > Accessibility > VoiceOver > Typing Style, or set the rotor to Typing Mode and swipe up or down."),
                        .bullets([
                            "Standard Typing: swipe to a key or touch it, then double-tap to type it. You can also touch a key and tap with a second finger.",
                            "Touch Typing: slide to a key and lift your finger to type it.",
                            "Direct Touch Typing: the keyboard works as if VoiceOver were off.",
                            "Accented letters: double-tap and hold the plain letter, or touch and hold it in Touch Typing, then slide to choose.",
                            "Start or stop dictation from the keyboard: two-finger double-tap.",
                        ]),
                        .heading("Edit text with the rotor"),
                        .bullets([
                            "Move by character, word, or line: set the rotor to Characters, Words, or Lines, then swipe up or down.",
                            "Jump to the start or end of the text: double-tap the text field.",
                            "Select text: set the rotor to Text Selection, swipe up or down to choose the size, then swipe left or right.",
                            "Cut, copy, paste, or select all: set the rotor to Edit, swipe up or down to choose, then double-tap.",
                            "Fix spelling: set the rotor to Misspelled Words, swipe up or down to find one, swipe left or right to choose a fix, then double-tap.",
                            "Undo: shake the device, choose the action, then double-tap.",
                        ]),
                        .heading("Braille Screen Input"),
                        .body("Type braille on the screen with your fingers. To start, put one finger of each hand at the top and bottom edges of the screen and double-tap. You can also set the rotor to Braille Screen Input in a text field. Hold the device flat on a table, or in landscape with the screen facing away from you."),
                        .bullets([
                            "Space: swipe right with one finger.",
                            "Delete: swipe left with one finger.",
                            "New line: swipe right with two fingers.",
                            "Return, or send in Messages: swipe up with three fingers.",
                            "Spelling suggestions: swipe up or down with one finger.",
                            "Translate contracted braille now: swipe down with two fingers.",
                            "Next braille table: swipe up with two fingers.",
                            "Switch between typing and Command Mode: swipe left or right with three fingers. Command Mode accepts the same commands as a braille display.",
                            "Recalibrate the dots: tap all three right fingers, then all three left fingers.",
                            "Leave Braille Screen Input: two-finger scrub.",
                        ]),
                        .heading("Dictation commands"),
                        .bullets([
                            "Punctuation: say period, comma, question mark, exclamation point, colon, semicolon, quote and end quote, or open and close parenthesis.",
                            "Layout: say new line or new paragraph.",
                            "Capitals: say cap for the next word, or all caps for the next word in capitals.",
                            "Editing, in U.S. English on iPhone 12 and later: say undo, redo, delete all, or change this to that.",
                        ]),
                        .note("Checked against Apple's iPhone User Guide for iOS 27, in October 2026."),
                        .source(label: "Apple Support: Use the onscreen keyboard with VoiceOver on iPhone", url: "https://support.apple.com/guide/iphone/use-the-onscreen-keyboard-iph3e2e3d1d/ios"),
                        .source(label: "Apple Support: Type braille directly on the iPhone screen with VoiceOver", url: "https://support.apple.com/guide/iphone/type-braille-on-the-screen-iph10366cc30/ios"),
                        .source(label: "Apple Support: Commands for dictating text on iPhone", url: "https://support.apple.com/guide/iphone/commands-for-dictating-text-iph3bf19d7b9/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-recognition",
                    title: "Describe Images, Text, and Your Surroundings",
                    summary: "Live Recognition, Magnifier detection, image descriptions, and Screen Recognition on iPhone.",
                    content: [
                        .heading("Live Recognition"),
                        .bullets([
                            "Start or stop: with VoiceOver on, four-finger triple-tap.",
                            "Choose what's described, such as scenes, people, doors, furniture, or text. Select a category, then double-tap to turn it on or off.",
                            "Point and Speak: point a finger at text to hear it read.",
                            "Ask a question about what the camera sees, when Apple Intelligence is available.",
                            "Skip to the next thing detected: two-finger tap.",
                            "Settings: Settings > Accessibility > Live Recognition.",
                        ]),
                        .heading("Magnifier detection"),
                        .body("In the Magnifier app, Detection Mode finds doors, people, and furniture with the rear camera. It tells you with sounds, speech, or haptics, more often as you get closer. Pause or resume with a two-finger double-tap. Door detection can also describe how a door opens and read signs near it."),
                        .heading("Images in apps and webpages"),
                        .body("In Settings > Accessibility > VoiceOver > VoiceOver Recognition, you can turn on descriptions of images and the text in them. Then select an image, swipe down for more options, and double-tap a description option. Some options need Apple Intelligence."),
                        .heading("Apps that aren't labeled"),
                        .body("Screen Recognition can make controls in a poorly labeled app usable. Turn it on in Settings > Accessibility > VoiceOver > VoiceOver Recognition > Screen Recognition, then choose the apps."),
                        .heading("Your own photo descriptions"),
                        .body("In Photos, you can add your own description to a photo. VoiceOver reads it when you select that photo."),
                        .warning("Don't rely on recognition for safety, navigation, or medical decisions. It can be wrong."),
                        .note("Some features need a supported iPhone model, or Apple Intelligence, which isn't available in every language or region. Checked against Apple's iPhone User Guide for iOS 27, in October 2026."),
                        .source(label: "Apple Support: Hear what's on your screen and around you with VoiceOver", url: "https://support.apple.com/guide/iphone/get-live-descriptions-of-your-surroundings-iph37e6b3844/ios"),
                        .source(label: "Apple Support: Detect doors, people, and furniture near you", url: "https://support.apple.com/guide/iphone/detect-doors-people-and-furniture-around-you-iph35c335575/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-web-voiceover",
                    title: "Browsing the Web with VoiceOver",
                    summary: "Moving around webpages quickly in Safari on iPhone, iPad, and Mac.",
                    content: [
                        .heading("iPhone and iPad"),
                        .bullets([
                            "Jump by headings, links, form controls, and more: set the rotor to that kind of item, then swipe up or down.",
                            "Choose which rotor items appear, and their order: Settings > Accessibility > VoiceOver > Rotor.",
                            "Skip images: Settings > Accessibility > VoiceOver > Navigate Images.",
                            "Read without clutter: in the address bar, choose Format Options, then Show Reader View, when a page offers it.",
                            "Read the whole page from the top: two-finger swipe up.",
                            "Find something on the page: open the Item Chooser with a two-finger triple-tap, then type its name.",
                            "With a keyboard, single-key Quick Nav jumps by letter, such as H for headings. See VoiceOver Keyboard Commands on iPhone and iPad.",
                        ]),
                        .heading("Mac"),
                        .bullets([
                            "Open the rotor to list headings, links, landmarks, and more: VO-U. Use Left Arrow and Right Arrow to change the list, then Up Arrow and Down Arrow to choose.",
                            "Open the Item Chooser: VO-I.",
                            "Find text: VO-F.",
                            "Read from the VoiceOver cursor: VO-A.",
                        ]),
                        .note("Checked against Apple's guides for iOS 27 and macOS 27, in October 2026."),
                        .source(label: "Apple Support: Use VoiceOver in apps on iPhone", url: "https://support.apple.com/guide/iphone/use-voiceover-in-apps-iphe4ee74be8/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-siri-phrases",
                    title: "Useful Siri Requests",
                    summary: "Things to ask Siri that help when gestures are hard, or something isn't working.",
                    content: [
                        .body("Siri works the same way with or without VoiceOver. Siri knows when VoiceOver is on, and often reads back more than the screen shows."),
                        .heading("Accessibility"),
                        .bullets([
                            "Turn on VoiceOver, or turn off VoiceOver.",
                            "Turn on Zoom, or turn on Voice Control.",
                            "Speak screen, to hear everything on the screen.",
                        ]),
                        .heading("Everyday"),
                        .bullets([
                            "What time is it?",
                            "Read my messages.",
                            "Call, followed by a name.",
                            "Set a timer for 10 minutes.",
                            "Open, followed by an app's name. For example, Open AppleVis.",
                        ]),
                        .heading("AppleVis"),
                        .body("AppleVis adds its own Siri phrases, such as What's new on AppleVis. They're listed in Help under Siri and Spotlight."),
                        .note("Siri requests can vary by language, region, and device. Checked against Apple's guides in October 2026."),
                        .source(label: "Apple Support: Turn on and practice VoiceOver on iPhone", url: "https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-iphone-everyday-voiceover",
                    title: "Everyday iPhone Tasks with VoiceOver",
                    summary: "Unlocking, the Home Screen, switching apps, Control Center, calls, the camera, and Face ID.",
                    content: [
                        .heading("Unlock and go Home"),
                        .bullets([
                            "Unlock with Face ID: wake iPhone and look at it, then drag one finger up from the bottom edge until you feel a vibration or hear two rising tones.",
                            "Unlock with Touch ID: press the Home button with your registered finger.",
                            "Enter your passcode without it being spoken: use handwriting or Braille Screen Input.",
                            "Go to the Home Screen with Face ID: drag one finger up from the bottom edge until you feel a vibration or hear two rising tones, then lift.",
                        ]),
                        .heading("Switch apps"),
                        .bullets([
                            "Switch between open apps: swipe left or right with four fingers.",
                            "App Switcher with Face ID: drag up from the bottom edge until you feel a second vibration or hear three tones. With a Home button, double-press it.",
                        ]),
                        .heading("Control Center, notifications, and status"),
                        .bullets([
                            "Control Center with Face ID: drag one finger down from the top edge until you feel a vibration or hear a second tone.",
                            "Notifications with Face ID: drag one finger down from the top edge until you feel a second vibration or hear a third tone.",
                            "On any iPhone: select an item in the status bar, then swipe up with three fingers for Control Center, or down with three fingers for notifications.",
                            "Close Control Center or notifications: two-finger scrub.",
                            "Hear the time, battery, and signal: tap the status bar, then swipe left or right.",
                        ]),
                        .heading("Calls"),
                        .bullets([
                            "Answer or end a call: two-finger double-tap.",
                            "During a call, the keypad shows first. Choose Hide for call options.",
                        ]),
                        .heading("Camera"),
                        .body("VoiceOver describes what's in the viewfinder. To take a photo or start or stop a video, two-finger double-tap. Choose the mode, such as Photo or Video, by selecting Camera Mode and swiping up or down."),
                        .heading("Face ID with VoiceOver"),
                        .body("Face ID normally checks that your eyes are open and looking at the screen. If you set up iPhone with VoiceOver on, this check is off by default. Change it in Settings > Accessibility > Face ID & Attention, under Require Attention for Face ID. Turning it on is more secure. If you can't move your head in a circle during Face ID setup, choose Accessibility Options."),
                        .heading("Arrange apps"),
                        .body("Select an app, then swipe down to Edit Mode and double-tap. Find the app, swipe down to Move, and double-tap. Move to the new spot, then choose Move Before, Move After, Add to Folder, or Create New Folder. Choose Done when you're finished."),
                        .note("Checked against Apple's iPhone User Guide for iOS 27, in October 2026."),
                        .source(label: "Apple Support: Operate iPhone when VoiceOver is on", url: "https://support.apple.com/guide/iphone/operate-iphone-when-voiceover-is-on-iph3e2e2329/ios"),
                        .source(label: "Apple Support: Change Face ID and attention settings on iPhone", url: "https://support.apple.com/guide/iphone/change-face-id-and-attention-settings-iph646624222/ios"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-mac-essentials",
                    title: "Mac Essentials",
                    summary: "Everyday Mac keyboard shortcuts, and tips for anyone moving from a Windows PC.",
                    content: [
                        .heading("Shortcuts you'll use every day"),
                        .bullets([
                            "Search your Mac and open apps: Command-Space bar, for Spotlight. Type the name, then press Return.",
                            "Switch apps: hold Command and press Tab.",
                            "Copy, cut, and paste: Command-C, Command-X, and Command-V.",
                            "Undo and redo: Command-Z and Shift-Command-Z.",
                            "Select all: Command-A.",
                            "Find: Command-F.",
                            "Save: Command-S.",
                            "Print: Command-P.",
                            "New tab: Command-T.",
                            "Close the window or tab: Command-W.",
                            "Quit the app: Command-Q.",
                            "Force quit an app that isn't responding: Option-Command-Escape.",
                        ]),
                        .heading("Coming from Windows"),
                        .bullets([
                            "Most Windows shortcuts that use Control use Command on a Mac. For example, copy is Command-C.",
                            "The Alt key is called Option on a Mac.",
                            "On a keyboard made for Windows, press Alt for Option, and Control or the Windows key for Command.",
                            "Apps are in the Applications folder, and in Spotlight.",
                            "VoiceOver uses Control and Option, or Caps Lock, as its modifier. See VoiceOver Keyboard Commands on Mac.",
                            "Many apps show their shortcuts next to each command in the menu bar. Press VO-M to reach the menu bar.",
                        ]),
                        .note("Checked against Apple's Mac User Guide and support articles in October 2026."),
                        .source(label: "Apple Support: Mac keyboard shortcuts", url: "https://support.apple.com/en-us/102650"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-getting-help",
                    title: "Getting Help with Accessibility",
                    summary: "How to reach Apple's accessibility support, send feedback, and get help from the AppleVis community.",
                    content: [
                        .heading("Apple Accessibility Support"),
                        .body("Apple has a support line for its accessibility features, by phone or chat. You can also use your telecommunications relay service of choice."),
                        .bullets([
                            "United States (US): 1-877-204-3930, in English.",
                            "United Kingdom (UK): 0800 048 0754, in English.",
                            "Australia: 1300 365 083, in English.",
                            "China mainland: 400-619-8141, in Mandarin.",
                            "Elsewhere, or to chat: go to Apple's accessibility support page, linked below.",
                        ]),
                        .heading("Send feedback to Apple"),
                        .bullets([
                            "To ask for an accessibility improvement or share your story: email accessibility@apple.com.",
                            "Other product feedback: apple.com/feedback.",
                            "Beta software bugs: use the Feedback Assistant app that comes with Apple's beta software.",
                        ]),
                        .heading("Help from AppleVis"),
                        .bullets([
                            "Check the Bug Tracker in Discover, to see whether others have reported the same accessibility bug, and what helped.",
                            "Ask in the Forums. Members often know a workaround.",
                            "Ask the Mouse searches AppleVis guides and discussions for you.",
                            "Use Contact AppleVis, in Profile > About AppleVis, for questions about the app or website.",
                        ]),
                        .note("Phone numbers checked against Apple's support article in October 2026. They can change."),
                        .source(label: "Apple Support: How to contact Apple for help with accessibility features", url: "https://support.apple.com/en-us/111749"),
                    ],
                    contentType: .guide
                ),
                HelpArticle(
                    id: "ref-updating",
                    title: "Updating and Backing Up",
                    summary: "Back up before you update, install updates, and what to do if VoiceOver changes afterward.",
                    content: [
                        .heading("Back up first"),
                        .bullets([
                            "iCloud: Settings > your name > iCloud > iCloud Backup. Turn on Back Up This iPhone, or choose Back Up Now. Backups need Wi-Fi and enough iCloud storage.",
                            "Computer: connect with a cable, then use Finder on a Mac, or the Apple Devices app on Windows.",
                        ]),
                        .heading("Update iPhone or iPad"),
                        .bullets([
                            "Go to Settings > General > Software Update. If an update is available, choose Download and Install.",
                            "Automatic updates: in Software Update, choose Automatic Updates. Automatically Install updates overnight while charging on Wi-Fi.",
                            "From a computer: connect with a cable. In Finder, select the device, then Check for Update.",
                            "Your data and settings stay as they are when you update.",
                        ]),
                        .heading("Before a big update"),
                        .bullets([
                            "Read AppleVis's accessibility report for the new version first. AppleVis publishes one after each major Apple release, with the accessibility bugs found and fixed.",
                            "Check the Bug Tracker for any problem that matters to you.",
                            "Make sure you can turn VoiceOver back on without the screen, with Siri or the Accessibility Shortcut.",
                        ]),
                        .heading("If VoiceOver acts differently after an update"),
                        .bullets([
                            "Check your speech, rotor, and verbosity settings. Updates can add new options.",
                            "See When VoiceOver Stops Talking.",
                            "As a last resort: Settings > Accessibility > VoiceOver > Reset VoiceOver Settings.",
                        ]),
                        .note("Checked against Apple's iPhone User Guide for iOS 27, in October 2026."),
                        .source(label: "Apple Support: Update iOS on iPhone", url: "https://support.apple.com/guide/iphone/update-ios-iph3e504502/ios"),
                        .source(label: "Apple Support: Back up iPhone", url: "https://support.apple.com/guide/iphone/back-up-iphone-iph3ecf67d29/ios"),
                    ],
                    contentType: .guide
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
                            "Make sure Enable iCloud Sync is on in Settings > Saved & Sync, along with the switch for what you want to sync.",
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
                            "If AppleVis is using a lot of storage, check Settings > Storage & Cache.",
                            "If a download fails, check your connection and try again from the episode page or Downloads. Unfinished downloads are removed automatically.",
                            "If content isn't updating, pull down to refresh. If you expect it to sync from another device, check Settings > Saved & Sync.",
                            "If you can't find something you saved, open For You > Saved and check the Show picker. It may be filtered to one content type.",
                        ]),
                    ],
                    contentType: .troubleshooting
                ),
                HelpArticle(
                    id: "trouble-posting",
                    title: "When a Post Doesn't Go Through",
                    summary: "What to do when a topic, comment, reply, edit, or app submission doesn't post.",
                    content: [
                        .body("If something you post doesn't go through, AppleVis tells you why when the site gives a reason. VoiceOver reads the message as soon as it appears. Everything you wrote stays on screen, so nothing is lost."),
                        .bullets([
                            "If the message names part of the form, such as the iOS version, change that part and try again.",
                            "If the message says AppleVis is having trouble, wait a little while and try again. It's not something you did.",
                            "If it keeps happening, choose Copy Details for AppleVis under the message. This copies a short note of what went wrong. It doesn't include anything you wrote.",
                            "Paste the note into an email, or open Contact AppleVis. For a day after the problem, the contact form also offers to include the details for you.",
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
                            "Choose Next.",
                        ]),
                        .heading("Step 2: Your contact details (only when signed out)"),
                        .body("If you're not signed in, enter your name and email address so the team can reply. If you're signed in, this step is skipped."),
                        .heading("Write your message"),
                        .body("This is step 2 when you're signed in, and step 3 when you're not."),
                        .steps([
                            "Type your message.",
                            "If you chose App Bug Report, a switch appears for including app and device information. Turn it on to add your app version, device model, and accessibility settings such as VoiceOver automatically.",
                            "Rewrite and Translate to English are available if you'd like help with your message.",
                            "Choose Next.",
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
