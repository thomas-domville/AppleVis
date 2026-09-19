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
                body: "So glad you're here! AppleVis is the community for blind, DeafBlind, and low vision Apple users — a place to swap accessibility advice, discover apps that actually work well with VoiceOver, and hear from people who get it. I'm the Mouse — you might know me from the weekly recap on Home — and I'll be your guide for this tour. We'll go tab by tab: Home, Discover, and For You, then finish with Profile & Settings, with Help getting its own moment along the way. Take as long as you like with each one, and feel free to jump into the app for real anytime — I'll be waiting right where you left off when you're ready to pick the tour back up."
            ),

            // MARK: Home
            GuidedExperienceStep(
                id: "home-overview", chapterTitle: "Home", title: "Home", icon: "house",
                body: "Home is your first stop — a friendly catch-up on everything that's happened since you last checked in: new forum replies, fresh app entries, podcast episodes, guides, and blog posts, all gathered in one place so you're never digging for what's new. Up top you'll find two handy buttons — Customize Home, shown as a small sliders icon, and Add, a plus sign in a circle, for posting a new topic or app entry of your own — sign in first if you haven't already. Over the next few steps, I'll walk you through making this feed yours, the different ways to look at what's new, and what you can actually do once something catches your eye."
            ),
            GuidedExperienceStep(
                id: "home-customize", chapterTitle: "Home", title: "Customize Your Feed", icon: "slider.horizontal.3",
                // Previously also claimed "an even finer forum filter" was
                // "tucked in there too" — that Settings > Home Feed picker
                // (Recent/New/Unread/Since Last Visit) has since been
                // removed entirely (it silently pre-filtered forum topics
                // underneath Home's own All/New switcher), so there's
                // nothing left to point to. Requested directly.
                body: "Tap that Customize Home button, and you're in control of exactly what shows up: turn Forum Topics, Podcast Episodes, App Listings, Guides & Tutorials, or Blog Posts on or off individually, whatever mix suits you. Want to keep things focused on Apple's own products and platforms? Flip on Apple Topics Only and everything else quietly steps aside. Changed your mind about any of it? Reset to Defaults puts everything back the way it started."
            ),
            GuidedExperienceStep(
                id: "home-welcome-message", chapterTitle: "Home", title: "A Welcome, Your Way", icon: "text.bubble",
                body: "Open Home, and depending on your settings, you might hear a short spoken welcome — or even a full rundown of what's new since you were last here. That's Home Startup Behavior, and you can turn it up, down, or off entirely in Settings. You may also spot a dismissible card summarizing new activity — tap it to jump straight to the first new item, or turn it off separately if you'd rather Home stay visually quiet (it's its own setting, independent of the spoken welcome). Right below that lives a little switcher with three views — All, New, and Mouse Recap — and I'll walk you through exactly what each one shows you next."
            ),
            GuidedExperienceStep(
                id: "home-all-new-recap", chapterTitle: "Home", title: "All, New, or Mouse Recap — Pick Your View", icon: "rectangle.3.group",
                body: "All shows you everything currently in your feed, based on whatever content types you've turned on in Customize Home. New narrows that same feed down to just what's actually changed since your last visit — no re-scanning things you've already seen. Mouse Recap is a different animal entirely: a curated, newsletter-style digest — grouped by apps, podcasts, forums, blogs, and guides — that you can scope to the Past Week or Past Month. Short on time? That's exactly when Mouse Recap earns its keep — one quick read catches you up on everything that happened in that window, without scrolling through it all yourself."
            ),
            GuidedExperienceStep(
                id: "home-card-actions", chapterTitle: "Home", title: "Every Card, Same Toolkit", icon: "hand.tap",
                body: "No matter what kind of card you're looking at — a topic, an app, an episode — they all share a common set of actions. However you like to interact — a swipe, a tap-and-hold, or the VoiceOver Actions rotor — you'll find the same things waiting: Save, which works like a bookmark so you can find it again anytime in For You; Share; a quick jump to what's new; and, if you're signed in, Follow, which notifies you of new activity rather than just setting something aside (more on that difference when we get to For You). Posted the topic yourself? You'll spot Edit and Delete there too, just for your own posts."
            ),
            GuidedExperienceStep(
                id: "home-topic-detail", chapterTitle: "Home", title: "Inside a Topic (or Blog Post, or Guide)", icon: "bubble.left.and.bubble.right",
                body: "Open a topic — or a blog post or guide, which work the same way — and you'll land on the original post, with Community Discussion right below it for everyone's replies. Two quick paths to the actions we just covered live right here too: a menu called Topic Actions, or a set of buttons that stays on screen the whole time you're reading — pick whichever's easier to reach (the menu sits at the top, the buttons along the bottom, if you're looking for them visually). If there's new activity since you last visited, that's exactly where the quick jump from the card takes you. Ready to join in? The reply button opens a composer, and you can quote someone directly if you're responding to a specific comment. Each comment carries its own set of actions too — reply, copy the text, share it, or report it if something's not right — reachable the same way as everywhere else, however you like to interact."
            ),
            GuidedExperienceStep(
                id: "home-app-entry", chapterTitle: "Home", title: "Inside an App Entry", icon: "square.grid.2x2",
                body: "Every app entry comes with accessibility details you actually want before downloading — VoiceOver Performance, Button Labeling, Usability, and more — filled in by the community member who submitted the entry, based on their own hands-on experience with the app. Want the wider community's take? Scroll down to reviews, where an AI-powered Consensus feature distills everyone's accessibility comments into one verdict, and Community Discussion Summary recaps what reviewers are saying overall. Ready to try it? Open in App Store takes you straight there to download or update — no detour through a browser first. Like it enough to vouch for it yourself? Recommend This App adds your name to the list of people who've given it a thumbs up, separate from Save or Follow. Same two quick paths as before — the App Entry Actions menu, or the button row that stays on screen the whole time — get you to all of it."
            ),
            GuidedExperienceStep(
                id: "home-podcast-detail", chapterTitle: "Home", title: "Inside a Podcast Episode", icon: "headphones",
                body: "Podcast episodes get their own playback screen — play, pause, skip, and adjust speed right there, plus a Chapters list you can tap through, or jump between with its own dedicated VoiceOver rotor if the episode has them marked. Want the episode in front of you as text? Open the Transcript. Prefer to tune how it sounds? Audio Enhancements gives you Voice Boost for clearer speech, Trim Silence to skip the dead air, and an Equaliser with presets built in — and AirPlay is right there too, for sending playback to a speaker or your TV. Leave the screen and playback doesn't stop: a mini player follows you to whatever tab you're on, so you're never stuck here just to keep listening. Want to control it without even opening this screen? A two-finger double-tap anywhere — a Magic Tap — plays or pauses whatever's loaded, no matter where you are in the app. Add to Queue and Download for offline listening live here too, alongside the same Save, Share, and Follow actions from before."
            ),
            GuidedExperienceStep(
                id: "home-checkpoint", chapterTitle: "Home", title: "That's Home!", icon: "arrow.right.circle",
                body: "That covers Home — the feed, making it yours, all three views, card actions, and every kind of detail page. Ready to see what Discover has to offer, or want to explore Home for real first?",
                continueLabel: "Continue to Discover",
                secondaryActions: [
                    GuidedExperienceSecondaryAction(label: "Explore Home Now", kind: .exploreScreen(.home)),
                ]
            ),

            // MARK: Discover
            GuidedExperienceStep(
                id: "discover-overview", chapterTitle: "Discover", title: "Discover", icon: "safari",
                body: "While Home hands you a personalized catch-up, Discover is the front door to everything AppleVis has to offer — organized into browsable sections: the App Directory, Community (Forums and Blogs), Learn (Guides and Podcasts), the Bug Tracker, ways to contribute back, ways to stay updated, and a growing \"Friends of AppleVis\" section — trusted outside resources the community vouches for, starting with Be My Eyes. Over the next few steps, I'll walk you through the standout parts — starting with something that lives right at the top of this screen and deserves its own spotlight: Search."
            ),
            GuidedExperienceStep(
                id: "discover-search", chapterTitle: "Discover", title: "Search", icon: "magnifyingglass",
                body: "This isn't your typical search — it's a real full-text index, so it finds matches inside the actual content of a post, not just its title. Type here and AppleVis searches Forums, the App Directory, Guides, Blogs, Podcasts, and the Bug Tracker all at once, then groups what it finds so you can zero in on exactly the kind of thing you're after. Results are announced as you type — no need to stop and press a search button. Typed your search in another language? AppleVis notices and offers to translate it for you, so you're not stuck searching in English just to find what you need. It's always sitting right at the top of Discover, ready whenever you need it. (Looking for a Help article specifically? That one's got its own dedicated search — more on that when we get to Profile and Settings.)"
            ),
            GuidedExperienceStep(
                id: "discover-app-directory", chapterTitle: "Discover", title: "App Directory", icon: "square.grid.2x2",
                body: "Browse by platform first — iOS, Mac, Apple Watch, or Apple TV — then by category, so you're never scrolling through the entire directory just to find something for the platform you actually use. Once you're looking at an entry, it's the same detail page you already know from Home: one submitter's real accessibility notes, an AI-powered Consensus pulling together what the wider community's reviews say, and a direct line to the App Store when you're ready to grab it."
            ),
            GuidedExperienceStep(
                id: "discover-forums-blogs-guides-podcasts", chapterTitle: "Discover", title: "Forums, Blogs, Guides & Podcasts", icon: "books.vertical",
                body: "Each of these opens into a straightforward browsable list — Forums lets you filter by category or by the same Recent/New/Unread/Following/Saved options from Customize Home, Blogs runs newest-first, Guides group by topic, and Podcasts list episodes by show. Tap into any of them, and you're right back on the same kind of detail page you already toured in Home — topic, blog, or episode, working exactly the way you already know."
            ),
            GuidedExperienceStep(
                id: "discover-bug-tracker", chapterTitle: "Discover", title: "Bug Tracker", icon: "ant",
                body: "Browse known accessibility bugs by platform — iOS or macOS — and filter to just what's currently active, or see the full history. Each report shows its severity at a glance, and when a bug's already been formally reported to Apple, you'll see its Apple Feedback ID right there too, so you know it's already on Apple's radar, not just AppleVis's."
            ),
            GuidedExperienceStep(
                id: "discover-contribute", chapterTitle: "Discover", title: "Ways to Contribute", icon: "plus.square",
                body: "Have something to add? Submit an App, a Blog Post, a Bug Report, or a Podcast right from here — sign in first, since each one gets reviewed before it's published under AppleVis's name. Want to post a topic instead? That's immediate and doesn't need review — you'll find that back on Home or in Forums. And if you just want to reach the team directly, Contact AppleVis is right here too, no sign-in required."
            ),
            GuidedExperienceStep(
                id: "discover-staying-in-touch", chapterTitle: "Discover", title: "Staying in Touch", icon: "dot.radiowaves.left.and.right",
                body: "Prefer to keep up with AppleVis outside the app too? RSS Feeds are right here for it — copy or share a feed link to whatever reader you use. And AppleVis is out on social media as well: Mastodon, Facebook, and X, all one tap away, so you can follow along wherever you already spend your time."
            ),
            GuidedExperienceStep(
                id: "discover-checkpoint", chapterTitle: "Discover", title: "That's Discover!", icon: "arrow.right.circle",
                body: "That covers Discover — Search, the App Directory, Forums, Blogs, Guides, Podcasts, the Bug Tracker, ways to contribute, and staying in touch. Ready to see what's waiting for you in For You, or want to explore Discover for real first?",
                continueLabel: "Continue to For You",
                secondaryActions: [
                    GuidedExperienceSecondaryAction(label: "Explore Discover Now", kind: .exploreScreen(.discover)),
                ]
            ),

            // MARK: For You
            GuidedExperienceStep(
                id: "foryou-overview", chapterTitle: "For You", title: "For You", icon: "person.crop.circle",
                body: "For You is your own corner of AppleVis — a picker up top switches between five sections: Saved, Following, Recommended, Queue, and Downloads. Whatever you've kept, followed, vouched for, or lined up to listen to later, it all lives here, ready whenever you want to pick back up where you left off. Let's go through what makes each one worth knowing about."
            ),
            GuidedExperienceStep(
                id: "foryou-save-vs-follow", chapterTitle: "For You", title: "Save vs. Follow — What's the Difference?", icon: "bookmark",
                body: "These two get mixed up a lot, so here's the short version: Save is a bookmark — it just keeps something so you can find it again, nothing more. Follow is about staying in the loop — it notifies you when there's new activity, like a reply on a topic, and you'll see it waiting for you here in Following. You can do either one, both, or neither on the same item — they're completely independent, so use whichever fits what you actually want from it."
            ),
            GuidedExperienceStep(
                id: "foryou-downloads-queue", chapterTitle: "For You", title: "Downloads & Queue", icon: "arrow.down.circle",
                body: "Queue lines up episodes to play one after another — add something, and it picks up automatically once the current episode finishes, or use Play Next to jump it straight to the front. It even syncs across your devices via iCloud, so a queue you build on one device shows up on the next. Downloads keeps episodes right on your device for offline listening, with an Auto-Download setting in Settings if you'd rather it happen for you automatically."
            ),
            GuidedExperienceStep(
                id: "foryou-recommended", chapterTitle: "For You", title: "Recommended", icon: "hand.thumbsup",
                body: "Every app you've given a thumbs up to lives here — and since Recommend is tied to your account, not just this app, your full history shows up even if you started recommending apps on the website years before you ever installed this app. Changed your mind about one? Remove it right from this list, same as anywhere else."
            ),
            GuidedExperienceStep(
                id: "foryou-checkpoint", chapterTitle: "For You", title: "That's For You!", icon: "arrow.right.circle",
                body: "That covers For You — Saved, Following, Recommended, Queue, and Downloads, plus the difference between Save and Follow. Ready for the last stop — Profile and Settings — or want to explore For You for real first?",
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
                body: "Every screen — Home, Discover, and For You — has a button labeled Profile and Settings tucked into the toolbar, shown as a small person icon if you're looking for it visually. It stays with you no matter which tab you're on, rather than living as a tab of its own. Head in, and you'll find My Account for everything sign-in related, a link into Settings for making AppleVis feel like yours, and a section for What's New, About, quick access to Contact AppleVis, and — worth remembering — Replay Welcome Tour, right there whenever you want to run through this again. Let's go through what's actually in each."
            ),
            GuidedExperienceStep(
                id: "profile-my-account", chapterTitle: "Profile & Settings", title: "My Account", icon: "person.crop.circle.badge.pencil",
                body: "My Account is where everything sign-in related lives: Edit Profile to change how you show up to the community — including your Bio, which other members will see when they visit your profile, with an AI-powered Bio Assist to help draft one if you're not sure where to start. Change Password and Change Email Address update your credentials right from the app, and Sign Out is there whenever you're done. Want to message someone directly? That's not tucked in here — just look for their name anywhere in the app, and you'll find the option to send them a private message right from their own profile."
            ),
            GuidedExperienceStep(
                id: "profile-settings-breadth", chapterTitle: "Profile & Settings", title: "Settings", icon: "gearshape",
                body: "Settings is genuinely deep — General for how Home behaves and tips; Customisation for Appearance and Accessibility controls; Alerts for Notifications and Sounds & Haptics; Content for your Home Feed (which we already covered) and Podcast defaults; Data & Privacy covering iCloud sync, privacy, Apple Intelligence features, content translation, and Siri & Shortcuts; and Storage & Cache for managing downloads. If you're hunting for something specific, Settings has its own search built right in — type a few letters and it narrows straight down to the matching screen."
            ),
            GuidedExperienceStep(
                id: "profile-help", chapterTitle: "Profile & Settings", title: "Help", icon: "questionmark.circle",
                body: "Help gets its own moment because it deserves one: tutorials, accessibility tips, settings walkthroughs, smart features, troubleshooting — all of it saved right on your device, so it works even without a connection. And it has its own dedicated search, separate from Discover's and Settings' own, that looks inside both article titles and their summaries to find exactly what you need. If reading through Help isn't enough, Contact & Support is right there too, one section away from reaching the team directly."
            ),

            // MARK: All Set
            GuidedExperienceStep(
                id: "welcome-ready", chapterTitle: "All Set", title: "You're All Set", icon: "checkmark.circle",
                body: "That's everything — Home, Discover, For You, and your Profile and Settings, all covered. Wander over to whichever tab calls to you first, however you like to start. If you want to run through this again, or need a hand with anything else, Help and Replay Welcome Tour are both waiting for you in Profile whenever you need them. Thanks for letting me show you around — go make yourself at home."
            ),
        ],
        completionActions: [
            GuidedExperienceCompletionAction(label: "Start Exploring", kind: .finish),
            GuidedExperienceCompletionAction(label: "Open Help", kind: .openHelp),
            GuidedExperienceCompletionAction(label: "Replay Tour", kind: .replay),
        ]
    )
}
