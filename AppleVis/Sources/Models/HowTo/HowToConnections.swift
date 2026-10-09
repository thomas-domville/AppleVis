import Foundation

/// How-To Library: Wi-Fi, Bluetooth, and other connections (2026-10-08).
/// Written for iOS 27 in AppleVis's own words. Help is translated while the
/// app runs.
extension HelpContent {
    static let howToConnections = HelpSection(
        id: "howto-connections",
        title: "How To: Wi-Fi, Bluetooth, and Connections",
        icon: "wifi",
        description: "Joining Wi-Fi, sharing passwords, pairing Bluetooth devices, hotspot, mobile data, AirDrop, AirPlay, eSIM, and VPN.",
        articles: [
            HelpArticle(
                id: "howto-wifi-join",
                title: "How Do I Join a Wi-Fi Network?",
                summary: "Connect to Wi-Fi at home or out and about.",
                content: [
                    .steps([
                        "Open Settings, then Wi-Fi.",
                        "Make sure Wi-Fi is on.",
                        "Under Networks, choose the network.",
                        "Type the password, then choose Join.",
                    ]),
                    .body("iPhone remembers the network and joins it by itself next time."),
                    .tip("If someone nearby with an iPhone, iPad, or Mac already has the password, they can share it with you. See How Do I Share a Wi-Fi Password?"),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Share a Wi-Fi Password?", type: .tutorial, destination: .article("howto-wifi-share"))]
            ),
            HelpArticle(
                id: "howto-wifi-forget",
                title: "How Do I Forget a Wi-Fi Network?",
                summary: "Stop iPhone joining a network by itself.",
                content: [
                    .steps([
                        "Open Settings, then Wi-Fi.",
                        "Swipe right from the network's name to its More Info button, then double-tap.",
                        "Choose Forget This Network, then Forget.",
                    ]),
                    .tip("Forgetting and joining again can fix a network that won't connect."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-wifi-share",
                title: "How Do I Share a Wi-Fi Password?",
                summary: "Send your Wi-Fi password to a friend's iPhone, iPad, or Mac without reading it out.",
                content: [
                    .steps([
                        "Make sure your iPhone is unlocked and connected to the network, and the other person is in your contacts.",
                        "On their device, they choose the network to join.",
                        "On your iPhone, a Share Password button appears. Choose it.",
                    ]),
                    .note("Both devices need Wi-Fi and Bluetooth on, and need to be near each other. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-wifi-see-password",
                title: "How Do I Find the Password for My Wi-Fi?",
                summary: "See or copy the password of a network you've joined.",
                content: [
                    .steps([
                        "Open Settings, then Wi-Fi.",
                        "Choose More Info beside the network.",
                        "Choose Password, and let iPhone check it's you.",
                        "The password is shown. Choose Copy to copy it.",
                    ]),
                    .tip("The Passwords app also lists every Wi-Fi network you've joined, under Wi-Fi."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-bluetooth-pair",
                title: "How Do I Pair a Bluetooth Device?",
                summary: "Headphones, speakers, keyboards, hearing devices, and more.",
                content: [
                    .steps([
                        "Put the device in pairing mode. Its instructions explain how. Often it's holding the power button until a light flashes or it speaks.",
                        "On iPhone, open Settings, then Bluetooth, and make sure Bluetooth is on.",
                        "Under Other Devices, choose the device.",
                        "If asked, confirm the code or type the one in its instructions.",
                    ]),
                    .body("It moves to My Devices once it's paired. It reconnects by itself next time."),
                    .note("Braille displays pair from VoiceOver's settings instead. AirPods pair by opening their case near iPhone. Hearing aids pair from Accessibility settings. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [
                    RelatedLink(label: "How Do I Connect a Braille Display?", type: .tutorial, destination: .article("howto-braille-connect")),
                    RelatedLink(label: "My Bluetooth Device Won't Connect", type: .troubleshooting, destination: .article("howto-bluetooth-trouble")),
                ]
            ),
            HelpArticle(
                id: "howto-bluetooth-forget",
                title: "How Do I Unpair a Bluetooth Device?",
                summary: "Remove a device from iPhone.",
                content: [
                    .steps([
                        "Open Settings, then Bluetooth.",
                        "Under My Devices, swipe right from the device to its More Info button, then double-tap.",
                        "Choose Forget This Device, then confirm.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-bluetooth-trouble",
                title: "My Bluetooth Device Won't Connect",
                summary: "Things to try, in order.",
                content: [
                    .steps([
                        "Check the device is charged, switched on, and close to iPhone.",
                        "Make sure it isn't connected to another phone, tablet, or computer.",
                        "Turn Bluetooth off and on again in Settings > Bluetooth.",
                        "Forget the device on iPhone, put it in pairing mode, and pair it again.",
                        "Restart iPhone and the device.",
                        "Check the device maker's website or app for a firmware update.",
                    ]),
                    .note("Turning Bluetooth off in Control Center only disconnects devices until tomorrow. Settings > Bluetooth turns it fully off. Written for iOS 27."),
                ],
                contentType: .troubleshooting,
                relatedLinks: [RelatedLink(label: "How Do I Unpair a Bluetooth Device?", type: .tutorial, destination: .article("howto-bluetooth-forget"))]
            ),
            HelpArticle(
                id: "howto-hotspot",
                title: "How Do I Share My Phone's Internet? (Personal Hotspot)",
                summary: "Let a laptop, tablet, or another phone use your mobile data.",
                content: [
                    .steps([
                        "Open Settings, then Personal Hotspot.",
                        "Turn on Allow Others to Join.",
                        "Choose Wi-Fi Password to see or change the password.",
                        "On the other device, join the Wi-Fi network with your iPhone's name.",
                    ]),
                    .note("If Personal Hotspot isn't there, your plan may not include it. Your carrier can tell you. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-airplane-mode",
                title: "How Do I Use Airplane Mode but Keep Wi-Fi or Bluetooth?",
                summary: "Turn off calls and mobile data, but keep headphones or Wi-Fi.",
                content: [
                    .steps([
                        "Open Control Center, and choose Airplane Mode. Or open Settings and turn on Airplane Mode.",
                        "To use Wi-Fi or Bluetooth, turn them back on in Control Center or Settings.",
                    ]),
                    .body("iPhone remembers. Next time you turn on Airplane Mode, Wi-Fi or Bluetooth stays on if you left it on last time."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-mobile-data-apps",
                title: "How Do I Stop an App Using Mobile Data?",
                summary: "Let an app use Wi-Fi only.",
                content: [
                    .steps([
                        "Open Settings, then Cellular. In some countries it's called Mobile Data.",
                        "Swipe down to the list of apps.",
                        "Turn off the switch for any app that shouldn't use mobile data.",
                    ]),
                    .tip("The list shows how much data each app has used, which helps find the hungry ones."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-airdrop",
                title: "How Do I Send or Receive with AirDrop?",
                summary: "Share photos, files, and links with nearby Apple devices.",
                content: [
                    .heading("Send"),
                    .steps([
                        "Choose Share, in the app you're sharing from.",
                        "Choose AirDrop.",
                        "Choose the person or device.",
                    ]),
                    .heading("Receive"),
                    .steps([
                        "Open Settings, then General, then AirDrop.",
                        "Choose Contacts Only, or Everyone for 10 Minutes for someone not in your contacts.",
                        "When something arrives, choose Accept.",
                    ]),
                    .note("Both devices need Wi-Fi and Bluetooth on. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-iphone-mirroring",
                title: "How Do I Use iPhone Mirroring on a Mac?",
                summary: "Use your iPhone from your Mac's screen and keyboard.",
                content: [
                    .steps([
                        "On the Mac, open iPhone Mirroring from Spotlight, the Dock, or Applications.",
                        "Unlock your iPhone when asked, then follow the steps on the Mac.",
                        "Your iPhone's screen appears in a window on the Mac. Keep the iPhone locked and nearby.",
                    ]),
                    .body("You need a Mac with Apple silicon or a T2 chip, and an iPhone with a passcode. Both need the same Apple Account, with Bluetooth and Wi-Fi on. It isn't available in the European Union."),
                    .warning("Members report that iPhone Mirroring still only partly works with VoiceOver on the Mac. Some screens, such as the App Switcher and pickers, can be hard or impossible to use. Check the AppleVis Forums for the latest experience."),
                    .note("Written for iOS 27 and macOS 27."),
                    .source(label: "Apple Support: Use iPhone Mirroring", url: "https://support.apple.com/en-us/120421"),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-airplay",
                title: "How Do I Play Audio on a Speaker or Apple TV? (AirPlay)",
                summary: "Send music, podcasts, and video to an AirPlay speaker, HomePod, or Apple TV.",
                content: [
                    .steps([
                        "Start playing something.",
                        "Choose the AirPlay button in the app. Or open Control Center, and choose AirPlay in the Now Playing control.",
                        "Choose the speaker or TV.",
                    ]),
                    .tip("To stop, choose AirPlay again and pick iPhone."),
                    .note("In AppleVis, the podcast player has its own AirPlay button. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-esim",
                title: "How Do I Add an eSIM or Switch Phone Lines?",
                summary: "Set up a digital SIM, or choose which line to use.",
                content: [
                    .steps([
                        "Open Settings, then Cellular, or Mobile Data in some countries.",
                        "Choose Add eSIM, and follow the steps. Your carrier may give you a QR code to scan, or set it up in their app.",
                    ]),
                    .body("With two lines, the same screen lets you choose the default line for calls and which line uses mobile data."),
                    .note("Exact steps depend on your carrier. They can help if it doesn't work. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vpn",
                title: "How Do I Use a VPN?",
                summary: "Connect through a VPN service.",
                content: [
                    .body("Most VPN services have an app. Download it from the App Store, sign in, and let it add its settings when asked."),
                    .body("To turn a VPN on or off, open Settings, then VPN. It appears near the top once one is set up. Settings for VPNs added without an app are in Settings > General > VPN & Device Management."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
