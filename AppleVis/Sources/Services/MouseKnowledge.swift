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

    /// Lowercased search words with common filler removed.
    static func terms(_ text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { $0.count >= 2 && !stopWords.contains($0) }
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    /// How well `text` matches. Title hits count most, then the summary,
    /// then the body (capped so a long article can't win on length alone).
    /// A whole phrase appearing counts extra.
    static func score(title: String, summary: String = "", body: String = "", terms: [String], phrases: [String] = []) -> Int {
        let title = title.lowercased(), summary = summary.lowercased(), body = body.lowercased()
        var total = 0
        for term in terms {
            if title.contains(term) { total += 6 }
            if summary.contains(term) { total += 3 }
            total += min(body.components(separatedBy: term).count - 1, 3)
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
        // Quick Reference (2026-10-04).
        "ref-voiceover-gestures": ["voiceover gesture", "gestures", "magic tap", "rotor", "scrub", "split tap", "screen curtain", "item chooser", "go back with voiceover", "go back in voiceover", "back gesture", "scroll with voiceover", "scroll down with voiceover"],
        "ref-voiceover-keyboard-ios": ["keyboard command", "keyboard shortcut", "magic keyboard", "external keyboard", "quick nav", "vo key"],
        "ref-braille-display": ["braille command", "braille display", "braille key", "dots", "perkins", "pan braille"],
        "ref-voiceover-keyboard-mac": ["mac voiceover", "voiceover on mac", "vo key", "voiceover utility", "command f5"],
        "ref-voiceover-trackpad-mac": ["trackpad", "trackpad gesture", "trackpad commander"],
        "ref-restart-iphone-ipad": ["force restart", "restart iphone", "restart ipad", "frozen", "not responding", "recovery mode", "restore iphone", "won't turn on", "hard reset", "reboot", "turn off my iphone", "turn off iphone", "turn off my ipad", "turn off ipad", "power off my iphone", "power off iphone", "shut down iphone", "shut down my iphone", "slide to power off"],
        "ref-restart-mac": ["macos recovery", "restart mac", "restart my mac", "force shut down", "reinstall macos", "mac frozen", "turn off my mac", "shut down my mac"],
        "ref-voiceover-watch": ["apple watch voiceover", "watch gestures", "digital crown navigation", "hand gestures"],
        "ref-voiceover-tv": ["apple tv voiceover", "tv remote", "exploration mode", "navigation mode", "clickpad"],
        "ref-braille-display-mac": ["mac braille", "braille on mac", "braille display mac"],
        "ref-accessibility-shortcut": ["accessibility shortcut", "triple click", "triple-click", "turn on voiceover", "turn off voiceover", "turn voiceover off", "turn voiceover on", "back tap"],
        "ref-setup-voiceover": ["set up with voiceover", "setup voiceover", "new iphone", "new mac", "pair apple watch", "first time setup"],
        "ref-glossary": ["glossary", "definition of", "perkins keyboard", "perkins-style", "what is braille access", "what is live recognition", "what is the rotor", "what is magic tap", "what is screen curtain", "what is quick nav", "contracted braille", "grade 2", "grade 1"],
        "ref-voiceover-silent": ["everything twice", "reading twice", "reads twice", "says twice", "speaks twice", "speaking twice", "talking twice", "speaking double", "speaks double", "voiceover stopped", "not talking", "no speech", "voiceover silent", "voiceover is silent", "screen is black", "screen black", "voiceover quiet", "can't hear voiceover"],
        "ref-low-vision": ["low vision", "zoom", "magnify", "bigger text", "larger text", "speak screen", "read aloud", "out loud", "read my email", "read my emails", "read & speak", "read the screen", "read my screen", "without voiceover", "text bigger", "see the screen"],
        "ref-typing-voiceover": ["typing", "type faster", "touch typing", "braille screen input", "bsi", "braille on the screen", "braille on screen", "type braille", "dictation", "text selection", "edit text"],
        "ref-recognition": ["describe image", "image description", "live recognition", "screen recognition", "door detection", "point and speak", "describe photo", "doors", "around me", "surroundings", "describe what", "what's in front", "describe the"],
        "ref-web-voiceover": ["safari", "webpage", "web page", "browse the web", "browsing the web", "reader view", "web rotor"],
        "ref-siri-phrases": ["hey siri", "ask siri", "siri commands", "siri requests", "voice commands"],
        "ref-iphone-everyday-voiceover": ["unlock", "home screen", "app switcher", "answer call", "camera voiceover", "take a photo", "take a picture", "camera with voiceover", "face id", "require attention", "arrange apps"],
        "ref-mac-essentials": ["mac shortcut", "mac keyboard shortcut", "windows user", "switching from windows", "spotlight on mac", "mac spotlight", "force quit"],
        "ref-getting-help": ["contact apple", "apple support", "accessibility support", "apple phone number", "call apple", "feedback to apple", "report to apple", "accessibility@apple.com"],
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
        let words = terms(([query] + phrases).joined(separator: " "))
        guard !words.isEmpty else { return [] }
        let lowerQuery = query.lowercased()
        let scored: [(HelpArticle, Int)] = allHelpArticles.map { article in
            var value = score(title: article.title, summary: article.summary, body: helpArticleText(article), terms: words, phrases: [query] + phrases)
            if let names = nicknames[article.id], names.contains(where: { lowerQuery.contains($0) }) { value += 12 }
            return (article, value)
        }
        // Needs more than a single stray body hit to count as a match.
        return scored.filter { $0.1 >= 4 }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    /// Help's own search field: the same ranking, grouped back into sections
    /// in their usual order. Used to match titles and summaries only, so
    /// anything mentioned only in an article's text couldn't be found.
    static func filterHelpSections(_ query: String) -> [HelpSection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
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
        case .podcastSettings: return settings(String(localized: "Podcasts"))
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
