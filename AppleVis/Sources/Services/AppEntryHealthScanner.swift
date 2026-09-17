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

/// Scans every iOS App Directory entry against the live App Store, for the
/// App Directory Health Check admin screen. Two-phase, deliberately kept
/// cheap: phase one lists every entry via the same paginated, already-cached
/// `AppEndpoints.list` call the App Directory browse screen itself uses (6
/// hour fresh window — a scan run twice in the same afternoon costs nothing
/// extra for this part). Phase two batches every entry's App Store id into
/// as few `ItunesAPI.batchLookup` requests as possible, rather than the one-
/// request-per-app the single-app "Refresh App Details" flow uses — checking
/// a few hundred apps one at a time would risk Apple's rate limit.
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

    private var currentScanId = UUID()

    /// iTunes's lookup accepts a comma-separated id list; kept well under
    /// any plausible undocumented URL-length or per-request limit rather
    /// than tested against one.
    private static let batchSize = 100

    func scan() async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        scannedAppCount = 0

        let listings: [AppListing]
        do {
            listings = try await Self.allIosListings()
        } catch {
            guard currentScanId == scanId else { return }
            self.error = "Couldn't load the App Directory. Try again."
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

    /// Pages through the iOS App Directory until a page comes back with
    /// fewer than a full page (or empty) — no time-window early exit here,
    /// unlike the forum scanner: a stale, rarely-viewed entry is just as
    /// likely to be quietly delisted as a popular one, so this has to look
    /// at everything. Safety-capped at 200 pages.
    private static func allIosListings() async throws -> [AppListing] {
        var results: [AppListing] = []
        var page = 0
        while page < 200 {
            let batch = try await APIClient.shared.apps.list(page: page)
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
            let liveTitle = metadata.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedTitle = entry.listing.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !liveTitle.isEmpty, liveTitle != storedTitle {
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
