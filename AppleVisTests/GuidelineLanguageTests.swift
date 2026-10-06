import Testing
@testable import AppleVis

/// Covers the 2026-09-25 widening of the vulgar-language list and the new
/// crude-language and put-down checks. The clean cases matter as much as
/// the hits: these words hide inside ordinary ones (Scunthorpe, Dickens,
/// shiitake), and a false flag blocks or nags an innocent post.
@Suite("Guideline language checks")
@MainActor
struct GuidelineLanguageTests {

    @Test("strong vulgar forms block, including endings, compounds, censored, and misspelled", arguments: [
        "that fuckin app", "what a clusterfuck", "f*ck this", "f**k", "f***ing update", "fck this", "fuk it",
        "fkn slow", "fuckhead", "you twat", "motherfucker", "FUCK", "f-u-c-k", "fucking great", "c*nt",
    ])
    func strong(_ text: String) {
        #expect(ContentSubmissionPolicy.containsStrongVulgarLanguage(text))
    }

    @Test("crude words get a medium reminder, not a block", arguments: [
        "this is shit", "bullshit update", "shitty app", "sh*t", "sh!t happens", "what an asshole", "dumbass move",
        "stop bitching", "you're a dick", "he's such a prick", "dickhead", "piss off", "what a bastard",
    ])
    func crude(_ text: String) {
        #expect(ContentSubmissionPolicy.containsCrudeLanguage(text))
        #expect(!ContentSubmissionPolicy.containsStrongVulgarLanguage(text))
    }

