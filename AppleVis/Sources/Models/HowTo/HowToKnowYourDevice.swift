import Foundation

/// How-To Library: what the buttons, bumps, and holes are (2026-10-08).
/// For the person holding a device and asking "what's this?". Positions
/// differ by model, so each article says where things usually are and how
/// to tell. Written in AppleVis's own words. Help is translated while the
/// app runs.
extension HelpContent {
    static let howToKnowYourDevice = HelpSection(
        id: "howto-know-device",
        title: "How To: Know Your Device",
        icon: "iphone",
        description: "What the buttons, camera bumps, holes, and ports on iPhone are, MagSafe, charging, the SIM tray, and the parts of AirPods, Apple Watch, and the Apple TV remote.",
        articles: [
            HelpArticle(
                id: "howto-know-side-buttons",
                title: "What Are the Buttons on the Sides of My iPhone?",
                summary: "The side button, volume buttons, Action button, and Camera Control.",
                content: [
                    .body("Hold iPhone upright with the screen facing you."),
                    .heading("Right side"),
                    .bullets([
                        "Side button: the long button near the top. Press it to lock or wake iPhone. Press and hold it for Siri. Triple-click it for the Accessibility Shortcut, such as VoiceOver.",
                        "Camera Control: on newer models, a flat button lower down the right side. See What Is Camera Control?",
                    ]),
                    .heading("Left side"),
                    .bullets([
                        "Volume up and volume down: two buttons, up on top.",
                        "Action button: on newer models, a short button above the volume buttons. On older models, there's a small Ring/Silent switch there instead, which you flip.",
                    ]),
                    .tip("Not sure which iPhone you have? Open Settings > General > About, and check Model Name."),
                ],
                contentType: .guide,
                relatedLinks: [
                    RelatedLink(label: "What Is the Action Button?", type: .guide, destination: .article("howto-know-action-button")),
                    RelatedLink(label: "Which iPhone Do I Have?", type: .guide, destination: .article("howto-know-which-iphone")),
                ]
            ),
            HelpArticle(
                id: "howto-know-action-button",
                title: "What Is the Action Button?",
                summary: "The short button above the volume buttons on newer iPhones.",
                content: [
                    .body("The Action button is on the left side, above the volume buttons, on iPhone 15 Pro and later, and on iPhone 16 and later. It replaced the Ring/Silent switch."),
                    .body("Press and hold it to do one thing you choose. It starts out as Silent Mode. It can be the flashlight, the camera, Magnifier, a shortcut, VoiceOver's Ask a Question, and more."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Change What the Action Button Does?", type: .tutorial, destination: .article("howto-home-action-button"))]
            ),
            HelpArticle(
                id: "howto-know-camera-control",
                title: "What Is Camera Control?",
                summary: "The flat button low on the right side of newer iPhones.",
                content: [
                    .body("Camera Control is on the right side, below the side button, on iPhone 16 and later models that have it. It's flat and flush with the edge, and it can sense a light press and a slide of your finger."),
                    .bullets([
                        "Press it to open the Camera, and press again to take a photo.",
                        "Press and hold to record video.",
                        "Press lightly, then slide your finger along it, to change settings such as zoom.",
                    ]),
                    .tip("If it's easy to press by accident, Settings > Accessibility > Camera Control lets you adjust or turn off the light press."),
                ],
                contentType: .guide
            ),
            HelpArticle(
                id: "howto-know-camera-bumps",
                title: "What Are the Round Bumps on the Back of My iPhone?",
                summary: "The camera lenses.",
                content: [
                    .body("The large round bumps near a top corner of the back are the camera lenses. Each lens is a different camera: wide, ultra wide, or telephoto for zooming in."),
                    .bullets([
                        "Most iPhones have one, two, or three lenses, depending on the model.",
                        "On iPhone 17 Pro and later Pro models, the cameras sit in a raised bar that runs across the top of the back.",
                        "The front camera is a small dot in the screen, at the top.",
                    ]),
                    .tip("Fingerprints on the lenses blur photos. Wipe them with a soft cloth now and then."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "What Are the Small Circles and Holes on the Back?", type: .guide, destination: .article("howto-know-small-holes"))]
            ),
            HelpArticle(
                id: "howto-know-small-holes",
                title: "What Are the Small Circles and Holes on the Back of My iPhone?",
                summary: "The flash, a microphone, and on Pro models, the LiDAR scanner.",
                content: [
                    .body("Near the camera lenses there are some smaller parts:"),
                    .bullets([
                        "Flash: a small flat circle. It's the light for photos and the flashlight.",
                        "Microphone: a tiny hole, used when recording video and for clearer calls.",
                        "LiDAR scanner: on Pro models, a small dark circle. It measures distance, which helps the camera focus. Magnifier uses it to detect people and doors and tell you how far away they are.",
                    ]),
                    .note("Exactly where each one sits depends on the model."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Use Magnifier?", type: .tutorial, destination: .article("howto-magnifier"))]
            ),
            HelpArticle(
                id: "howto-know-bottom-edge",
                title: "What's Along the Bottom Edge of My iPhone?",
                summary: "The charging port in the middle, with a speaker and microphones on either side.",
                content: [
                    .bullets([
                        "In the middle: the charging port. It's USB-C on iPhone 15 and later, and Lightning on earlier models. It's also for headphones with that kind of plug, and for connecting to a computer.",
                        "On one side: a row of holes for the loudspeaker.",
                        "On the other side: another row of holes, mostly for the microphones.",
                    ]),
                    .tip("If calls sound muffled or people can't hear you, gently clear these holes with a soft, dry brush."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Charge My iPhone?", type: .guide, destination: .article("howto-know-charging"))]
            ),
            HelpArticle(
                id: "howto-know-front",
                title: "What's at the Top of the Front of My iPhone?",
                summary: "The earpiece, the Dynamic Island, and Face ID.",
                content: [
                    .bullets([
                        "Earpiece: a thin slot along the very top edge. You hear calls through it when you hold iPhone to your ear. It's also the second speaker.",
                        "Dynamic Island: on iPhone 14 Pro and later, a pill shape at the top of the screen. It holds the front camera and Face ID, and shows things like a timer or what's playing.",
                        "On some models, there's a notch, a dark area cut into the top of the screen, instead.",
                        "Face ID: sensors next to the front camera that recognize your face. Older models have a Home button with Touch ID at the bottom of the front instead.",
                    ]),
                ],
                contentType: .guide
            ),
            HelpArticle(
                id: "howto-know-magsafe",
                title: "What Is MagSafe?",
                summary: "Magnets in the back of iPhone for chargers and accessories.",
                content: [
                    .body("MagSafe is a ring of magnets inside the back of iPhone 12 and later. You can't see or feel it, but MagSafe accessories snap into place in the middle of the back."),
                    .bullets([
                        "MagSafe chargers line up by themselves, so you don't have to feel for the right spot.",
                        "Cases, wallets, stands, and car mounts can attach magnetically.",
                        "Qi2 chargers use the same magnets and work too.",
                    ]),
                    .tip("If you use a case, choose one marked as MagSafe compatible, or the magnets won't hold as well."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Charge My iPhone?", type: .guide, destination: .article("howto-know-charging"))]
            ),
            HelpArticle(
                id: "howto-know-charging",
                title: "How Do I Charge My iPhone?",
                summary: "With a cable, MagSafe, or a wireless charger.",
                content: [
                    .bullets([
                        "Cable: plug it into the port on the bottom edge. USB-C on iPhone 15 and later, Lightning on earlier models.",
                        "MagSafe or Qi2: place iPhone on the charger. The magnets line it up.",
                        "Other wireless chargers: place iPhone screen up on the pad, with the middle of the back over the middle of the pad.",
                    ]),
                    .body("iPhone plays a sound and vibrates when charging starts. With VoiceOver, the status bar tells you the battery level and whether it's charging."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Make My Battery Last Longer?", type: .tutorial, destination: .article("howto-low-power"))]
            ),
            HelpArticle(
                id: "howto-know-sim",
                title: "Where Is the SIM Card Slot?",
                summary: "A small tray on the side, on models that have one.",
                content: [
                    .body("On iPhones with a SIM tray, it's a small slot on the side with a pinhole next to it. Push the SIM tool, or a straightened paper clip, into the pinhole, and the tray pops out."),
                    .body("iPhone 14 and later sold in the United States, and some other models, have no SIM tray at all. They use eSIM instead."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Add an eSIM or Switch Phone Lines?", type: .tutorial, destination: .article("howto-esim"))]
            ),
            HelpArticle(
                id: "howto-know-edge-lines",
                title: "What Are the Thin Lines on the Edges of My iPhone?",
                summary: "Antenna bands.",
                content: [
                    .body("The thin strips across the metal edges, often a slightly different texture, are antenna bands. They let the cellular, Wi-Fi, and Bluetooth signals through the metal frame. They aren't buttons, and there's nothing to press."),
                ],
                contentType: .guide
            ),
            HelpArticle(
                id: "howto-know-which-iphone",
                title: "Which iPhone Do I Have?",
                summary: "Find your model name and iOS version.",
                content: [
                    .steps([
                        "Open Settings, then General, then About.",
                        "Model Name is your iPhone, such as iPhone 17 Pro.",
                        "iOS Version is the software it's running.",
                    ]),
                    .tip("Knowing your model helps when someone gives instructions for a button your iPhone may not have."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-know-airpods",
                title: "What Are the Parts of My AirPods and Their Case?",
                summary: "Stems, the case button, and the light.",
                content: [
                    .bullets([
                        "Stem: the part of each AirPod that points down. On most models, you press or squeeze it to play, pause, answer calls, and more. On AirPods Max, there's a Digital Crown and a button instead.",
                        "Case light: shows the charge and pairing status. Your iPhone also shows the battery level when you open the case nearby.",
                        "Case button: on many cases, a small button on the back, used for pairing and resetting.",
                        "Charging: the case has a port on the bottom. Many cases also charge on a wireless or MagSafe charger.",
                    ]),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "How Do I Change What My AirPods Do When I Press Them?", type: .tutorial, destination: .article("howto-airpods-controls"))]
            ),
            HelpArticle(
                id: "howto-know-watch",
                title: "What Are the Buttons on My Apple Watch?",
                summary: "The Digital Crown, the side button, and on Ultra, the Action button.",
                content: [
                    .bullets([
                        "Digital Crown: the round dial on the right side. Turn it to scroll, and press it to go to the watch face or the Home Screen. Triple-press it for the Accessibility Shortcut, such as VoiceOver.",
                        "Side button: the long button below the Digital Crown. Press it for Control Center. Press and hold it to turn the watch off, or for Emergency SOS.",
                        "Action button: on Apple Watch Ultra, an extra button on the left side.",
                        "The back: the sensors that rest on your wrist, for heart rate and more.",
                    ]),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "VoiceOver on Apple Watch", type: .guide, destination: .article("ref-voiceover-watch"))]
            ),
            HelpArticle(
                id: "howto-know-tv-remote",
                title: "What Are the Buttons on My Apple TV Remote?",
                summary: "The Siri Remote, from top to bottom.",
                content: [
                    .bullets([
                        "Clickpad, at the top: press its edges for up, down, left, and right, and the middle to select. You can also swipe on it.",
                        "Back button: below the clickpad on the left. Triple-press it for the Accessibility Shortcut, such as VoiceOver.",
                        "TV button: beside it. Goes to the Home Screen.",
                        "Play/Pause, Mute, and the volume buttons: below those.",
                        "Siri button: on the right side of the remote. Press and hold it to talk to Siri.",
                        "Power button: at the top, on newer remotes, to turn the TV on or off.",
                    ]),
                    .note("Older Siri Remotes have a Menu button instead of Back, and fewer buttons."),
                ],
                contentType: .guide,
                relatedLinks: [RelatedLink(label: "VoiceOver on Apple TV", type: .guide, destination: .article("ref-voiceover-tv"))]
            ),
        ]
    )
}
