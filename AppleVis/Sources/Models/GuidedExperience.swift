import Foundation

// Ported from src/guidedExperience/types.ts + src/data/guidedExperiences.ts.

/// Concrete stand-in for RN's generic route strings — Swift has no generic
/// router, and every `route:` the RN data actually used maps 1:1 onto one of
/// these (verified against src/data/guidedExperiences.ts).
enum GuidedExperienceScreenTarget {
    case home, discover, forYou, profile, settings
}

enum GuidedExperienceSecondaryActionKind {
    case exploreScreen(GuidedExperienceScreenTarget)
    case learnMore(helpArticleId: String)
}

struct GuidedExperienceSecondaryAction: Identifiable {
    let id = UUID()
    let label: String
    let kind: GuidedExperienceSecondaryActionKind
}

struct GuidedExperienceStep: Identifiable {
    let id: String
    let title: String
    let icon: String
    let shortText: String
    var explainMoreText: String? = nil
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

enum GuidedExperienceRegistry {
    static let welcome = GuidedExperience(
        id: "welcome",
        title: "Welcome Tour",
        estimatedTime: "3-5 minutes",
        steps: [
            GuidedExperienceStep(
                id: "welcome-intro", title: "Welcome to AppleVis", icon: "sparkles",
                shortText: "So glad you're here! AppleVis is the community for blind, DeafBlind, and low vision Apple users — a place to swap accessibility advice, discover apps that actually work well with VoiceOver, and hear from people who get it.",
                explainMoreText: "This quick tour will walk you through where everything lives, so you can jump in feeling right at home. Skip ahead anytime — you can always come back to it from Help."
            ),
            GuidedExperienceStep(
                id: "welcome-home", title: "Home", icon: "house",
                shortText: "Home is your first stop — a friendly catch-up on what's happened since you last checked in.",
                explainMoreText: "New forum replies, fresh app entries, podcast episodes, guides — it's all gathered here so you're never digging for what's new. Once in a while you'll spot a little something extra too, like a Mouse Recap of the week or a nod on your AppleVis anniversary.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen(.home))]
            ),
            GuidedExperienceStep(
                id: "welcome-discover", title: "Discover", icon: "safari",
                shortText: "Discover is where the whole community opens up to you.",
                explainMoreText: "Browse the App Directory (with real accessibility ratings from real users), dive into the Forums, catch up on Blogs and Guides, queue up a Podcasts episode, check the Bug Tracker, or find ways to contribute yourself. There's a lot here — take your time with it.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen(.discover))]
            ),
            GuidedExperienceStep(
                id: "welcome-foryou", title: "For You", icon: "person.crop.circle",
                shortText: "For You is your own little corner of AppleVis — everything you've kept, followed, or want to pick back up.",
                explainMoreText: "Saved items, topics you're following, apps you've recommended to others, your podcast queue and downloads — it's all right here whenever you want to pick up where you left off.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen(.forYou))]
            ),
            GuidedExperienceStep(
                id: "welcome-search", title: "Search", icon: "magnifyingglass",
                shortText: "Can't remember where you saw something? Search has you covered.",
                explainMoreText: "It looks across discussions, apps, guides, podcast episodes, and Help all at once, and groups the results so you can zero in on exactly the kind of thing you're after.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen(.discover))]
            ),
            GuidedExperienceStep(
                id: "welcome-profile", title: "Profile", icon: "person",
                shortText: "Profile is your home base for everything account-related.",
                explainMoreText: "Sign in, edit how you show up to the rest of the community, change your password or email right from the app, message another member, or reach out to the AppleVis team if you ever need a hand.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen(.profile))]
            ),
            GuidedExperienceStep(
                id: "welcome-settings-help", title: "Settings and Help", icon: "gearshape",
                shortText: "Settings is where you make AppleVis feel like yours — appearance, accessibility, sounds and haptics, notifications, podcasts, privacy, and more.",
                explainMoreText: "And whenever you want a refresher, Help is always just a tap away, with guides, tutorials, and answers to the questions people ask most.",
                secondaryActions: [
                    GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen(.settings)),
                    GuidedExperienceSecondaryAction(label: "Learn More", kind: .learnMore(helpArticleId: "start-tabs")),
                ]
            ),
            GuidedExperienceStep(
                id: "welcome-ready", title: "You're All Set", icon: "checkmark.circle",
                shortText: "That's the tour! You're ready to make yourself at home in AppleVis.",
                explainMoreText: "Wander over to Home, poke around Discover, or settle into For You — however you like to start. And if you ever want to run through this again, it's waiting for you in Help."
            ),
        ],
        completionActions: [
            GuidedExperienceCompletionAction(label: "Start Exploring", kind: .finish),
            GuidedExperienceCompletionAction(label: "Open Help", kind: .openHelp),
            GuidedExperienceCompletionAction(label: "Replay Tour", kind: .replay),
        ]
    )
}