    @Test("put-downs aimed at a person are a medium tone concern", arguments: [
        "lmaoo I never brought your name up, but whatever helps you sleep at night.",
        "Because they always find someone like you to come up and defend them.",
        "people like you always ruin threads", "cope and seethe", "go touch grass", "ok boomer", "get a life",
        "Who asked?", "Just grow up.", "skill issue",
    ])
    func putDowns(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == .medium)
    }

    @Test("self-promotion needs an invitation, a launch, or a link", arguments: [
        "Check out my podcast about accessibility!", "Please subscribe to my YouTube channel", "visit my website for more",
        "I just started a podcast for blind gamers", "My new blog covers VoiceOver tips", "Like and subscribe!",
        "My podcast is at https://example.com/pod", "Head over to my channel for the full review",
        "I've launched my new newsletter", "listen to my latest episode",
        "Check out my new podcast at https://example.com and let me know your thoughts!",
        "I posted more on my blog https://example.com, let me know what you think",
    ])
    func selfPromotion(_ text: String) {
        #expect(ContentSubmissionPolicy.looksLikeSelfPromotion(text))
    }

    @Test("just mentioning your own site or podcast isn't promotion", arguments: [
        "So I am editing code for my website. I go to Discord.", "my podcast player keeps crashing",
        "My website broke after the update", "I use Overcast as my podcast app",
        "I wrote about this on my blog last year and it still happens", "my channel list in Slack",
        "my YouTube channel subscriptions don't load", "How do I back up my website?", "my new podcast app is great",
        "I follow my favorite podcasts in Castro",
        // A developer sharing a prototype for feedback, which the guidelines
        // allow (2026-10-06).
        "I'm done with the game prototype and I've uploaded to my website at https://audiofootball.gatunogames.com/ If you have a chance to try it out, I'd love to get your feedback on it.",
        "Beta testers wanted! Details on my website https://dev.example.com",
    ])
    func notSelfPromotion(_ text: String) {
        #expect(!ContentSubmissionPolicy.looksLikeSelfPromotion(text))
    }

    /// The real post that was flagged medium as self-promotion (2026-09-25):
    /// a member asking for help after VoiceOver crashed in Terminal.
    @Test("a help request after a VoiceOver crash gets no medium or high warning")
    func voiceOverCrashPost() {
        let post = """
        first things first, my intentions of this post is not to start a Mac versus Windows argument. I will not move to Windows because of this.
        So I am editing code for my website. I go to Discord, go into the chat and chat with some people. That's fine.
        I then go back out and go back into my Terminal. Now to be fair there is a lot of code in this terminal window.
        But then VoiceOver decides that it's going to crash. Hard.
        Speech? Gone. Sounds? Barely any. Mind you, I completely lack sight, so this is bad. Really, really bad for me.
        So I turn voiceover off, like what I usually do because it had crashed before, but not as catastrophically. I tried to turn voiceover back on.
        NOTHING!
        so i keep on trying, again i have no idea on ware i am in the OS at this point.
        but it still doesn't work.
        command f 5?
        nothing.
        so then i restart.
        well, i don't i force shutdown the hole dam laptop cause what on earth am i ment to do otherwhise
        finaly im able to get siri into the chat and shes able to tern voice over back on. with speach.
        so, uh. how do i stop this from happening.
        do i use a better termonal.
        pleas someone, this is insane!
        """
        let serious = GuidelinesChecker.check(post).filter { $0.severity != .low }
        #expect(serious.isEmpty, "Unexpected: \(serious.map(\.id))")
    }

    @Test("ordinary text stays clean", arguments: [
        "Scunthorpe is a town", "a cocktail recipe", "I love Dickens", "Moby Dick is a novel", "my friend Dick",
        "shiitake mushrooms", "a pin prick", "people like you make this community great", "It's people like you that help",
        "how do you cope with low battery", "who asked about Android support earlier?", "kids grow up so fast",
        "damn this is slow", "what the hell", "this is crap", "it sucks", "pissed off at Apple", "the Pacific coast",
        "Shift key", "the shuttle", "lol you're right", "you do you", "if you say so", "Ask the ffmpeg folks",
        "The FCC approved it", "check the fuse", "I am a bit shy", "shih tzu",
        "Honestly, seems a bit contradictory", "that is exactly my point in a nicer way lol",
        "the hate for developers is starting to get out of control",
    ])
    func clean(_ text: String) {
        #expect(!ContentSubmissionPolicy.containsStrongVulgarLanguage(text))
        #expect(!ContentSubmissionPolicy.containsCrudeLanguage(text))
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    // MARK: - Email addresses (2026-09-27)

    private func emailSeverity(_ text: String) -> GuidelineWarning.Severity? {
        GuidelinesChecker.check(text).first { $0.id == "personal-info" }?.severity
    }

    @Test("a personal mailbox in a pasted email header is medium", arguments: [
        // Like the real post: her own address sat in a pasted email header.
        "I am following up again regarding my case.\nMelanie Spears < mamapeach67@gmail.com > wrote:",
        "Following up on my case.\nOn Sep 17, Melanie Spears <mamapeach67@gmail.com> wrote:",
        "From: Bob Jones <bob.jones@hotmail.com>\nSent: Tuesday",
    ])
    func personalEmailIsMedium(_ text: String) {
        #expect(emailSeverity(text) == .medium)
    }

    @Test("a personal address shared on purpose is only low", arguments: [
        // Shared on purpose, from real posts (2026-09-27 month review).
        "If you would like to join, email me at youmbidev@gmail.com and I will add you to the TestFlight group.",
        "Anyone interested is warmly welcome to drop me a line at mohammad.xciii@gmail.com.",
        "Hi, would you mind dropping me a line at mohammad.xciii@gmail.com? I'd like to add you to TestFlight.",
        "or to my email address: <a href=\"mailto:mohammad.xciii@gmail.com\">mohammad.xciii@gmail.com</a>.",
        "email me at someone.else@icloud.com",
        "reach me at jane@yahoo.co.uk",
        // Typed in by the member themselves (2026-09-27 three-month review).
        "Hi, Can you add me please? Afik.sofir@icloud.com Thanks.",
        "my address is bob@hotmail.fr",
        "Sincerely,\nMike\nmike1987@gmail.com",
        // Named like a project, not a person.
        "Send your feedback to footlord.info@gmail.com. Thank you!",
        // The same address repeated later in the post is still the same share.
        "You can email the code to: gift.cards.jo@proton.me. Questions? Write anytime. Again, it's gift.cards.jo@proton.me.",
    ])
    func sharedPersonalEmailIsLow(_ text: String) {
        #expect(emailSeverity(text) == .low)
    }

    @Test("role and placeholder addresses aren't flagged", arguments: [
        "write to accessibility@apple.com",
        // Work and support addresses at a company's own domain (2026-10-06).
        "please send a quick email to gokhan@birkinapps.com with the address you used",
        "contact me at jane@mycompany.co.uk",
        "send it to feedback@applevis.com",
        "Example: User@iCloud.com",
        "Support@birkinapps.com can help",
    ])
    func roleEmailIsIgnored(_ text: String) {
        #expect(emailSeverity(text) == nil)
    }

    @Test("a pasted-header personal address wins when both kinds appear")
    func mixedEmailIsMedium() {
        #expect(emailSeverity("Email me at gokhan@birkinapps.com.\nFrom: Jane Doe <jane.doe@gmail.com>") == .medium)
    }

    // MARK: - "Clearly" / "obviously" tone check (2026-09-27)

    @Test("friendly or descriptive uses aren't a tone concern", arguments: [
        "Thank you again for explaining it clearly and for helping me improve the game!",
        "I can hear it clearly now!",
        "The button is clearly labelled now?",
        "Can you speak more clearly?",
    ])
    func descriptiveClearlyIsFine(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("dismissive uses are still a low tone concern", arguments: [
        "Clearly you didn't read the post!",
        "It's obviously broken, did you even test it?",
    ])
    func dismissiveClearlyIsLow(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == .low)
    }

    // MARK: - Month review fixes (2026-09-27)

    @Test("survey mentions that don't invite anyone need no approval", arguments: [
        "iPhone users were 65% more likely to say they had not received a scam text in the week before answering the survey.",
        "It's also essential to organise focus group discussion among Blind travellers.",
        "A while ago, we invited you to share your ideas through our power bank survey.",
    ])
    func surveyMentionIsFine(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "announcement-approval" })
    }

    @Test("an invitation to take part still needs approval", arguments: [
        "Please fill out the survey and become a tester.",
        "There is also a short survey that they would like as many visually impaired people as possible to fill out.",
        "We are looking for participants for a research study on screen readers.",
    ])
    func surveyInvitationNeedsApproval(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "announcement-approval" })
    }

    @Test("passing mentions of buying aren't advertising", arguments: [
        "Purple is my favorite color, and I've wanted to buy a purple iMac in the past.",
        "Is the new AirPods case for sale in the UK yet?",
    ])
    func buyingMentionIsFine(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "advertising" })
    }

    @Test("a real listing is advertising", arguments: [
        "For sale: iPhone 14 Pro, 128 GB, like new.",
        "I'm selling my Focus 40 Braille display.",
        "I have a spare Victor Reader Stream for sale.",
        "Use promo code BLIND20 at checkout.",
    ])
    func listingIsAdvertising(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "advertising" })
    }

    @Test("shut up about yourself isn't a tone concern", arguments: [
        "None of this means we should just stay quiet and shut up about it either.",
        "Okay, I'll shut up now and let others chime in.",
    ])
    func selfShutUpIsFine(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("shut up aimed at someone still is", arguments: ["Just shut up.", "Tell him to shut up."])
    func shutUpAtSomeoneIsMedium(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == .medium)
    }

    // MARK: - Low-severity review (2026-09-27)

    @Test("frustration that isn't aimed at anyone isn't a tone concern", arguments: [
        "They're obviously resyncing from somewhere, but where is it coming from?",
        "I assume this works for everything, .m4v, .mp3, documents, whatever?",
        "Is there some way to tell VoiceOver you're done editing if there's no enter/go/whatever button?",
        "Is there an equalizer app which will change the sound of whatever app is playing music?",
        "With this being foldable, obviously the intention is for it to be used while travelling, but this has become my daily keyboard!",
    ])
    func undirectedLowToneIsFine(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("dismissive whatever is still a low tone concern", arguments: ["Whatever. Believe what you want!", "Sure, whatever you say."])
    func dismissiveWhateverIsLow(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == .low)
    }

    @Test("excitement isn't shouting", arguments: [
        "Hi, I've just started playing this game, it's AWESOME!!!! I agree with all of the suggestions.",
        "this looks like a cosy game I can get really addicted too!!!!",
        "Interested to hear all of your experiences too!!!",
    ])
    func excitementIsFine(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "excessive-punctuation" })
    }

    @Test("shouting with capitals and marks is flagged", arguments: [
        "Now if only we could bring back unlockable boot loaders. Looking at you, SAMSUNG!!!!!!!!!!",
        "WHY DOES THIS KEEP HAPPENING???",
    ])
    func shoutingIsFlagged(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "excessive-punctuation" })
    }

    @Test("several questions about one subject are one topic", arguments: [
        "I'm considering getting an iPad. Can I use my MacBook charger to charge it? How do I make sure all my apps cross over? What type of case do you recommend?",
        "So why do you pick the device voice you pick? Also, what does that voice represent to you? Is it an extension of you somehow? Is it like a friend?",
    ])
    func relatedQuestionsAreOneTopic(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "multi-topic" })
    }

    @Test("a clear change of subject is flagged", arguments: [
        "My contacts keep duplicating after I delete them. How do I stop it? Also, unrelated question: which Braille display should I buy?",
        "VoiceOver keeps reading the time wrong on my lock screen, is there a fix? On a different note, does anyone know a good recipe app?",
    ])
    func topicSwitchIsFlagged(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "multi-topic" })
    }

    // MARK: - Unseen-month review (2026-09-27)

    @Test("App Store promo codes aren't advertising", arguments: [
        "It will be helpful if I can get a promo code for testing the software.",
        "If you need a promo code for a playing partner, please contact me.",
        "I'd love a promo code if you have any remaining.",
        // "off" matched the start of "offers" (2026-10-06).
        "I'm also interested in procedural soundscape generation, and request a promo code to hear the other sounds that Veil offers.",
    ])
    func appStorePromoCodeIsFine(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "advertising" })
    }

    @Test("a discount code is advertising", arguments: [
        "The code BACKTOSCHOOL20 takes up to $250 off. Just apply the coupon code at checkout.",
        "Use promo code BLIND20 for 20% off.",
    ])
    func discountCodeIsAdvertising(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "advertising" })
    }

    @Test("mentioning a press release isn't posting one", arguments: [
        "I bought a Samsung QLED after seeing a press release with them and the RNIB about accessibility.",
        "In its press release, Apple called the new chip its most powerful silicon ever.",
    ])
    func pressReleaseMentionIsFine(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "press-release" })
    }

    @Test("an actual press release is flagged", arguments: [
        "FOR IMMEDIATE RELEASE\nAcme launches an accessible microwave.",
        "Press release: Acme launches an accessible microwave today.",
    ])
    func pressReleaseIsFlagged(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "press-release" })
    }

    @Test("a quoted insult used as an example doesn't block posting")
    func quotedInsultIsNotHigh() {
        let text = #"There is a difference between calling out a behavior ("Michael, you're being a keyboard warrior") and a personal attack ("Michael, you're an idiot")."#
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == .medium)
    }

    @Test("an insult outside quotes still blocks")
    func unquotedInsultIsHigh() {
        #expect(ContentSubmissionPolicy.toneConcern(in: "Michael, you're an idiot.") == .high)
    }

    // MARK: - Three-month review (2026-09-27)

    @Test("talking about AI isn't undisclosed AI text", arguments: [
        "It's possible the 6.5 was an AI error.",
        "I use Be My Eyes as an AI helper for photos.",
    ])
    func aiMentionIsFine(_ text: String) {
        #expect(!GuidelinesChecker.check(text).contains { $0.id == "ai-disclosure" })
    }

    @Test("chatbot phrasing is still flagged", arguments: [
        "As an AI language model, I can't give medical advice.",
        "As an AI, I don't have personal preferences.",
    ])
    func chatbotPhrasingIsFlagged(_ text: String) {
        #expect(GuidelinesChecker.check(text).contains { $0.id == "ai-disclosure" })
    }

    @Test("a caring or neutral statement about a group isn't hate", arguments: [
        "Forgetting that not all blind people are able to go on a straight line is not good.",
        "All blind people are welcome here.",
    ])
    func groupStatementIsFine(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) != .high)
    }

    @Test("an insulting generalisation still blocks")
    func hatefulGeneralisationIsHigh() {
        #expect(ContentSubmissionPolicy.toneConcern(in: "All blind people are useless.") == .high)
    }

    // MARK: - Missed in the three-month review (2026-09-27)

    @Test("put-downs that were missed are now a medium tone concern", arguments: [
        "I'm also telling you to either mind your own business or just be fair.",
        "If you chose to be a developer for the feedback then you have some insecurities that you should probably address with a mental health counselor.",
        "Honestly, you need therapy.",
    ])
    func missedPutDownsAreMedium(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == .medium)
    }

    @Test("caring talk about counselling stays clean", arguments: [
        "A counsellor helped me a lot when I lost my sight.",
        "If you're struggling, talking to a therapist can really help.",
    ])
    func caringCounsellingIsFine(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("suck it up is a low tone concern")
    func suckItUpIsLow() {
        #expect(ContentSubmissionPolicy.toneConcern(in: "If you don't like it in landscape, I'm sorry but suck it up.") == .low)
    }

    @Test("a moderator quoting a put-down isn't making one", arguments: [
        #"Saying things like "Mind your own business" in response to someone's opinion is counterproductive."#,
        #"You told that person that "... you have some insecurities that you should probably address with a mental health counselor," which was hurtful."#,
        "You wrote, long before I suggested that someone might have insecurities that should be addressed with a mental health counselor, that I was a keyboard warrior.",
    ])
    func quotedPutDownIsFine(_ text: String) {
        #expect(ContentSubmissionPolicy.toneConcern(in: text) != .medium)
    }

    // MARK: - Moderators (2026-09-27, suggested directly)

    @Test("quotes stored as the site's HTML are still quotes")
    func htmlQuotedPutDownIsFine() {
        let text = "Please be respectful. Saying things like &quot;Mind your own business&quot; is counterproductive."
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("a quote block is still a quote")
    func blockquotedPutDownIsFine() {
        let text = "<blockquote><p>Mind your own business.</p></blockquote><p>That wasn't kind. Please be respectful.</p>"
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("a moderator quoting an insult while calling it out isn't flagged")
    func moderatorQuotingInsultIsFine() {
        let text = #"There is a difference between calling out a behavior and a personal attack ("Michael, you're an idiot"). Personal attacks are not welcome on AppleVis."#
        #expect(ContentSubmissionPolicy.toneConcern(in: text) == nil)
    }

    @Test("telling an app or browser to be quiet isn't a tone concern")
    func browserShutUpIsFine() {
        #expect(ContentSubmissionPolicy.toneConcern(in: "Legato 0.3.85 is out. Most of this release is the browser learning to shut up.") == nil)
    }
}
