import Foundation

/// How-To Library: vision, hearing, and physical access (2026-10-08).
/// Written for iOS 27 in AppleVis's own words. Settings > Accessibility >
/// Read & Speak was called Spoken Content before iOS 26. Help is
/// translated while the app runs.
extension HelpContent {
    static let howToAccessibility = HelpSection(
        id: "howto-accessibility",
        title: "How To: Vision, Hearing, and Physical Access",
        icon: "accessibility",
        description: "Text size, contrast, the glass design, Zoom, Magnifier, Accessibility Reader, captions, hearing devices, Sound Recognition, AssistiveTouch, Back Tap, Voice Control, and Switch Control.",
        articles: [
            HelpArticle(
                id: "howto-text-size",
                title: "How Do I Make Text Bigger?",
                summary: "Larger text across iPhone, in apps that support it, including AppleVis.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Display & Text Size.",
                        "Choose Larger Text.",
                        "Swipe up on the slider to make text bigger. Turn on Larger Accessibility Sizes for the biggest sizes.",
                    ]),
                    .tip("Add Text Size to Control Center to change it in a moment, even for just one app."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Low Vision Features", type: .guide, destination: .article("ref-low-vision"))]
            ),
            HelpArticle(
                id: "howto-bold-text",
                title: "How Do I Make Text Bold or Show Button Outlines?",
                summary: "Bold Text, Button Shapes, and On/Off Labels.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Display & Text Size.",
                        "Turn on Bold Text.",
                        "Turn on Button Shapes to underline or outline buttons.",
                        "Turn on On/Off Labels to mark switches with a line or circle.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-liquid-glass",
                title: "How Do I Make the Glass Design Easier to See?",
                summary: "The Liquid Glass slider in iOS 27, Reduce Transparency, and Increase Contrast.",
                content: [
                    .heading("Glass Intensity, new in iOS 27"),
                    .steps([
                        "Open Settings, then Display & Brightness.",
                        "Choose Liquid Glass.",
                        "Swipe down on the Glass Intensity slider for a clearer, more solid look. Swipe up for more see-through glass.",
                    ]),
                    .heading("More contrast"),
                    .steps([
                        "Open Settings, then Accessibility, then Display & Text Size.",
                        "Turn on Reduce Transparency to make glass backgrounds solid.",
                        "Turn on Increase Contrast to strengthen edges and colors.",
                    ]),
                    .note("In iOS 26, Liquid Glass had a Clear or Tinted choice instead of a slider. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-zoom",
                title: "How Do I Use Zoom?",
                summary: "Magnify anything on the screen.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Zoom, and turn on Zoom.",
                        "Double-tap with three fingers to zoom in or out.",
                        "Drag three fingers to move around the screen.",
                        "Double-tap with three fingers and hold, then drag up or down, to change how far it zooms.",
                    ]),
                    .body("Zoom Region chooses full screen, a window, or pinned to one side. Show Controller adds a floating button for Zoom's menu."),
                    .tip("Zoom and VoiceOver can work together. VoiceOver's cursor is followed as you move."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-magnifier",
                title: "How Do I Use Magnifier?",
                summary: "Use the camera to read small print and find things around you.",
                content: [
                    .body("Magnifier is an app. Find it in App Library, with Search, or by asking Siri to open Magnifier. You can also add it to Control Center, the Action button, or the Accessibility Shortcut."),
                    .bullets([
                        "Zoom: adjust the Zoom slider.",
                        "Flashlight: turn on the light for dark places.",
                        "Freeze Frame: capture what's in view, so you can zoom in without holding still.",
                        "Filters: change colors, or invert them, for easier reading.",
                        "Detection Mode, on iPhones with LiDAR: find people, doors, and text, and hear descriptions of what's around you.",
                    ]),
                    .body("In iOS 27, Magnifier can also answer spoken questions about what it sees, such as a document, and take voice commands like \"zoom in\" or \"turn on the flashlight\"."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-accessibility-reader",
                title: "How Do I Use Accessibility Reader?",
                summary: "Read any app's text in a clean, adjustable view, and have it read aloud.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Read & Speak.",
                        "Choose Accessibility Reader, and turn it on.",
                        "Add it to the Accessibility Shortcut, Control Center, or the Action button.",
                        "In any app with text, start it the way you chose. The text opens in Accessibility Reader.",
                        "Change the font, size, colors, and spacing, or choose Play to hear it.",
                    ]),
                    .body("In iOS 27, it handles columns, tables, and scientific articles better, and can summarize an article for you."),
                    .note("Accessibility Reader is also built into Magnifier, for printed text. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Change the Accessibility Shortcut?", type: .tutorial, destination: .article("howto-accessibility-shortcut"))]
            ),
            HelpArticle(
                id: "howto-invert-dark",
                title: "How Do I Use Dark Mode or Smart Invert?",
                summary: "Light text on a dark background.",
                content: [
                    .bullets([
                        "Dark Mode: open Settings, then Display & Brightness, and choose Dark. Choose Automatic to switch at sunset.",
                        "Smart Invert: open Settings, then Accessibility, then Display & Text Size, and turn on Smart Invert. It inverts colors but leaves photos and video as they are.",
                        "Classic Invert: inverts everything, including photos.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-color-filters",
                title: "How Do I Make the Screen Grayscale or Use Color Filters?",
                summary: "Color Filters, grayscale, and Reduce White Point.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Display & Text Size.",
                        "Choose Color Filters, and turn them on. Pick grayscale, a filter for a type of color blindness, or a Color Tint.",
                        "Turn on Reduce White Point, and adjust the slider, to tone down bright colors.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-reduce-motion",
                title: "How Do I Reduce Motion and Stop Animations?",
                summary: "Calmer screen changes, and no autoplaying previews.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Motion.",
                        "Turn on Reduce Motion.",
                        "Turn off Auto-Play Animated Images and Auto-Play Video Previews if you'd like them to stay still.",
                    ]),
                    .body("AppleVis follows Reduce Motion too. Its animations turn off."),
                    .tip("Vehicle Motion Cues, on the same screen, can help with motion sickness when reading in a car."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-speak-screen",
                title: "How Do I Have Text Read Aloud Without VoiceOver?",
                summary: "Speak Screen, Speak Selection, and Typing Feedback.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Read & Speak.",
                        "Turn on Speak Selection, to hear text you select.",
                        "Turn on Speak Screen. Then swipe down from the top of the screen with two fingers to hear the whole screen.",
                    ]),
                    .body("Typing Feedback, on the same screen, speaks letters and words as you type."),
                    .note("Read & Speak was called Spoken Content before iOS 26. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-live-captions",
                title: "How Do I Turn On Live Captions?",
                summary: "Captions for speech in calls, videos, and conversations around you.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Live Captions, and turn it on.",
                        "A captions window appears. Captions show for speech from apps, calls, and the microphone.",
                    ]),
                    .tip("Add Live Captions to Control Center to turn it on and off quickly. With a braille display, Braille Access shows Live Captions in braille."),
                    .note("Live Captions is available in some languages and regions. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Use Braille Access?", type: .tutorial, destination: .article("howto-braille-access"))]
            ),
            HelpArticle(
                id: "howto-auto-captions",
                title: "How Do I Get Captions on a Video That Has None?",
                summary: "Automatic captions, new in iOS 27.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Subtitles & Captioning.",
                        "Turn on Automatic Captions for Personal Videos.",
                        "While a video plays, for example in Photos, choose the captions button beside the volume, and turn captions on.",
                    ]),
                    .body("Captions are made on iPhone, without the internet. The captions button can also change the language and style. They also appear for videos in Messages."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-sound-recognition",
                title: "How Do I Get Alerts for Sounds Like a Doorbell?",
                summary: "Sound Recognition listens for sounds and tells you.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Sound Recognition, and turn it on.",
                        "Choose Sounds, then the ones you want, such as Doorbell, Smoke Alarm, Baby Crying, or Water Running.",
                    ]),
                    .body("You can also teach it a sound of your own, such as your doorbell or appliance."),
                    .warning("Don't rely on Sound Recognition in an emergency or where you could be hurt."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-hearing-devices",
                title: "How Do I Pair Hearing Aids?",
                summary: "Made for iPhone hearing aids and cochlear implant processors.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Hearing Devices.",
                        "Open your hearing aids' battery doors, then close them, so they're ready to pair.",
                        "Choose them under MFi Hearing Devices, then Pair.",
                    ]),
                    .body("Some hearing aids use Bluetooth LE Audio instead, and pair from Settings > Bluetooth. Check their instructions."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-airpods-hearing",
                title: "How Do I Use AirPods for Hearing Help or a Hearing Test?",
                summary: "Hearing features on AirPods Pro 2 and later.",
                content: [
                    .steps([
                        "Put your AirPods in your ears, connected to iPhone.",
                        "Open Settings, then your AirPods' name near the top.",
                        "Under Hearing Health, choose Take a Hearing Test, or set up Hearing Assistance.",
                    ]),
                    .note("Hearing features need AirPods Pro 2 or later and are available in some countries. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-live-listen",
                title: "How Do I Use Live Listen?",
                summary: "Use iPhone as a microphone that sends sound to your AirPods or hearing aids.",
                content: [
                    .steps([
                        "Add Hearing to Control Center, if it isn't there.",
                        "Open Control Center, and choose Hearing.",
                        "Choose Live Listen, and turn it on.",
                        "Put iPhone near the person you want to hear.",
                    ]),
                    .note("Works with AirPods, some Beats, and Made for iPhone hearing aids. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-audio-adjust",
                title: "How Do I Make Calls and Audio Clearer?",
                summary: "Headphone Accommodations, Mono Audio, and balance.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Audio & Visual.",
                        "Choose Headphone Accommodations to boost soft sounds and some frequencies.",
                        "Turn on Mono Audio to hear everything in both ears.",
                        "Use Balance to make one side louder.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-led-flash",
                title: "How Do I Flash the Light for Alerts?",
                summary: "The camera flash blinks for calls and notifications.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Audio & Visual.",
                        "Turn on LED Flash for Alerts.",
                    ]),
                    .body("Choose whether it also flashes when iPhone is unlocked, or in Silent Mode."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-rtt",
                title: "How Do I Use RTT or TTY?",
                summary: "Text-based phone calls.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then RTT/TTY.",
                        "Turn on Software RTT/TTY, and set the relay number if you use one.",
                        "When you call someone, choose RTT Call or RTT Relay Call.",
                    ]),
                    .note("Available with some carriers and countries. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-assistivetouch",
                title: "How Do I Use AssistiveTouch?",
                summary: "An on-screen button for gestures and buttons that are hard to press.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Touch, then AssistiveTouch, and turn it on.",
                        "A floating button appears. Tap it for a menu of things like Home, Notification Center, and volume.",
                        "Choose Customize Top Level Menu to change what's in it.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-back-tap",
                title: "How Do I Set Up Back Tap?",
                summary: "Double-tap or triple-tap the back of iPhone to do something.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Touch, then Back Tap.",
                        "Choose Double Tap or Triple Tap.",
                        "Choose what it does, such as Screenshot, VoiceOver, Magnifier, or a shortcut.",
                    ]),
                    .note("Works on iPhone 8 and later, even with many cases. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-accessibility-shortcut",
                title: "How Do I Change the Accessibility Shortcut?",
                summary: "Choose what a triple-click of the side button turns on.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Accessibility Shortcut.",
                        "Select the features you want, such as VoiceOver, Zoom, Magnifier, or Accessibility Reader.",
                    ]),
                    .body("With one feature, a triple-click turns it on or off. With more than one, a triple-click asks which."),
                    .note("On iPhones with a Home button, triple-click the Home button. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "The Accessibility Shortcut", type: .guide, destination: .article("ref-accessibility-shortcut"))]
            ),
            HelpArticle(
                id: "howto-voice-control",
                title: "How Do I Use Voice Control?",
                summary: "Control iPhone with your voice. In iOS 27, describe controls in your own words.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Voice Control.",
                        "Choose Set Up Voice Control, and follow the steps.",
                        "Say commands like \"Open Mail\", \"Go home\", or \"Tap Send\".",
                    ]),
                    .body("In iOS 27, you don't need a button's exact name. Describe it, for example \"tap the blue button at the bottom\"."),
                    .tip("Say \"Show names\" or \"Show numbers\" to see what you can say for each item."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-switch-control",
                title: "How Do I Set Up Switch Control?",
                summary: "Use one or more switches to control iPhone.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Switch Control.",
                        "Choose Switches, then Add New Switch. Choose External, Screen, Camera, or Sound.",
                        "Choose the action for the switch, such as Select Item.",
                        "Go back, and turn on Switch Control.",
                    ]),
                    .tip("Add Switch Control to the Accessibility Shortcut first, so you can turn it off quickly while you're learning."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-touch-accommodations",
                title: "How Do I Change How Long a Touch Has to Be?",
                summary: "Touch Accommodations, and turning off Shake to Undo.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Touch, then Touch Accommodations.",
                        "Turn on Hold Duration, to ignore brief touches, or Ignore Repeat, to treat several touches as one.",
                    ]),
                    .body("On the Touch screen, turn off Shake to Undo if shaking iPhone keeps asking about undoing."),
                    .warning("Touch Accommodations can change how VoiceOver gestures work. Try a setting before relying on it."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-eye-tracking",
                title: "How Do I Use Eye Tracking?",
                summary: "Control iPhone by looking at the screen.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then Eye Tracking, and turn it on.",
                        "Follow the dot with your eyes to calibrate.",
                        "Look at an item, and hold your gaze to select it.",
                    ]),
                    .note("Works best with iPhone on a stand, about a foot and a half from your face. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
