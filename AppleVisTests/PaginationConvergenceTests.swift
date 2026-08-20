import Testing
import Foundation
@testable import AppleVis

/// Regression coverage for ARCH-10/TEST-05: browse-list endpoints (Apps,
/// Podcasts, Guides, Blogs, Bug Reports) previously computed "is there
/// more" from a client-side "did this page come back full" heuristic,
/// which is wrong whenever a page happens to land exactly full but no
/// more data actually exists (the exact boundary condition this suite
/// targets). They now read `JsonApiCollectionResponse.hasNextPage`, the
/// real signal from Drupal JSON:API's standard `links.next`, via the
/// shared `PagedListResult` wrapper.
@Suite("Pagination convergence")
struct PaginationConvergenceTests {

    private func decodeResponse(hasNext: Bool) throws -> JsonApiCollectionResponse {
        let linksJSON = hasNext ? #""links": {"next": {"href": "https://applevis.com/jsonapi/node/podcast?page[offset]=20"}},"# : ""
        let json = """
        {
            "data": [
                {"id": "1", "type": "node--podcast", "attributes": {}, "relationships": {}}
            ],
            \(linksJSON)
            "included": []
        }
        """
        return try JSONDecoder().decode(JsonApiCollectionResponse.self, from: Data(json.utf8))
    }

    @Test("a response with a links.next entry reports hasNextPage true — even on an exactly-full page")
    func exactlyFullPageWithNextLinkHasMore() throws {
        let response = try decodeResponse(hasNext: true)
        #expect(response.hasNextPage == true)
    }

    @Test("a response with no links.next entry reports hasNextPage false — the last, possibly partial, page")
    func lastPageWithNoNextLinkHasNoMore() throws {
        let response = try decodeResponse(hasNext: false)
        #expect(response.hasNextPage == false)
    }

    @Test("an empty page with no links.next reports hasNextPage false")
    func emptyPageHasNoMore() throws {
        let json = """
        {"data": [], "included": []}
        """
        let response = try JSONDecoder().decode(JsonApiCollectionResponse.self, from: Data(json.utf8))
        #expect(response.hasNextPage == false)
        #expect(response.data.isEmpty)
    }

    @Test("PagedListResult round-trips items and hasMore through Codable (used by fetchWithCache's disk cache)")
    func pagedListResultCodableRoundTrip() throws {
        let original = PagedListResult(items: ["a", "b", "c"], hasMore: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PagedListResult<String>.self, from: data)
        #expect(decoded.items == original.items)
        #expect(decoded.hasMore == original.hasMore)
    }
}
