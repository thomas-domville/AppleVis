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
        /// The titles differ only in capitalization, punctuation, spacing,
        /// or an added or dropped subtitle ("No wifi mini games" vs "No Wifi
        /// Mini Games"). Still flagged so the entry can be matched exactly,
        /// but in its own group, since it's rarely urgent. Requested
        /// directly: minor differences should still appear, not be ignored.
        case minorTitleDifference(newTitle: String)
        /// The title still matches, but other App Store details (version,
        /// description, supported devices) don't. Listed in
        /// `outdatedFields`. Requested directly.
        case detailsOutdated

        /// Which results section the flag belongs to, in display order.
        var group: Group {
            switch self {
            case .removed:              return .removed
            case .titleChanged:         return .titleChanged
            case .detailsOutdated:      return .detailsOutdated
            case .minorTitleDifference: return .minorTitleDifference
            }
        }
    }

    enum Group: Int, CaseIterable, Identifiable {
        case removed, titleChanged, detailsOutdated, minorTitleDifference
        var id: Self { self }
    }

    /// One App Store detail, other than the title, that no longer matches.
    /// Found with the same comparison Refresh App Details uses
    /// (`AppInfoFieldDiff`), so a row and that sheet always agree.
    struct OutdatedField: Hashable {
        let id: String
        let label: String
        /// Short values worth reading out (version, devices). `nil` for a
        /// description, which is too long to repeat in a row.
        let oldValue: String?
        let newValue: String?

        /// English name for the shared report, which goes to the editorial team.
        var englishLabel: String {
            switch id {
            case "version":     return "Version"
            case "description": return "Description"
            case "devices":     return "Supported Devices"
            case "link":        return "App Store Link (not the neutral link)"
            default:            return id
            }
        }
    }

    let id: String
    let appId: String
    let appName: String
    let kind: Kind
    /// Every other detail that's out of date, whatever the kind. Empty for
    /// removed apps and when the entry's details couldn't be loaded.
    var outdatedFields: [OutdatedField] = []
    /// The entry's AppleVis page and its stored App Store link, for Share
    /// and Open in App Store.
    var appleVisUrl: String = ""
    var appStoreUrl: String? = nil
}

/// What the last scan covered, so its results and Try Again survive leaving
/// the screen.
enum AppHealthScanScope: Equatable {
    case recent(AppHealthScanRange)
    case category(AppCategory)

    var displayName: String {
        switch self {
        case .recent(let range):       return range.displayName
        case .category(let category):  return category.name
        }
    }
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
    /// Shared so the last results are still there after leaving the screen
    /// and coming back, instead of needing a fresh scan every time.
    /// Requested directly.
    static let shared = AppEntryHealthScanner()

    @Published private(set) var flags: [AppHealthFlag] = []
    /// What the last scan covered and when it finished.
    @Published private(set) var lastScope: AppHealthScanScope?
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var isScanning = false
    @Published private(set) var scannedAppCount = 0
    /// Progress through loading each entry's full details, the slow part
    /// of a scan, so the Scanning row can say how far along it is.
    @Published private(set) var detailsChecked = 0
    @Published private(set) var detailsTotal = 0
    /// True between Stop and the scan actually winding down.
    @Published private(set) var isStopping = false
    /// The last scan was stopped early, so its results cover only part of
    /// what was asked for.
    @Published private(set) var lastScanWasStopped = false
    private var stopRequested = false
    @Published var error: String?
    /// For the "By Category" picker — populated once via `loadCategories()`,
    /// not tied to either scan itself.
    @Published private(set) var categories: [AppCategory] = []

    private var currentScanId = UUID()

    /// iTunes's lookup accepts a comma-separated id list; kept well under
    /// any plausible undocumented URL-length or per-request limit rather
    /// than tested against one.
    private static let batchSize = 100
    /// Entries per bulk request to AppleVis. Keeps each request's URL a
    /// sensible length (every id is in it).
    private static let siteBatchSize = 50

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

