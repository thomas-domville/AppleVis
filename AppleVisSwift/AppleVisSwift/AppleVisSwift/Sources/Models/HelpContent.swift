import Foundation

// Ported from src/data/helpContent.ts — the RN reference client's offline
// help center. That file has ~50 articles across 12 sections; this is a
// curated, faithful subset (Getting Started + Accessibility, the two most
// essential to a new or accessibility-focused user) rather than an
// exhaustive transcription. The block-based content model matches theirs
// exactly, so adding the remaining sections later is just more data, not
// new architecture.

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

struct HelpArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let content: [HelpContentBlock]
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
                            "Post topics, replies, comments, app reviews, and app submissions when signed in.",
                        ]),
                        .note("Most browsing works without signing in. Posting, following, personalized notifications, and some account tools require an AppleVis account."),
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
                        .faq(question: "How do I search AppleVis?", answer: "Open the Discover tab and use the search field. Results are grouped into Forum Topics, Apps, and Guides."),
                        .faq(question: "Where are my saved items?", answer: "Open For You and choose the Saved section."),
                        .faq(question: "What is the difference between Save and Follow?", answer: "Save bookmarks an item locally so you can find it again. Follow keeps it in For You > Following and notifies you when it has new activity."),
                        .faq(question: "How do I download podcast episodes?", answer: "Open the episode and choose Download. Downloaded episodes appear in For You > Downloads for offline listening."),
                        .faq(question: "How do I change my VoiceOver detail level?", answer: "Open Settings > Accessibility > VoiceOver Detail Level and choose Simple, Normal, or All."),
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
                    ]
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
                    ]
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
                    ]
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
                    ]
                ),
            ]
        ),
    ]

    static func find(_ id: String) -> HelpArticle? {
        sections.flatMap(\.articles).first { $0.id == id }
    }
}
