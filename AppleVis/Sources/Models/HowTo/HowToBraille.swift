import Foundation

/// How-To Library: braille on iPhone and iPad (2026-10-08). Written for
/// iOS 27 in AppleVis's own words. Paths checked against Apple's braille
/// support pages, the Helen Keller National Center, and AppleVis's iOS 27
/// review. Help is translated while the app runs.
extension HelpContent {
    static let howToBraille = HelpSection(
        id: "howto-braille",
        title: "How To: Braille",
        icon: "hand.point.up.braille",
        description: "Connecting a braille display, braille tables, commands, Braille Screen Input, Braille Access, and the iOS 27 braille changes.",
        articles: [
            HelpArticle(
                id: "howto-braille-connect",
                title: "How Do I Connect a Braille Display?",
                summary: "Pair a Bluetooth braille display from VoiceOver's braille settings.",
                content: [
                    .body("Braille displays pair from VoiceOver's settings, not from the Bluetooth screen."),
                    .steps([
                        "Turn on the display, and put it in Bluetooth pairing mode. Its manual explains how.",
                        "On iPhone, open Settings, then Accessibility, then VoiceOver.",
                        "Choose Braille.",
                        "Under Choose a Braille Display, choose your display.",
                        "If asked, type the pairing code from the display's manual, often 0000.",
                    ]),
                    .tip("Some displays connect over USB too. Plug them in and they appear in the same list."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [
                    RelatedLink(label: "Braille Display Commands on iPhone and iPad", type: .guide, destination: .article("ref-braille-display")),
                    RelatedLink(label: "My Braille Display Won't Connect or Keeps Dropping", type: .troubleshooting, destination: .article("howto-braille-trouble")),
                ]
            ),
            HelpArticle(
                id: "howto-braille-commands",
                title: "How Do I Change a Braille Display Command?",
                summary: "Assign a different key press to a VoiceOver command on your display.",
                content: [
                    .steps([
                        "Connect your braille display.",
                        "Open Settings, then Accessibility, then VoiceOver, then Braille.",
                        "Choose More Info beside your display's name.",
                        "Choose Braille Commands, then a category, such as Interaction or Navigation.",
                        "Choose the command, then Assign New Braille Keys. Press the keys you want on the display.",
                    ]),
                    .note("Commands are saved for that display. Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Braille Display Commands on iPhone and iPad", type: .guide, destination: .article("ref-braille-display"))]
            ),
            HelpArticle(
                id: "howto-braille-tables",
                title: "How Do I Switch Between Contracted and Uncontracted Braille?",
                summary: "Choose contracted, six-dot, or eight-dot braille, and the braille table.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver, then Braille.",
                        "Choose Output to set how braille appears on the display, and Input to set how you type.",
                        "Choose Contracted Braille, Uncontracted Six-dot Braille, or Uncontracted Eight-dot Braille.",
                    ]),
                    .body("Braille Tables, on the same screen, chooses the language and code, such as Unified English Braille. Add more than one table to switch between them."),
                    .tip("With a display, you can also switch between contracted and uncontracted from the keyboard. See Braille Display Commands."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-braille-screen-input",
                title: "How Do I Type with Braille Screen Input?",
                summary: "Type braille on the touchscreen, with word predictions in iOS 27.",
                content: [
                    .heading("Add it to the rotor"),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver.",
                        "Choose Rotor, then Rotor Items.",
                        "Select Braille Screen Input.",
                    ]),
                    .heading("Type"),
                    .steps([
                        "In a text field, set the rotor to Braille Screen Input.",
                        "Hold iPhone flat on a table, or with the screen facing away from you.",
                        "Type with your fingers on the dots. Swipe right for a space, left to delete, and two fingers right for a new line.",
                        "To stop, set the rotor to something else.",
                    ]),
                    .heading("Word predictions, new in iOS 27"),
                    .body("After a word, swipe up or down with one finger to move through suggestions and corrections. Then carry on typing. You can also type part of an emoji's name and swipe up or down to find it."),
                    .body("To type an alternative character, hold the dots for the character until you hear a sound. Release, then swipe up or down to choose."),
                    .note("Predictions need Auto-Correction on, in Settings > General > Keyboard. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-braille-access",
                title: "How Do I Use Braille Access?",
                summary: "A braille notetaker built into iPhone: notes, files, a calculator, live captions, and more.",
                content: [
                    .body("Braille Access turns iPhone and a braille display into a braille notetaker that works anywhere, not just in one app."),
                    .heading("Open it"),
                    .bullets([
                        "On a Perkins-style keyboard: press dots 7 and 8 together. With an eight-dot braille table, press Space with them.",
                        "On a QWERTY keyboard: press the VoiceOver keys, Shift, and Y.",
                    ]),
                    .heading("What's in it"),
                    .bullets([
                        "Launch App and Item Chooser.",
                        "Braille Notes, for writing in braille.",
                        "Files: braille BRF files, and in iOS 27 plain text and PDF files too. They're kept in the BRF Files folder in iCloud Drive.",
                        "A calculator, with Nemeth Code.",
                        "Live Captions, shown in braille.",
                        "The time, down to the second.",
                    ]),
                    .body("To choose what appears, open Settings > Accessibility > VoiceOver > Braille > Braille Access."),
                    .note("Braille Access needs a braille display. It doesn't work with Braille Screen Input. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-braille-cursor",
                title: "How Do I Make the Cursor Easier to Follow on My Braille Display?",
                summary: "Snap to Print Text Cursor, new in iOS 27.",
                content: [
                    .body("With contracted braille, a cursor routing button can land in the middle of a contraction. Snap to Print Text Cursor moves it to the nearest real character instead. It's especially handy if you type on a QWERTY keyboard and read contracted braille."),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver, then Braille.",
                        "Choose Cursor Routing.",
                        "Choose Snap to Print Text Cursor, or Any Braille Cell for the old behavior.",
                    ]),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-braille-field-labels",
                title: "How Do I Keep a Text Field's Label on My Braille Display?",
                summary: "Text Field Labels, new in iOS 27.",
                content: [
                    .body("In iOS 27, a text field's label can stay on the display while you type, between two marker symbols."),
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver, then Braille.",
                        "Choose Text Field Labels.",
                        "Choose Full for the whole label, or Collapse for just the two markers.",
                    ]),
                    .tip("Press a cursor routing button on the label to collapse it."),
                    .note("Turn everything off here for the way labels worked before. Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-braille-status",
                title: "How Do I Turn On the Status Cell or Word Wrap?",
                summary: "Display options for your braille display.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver, then Braille.",
                        "Choose Status Cells to show status at the left or right end of the display.",
                        "Turn on Word Wrap so words aren't split between lines.",
                    ]),
                    .body("The same screen also has Show Onscreen Keyboard, Turn Pages when Panning, and Alert Display Duration."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-braille-nemeth",
                title: "How Do I Use Nemeth Code for Math?",
                summary: "Show equations in Nemeth Code on a braille display.",
                content: [
                    .steps([
                        "Open Settings, then Accessibility, then VoiceOver, then Braille.",
                        "Turn on Equations Use Nemeth Code.",
                    ]),
                    .tip("Braille Access has a calculator that works in Nemeth Code too."),
                    .note("Written for iOS 27."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "How Do I Use Braille Access?", type: .tutorial, destination: .article("howto-braille-access"))]
            ),
            HelpArticle(
                id: "howto-braille-trouble",
                title: "My Braille Display Won't Connect or Keeps Dropping",
                summary: "Things to try, in order.",
                content: [
                    .steps([
                        "Check that Bluetooth is on, and that the display is charged and on.",
                        "Turn the display off and on again.",
                        "Make sure the display isn't connected to another device, such as a computer.",
                        "In Settings > Accessibility > VoiceOver > Braille, choose More Info beside the display, then Forget This Device. Put the display in pairing mode and connect again.",
                        "Restart iPhone.",
                        "Check the display maker's website for a firmware update.",
                    ]),
                    .note("Pair braille displays in VoiceOver's braille settings, not from the Bluetooth screen. Written for iOS 27."),
                ],
                contentType: .troubleshooting,
                relatedLinks: [RelatedLink(label: "How Do I Connect a Braille Display?", type: .tutorial, destination: .article("howto-braille-connect"))]
            ),
        ]
    )
}
