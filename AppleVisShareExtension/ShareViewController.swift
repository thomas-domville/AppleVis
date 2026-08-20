// Share Extension for AppleVis.
//
// Handles three types of shared content:
//   • App Store URLs               → applevis://submit-app?url=…
//   • Plain text / .txt/.md files  → applevis://submit-blog?text=…
//   • Podcast URLs (Apple Podcasts, Spotify, etc.) → applevis://submit-podcast?url=…
//
// No UI is shown — the extension deep-links into the main app and dismisses
// immediately. AppShareConsumer (main app target) reads the values this
// writes to the shared App Group on next foreground.

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private static let appGroupSuite        = "group.com.applevis.app"
    private static let pendingURLKey        = "pendingAppShareURL"
    private static let pendingBlogTextKey   = "pendingBlogText"
    private static let pendingPodcastURLKey = "pendingPodcastURL"

    override func viewDidLoad() {
        super.viewDidLoad()
        classify { [weak self] action in
            guard let self else { return }
            switch action {
            case .appStore(let url):  self.handleAppStoreURL(url)
            case .podcast(let url):   self.handlePodcastURL(url)
            case .blogText(let text): self.handleBlogText(text)
            case .none:
                self.extensionContext?.cancelRequest(withError: NSError(
                    domain: "com.applevis.shareextension", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported content type"]
                ))
            }
        }
    }

    // MARK: - Classification

    private enum ShareAction {
        case appStore(URL)
        case podcast(URL)
        case blogText(String)
        case none
    }

    private func classify(completion: @escaping (ShareAction) -> Void) {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = item.attachments
        else { completion(.none); return }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier
        let fileType = UTType.data.identifier

        // 1. URL items first.
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { item, _ in
                    let url: URL? = {
                        if let u = item as? URL { return u }
                        if let s = item as? String { return URL(string: s) }
                        return nil
                    }()
                    DispatchQueue.main.async {
                        guard let url else { completion(.none); return }
                        if Self.isAppStoreURL(url) {
                            completion(.appStore(url))
                        } else if Self.isPodcastURL(url) {
                            completion(.podcast(url))
                        } else {
                            completion(.none)
                        }
                    }
                }
                return
            }
        }

        // 2. Plain text (could be a blog draft, or a URL pasted as text).
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(textType) {
                provider.loadItem(forTypeIdentifier: textType, options: nil) { item, _ in
                    let text = (item as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    DispatchQueue.main.async {
                        guard let text, !text.isEmpty else { completion(.none); return }
                        if let url = URL(string: text) {
                            if Self.isAppStoreURL(url) { completion(.appStore(url)); return }
                            if Self.isPodcastURL(url) { completion(.podcast(url)); return }
                        }
                        completion(.blogText(text))
                    }
                }
                return
            }
        }

        // 3. File attachments (.txt, .md).
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(fileType) {
                provider.loadItem(forTypeIdentifier: fileType, options: nil) { item, _ in
                    let fileURL = item as? URL
                    DispatchQueue.main.async {
                        guard let fileURL,
                              let text = try? String(contentsOf: fileURL, encoding: .utf8),
                              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else { completion(.none); return }
                        completion(.blogText(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                }
                return
            }
        }

        completion(.none)
    }

    // MARK: - URL helpers

    private static func isAppStoreURL(_ url: URL) -> Bool {
        let host = url.host ?? ""
        return host == "apps.apple.com" || host == "itunes.apple.com"
    }

    private static func isPodcastURL(_ url: URL) -> Bool {
        let host = url.host ?? ""
        return host.contains("podcasts.apple.com")
            || host.contains("anchor.fm")
            || host.contains("spotify.com")
            || host.contains("overcast.fm")
            || host.contains("pocketcasts.com")
            || host.contains("castbox.fm")
    }

    // MARK: - Handlers

    private func handleAppStoreURL(_ url: URL) {
        let defaults = UserDefaults(suiteName: Self.appGroupSuite)
        defaults?.set(url.absoluteString, forKey: Self.pendingURLKey)
        deepLink(host: "submit-app", query: [URLQueryItem(name: "url", value: url.absoluteString)])
    }

    private func handlePodcastURL(_ url: URL) {
        let defaults = UserDefaults(suiteName: Self.appGroupSuite)
        defaults?.set(url.absoluteString, forKey: Self.pendingPodcastURLKey)
        deepLink(host: "submit-podcast", query: [URLQueryItem(name: "url", value: url.absoluteString)])
    }

    private func handleBlogText(_ text: String) {
        let defaults = UserDefaults(suiteName: Self.appGroupSuite)
        defaults?.set(text, forKey: Self.pendingBlogTextKey)
        deepLink(host: "submit-blog", query: [URLQueryItem(name: "text", value: text)])
    }

    private func deepLink(host: String, query: [URLQueryItem]) {
        var components = URLComponents()
        components.scheme = "applevis"
        components.host = host
        components.queryItems = query

        guard let url = components.url else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        extensionContext?.open(url, completionHandler: { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
    }
}
