import Foundation

/// How-To Library: VoiceOver on iPhone and iPad (2026-10-08). Written in
/// AppleVis's own words for iOS 27, with every Settings path checked against
/// Apple and AppleVis sources. Help is translated while the app runs, so
/// these strings aren't in the string catalog. Ask the Mouse searches them
/// like any other Help article.
extension HelpContent {
    static let howToVoiceOver = HelpSection(
        id: "howto-voiceover",
        title: "How To: VoiceOver",
        icon: "speaker.wave.2",
        description: "Speech, voices, the rotor, gestures, hints, reading by sentence, image descriptions, and other VoiceOver settings on iPhone and iPad.",
        articles: [
            HelpArticle(
                id: "howto-vo-speaking-rate",
                title: "How Do I Change How Fast VoiceOver Speaks?",
                summary: "Speed VoiceOver up or slow it down, in Settings or with the rotor.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Find Speaking Rate.",
                        "Swipe up to speed it up, or down to slow it down.",
                    ]),
                    .tip("For a quick change anywhere, set the rotor to Speaking Rate, then swipe up or down. If Speaking Rate isn't in your rotor, add it in Settings > Accessibility > VoiceOver > Rotor > Rotor Items."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Change What's in the Rotor?", type: .tutorial, destination: .article("howto-vo-rotor-items"))]
            ),
            HelpArticle(
                id: "howto-vo-voice",
                title: "How Do I Change VoiceOver's Voice?",
                summary: "Pick a different voice, download a higher-quality one, or use one of the older Siri voices.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Speech.",
                        "Choose Voice.",
                        "Choose a voice to hear a sample. Some voices come in Enhanced or Premium quality, which download first.",
                        "Double-tap the voice you want to use.",
                    ]),
                    .body("In iOS 27, some of the older Siri voices are also available for VoiceOver."),
                    .note("Enhanced and Premium voices take up storage. You can delete one you don't use from the same list."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-languages",
                title: "How Do I Switch VoiceOver Between Languages?",
                summary: "Add a second language or voice, then switch with the rotor.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Speech.",
                        "Under Rotor Languages, choose Add New Language.",
                        "Choose the language, then the voice you want for it.",
                    ]),
                    .body("Now set the rotor to Languages and swipe up or down to switch."),
                    .tip("You can add the same language twice with different voices, so the rotor switches between voices too."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-rotor-items",
                title: "How Do I Change What's in the Rotor?",
                summary: "Add or remove rotor settings, and change their order.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Rotor, then Rotor Items.",
                        "Double-tap an item to add it to the rotor or take it out. Items in the rotor are selected.",
                        "To change the order, swipe right from an item to its Reorder button. Swipe up or down to choose Move Up or Move Down, then double-tap.",
                    ]),
                    .tip("Another way to reorder: double-tap and hold the Reorder button, wait for the sound, then drag up or down."),
                    .body("In iOS 27, Image Recognition is a rotor item too. You can choose which of its options appear in Settings > Accessibility > VoiceOver > Rotor > Image Recognition Rotor."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Get a Detailed Description of an Image?", type: .tutorial, destination: .article("howto-vo-image-explorer"))]
            ),
            HelpArticle(
                id: "howto-vo-gestures",
                title: "How Do I Change or Add a VoiceOver Gesture?",
                summary: "Give a gesture a different job, or add one for something you use often.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Commands, then Touch Gestures.",
                        "Choose the gesture you want to change.",
                        "Choose what it should do.",
                    ]),
                    .body("Commands also has Keyboard Commands for a hardware keyboard, and Handwriting and Braille Screen Input gestures."),
                    .tip("To start again, Commands has Reset VoiceOver Commands."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "VoiceOver Gestures on iPhone and iPad", type: .guide, destination: .article("ref-voiceover-gestures"))]
            ),
            HelpArticle(
                id: "howto-vo-no-modifier",
                title: "How Do I Use the Function Keys Without the VoiceOver Keys?",
                summary: "With a hardware keyboard in iOS 27, press F8 alone instead of the VoiceOver keys and F8.",
                content: [
                    .body("In iOS 27, VoiceOver commands that use the function keys on the top row of a keyboard can work without the VoiceOver modifier keys."),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Commands.",
                        "Turn on No Modifier Keys.",
                    ]),
                    .body("For example, F8 alone then opens the VoiceOver settings menu."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-hints",
                title: "How Do I Change or Turn Off VoiceOver Hints?",
                summary: "Choose all hints, app hints only, or none, and how long VoiceOver waits before a hint.",
                content: [
                    .body("Hints are the extra instructions VoiceOver says after an item, such as \"Double-tap to open.\""),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Verbosity, then Hints.",
                        "Choose all hints, only hints that apps provide, or no hints.",
                        "To change how long VoiceOver waits before a hint, type a time between 0.05 and 2 seconds, or use Decrement and Increment. It starts at 0.8 seconds.",
                    ]),
                    .note("The choice of hints and the wait are new in iOS 27. Earlier versions only had a Speak Hints switch."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-verbosity",
                title: "How Do I Change How Much VoiceOver Says?",
                summary: "Punctuation, capital letters, links, and other details VoiceOver reads.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Verbosity.",
                    ]),
                    .bullets([
                        "Punctuation: choose All, Some, or None.",
                        "Capital Letters, Deleting Text, Links, and Table Headers: choose whether VoiceOver speaks them, plays a sound, or changes pitch.",
                        "Hints: see How Do I Change or Turn Off VoiceOver Hints?",
                    ]),
                    .tip("Punctuation is also a rotor item, so you can change it while reading."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Change or Turn Off VoiceOver Hints?", type: .tutorial, destination: .article("howto-vo-hints"))]
            ),
            HelpArticle(
                id: "howto-vo-text-exploration",
                title: "How Do I Make VoiceOver Read Only the Sentence or Line Under My Finger?",
                summary: "Text Exploration, new in iOS 27, for reading by touch.",
                content: [
                    .body("When you move your finger around the screen, VoiceOver normally reads the whole item under it. Text Exploration can make it read just the paragraph, line, or sentence instead."),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Text Exploration.",
                        "Choose Paragraph, Line, or Sentence.",
                    ]),
                    .note("This only changes reading by touch. To change what swiping does, see How Do I Make VoiceOver Move by Sentence When I Swipe?"),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Make VoiceOver Move by Sentence When I Swipe?", type: .tutorial, destination: .article("howto-vo-text-navigation"))]
            ),
            HelpArticle(
                id: "howto-vo-text-navigation",
                title: "How Do I Make VoiceOver Move by Sentence When I Swipe?",
                summary: "Text Navigation, new in iOS 27, for swiping through long text.",
                content: [
                    .body("When you swipe left or right, VoiceOver normally moves one item at a time. A long block of text can be a single item. Text Navigation lets swiping move by line, sentence, or paragraph instead."),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Text Navigation.",
                        "Choose Line, Sentence, Paragraph, or Element. Element is how swiping always worked.",
                    ]),
                    .note("Text Navigation and Text Exploration are separate settings, so set each the way you like."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Make VoiceOver Read Only the Sentence or Line Under My Finger?", type: .tutorial, destination: .article("howto-vo-text-exploration"))]
            ),
            HelpArticle(
                id: "howto-vo-pronunciations",
                title: "How Do I Fix How VoiceOver Pronounces a Word, or Share My Fixes?",
                summary: "Pronunciations, and in iOS 27, importing and sharing them.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Speech, then Pronunciations.",
                        "Choose Add, type the word as it's written, then how it should sound. You can also dictate it.",
                    ]),
                    .heading("Share or import pronunciations"),
                    .body("In iOS 27, the same screen can share your pronunciations as a file, or import a file someone has shared with you. Import opens Files so you can choose the file. Share opens the Share Sheet."),
                    .tip("Handy for names or local words. One person can build the list and share it with others."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-cursor-visibility",
                title: "How Do I Hide the VoiceOver Cursor?",
                summary: "Cursor Visibility, new in iOS 27: always show it, hide it, or hide it while sharing your screen.",
                content: [
                    .body("The VoiceOver cursor is the black outline around the item VoiceOver is on. It helps sighted helpers and low vision users follow along, but it can get in the way, for example when you show someone text you've typed."),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Cursor Visibility.",
                        "Choose to show the cursor, always hide it, or hide it only while you share your screen.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-image-explorer",
                title: "How Do I Get a Detailed Description of an Image or the Screen?",
                summary: "Image Recognition in iOS 27: describe, explore, and ask questions about images and the screen.",
                content: [
                    .body("iOS 27 can describe almost any image VoiceOver lands on, in detail, usually in under three seconds. It needs a device with Apple Intelligence."),
                    .steps([
                        "Move VoiceOver to an image.",
                        "Set the rotor to Image Recognition.",
                        "Swipe up or down to choose an option, then double-tap.",
                    ]),
                    .bullets([
                        "Image or Item Description: VoiceOver says a description of the image.",
                        "Ask About Image or Item: type a question, such as \"What does the text say?\", then press Return.",
                        "Explore Image or Item: the description as text you can read at your own pace and copy, with a place to ask a question.",
                        "Describe Screen, Explore Screen, and Ask About Screen: the same, for the whole screen. Useful for buttons with no label.",
                    ]),
                    .tip("In Photos, Save Intelligent Image Description adds the description to the photo, so it's there next time."),
                    .note("If Image Recognition isn't in your rotor, add it in Settings > Accessibility > VoiceOver > Rotor > Rotor Items. Choose which options it offers in Rotor > Image Recognition Rotor."),
                    .note("With a braille display, Image or Item Description can have its own braille command. Press Space with N to read the description at your own pace, and again to go back. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [
                    RelatedLink(label: "Apple Intelligence Features", type: .guide, destination: .article("smart-apple-intelligence")),
                    RelatedLink(label: "How Do I Ask Questions About What the Camera Sees?", type: .tutorial, destination: .article("howto-vo-live-recognition")),
                ]
            ),
            HelpArticle(
                id: "howto-vo-live-recognition",
                title: "How Do I Ask Questions About What the Camera Sees?",
                summary: "Live Recognition and Ask in iOS 27, including from the Action button.",
                content: [
                    .body("Live Recognition describes what's in front of the camera. In iOS 27, with Apple Intelligence, its Ask button lets you ask about what the camera sees. You can also have it watch for one thing and tell you when it moves."),
                    .heading("Set it up"),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Live Recognition.",
                        "Choose the question Ask starts with, whether you ask by dictation or typing, and whether the volume buttons take a photo for a closer look.",
                    ]),
                    .heading("Start Ask from the Action button"),
                    .steps([
                        "Open Settings, then Action Button.",
                        "Choose the Accessibility category.",
                        "Choose Ask a Question.",
                    ]),
                    .body("You can also start Ask with a VoiceOver gesture, a keyboard command, the Accessibility Shortcut, or a braille command."),
                    .note("Needs a device with Apple Intelligence and an Action button for that part. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Change or Add a VoiceOver Gesture?", type: .tutorial, destination: .article("howto-vo-gestures"))]
            ),
            HelpArticle(
                id: "howto-vo-auto-descriptions",
                title: "How Do I Turn Automatic Image Descriptions On or Off?",
                summary: "The short descriptions VoiceOver adds to images on its own.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose VoiceOver Recognition, then Image Descriptions.",
                        "Choose whether VoiceOver describes images on its own, and whether it does so even when an image already has a text description from the app.",
                    ]),
                    .note("These are the shorter descriptions every supported device gets. The detailed ones come from Image Recognition. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Get a Detailed Description of an Image or the Screen?", type: .tutorial, destination: .article("howto-vo-image-explorer"))]
            ),
            HelpArticle(
                id: "howto-vo-screen-curtain",
                title: "How Do I Turn Screen Curtain On or Off?",
                summary: "Turn the display off for privacy while VoiceOver keeps working.",
                content: [
                    .body("Screen Curtain makes the screen dark, so no one can see it, while everything keeps working. It can also save some battery."),
                    .steps([
                        "With VoiceOver on, triple-tap the screen with three fingers.",
                        "Do it again to turn Screen Curtain off.",
                    ]),
                    .tip("Screen Curtain is also in VoiceOver Quick Settings."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Use VoiceOver Quick Settings?", type: .tutorial, destination: .article("howto-vo-quick-settings"))]
            ),
            HelpArticle(
                id: "howto-vo-quick-settings",
                title: "How Do I Use VoiceOver Quick Settings?",
                summary: "A menu of VoiceOver settings you can change from anywhere.",
                content: [
                    .steps([
                        "Tap the screen four times with two fingers.",
                        "Swipe through the settings, and swipe up or down to change one.",
                        "Scrub to close it: move two fingers back and forth quickly, in a Z shape.",
                    ]),
                    .body("To choose what's in Quick Settings, open Settings > Accessibility > VoiceOver > Quick Settings."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-audio-ducking",
                title: "How Do I Stop Music Getting Quieter When VoiceOver Speaks?",
                summary: "Audio Ducking lowers other sound while VoiceOver talks.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Audio.",
                        "Turn Audio Ducking on or off.",
                    ]),
                    .tip("Audio Ducking is also a rotor item, so you can change it while music plays."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-typing-style",
                title: "How Do I Change How I Type with VoiceOver?",
                summary: "Standard, Touch, and Direct Touch typing.",
                content: [
                    .bullets([
                        "Standard Typing: move to a key, then double-tap it, or tap it with a second finger.",
                        "Touch Typing: slide your finger to a key, then lift to type it.",
                        "Direct Touch Typing: keys type straight away, as they do without VoiceOver.",
                    ]),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Typing, then Typing Style.",
                        "Choose the style you want.",
                    ]),
                    .tip("Typing Mode is also a rotor item while the keyboard is on screen."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Typing with VoiceOver", type: .guide, destination: .article("ref-typing-voiceover"))]
            ),
            HelpArticle(
                id: "howto-vo-label",
                title: "How Do I Label a Button That VoiceOver Can't Read?",
                summary: "Give an unlabelled button a name of your own.",
                content: [
                    .steps([
                        "Move VoiceOver to the button.",
                        "Double-tap with two fingers and hold.",
                        "Type a name for it, then choose Save.",
                    ]),
                    .body("VoiceOver uses your label on that button from then on."),
                    .tip("Not sure what the button does? In iOS 27, with Apple Intelligence, Image Recognition can describe or answer questions about the screen."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Get a Detailed Description of an Image or the Screen?", type: .tutorial, destination: .article("howto-vo-image-explorer"))]
            ),
            HelpArticle(
                id: "howto-vo-item-chooser",
                title: "How Do I Find Something on the Screen Quickly?",
                summary: "The Item Chooser lists everything on the screen.",
                content: [
                    .steps([
                        "Triple-tap the screen with two fingers.",
                        "Swipe through the list, or type a few letters to filter it.",
                        "Double-tap an item to move straight to it.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-copy-speech",
                title: "How Do I Copy What VoiceOver Just Said?",
                summary: "Copy the last thing VoiceOver spoke, to paste somewhere else.",
                content: [
                    .steps([
                        "Tap the screen four times with three fingers.",
                        "VoiceOver copies what it last said.",
                        "Paste it wherever you like.",
                    ]),
                    .tip("Earlier things VoiceOver said are in the Copied Speech rotor item, if you add it to the rotor."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-activities",
                title: "How Do I Use Different VoiceOver Settings in Different Apps?",
                summary: "Activities switch voice, rate, and more for an app or task.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Activities, then Add Activity.",
                        "Name it, then choose the voice, speaking rate, punctuation, and other settings you want.",
                        "Under Apps, choose the apps it switches on for by itself.",
                    ]),
                    .body("You can also switch Activities by hand with the rotor."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
