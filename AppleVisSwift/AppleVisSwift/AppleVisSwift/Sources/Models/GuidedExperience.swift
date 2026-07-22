import Foundation

// Ported from src/guidedExperience/types.ts + src/data/guidedExperiences.ts.

enum GuidedExperienceSecondaryActionKind {
    case exploreScreen
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
                shortText: "AppleVis brings together community discussions, accessible app information, podcasts, guides, and Apple accessibility resources in one place.",
                explainMoreText: "This quick tour will show you where to begin and where to find help when you need it."
            ),
            GuidedExperienceStep(
                id: "welcome-home", title: "Home", icon: "house",
                shortText: "Home helps you catch up on the latest AppleVis activity.",
                explainMoreText: "It brings together new topics, podcast activity, app entries, guides, and other updates so you know where to begin.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen)]
            ),
            GuidedExperienceStep(
                id: "welcome-discover", title: "Discover", icon: "safari",
                shortText: "Discover is your gateway to the wider AppleVis community.",
                explainMoreText: "Browse the App Directory, community areas, learning resources, the Bug Tracker, and ways to contribute.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen)]
            ),
            GuidedExperienceStep(
                id: "welcome-foryou", title: "For You", icon: "person.crop.circle",
                shortText: "For You is your personal AppleVis hub.",
                explainMoreText: "Return to your queue, downloads, saved items, and followed content whenever you want to continue where you left off.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen)]
            ),
            GuidedExperienceStep(
                id: "welcome-search", title: "Search", icon: "magnifyingglass",
                shortText: "Search (inside Discover) helps you find discussions, apps, guides, and podcast episodes across AppleVis.",
                explainMoreText: "Results are grouped so you can quickly choose the kind of content you want.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen)]
            ),
            GuidedExperienceStep(
                id: "welcome-profile", title: "Profile", icon: "person",
                shortText: "Profile is where you sign in, view account tools, check support information, and access app information.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Explore This Screen", kind: .exploreScreen)]
            ),
            GuidedExperienceStep(
                id: "welcome-settings-help", title: "Settings and Help", icon: "gearshape",
                shortText: "Settings lets you customize appearance, accessibility, notifications, podcasts, privacy, storage, and more.",
                explainMoreText: "Help is always available when you want a guide, troubleshooting step, or refresher.",
                secondaryActions: [GuidedExperienceSecondaryAction(label: "Learn More", kind: .learnMore(helpArticleId: "start-tabs"))]
            ),
            GuidedExperienceStep(
                id: "welcome-ready", title: "You're Ready", icon: "checkmark.circle",
                shortText: "You're ready to explore AppleVis. You can replay this tour anytime from Help.",
                explainMoreText: "Start with Home, browse Discover, or open For You to continue your personal AppleVis journey."
            ),
        ],
        completionActions: [
            GuidedExperienceCompletionAction(label: "Start Exploring", kind: .finish),
            GuidedExperienceCompletionAction(label: "Open Help", kind: .openHelp),
            GuidedExperienceCompletionAction(label: "Replay Tour", kind: .replay),
        ]
    )
}
