import Foundation

/// How-To Library: the Home Screen and apps (2026-10-08). Written for iOS 27
/// in AppleVis's own words, VoiceOver first. The Actions rotor steps are
/// checked against Perkins School for the Blind and AppleVis guides and bug
/// reports. Help is translated while the app runs.
extension HelpContent {
    static let howToHomeScreen = HelpSection(
        id: "howto-home-screen",
        title: "How To: Home Screen and Apps",
        icon: "square.grid.3x3",
        description: "Moving apps, folders, locking and hiding apps, deleting, pages, widgets, icons, Control Center, and the Action button.",
        articles: [
            HelpArticle(
                id: "howto-home-move-app",
                title: "How Do I Move an App on the Home Screen with VoiceOver?",
                summary: "Drag and drop with the Actions rotor.",
                content: [
                    .steps([
                        "On the Home Screen, move VoiceOver to the app you want to move.",
                        "Set the rotor to Actions. Swipe down to Drag, then double-tap. VoiceOver says the app is being dragged.",
                        "Move to the app you want it next to. You can go to another page with a three-finger swipe.",
                        "Swipe down through the actions to Drop Before or Drop After, then double-tap.",
                    ]),
                    .tip("Another way: double-tap and hold the app until VoiceOver says the Home Screen is being edited. Keep your finger down and slide the app to its new place, then lift."),
                    .note("If an app ends up in a folder instead of beside the app you chose, drag it out again. See How Do I Take an App Out of a Folder? Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Make a Folder?", type: .tutorial, destination: .article("howto-home-make-folder"))]
            ),
            HelpArticle(
                id: "howto-home-make-folder",
                title: "How Do I Make a Folder?",
                summary: "Put two apps together to make a folder.",
                content: [
                    .steps([
                        "Move VoiceOver to one of the apps.",
                        "Set the rotor to Actions. Swipe down to Drag, then double-tap.",
                        "Move to the other app.",
                        "Swipe down to Create New Folder, then double-tap.",
                    ]),
                    .body("iPhone names the folder for you, such as Utilities. To add more apps, drag each one and choose Add to Folder on the folder."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Rename a Folder?", type: .tutorial, destination: .article("howto-home-rename-folder"))]
            ),
            HelpArticle(
                id: "howto-home-rename-folder",
                title: "How Do I Rename a Folder?",
                summary: "Give a folder a name of your own.",
                content: [
                    .steps([
                        "Move VoiceOver to the folder.",
                        "Set the rotor to Actions. Swipe down to Edit Mode, then double-tap. The Home Screen is now being edited.",
                        "Double-tap the folder to open it.",
                        "Move to the folder's name at the top. It's now a text field. Double-tap it.",
                        "Delete the old name, type the new one, then choose Done.",
                    ]),
                    .tip("Without VoiceOver, touch and hold the folder, then choose Rename."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-out-of-folder",
                title: "How Do I Take an App Out of a Folder?",
                summary: "Move an app from a folder back to the Home Screen.",
                content: [
                    .steps([
                        "Open the folder.",
                        "Move VoiceOver to the app. Set the rotor to Actions, swipe down to Drag, then double-tap.",
                        "Close the folder by scrubbing: move two fingers back and forth quickly.",
                        "Move to an app on the Home Screen, then choose Drop Before or Drop After.",
                    ]),
                    .body("When a folder has only one app left in it, the folder goes away."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-rename-app",
                title: "Can I Rename an App?",
                summary: "Not directly, but a shortcut can do the job.",
                content: [
                    .body("iPhone doesn't let you change an app's name. You can make a Home Screen shortcut with any name that opens the app instead."),
                    .steps([
                        "Open the Shortcuts app, and choose Add, the plus button.",
                        "Search the actions for Open App, and add it.",
                        "Choose App, then pick the app.",
                        "Choose the shortcut's name at the top, then Add to Home Screen.",
                        "Type the name you want, then choose Add.",
                    ]),
                    .note("The shortcut is a separate icon. You can move the real app to App Library so you don't see both. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Remove an App from the Home Screen Without Deleting It?", type: .tutorial, destination: .article("howto-home-remove"))]
            ),
            HelpArticle(
                id: "howto-home-lock-app",
                title: "How Do I Lock an App with Face ID or Touch ID?",
                summary: "Make an app ask for Face ID, Touch ID, or your passcode before it opens.",
                content: [
                    .steps([
                        "Move VoiceOver to the app.",
                        "Double-tap and hold to open its menu. Or set the rotor to Actions and choose Show Menu.",
                        "Choose Require Face ID, or Require Touch ID.",
                        "Choose it again to confirm, and let iPhone check it's you.",
                    ]),
                    .body("To unlock it, open the same menu and choose Don't Require Face ID."),
                    .note("Content from a locked app, such as messages, doesn't show in Search or notifications. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Hide an App?", type: .tutorial, destination: .article("howto-home-hide-app"))]
            ),
            HelpArticle(
                id: "howto-home-hide-app",
                title: "How Do I Hide an App, and Find It Again?",
                summary: "Hide an app away and lock it in the Hidden folder.",
                content: [
                    .steps([
                        "Open the app's menu: double-tap and hold the app, or use Show Menu in the Actions rotor.",
                        "Choose Require Face ID, then Hide and Require Face ID.",
                        "Confirm. The app leaves the Home Screen.",
                    ]),
                    .heading("Find hidden apps"),
                    .steps([
                        "Go to App Library, past your last Home Screen page. With VoiceOver, swipe left with three fingers until you reach it.",
                        "Move to the bottom, and choose the Hidden folder.",
                        "Let iPhone check it's you. Your hidden apps appear.",
                    ]),
                    .note("Only apps from the App Store can be hidden. Apple's own apps can be locked but not hidden. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-remove",
                title: "How Do I Remove an App from the Home Screen Without Deleting It?",
                summary: "Tidy the Home Screen and keep the app in App Library.",
                content: [
                    .steps([
                        "Open the app's menu: double-tap and hold the app, or use Show Menu in the Actions rotor.",
                        "Choose Remove App.",
                        "Choose Remove from Home Screen.",
                    ]),
                    .body("The app stays in App Library, and you can still find it with Search."),
                    .tip("To put it back, find it in App Library, open its menu, and choose Add to Home Screen."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-delete",
                title: "How Do I Delete an App?",
                summary: "Remove an app and its data from iPhone.",
                content: [
                    .steps([
                        "Open the app's menu: double-tap and hold the app, or use Show Menu in the Actions rotor.",
                        "Choose Remove App.",
                        "Choose Delete App, then Delete.",
                    ]),
                    .body("You can download it again later from the App Store, from your purchases, without paying again."),
                    .tip("To keep the app's data but free up space, offload it instead. See How Do I Offload an App?"),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Offload an App?", type: .tutorial, destination: .article("howto-home-offload"))]
            ),
            HelpArticle(
                id: "howto-home-offload",
                title: "How Do I Offload an App?",
                summary: "Free up space and keep the app's documents and data.",
                content: [
                    .steps([
                        "Open Settings, then General, then iPhone Storage.",
                        "Choose the app.",
                        "Choose Offload App, then confirm.",
                    ]),
                    .body("The app's icon stays. Open it, and it downloads again with your data where you left it."),
                    .tip("To have iPhone do this by itself for apps you don't use, open Settings > Apps > App Store and turn on Offload Unused Apps."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-find-app",
                title: "How Do I Find an App I Can't See?",
                summary: "Search, and App Library.",
                content: [
                    .bullets([
                        "Search: on the Home Screen, swipe down with one finger in the middle of the screen. With VoiceOver, move to the Search button at the bottom of the Home Screen instead. Type the app's name.",
                        "App Library: go past your last Home Screen page. Every app is there, sorted into groups, with a search field at the top.",
                        "Siri: say \"Open\" and the app's name.",
                    ]),
                    .note("If an app is hidden, it's only in the Hidden folder at the bottom of App Library. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-pages",
                title: "How Do I Add, Hide, or Remove a Home Screen Page?",
                summary: "Manage whole pages of apps.",
                content: [
                    .steps([
                        "Start editing the Home Screen: on an app, set the rotor to Actions and choose Edit Mode.",
                        "Move to the page dots near the bottom, then double-tap.",
                        "Each page is listed. Double-tap a page to hide it or show it again.",
                        "To remove a hidden page, choose its Remove button.",
                        "Choose Done.",
                    ]),
                    .body("A new page appears by itself when you drag an app past your last page."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-widget",
                title: "How Do I Add a Widget?",
                summary: "Put a widget, such as Weather or Batteries, on the Home Screen.",
                content: [
                    .steps([
                        "Start editing the Home Screen: on an app, set the rotor to Actions and choose Edit Mode.",
                        "Choose Edit at the top, then Add Widget.",
                        "Choose a widget, then swipe through its sizes.",
                        "Choose Add Widget, then Done.",
                    ]),
                    .tip("To remove a widget, open its menu and choose Remove Widget."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-icons",
                title: "How Do I Change How App Icons Look?",
                summary: "Light, dark, clear, or tinted icons, and bigger icons.",
                content: [
                    .steps([
                        "Start editing the Home Screen.",
                        "Choose Edit at the top, then Customize.",
                        "Choose Default, Dark, Clear, or Tinted. Tinted lets you pick a color.",
                        "Choose Large to make icons bigger without their names.",
                    ]),
                    .tip("For icons that are easier to see, try Dark, and turn on Increase Contrast in Settings > Accessibility > Display & Text Size."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-new-apps",
                title: "How Do I Stop New Apps Going on My Home Screen?",
                summary: "Send newly downloaded apps to App Library only.",
                content: [
                    .steps([
                        "Open Settings, then Home Screen & App Library.",
                        "Under Newly Downloaded Apps, choose App Library Only.",
                    ]),
                    .body("The same screen can show notification badges in App Library, and Search on the Home Screen."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-dock",
                title: "How Do I Change the Apps in the Dock?",
                summary: "The row of apps at the bottom of every Home Screen page.",
                content: [
                    .steps([
                        "Drag an app out of the Dock, and drop it on a Home Screen page, to make room.",
                        "Drag the app you want, and drop it before or after an app in the Dock.",
                    ]),
                    .body("The Dock holds up to four apps on iPhone. A folder can go there too."),
                    .note("See How Do I Move an App on the Home Screen with VoiceOver? for dragging. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Move an App on the Home Screen with VoiceOver?", type: .tutorial, destination: .article("howto-home-move-app"))]
            ),
            HelpArticle(
                id: "howto-home-control-center",
                title: "How Do I Change Control Center?",
                summary: "Add, remove, and rearrange controls.",
                content: [
                    .steps([
                        "Open Control Center. With VoiceOver, move to the status bar at the top of the screen, then swipe down with three fingers.",
                        "Choose Add a Control, near the bottom. Or double-tap and hold an empty area.",
                        "To add a control, choose it from the list.",
                        "To remove one, choose its Remove button.",
                        "To rearrange, drag a control to a new place.",
                    ]),
                    .tip("Controls can go on more than one page. Swipe up or down with three fingers to move between pages."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-home-action-button",
                title: "How Do I Change What the Action Button Does?",
                summary: "On iPhone 15 Pro and later, and iPhone 16 and later.",
                content: [
                    .steps([
                        "Open Settings, then Action Button.",
                        "Swipe left or right through the choices, such as Silent Mode, Flashlight, Camera, Magnifier, Shortcut, or Accessibility.",
                        "Some choices have options below. For example, Accessibility lets you choose VoiceOver, Zoom, or another feature.",
                    ]),
                    .body("In iOS 27, the Accessibility choice includes Ask a Question, for VoiceOver's Live Recognition."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Ask Questions About What the Camera Sees?", type: .tutorial, destination: .article("howto-vo-live-recognition"))]
            ),
            HelpArticle(
                id: "howto-home-lock-screen",
                title: "How Do I Change the Lock Screen Buttons?",
                summary: "Swap the two buttons at the bottom of the Lock Screen, such as the flashlight.",
                content: [
                    .steps([
                        "On the Lock Screen, after Face ID or Touch ID, double-tap and hold the Lock Screen.",
                        "Choose Customize, then Lock Screen.",
                        "Choose the Remove button on a control at the bottom, then the plus button to choose a new one.",
                        "Choose Done.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
