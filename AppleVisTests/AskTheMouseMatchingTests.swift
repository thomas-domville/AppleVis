import Testing
import Foundation
@testable import AppleVis

/// The parts of Ask the Mouse that don't need Apple Intelligence or the
/// website: how it matches words, names, Apple's guide topics, and apps, and
/// what it remembers. Each case is one that went wrong in testing
/// (2026-10-01), so a later change can't quietly bring it back. The live
/// site checks are in tools/mouse_regression.
@Suite("Ask the Mouse matching")
@MainActor
struct AskTheMouseMatchingTests {

    private func app(_ name: String, summary: String = "", reviews: Int = 0, url: String = "", store: String? = nil,
                     voiceOver: String? = nil, usability: String? = nil) -> AppListing {
        AppListing(id: UUID().uuidString, name: name, developer: "", platform: .ios, category: "", categoryId: "",
                   reviewCount: reviews, lastUpdatedAt: Date(), lastActivityAt: Date(), createdAt: Date(),
                   submittedBy: "", submitterUid: "", appStoreUrl: store, iconUrl: nil, price: "",
                   supportedDevices: [], voiceOverPerformance: voiceOver, usability: usability, summary: summary, url: url, isSaved: false)
    }

    // MARK: Spelling and wording

    @Test("Two-word and hyphenated VoiceOver read as VoiceOver")
    func voiceOverSpellings() {
        #expect(AskTheMouse.normalizedForMatching("voice over gestures") == AskTheMouse.normalizedForMatching("VoiceOver gestures"))
        #expect(AskTheMouse.normalizedForMatching("Voice-Over rotor") == AskTheMouse.normalizedForMatching("VoiceOver rotor"))
    }

    @Test("Common misspellings and British spellings match")
    func spellingVariants() {
        #expect(AskTheMouse.normalizedForMatching("brail display") == AskTheMouse.normalizedForMatching("braille display"))
        #expect(AskTheMouse.normalizedForMatching("control centre") == AskTheMouse.normalizedForMatching("control center"))
        #expect(AskTheMouse.normalizedForMatching("colour filters") == AskTheMouse.normalizedForMatching("color filters"))
        #expect(AskTheMouse.normalizedForMatching("3-finger double-taps") == AskTheMouse.normalizedForMatching("three finger double tap"))
    }

    // MARK: Named apps

    @Test("A named app finds its own entry, not one that mentions it")
    func namedAppPrefersName() {
        let apps = [app("Roads Audio: Voice Threads"), app("Threads, an Instagram app"), app("Bottled")]
        #expect(AskTheMouse.bestNameMatch(apps, for: "Threads")?.name == "Threads, an Instagram app")
    }

    @Test("A one-letter name must match exactly, or be the renamed app")
    func shortNames() {
        #expect(AskTheMouse.bestNameMatch([app("Vox libri"), app("Xcode Helper")], for: "X") == nil)
        #expect(AskTheMouse.bestNameMatch([app("Vox libri"), app("X [Formerly Twitter]")], for: "X")?.name == "X [Formerly Twitter]")
        #expect(AskTheMouse.bestNameMatch([app("X [Formerly Twitter]")], for: "Twitter")?.name == "X [Formerly Twitter]")
    }

    @Test("A whole word inside a longer name still counts")
    func wholeWordName() {
        #expect(AskTheMouse.bestNameMatch([app("Amazon Kindle")], for: "Kindle")?.name == "Amazon Kindle")
        #expect(AskTheMouse.bestNameMatch([app("Kindleberry")], for: "Kindle") == nil)
    }

    // MARK: App ranking

    @Test("Car games don't bring up card games first")
    func carIsNotCard() {
        let ranked = AskTheMouse.rankedApps([app("Ears BlackJack card game"), app("Audio Rally Racing car game")], keyword: "car")
        #expect(ranked.first?.name == "Audio Rally Racing car game")
    }

    @Test("Apps with the word in their name come before ones that only describe it")
    func nameBeforeDescription() {
        let ranked = AskTheMouse.rankedApps([app("Board Games Hub", summary: "Includes solitaire"), app("Solitaire Pro")], keyword: "solitaire")
        #expect(ranked.first?.name == "Solitaire Pro")
    }

    // Only what the Mouse knows is good. Requested directly (2026-10-08).

    @Test("Apps rated not accessible are never suggested")
    func inaccessibleLeftOut() {
        let ranked = AskTheMouse.rankedApps([
            app("Solitaire Fun", voiceOver: "VoiceOver reads no page elements."),
            app("Solitaire Classic", usability: "The app is totally inaccessible."),
            app("Solitaire Watch", usability: "Inaccessible"),
            app("Accessible Solitaire", voiceOver: "VoiceOver reads all page elements."),
        ], keyword: "solitaire")
        #expect(ranked.map(\.name) == ["Accessible Solitaire"])
    }

    @Test("Fully accessible apps come first among equally good matches")
    func fullyAccessibleFirst() {
        let ranked = AskTheMouse.rankedApps([
            app("Poker Night", reviews: 50, voiceOver: "VoiceOver reads most page elements."),
            app("Poker Unrated", reviews: 80),
            app("Ears Video Poker", reviews: 7, voiceOver: "VoiceOver reads all page elements."),
        ], keyword: "poker")
        #expect(ranked.map(\.name) == ["Ears Video Poker", "Poker Night", "Poker Unrated"])
    }