    /// Ends a long scan early. It finishes the chunk it's on, then shows
    /// what it found so far. Requested directly.
    func stop() {
        guard isScanning, !stopRequested else { return }
        stopRequested = true
        isStopping = true
    }

    func scanRecent(range: AppHealthScanRange) async {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
        await runScan(scope: .recent(range)) { try await Self.recentIosListings(cutoff: cutoff) }
    }

    func scanCategory(_ category: AppCategory) async {
        await runScan(scope: .category(category)) { try await Self.allListings(categoryTid: category.tid) }
    }

    /// Runs the last scan again — Try Again after an error.
    func repeatLastScan() async {
        switch lastScope {
        case .recent(let range):       await scanRecent(range: range)
        case .category(let category):  await scanCategory(category)
        case nil:                      break
        }
    }

    private func runScan(scope: AppHealthScanScope, fetchListings: () async throws -> [AppListing]) async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        scannedAppCount = 0
        detailsChecked = 0
        detailsTotal = 0
        stopRequested = false
        isStopping = false
        lastScanWasStopped = false
        lastScope = scope
        lastScanDate = nil

        // Everything the scan reads comes live from the site, not the
        // phone's copy from up to a minute before, so entries just
        // refreshed aren't flagged again. Reported directly (2026-10-02).
        let listings: [AppListing]
        do {
            listings = try await HTTPCacheBypass.$isOn.withValue(true) { try await fetchListings() }
        } catch {
            guard currentScanId == scanId else { return }
            // `Text(error)` in AppEntryHealthCheckView shows this as a plain
            // String, which never consults the localization catalog for
            // anything but a `LocalizedStringKey` — has to be resolved here.
            self.error = String(localized: "Couldn't load the App Directory. Try again.")
            isScanning = false
            isStopping = false
            return
        }
        guard currentScanId == scanId else { return }
        scannedAppCount = listings.count

        let outcome = await HTTPCacheBypass.$isOn.withValue(true) { await Self.checkListings(
            listings,
            shouldStop: { [weak self] in self?.stopRequested ?? true },
            onProgress: { [weak self] done, total in
                guard let self, self.currentScanId == scanId else { return }
                self.detailsChecked = done
                self.detailsTotal = total
            }
        ) }
        guard currentScanId == scanId else { return }
        if outcome.stoppedEarly {
            // The summary then says how many were really checked.
            scannedAppCount = outcome.checkedCount
            lastScanWasStopped = true
        }
        stopRequested = false
        isStopping = false
        let results = outcome.flags

