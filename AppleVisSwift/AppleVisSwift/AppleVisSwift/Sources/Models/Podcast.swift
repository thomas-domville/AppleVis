import Foundation

struct PodcastEpisode: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let showTitle: String
    let audioUrl: String
    let duration: TimeInterval?
    let publishedAt: Date
    let lastActivityAt: Date
    let description: String
    let artworkUrl: String?
    let transcriptUrl: String?
    let chapters: [Chapter]
    let tags: [PodcastTag]
    let commentCount: Int
    let authorName: String
    let url: String
    var isSaved: Bool
    var isDownloaded: Bool
    var downloadProgress: Double?
}

struct Chapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct PodcastTag: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tid: Int
    let count: Int
}

struct PodcastComment: Identifiable, Codable {
    let id: String
    let authorName: String
    let authorId: String
    let subject: String
    let body: String
    let createdAt: Date
}
