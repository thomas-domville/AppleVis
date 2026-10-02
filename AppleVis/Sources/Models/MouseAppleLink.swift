import Foundation

/// Hand-picked pages outside AppleVis that Ask the Mouse can point to when a
/// question goes beyond AppleVis: Apple Support, and a few trusted
/// organizations (Be My Eyes and Hadley, added 2026-10-01). Plain links
/// only: the Mouse never reads or quotes these pages (App Review 4.5.1 bars
/// scraping Apple sites, and the others are someone else's words), so the
/// person follows the link and reads the page themselves. Apple Intelligence
/// picks one from this list when planning a question; it can't add others.
/// Each address was checked on 2026-10-01: no redirect, and the page title
/// matches. Apple sends a wrong address to the guide's welcome page
/// rather than an error, so check titles when adding one. Requested directly (2026-10-01).
enum MouseAppleLink: String, CaseIterable, Sendable {
    case voiceOverGestures, brailleCommands, brailleDisplay, brailleScreenInput, voiceOverKeyboard
    case customizeVoiceOver, zoom, magnifier, visionFeatures, macVoiceOver, accessibilitySupport
    case screenshotIPhone, screenshotIPad
    case restartIPhone, forceRestartIPhone, restartIPad, forceRestartIPad
    /// Each device's whole user guide, for when no page above fits.
    /// Requested directly (2026-10-01).
    case voiceOverIPhone, voiceOverIPad, voiceOverWatch
    /// Trusted organizations' pages, links only. Requested directly
    /// (2026-10-01).
    case beMyEyesStart, beMyAI, hadleyVoiceOver, hadleyAppleTV, hadleyLearn
    case iPhoneGuide, iPadGuide, macGuide, watchGuide, tvGuide
    case airPodsGuide, homePodGuide, visionProGuide, voiceOverMacGuide

    /// The page's name, as shown and read.
    var title: String {
        switch self {
        case .voiceOverGestures: return String(localized: "Use VoiceOver gestures on iPhone")
        case .brailleCommands: return String(localized: "Common braille commands for VoiceOver")
        case .brailleDisplay: return String(localized: "Use a braille display with VoiceOver on iPhone")
        case .brailleScreenInput: return String(localized: "Type braille on the iPhone screen")
        case .voiceOverKeyboard: return String(localized: "Use VoiceOver on iPhone with a keyboard")
        case .customizeVoiceOver: return String(localized: "Customize VoiceOver gestures and keyboard shortcuts")
        case .zoom: return String(localized: "Zoom in on the iPhone screen")
        case .magnifier: return String(localized: "Use Magnifier on iPhone")
        case .visionFeatures: return String(localized: "About vision accessibility features on iPhone and iPad")
        case .macVoiceOver: return String(localized: "Control your Mac with VoiceOver keyboard commands")
        case .accessibilitySupport: return String(localized: "Apple Accessibility Support")
        case .screenshotIPhone: return String(localized: "Take a screenshot on iPhone")
        case .screenshotIPad: return String(localized: "Take a screenshot on iPad")
        case .restartIPhone: return String(localized: "Restart your iPhone")
        case .forceRestartIPhone: return String(localized: "Force restart iPhone")
        case .restartIPad: return String(localized: "Restart your iPad")
        case .forceRestartIPad: return String(localized: "Force restart iPad")
        case .voiceOverIPhone: return String(localized: "Turn on and practice VoiceOver on iPhone")
        case .voiceOverIPad: return String(localized: "Turn on and practice VoiceOver on iPad")
        case .voiceOverWatch: return String(localized: "Use VoiceOver on Apple Watch")
        case .beMyEyesStart: return String(localized: "Getting started with Be My Eyes")
        case .beMyAI: return String(localized: "Be My AI: image-to-text assistance")
        case .hadleyVoiceOver: return String(localized: "Listen with VoiceOver series")
        case .hadleyAppleTV: return String(localized: "Apple TV: VoiceOver Basics")
        case .hadleyLearn: return String(localized: "Learn with Hadley")
        case .iPhoneGuide: return String(localized: "iPhone User Guide")
        case .iPadGuide: return String(localized: "iPad User Guide")
        case .macGuide: return String(localized: "Mac User Guide")
        case .watchGuide: return String(localized: "Apple Watch User Guide")
        case .tvGuide: return String(localized: "Apple TV User Guide")
        case .airPodsGuide: return String(localized: "AirPods User Guide")
        case .homePodGuide: return String(localized: "HomePod User Guide")
        case .visionProGuide: return String(localized: "Apple Vision Pro User Guide")
        case .voiceOverMacGuide: return String(localized: "VoiceOver User Guide for Mac")
        }
    }

