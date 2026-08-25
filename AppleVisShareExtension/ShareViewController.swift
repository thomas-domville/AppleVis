// Share Extension for AppleVis.
//
// Handles four types of shared content:
//   • App Store URLs               → applevis://submit-app?url=…
//   • Plain text / .txt/.md/.rtf files → applevis://submit-blog?text=…
//   • Podcast URLs (Apple Podcasts, Spotify, etc.) → applevis://submit-podcast?url=…
//   • Audio files (.mp3/.m4a/.wav)  → applevis://submit-podcast-audio
//
// No UI is shown — the extension deep-links into the main app and dismisses
// immediately. AppShareConsumer (main app target) reads the values this
// writes to the shared App Group on next foreground. Audio is the one
// exception to "values" — it's too large for UserDefaults, so the file
// itself is copied into the shared App Group *container* instead (a
// disk-to-disk copy, not loaded into this extension's own memory, which
// stays well under the process's tight memory ceiling even for the real
// form's 200 MB limit); only the original filename goes into UserDefaults.
// Reported directly.

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private static let appGroupSuite         = "group.com.applevis.app"
    private static let pendingURLKey         = "pendingAppShareURL"
    private static let pendingBlogTextKey    = "pendingBlogText"
    private static let pendingPodcastURLKey  = "pendingPodcastURL"
    private static let pendingAudioNameKey   = "pendingPodcastAudioName"
    private static let sharedAudioFilename   = "pending_podcast_audio"

    override func viewDidLoad() {
        super.viewDidLoad()
        classify { [weak self] action in
            guard let self else { return }
            switch action {
            case .appStore(let url):  self.handleAppStoreURL(url)
            case .podcast(let url):   self.handlePodcastURL(url)
            case .blogText(let text): self.handleBlogText(text)
            case .podcastAudio(let url, let name): self.handlePodcastAudio(fileURL: url, suggestedName: name)
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
        case podcastAudio(URL, String)
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

        // 3. Audio files (podcast episode uploads) — checked before the
        // generic file/text fallback below, since an audio file also
        // conforms to `public.data` and would otherwise be force-read as
        // UTF-8 text there (silently failing on the binary content).
        let audioType = UTType.audio.identifier
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(audioType) {
                provider.loadItem(forTypeIdentifier: audioType, options: nil) { item, _ in
                    let fileURL = item as? URL
                    DispatchQueue.main.async {
                        guard let fileURL else { completion(.none); return }
                        completion(.podcastAudio(fileURL, fileURL.lastPathComponent))
                    }
                }
                return
            }
        }

        // 4. File attachments (.txt, .md, .rtf).
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(fileType) {
                provider.loadItem(forTypeIdentifier: fileType, options: nil) { item, _ in
                    let fileURL = item as? URL
                    DispatchQueue.main.async {
                        guard let fileURL,
                              let text = Self.decodeTextFile(at: fileURL),
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

    /// A plain `String(contentsOf:encoding:.utf8)` read doesn't fail on an
    /// `.rtf` file — RTF's own markup is text-based — so sharing one in
    /// produced raw `{\rtf1\ansi...}` control-code text as the blog draft
    /// instead of the actual document content. Decodes through
    /// `NSAttributedString` for `.rtf` specifically; every other file
    /// keeps the plain UTF-8 read. Same fix as `SubmitBlogView`'s in-wizard
    /// file importer. Reported directly.
    private static func decodeTextFile(at url: URL) -> String? {
        if url.pathExtension.lowercased() == "rtf" {
            guard let data = try? Data(contentsOf: url),
                  let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            else { return nil }
            return attributed.string
        }
        return try? String(contentsOf: url, encoding: .utf8)
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

    /// Copies the shared audio file into the shared App Group container
    /// under a fixed name (disk-to-disk, not loaded into this extension's
    /// memory) and records only the original filename in UserDefaults —
    /// `AppShareConsumer` reads the bytes back on the main app side, where
    /// memory headroom isn't the tight constraint it is in an extension.
    /// Clears any previous pending audio first, so a stale file from an
    /// earlier, abandoned share can't get picked up by this one.
    private func handlePodcastAudio(fileURL: URL, suggestedName: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupSuite) else {
            extensionContext?.cancelRequest(withError: NSError(
                domain: "com.applevis.shareextension", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't prepare shared storage."]
            ))
            return
        }
        let destination = containerURL.appendingPathComponent(Self.sharedAudioFilename)
        try? FileManager.default.removeItem(at: destination)
        guard (try? FileManager.default.copyItem(at: fileURL, to: destination)) != nil else {
            extensionContext?.cancelRequest(withError: NSError(
                domain: "com.applevis.shareextension", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't copy the audio file."]
            ))
            return
        }
        UserDefaults(suiteName: Self.appGroupSuite)?.set(suggestedName, forKey: Self.pendingAudioNameKey)
        deepLink(host: "submit-podcast-audio", query: [])
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
