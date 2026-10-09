import Testing
import Foundation
@testable import AppleVis

/// The subject a comment is posted with, matching the website's own form
/// (2026-10-09). The app used to send "Reply" or "Comment" for everything.
@Suite("Comment subjects")
@MainActor
struct CommentSubjectTests {

    @Test("A typed subject is used as it is")
    func typed() {
        #expect(CommentSubject.make(typed: "  Very cool!  ", body: "Anything") == "Very cool!")
    }

    @Test("A reply gets Re: and the subject it answers, never Re: Re:")
    func reply() {
        #expect(CommentSubject.make(typed: "", body: "Thanks", replyingTo: "leaderboard") == "Re: leaderboard")
        #expect(CommentSubject.make(typed: "", body: "Thanks", replyingTo: "Re: leaderboard") == "Re: leaderboard")
        #expect(CommentSubject.make(typed: "", body: "Thanks", replyingTo: "re: Re: Tall Cups") == "Re: Tall Cups")
    }

    @Test("A reply's Subject starts filled in, like the website's reply form")
    func replyPrefill() {
        #expect(CommentSubject.replyPrefill("My thoughts") == "Re: My thoughts")
        #expect(CommentSubject.replyPrefill("Re: My thoughts") == "Re: My thoughts")
        #expect(CommentSubject.replyPrefill(nil) == "")
        #expect(CommentSubject.replyPrefill("  ") == "")
    }

    @Test("A blank subject takes the first words, cut at a word")
    func fromBody() {
        #expect(CommentSubject.make(typed: "", body: "Love it") == "Love it")
        #expect(CommentSubject.make(typed: "", body: "Really interesting to read your thoughts. I'm happy.")
                == "Really interesting to read…")
    }

    @Test("The quote a reply starts with isn't used")
    func skipsQuote() {
        let body = "Oliver wrote:\n> The old one was better.\n\nI agree, mostly."
        #expect(CommentSubject.make(typed: "", body: body) == "I agree, mostly.")
    }

    @Test("Never longer than the website allows")
    func maxLength() {
        let long = String(repeating: "a", count: 100)
        #expect(CommentSubject.make(typed: long, body: "").count == CommentSubject.maxLength)
    }
}
