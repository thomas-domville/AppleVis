import Foundation

nonisolated struct BlogPost: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var nid: Int? = nil
    let title: String
    let authorName: String
    let authorId: String
    let publishedAt: Date
    let lastActivityAt: Date
    let summary: String
    let commentCount: Int
    let url: String
    var isSaved: Bool
}

nonisolated struct BlogPostDetail: Identifiable, Codable, Sendable {
    let id: String
    /// Drupal's internal integer node ID — needed to call History's
    /// `/history/{nid}/read`, distinct from `id` (the JSON:API UUID).
    let nid: Int
    let title: String
    let authorName: String
    let authorId: String
    let publishedAt: Date
    let lastActivityAt: Date
    let body: String
    /// See `ForumTopicDetail.rawBody`/`bodyFormat`'s doc comment.
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let commentCount: Int
    let url: String
    var comments: [BlogComment]
    var isSaved: Bool
}

nonisolated struct BlogComment: Identifiable, Codable, Sendable {
    let id: String
    let authorName: String
    let authorId: String
    let subject: String
    let body: String
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let createdAt: Date
}

nonisolated enum ReadingTime {
    private static let wordsPerMinute = 200.0

    /// "3 min read" — needs the full HTML body, so it's only computable
    /// once that's been fetched (list-level BlogPost only carries `summary`;
    /// full text lives on BlogPostDetail).
    static func text(forHTMLBody body: String) -> String? {
        let wordCount = body.strippingHTMLTags()
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
        guard wordCount > 0 else { return nil }
        let minutes = max(1, Int((Double(wordCount) / wordsPerMinute).rounded(.up)))
        return String(localized: "\(minutes) min read")
    }
}
