import Foundation

/// How-To Library: AppleVis's own settings (2026-10-08). "How do I change…"
/// questions about this app, answered with its real screen and setting
/// names. Help is translated while the app runs.
extension HelpContent {
    static let howToAppleVisSettings = HelpSection(
        id: "howto-applevis-settings",
        title: "How To: AppleVis Settings",
        icon: "gearshape.2",
        description: "Themes, sounds, haptics, the welcome when AppleVis opens, what's on Home, reminders, podcast playback, links, and signing out.",
        articles: [
            HelpArticle(
                id: "howto-av-open-settings",
                title: "How Do I Open AppleVis Settings?",
                summary: "Settings live in Profile.",
                content: [
                    .steps([
                        "Choose Profile and Settings, at the top right of Home, Discover, or For You.",
                        "Choose Settings.",
                    ]),
                    .tip("With a keyboard, press Command-Comma from anywhere. Settings also has its own search."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-theme",
                title: "How Do I Change the AppleVis Theme?",
                summary: "High contrast, the Mouse and Goldie themes, and more.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Appearance.",
                        "Choose a theme from the Accessibility, AppleVis, or Standard groups.",
                    ]),
                    .bullets([
                        "Accessibility: High Contrast Light and High Contrast Dark.",
                        "AppleVis: AppleVis Classic, Mouse, Goldie, Orchard, Cupertino Sunset, and Nebula. Mouse and Goldie each come in Light and Dark.",
                        "Standard: follow iOS, always light, always dark, and softer options like Warm and Sepia.",
                    ]),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Open AppleVis Settings?", type: .tutorial, destination: .article("howto-av-open-settings"))]
            ),
            HelpArticle(
                id: "howto-av-sounds",
                title: "How Do I Turn AppleVis Sounds Off?",
                summary: "Confirmation sounds and interface sounds.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Sounds & Haptics.",
                        "Turn off Confirmation Sounds for the sounds after you save, post, mark as read, and so on.",
                        "Turn off Interface Sounds for the quieter sounds, such as switching tabs and opening screens.",
                    ]),
                    .note("Error and offline sounds always play, so you know when something needs attention."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-haptics",
                title: "How Do I Turn Off Haptics in AppleVis?",
                summary: "The taps you feel when something happens.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Sounds & Haptics.",
                        "Turn off Haptic Feedback.",
                    ]),
                    .note("If you turn off both Confirmation Sounds and Haptic Feedback, VoiceOver says what happened in words instead."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-welcome",
                title: "How Do I Change the Welcome When AppleVis Opens?",
                summary: "Home Startup Behavior: Quiet, Helpful, or Detailed.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then General.",
                        "Choose Home Startup Behavior.",
                        "Choose Quiet for no welcome, Helpful for a short one, or Detailed for a welcome with a summary of what's new.",
                    ]),
                    .body("Welcome Summary, on the same screen, turns the summary box at the top of Home on or off."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-apple-only",
                title: "How Do I Hide Non-Apple Topics?",
                summary: "Show only Apple topics on Home and in Forums.",
                content: [
                    .steps([
                        "On Home, choose Customize Home at the top left. Or open AppleVis Settings, then Home Feed.",
                        "Turn on Apple Topics Only.",
                    ]),
                    .body("Non-Apple topics include Windows, Android, smart home, and general assistive technology discussions."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-home-content",
                title: "How Do I Choose What Appears on Home?",
                summary: "Forum topics, podcast episodes, app listings, guides, and blog posts.",
                content: [
                    .steps([
                        "On Home, choose Customize Home at the top left. Or open AppleVis Settings, then Home Feed.",
                        "Turn each type on or off: Forum Topics, Podcast Episodes, App Listings, Guides & Tutorials, and Blog Posts.",
                    ]),
                    .tip("Show What's New on Home, in AppleVis Settings > General, turns off the New view, the summary, and the new-activity badges, for a quieter Home."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-reminders",
                title: "How Do I Turn On Catch-Up Reminders?",
                summary: "A gentle reminder of what's new after a week away.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Notifications.",
                        "Under Reminders, turn on Catch-Up Reminders.",
                    ]),
                    .body("If you haven't opened AppleVis for a week, you get one reminder of what's new. One more comes two weeks later, and then no more until you're back."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Notifications", type: .guide, destination: .article("settings-notifications"))]
            ),
            HelpArticle(
                id: "howto-av-notification-sound",
                title: "How Do I Change the AppleVis Notification Sound?",
                summary: "A mouse squeak, an apple crunch, a bark, or your iPhone's own sound.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Notifications.",
                        "Choose Notification Sound, and swipe up or down through the choices. Each one plays as you choose it.",
                    ]),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-podcast",
                title: "How Do I Change Podcast Speed and Skip Times?",
                summary: "Playback settings for the AppleVis Podcast.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Podcast.",
                        "Set Speed, Skip Back, and Skip Forward.",
                    ]),
                    .body("The same screen has Headphone Controls, Auto-Play Next, Open Player on Play, Trim Silence, Voice Boost, the Equaliser, the Sleep Timer, Resume Rewind, Auto-Download, and Auto-Delete."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-web-links",
                title: "How Do I Open Links in Safari Instead of AppleVis?",
                summary: "Choose where web links open.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then General.",
                        "Choose Web Links, then In-App Browser or Default Browser.",
                    ]),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-av-sign-out",
                title: "How Do I Sign Out of AppleVis?",
                summary: "Sign out on this device.",
                content: [
                    .steps([
                        "Choose Profile and Settings.",
                        "Choose your name at the top.",
                        "Choose Sign Out, then confirm.",
                    ]),
                    .note("Your saved password is removed from this iPhone when you sign out."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
