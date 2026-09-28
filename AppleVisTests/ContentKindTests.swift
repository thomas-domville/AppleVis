import Testing
@testable import AppleVis

@Suite("ContentKind wording")
struct ContentKindTests {

    @Test("forum topics say 'Topic'")
    func forumTopicDisplayName() {
        #expect(ContentKind.forumTopic.displayName == "Topic")
    }

    @Test("app listings say 'App Entry'")
    func appListingDisplayName() {
        #expect(ContentKind.appListing.displayName == "App Entry")
    }

    @Test("saveActionNoun says 'Episode' for podcast episodes, not 'Podcast'")
    func podcastEpisodeSaveActionNoun() {
        #expect(ContentKind.podcastEpisode.saveActionNoun == "Episode")
    }

    @Test("saveActionNoun matches displayName for every other kind", arguments: ContentKind.allCases.filter { $0 != .podcastEpisode })
    func saveActionNounMatchesDisplayNameElsewhere(kind: ContentKind) {
        #expect(kind.saveActionNoun == kind.displayName)
    }

    @Test("app entry pluralizes irregularly")
    func appEntryPluralization() {
        #expect(ContentKind.appListing.countPhrase(1) == "1 app entry")
        #expect(ContentKind.appListing.countPhrase(2) == "2 app entries")
        #expect(ContentKind.appListing.countPhrase(18) == "18 app entries")
    }

    @Test("other kinds pluralize with a trailing 's'")
    func regularPluralization() {
        #expect(ContentKind.forumTopic.countPhrase(1) == "1 topic")
        #expect(ContentKind.forumTopic.countPhrase(2) == "2 topics")
    }
}
