import Testing
@testable import AppleVisSwift

@Suite("Mappers.forumFromRecent", .serialized)
@MainActor
struct MappersTests {

    private func item(uuid: String, url: String, title: String = "Some Topic") -> [String: JSONValue] {
        [
            "uuid": .string(uuid),
            "title": .string(title),
            "url": .string(url),
            "comment_count": .number(3),
            "created": .number(1_700_000_000),
            "changed": .number(1_700_000_000),
        ]
    }

    @Test("accepts a genuine /forum/{category}/{slug} item")
    func acceptsGenuineForumURL() {
        let topic = Mappers.forumFromRecent(item(
            uuid: "8C1B8E8E-1234-4A11-9C11-000000000001",
            url: "/forum/apple-watch/some-topic"
        ))
        #expect(topic != nil)
        #expect(topic?.category == "Apple Watch")
    }

    // Confirmed via a live repro: /api/v1/forums/recent returned an item
    // whose uuid belonged to an App Directory node, not a forum topic — its
    // url was the app's real /apps/... page. It rendered as a bare "topic"
    // (categoryFromForumURL failed on the non-forum url) and 400'd on open.
    @Test("rejects an item whose url isn't actually a /forum/ path")
    func rejectsNonForumURL() {
        let topic = Mappers.forumFromRecent(item(
            uuid: "8C1B8E8E-1234-4A11-9C11-000000000002",
            url: "/apps/some-app-entry"
        ))
        #expect(topic == nil)
    }

    @Test("rejects a missing uuid")
    func rejectsMissingUUID() {
        var raw = item(uuid: "unused", url: "/forum/apple-watch/some-topic")
        raw["uuid"] = nil
        #expect(Mappers.forumFromRecent(raw) == nil)
    }

    @Test("rejects a uuid field that isn't a real UUID (e.g. the literal string \"null\")")
    func rejectsMalformedUUID() {
        let topic = Mappers.forumFromRecent(item(uuid: "null", url: "/forum/apple-watch/some-topic"))
        #expect(topic == nil)
    }

    @Test("rejects a /forum/ url with no category segment")
    func rejectsShortForumURL() {
        let topic = Mappers.forumFromRecent(item(
            uuid: "8C1B8E8E-1234-4A11-9C11-000000000003",
            url: "/forum"
        ))
        #expect(topic == nil)
    }
}
