import Combine
import Foundation

/// One iOS App Directory entry worth an editor's attention.
struct AppHealthFlag: Identifiable {
    enum Kind {
        /// Apple's lookup returned no match at all for this app's id —
        /// it's no longer on the App Store (delisted, pulled by the
        /// developer, or the account was removed).
        case removed
        /// Still on the App Store, but the live title no longer matches
        /// what AppleVis has on file — often means other fields (description,
        /// version) have drifted too and are worth a look.
        case titleChanged(newTitle: String)
    }

    let id: String
    let appId: String
    let appName: String
    let kind: Kind
}

/// How far back "Recent Activity" looks — entries added to the directory
/// within this window, not "everything," so a quick check after a batch of
/// new submissions doesn't mean waiting on the entire catalog.
enum AppHealthScanRange: Int, CaseIterable, Identifiable {
    case day, week, month

    var id: Self { self }

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        }
    }

    var displayName: String {
        switch self {
        case .day: return String(localized: "Past Day")
        case .week: return String(localized: "Past Week")
        case .month: return String(localized: "Past Month")
        }
    }
}

/// Scans iOS App Directory entries against the live App Store, for the App
/// Directory Health Check admin screen. Originally scanned the *entire*
/// directory every time — a genuinely heavy, slow operation against a
/// catalog this size. Replaced with two narrower, faster modes instead of
/// one all-or-nothing sweep: "Recent Activity" (entries added within a
/// chosen window — catches problems with a fresh submission quickly) and
/// "By Category" (one whole category at a time — still exhaustive, just
/// scoped to a manageable slice instead of everything at once). Requested
/// directly: "that sounds daunty."
///
/// Both modes still finish the same way: batch every candidate entry's App
/// Store id into as few `ItunesAPI.batchLookup` requests as possible,
/// rather than the one-request-per-app the single-app "Refresh App
/// Details" flow uses — checking a few hundred apps one at a time would
/// risk Apple's rate limit.
///
/// Deliberately does *not* fetch each app's full local `AppDetail` (which
/// `AppInfoFieldDiff` needs for the complete title/description/link/version
/// diff) — that would mean one more request per app on top of the batched
/// iTunes calls, undoing the point of batching. This scan's job is triage:
/// find what's worth a look. Tapping a flagged result opens that app's own
/// detail screen, where the existing Refresh App Details flow already does
/// the full comparison and update. Requested directly.
@MainActor
final class AppEntryHealthScanner: ObservableObject {
    @Published private(set) var flags: [AppHealthFlag] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedAppCount = 0
    @Published var error: String?
    /// For the "By Category" picker — populated once via `loadCategories()`,
    /// not tied to either scan itself.
    @Published private(set) var categories: [AppCategory] = []

    private var currentScanId = UUID()

    /// iTunes's lookup accepts a comma-separated id list; kept well under
    /// any plausible undocumented URL-length or per-request limit rather
    /// than tested against one.
    private static let batchSize = 100

    func loadCategories() async {
        categories = (try? await APIClient.shared.apps.categories(platform: .ios))?
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
    }

    /// Drops one flag right after its admin swipe action (Edit/Unpublish/
    /// Delete) succeeds — it's been handled, and leaving it in the list
    /// would just show stale content. Mirrors
    /// `GuidelineViolationScanner.removeFlag(id:)`.
    func removeFlag(id: String) {
        flags.removeAll { $0.id == id }
    }

    func scanRecent(range: AppHealthScanRange) async {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
        await runScan { try await Self.recentIosListings(cutoff: cutoff) }
    }

    func scanCategory(_ category: AppCategory) async {
        await runScan { try await Self.allListings(categoryTid: category.tid) }
    }

    private func runScan(fetchListings: () async throws -> [AppListing]) async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        scannedAppCount = 0

        let listings: [AppListing]
        do {
            listings = try await fetchListings()
        } catch {
            guard currentScanId == scanId else { return }
            // `Text(error)` in AppEntryHealthCheckView shows this as a plain
            // String, which never consults the localization catalog for
            // anything but a `LocalizedStringKey` — has to be resolved here.
            self.error = String(localized: "Couldn't load the App Directory. Try again.")
            isScanning = false
            return
        }
        guard currentScanId == scanId else { return }
        scannedAppCount = listings.count

