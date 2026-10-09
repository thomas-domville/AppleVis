import Foundation

/// How-To Library: sounds, notifications, Focus, calls, and messages
/// (2026-10-08). Written for iOS 27 in AppleVis's own words. Help is
/// translated while the app runs.
extension HelpContent {
    static let howToCallsAlerts = HelpSection(
        id: "howto-calls-alerts",
        title: "How To: Calls, Messages, and Notifications",
        icon: "phone",
        description: "Ringtones, Silent Mode, notifications, Focus, unknown callers, Hold Assist, voicemail, blocking, emergency settings, and messages.",
        articles: [
            HelpArticle(
                id: "howto-ringtone",
                title: "How Do I Change My Ringtone or Text Tone?",
                summary: "Pick the sound for calls, texts, and other alerts.",
                content: [
                    .steps([
                        "Open Settings, then Sounds & Haptics.",
                        "Choose Ringtone, Text Tone, or another alert.",
                        "Move through the tones to hear each one, and double-tap the one you want.",
                    ]),
                    .tip("You can give one person their own ringtone: open their contact, choose Edit, then Ringtone."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-silent-mode",
                title: "How Do I Turn Silent Mode On or Off?",
                summary: "Silence the ringer and alerts.",
                content: [
                    .bullets([
                        "On iPhone 15 Pro and later, and iPhone 16 and later: press and hold the Action button, if it's set to Silent Mode.",
                        "On earlier iPhones: flip the Ring/Silent switch on the side.",
                        "On any iPhone: open Control Center and choose Silent Mode, if you've added it.",
                    ]),
                    .body("VoiceOver still speaks in Silent Mode. Alarms and timers still sound."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Change What the Action Button Does?", type: .tutorial, destination: .article("howto-home-action-button"))]
            ),
            HelpArticle(
                id: "howto-ringer-volume",
                title: "How Do I Change the Ringer Volume Separately from Music?",
                summary: "Keep calls loud and media quiet, or the other way round.",
                content: [
                    .steps([
                        "Open Settings, then Sounds & Haptics.",
                        "Set Ringtone and Alerts Volume: swipe up or down.",
                        "Turn off Change with Buttons, so the volume buttons only change music, video, and VoiceOver.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-notifications-app",
                title: "How Do I Turn Off Notifications for One App?",
                summary: "Silence an app, or change how its notifications appear.",
                content: [
                    .steps([
                        "Open Settings, then Notifications.",
                        "Choose the app.",
                        "Turn off Allow Notifications. Or keep them on, and change sounds, badges, or where they appear.",
                    ]),
                    .tip("Choosing Scheduled Summary for a noisy app collects its notifications and delivers them together at times you choose."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Get a Notification Summary?", type: .tutorial, destination: .article("howto-notification-summary"))]
            ),
            HelpArticle(
                id: "howto-notification-summary",
                title: "How Do I Get a Notification Summary?",
                summary: "Collect less urgent notifications and get them together.",
                content: [
                    .steps([
                        "Open Settings, then Notifications.",
                        "Choose Scheduled Summary, and turn it on.",
                        "Choose the times, then choose which apps go in it.",
                    ]),
                    .body("With Apple Intelligence, Summarize Notifications, on the same Notifications screen, can also sum up long notifications in a line."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-announce-notifications",
                title: "How Do I Hear Notifications on My AirPods?",
                summary: "Siri reads notifications aloud through headphones.",
                content: [
                    .steps([
                        "Open Settings, then Notifications.",
                        "Choose Announce Notifications, and turn it on.",
                        "Choose which apps Siri announces, and whether to announce on headphones.",
                    ]),
                    .note("Works with AirPods and some Beats headphones. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-vo-notifications",
                title: "How Do I Make VoiceOver Read Notifications as They Arrive?",
                summary: "Or keep VoiceOver quiet when the screen is locked.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Verbosity.",
                        "Choose how VoiceOver handles notifications, such as speaking them or only playing a sound.",
                    ]),
                    .tip("To read notifications you missed, open Notification Center: with VoiceOver, move to the status bar and swipe down with three fingers."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-focus",
                title: "How Do I Set Up a Focus, Like Sleep or Do Not Disturb?",
                summary: "Quiet notifications and calls, with the people and apps you choose let through.",
                content: [
                    .steps([
                        "Open Settings, then Focus.",
                        "Choose a Focus, such as Do Not Disturb, Sleep, or Work. Or choose Add Focus to make your own.",
                        "Under Allow Notifications, choose People and Apps to let through.",
                        "To have it come on by itself, choose Add Schedule, and pick a time, place, or app.",
                    ]),
                    .tip("Turn a Focus on or off from Control Center. The Focus control lists them all."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-unknown-callers",
                title: "How Do I Stop Calls from Unknown Numbers?",
                summary: "Have iPhone screen unknown callers, or silence them.",
                content: [
                    .steps([
                        "Open Settings, then Apps, then Phone.",
                        "Choose Screen Unknown Callers.",
                        "Choose Ask Reason for Calling, so iPhone asks the caller who they are before it rings, or Silence, so unknown callers go straight to voicemail.",
                    ]),
                    .body("With Ask Reason for Calling, you hear or read their answer and decide whether to pick up."),
                    .note("Calls from your contacts, and numbers you've called, always ring. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-hold-assist",
                title: "How Do I Let iPhone Wait on Hold for Me?",
                summary: "Hold Assist tells you when a person picks up.",
                content: [
                    .steps([
                        "On a call that's put you on hold, iPhone may offer Hold Assist. Choose it.",
                        "Carry on with other things. iPhone keeps the call going.",
                        "When someone comes on the line, iPhone alerts you so you can return to the call.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-unknown-senders",
                title: "How Do I Filter Messages from Unknown Senders?",
                summary: "Keep texts from people you don't know in a separate list.",
                content: [
                    .steps([
                        "Open Settings, then Apps, then Messages.",
                        "Turn on Screen Unknown Senders.",
                    ]),
                    .body("Messages from unknown senders then wait in their own list in Messages, without notifications, until you accept them."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-answer-call",
                title: "How Do I Answer or End a Call with VoiceOver?",
                summary: "Magic Tap, and other ways.",
                content: [
                    .bullets([
                        "Answer or end a call: double-tap anywhere with two fingers. This is the Magic Tap.",
                        "Decline a call: press the side button twice.",
                        "With AirPods or other headphones: press or squeeze the control once.",
                    ]),
                    .tip("Settings > Accessibility > Touch > Call Audio Routing chooses whether calls go to headphones or the speaker."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-block-number",
                title: "How Do I Block a Number?",
                summary: "Stop calls and messages from someone.",
                content: [
                    .steps([
                        "Open Phone, then Recents.",
                        "Swipe right from the call to its More Info button, then double-tap.",
                        "Choose Block This Caller, then Block Contact.",
                    ]),
                    .body("To see or remove blocked numbers, open Settings > Apps > Phone > Blocked Contacts."),
                    .note("Blocked numbers can still leave voicemail. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-voicemail",
                title: "How Do I Set Up Voicemail and Read Live Voicemail?",
                summary: "Visual voicemail, and seeing a message as it's left.",
                content: [
                    .steps([
                        "Open Phone, then Voicemail.",
                        "Choose Set Up Now, then create a password and greeting.",
                    ]),
                    .body("With Live Voicemail, a message is transcribed on screen while the caller speaks, and you can pick up. Turn it on or off in Settings > Apps > Phone > Live Voicemail."),
                    .note("Visual voicemail depends on your carrier. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-emergency",
                title: "How Do I Set Up Emergency Contacts and Medical ID?",
                summary: "Information that helps someone help you, even when iPhone is locked.",
                content: [
                    .steps([
                        "Open the Health app, then your profile picture, then Medical ID.",
                        "Choose Edit, and add your details.",
                        "Under Emergency Contacts, add people.",
                        "Turn on Show When Locked.",
                    ]),
                    .body("When you use Emergency SOS, your emergency contacts get a message with your location."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Use Emergency SOS?", type: .tutorial, destination: .article("howto-sos"))]
            ),
            HelpArticle(
                id: "howto-sos",
                title: "How Do I Use Emergency SOS?",
                summary: "Call emergency services quickly, and choose how it starts.",
                content: [
                    .body("Press and hold the side button and either volume button. Keep holding through the countdown, and iPhone calls emergency services."),
                    .steps([
                        "To change how it works, open Settings, then Emergency SOS.",
                        "Call with Hold and Release, and Call with 5 Button Presses, choose which presses start a call.",
                        "Call Quietly silences the countdown alarm.",
                    ]),
                    .warning("Practising will call emergency services. If you start by mistake, let go before the countdown ends, or end the call straight away."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-audio-message",
                title: "How Do I Send an Audio Message?",
                summary: "Record your voice in Messages.",
                content: [
                    .steps([
                        "In a conversation in Messages, choose the plus button, then Audio.",
                        "Speak your message.",
                        "Choose Send.",
                    ]),
                    .tip("To have new messages read aloud on AirPods, turn on Announce Notifications."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Hear Notifications on My AirPods?", type: .tutorial, destination: .article("howto-announce-notifications"))]
            ),
            HelpArticle(
                id: "howto-message-later",
                title: "How Do I Schedule, Edit, or Unsend a Message?",
                summary: "Send Later, Edit, and Undo Send in Messages.",
                content: [
                    .bullets([
                        "Schedule: type the message, choose the plus button, then Send Later, and pick a time.",
                        "Edit: open the sent message's menu, with a double-tap and hold or Show Menu in the Actions rotor, then choose Edit. You have 15 minutes.",
                        "Unsend: open the same menu, and choose Undo Send. You have 2 minutes.",
                    ]),
                    .note("Editing and unsending work with iMessage, not SMS text messages. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
        ]
    )
}
