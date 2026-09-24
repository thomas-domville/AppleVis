import Foundation

nonisolated struct Resource: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var nid: Int? = nil
    let title: String
    let kind: ResourceKind
    let authorName: String
    let authorId: String
    let categories: [String]
    let summary: String
    let createdAt: Date
    let updatedAt: Date
    let commentCount: Int
    let url: String
    var isSaved: Bool
}

nonisolated struct ResourceDetail: Identifiable, Codable, Sendable {
    let id: String
    /// Drupal's internal integer node ID — needed to call History's
    /// `/history/{nid}/read`, distinct from `id` (the JSON:API UUID).
    let nid: Int
    let title: String
    let kind: ResourceKind
    let authorName: String
    let authorId: String
    let categories: [String]
    let summary: String
    let body: String
    /// See `ForumTopicDetail.rawBody`/`bodyFormat`'s doc comment.
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let createdAt: Date
    let updatedAt: Date
    let commentCount: Int
    let url: String
    var comments: [ResourceComment]
    var isSaved: Bool
}

nonisolated struct ResourceComment: Identifiable, Codable, Sendable {
    let id: String
    let authorName: String
    let authorId: String
    let subject: String
    let body: String
    var rawBody: String = ""
    var bodyFormat: String = drupalDefaultTextFormat
    let createdAt: Date
}

nonisolated enum ResourceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case guide
    case tutorial
    case article
    case event
    case developer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .guide:      return String(localized: "Guide")
        case .tutorial:   return String(localized: "Tutorial")
        case .article:    return String(localized: "Article")
        case .event:      return String(localized: "Event")
        case .developer:  return String(localized: "Developer Resource")
        }
    }

    var systemImage: String {
        switch self {
        case .guide:      return "book"
        case .tutorial:   return "graduationcap"
        case .article:    return "newspaper"
        case .event:      return "calendar"
        case .developer:  return "hammer"
        }
    }
}
