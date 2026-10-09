import Foundation

/// Device guides (2026-10-08): one "start here" guide per device for
/// VoiceOver users, from setup to everyday use. They give the big picture
/// and link to the How-To Library and Quick Reference for the details,
/// rather than repeating them. Written for the 27 releases in AppleVis's own
/// words. Help is translated while the app runs.
extension HelpContent {
    static let deviceGuides = HelpSection(
        id: "device-guides",
        title: "Device Guides for VoiceOver Users",
        icon: "books.vertical",
        description: "Start here for iPhone, iPad, Mac, Apple Watch, and Apple TV: setting up with VoiceOver, getting around, and everyday use.",
        articles: [
            HelpArticle(
                id: "guide-iphone",
                title: "iPhone with VoiceOver: Start Here",
                summary: "From turning it on to everyday use, for blind and low vision iPhone users.",
                content: [
                    .heading("1. Turn on VoiceOver"),
                    .body("On a new iPhone, triple-click the side button as soon as you hear the welcome sound. On iPhones with a Home button, triple-click the Home button. VoiceOver starts speaking, and you can set up the rest yourself."),
                    .heading("2. Learn the core gestures"),
                    .body("Touch the screen to hear what's under your finger. Swipe right or left with one finger to move to the next or previous item. Double-tap to activate the item VoiceOver is on. Scrub with two fingers, a quick Z shape, to go back. Swipe up with three fingers to scroll down."),
                    .body("Turn two fingers on the screen like a dial to open the rotor, then swipe up or down to use the setting you chose, such as Headings or Speaking Rate."),
                    .heading("3. Know the buttons"),
                    .body("The side button locks and wakes iPhone. The volume buttons are on the left, and newer models have an Action button above them. The charging port is in the middle of the bottom edge."),
                    .heading("4. Get around iPhone"),
                    .body("The Home Screen holds your apps, and App Library holds every app. Control Center and Notification Center open with a three-finger swipe down from the status bar at the top. To switch apps, go to the App Switcher."),
                    .heading("5. Make it yours"),
                    .body("Set VoiceOver's voice and speaking rate, choose what's in the rotor, and decide how much it says. iOS 27 adds reading by sentence, hint choices, and detailed image descriptions on devices with Apple Intelligence."),
                    .heading("6. Everyday tasks"),
                    .body("Calls, messages, the camera, Wi-Fi, Bluetooth, and more each have a how-to in Help, with VoiceOver steps first."),
                    .heading("7. When something goes wrong"),
                    .body("If VoiceOver stops talking, or iPhone freezes, Quick Reference has the steps. Ask the Mouse can help in your own words, and the AppleVis community is always happy to help in the Forums."),
                    .note("Written for iOS 27."),
                ],
                contentType: .guide,
                relatedLinks: [
                    RelatedLink(label: "Setting Up with VoiceOver", type: .guide, destination: .article("ref-setup-voiceover")),
                    RelatedLink(label: "VoiceOver Gestures on iPhone and iPad", type: .guide, destination: .article("ref-voiceover-gestures")),
                    RelatedLink(label: "What Are the Buttons on the Sides of My iPhone?", type: .guide, destination: .article("howto-know-side-buttons")),
                    RelatedLink(label: "Everyday iPhone with VoiceOver", type: .guide, destination: .article("ref-iphone-everyday-voiceover")),
                    RelatedLink(label: "How Do I Change How Fast VoiceOver Speaks?", type: .tutorial, destination: .article("howto-vo-speaking-rate")),
                    RelatedLink(label: "How Do I Change What's in the Rotor?", type: .tutorial, destination: .article("howto-vo-rotor-items")),
                    RelatedLink(label: "How Do I Move an App on the Home Screen with VoiceOver?", type: .tutorial, destination: .article("howto-home-move-app")),
                    RelatedLink(label: "VoiceOver Has Gone Silent", type: .troubleshooting, destination: .article("ref-voiceover-silent")),
                ]
            ),
            HelpArticle(
                id: "guide-ipad",
                title: "iPad with VoiceOver: Start Here",
                summary: "What's the same as iPhone, and what's different: windows, the menu bar, and keyboards.",
                content: [
                    .heading("1. The same gestures"),
                    .body("VoiceOver on iPad works like on iPhone: the same gestures, rotor, and settings. If you know one, you know the other."),
                    .heading("2. Turn on VoiceOver"),
                    .body("Triple-click the top button, or the Home button on iPads that have one."),
                    .heading("3. More room"),
                    .body("Apps can show more at once, like a list and the item you chose side by side. Apps can also open in windows, and you can have several open. Set how in Settings > Multitasking & Gestures."),
                    .heading("4. A keyboard makes iPad shine"),
                    .body("With a keyboard, VoiceOver keyboard commands work everywhere. Press Globe-M to open the menu bar, and use the arrow keys to explore an app's menus and their keyboard shortcuts."),
                    .heading("5. In AppleVis"),
                    .body("On iPad, Forums, the App Directory, and the Podcast show the list and the item side by side when there's room. Keyboard shortcuts work too."),
                    .note("Written for iPadOS 27."),
                ],
                contentType: .guide,
                relatedLinks: [
                    RelatedLink(label: "iPhone with VoiceOver: Start Here", type: .guide, destination: .article("guide-iphone")),
                    RelatedLink(label: "How Do I Use iPad's Menu Bar and Windows?", type: .tutorial, destination: .article("howto-ipad-menu")),
                    RelatedLink(label: "VoiceOver Keyboard Commands on iPhone and iPad", type: .guide, destination: .article("ref-voiceover-keyboard-ios")),
                    RelatedLink(label: "AppleVis Keyboard Shortcuts", type: .guide, destination: .article("ref-applevis-keyboard")),
                ]
            ),
            HelpArticle(
                id: "guide-mac",
                title: "Mac with VoiceOver: Start Here",
                summary: "Turning on VoiceOver, the VO keys, getting around, and where to learn more.",
                content: [
                    .heading("1. Turn on VoiceOver"),
                    .body("Press Command-F5. On a Mac with Touch ID, press and hold Command while you quickly press Touch ID three times. During setup, VoiceOver can also start by itself if you wait."),
                    .heading("2. The VO keys"),
                    .body("Most VoiceOver commands use the VO keys, Control and Option held together, plus another key. For example, VO-Right Arrow moves to the next item. You can set Caps Lock as the VO key instead."),
                    .heading("3. Getting around"),
                    .body("The menu bar is at the top of the screen, and the Dock at the bottom. VO-M opens the menu bar, and VO-D the Dock. Command-Tab switches apps, and Command-Space opens Spotlight to find anything."),
                    .heading("4. Interacting"),
                    .body("Groups of items, like a list or a web page, need you to interact with them first: press VO-Shift-Down Arrow to go in, and VO-Shift-Up Arrow to come out."),
                    .heading("5. Learn more"),
                    .body("VoiceOver Utility, opened with VO-F8, holds every VoiceOver setting. The trackpad also works with VoiceOver gestures."),
                    .note("Written for macOS 27."),
                ],
                contentType: .guide,
                relatedLinks: [
                    RelatedLink(label: "Mac Essentials", type: .guide, destination: .article("ref-mac-essentials")),
                    RelatedLink(label: "VoiceOver Keyboard Commands on Mac", type: .guide, destination: .article("ref-voiceover-keyboard-mac")),
                    RelatedLink(label: "VoiceOver Trackpad Gestures on Mac", type: .guide, destination: .article("ref-voiceover-trackpad-mac")),
                    RelatedLink(label: "Braille Display Commands on Mac", type: .guide, destination: .article("ref-braille-display-mac")),
                    RelatedLink(label: "How Do I Use Magnifier on a Mac?", type: .tutorial, destination: .article("howto-mac-magnifier")),
                ]
            ),
            HelpArticle(
                id: "guide-watch",
                title: "Apple Watch with VoiceOver: Start Here",
                summary: "Setting up, the buttons, and the gestures on a small screen.",
                content: [
                    .heading("1. Turn on VoiceOver"),
                    .body("During setup, triple-click the Digital Crown. Afterwards, you can also turn it on from the Watch app on iPhone, in Accessibility."),
                    .heading("2. The buttons"),
                    .body("The Digital Crown is the round dial on the right. Turn it to scroll, and press it for the watch face or the Home Screen. The side button below it opens Control Center."),
                    .heading("3. Gestures"),
                    .body("Many iPhone gestures work: touch to explore, swipe left and right to move, and double-tap to activate. Tap with two fingers to pause speech, and scrub to go back."),
                    .note("Written for watchOS 27."),
                ],
                contentType: .guide,
                relatedLinks: [
                    RelatedLink(label: "How Do I Turn On VoiceOver on Apple Watch?", type: .tutorial, destination: .article("howto-watch-voiceover")),
                    RelatedLink(label: "What Are the Buttons on My Apple Watch?", type: .guide, destination: .article("howto-know-watch")),
                    RelatedLink(label: "VoiceOver on Apple Watch", type: .guide, destination: .article("ref-voiceover-watch")),
                ]
            ),
            HelpArticle(
                id: "guide-tv",
                title: "Apple TV with VoiceOver: Start Here",
                summary: "Setting up, the remote, and moving around the screen.",
                content: [
                    .heading("1. Turn on VoiceOver"),
                    .body("During setup, triple-press the Back button on the remote, or the Menu button on older remotes."),
                    .heading("2. The remote"),
                    .body("The clickpad at the top moves around and selects. Back goes back, and the TV button goes to the Home Screen. Siri is on the side."),
                    .heading("3. Moving around"),
                    .body("Swipe or press the edges of the clickpad to move between items. VoiceOver speaks each one. The rotor and exploration mode help on busy screens."),
                    .heading("4. Set up with iPhone"),
                    .body("During setup, you can hold your iPhone near the Apple TV to send your Wi-Fi and Apple Account settings across, so there's less to type."),
                    .note("Written for tvOS 27."),
                ],
                contentType: .guide,
                relatedLinks: [
                    RelatedLink(label: "How Do I Turn On VoiceOver on Apple TV?", type: .tutorial, destination: .article("howto-tv-voiceover")),
                    RelatedLink(label: "What Are the Buttons on My Apple TV Remote?", type: .guide, destination: .article("howto-know-tv-remote")),
                    RelatedLink(label: "VoiceOver on Apple TV", type: .guide, destination: .article("ref-voiceover-tv")),
                ]
            ),
        ]
    )
}
