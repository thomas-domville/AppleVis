import Foundation

// Ported from src/guidedExperience/types.ts + src/data/guidedExperiences.ts.

/// Concrete stand-in for RN's generic route strings — Swift has no generic
/// router, and every `route:` the RN data actually used maps 1:1 onto one of
/// these (verified against src/data/guidedExperiences.ts).
enum GuidedExperienceScreenTarget {
    case home, discover, forYou
    /// Covers both Profile and Settings — they're reached via the same
    /// toolbar icon and the same `keyCommands.showSettings` sheet, not two
    /// separate destinations (see GuidedExperienceView.navigate).
    case profile
}

enum GuidedExperienceSecondaryActionKind {
    case exploreScreen(GuidedExperienceScreenTarget)
}

struct GuidedExperienceSecondaryAction: Identifiable {
    let id = UUID()
    let label: String
    let kind: GuidedExperienceSecondaryActionKind
}

struct GuidedExperienceStep: Identifiable {
    let id: String
    /// Groups steps into the chapters progress is actually shown against —
    /// "Step 3 of 8 in Home" instead of "Step 11 of 28" — while the
    /// underlying array (and GuidedExperienceStore's persisted index) stays
    /// flat. Every step has one, including the single-step intro/closing
    /// "chapters," so progress display never needs to special-case them.
    let chapterTitle: String
    let title: String
    let icon: String
    let body: String
    /// Overrides the default "Continue" label — a chapter's last step uses
    /// this for "Continue to Discover" etc.
    var continueLabel: String? = nil
    var secondaryActions: [GuidedExperienceSecondaryAction] = []
}

enum GuidedExperienceCompletionActionKind: Equatable {
    case finish
    case openHelp
    case replay
}

struct GuidedExperienceCompletionAction: Identifiable {
    let id = UUID()
    let label: String
    let kind: GuidedExperienceCompletionActionKind
}

struct GuidedExperience {
    let id: String
    let title: String
    let estimatedTime: String
    let steps: [GuidedExperienceStep]
    let completionActions: [GuidedExperienceCompletionAction]
}

struct GuidedExperienceProgress: Codable {
    var completed = false
    var skipped = false
    var dismissed = false
    var lastStepIndex = 0
    var replayCount = 0
}

