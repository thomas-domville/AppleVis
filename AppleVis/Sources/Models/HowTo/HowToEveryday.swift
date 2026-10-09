import Foundation

/// How-To Library: typing, Siri, Apple Intelligence, Shortcuts, and
/// everyday tasks (2026-10-08). Written for iOS 27 in AppleVis's own words.
/// Help is translated while the app runs.
extension HelpContent {
    static let howToEveryday = HelpSection(
        id: "howto-everyday",
        title: "How To: Typing, Siri, and Everyday Tasks",
        icon: "keyboard",
        description: "Keyboards, autocorrect, text replacement, dictation, Siri, Writing Tools, Shortcuts, screenshots, alarms, scanning, the camera, Apple Pay, and Screen Time.",
        articles: [
            HelpArticle(
                id: "howto-keyboard-language",
                title: "How Do I Add a Keyboard Language?",
                summary: "Type in more than one language, or add an emoji keyboard.",
                content: [
                    .steps([
                        "Open Settings, then General, then Keyboard.",
                        "Choose Keyboards, then Add New Keyboard.",
                        "Choose the language.",
                    ]),
                    .body("To switch while typing, choose the Next Keyboard button, the globe, at the bottom of the keyboard."),
                    .heading("Emoji"),
                    .body("The emoji keyboard is usually there already. To type an emoji, choose the Emoji button, or Next Keyboard until you hear Emoji. Search Emoji at the top finds one by name. With VoiceOver, the categories are at the bottom: choose one, then swipe through its emoji and double-tap the one you want."),
                    .tip("With Dictation, say the emoji's name followed by emoji, such as \"smiley emoji\"."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-autocorrect",
                title: "How Do I Turn Autocorrect or Predictive Text On or Off?",
                summary: "Keyboard suggestions and corrections.",
                content: [
                    .steps([
                        "Open Settings, then General, then Keyboard.",
                        "Turn Auto-Correction, Predictive Text, or Auto-Capitalization on or off.",
                    ]),
                    .note("Braille Screen Input's word predictions in iOS 27 need Auto-Correction on. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Type with Braille Screen Input?", type: .tutorial, destination: .article("howto-braille-screen-input"))]
            ),
            HelpArticle(
                id: "howto-text-replacement",
                title: "How Do I Make a Text Shortcut That Types a Phrase?",
                summary: "Type a few letters, and get your email address or a whole sentence.",
                content: [
                    .steps([
                        "Open Settings, then General, then Keyboard, then Text Replacement.",
                        "Choose Add, the plus button.",
                        "Type the Phrase, such as your email address, and a short Shortcut, such as \"eml\".",
                        "Choose Save.",
                    ]),
                    .body("Now type the shortcut and a space, and the phrase replaces it. Text replacements sync to your other devices with iCloud."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-dictation",
                title: "How Do I Dictate Text?",
                summary: "Speak instead of typing, with punctuation.",
                content: [
                    .steps([
                        "In a text field, choose the Dictate button, the microphone, on the keyboard. With VoiceOver, you can also double-tap with two fingers to start and stop.",
                        "Speak. Say punctuation, like \"comma\", \"period\", or \"new line\".",
                        "Stop when you're done.",
                    ]),
                    .tip("If the microphone isn't there, turn on Enable Dictation in Settings > General > Keyboard."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-hardware-keyboard",
                title: "How Do I Use a Keyboard with iPhone?",
                summary: "Pair a keyboard, and control everything with Full Keyboard Access.",
                content: [
                    .steps([
                        "Pair the keyboard in Settings > Bluetooth, or plug it in.",
                        "With VoiceOver on, VoiceOver keyboard commands work straight away.",
                        "Without VoiceOver, turn on Full Keyboard Access in Settings > Accessibility > Keyboards & Typing to move around with Tab and the arrow keys.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "VoiceOver Keyboard Commands on iPhone and iPad", type: .guide, destination: .article("ref-voiceover-keyboard-ios"))]
            ),
            HelpArticle(
                id: "howto-siri-settings",
                title: "How Do I Change Siri's Voice, or Type to Siri?",
                summary: "Siri's voice and language, and typing instead of speaking.",
                content: [
                    .steps([
                        "Open Settings, then Apple Intelligence & Siri.",
                        "Choose Voice to change how Siri sounds, or Language.",
                        "Choose Talk & Type to Siri, and turn on Type to Siri, to type your requests.",
                    ]),
                    .body("In iOS 27, Siri also has its own app, for longer conversations and questions. You can still ask Siri by pressing and holding the side button."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Siri Phrases", type: .guide, destination: .article("ref-siri-phrases"))]
            ),
            HelpArticle(
                id: "howto-apple-intelligence-on",
                title: "How Do I Turn On Apple Intelligence?",
                summary: "Check your device supports it, and switch it on.",
                content: [
                    .steps([
                        "Open Settings, then Apple Intelligence & Siri.",
                        "Turn on Apple Intelligence. If it isn't there, your iPhone, language, or region doesn't support it yet.",
                        "Wait while it downloads. It needs about 7 GB of free space.",
                    ]),
                    .note("See Apple Intelligence Features for the devices and languages that support it. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Apple Intelligence Features", type: .guide, destination: .article("smart-apple-intelligence"))]
            ),
            HelpArticle(
                id: "howto-writing-tools",
                title: "How Do I Proofread or Rewrite What I've Written?",
                summary: "Writing Tools, with Apple Intelligence.",
                content: [
                    .steps([
                        "Select the text.",
                        "Open the edit menu, and choose Writing Tools.",
                        "Choose Proofread, Rewrite, Friendly, Professional, Concise, or Summary.",
                        "Choose Done to keep the change, or Revert to undo it.",
                    ]),
                    .body("In AppleVis, Rewrite is built into posting and replying."),
                    .note("Needs Apple Intelligence. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-shortcut",
                title: "How Do I Make a Shortcut?",
                summary: "Automate something you do often.",
                content: [
                    .steps([
                        "Open the Shortcuts app, and choose Add, the plus button.",
                        "Search for an action, such as Play Music or Send Message, and add it. Add more actions in order.",
                        "Choose the name at the top to rename it.",
                        "Choose Done. Run it from the Shortcuts app, by asking Siri its name, or from Back Tap or the Action button.",
                    ]),
                    .body("In iOS 27, with Apple Intelligence, you can describe what you'd like the shortcut to do, and Shortcuts builds it for you to check."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-screenshot",
                title: "How Do I Take a Screenshot?",
                summary: "Capture what's on the screen.",
                content: [
                    .bullets([
                        "Press the side button and the volume up button at the same time, then let go.",
                        "On iPhones with a Home button, press the side button and the Home button.",
                        "Or set Back Tap or AssistiveTouch to Screenshot.",
                    ]),
                    .body("Screenshots go to the Photos app. To share one right away, choose its preview, then Share."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Set Up Back Tap?", type: .tutorial, destination: .article("howto-back-tap"))]
            ),
            HelpArticle(
                id: "howto-screen-recording",
                title: "How Do I Record the Screen?",
                summary: "Make a video of what's on screen, with or without sound.",
                content: [
                    .steps([
                        "Add Screen Recording to Control Center, if it isn't there.",
                        "Open Control Center, and choose Screen Recording. Recording starts after a short countdown.",
                        "To stop, choose the red recording indicator at the top, then Stop.",
                    ]),
                    .tip("To record your voice too, double-tap and hold Screen Recording, and turn on the microphone. VoiceOver speech is recorded."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-alarm",
                title: "How Do I Set an Alarm or Timer?",
                summary: "With Siri or the Clock app.",
                content: [
                    .bullets([
                        "Ask Siri: \"Set an alarm for 7 AM\" or \"Set a timer for 10 minutes\".",
                        "Or open Clock, choose Alarms or Timers, then Add or Start.",
                    ]),
                    .note("Alarms and timers sound even in Silent Mode. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-scan-text",
                title: "How Do I Read Printed Text or Scan a Document?",
                summary: "Live Text, Notes scanning, and VoiceOver's text recognition.",
                content: [
                    .bullets([
                        "Notes: in a note, choose the attachment button, then Scan Documents. Hold the page in front of the camera. iPhone scans it when it's in view.",
                        "Camera: point it at text. A Live Text button appears. Choose it to read or copy the text.",
                        "Magnifier: Accessibility Reader inside Magnifier reads printed text aloud.",
                        "VoiceOver: with Text Recognition on, VoiceOver reads text in photos and images.",
                    ]),
                    .tip("In iOS 27, with Apple Intelligence, Image Recognition can describe a scanned bill or document in detail, and answer questions about it."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Get a Detailed Description of an Image or the Screen?", type: .tutorial, destination: .article("howto-vo-image-explorer"))]
            ),
            HelpArticle(
                id: "howto-sign-pdf",
                title: "How Do I Sign a PDF or Form?",
                summary: "Add your signature, or type into a form, with Markup.",
                content: [
                    .steps([
                        "Open the PDF in Files, Mail, or Messages.",
                        "Choose Markup.",
                        "Choose Add, then Signature, and draw your signature with your finger. iPhone saves it for next time.",
                        "Drag the signature into place, then choose Done.",
                    ]),
                    .body("To fill in a form, choose Add, then Text, and type. Many PDF forms also have fields you can type into directly."),
                    .tip("Drawing a signature in the right place is hard without sight. Some people save a signature once with sighted help, then reuse it. Others type their name with Add, then Text, when that's accepted. Members compare apps for signing in the Forums."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-duplicate-contacts",
                title: "How Do I Merge Duplicate Contacts?",
                summary: "Combine contacts that appear more than once.",
                content: [
                    .steps([
                        "Open Contacts.",
                        "If iPhone found duplicates, Duplicates Found appears under your own card at the top. Choose View Duplicates.",
                        "Choose Merge All, or open each one and choose Merge.",
                    ]),
                    .body("iPhone only finds contacts with exactly the same name. To join two cards for the same person with different names, open one, choose Edit, then Link Contacts at the bottom, and choose the other."),
                    .tip("Duplicates often come from the same contacts being in two accounts, such as iCloud and Gmail. Settings, then Apps, then Contacts, then Default Account, chooses where new contacts are saved."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-time-format",
                title: "How Do I Switch Between 12-Hour and 24-Hour Time?",
                summary: "Change how iPhone shows and speaks the time.",
                content: [
                    .steps([
                        "Open Settings, then General, then Date & Time.",
                        "Turn 24-Hour Time on or off.",
                    ]),
                    .body("The same screen sets your time zone, or lets iPhone set it automatically."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-group-chat-name",
                title: "How Do I Name a Group Chat in Messages?",
                summary: "Give a group conversation a name and photo everyone sees.",
                content: [
                    .steps([
                        "Open the group conversation in Messages.",
                        "Choose the group's names or picture at the top of the conversation.",
                        "Choose Edit, then Edit Name & Photo.",
                        "Type a name, choose a photo if you like, then choose Done.",
                    ]),
                    .body("Only groups where everyone uses iMessage can be named. Text message groups with Android phones can't."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Share My Name and Photo in Messages?", type: .tutorial, destination: .article("howto-share-name-photo"))]
            ),
            HelpArticle(
                id: "howto-share-name-photo",
                title: "How Do I Share My Name and Photo in Messages?",
                summary: "Choose the name and picture other people see when you message or call them.",
                content: [
                    .steps([
                        "Open Settings, then Apps, then Messages.",
                        "Choose Share Name and Photo.",
                        "Set your name and photo, then choose whether to share with contacts only, or ask each time.",
                    ]),
                    .body("If a friend sees a number instead of your name, they may need to add you as a contact, or accept your name when Messages offers to update it."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-files-cloud",
                title: "How Do I Use iCloud Drive, Dropbox, or Other Storage in Files?",
                summary: "Find, move, and share files from iCloud Drive and other services.",
                content: [
                    .steps([
                        "Open Files, then choose Browse.",
                        "To add Dropbox, Google Drive, or OneDrive, install its app first. Then in Browse, choose More, then Edit, and turn it on.",
                        "To copy or move a file, open its options with a long press, or the rotor's Actions, then choose Copy or Move.",
                    ]),
                    .heading("Keep a folder the same on Mac and iPhone"),
                    .body("Put it in iCloud Drive. On the Mac, open System Settings, then your Apple Account, then iCloud, then Drive. Turn on Desktop & Documents Folders to keep those two folders in iCloud Drive too."),
                    .note("Written for iOS 27 and macOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-flashlight",
                title: "How Do I Turn the Flashlight On or Off?",
                summary: "Control Center, the Lock Screen, Siri, or the Action button.",
                content: [
                    .bullets([
                        "Siri: say \"Turn on the flashlight\" or \"Turn off the flashlight\".",
                        "Control Center: open it, then choose Flashlight.",
                        "Lock Screen: touch and hold the Flashlight button at the bottom left. With VoiceOver, double-tap and hold it.",
                        "Action button: if you've set it to Flashlight, press and hold it.",
                    ]),
                    .tip("VoiceOver says whether the flashlight is on or off when you move to its button."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-camera-voiceover",
                title: "How Do I Take Photos with VoiceOver?",
                summary: "VoiceOver tells you who and what's in the picture.",
                content: [
                    .steps([
                        "Open Camera. VoiceOver says how many faces it sees, and where.",
                        "Move iPhone until what you want is centered. VoiceOver can describe the scene, depending on your VoiceOver Recognition settings.",
                        "Press a volume button, or choose Take Picture.",
                    ]),
                    .body("Afterwards, in Photos, VoiceOver can describe the photo. With Apple Intelligence in iOS 27, Image Recognition gives a detailed description you can save with the photo."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-apple-pay",
                title: "How Do I Pay with Apple Pay?",
                summary: "Pay in shops with iPhone.",
                content: [
                    .steps([
                        "Add a card in the Wallet app with the Add button.",
                        "At the till, double-press the side button.",
                        "Let iPhone check it's you with Face ID or Touch ID.",
                        "Hold the top of iPhone near the card reader until it confirms.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-shareplay",
                title: "How Do I Share My Screen on a FaceTime Call?",
                summary: "Let someone see your screen, for example to help you.",
                content: [
                    .steps([
                        "During a FaceTime call, choose Share Content, or the SharePlay button.",
                        "Choose Share My Screen.",
                        "To stop, choose the sharing button again.",
                    ]),
                    .tip("In iOS 27, Cursor Visibility can hide the VoiceOver cursor while you share."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Hide the VoiceOver Cursor?", type: .tutorial, destination: .article("howto-vo-cursor-visibility"))]
            ),
            HelpArticle(
                id: "howto-screen-time",
                title: "How Do I Set Up Screen Time?",
                summary: "See how you use iPhone, and set limits, including for a child.",
                content: [
                    .steps([
                        "Open Settings, then Screen Time.",
                        "Turn it on, and choose whether the iPhone is yours or a child's.",
                        "Set up the limits you'd like, such as app limits, downtime, and content restrictions.",
                    ]),
                    .body("Screen Time settings were redesigned in iOS 27, with an overview for parents of how children use their devices."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
