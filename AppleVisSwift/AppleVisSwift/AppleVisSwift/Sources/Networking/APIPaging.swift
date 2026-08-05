import Foundation

/// Shared page-size threshold for the client-side "did we get a full page,
/// so there's probably more" heuristic (`fetched.count >= APIPaging.pageSize`)
/// used by every paginated browse screen. Matches each Endpoints struct's own
/// server-side request page size — kept as one constant so the two can't
/// silently drift apart across the six browse screens that each used to
/// hardcode the literal `20` independently.
enum APIPaging {
    static let pageSize = 20
}