    @Test("Ratings read the same on every platform")
    func accessibilityLevels() {
        typealias R = AppAccessibilityRatings
        #expect(R.level(voiceOver: "VoiceOver reads all page elements.", usability: nil) == .full)
        #expect(R.level(voiceOver: "VoiceOver reads a few page elements.", usability: nil) == .partial)
        #expect(R.level(voiceOver: "VoiceOver reads no page elements.", usability: nil) == .none)
        #expect(R.level(voiceOver: "Not applicable for this app", usability: "The app is fully accessible with VoiceOver and is easy to navigate and use.") == .full)
        #expect(R.level(voiceOver: nil, usability: "Mostly Accessible") == .partial)
        #expect(R.level(voiceOver: nil, usability: "Fully Accessible") == .full)
        #expect(R.level(voiceOver: nil, usability: "Inaccessible") == .none)
        #expect(R.level(voiceOver: nil, usability: nil) == .unrated)
    }

    @Test("Only apps named for the question count as a sure match")
    func sureMatchIsName() {
        #expect(AskTheMouse.appMatch(app("Solitaire Pro"), keyword: "solitaire") == 2)
        #expect(AskTheMouse.appMatch(app("Board Games Hub", summary: "Includes solitaire"), keyword: "solitaire") == 1)
        #expect(AskTheMouse.appMatch(app("Weather Now"), keyword: "solitaire") == 0)
    }

    // MARK: Apple's guide topics

    @Test("An iPad screenshot question offers the iPad page")
    func catalogDevice() {
        let top = MouseAppleCatalog.candidates(for: "How do I take a screenshot on my iPad?", phrases: []).first
        #expect(top?.t == "Take a screenshot")
        #expect(top?.d == "iPad")
    }

    @Test("A follow-up borrows the subject of the question before it")
    func catalogFollowUp() {
        let alone = MouseAppleCatalog.candidates(for: "And on the Mac?", phrases: [])
        let withEarlier = MouseAppleCatalog.candidates(for: "And on the Mac?", phrases: ["How do I use the rotor?"])
        #expect(withEarlier.contains { $0.t.localizedCaseInsensitiveContains("rotor") })
        #expect(!alone.contains { $0.t.localizedCaseInsensitiveContains("rotor") })
    }

    @Test("Another language finds a page once it has English search words")
    func catalogOtherLanguage() {
        #expect(MouseAppleCatalog.confidentMatch(for: "Wie mache ich ein Bildschirmfoto auf dem iPad?", phrases: ["take screenshot iPad"]) != nil)
        #expect(MouseAppleCatalog.confidentMatch(for: "Hola", phrases: ["hello"]) == nil)
    }

    // MARK: Golden Apples

    @Test("A Golden Apple winner is found by its App Store id")
    func goldenApples() {
        let piccy = app("PiccyBot", store: "https://apps.apple.com/app/piccybot/id6476859317")
        #expect(GoldenApples.best(for: piccy)?.year == 2025)
        #expect(GoldenApples.best(for: app("Not An Award Winner")) == nil)
    }

    // MARK: What the Mouse remembers

    @Test("About Me is told to Apple Intelligence only when filled in")
    func aboutMeText() {
        #expect(MouseProfile().modelText.isEmpty)
        var profile = MouseProfile()
        profile.devices = [.iPhone, .mac]
        profile.methods = [.brailleDisplay]
        #expect(profile.modelText.contains("iPhone, Mac"))
        #expect(profile.modelText.contains("a braille display"))
    }

    @Test("Feedback counts only for similar questions")
    func sourceFeedback() {
        let records = [
            MouseSourceFeedback.Record(sourceId: "guide-1", words: ["braille", "display", "commands"], helpful: true),
            MouseSourceFeedback.Record(sourceId: "guide-1", words: ["braille", "display", "connect"], helpful: true),
            MouseSourceFeedback.Record(sourceId: "guide-1", words: ["podcast", "speed"], helpful: false),
        ]
        #expect(MouseSourceFeedback.score("guide-1", words: ["braille", "display"], in: records) == 2)
        #expect(MouseSourceFeedback.score("guide-1", words: ["podcast", "speed"], in: records) == -1)
        #expect(MouseSourceFeedback.score("guide-1", words: ["rotor", "settings"], in: records) == 0)
        #expect(MouseSourceFeedback.score("guide-2", words: ["braille", "display"], in: records) == 0)
    }

    @Test("Past conversations keep the newest 10, newest first, and update answers in place")
    func conversationHistory() {
        var history = MouseConversationHistory(conversations: [], updatedAt: .distantPast)
        func answer(_ id: String, _ text: String = "Answer") -> SavedMouseAnswer {
            SavedMouseAnswer(id: id, question: "Question \(id)", answer: text, sources: [], savedAt: Date())
        }
        for index in 0..<12 {
            history.record(answer("a\(index)"), in: "c\(index)")
        }
        #expect(history.conversations.count == MouseConversationHistory.maxConversations)
        #expect(history.conversations.first?.id == "c11")
        history.record(answer("a11", "Better answer"), in: "c11")
        #expect(history.conversations.first?.answers.count == 1)
        #expect(history.conversations.first?.answers.first?.answer == "Better answer")
        history.record(answer("b"), in: "c5")
        #expect(history.conversations.first?.id == "c5")
        history.remove("c5")
        #expect(!history.conversations.contains { $0.id == "c5" })
    }
}
