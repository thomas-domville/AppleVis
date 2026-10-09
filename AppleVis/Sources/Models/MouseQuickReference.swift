import Foundation

/// Exact answers Ask the Mouse can rely on for finger counts and braille
/// dots: each record points at the line in Help that says it, word for
/// word, and the Apple page it was checked against. When a question
/// matches, that Help article is read first and the line is always in
/// what Apple Intelligence reads, so "three-finger double-tap" can't lose
/// to Back Tap, and Help's own search shows the line as a quick answer.
///
/// Only records checked against Apple's documentation are here. The
/// handoff's draft and design-only records were left out on purpose, so
/// nothing unchecked is ever given as an exact command. A record's id
/// never changes; add new ones rather than renaming. `MouseQuickReferenceTests`
/// checks that every line is still in its article. Requested directly
/// (2026-10-09).
struct MouseQuickReference: Identifiable, Sendable, Hashable {

    enum Platform: String, Sendable {
        /// iPhone and iPad: VoiceOver gestures and braille commands are the same.
        case iPhoneAndIPad
        case mac
        /// Apple Watch, Apple TV, or Vision Pro: no records yet, so nothing
        /// for iPhone is offered as their answer.
        case other
    }

    /// Stable id, from the knowledge handoff (2026-10-09).
    let id: String
    let platform: Platform
    /// The Help article holding the answer.
    let articleId: String
    /// The lines that answer it, exactly as Help says them (English source).
    let lines: [String]
    /// The Apple page the answer was checked against.
    let source: String
    let checked: String
    /// Every group needs one of its phrases in the question, after `normalized`.
    let needs: [[String]]
    /// None of these may be in the question.
    var excludes: [String] = []
    /// Answers how to change a command, not what one does.
    var isAboutChanging = false

    var article: HelpArticle? { HelpContent.find(articleId) }

    /// The lines in the person's reading language when Auto-Translate is
    /// on, translated and kept the way Help translates its articles (no
    /// Apple Intelligence needed). English when it's off, or if a line
    /// couldn't be translated. Requested directly (2026-10-09).
    func readableLines(in language: String?) async -> (lines: [String], isTranslated: Bool) {
        guard let language else { return (lines, false) }
        var result = lines
        var missing: [Int] = []
        for (index, line) in lines.enumerated() {
            if let cached = PersistenceStore.shared.cachedTranslation(kind: "quickReference", id: id, field: String(index),
                                                                      targetLanguage: language, sourceText: line) {
                result[index] = cached
            } else {
                missing.append(index)
            }
        }
        if !missing.isEmpty {
            let done = await TranslationCoordinator.shared.translateBatch(missing.map { lines[$0] }, to: language)
            for (offset, index) in missing.enumerated() {
                guard let text = done[offset] else { continue }
                result[index] = text
                PersistenceStore.shared.cacheTranslation(kind: "quickReference", id: id, field: String(index), targetLanguage: language,
                                                         sourceText: lines[index], translatedText: text)
            }
        }
        return (result, result != lines)
    }

    // MARK: - Matching

