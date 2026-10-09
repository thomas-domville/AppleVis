import Foundation

/// How-To Library: battery, storage, updates, privacy, security, and other
/// devices (2026-10-08). Written for iOS 27 in AppleVis's own words. Help
/// is translated while the app runs.
extension HelpContent {
    static let howToDevice = HelpSection(
        id: "howto-device",
        title: "How To: Battery, Privacy, and Other Devices",
        icon: "battery.75percent",
        description: "Battery, storage, updates, backups, passcodes, Stolen Device Protection, privacy, passwords, Find My, AirPods, Apple Watch, Apple TV, iPad, and Mac.",
        articles: [
            HelpArticle(
                id: "howto-battery-usage",
                title: "How Do I See What's Using My Battery?",
                summary: "Battery usage by app, and battery health.",
                content: [
                    .steps([
                        "Open Settings, then Battery.",
                        "Swipe down to the usage chart and the list of apps, for the last 24 hours or 10 days.",
                        "Choose Battery Health to see its maximum capacity.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-low-power",
                title: "How Do I Make My Battery Last Longer?",
                summary: "Low Power Mode, and charging habits.",
                content: [
                    .bullets([
                        "Turn on Low Power Mode in Settings > Battery, or from Control Center. It pauses some background activity until you charge.",
                        "VoiceOver's Screen Curtain turns the display off while you use iPhone.",
                        "On iPhone 15 and later, Settings > Battery > Charging can stop charging at a limit, such as 80%, to keep the battery healthy.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Turn Screen Curtain On or Off?", type: .tutorial, destination: .article("howto-vo-screen-curtain"))]
            ),
            HelpArticle(
                id: "howto-storage",
                title: "How Do I Free Up Storage?",
                summary: "See what's using space, and clear some.",
                content: [
                    .steps([
                        "Open Settings, then General, then iPhone Storage.",
                        "Wait while it works out what's using space.",
                        "Follow the suggestions, or choose an app to offload or delete it, or delete its downloaded content.",
                    ]),
                    .tip("In AppleVis, downloaded podcast episodes can be removed in For You > Downloads, and Settings > Storage & Cache clears the app's saved content."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Offload an App?", type: .tutorial, destination: .article("howto-home-offload"))]
            ),
            HelpArticle(
                id: "howto-update-ios",
                title: "How Do I Update iOS?",
                summary: "Install the latest version, and turn on automatic updates.",
                content: [
                    .steps([
                        "Open Settings, then General, then Software Update.",
                        "If an update is listed, choose Update Now, and enter your passcode.",
                        "Choose Automatic Updates to have iPhone install updates by itself overnight.",
                    ]),
                    .note("Keep iPhone charging and on Wi-Fi during the update. VoiceOver turns off for a short time while iPhone restarts. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Updating Your Devices", type: .guide, destination: .article("ref-updating"))]
            ),
            HelpArticle(
                id: "howto-backup",
                title: "How Do I Back Up My iPhone?",
                summary: "iCloud Backup, or a computer.",
                content: [
                    .steps([
                        "Open Settings, then your name at the top, then iCloud.",
                        "Choose iCloud Backup, and turn on Back Up This iPhone.",
                        "Choose Back Up Now for one straight away.",
                    ]),
                    .body("iPhone backs up by itself when it's locked, charging, and on Wi-Fi. You can also back up to a Mac in the Finder, or to a Windows PC with the Apple Devices app."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-new-iphone",
                title: "How Do I Move to a New iPhone?",
                summary: "Quick Start copies everything from your old iPhone.",
                content: [
                    .steps([
                        "Turn on the new iPhone, and place it next to your old one.",
                        "On the new iPhone, turn on VoiceOver straight away with a triple-click of the side button.",
                        "On your old iPhone, choose Continue when Quick Start appears, and follow the steps.",
                    ]),
                    .body("Your apps, settings, and data move across. Keep both iPhones close together, and charging, until it's done."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Setting Up with VoiceOver", type: .guide, destination: .article("ref-setup-voiceover"))]
            ),
            HelpArticle(
                id: "howto-passcode",
                title: "How Do I Change My Passcode or Set Up Face ID?",
                summary: "Face ID or Touch ID, and your passcode.",
                content: [
                    .steps([
                        "Open Settings, then Face ID & Passcode. On iPhones with a Home button, it's Touch ID & Passcode.",
                        "Enter your passcode.",
                        "Choose Set Up Face ID, or Change Passcode.",
                    ]),
                    .tip("For Face ID with VoiceOver, turn off Require Attention for Face ID on the same screen if Face ID struggles to recognize you."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-stolen-device",
                title: "How Do I Turn On Stolen Device Protection?",
                summary: "Extra security if someone learns your passcode and takes your iPhone.",
                content: [
                    .steps([
                        "Open Settings, then Face ID & Passcode, and enter your passcode.",
                        "Turn on Stolen Device Protection.",
                    ]),
                    .body("Away from familiar places, some changes, such as your Apple Account password, then need Face ID or Touch ID and a short wait."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-permissions",
                title: "How Do I See Which Apps Use My Location, Camera, or Microphone?",
                summary: "Check and change app permissions.",
                content: [
                    .steps([
                        "Open Settings, then Privacy & Security.",
                        "Choose Location Services, Camera, Microphone, or another item.",
                        "Each app with access is listed. Change or turn off its access.",
                    ]),
                    .tip("Turn on Ask Apps Not to Track in Privacy & Security > Tracking, to stop apps tracking you across other apps and websites."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-passwords",
                title: "How Do I Use the Passwords App?",
                summary: "Saved passwords, passkeys, Wi-Fi passwords, and verification codes.",
                content: [
                    .steps([
                        "Open the Passwords app, and let iPhone check it's you.",
                        "Choose All to see your saved accounts, or search.",
                        "Choose an account to see or copy its password.",
                    ]),
                    .body("When you sign in to an app or website, iPhone offers to fill in a saved password or use a passkey. It can also suggest a strong password when you sign up."),
                    .heading("Passkeys"),
                    .body("A passkey signs you in with Face ID, Touch ID, or your passcode instead of a password. When a site or app offers to create one, accept, and it's saved in Passwords. Next time, choose the passkey when you sign in."),
                    .heading("Verification codes"),
                    .body("When a code arrives by text message or email, it's offered above the keyboard, in the suggestions. With VoiceOver, move to the suggestions and double-tap the code to fill it in."),
                    .body("To delete code messages once they're used, open Settings, then General, then AutoFill & Passwords, and turn on Delete After Use."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-find-my",
                title: "How Do I Find a Lost iPhone, AirPods, or Other Device?",
                summary: "Find My, and playing a sound to find it nearby.",
                content: [
                    .steps([
                        "Open the Find My app. On someone else's device, use icloud.com/find.",
                        "Choose Devices, then the device.",
                        "Choose Play Sound to find it nearby, or Directions for its location.",
                        "If it's lost, choose Mark As Lost to lock it and show a message.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-two-factor",
                title: "How Do I Check Two-Factor Authentication on My Apple Account?",
                summary: "A second check when you sign in somewhere new.",
                content: [
                    .steps([
                        "Open Settings, then your name, then Sign-In & Security.",
                        "Check that Two-Factor Authentication is on.",
                        "Add a trusted phone number, so you can always get a code.",
                    ]),
                    .note("Most Apple Accounts have this on already. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-apple-account-sign-out",
                title: "How Do I Sign Out of My Apple Account?",
                summary: "Before you sell or give away your iPhone, or to use a different Apple Account.",
                content: [
                    .steps([
                        "Open Settings, then your name at the top.",
                        "Swipe to the bottom, and choose Sign Out.",
                        "Enter your Apple Account password to turn off Find My.",
                        "Choose what to keep a copy of on this iPhone, then Sign Out.",
                    ]),
                    .warning("Signing out turns off iCloud on this iPhone. Anything not backed up or synced may be removed from it."),
                    .note("To sign out of the AppleVis app instead, see How Do I Sign Out of AppleVis? Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Sign Out of AppleVis?", type: .tutorial, destination: .article("howto-av-sign-out"))]
            ),
            HelpArticle(
                id: "howto-airpods-controls",
                title: "How Do I Change What My AirPods Do When I Press Them?",
                summary: "Press and hold, noise control, and Conversation Awareness.",
                content: [
                    .steps([
                        "Put your AirPods in your ears, connected to iPhone.",
                        "Open Settings, then your AirPods' name near the top.",
                        "Under Press and Hold AirPods, choose Left or Right, then what pressing and holding does, such as Noise Control or Siri.",
                    ]),
                    .body("Noise Control switches between Noise Cancellation, Transparency, and Adaptive. You can also change it in Control Center by double-tapping and holding the volume control."),
                    .note("Options depend on your AirPods model. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-watch-voiceover",
                title: "How Do I Turn On VoiceOver on Apple Watch?",
                summary: "During setup, or afterwards.",
                content: [
                    .bullets([
                        "During setup: on the watch, triple-click the Digital Crown.",
                        "On iPhone: open the Watch app, then Accessibility, then VoiceOver.",
                        "On the watch: ask Siri to turn on VoiceOver, or open Settings, then Accessibility, then VoiceOver.",
                    ]),
                    .tip("Set the Accessibility Shortcut on the watch to VoiceOver, so a triple-click of the Digital Crown turns it on and off."),
                    .note("Written for watchOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "VoiceOver on Apple Watch", type: .guide, destination: .article("ref-voiceover-watch"))]
            ),
            HelpArticle(
                id: "howto-tv-voiceover",
                title: "How Do I Turn On VoiceOver on Apple TV?",
                summary: "During setup, or afterwards.",
                content: [
                    .bullets([
                        "During setup: triple-press the Back button, or the Menu button on older remotes.",
                        "Afterwards: open Settings, then Accessibility, then VoiceOver.",
                        "Or set the Accessibility Shortcut, in the same place, so a triple-press of Back turns VoiceOver on and off.",
                    ]),
                    .note("Written for tvOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "VoiceOver on Apple TV", type: .guide, destination: .article("ref-voiceover-tv"))]
            ),
            HelpArticle(
                id: "howto-ipad-menu",
                title: "How Do I Use iPad's Menu Bar and Windows?",
                summary: "Menus, windows, and multitasking on iPad.",
                content: [
                    .bullets([
                        "With a keyboard, press Globe-M to open the menu bar, then use the arrow keys.",
                        "To see an app's keyboard shortcuts, open its menus.",
                        "Windows: apps can open in resizable windows. Set how in Settings > Multitasking & Gestures.",
                    ]),
                    .body("In AppleVis on iPad, Forums, the App Directory, and the Podcast show the list and the item side by side when there's room."),
                    .note("Written for iPadOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "AppleVis Keyboard Shortcuts", type: .guide, destination: .article("ref-applevis-keyboard"))]
            ),
            HelpArticle(
                id: "howto-mac-magnifier",
                title: "How Do I Use Magnifier on a Mac?",
                summary: "Use iPhone or a USB camera to magnify things around you on your Mac.",
                content: [
                    .steps([
                        "On the Mac, open the Magnifier app, in Applications > Utilities.",
                        "Choose a camera: your iPhone, through Continuity Camera, or a connected USB camera.",
                        "Point the camera at what you'd like to see, such as a whiteboard or a document, and zoom in.",
                    ]),
                    .note("Needs macOS 26 or later. Written for macOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Mac Essentials", type: .guide, destination: .article("ref-mac-essentials"))]
            ),
        ]
    )
}
