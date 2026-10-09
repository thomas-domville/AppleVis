import Foundation

/// Everything Ask the Mouse can search on the device: Help, What's New,
/// Tips, and the person's own saved items, plus the fixed lists of places
/// it can open ("Take me there") and switches it can flip ("Change it for
/// me"). The model only ever picks from these lists; it never makes up a
/// screen or a setting. Requested directly (2026-09-28).
enum MouseKnowledge {

    // MARK: - Words

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "but", "by", "can", "do", "does", "for", "from",
        "get", "has", "have", "how", "i", "if", "in", "is", "it", "its", "me", "my", "of", "on",
        "or", "so", "that", "the", "their", "there", "this", "to", "was", "what", "when", "where",
        "which", "who", "why", "will", "with", "you", "your", "about", "any", "there's", "i'm",
        "want", "would", "could", "should", "please", "tell", "find", "show", "some", "one",
    ]

    /// Lowercased, with "Wi-Fi", "Wi Fi", and "wifi" as one word: Help
    /// says Wi-Fi and people type wifi, so "connect to wifi at a hotel"
    /// found nothing. Found testing (2026-10-09).
    static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"\bwi[- ]fi\b"#, with: "wifi", options: .regularExpression)
    }

    /// Lowercased search words with common filler removed.
    static func terms(_ text: String) -> [String] {
        let words = normalized(text)
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { $0.count >= 2 && !stopWords.contains($0) }
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    /// Words nearly every article has. When the question has a subject of
    /// its own, they count for half: "How do I set an alarm with VoiceOver?"
    /// found articles with VoiceOver in the title before the alarm one, and
    /// "AppleVis" in a question favored every AppleVis article. Found
    /// testing 160 new questions (2026-10-09).
    private static let weakWords: Set<String> = ["voiceover", "iphone", "ipad", "applevis", "app", "apps", "use", "using"]

    /// The word without a common ending, so "deleting", "transcripts", and
    /// "funded" find "delete", "transcript", and "funds" (2026-10-09).
    static func stem(_ word: String) -> String {
        guard word.count > 4 else { return word }
        for suffix in ["ing", "ed", "es", "s"] where word.hasSuffix(suffix) && word.count - suffix.count >= 4 {
            return String(word.dropLast(suffix.count))
        }
        return word.hasSuffix("e") ? String(word.dropLast()) : word
    }

    /// How many words in `text` start with `stem`, up to `cap`. Only at the
    /// start of a word, so "thing" isn't found inside "something".
    private static func wordStarts(of stem: String, in text: String, cap: Int) -> Int {
        guard !stem.isEmpty else { return 0 }
        var count = 0
        var rest = text.startIndex..<text.endIndex
        while count < cap, let found = text.range(of: stem, range: rest) {
            if found.lowerBound == text.startIndex {
                count += 1
            } else {
                let before = text[text.index(before: found.lowerBound)]
                if !before.isLetter && !before.isNumber { count += 1 }
            }
            rest = found.upperBound..<text.endIndex
        }
        return count
    }

    /// How well `text` matches. Title hits count most, then the summary,
    /// then the body (capped so a long article can't win on length alone).
    /// A whole phrase appearing counts extra.
    static func score(title: String, summary: String = "", body: String = "", terms: [String], phrases: [String] = []) -> Int {
        let title = normalized(title), summary = normalized(summary), body = normalized(body)
        var total = 0
        let hasSubject = terms.contains { !weakWords.contains($0) }
        for term in terms {
            let weak = hasSubject && weakWords.contains(term)
            let root = stem(term)
            if wordStarts(of: root, in: title, cap: 1) > 0 { total += weak ? 3 : 6 }
            if wordStarts(of: root, in: summary, cap: 1) > 0 { total += weak ? 1 : 3 }
            total += wordStarts(of: root, in: body, cap: weak ? 2 : 3)
        }
        for phrase in phrases.map({ $0.lowercased() }) where phrase.contains(" ") {
            if title.contains(phrase) { total += 8 }
            if summary.contains(phrase) || body.contains(phrase) { total += 4 }
        }
        return total
    }

    // MARK: - Help

    /// Names people can't be expected to guess, pointing at the article
    /// that explains them.
    private static let nicknames: [String: [String]] = [
        // AppleVis's own side-by-side layout, so "move to the topic beside
        // the list" isn't taken for moving an app (2026-10-08).
        "start-ipad-duo": ["beside the list", "next to the list", "side by side"],
        // "The three things at the bottom of my screen" is about what's on
        // the screen, not the iPhone's bottom edge. The Mouse can't see the
        // screen; AppleVis's own tabs are the likeliest answer, and the
        // answer says it can't see (2026-10-09).
        // Forum questions members actually asked (2026-10-09), and the
        // articles written for the ones Help didn't cover.
        "howto-sign-pdf": ["sign a pdf", "signing a pdf", "sign a document", "signing a document", "sign papers", "signing papers", "signature", "fill in a form", "fill out a form", "fill in a pdf"],
        "howto-duplicate-contacts": ["duplicate contact", "merge contacts", "merge duplicate", "contacts twice", "same contact twice"],
        "howto-time-format": ["24 hour", "24-hour", "12 hour", "12-hour", "military time"],
        "howto-group-chat-name": ["group text", "group chat", "group message", "group conversation", "name a group", "label a group", "labeling a group", "labelling a group"],
        "howto-share-name-photo": ["my name and photo", "name not showing", "name isn't showing", "name doesn't show", "share my name", "contact poster", "see my name"],
        "howto-files-cloud": ["dropbox", "google drive", "onedrive", "icloud drive", "files app", "sync a folder", "syncing a folder", "transfer files", "transferring files", "move files", "folder synced", "keep a folder", "synced between", "sync between my mac"],
        "howto-iphone-mirroring": ["iphone mirroring", "mirror my iphone", "mirroring my iphone", "control my iphone from my mac", "use my iphone from my mac"],
        "howto-passwords": ["verification code", "codes from text", "code from a text", "one-time code", "one time code", "passkey", "2fa code", "security code"],
        "howto-keyboard-language": ["emoji", "emojis"],
        "community-edit-profile": ["my applevis account", "applevis account changes", "change my applevis account"],
        // Wording from 160 new questions (2026-10-09): plain titles that skip the jargon people use.
        "howto-shareplay": ["shareplay", "share play", "share my screen", "screen share", "screen sharing"],
        "howto-vo-audio-ducking": ["audio ducking", "ducking", "music gets quieter", "music getting quieter", "music quieter"],
        "howto-vo-activities": ["voiceover activities", "voiceover activity", "different settings in different apps"],
        "howto-airpods-controls": ["airpods controls", "airpod controls", "press my airpods", "squeeze my airpods", "airpods stem controls"],
        "howto-autocorrect": ["autocorrect", "auto correct", "auto-correct", "predictive text", "changing my words", "changes my words"],
        "howto-bluetooth-trouble": ["won't connect", "wont connect", "not connecting", "won't pair", "wont pair"],
        "howto-airplay": ["stream to my apple tv", "stream to apple tv", "airplay", "cast to"],
        "howto-vo-verbosity": ["say less", "talks too much", "talk less", "speak less", "too chatty", "less chatty"],
        "howto-app-transcript": ["transcript"],
        "howto-app-contact": ["bug in the applevis app", "problem with the applevis app", "applevis app bug", "applevis app isn't working", "applevis app not working"],
        "community-language-filter": ["masked", "with stars", "asterisk", "bleeped", "censored", "swear"],
        // Odd wordings, typos, and plain words from the fifth batch (2026-10-09).
        "howto-announce-notifications": ["read my texts", "read my messages", "read my text messages", "read incoming", "read messages to me"],
        "howto-app-ai-off": ["turn off the mouse", "hide the mouse", "turn off ask the mouse", "don't want the mouse", "dont want the mouse"],
        "howto-app-play-episode": ["newest podcast", "latest podcast", "latest episode", "newest episode"],
        "community-guidelines": ["rules for posting", "posting rules", "the rules", "allowed to post", "what can i post"],
        "howto-wifi-join": ["connect to wifi", "join wifi", "wifi at a", "hotel wifi", "public wifi", "wifi password at"],
        "howto-airdrop": ["send a photo to", "send photos to", "send a file to", "send files to"],
        "howto-braille-connect": ["focus 40", "focus 14", "focus blue", "brailliant", "mantis", "orbit reader", "chameleon"],
        "howto-flashlight": ["flashlight", "flash light", "torch"],
        "start-tabs": ["bottom of the screen", "bottom of my screen", "tab bar", "tabs at the bottom", "three tabs", "buttons at the bottom of the screen", "things at the bottom"],
        // How-To Library (2026-10-08): the words people use, which aren't
        // always the article's. Checked with test_howto_questions.py.
        "howto-home-move-app": ["rearrange", "move app", "move apps", "move an app", "reorder app", "organize app", "organise app"],
        "howto-home-hide-app": ["hidden app", "hide app", "hide an app"],
        "howto-home-find-app": ["find an app", "can't find an app", "cant find an app", "missing app", "app disappeared", "app is gone"],
        "howto-hotspot": ["hotspot", "hot spot", "tether"],
        "howto-silent-mode": ["silent", "mute my phone", "mute the ringer", "vibrate only", "on vibrate", "vibrate mode", "vibrate"],
        "howto-emergency": ["medical id", "emergency contact"],
        "howto-vo-speaking-rate": ["talk faster", "talk slower", "speak faster", "speak slower", "speech rate", "speaking rate", "voiceover faster", "voiceover slower", "talking too fast", "talks too fast", "talking too slow", "talks too slow", "slow down voiceover", "speed up voiceover"],
        "howto-vo-voice": ["voiceover voice", "different voice", "change the voice", "change voice", "new voice", "siri voice for voiceover", "old siri voice", "enhanced voice", "premium voice", "downloaded voice", "remove a voice", "delete a voice", "delete voices", "remove voices", "downloading voices", "download a voice"],
        "howto-vo-hints": ["double tap to open", "double-tap to open", "hints", "stop saying double"],
        "howto-vo-image-explorer": ["describe a picture", "describe a photo", "describe an image", "describe the picture", "describe the image", "question about a photo", "question about an image", "question about a picture", "image recognition", "image explorer", "describe the screen"],
        "howto-vo-live-recognition": ["what my camera", "camera is looking", "camera sees", "live recognition", "ask a question action button"],
        "howto-vo-typing-style": ["typing mode", "typing style", "direct touch typing"],
        "howto-braille-commands": ["change braille command", "change a braille command", "change this command", "change the command", "reassign braille", "braille key assignment"],
        "howto-braille-trouble": ["braille display keeps", "braille display won't", "braille display wont", "braille display disconnect", "braille display drops"],
        "howto-color-filters": ["grayscale", "greyscale", "color filter", "colour filter", "black and white screen"],
        "howto-reduce-motion": ["reduce motion", "screen moving", "motion sick", "animations"],
        "howto-speak-screen": ["read the screen to me", "read aloud without voiceover", "speak screen", "speak selection", "read it to me"],
        "howto-auto-captions": ["subtitles", "captions on video", "captions on my video", "automatic captions", "caption my video"],
        "howto-live-captions": ["live captions"],
        "howto-sound-recognition": ["doorbell", "smoke alarm", "sound recognition", "baby crying", "hear the door"],
        "howto-text-replacement": ["text replacement", "text shortcut", "type a phrase"],
        "howto-dictation": ["dictate", "dictation", "speak to type", "voice typing"],
        "howto-writing-tools": ["proofread", "writing tools", "rewrite my", "check my spelling"],
        "howto-apple-pay": ["apple pay", "pay with my iphone", "pay with my phone", "contactless"],
        "howto-low-power": ["low power", "battery last", "save battery", "charging limit"],
        "howto-storage": ["storage", "out of space", "free up space", "running out of space"],
        "howto-find-my": ["lost my", "find my app", "find my airpods", "find my iphone", "find my ipad", "find my watch", "find my mac", "find my network", "where is my iphone", "where is my phone", "where are my airpods", "use find my"],
        "howto-watch-voiceover": ["voiceover on my apple watch", "voiceover on apple watch", "voiceover on my watch"],
        "howto-tv-voiceover": ["voiceover on apple tv", "voiceover on my apple tv"],
        // AppleVis's own settings (2026-10-08).
        "howto-av-theme": ["theme", "goldie theme", "mouse theme", "high contrast theme", "dark theme", "app dark", "make the app dark", "dark mode in applevis", "app darker", "applevis dark"],
        "howto-av-sounds": ["sounds in applevis", "applevis sounds", "turn off the sounds", "confirmation sounds", "interface sounds", "make noises", "makes noises", "noises", "beeps", "clicking sounds"],
        "howto-av-haptics": ["haptics in applevis", "haptic feedback", "turn off haptics", "vibrations in applevis", "app vibrating", "app vibrates", "stop the app vibrating", "applevis vibrat"],
        "howto-av-welcome": ["welcome message", "welcome when", "startup behavior", "home startup", "stop the welcome"],
        "howto-av-apple-only": ["non-apple", "non apple", "apple topics only", "only apple topics"],
        "howto-av-reminders": ["catch-up reminder", "catch up reminder", "catchup reminder"],
        "howto-av-notification-sound": ["notification sound for applevis", "applevis notification sound", "mouse squeak", "apple crunch"],
        "howto-av-podcast": ["skip time", "skip forward", "skip back", "podcast speed", "playback speed", "play faster", "play slower", "speed up the podcast", "slow down the podcast", "faster podcast"],
        "howto-apple-account-sign-out": ["apple account", "apple id", "icloud account"],
        "howto-home-rename-app": ["rename an app", "rename app", "change an app's name", "change the name of an app"],
        "howto-app-where": ["where is everything", "where everything is", "find my way around", "map of the app"],
        "howto-app-last-comment": ["last comment", "latest comment", "end of the thread", "end of a thread", "bottom of the thread"],
        "howto-app-share": ["share a topic", "share a forum topic", "share a post", "share an episode", "share a link", "send a link"],
        "howto-app-check-app": ["app is accessible", "app accessible", "is the app accessible", "accessible with voiceover", "app works with voiceover"],
        "howto-app-own-language": ["in spanish", "in french", "in german", "read applevis in", "translate posts", "translate comments"],
        "howto-app-sync": ["between my iphone and ipad", "between devices", "all my devices", "sync my saved", "sync saved", "icloud sync"],
        "howto-app-free-space": ["applevis is using", "space used by applevis", "applevis storage", "storage used by applevis", "applevis taking up"],
        "content-apps": ["get a mac app", "download a mac app", "developer's website"],
        "start-what-is-applevis": ["who owns applevis", "who runs applevis", "who controls applevis", "is applevis independent", "who funds applevis", "owned by be my eyes", "nonprofit", "non-profit", "not for profit", "be my eyes foundation", "donate to applevis", "support applevis", "who founded applevis", "funds applevis", "need an account", "without an account", "without signing in", "need to sign in", "how is applevis funded", "who pays for applevis", "is applevis free", "applevis cost", "does applevis cost", "pay for applevis", "who started applevis", "started applevis"],
        "howto-av-sign-out": ["sign out of applevis", "log out of applevis", "sign out of the app", "log out of the app"],
        "howto-av-open-settings": ["applevis settings", "open settings in applevis"],
        // Device guides: "where do I start?" (2026-10-08).
        "guide-iphone": ["new to iphone", "new iphone user", "getting started with iphone", "learn iphone", "learn voiceover", "beginner", "just got an iphone", "start with voiceover", "where to start", "don't know where to start", "dont know where to start", "new to this"],
        "guide-ipad": ["getting an ipad", "buying an ipad", "buy an ipad", "new to ipad", "getting started with ipad", "learn ipad", "just got an ipad"],
        "guide-mac": ["first mac", "buying a mac", "buy a mac", "new to mac", "getting started with mac", "learn mac", "just got a mac", "voiceover on mac", "got a new mac", "new mac what now"],
        "guide-watch": ["new to apple watch", "getting started with apple watch", "just got an apple watch", "learn apple watch"],
        "guide-tv": ["new to apple tv", "getting started with apple tv", "just got an apple tv"],
        // Know Your Device: "what's this?" questions (2026-10-08).
        "howto-know-side-buttons": ["buttons on the side", "button on the side", "side buttons", "buttons on my iphone", "what are the buttons", "what is this button", "what's this button", "what button"],
        "howto-know-action-button": ["action button"],
        "howto-know-camera-control": ["camera control", "button on the bottom right", "flat button"],
        "howto-know-camera-bumps": ["bumps", "bump on the back", "round things on the back", "circles on the back", "camera lenses", "lenses on the back"],
        "howto-know-small-holes": ["small hole", "smaller bump", "little hole", "tiny hole", "small circle", "lidar", "flash on the back"],
        "howto-know-bottom-edge": ["bottom edge", "bottom of my iphone", "bottom of my phone", "holes on the bottom", "three things", "charging port", "speaker holes"],
        "howto-know-front": ["dynamic island", "earpiece", "notch", "top of the screen", "front camera"],
        "howto-know-magsafe": ["magsafe", "magnet", "qi2"],
        "howto-know-charging": ["charge my iphone", "charge my phone", "how do i charge", "wireless charging", "wireless charger"],
        "howto-know-sim": ["sim card", "sim tray", "sim slot"],
        "howto-know-edge-lines": ["lines on the edge", "lines on the side", "antenna", "strips on the edge"],
        "howto-know-which-iphone": ["which iphone", "what iphone do i have", "model name", "what model"],
        "howto-know-airpods": ["airpods case", "case button", "light on my airpods", "the stem", "airpods stem"],
        "howto-know-watch": ["digital crown", "buttons on my apple watch", "buttons on my watch", "watch buttons"],
        "howto-know-tv-remote": ["apple tv remote", "siri remote", "remote buttons", "buttons on the remote"],
        // Quick Reference (2026-10-04).
        "ref-voiceover-gestures": ["voiceover gesture", "gestures", "magic tap", "rotor", "scrub", "split tap", "screen curtain", "item chooser", "go back with voiceover", "go back in voiceover", "back gesture", "scroll with voiceover", "scroll down with voiceover", "how do i double tap", "what is double tap", "what is a double tap"],
        "ref-voiceover-keyboard-ios": ["keyboard command", "keyboard shortcut", "magic keyboard", "external keyboard", "quick nav", "vo key"],
        "ref-braille-display": ["braille command", "braille display", "braille key", "dots", "perkins", "pan braille"],
        "ref-voiceover-keyboard-mac": ["mac voiceover", "voiceover on mac", "vo key", "voiceover utility", "command f5"],
        "ref-voiceover-trackpad-mac": ["trackpad", "trackpad gesture", "trackpad commander"],
        "ref-restart-iphone-ipad": ["force restart", "restart iphone", "restart ipad", "frozen", "not responding", "recovery mode", "restore iphone", "won't turn on", "hard reset", "reboot", "turn off my iphone", "turn off iphone", "turn off my ipad", "turn off ipad", "power off my iphone", "power off iphone", "shut down iphone", "shut down my iphone", "slide to power off"],
        "ref-restart-mac": ["macos recovery", "restart mac", "restart my mac", "force shut down", "reinstall macos", "mac frozen", "turn off my mac", "shut down my mac"],
        "ref-voiceover-watch": ["apple watch voiceover", "watch gestures", "digital crown navigation", "hand gestures"],
        "ref-voiceover-tv": ["apple tv voiceover", "tv remote", "exploration mode", "navigation mode", "clickpad"],
        "ref-braille-display-mac": ["mac braille", "braille on mac", "braille display mac"],
        "ref-accessibility-shortcut": ["accessibility shortcut", "triple click", "triple-click", "turn on voiceover", "turn off voiceover", "turn voiceover off", "turn voiceover on", "back tap", "double tap everything", "have to double tap", "turned on by accident", "accidentally turned", "turned it on by accident"],
        "ref-setup-voiceover": ["set up with voiceover", "setup voiceover", "new iphone", "new mac", "pair apple watch", "first time setup"],
        "ref-glossary": ["glossary", "definition of", "perkins keyboard", "perkins-style", "what is braille access", "what is live recognition", "what is the rotor", "what is magic tap", "what is screen curtain", "what is quick nav", "contracted braille", "grade 2", "grade 1", "golden apple"],
        "ref-voiceover-silent": ["reset voiceover", "everything twice", "reading twice", "reads twice", "says twice", "speaks twice", "speaking twice", "talking twice", "speaking double", "speaks double", "voiceover stopped", "not talking", "no speech", "voiceover silent", "voiceover is silent", "screen is black", "screen black", "voiceover quiet", "can't hear voiceover", "went dark", "gone dark", "went black", "gone black", "cant hear voiceover", "cant here voiceover", "can't here voiceover", "wont stop talking", "won't stop talking"],
        "ref-low-vision": ["low vision", "zoom", "magnify", "bigger text", "larger text", "speak screen", "read aloud", "out loud", "read my email", "read my emails", "read & speak", "read the screen", "read my screen", "without voiceover", "text bigger", "see the screen"],
        "ref-typing-voiceover": ["typing", "type faster", "touch typing", "braille screen input", "bsi", "braille on the screen", "braille on screen", "type braille", "dictation", "text selection", "edit text", "copy text", "copying text", "copy and paste", "paste text", "selecting text", "select text"],
        "ref-recognition": ["describe image", "image description", "live recognition", "screen recognition", "door detection", "point and speak", "describe photo", "doors", "around me", "surroundings", "describe what", "what's in front", "describe the", "in front of me"],
        "ref-web-voiceover": ["safari", "webpage", "web page", "browse the web", "browsing the web", "reader view", "web rotor"],
        "ref-siri-phrases": ["hey siri", "ask siri", "siri commands", "siri requests", "voice commands"],
        "ref-iphone-everyday-voiceover": ["unlock", "home screen", "app switcher", "answer call", "camera voiceover", "take a photo", "take a picture", "camera with voiceover", "face id", "require attention", "arrange apps", "during a call", "on a call", "while on a call", "in a call"],
        "ref-mac-essentials": ["mac shortcut", "mac keyboard shortcut", "windows user", "switching from windows", "spotlight on mac", "mac spotlight", "force quit", "lock my mac", "locking my mac", "lock the mac", "lock the screen on my mac", "unlock my mac", "unlocking my mac"],
        "ref-getting-help": ["contact apple", "apple support", "accessibility support", "apple phone number", "call apple", "feedback to apple", "report to apple", "accessibility@apple.com", "person at apple", "talk to apple", "speak to someone at apple", "phone at apple", "talk to someone at apple"],
        "ref-updating": ["software update", "update my iphone", "update my ipad", "update ios", "ios update", "backup", "back up", "new ios", "after the update", "after updating"],
        "ref-restart-watch-airpods-tv": ["reset airpods", "restart airpods", "airpods max", "force restart watch", "restart apple watch", "restart apple tv", "turn off my apple watch", "turn off apple watch", "turn off my watch", "power off my apple watch", "power off apple watch", "power off my watch", "restart my watch"],
        "home-fetch": ["reading view", "goldie", "read everything", "grouped reading"],
        "home-whats-new": ["nibbles", "recap", "weekly summary", "monthly summary", "digest", "mouse recap"],
        "tutorial-post": ["plus button", "add button", "post button", "new topic", "start a topic"],
        "community-submit-blog": ["write a blog", "post a blog", "blog post", "submit a blog"],
        "community-submit-app": ["add an app", "new app entry", "submit an app"],
        "community-submit-podcast": ["submit a podcast", "send a podcast", "audio file"],
        "community-submit-bug": ["report a bug", "bug report", "feedback assistant"],
        "trouble-sign-in": ["can't sign in", "cannot log in", "password", "log in", "login", "signed out"],
    ]

    /// Words that mean a nickname isn't about that article after all.
    private static let nicknameExcludes: [String: [String]] = [
        "howto-know-bottom-edge": ["screen"],
        // "Focus 40" is a braille display, not Focus (2026-10-09).
        "howto-focus": ["focus 40", "focus 14", "focus blue"],
    ]

    // MARK: - Spelling

    /// Nicknames match without apostrophes: "whats in front of me" finds
    /// "what's in front".
    private static func nicknameText(_ text: String) -> String {
        normalized(text).replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
    }

    /// Every word Help and its nicknames use.
    private static let vocabulary: Set<String> = {
        var words = Set<String>()
        func add(_ text: String) {
            for word in normalized(text).components(separatedBy: CharacterSet.alphanumerics.inverted) where word.count >= 3 {
                words.insert(word)
            }
        }
        for article in allHelpArticles {
            add(article.title)
            add(article.summary)
            add(helpArticleText(article))
        }
        nicknames.values.forEach { $0.forEach(add) }
        return words
    }()

    /// The question with a misspelled word replaced by the one Help word a
    /// letter away, when there's exactly one: "evrything", "roter", and
    /// "magnifyer" found nothing. A capitalized word after the first is
    /// left alone, since it's likely a name, like Sonos. Found testing odd
    /// wordings (2026-10-09).
    static func spellingFixed(_ text: String) -> String {
        var result = ""
        var word = ""
        var isFirst = true
        func flush() {
            guard !word.isEmpty else { return }
            let lower = word.lowercased()
            if isFirst || word == lower {
                let fixed = correction(lower)
                result += fixed != lower ? fixed : word
            } else {
                result += word
            }
            isFirst = false
            word = ""
        }
        for character in text {
            if character.isLetter || character.isNumber || character == "'" {
                word.append(character)
            } else {
                flush()
                result.append(character)
            }
        }
        flush()
        return result
    }

    private static func correction(_ word: String) -> String {
        guard word.count >= 5, !vocabulary.contains(word), word.allSatisfy(\.isLetter) else { return word }
        let near = vocabulary.filter { oneLetterApart(word, $0) }
        return near.count == 1 ? near.first ?? word : word
    }

    /// One letter added, left out, or changed.
    private static func oneLetterApart(_ first: String, _ second: String) -> Bool {
        let a = Array(first), b = Array(second)
        guard a != b, abs(a.count - b.count) <= 1 else { return false }
        if a.count == b.count {
            return zip(a, b).filter { $0 != $1 }.count == 1
        }
        let (short, long) = a.count < b.count ? (a, b) : (b, a)
        var i = 0, j = 0, skipped = false
        while i < short.count, j < long.count {
            if short[i] == long[j] {
                i += 1
                j += 1
            } else {
                if skipped { return false }
                skipped = true
                j += 1
            }
        }
        return true
    }

    static func helpArticleText(_ article: HelpArticle) -> String {
        article.content.map { block -> String in
            switch block {
            case .heading(let text), .body(let text), .tip(let text), .note(let text), .warning(let text):
                return text
            case .bullets(let items), .steps(let items):
                return items.joined(separator: "\n")
            case .faq(let question, let answer):
                return question + "\n" + answer
            case .source(let label, _):
                return label
            }
        }.joined(separator: "\n")
    }

    /// An article as lines for Ask the Mouse to choose passages from.
    /// Each bullet or step carries its heading, so a line picked on its own
    /// still says what it's about: "Apple Watch: Turn off: press and hold
    /// the side button…", not just "Turn off: …". Headings aren't lines of
    /// their own, since a bare "Braille" or "Control VoiceOver" picked
    /// without its content only crowded out real answers. Links are left
    /// out; the Mouse shows the article itself as the source. Found testing
    /// Quick Reference questions (2026-10-05).
    static func helpPassageText(_ article: HelpArticle) -> String {
        var heading = ""
        var lines: [String] = []
        for block in article.content {
            switch block {
            case .heading(let text):
                heading = text
            case .body(let text), .tip(let text), .note(let text), .warning(let text):
                lines.append(heading.isEmpty ? text : "\(heading): \(text)")
            case .bullets(let items):
                lines += items.map { heading.isEmpty ? $0 : "\(heading): \($0)" }
            case .steps(let items):
                lines += items.enumerated().map { index, item in
                    let step = "Step \(index + 1). \(item)"
                    return heading.isEmpty ? step : "\(heading): \(step)"
                }
            case .faq(let question, let answer):
                lines.append(question + " " + answer)
            case .source:
                break
            }
        }
        return lines.joined(separator: "\n")
    }

    static var allHelpArticles: [HelpArticle] {
        HelpContent.sections.flatMap(\.articles)
    }

    /// Help articles ranked by how well they match, best first.
    static func searchHelp(_ query: String, phrases: [String] = [], limit: Int = 3) -> [HelpArticle] {
        let query = spellingFixed(query)
        let words = terms(([query] + phrases).joined(separator: " "))
        guard !words.isEmpty else { return [] }
        let lowerQuery = nicknameText(query)
        let scored: [(HelpArticle, Int)] = allHelpArticles.map { article in
            var value = score(title: article.title, summary: article.summary, body: helpArticleText(article), terms: words, phrases: [query] + phrases)
            // A nickname is a person's choice of article, so it outweighs a
            // strong title match on common words: "read my texts to me" lost
            // to "Read Printed Text" at 12 (2026-10-09).
            if let names = nicknames[article.id], names.contains(where: { lowerQuery.contains(nicknameText($0)) }),
               !(nicknameExcludes[article.id] ?? []).contains(where: { lowerQuery.contains(nicknameText($0)) }) { value += 16 }
            return (article, value)
        }
        // Needs more than a single stray body hit to count as a match.
        return scored.filter { $0.1 >= 4 }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    /// Help's own search field: the same ranking, grouped back into sections
    /// in their usual order. Used to match titles and summaries only, so
    /// anything mentioned only in an article's text couldn't be found.
    static func filterHelpSections(_ query: String) -> [HelpSection] {
        let trimmed = spellingFixed(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else { return HelpContent.sections }
        let lower = trimmed.lowercased()
        let words = terms(trimmed)
        return HelpContent.sections.compactMap { section in
            if section.title.lowercased().contains(lower) { return section }
            let matching = section.articles.filter { article in
                if article.title.lowercased().contains(lower) || article.summary.lowercased().contains(lower) { return true }
                if helpArticleText(article).lowercased().contains(lower) { return true }
                guard !words.isEmpty else { return false }
                let text = (article.title + " " + article.summary + " " + helpArticleText(article)).lowercased()
                return words.allSatisfy { text.contains($0) }
            }
            guard !matching.isEmpty else { return nil }
            return HelpSection(id: section.id, title: section.title, icon: section.icon, description: section.description, articles: matching)
        }
    }

    /// The parts of an article that best match, trimmed to fit what the
    /// on-device model can read at once.
    static func bestPassages(in text: String, terms: [String], maxCharacters: Int) -> String {
        let paragraphs = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !paragraphs.isEmpty else { return "" }
        let ranked = paragraphs.enumerated().map { index, paragraph in
            (index, score(title: "", body: paragraph, terms: terms))
        }
        let chosen = ranked.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map(\.0)
        // Matching lines first, then the rest from the top to fill any room
        // left. When only a line or two matched, the rest of the space went
        // unused, and an article's opening steps, usually the most
        // important, were left out. Found testing (2026-10-05).
        let order = chosen + paragraphs.indices.filter { !chosen.contains($0) }
        var picked: [Int] = []
        var length = 0
        for index in order {
            let paragraph = paragraphs[index]
            if length + paragraph.count > maxCharacters { continue }
            picked.append(index)
            length += paragraph.count + 1
        }
        // Keep the article's own order so steps still read in sequence.
        return picked.sorted().map { paragraphs[$0] }.joined(separator: "\n")
    }

    /// The single paragraph (or line, for lists and tables) that best
    /// matches, for landing on it when the page opens.
    static func bestParagraph(in text: String, terms: [String]) -> String? {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 12 }
        return lines.map { ($0, score(title: "", body: $0, terms: terms)) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
    }

    /// The best-matching sentence, word for word, when Apple Intelligence
    /// can't write a line.
    static func bestSentence(in text: String, terms: [String]) -> String? {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), sentence.count >= 12 {
                sentences.append(sentence)
            }
        }
        guard let best = sentences.map({ ($0, score(title: "", body: $0, terms: terms)) }).filter({ $0.1 > 0 }).max(by: { $0.1 < $1.1 })?.0 else { return nil }
        return best.count > 240 ? String(best.prefix(240)) + "…" : best
    }

    // MARK: - What's New and Tips

    struct Note: Identifiable, Hashable {
        let id: String
        let title: String
        let text: String
        /// "What's New in 2026.18", or "Tip".
        let source: String
    }

    static func searchWhatsNew(_ query: String, phrases: [String] = [], limit: Int = 2) -> [Note] {
        let words = terms(([query] + phrases).joined(separator: " "))
        guard !words.isEmpty else { return [] }
        var entries: [(ChangeItem, String)] = ChangeItem.current.map { ($0, ChangeItem.currentVersion) }
        for section in HistorySection.all {
            let version = section.title.replacingOccurrences(of: "Also in ", with: "")
            entries += section.items.map { ($0, version) }
        }
        return entries
            .map { entry in (entry, score(title: entry.0.title, body: entry.0.description, terms: words, phrases: phrases)) }
            .filter { $0.1 >= 8 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { entry, _ in
                Note(id: "whatsnew:\(entry.0.title)", title: entry.0.title, text: entry.0.description,
                     source: String(localized: "What's New in \(entry.1)"))
            }
    }

    /// The newest version's changes, for "what's new?" questions.
    static func latestChanges(limit: Int = 6) -> [Note] {
        ChangeItem.current.prefix(limit).map {
            Note(id: "whatsnew:\($0.title)", title: $0.title, text: $0.description,
                 source: String(localized: "What's New in \(ChangeItem.currentVersion)"))
        }
    }

    static func searchTips(_ query: String, phrases: [String] = []) -> [Note] {
        let words = terms(([query] + phrases).joined(separator: " "))
        guard !words.isEmpty else { return [] }
        return Tips.content
            .map { key, tip in (key, tip, score(title: tip.title, body: tip.message, terms: words, phrases: phrases)) }
            .filter { $0.2 >= 8 }
            .sorted { $0.2 > $1.2 }
            .prefix(1)
            .map { key, tip, _ in Note(id: "tip:\(key.rawValue)", title: tip.title, text: tip.message, source: String(localized: "Tip")) }
    }

    // MARK: - Saved items

    @MainActor
    static func searchSaved(_ query: String, phrases: [String] = [], limit: Int = 5) -> [SavedItem] {
        let words = terms(([query] + phrases).joined(separator: " "))
            .filter { !["saved", "save", "bookmark", "bookmarks", "bookmarked", "item", "items"].contains($0) }
        let saved = PersistenceStore.shared.savedItems()
        guard !words.isEmpty else { return Array(saved.sorted { $0.savedAt > $1.savedAt }.prefix(limit)) }
        return saved
            .map { ($0, score(title: $0.title, terms: words)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}

// MARK: - Places ("Take me there")

/// Screens Ask the Mouse can open. The model picks one by `rawValue`.
enum MousePlace: String, CaseIterable, Identifiable, Hashable {
    case generalSettings, appearanceSettings, accessibilitySettings, notificationSettings
    case soundsHapticsSettings, homeFeedSettings, podcastSettings, savedSyncSettings
    case privacySettings, intelligenceSettings, contentTranslationSettings, siriSettings, storageSettings
    case whatsNew, savedItems, newTopic, submitApp, submitBlog, submitBug, submitPodcast, welcomeTour

    var id: String { rawValue }

    /// The name shown on the button. Settings screens read as a path,
    /// "Settings > Podcasts", the way Help writes them, built from the
    /// names Settings already shows.
    var name: String {
        func settings(_ screen: String) -> String { "\(String(localized: "Settings")) > \(screen)" }
        switch self {
        case .generalSettings: return settings(String(localized: "General"))
        case .appearanceSettings: return settings(String(localized: "Appearance"))
        case .accessibilitySettings: return settings(String(localized: "Accessibility"))
        case .notificationSettings: return settings(String(localized: "Notifications"))
        case .soundsHapticsSettings: return settings(String(localized: "Sounds & Haptics"))
        case .homeFeedSettings: return settings(String(localized: "Home Feed"))
        case .podcastSettings: return settings(String(localized: "Podcast"))
        case .savedSyncSettings: return settings(String(localized: "Saved & Sync"))
        case .privacySettings: return settings(String(localized: "Privacy"))
        case .intelligenceSettings: return settings(String(localized: "Intelligence"))
        case .contentTranslationSettings: return settings(String(localized: "Content Translation"))
        case .siriSettings: return settings(String(localized: "Siri & Shortcuts"))
        case .storageSettings: return settings(String(localized: "Storage & Cache"))
        case .whatsNew: return String(localized: "What's New")
        case .savedItems: return String(localized: "Saved Items")
        case .newTopic: return String(localized: "New Topic")
        case .submitApp: return String(localized: "Submit an App")
        case .submitBlog: return String(localized: "Submit a Blog Post")
        case .submitBug: return String(localized: "Submit a Bug Report")
        case .submitPodcast: return String(localized: "Submit a Podcast")
        case .welcomeTour: return String(localized: "Welcome Tour")
        }
    }

    /// What the screen is for, in English, so the model can choose well.
    var modelDescription: String {
        switch self {
        case .generalSettings: return "Home startup behavior, welcome summary, AppleVis tips, web links, profanity filter"
        case .appearanceSettings: return "theme, dark mode, colours, text and card density"
        case .accessibilitySettings: return "VoiceOver announcements and low vision controls"
        case .notificationSettings: return "push notifications, alerts, badge count, notification sound"
        case .soundsHapticsSettings: return "interface sounds, confirmation sounds, haptic feedback"
        case .homeFeedSettings: return "which content types appear on Home, Apple topics only"
        case .podcastSettings: return "playback speed, skip intervals, auto-play, trim silence, voice boost, downloads"
        case .savedSyncSettings: return "iCloud sync of saved items, follows, podcast position"
        case .privacySettings: return "privacy and clearing local data"
        case .intelligenceSettings: return "AI features such as summaries, rewrite, and translation"
        case .contentTranslationSettings: return "auto-translate AppleVis content into your language"
        case .siriSettings: return "Siri phrases and Shortcuts"
        case .storageSettings: return "downloads, cache, storage"
        case .whatsNew: return "list of changes in the latest app version"
        case .savedItems: return "your saved bookmarks"
        case .newTopic: return "start a new forum topic"
        case .submitApp: return "add an app to the App Directory"
        case .submitBlog: return "send a blog post draft to the editors"
        case .submitBug: return "report an accessibility bug in Apple software"
        case .submitPodcast: return "submit a podcast episode"
        case .welcomeTour: return "replay the Welcome Tour of the app"
        }
    }

    /// Opened as a sheet rather than pushed, like everywhere else in the app.
    var opensAsSheet: Bool {
        switch self {
        case .newTopic, .submitApp, .submitBlog, .submitBug, .submitPodcast, .welcomeTour: return true
        default: return false
        }
    }
}

// MARK: - Switches ("Change it for me")

/// Simple on/off settings the Mouse may change, and only after the person
/// says yes. Deliberately leaves out anything with side effects, such as
/// notifications (which need iOS permission) and iCloud sync.
enum MouseSwitch: String, CaseIterable, Identifiable {
    case welcomeSummary, showWhatsNewOnHome, searchAutoFocus, appleVisTips, filterProfanity
    case homeForums, homePodcasts, homeApps, homeGuides, homeBlogs, appleTopicsOnly
    case autoPlayNext, openPlayerOnPlay, trimSilence, voiceBoost
    case confirmationSounds, interfaceSounds, haptics
    case aiSummaries, composeRewrite, searchTranslation

    var id: String { rawValue }

    /// The switch's name exactly as it appears in Settings.
    var name: String {
        switch self {
        case .welcomeSummary: return String(localized: "Welcome Summary")
        case .showWhatsNewOnHome: return String(localized: "Show What's New on Home")
        case .searchAutoFocus: return String(localized: "Auto-Focus Search Field")
        case .appleVisTips: return String(localized: "AppleVis Tips")
        case .filterProfanity: return String(localized: "Filter Profanity")
        case .homeForums: return String(localized: "Forum Topics")
        case .homePodcasts: return String(localized: "Podcast Episodes")
        case .homeApps: return String(localized: "App Listings")
        case .homeGuides: return String(localized: "Guides & Tutorials")
        case .homeBlogs: return String(localized: "Blog Posts")
        case .appleTopicsOnly: return String(localized: "Apple Topics Only")
        case .autoPlayNext: return String(localized: "Auto-Play Next")
        case .openPlayerOnPlay: return String(localized: "Open Player on Play")
        case .trimSilence: return String(localized: "Trim Silence")
        case .voiceBoost: return String(localized: "Voice Boost")
        case .confirmationSounds: return String(localized: "Confirmation Sounds")
        case .interfaceSounds: return String(localized: "Interface Sounds")
        case .haptics: return String(localized: "Haptic Feedback")
        case .aiSummaries: return String(localized: "AI Summaries")
        case .composeRewrite: return String(localized: "Compose Rewrite")
        case .searchTranslation: return String(localized: "Search Translation")
        }
    }

    var place: MousePlace {
        switch self {
        case .welcomeSummary, .showWhatsNewOnHome, .searchAutoFocus, .appleVisTips, .filterProfanity: return .generalSettings
        case .homeForums, .homePodcasts, .homeApps, .homeGuides, .homeBlogs, .appleTopicsOnly: return .homeFeedSettings
        case .autoPlayNext, .openPlayerOnPlay, .trimSilence, .voiceBoost: return .podcastSettings
        case .confirmationSounds, .interfaceSounds, .haptics: return .soundsHapticsSettings
        case .aiSummaries, .composeRewrite, .searchTranslation: return .intelligenceSettings
        }
    }

    var modelDescription: String {
        switch self {
        case .welcomeSummary: return "spoken welcome summary when opening Home"
        case .showWhatsNewOnHome: return "NEW badges and new activity markers on Home"
        case .searchAutoFocus: return "put focus in the search field automatically"
        case .appleVisTips: return "helpful tip pop-ups"
        case .filterProfanity: return "hide swear words"
        case .homeForums: return "show forum topics on Home"
        case .homePodcasts: return "show podcast episodes on Home"
        case .homeApps: return "show app entries on Home"
        case .homeGuides: return "show guides on Home"
        case .homeBlogs: return "show blog posts on Home"
        case .appleTopicsOnly: return "only Apple-related forum topics on Home"
        case .autoPlayNext: return "play the next podcast episode automatically"
        case .openPlayerOnPlay: return "open the full podcast player when playing an episode from a list"
        case .trimSilence: return "skip silences in podcasts"
        case .voiceBoost: return "make podcast voices louder and clearer"
        case .confirmationSounds: return "sounds when something succeeds"
        case .interfaceSounds: return "sounds for taps, tabs and refreshing"
        case .haptics: return "vibration feedback"
        case .aiSummaries: return "AI summaries of long posts"
        case .composeRewrite: return "Rewrite button when writing"
        case .searchTranslation: return "offer to translate non-English searches"
        }
    }

    @MainActor
    var keyPath: ReferenceWritableKeyPath<PreferencesStore, Bool> {
        switch self {
        case .welcomeSummary: return \.welcomeSummaryEnabled
        case .showWhatsNewOnHome: return \.showNewActivityIndicators
        case .searchAutoFocus: return \.searchAutoFocusEnabled
        case .appleVisTips: return \.helpfulTipsEnabled
        case .filterProfanity: return \.filterProfanity
        case .homeForums: return \.showForums
        case .homePodcasts: return \.showPodcasts
        case .homeApps: return \.showApps
        case .homeGuides: return \.showGuides
        case .homeBlogs: return \.showBlogs
        case .appleTopicsOnly: return \.appleOnlyForums
        case .autoPlayNext: return \.autoPlayNext
        case .openPlayerOnPlay: return \.openPlayerOnPlay
        case .trimSilence: return \.trimSilence
        case .voiceBoost: return \.voiceBoost
        case .confirmationSounds: return \.confirmationSoundsEnabled
        case .interfaceSounds: return \.interfaceSoundsEnabled
        case .haptics: return \.hapticsEnabled
        case .aiSummaries: return \.aiSummariesEnabled
        case .composeRewrite: return \.composeRewriteEnabled
        case .searchTranslation: return \.searchTranslationEnabled
        }
    }
}
