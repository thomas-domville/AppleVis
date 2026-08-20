import Testing
@testable import AppleVis

@Suite("Row label wording")
struct RowLabelTests {

    // MARK: - byAuthorAndCount

    @Test("omits the leading 'by' fragment when author is blank")
    func byAuthorAndCountBlankAuthor() {
        #expect(byAuthorAndCount("", "39 replies") == "39 replies")
    }

    @Test("includes 'by <author>' when author is present")
    func byAuthorAndCountWithAuthor() {
        #expect(byAuthorAndCount("Jane", "3 comments") == "by Jane, 3 comments")
    }

    // MARK: - forumContentType

    @Test("omits the leading space when category is blank")
    func forumContentTypeBlankCategory() {
        #expect(forumContentType(category: "") == "topic")
    }

    @Test("prefixes the category when present")
    func forumContentTypeWithCategory() {
        #expect(forumContentType(category: "Apple Beta Releases") == "Apple Beta Releases topic")
    }

    // MARK: - podcastContentType

    @Test("does not double the word 'podcast' when the show title already contains it")
    func podcastContentTypeAlreadyNamedPodcast() {
        #expect(podcastContentType(showTitle: "AppleVis Podcast") == "AppleVis Podcast")
    }

    @Test("is case-insensitive when detecting an existing 'podcast' word")
    func podcastContentTypeCaseInsensitive() {
        #expect(podcastContentType(showTitle: "Blind Bargains Podcast") == "Blind Bargains Podcast")
    }

    @Test("appends 'podcast' when the show title doesn't already say it")
    func podcastContentTypeAppendsWord() {
        #expect(podcastContentType(showTitle: "Mosen At Large") == "Mosen At Large podcast")
    }

    // MARK: - detailLevelLabel

    @Test("combines title, content type, author/count, and always-append suffix at Normal detail level")
    func detailLevelLabelNormal() {
        let label = detailLevelLabel(
            title: "Some Topic",
            contentType: "Apple Watch topic",
            authorAndCount: "by Jane, 3 comments",
            date: "yesterday",
            alwaysAppend: ". Saved."
        )
        // Normal level (the default with no PreferencesStore configured):
        // title, contentType, authorAndCount — but not date.
        #expect(label == "Some Topic, Apple Watch topic, by Jane, 3 comments. Saved.")
    }
}
