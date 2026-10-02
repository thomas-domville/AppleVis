import Foundation

/// AppleVis guides the Mouse always reads when a question is about their
/// subject, even when the site search buries them. "Three finger double
/// tap" brought back a Mac trackpad guide and never the complete iOS
/// gesture list until this. Apple Intelligence picks one while planning a
/// question; it can't add others. Each id was checked against the live site
/// on 2026-10-01. Requested directly (2026-10-01).
enum MouseEssentialGuide: String, CaseIterable, Sendable {
    case iosGestures, iosBeginner, iosVoiceOverSettings, rotor, gesturesInsteadOfButtons, accessibilityShortcut
    case brailleScreenInput, brailleDisplayIOS, bluetoothKeyboardIOS
    case macBeginner, macKeyboardShortcuts, macVoiceOverUtility
    case shortcuts, continuity

    /// The guide's id on applevis.com.
    var id: String {
        switch self {
        case .iosGestures: return "72c6bedc-6076-45b7-9a43-a4c94bcc36ba"
        case .iosBeginner: return "91099b5a-2469-459a-8eb5-2fa5f1daedde"
        case .iosVoiceOverSettings: return "a053e47d-d16c-4e7e-bd27-83d2c9860e85"
        case .rotor: return "12994437-e6d7-4387-984c-963eee378592"
        case .gesturesInsteadOfButtons: return "6dc90d73-2772-4fbb-a817-352e1f834320"
        case .accessibilityShortcut: return "a82df360-0ec3-492c-9e6a-1dd8b5c7c45c"
        case .brailleScreenInput: return "aff980ee-b75e-42f0-9928-054bc4f5a4f1"
        case .brailleDisplayIOS: return "e18a3570-5fbd-4923-a0bf-daa3a0cb7988"
        case .bluetoothKeyboardIOS: return "5c4a5c17-a25e-418a-8cb7-917c85f32568"
        case .macBeginner: return "39af6182-d4c7-4528-ae5a-28210557b9cb"
        case .macKeyboardShortcuts: return "8849b463-4379-4676-80e7-274935ddd6fe"
        case .macVoiceOverUtility: return "7740bd9f-b05b-4726-a13f-180506e912f6"
        case .shortcuts: return "f9453f23-a701-40aa-8269-89a7f5b178fb"
        case .continuity: return "2e46fa61-3682-4a03-bd75-a69d785e9b28"
        }
    }

    /// The guide's title on applevis.com, used to find it with the site's
    /// search (which returns the full entry the app needs).
    var title: String {
        switch self {
        case .iosGestures: return "A Complete List of iOS and iPadOS Gestures Available to VoiceOver Users"
        case .iosBeginner: return "A Beginner's Guide to Using iOS with VoiceOver"
        case .iosVoiceOverSettings: return "a Deep dive into VoiceOver settings for iOS and iPadOS"
        case .rotor: return "iDevice Primer 103: What is the rotor for and how do I use it?"
        case .gesturesInsteadOfButtons: return "How To Use Gestures Instead of Buttons for Home, Notifications, and More"
        case .accessibilityShortcut: return "Toggling VoiceOver On and Off Using the Accessibility Shortcut on iOS and iPadOS"
        case .brailleScreenInput: return "A Guide to Braille Screen Input on iOS and iPadOS"
        case .brailleDisplayIOS: return "Using a Braille Display on iOS: an Introduction"
        case .bluetoothKeyboardIOS: return "Don't Touch it, Type it! A VoiceOver User's Guide to Using a QWERTY Bluetooth Keyboard"
        case .macBeginner: return "How to use Mac with VoiceOver (A beginners guide)"
        case .macKeyboardShortcuts: return "A Complete List of VoiceOver Keyboard Shortcuts Available on macOS"
        case .macVoiceOverUtility: return "A Deep Dive into VoiceOver Utility On Mac"
        case .shortcuts: return "a guide to creating and running shortcuts on iOS and macOS"
        case .continuity: return "How Apple Devices Can Work Better Together with Continuity Features"
        }
    }

    /// What the guide covers, for Apple Intelligence to choose by. English
    /// on purpose: the model reads it, people don't.
    var modelDescription: String {
        switch self {
        case .iosGestures: return "every VoiceOver touch gesture on iPhone and iPad and what it does"
        case .iosBeginner: return "getting started with VoiceOver on iPhone and iPad"
        case .iosVoiceOverSettings: return "every VoiceOver setting on iPhone and iPad, such as speech, verbosity, and braille options"
        case .rotor: return "what the VoiceOver rotor is and how to use it on iPhone"
        case .gesturesInsteadOfButtons: return "going Home, opening Notification Center and Control Center, and the App Switcher with gestures on iPhone"
        case .accessibilityShortcut: return "turning VoiceOver on and off with the Accessibility Shortcut on iPhone and iPad"
        case .brailleScreenInput: return "Braille Screen Input on iPhone and iPad, including its command mode"
        case .brailleDisplayIOS: return "using a refreshable braille display with VoiceOver on iPhone and iPad"
        case .bluetoothKeyboardIOS: return "using a Bluetooth keyboard with VoiceOver on iPhone and iPad"
        case .macBeginner: return "getting started with VoiceOver on a Mac"
        case .macKeyboardShortcuts: return "every VoiceOver keyboard command on a Mac"
        case .macVoiceOverUtility: return "VoiceOver Utility settings on a Mac"
        case .shortcuts: return "creating and running Shortcuts on iPhone and Mac"
        case .continuity: return "Continuity features between Apple devices, such as Handoff and Universal Clipboard"
        }
    }
}
