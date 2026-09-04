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
    let createdAt: Date
}
