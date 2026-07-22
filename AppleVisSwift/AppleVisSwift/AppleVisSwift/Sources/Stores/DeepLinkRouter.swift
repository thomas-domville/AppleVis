import Foundation
import Combine

/// Resolves Spotlight search-result taps and (best-effort) universal links
/// into in-app navigation. Spotlight identifiers are our own encoding
/// (kind.id), so those resolve reliably. Real applevis.com URLs from
/// Universal Links don't map to a fetchable JSON:API id without a
/// path-alias-resolution endpoint this app doesn't implement — those open in
/// an in-app browser instead of a fabricated (and likely wrong) deep link.
@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var pendingContent: (kind: ContentKind, id: String)?
    @Published var pendingWebURL: URL?

    func handleSpotlight(identifier: String) {
        guard let resolved = SpotlightIndexer.parse(identifier: identifier) else { return }
        pendingContent = resolved
    }

    func handleUniversalLink(_ url: URL) {
        guard url.host?.contains("applevis.com") == true else { return }
        pendingWebURL = url
    }
}