    var url: URL {
        let address: String
        switch self {
        case .voiceOverGestures: address = "https://support.apple.com/guide/iphone/use-voiceover-gestures-iph3e2e2281/ios"
        case .brailleCommands: address = "https://support.apple.com/en-us/118665"
        case .brailleDisplay: address = "https://support.apple.com/guide/iphone/use-a-braille-display-iph73b8c43/ios"
        case .brailleScreenInput: address = "https://support.apple.com/guide/iphone/type-braille-on-the-screen-iph10366cc30/ios"
        case .voiceOverKeyboard: address = "https://support.apple.com/guide/iphone/use-voiceover-with-an-external-keyboard-iph6c494dc6/ios"
        case .customizeVoiceOver: address = "https://support.apple.com/guide/iphone/customize-gestures-and-keyboard-shortcuts-iph59a8e6fd2/ios"
        case .zoom: address = "https://support.apple.com/guide/iphone/zoom-in-iph3e2e367e/ios"
        case .magnifier: address = "https://support.apple.com/guide/iphone/magnify-information-iphe867dc99c/ios"
        case .visionFeatures: address = "https://support.apple.com/en-us/111779"
        case .macVoiceOver: address = "https://support.apple.com/guide/voiceover/control-your-mac-with-keyboard-commands-vo2681/mac"
        case .accessibilitySupport: address = "https://support.apple.com/accessibility"
        case .screenshotIPhone: address = "https://support.apple.com/guide/iphone/take-a-screenshot-iphc872c0115/ios"
        case .screenshotIPad: address = "https://support.apple.com/guide/ipad/take-a-screenshot-ipad08a40f3b/ipados"
        case .restartIPhone: address = "https://support.apple.com/en-us/118259"
        case .forceRestartIPhone: address = "https://support.apple.com/guide/iphone/force-restart-iphone-iph8903c3ee6/ios"
        case .restartIPad: address = "https://support.apple.com/en-us/101603"
        case .forceRestartIPad: address = "https://support.apple.com/guide/ipad/force-restart-ipad-ipad9955c007/ipados"
        case .voiceOverIPhone: address = "https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios"
        case .voiceOverIPad: address = "https://support.apple.com/guide/ipad/turn-on-and-practice-voiceover-ipad9a246898/ipados"
        case .voiceOverWatch: address = "https://support.apple.com/guide/watch/use-voiceover-apdaabc79d3b/watchos"
        case .beMyEyesStart: address = "https://support.bemyeyes.com/hc/en-us/articles/360005528557-Getting-started-with-Be-My-Eyes"
        case .beMyAI: address = "https://support.bemyeyes.com/hc/en-us/articles/17493302011921-Be-My-AI-Image-to-text-assistance"
        case .hadleyVoiceOver: address = "https://hadleyhelps.org/workshops/listen-with-voiceover-series"
        case .hadleyAppleTV: address = "https://hadleyhelps.org/workshops/apple-tv-series/apple-tv-voiceover-basics"
        case .hadleyLearn: address = "https://hadleyhelps.org/learn"
        case .iPhoneGuide: address = "https://support.apple.com/guide/iphone/welcome/ios"
        case .iPadGuide: address = "https://support.apple.com/guide/ipad/welcome/ipados"
        case .macGuide: address = "https://support.apple.com/guide/mac-help/welcome/mac"
        case .watchGuide: address = "https://support.apple.com/guide/watch/welcome/watchos"
        case .tvGuide: address = "https://support.apple.com/guide/tv/welcome/tvos"
        case .airPodsGuide: address = "https://support.apple.com/guide/airpods/welcome/web"
        case .homePodGuide: address = "https://support.apple.com/guide/homepod/welcome/homepod"
        case .visionProGuide: address = "https://support.apple.com/guide/apple-vision-pro/welcome/visionos"
        case .voiceOverMacGuide: address = "https://support.apple.com/guide/voiceover/welcome/mac"
        }
        return URL(string: address)!
    }

    enum Provider: Sendable { case apple, beMyEyes, hadley }

    var provider: Provider {
        switch self {
        case .beMyEyesStart, .beMyAI: return .beMyEyes
        case .hadleyVoiceOver, .hadleyAppleTV, .hadleyLearn: return .hadley
        default: return .apple
        }
    }

