import Testing
import Foundation
@testable import AppleVis

/// The checked gestures and braille commands Ask the Mouse and Help's
/// search answer from (2026-10-09). The same cases run without Xcode in
/// tools/mouse_help_eval/test_handoff_scenarios.py.
@Suite("Quick reference")
@MainActor
struct MouseQuickReferenceTests {

    private func id(_ question: String, earlier: String = "", onMac: Bool = false) -> String? {
        MouseQuickReference.match(question, earlier: earlier, onMac: onMac)?.id
    }

    @Test("Every record's lines are still in its Help article, word for word")
    func linesAreInHelp() throws {
        for record in MouseQuickReference.all {
            let article = try #require(record.article, "\(record.id): no article \(record.articleId)")
            let text = MouseKnowledge.helpArticleText(article)
            for line in record.lines {
                #expect(text.contains(line), "\(record.id): \(line)")
            }
            #expect(record.source.hasPrefix("https://support.apple.com/"), "\(record.id)")
        }
        #expect(Set(MouseQuickReference.all.map(\.id)).count == MouseQuickReference.all.count)
    }

    @Test("Finger and tap counts are kept apart, however they're written")
    func gestures() {
        #expect(id("What does a three finger double tap do?") == "vo.mute")
        #expect(id("What does a 3-finger double-tap do?") == "vo.mute")
        #expect(id("what does double tap with three fingers do") == "vo.mute")
        #expect(id("triple finger double tap") == "vo.mute")
        #expect(id("What does a three-finger triple-tap do?") == "vo.curtain")
        #expect(id("What does a two-finger double-tap do?") == "vo.magic-tap")
    }

    @Test("A follow-up finds the gesture it's about")
    func followUps() {
        #expect(id("How do I change that?", earlier: "What does a three-finger double-tap do?") == "vo.customize")
        #expect(id("How do I turn that off?", earlier: "What does a three finger triple tap do?") == "vo.curtain")
        #expect(id("How do I turn that off?") == nil)
        // Changing a braille command isn't the command itself.
        #expect(id("Is there a way to change this command?",
                   earlier: "What is the braille command to open the Notification Center on my iPhone?") == nil)
    }

    @Test("Braille commands need braille in the question")
    func braille() {
        #expect(id("What's the braille command to open Notification Center?") == "braille.notification")
        #expect(id("How do I open Notification Centre with my braille display?") == "braille.notification")
        #expect(id("braille command for next item") == "braille.next")
        #expect(id("whats the brail command for notification centre") == "braille.notification")
        #expect(id("How do I move to the next item?") == "vo.next")
        #expect(id("What is the exact shortcut on my obscure display?", onMac: true) == nil)
    }

    @Test("The device named, then the one the topic named, then this one")
    func devices() {
        #expect(id("How do I use the rotor?") == "vo.rotor")
        #expect(id("What about on a Mac?", earlier: "How do I use the rotor?") == "mac.rotor")
        #expect(id("How do I change text size?") == "vision.text")
        #expect(id("What does a three finger double tap do on my Mac?") == nil)
        #expect(id("What does a three finger double tap do on my Apple Watch?") == nil)
        #expect(id("What does VO mean?", onMac: true) == "mac.voiceover.modifier")
        #expect(MouseQuickReference.platform(for: "How do I change text size?") == .iPhoneAndIPad)
    }

    @Test("Low vision questions don't assume VoiceOver, and the Zoom app isn't Zoom")
    func lowVision() {
        #expect(id("How can I make everything bigger?") == "vision.zoom")
        #expect(id("Is the Zoom app accessible?") == nil)
        #expect(id("Can my iPhone read the screen without VoiceOver?") == "vision.speak-screen")
        #expect(id("How do I change the voice?") == nil)
    }

    @Test("A misspelled word becomes the Help word one letter away, but names stay")
    func spelling() {
        #expect(MouseKnowledge.spellingFixed("how do i use the roter") == "how do i use the rotor")
        #expect(MouseKnowledge.spellingFixed("magnifyer on my phone") == "magnifier on my phone")
        #expect(MouseKnowledge.spellingFixed("Is the Sonos app accessible?") == "Is the Sonos app accessible?")
        #expect(id("how do i use the roter") == "vo.rotor")
    }

    @Test("A short question with its own subject is a new topic")
    func newTopics() {
        #expect(!AskTheMouse.refersBack("How do I change text size?"))
        #expect(!AskTheMouse.refersBack("How do I change my speech rate?"))
        #expect(AskTheMouse.refersBack("What about on a Mac?"))
        #expect(AskTheMouse.refersBack("How do I change that gesture?"))
    }
}