/// Rebuilt 2026-09-14 from a flat 8-step tour into 6 chapters (Welcome, Home,
/// Discover, For You, Profile & Settings, All Set) — the old version gave
/// every tab one paragraph regardless of how much there was to say, which
/// beta feedback flagged as too high-level. Each content-heavy chapter now
/// ends on its own checkpoint step (see the `*-checkpoint` steps below)
/// offering Continue/Explore/Pause together, rather than every single step
/// carrying its own "Explore This Screen" the way the old tour did.
enum GuidedExperienceRegistry {
    static let welcome = GuidedExperience(
        id: "welcome",
        title: "Welcome Tour",
        estimatedTime: "A few minutes per section",
        steps: [
            // MARK: Welcome
            GuidedExperienceStep(
                id: "welcome-intro", chapterTitle: "Welcome", title: "Welcome to AppleVis", icon: "sparkles",
                body: "Welcome to AppleVis! AppleVis is the community for blind, DeafBlind, and low vision Apple users. It's a place to exchange accessibility advice, discover apps that work well with VoiceOver, and connect with people who understand.\n\nI'm the Mouse. You might know me from the weekly recap on Home, and I'll be your guide for this tour.\n\nWe'll go through Home, Discover, and For You, then finish with Profile & Settings. I'll also show you Help along the way.\n\nTake as much time as you like. You can leave the tour at any point to explore the app, and when you come back, we'll continue from where you left off."
            ),

            // MARK: Home
            GuidedExperienceStep(
                id: "home-overview", chapterTitle: "Home", title: "Home", icon: "house",
                body: "We'll start with Home. It shows what's happened since you last checked AppleVis, including new forum replies, app entries, podcast episodes, guides, and blog posts.\n\nAt the top are two buttons. Customize Home, shown visually as a small sliders icon, lets you choose what appears in your feed. Add, shown visually as a plus sign in a circle, lets you post a new forum topic or app entry. You'll need to sign in first if you haven't already.\n\nOver the next few steps, I'll show you how to customize the feed, the different ways to view what's new, and the actions available for each type of content."
            ),
            GuidedExperienceStep(
                id: "home-customize", chapterTitle: "Home", title: "Customize Your Feed", icon: "slider.horizontal.3",
                // Previously also claimed "an even finer forum filter" was
                // "tucked in there too" — that Settings > Home Feed picker
                // (Recent/New/Unread/Since Last Visit) has since been
                // removed entirely (it silently pre-filtered forum topics
                // underneath Home's own All/New switcher), so there's
                // nothing left to point to. Requested directly.
                body: "Use Customize Home to choose the types of content that appear in your feed. You can turn Forum Topics, Podcast Episodes, App Listings, Guides & Tutorials, and Blog Posts on or off individually.\n\nIf you only want content about Apple's own products and platforms, turn on Apple Topics Only.\n\nReset to Defaults restores the original Home feed settings."
            ),
            GuidedExperienceStep(
                id: "home-welcome-message", chapterTitle: "Home", title: "Home Welcome Options", icon: "text.bubble",
                body: "Depending on your settings, opening Home can play a short spoken welcome or a fuller spoken summary of what's new since your last visit. You can change this under Home Startup Behavior in Settings, including turning it off completely.\n\nHome can also show a short summary of new activity at the top, which you can dismiss. Activating the summary takes you directly to the first new item. It has its own setting, separate from the spoken welcome, so you can turn either one on or off independently.\n\nBelow the summary is a switcher with three views: All, New, and Mouse Recap. I'll explain those next."
            ),
            GuidedExperienceStep(
                id: "home-all-new-recap", chapterTitle: "Home", title: "All, New, and Mouse Recap", icon: "rectangle.3.group",
                body: "All shows everything currently in your feed, based on the content types you selected in Customize Home.\n\nNew shows only the content that has changed since your last visit, so you don't have to go through items you've already seen.\n\nMouse Recap is a curated, newsletter-style summary of recent activity, grouped into apps, podcasts, forums, blogs, and guides. You can choose either the Past Week or Past Month.\n\nIf you want a quick way to catch up without going through the full feed, Mouse Recap gives you a summary of what happened during that period."
            ),
            GuidedExperienceStep(
                id: "home-card-actions", chapterTitle: "Home", title: "Item Actions", icon: "hand.tap",
                body: "Forum topics, app entries, podcast episodes, and everything else on Home share the same main set of actions.\n\nYou can reach them with a swipe, a tap-and-hold, or the VoiceOver Actions rotor.\n\nSave works like a bookmark and keeps the item in For You so you can find it again later. Share lets you send it to someone else. When there are new comments, Jump to First New Comment opens the item right at the first one you haven't seen.\n\nIf you're signed in, Follow notifies you when there is new activity. Save and Follow serve different purposes, and I'll explain that difference in more detail when we get to For You.\n\nIf you posted a forum topic yourself, Edit and Delete are also available for that topic."
            ),
            GuidedExperienceStep(
                id: "home-topic-detail", chapterTitle: "Home", title: "Inside a Topic, Blog Post, or Guide", icon: "bubble.left.and.bubble.right",
                body: "When you open a forum topic, blog post, or guide, the original post appears first. If the item has replies, Community Discussion appears below it.\n\nThe actions I just covered are available in two places. Topic Actions is a menu at the top of the screen, and a set of action buttons remains available at the bottom of the screen while you're reading.\n\nIf there has been new activity since your last visit, Jump to First New Comment on Home takes you directly to it.\n\nIn a forum topic, the Reply button opens the composer. You can also quote a specific comment when responding to someone.\n\nEach comment has its own actions, including Reply, Copy Text, Share, and Report. You can reach them using the same interaction methods used elsewhere in the app."
            ),
            GuidedExperienceStep(
                id: "home-app-entry", chapterTitle: "Home", title: "Inside an App Entry", icon: "square.grid.2x2",
                body: "Each app entry includes accessibility information provided by the community member who submitted it, based on their own experience with the app. This includes VoiceOver Performance, Button Labeling, Usability, and other accessibility details.\n\nBelow the entry are reviews from the wider community. The AI-powered Consensus feature summarizes the accessibility comments into an overall verdict, and Community Discussion Summary gives you an overview of what reviewers are saying.\n\nOpen in App Store takes you directly to the app's App Store page, where you can download or update it without first opening a browser.\n\nRecommend This App adds your name to the list of people who have given the app a thumbs up. Recommend is separate from Save and Follow.\n\nThe App Entry Actions menu and the button row that remains on screen provide the same two ways to reach the available actions."
            ),
            GuidedExperienceStep(
                id: "home-podcast-detail", chapterTitle: "Home", title: "Inside a Podcast Episode", icon: "headphones",
                body: "Podcast episodes have their own playback screen. You can play, pause, skip, and change the playback speed.\n\nIf the episode includes chapters, you can use the Chapters list or move between chapters with the dedicated VoiceOver rotor.\n\nTranscript lets you read the episode as text.\n\nAudio Enhancements includes Voice Boost for clearer speech, Trim Silence for skipping silent sections, and an Equaliser with built-in presets. AirPlay is also available if you want to send playback to a speaker or TV.\n\nPlayback continues if you leave the episode screen. A mini player remains available as you move between tabs.\n\nA two-finger double-tap anywhere in the app, also known as the Magic Tap, plays or pauses whatever is currently loaded.\n\nAppleVis remembers where you stopped in each episode. Start Over takes you back to the beginning, and Listened is a switch you can turn on as a reminder that you've heard an episode.\n\nYou can also use Add to Queue, download the episode for offline listening, or use the same Save, Share, and Follow actions available elsewhere."
            ),
            GuidedExperienceStep(
                id: "home-checkpoint", chapterTitle: "Home", title: "That's Home!", icon: "arrow.right.circle",
                body: "That's Home! We've covered the feed, customizing what it shows, the All, New, and Mouse Recap views, item actions, and each type of detail page.\n\nYou can continue to Discover or leave the tour for a while and explore Home.",
                continueLabel: "Continue to Discover",
                secondaryActions: [
                    GuidedExperienceSecondaryAction(label: "Explore Home Now", kind: .exploreScreen(.home)),
                ]
            ),

            // MARK: Discover
            GuidedExperienceStep(
                id: "discover-overview", chapterTitle: "Discover", title: "Discover", icon: "safari",
                body: "Next is Discover. This is where you'll find the main sections of AppleVis in browsable lists.\n\nThe App Directory contains app listings. Community includes Forums and Blogs. Learn includes Guides and Podcasts. You'll also find the Bug Tracker, ways to contribute to AppleVis, ways to stay updated, and a growing Friends of AppleVis section with trusted outside resources the community vouches for, starting with Be My Eyes.\n\nSearch is at the top of the Discover screen, so I'll show you that first."
            ),
            GuidedExperienceStep(
                id: "discover-search", chapterTitle: "Discover", title: "Search", icon: "magnifyingglass",
                body: "Search uses a full-text index. That means it can find words inside the content of a post, not just in its title.\n\nWhen you type a search, AppleVis searches Forums, the App Directory, Guides, Blogs, Podcasts, and the Bug Tracker at the same time. Results are grouped by content type so you can narrow down what you're looking for.\n\nResults are announced as you type, so you don't need to press a separate Search button.\n\nIf you enter your search in another language, AppleVis can detect that and offer to translate it before searching.\n\nSearch is always available at the top of Discover. Help has a separate search of its own, which I'll show you later when we get to Profile & Settings."
            ),
            GuidedExperienceStep(
                id: "discover-app-directory", chapterTitle: "Discover", title: "App Directory", icon: "square.grid.2x2",
                body: "The App Directory can be browsed first by platform — iOS, Mac, Apple Watch, or Apple TV — and then by category.\n\nWhen you open an app entry, you'll see the same detail page covered earlier in Home: accessibility notes from the person who submitted the entry, the AI-powered Consensus based on wider community reviews, and a direct link to the App Store.\n\nNext to the App Directory is Community Picks. It shows the apps members recommend, either the latest ones or the most recommended."
            ),
            GuidedExperienceStep(
                id: "discover-forums-blogs-guides-podcasts", chapterTitle: "Discover", title: "Forums, Blogs, Guides & Podcasts", icon: "books.vertical",
                body: "Forums, Blogs, Guides, and Podcasts each open into their own browsable lists.\n\nForums can be filtered by category or by Recent, New, Unread, Following, and Saved, using the same options available through Customize Home.\n\nBlogs are listed with the newest posts first. Guides are grouped by topic. Podcasts list episodes by show.\n\nWhen you open an item, you'll use the same type of detail page already covered in Home for topics, blog posts, guides, and podcast episodes."
            ),
            GuidedExperienceStep(
                id: "discover-bug-tracker", chapterTitle: "Discover", title: "Bug Tracker", icon: "ant",
                body: "The Bug Tracker contains known accessibility bugs for iOS and macOS. It shows iOS bugs first, and you can switch to macOS from the filter menu.\n\nYou can filter the list to show only bugs that are currently active, or view the full history.\n\nEach report shows its severity. If AppleVis has formally reported the bug to Apple, the report also includes its Apple Feedback ID."
            ),
            GuidedExperienceStep(
                id: "discover-contribute", chapterTitle: "Discover", title: "Ways to Contribute", icon: "plus.square",
                body: "You can submit an App, Blog Post, Bug Report, or Podcast from Discover. You need to be signed in, and each submission is reviewed before it is published under the AppleVis name.\n\nForum topics work differently. You can post a topic immediately without editorial review from Home or from Forums.\n\nContact AppleVis is also available here if you want to reach the team directly, and you don't need to be signed in to use it."
            ),
            GuidedExperienceStep(
                id: "discover-staying-in-touch", chapterTitle: "Discover", title: "Staying in Touch", icon: "dot.radiowaves.left.and.right",
                body: "Discover also includes ways to follow AppleVis outside the app.\n\nUnder RSS Feeds, you can copy or share a feed link with the RSS reader you use.\n\nYou'll also find links to AppleVis on Mastodon, Facebook, and X. Each opens with one tap."
            ),
            GuidedExperienceStep(
                id: "discover-checkpoint", chapterTitle: "Discover", title: "That's Discover!", icon: "arrow.right.circle",
                body: "That's Discover! We've covered Search, the App Directory, Forums, Blogs, Guides, Podcasts, the Bug Tracker, ways to contribute, and ways to stay in touch with AppleVis.\n\nYou can continue to For You or explore Discover first.",
                continueLabel: "Continue to For You",
                secondaryActions: [
                    GuidedExperienceSecondaryAction(label: "Explore Discover Now", kind: .exploreScreen(.discover)),
                ]
            ),

            // MARK: For You
            GuidedExperienceStep(
                id: "foryou-overview", chapterTitle: "For You", title: "For You", icon: "person.crop.circle",
                body: "For You brings together the things you've chosen to keep close.\n\nA picker at the top switches between five sections: Saved, Following, Recommended, Queue, and Downloads.\n\nThis is where you'll find items you've saved or followed, apps you've recommended, and podcast episodes you've added to your queue or downloaded.\n\nI'll go through each section with you."
            ),
            GuidedExperienceStep(
                id: "foryou-save-vs-follow", chapterTitle: "For You", title: "Save vs. Follow — What's the Difference?", icon: "bookmark",
                body: "Save and Follow do different things.\n\nSave works like a bookmark. It keeps an item in your Saved list so you can find it again later.\n\nFollow notifies you when there is new activity, such as a new reply to a forum topic. Items you follow appear in the Following section.\n\nYou can Save an item, Follow it, do both, or do neither. The two features are completely independent."
            ),
            GuidedExperienceStep(
                id: "foryou-downloads-queue", chapterTitle: "For You", title: "Downloads & Queue", icon: "arrow.down.circle",
                body: "Queue lets you line up podcast episodes to play one after another. When the current episode finishes, the next one begins automatically. Play Next moves an episode directly to the front of the queue.\n\nYour queue syncs across your devices through iCloud, so a queue created on one device is available on another.\n\nDownloads keeps podcast episodes on your device for offline listening. If you prefer, you can turn on Auto-Download in Settings so episodes are downloaded automatically."
            ),
            GuidedExperienceStep(
                id: "foryou-recommended", chapterTitle: "For You", title: "Recommended", icon: "hand.thumbsup",
                body: "Recommended contains every app you've given a thumbs up to.\n\nRecommendations are tied to your AppleVis account rather than only to this app. That means recommendations you made on the AppleVis website in the past also appear here, even if you made them years before installing the app.\n\nYou can remove a recommendation directly from this list."
            ),
            GuidedExperienceStep(
                id: "foryou-checkpoint", chapterTitle: "For You", title: "That's For You!", icon: "arrow.right.circle",
                body: "That's For You! We've covered Saved, Following, Recommended, Queue, and Downloads, along with the difference between Save and Follow.\n\nYou can continue to Profile & Settings or explore For You first.",
                continueLabel: "Continue to Profile & Settings",
                secondaryActions: [
                    GuidedExperienceSecondaryAction(label: "Explore For You Now", kind: .exploreScreen(.forYou)),
                ]
            ),

            // MARK: Profile & Settings
            GuidedExperienceStep(
                id: "profile-settings-overview", chapterTitle: "Profile & Settings", title: "Profile & Settings", icon: "person.circle",
                // Used to also offer a "Learn More" secondary action linking
                // to the "Main Tabs and Navigation" Help article — but that
                // article covers what Home/Discover/For You/Profile do
                // broadly, which this step isn't about (it's specifically
                // about the Profile/Settings toolbar button), and which the
                // tour itself had already covered in far more depth over the
                // preceding chapters anyway. Removed as the only "Learn
                // More" in the whole tour, not a pattern applied elsewhere.
                // Requested directly.
                body: "The Profile and Settings button is available from Home, Discover, and For You. Visually, it appears as a small person icon in the toolbar.\n\nProfile and Settings isn't a separate tab. The button remains available in the toolbar as you move between the three main tabs.\n\nHere you'll find My Account, Settings, What's New, About, Contact AppleVis, and Replay Welcome Tour.\n\nI'll show you the main sections."
            ),
            GuidedExperienceStep(
                id: "profile-my-account", chapterTitle: "Profile & Settings", title: "My Account", icon: "person.crop.circle.badge.pencil",
                body: "My Account contains the options related to signing in and managing your AppleVis account.\n\nEdit Profile lets you change the information shown to other community members, including your Bio. AI-powered Bio Assist can help you draft a Bio if you'd like help getting started.\n\nChange Password and Change Email Address let you update your account credentials from the app. Sign Out is also available here.\n\nPrivate messages are handled from member profiles rather than My Account. To message someone, find their name in the app, open their profile, and choose the option to send them a private message."
            ),
            GuidedExperienceStep(
                id: "profile-settings-breadth", chapterTitle: "Profile & Settings", title: "Settings", icon: "gearshape",
                body: "Settings contains several groups of options.\n\nGeneral includes settings for how Home behaves and for tips.\n\nCustomisation includes Appearance and Accessibility controls.\n\nAlerts includes Notifications and Sounds & Haptics.\n\nContent includes settings for your Home Feed and Podcast defaults.\n\nData & Privacy includes iCloud sync, privacy settings, Apple Intelligence features, content translation, and Siri & Shortcuts.\n\nStorage & Cache includes controls for managing downloads.\n\nSettings also has its own search. Type a few letters, and the results narrow to the matching settings screen."
            ),
            GuidedExperienceStep(
                id: "profile-help", chapterTitle: "Profile & Settings", title: "Help", icon: "questionmark.circle",
                body: "Before we finish, I'll show you Help.\n\nHelp includes tutorials, accessibility tips, settings walkthroughs, information about smart features, and troubleshooting articles.\n\nThe Help content is stored on your device, so you can use it even when you don't have an internet connection.\n\nHelp has its own search, separate from Search in Discover and the search in Settings. It searches both article titles and their summaries.\n\nIf you still need help after reading an article, Contact & Support is one section away and gives you a way to reach the AppleVis team directly."
            ),

            // MARK: All Set
            GuidedExperienceStep(
                id: "welcome-ready", chapterTitle: "All Set", title: "You're All Set", icon: "checkmark.circle",
                body: "That's the end of the tour. We've covered Home, Discover, For You, Profile & Settings, and Help.\n\nYou can start exploring the app from whichever tab you'd like.\n\nIf you want to take the tour again later, Replay Welcome Tour is available from Profile. Help is there too whenever you need it.\n\nThanks for letting me show you around. I'm the Mouse, and I'll see you around AppleVis!"
            ),
        ],
        completionActions: [
            GuidedExperienceCompletionAction(label: "Start Exploring", kind: .finish),
            GuidedExperienceCompletionAction(label: "Open Help", kind: .openHelp),
            GuidedExperienceCompletionAction(label: "Replay Tour", kind: .replay),
        ]
    )
}