        let results = await Self.checkListings(listings)
        guard currentScanId == scanId else { return }

        flags = results.sorted { a, b in
            let aIsRemoved = if case .removed = a.kind { true } else { false }
            let bIsRemoved = if case .removed = b.kind { true } else { false }
            if aIsRemoved != bIsRemoved { return aIsRemoved }
            return a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
        }
        isScanning = false
    }

    /// Pages `node/ios_app_directory` sorted by `-created`, stopping as soon
    /// as a page's entries fall outside the window — mirrors
    /// `GuidelineViolationScanner.recentPosts` exactly. Safety-capped at 20
    /// pages (1000 entries); a real "recent activity" window shouldn't ever
    /// need more than a fraction of that.
    private static func recentIosListings(cutoff: Date) async throws -> [AppListing] {
        var results: [AppListing] = []
        var page = 0
        while page < 20 {
            let response = try await APIClient.shared.jsonAPIList(
                "node/ios_app_directory",
                query: ["sort": "-created", "include": "uid", "page[limit]": "50", "page[offset]": "\(page * 50)"]
            )
            if response.data.isEmpty { break }
            let included = response.included ?? []
            var reachedCutoff = false
            for node in response.data {
                if node.createdDate < cutoff {
                    reachedCutoff = true
                    break
                }
                results.append(Mappers.app(node, included: included))
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }

    /// Pages one whole category via the same native REST category-listing
    /// path Discover's own App Directory browsing uses
    /// (`AppEndpoints.list(categoryTid:)`). Exhaustive within that category
    /// — same reasoning as the original full-directory scan (a stale entry
    /// is just as likely to be delisted as a popular one) — but a category
    /// is normally a small enough slice that this stays quick. Safety-capped
    /// at 200 pages, matching the original scan's cap.
    private static func allListings(categoryTid: Int) async throws -> [AppListing] {
        var results: [AppListing] = []
        var page = 0
        while page < 200 {
            let batch = try await APIClient.shared.apps.list(page: page, platform: .ios, categoryTid: categoryTid)
            results.append(contentsOf: batch.items)
            if !batch.hasMore { break }
            page += 1
        }
        return results
    }

    private static func checkListings(_ listings: [AppListing]) async -> [AppHealthFlag] {
        // Only entries with an actual App Store link can be checked at all.
        let checkable = listings.compactMap { listing -> (listing: AppListing, appStoreId: String)? in
            guard let url = listing.appStoreUrl, let id = extractAppStoreId(url) else { return nil }
            return (listing, id)
        }

        var byId: [String: ItunesMetadata] = [:]
        for chunk in checkable.chunked(into: batchSize) {
            let ids = chunk.map(\.appStoreId)
            let found = await ItunesAPI.batchLookup(appStoreIds: ids)
            byId.merge(found) { current, _ in current }
        }

        var flags: [AppHealthFlag] = []
        for entry in checkable {
            guard let metadata = byId[entry.appStoreId] else {
                flags.append(AppHealthFlag(id: "removed-\(entry.listing.id)", appId: entry.listing.id, appName: entry.listing.name, kind: .removed))
                continue
            }
            // Same comparison Refresh App Details uses — this was a plain
            // string compare, so it flagged titles the app page then said
            // hadn't changed (an invisible mark, a doubled space, an
            // encoded "&"). Reported directly.
            let liveTitle = metadata.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !liveTitle.isEmpty, HTMLText.comparableText(liveTitle) != HTMLText.comparableText(entry.listing.name) {
                flags.append(AppHealthFlag(id: "title-\(entry.listing.id)", appId: entry.listing.id, appName: entry.listing.name, kind: .titleChanged(newTitle: liveTitle)))
            }
        }
        return flags
    }

    /// Same numeric-id extraction `ItunesAPI` uses internally, duplicated
    /// rather than exposed there — a one-line regex, not worth widening
    /// that type's API surface for.
    private static func extractAppStoreId(_ url: String) -> String? {
        guard let range = url.range(of: #"/id(\d+)"#, options: .regularExpression) else { return nil }
        return url[range].dropFirst(3).description
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