        flags = results.sorted { a, b in
            if a.kind.group != b.kind.group { return a.kind.group.rawValue < b.kind.group.rawValue }
            return a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
        }
        lastScanDate = Date()
        isScanning = false
    }

    /// The same test the App Entry page uses before saying an app was
    /// renamed: ignoring capitalization, punctuation, and spacing, the
    /// titles match, or one is the other plus a subtitle.
    nonisolated static func isMinorTitleDifference(_ ours: String, _ theirs: String) -> Bool {
        func squashed(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let a = squashed(ours), b = squashed(theirs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.hasPrefix(b) || b.hasPrefix(a)
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

    /// Checks entries a chunk at a time: one App Store lookup and one or
    /// two bulk AppleVis requests per 100 apps. Games (about 430 entries)
    /// takes about 5 App Store requests and 9 AppleVis requests. It used
    /// to load every entry one by one, with its reviews, which came to
    /// hundreds of requests. Working in chunks is also what lets Stop keep
    /// the results found so far. Requested directly.
    private static func checkListings(
        _ listings: [AppListing],
        shouldStop: () -> Bool,
        onProgress: (_ done: Int, _ total: Int) -> Void
    ) async -> (flags: [AppHealthFlag], checkedCount: Int, stoppedEarly: Bool) {
        // Only entries with an actual App Store link can be checked at all.
        let checkable = listings.compactMap { listing -> (listing: AppListing, appStoreId: String)? in
            guard let url = listing.appStoreUrl, let id = extractAppStoreId(url) else { return nil }
            return (listing, id)
        }

        var flags: [AppHealthFlag] = []
        var done = 0
        onProgress(0, checkable.count)
        for chunk in checkable.chunked(into: batchSize) {
            if shouldStop() {
                // Entries with no App Store link count as looked at.
                return (flags, listings.count - checkable.count + done, true)
            }
            async let storeLookup = ItunesAPI.batchLookup(appStoreIds: chunk.map(\.appStoreId))
            // The directory lists don't include an entry's version or full
            // description, so the entries themselves are loaded in bulk,
            // without reviews. If a request fails, those entries still get
            // the title and removed checks.
            var details: [String: AppDetail] = [:]
            for siteChunk in chunk.map(\.listing.id).chunked(into: siteBatchSize) {
                if let batch = try? await APIClient.shared.apps.iosDetailsWithoutReviews(ids: siteChunk) {
                    for detail in batch { details[detail.id] = detail }
                }
            }
            let byId = await storeLookup
            for entry in chunk {
                if let flag = flag(for: entry.listing, metadata: byId[entry.appStoreId], detail: details[entry.listing.id]) {
                    flags.append(flag)
                }
            }
            done += chunk.count
            onProgress(done, checkable.count)
        }
        return (flags, listings.count, false)
    }

    /// What's wrong with one entry, if anything.
    private static func flag(for listing: AppListing, metadata: ItunesMetadata?, detail: AppDetail?) -> AppHealthFlag? {
        guard let metadata else {
            return AppHealthFlag(
                id: "removed-\(listing.id)", appId: listing.id, appName: listing.name, kind: .removed,
                appleVisUrl: listing.url, appStoreUrl: listing.appStoreUrl
            )
        }
        // The link counts only when the one on file isn't the neutral
        // form (https://apps.apple.com/app/id…): it names a country or the
        // app, or has a tracking tag. AppInfoFieldDiff compares by the
        // app's id, so the App Store's own tracking bits never count. It
        // used to be skipped entirely, so a scan never found a /us/ link.
        // Requested directly (2026-10-08).
        let outdated: [AppHealthFlag.OutdatedField] = detail.map { detail in
            AppInfoFieldDiff.build(detail: detail, metadata: metadata)
                .filter { $0.changed && $0.id != "title" }
                .map { diff in
                    let showsValues = diff.id == "version" || diff.id == "devices"
                    return AppHealthFlag.OutdatedField(
                        id: diff.id, label: diff.label,
                        oldValue: showsValues ? diff.oldValue : nil,
                        newValue: showsValues ? diff.newValue : nil
                    )
                }
        } ?? []

        // Same comparison Refresh App Details uses — this was a plain
        // string compare, so it flagged titles the app page then said
        // hadn't changed (an invisible mark, a doubled space, an
        // encoded "&"). Reported directly.
        let storedTitle = detail?.name ?? listing.name
        let liveTitle = metadata.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveTitle.isEmpty, HTMLText.comparableText(liveTitle) != HTMLText.comparableText(storedTitle) {
            let kind: AppHealthFlag.Kind = isMinorTitleDifference(storedTitle, liveTitle)
                ? .minorTitleDifference(newTitle: liveTitle)
                : .titleChanged(newTitle: liveTitle)
            return AppHealthFlag(
                id: "title-\(listing.id)", appId: listing.id, appName: listing.name, kind: kind,
                outdatedFields: outdated,
                appleVisUrl: listing.url, appStoreUrl: listing.appStoreUrl
            )
        }
        guard !outdated.isEmpty else { return nil }
        return AppHealthFlag(
            id: "details-\(listing.id)", appId: listing.id, appName: listing.name, kind: .detailsOutdated,
            outdatedFields: outdated,
            appleVisUrl: listing.url, appStoreUrl: listing.appStoreUrl
        )
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