    /// Whose page it is, as named under the link. Brand names, not
    /// translated.
    var providerName: String {
        switch provider {
        case .apple: return "Apple Support"
        case .beMyEyes: return "Be My Eyes"
        case .hadley: return "Hadley"
        }
    }

    /// The link's label: "Apple's Guide: …", or the organization's name.
    var label: String {
        provider == .apple ? String(localized: "Apple's Guide: \(title)") : "\(providerName): \(title)"
    }

    /// Apple Support's own search, for any Apple question: the safety net
    /// when no hand-picked page fits. A plain link to Apple's search page,
    /// so the person does the browsing (App Review 4.5.1). Checked on
    /// 2026-10-01: /kb/index?page=search works; /search?q= is a 404.
    /// Requested directly (2026-10-01).
    static func appleSupportSearch(_ query: String) -> URL? {
        var components = URLComponents(string: "https://support.apple.com/kb/index")
        components?.queryItems = [URLQueryItem(name: "page", value: "search"), URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    /// What the page covers, for Apple Intelligence to choose by. English
    /// on purpose: the model reads it, people don't.
    var modelDescription: String {
        switch self {
        case .voiceOverGestures: return "touch gestures for VoiceOver on iPhone, such as taps and swipes with one to four fingers"
        case .brailleCommands: return "the list of braille display key commands for VoiceOver on iPhone and iPad, such as opening Control Center or Notification Center"
        case .brailleDisplay: return "connecting and setting up a refreshable braille display with VoiceOver on iPhone"
        case .brailleScreenInput: return "Braille Screen Input: typing braille on the iPhone touchscreen"
        case .voiceOverKeyboard: return "keyboard commands for VoiceOver on iPhone with a Bluetooth or Magic Keyboard"
        case .customizeVoiceOver: return "changing or adding VoiceOver gestures and keyboard shortcuts on iPhone"
        case .zoom: return "the Zoom screen magnifier on iPhone"
        case .magnifier: return "the Magnifier app and its detection features on iPhone"
        case .visionFeatures: return "an overview of iPhone and iPad features for blind and low vision people"
        case .macVoiceOver: return "VoiceOver keyboard commands on a Mac"
        case .accessibilitySupport: return "contacting Apple's accessibility support team by phone or chat"
        case .screenshotIPhone: return "taking a screenshot on iPhone"
        case .screenshotIPad: return "taking a screenshot on iPad"
        case .restartIPhone: return "turning iPhone off and back on, the normal way to restart it"
        case .forceRestartIPhone: return "forcing iPhone to restart when it isn't responding"
        case .restartIPad: return "turning iPad off and back on, the normal way to restart it"
        case .forceRestartIPad: return "forcing iPad to restart when it isn't responding"
        case .voiceOverIPhone: return "turning on VoiceOver on iPhone, the VoiceOver Tutorial, and VoiceOver Practice"
        case .voiceOverIPad: return "turning on VoiceOver on iPad, the VoiceOver Tutorial, and VoiceOver Practice"
        case .voiceOverWatch: return "turning on and using VoiceOver on Apple Watch, its gestures and rotor"
        case .beMyEyesStart: return "getting started with the Be My Eyes app and calling a sighted volunteer"
        case .beMyAI: return "Be My AI in the Be My Eyes app, which describes photos and images"
        case .hadleyVoiceOver: return "free step-by-step audio lessons from Hadley for learning VoiceOver on iPhone and iPad, for beginners"
        case .hadleyAppleTV: return "free beginner lessons from Hadley on using VoiceOver with Apple TV"
        case .hadleyLearn: return "Hadley's free lessons for adults new to vision loss, including technology"
        case .iPhoneGuide: return "the complete iPhone User Guide, for any question about it when no page above fits"
        case .iPadGuide: return "the complete iPad User Guide, for any question about it when no page above fits"
        case .macGuide: return "the complete Mac User Guide for macOS, for any question about it when no page above fits"
        case .watchGuide: return "the complete Apple Watch User Guide, for any question about it when no page above fits"
        case .tvGuide: return "the complete Apple TV User Guide, for any question about it when no page above fits"
        case .airPodsGuide: return "the complete AirPods User Guide, for any question about it when no page above fits"
        case .homePodGuide: return "the complete HomePod User Guide, for any question about it when no page above fits"
        case .visionProGuide: return "the complete Apple Vision Pro User Guide, for any question about it when no page above fits"
        case .voiceOverMacGuide: return "the complete VoiceOver User Guide for Mac, for any question about it when no page above fits"
        }
    }
}
