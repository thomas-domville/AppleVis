import Foundation

/// Where a reply sits on the website, so Apple Intelligence can read the
/// conversation around it before deciding on a borderline guideline flag.
/// Judged alone, a developer replying in their own "looking for game ideas"
/// thread with the prototype they'd built looked like self-promotion
/// (2026-10-06). Requested directly.
nonisolated struct ConversationSource: Sendable, Hashable {
    /// Drupal comment bundle, such as "comment_forum".
    let commentBundle: String
    /// The post's JSON:API UUID.
    let nodeId: String
    /// The comment a draft is replying to, when known (writing a reply).
    var replyingToCommentId: String? = nil
    /// The flagged comment itself (the admin scan), to find what came
    /// before it and what it replied to.
    var flaggedCommentId: String? = nil

    /// "comment_forum" → "forum", "comment_node_blog2" → "blog2".
    var nodeType: String {
        if commentBundle.hasPrefix("comment_node_") { return String(commentBundle.dropFirst("comment_node_".count)) }
        if commentBundle.hasPrefix("comment_") { return String(commentBundle.dropFirst("comment_".count)) }
        return commentBundle
    }
}

/// The conversation around a reply, in plain text.
nonisolated struct ConversationContext: Sendable {
    let threadTitle: String
    let openingPost: String
    /// The website account that started the thread.
    let startedById: String
    /// "Name: text" of the comment being replied to.
    let replyingTo: String?
    /// "Name: text" of the comments just before, oldest first.
    let earlier: [String]
    /// The flagged comment's author started the thread (admin scan only).
    var flaggedAuthorStartedThread = false
}

enum GuidelineConversation {
    /// The opening post and the latest comments, in two small requests.
    /// Nil if the website can't be reached; the first verdict then stands.
    static func load(_ source: ConversationSource) async -> ConversationContext? {
        let nodeType = source.nodeType
        guard let node = try? await APIClient.shared.jsonAPISingle(
            "node/\(nodeType)/\(source.nodeId)",
            query: ["fields[node--\(nodeType)]": "title,body,uid"]
        ) else { return nil }
        let comments = try? await APIClient.shared.jsonAPIList(
            "comment/\(source.commentBundle)",
            query: [
                "filter[entity_id.id]": source.nodeId, "sort": "-created", "page[limit]": "50", "include": "uid",
                "fields[comment--\(source.commentBundle)]": "comment_body,uid,pid,created",
                "fields[user--user]": "display_name,name",
            ]
        )
        let a = node.data.attributes
        let opening = plain(a["body"]?.richTextValue ?? "")
        let startedBy = node.data.relationshipId("uid") ?? ""

        // Newest first, as fetched.
        let included = comments?.included ?? []
        let all = comments?.data ?? []
        func line(_ comment: JsonApiNode) -> String {
            let c = Mappers.genericComment(comment, included: included)
            let name = c.authorName.isEmpty ? "Someone" : c.authorName
            return "\(name): \(plain(c.body))"
        }

        var earlier: [String] = []
        var replyingTo: String?
        var flaggedAuthorStarted = false
        if let flaggedId = source.flaggedCommentId, let index = all.firstIndex(where: { $0.id == flaggedId }) {
            let flagged = all[index]
            flaggedAuthorStarted = !startedBy.isEmpty && flagged.relationshipId("uid") == startedBy
            earlier = all[(index + 1)...].prefix(3).reversed().map(line)
            if let parentId = flagged.relationshipId("pid") {
                replyingTo = all.first { $0.id == parentId }.map(line)
            }
        } else {
            earlier = all.prefix(3).reversed().map(line)
            if let replyId = source.replyingToCommentId {
                replyingTo = all.first { $0.id == replyId }.map(line)
            }
        }
        return ConversationContext(
            threadTitle: a["title"]?.stringValue ?? "", openingPost: opening, startedById: startedBy,
            replyingTo: replyingTo, earlier: earlier, flaggedAuthorStartedThread: flaggedAuthorStarted
        )
    }

    private static func plain(_ html: String) -> String {
        HTMLText.plainText(fromHTML: html)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}
