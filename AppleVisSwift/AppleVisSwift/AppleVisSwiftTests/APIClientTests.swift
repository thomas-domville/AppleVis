import Testing
@testable import AppleVisSwift

@Suite("APIError and 400/404 remapping")
struct APIClientTests {

    @Test("notFound has a friendly, non-technical message")
    func notFoundMessage() {
        let message = APIError.notFound.errorDescription
        #expect(message == "This item is no longer available. It may have been removed, moved, or is awaiting moderation.")
    }

    @Test("unknown(400) still reports the raw code when not remapped")
    func unknownMessageStillMentionsCode() {
        #expect(APIError.unknown(statusCode: 400).errorDescription == "Unexpected error (HTTP 400).")
    }

    // A content UUID sourced from a list/feed endpoint can outlive the node
    // it pointed to — Drupal's JSON:API returns 400, not 404, for a UUID
    // that doesn't resolve to a resource of the expected bundle. Single-item
    // detail fetches wrap their call in remapping400ToNotFound so that
    // specific case surfaces the friendlier .notFound instead of a raw code.
    @Test("remaps .unknown(400) thrown by the operation to .notFound")
    func remaps400ToNotFound() async {
        await #expect(throws: APIError.notFound) {
            try await APIClient.shared.remapping400ToNotFound {
                throw APIError.unknown(statusCode: 400)
            }
        }
    }

    @Test("leaves other errors untouched")
    func leavesOtherErrorsAlone() async {
        await #expect(throws: APIError.forbidden) {
            try await APIClient.shared.remapping400ToNotFound {
                throw APIError.forbidden
            }
        }
    }

    @Test("passes through the operation's result when it succeeds")
    func passesThroughSuccess() async throws {
        let result = try await APIClient.shared.remapping400ToNotFound {
            "ok"
        }
        #expect(result == "ok")
    }
}