    /// Lowercased, with gestures written one way: "3-finger double-tap",
    /// "three fingers double tap", "double-tap with three fingers", and the
    /// often-heard "triple finger double tap" all become "three finger
    /// double tap". Braille dots become "dots 4 6".
    /// Common misspellings ("brail", "voice over") are fixed first, the
    /// way the rest of Ask the Mouse matches.
    static func normalized(_ text: String) -> String {
        var s = " " + AskTheMouse.normalizedForMatching(text)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: ".", with: " ") + " "
        let numbers = ["1": "one", "2": "two", "3": "three", "4": "four"]
        for (digit, word) in numbers {
            s = s.replacingOccurrences(of: " \(digit) finger", with: " \(word) finger")
        }
        s = s.replacingOccurrences(of: " fingers ", with: " finger ")
            .replacingOccurrences(of: " single finger", with: " one finger")
            .replacingOccurrences(of: " triple finger", with: " three finger")
            .replacingOccurrences(of: " double finger", with: " two finger")
            .replacingOccurrences(of: " doubletap", with: " double tap")
            .replacingOccurrences(of: " centre", with: " center")
        // "double tap with three finger" → "three finger double tap"
        for count in ["one", "two", "three", "four"] {
            for kind in ["double tap", "triple tap", "quadruple tap", "tap", "swipe up", "swipe down", "swipe left", "swipe right"] {
                s = s.replacingOccurrences(of: " \(kind) with \(count) finger ", with: " \(count) finger \(kind) ")
            }
        }
        // "tap three fingers twice", "tapped 3 fingers 2 times" → "three
        // finger double tap". Found testing new wordings (2026-10-09).
        for count in ["one", "two", "three", "four"] {
            for (times, kind) in [("twice", "double tap"), ("two times", "double tap"), ("2 times", "double tap"),
                                  ("three times", "triple tap"), ("3 times", "triple tap"), ("thrice", "triple tap")] {
                for verb in [" tap", " tapped", " tapping", " taps"] {
                    s = s.replacingOccurrences(of: "\(verb) \(count) finger \(times) ", with: " \(count) finger \(kind) ")
                    s = s.replacingOccurrences(of: "\(verb) with \(count) finger \(times) ", with: " \(count) finger \(kind) ")
                }
                s = s.replacingOccurrences(of: " \(count) finger tap \(times) ", with: " \(count) finger \(kind) ")
            }
        }
        // "dots 4 and 6", "dot 4 6", "4 6 with space" → "dots 4 6"
        s = s.replacingOccurrences(of: " and ", with: " & ")
        let words = s.split(separator: " ").map(String.init)
        var out: [String] = []
        var index = 0
        while index < words.count {
            let word = words[index]
            if word == "dot" || word == "dots" {
                var digits: [String] = []
                var next = index + 1
                while next < words.count {
                    let candidate = words[next]
                    if candidate.count == 1, let value = Int(candidate), (1...8).contains(value) {
                        digits.append(candidate)
                    } else if candidate != "&" {
                        break
                    }
                    next += 1
                }
                if !digits.isEmpty {
                    // Matching text, not shown: one digit is "dot 4", more are "dots 4 6".
                    out.append(["dot", "dots"][min(digits.count, 2) - 1] + " " + digits.joined(separator: " "))
                    index = next
                    continue
                }
            }
            out.append(word == "&" ? "and" : word)
            index += 1
        }
        return " " + out.joined(separator: " ") + " "
    }

    /// The device a question is about: the one it names, else the one an
    /// earlier question in the same topic named, else this device. A new
    /// topic that names a device starts over. "And on my Mac?" keeps the
    /// subject but switches the device for that topic only.
    static func platform(for question: String, earlier: String = "", onMac: Bool = false) -> Platform {
        if let named = namedPlatform(question) { return named }
        if let named = namedPlatform(earlier) { return named }
        return onMac ? .mac : .iPhoneAndIPad
    }

    static func namedPlatform(_ text: String) -> Platform? {
        let s = normalized(text)
        if [" mac ", " macs ", " macbook", " imac", " mac's ", " macos ", " mac mini", " mac studio", " mac pro "].contains(where: s.contains) { return .mac }
        if [" iphone", " ipad", " ios ", " ipados "].contains(where: s.contains) { return .iPhoneAndIPad }
        if [" apple watch", " my watch", " the watch ", " watchos ", " apple tv", " tvos ", " vision pro", " visionos "].contains(where: s.contains) { return .other }
        return nil
    }

    /// The best record for the question, or nil. A follow-up ("how do I
    /// change that?") is matched with the question before it, so it can
    /// find the gesture it's about.
    static func match(_ question: String, earlier: String = "", onMac: Bool = false) -> MouseQuickReference? {
        // "roter" is the rotor (2026-10-09).
        let question = MouseKnowledge.spellingFixed(question)
        let device = platform(for: question, earlier: earlier, onMac: onMac)
        if let own = best(in: normalized(question), platform: device) { return own }
        guard !earlier.isEmpty else { return nil }
        return best(in: normalized(question + " " + earlier), platform: device)
    }

    /// Asking to change a command ("Is there a way to change this
    /// command?" after a braille question): only a record about changing
    /// one may answer. It used to repeat the command itself, Notification
    /// Center's dots. Found testing (2026-10-09).
    private static let changeWords = [" change", " reassign", " customize", " customise", " remap", " assign"]
    private static let commandWords = [" command", " gesture", " shortcut", " key ", " keys "]

    private static func asksToChange(_ text: String) -> Bool {
        changeWords.contains { text.contains($0) } && commandWords.contains { text.contains($0) }
    }

    /// Records that match, most specific first.
    private static func best(in text: String, platform: Platform) -> MouseQuickReference? {
        let changing = asksToChange(text)
        return all.enumerated()
            .filter { _, record in
                record.platform == platform
                    && (!changing || record.isAboutChanging)
                    && !record.excludes.contains { text.contains($0) }
                    && record.needs.allSatisfy { group in group.contains { text.contains($0) } }
            }
            .max { lhs, rhs in
                lhs.element.needs.count != rhs.element.needs.count
                    ? lhs.element.needs.count < rhs.element.needs.count
                    : lhs.offset > rhs.offset
            }?
            .element
    }

    // MARK: - Records

    private static let gestures = "https://support.apple.com/guide/iphone/iph3e2e2281/ios"
    private static let customize = "https://support.apple.com/guide/iphone/iph59a8e6fd2/ios"
    private static let brailleCommands = "https://support.apple.com/118665"
    private static let day = "2026-10-09"
    private static let brailleWords = ["braille", " dot", "display"]

    static let all: [MouseQuickReference] = [
        // Changing a gesture comes first: "how do I change the three-finger
        // double-tap?" is about Touch Gestures, not muting.
        .init(id: "vo.customize", platform: .iPhoneAndIPad, articleId: "howto-vo-gestures",
              lines: ["Open Settings, then Accessibility, then VoiceOver.", "Choose Commands, then Touch Gestures.",
                      "Choose the gesture you want to change.", "Choose what it should do."],
              source: customize, checked: day,
              needs: [[" change", " reassign", " customize", " customise", " assign", " different job", " remap"],
                      [" gesture", " finger", " magic tap"]],
              excludes: [" braille", " zoom"], isAboutChanging: true),
        .init(id: "vo.mute", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Mute or unmute speech: three-finger double-tap. If Zoom is also on, three-finger triple-tap."],
              source: gestures, checked: day,
              needs: [[" three finger double tap", " mute voiceover", " unmute voiceover", " mute speech", " unmute speech"]]),
        .init(id: "vo.curtain", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Turn Screen Curtain on or off: three-finger triple-tap. If Zoom is also on, three-finger quadruple-tap. With Screen Curtain on, the display is dark but everything still works."],
              source: gestures, checked: day,
              needs: [[" three finger triple tap", " screen curtain", " three finger quadruple tap",
                       " screen black", " black screen", " screen go black", " screen is black", " screen dark", " dark screen"]],
              excludes: [" what is screen curtain"]),
        .init(id: "vo.magic-tap", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Play or pause, take a photo, or start or stop a recording or timer: two-finger double-tap. This is called the Magic Tap."],
              source: gestures, checked: day,
              needs: [[" two finger double tap", " magic tap"]]),
        .init(id: "vo.scroll", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Scroll down one page: three-finger swipe up.", "Scroll up one page: three-finger swipe down."],
              source: gestures, checked: day,
              needs: [[" three finger swipe up", " three finger swipe down", " scroll down", " scroll up", " scroll a page", " scroll the page", " scroll with voiceover", " scroll in voiceover"]],
              excludes: [" zoom"]),
        .init(id: "vo.readall", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Read the whole screen from the top: two-finger swipe up.", "Read from the current item onward: two-finger swipe down."],
              source: gestures, checked: day,
              needs: [[" read the whole screen", " read the entire screen", " read from the top", " say all", " two finger swipe up", " two finger swipe down",
                       " everything from the top", " from the top of the screen", " read everything on the screen"]],
              excludes: [" without voiceover", " speak screen", " web", " safari", " twice", " double"]),
        .init(id: "vo.rotor", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Choose a rotor setting: turn two fingers on the screen, like turning a dial."],
              source: gestures, checked: day,
              needs: [[" rotor"]],
              excludes: [" add", " remove", " rotor items", " rotor settings", " what is", " speaking rate", " speech rate",
                         " customize", " customise", " keyboard", " braille", " trackpad"]),
        .init(id: "vo.next", platform: .iPhoneAndIPad, articleId: "ref-voiceover-gestures",
              lines: ["Next item: swipe right.", "Previous item: swipe left."],
              source: gestures, checked: day,
              needs: [[" next item", " previous item", " move to the next", " move to the previous"]],
              excludes: brailleWords + [" keyboard", " arrow", " keys", " trackpad"]),
        .init(id: "braille.notification", platform: .iPhoneAndIPad, articleId: "ref-braille-display",
              lines: ["Notification Center: Space with dots 4-6."],
              source: brailleCommands, checked: day,
              needs: [brailleWords, [" notification center", " notifications"]]),
        .init(id: "braille.control", platform: .iPhoneAndIPad, articleId: "ref-braille-display",
              lines: ["Control Center: Space with dots 2-5."],
              source: brailleCommands, checked: day,
              needs: [brailleWords, [" control center"]]),
        .init(id: "braille.next", platform: .iPhoneAndIPad, articleId: "ref-braille-display",
              lines: ["Next item: Space with dot 4.", "Previous item: Space with dot 1."],
              source: brailleCommands, checked: day,
              needs: [brailleWords, [" next item", " previous item", " move to the next", " move to the previous"]]),
        .init(id: "braille.first-last", platform: .iPhoneAndIPad, articleId: "ref-braille-display",
              lines: ["First item: Space with dots 1-2-3.", "Last item: Space with dots 4-5-6."],
              source: brailleCommands, checked: day,
              needs: [brailleWords, [" first item", " last item", " top of the screen", " bottom of the screen"]]),
        .init(id: "braille.access", platform: .iPhoneAndIPad, articleId: "howto-braille-access",
              lines: ["On a Perkins-style keyboard: press dots 7 and 8 together. With an eight-dot braille table, press Space with them."],
              source: "https://support.apple.com/guide/iphone/iph5953d3c7a/ios", checked: day,
              needs: [[" braille access"], [" open", " turn on", " toggle", " start", " get to", " get into", " launch"]],
              excludes: [" pdf", " file", " notes", " calculator", " captions", " brf"]),
        .init(id: "vision.zoom", platform: .iPhoneAndIPad, articleId: "howto-zoom",
              lines: ["Open Settings, then Accessibility, then Zoom, and turn on Zoom.", "Double-tap with three fingers to zoom in or out."],
              source: "https://support.apple.com/guide/iphone/iph3e2e367e/ios", checked: day,
              needs: [[" turn on zoom", " use zoom", " magnify the screen", " magnify my screen", " everything bigger", " everything larger", " whole screen bigger", " screen bigger", " zoom in on the screen",
                       " too small", " can t see the screen", " cant see the screen"]],
              excludes: [" zoom app", " zoom meeting", " zoom call", " text", " letters", " font", " braille"]),
        .init(id: "vision.text", platform: .iPhoneAndIPad, articleId: "howto-text-size",
              lines: ["Choose Larger Text."],
              source: "https://support.apple.com/guide/iphone/iph3c076905a/ios", checked: day,
              needs: [[" text bigger", " bigger text", " larger text", " text size", " font size", " text larger", " letters bigger",
                       " bigger letters", " larger letters", " text is too small", " text too small", " letters are too small", " font bigger", " bigger font"]],
              excludes: [" braille"]),
        .init(id: "vision.speak-screen", platform: .iPhoneAndIPad, articleId: "howto-speak-screen",
              lines: ["Turn on Speak Screen. Then swipe down from the top of the screen with two fingers to hear the whole screen."],
              source: "https://support.apple.com/guide/iphone/iph96b214f0/ios", checked: day,
              needs: [[" speak screen", " without voiceover"], [" read", " speak", " hear", " aloud"]]),
        // From Help's Quick Reference, checked against Apple's VoiceOver
        // commands for Mac on 2026-10-04.
        .init(id: "mac.rotor", platform: .mac, articleId: "ref-voiceover-keyboard-mac",
              lines: ["Open the rotor: VO-U."],
              source: "https://support.apple.com/guide/voiceover/general-commands-cpvokys01/mac", checked: "2026-10-04",
              needs: [[" rotor"]],
              excludes: [" trackpad"]),
        .init(id: "mac.voiceover.modifier", platform: .mac, articleId: "ref-voiceover-keyboard-mac",
              lines: ["VO stands for the VoiceOver modifier: Control and Option pressed together, or Caps Lock. For example, VO-Right Arrow means hold the modifier, then press Right Arrow."],
              source: "https://support.apple.com/guide/voiceover/vo2681/mac", checked: day,
              needs: [[" vo key", " vo keys", " vo modifier", " voiceover modifier", " vo mean", " vo stand"]]),
    ]
}
