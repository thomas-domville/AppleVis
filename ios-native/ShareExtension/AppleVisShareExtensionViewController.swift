// Share Extension for submitting App Store apps to AppleVis.
//
// When a user finds an accessible iOS app in the App Store (or Safari) they
// can tap Share → AppleVis to open the in-app submission form pre-filled with
// that app's details.
//
// Flow:
//   1. User taps Share → AppleVis in the system share sheet
//   2. This view controller validates the shared URL is an App Store link
//   3. Writes the URL to App Group UserDefaults as a fallback
//   4. Opens applevis://submit-app?url=[encoded] to bring the main app to
//      foreground with the URL already available
//   5. Calls extensionContext?.completeRequest() to dismiss the share sheet
//
// Xcode setup:
//   • Add a new "Share Extension" target named "AppleVisShareExtension"
//   • Set NSExtensionPrincipalClass to AppleVisShareExtensionViewController
//   • Add App Groups entitlement (group.com.applevis.app) to BOTH the main
//     app target AND this extension target
//   • Add NSExtensionActivationRule to Info.plist (see Info.plist in this dir)
//   • Add URL scheme "applevis" to the main app target's Info.plist so iOS
//     knows to route applevis:// to AppleVis
//
// No UI is shown — the extension immediately deep-links and dismisses.

import MobileCoreServices
import Social
import UIKit
import UniformTypeIdentifiers

class AppleVisShareExtensionViewController: UIViewController {

  private static let appGroupSuite = "group.com.applevis.app"
  private static let pendingURLKey  = "pendingAppShareURL"

  override func viewDidLoad() {
    super.viewDidLoad()
    extractAppStoreURL { [weak self] url in
      guard let self else { return }
      if let url {
        self.handleAppStoreURL(url)
      } else {
        // Not an App Store URL — dismiss silently.
        self.extensionContext?.cancelRequest(withError: NSError(
          domain: "com.applevis.shareextension",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Not an App Store URL"]
        ))
      }
    }
  }

  // ── URL extraction ──────────────────────────────────────────────────────────

  private func extractAppStoreURL(completion: @escaping (URL?) -> Void) {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let attachments = item.attachments
    else {
      completion(nil)
      return
    }

    // Try public.url first (Safari, App Store share)
    let urlType: String
    if #available(iOS 14.0, *) {
      urlType = UTType.url.identifier
    } else {
      urlType = kUTTypeURL as String
    }

    for provider in attachments {
      if provider.hasItemConformingToTypeIdentifier(urlType) {
        provider.loadItem(forTypeIdentifier: urlType, options: nil) { item, _ in
          let url: URL? = {
            if let u = item as? URL { return u }
            if let s = item as? String { return URL(string: s) }
            return nil
          }()
          DispatchQueue.main.async {
            completion(url.flatMap { Self.isAppStoreURL($0) ? $0 : nil })
          }
        }
        return
      }
    }

    // Try plain text (in case the URL comes as a string)
    let textType: String
    if #available(iOS 14.0, *) {
      textType = UTType.plainText.identifier
    } else {
      textType = kUTTypePlainText as String
    }

    for provider in attachments {
      if provider.hasItemConformingToTypeIdentifier(textType) {
        provider.loadItem(forTypeIdentifier: textType, options: nil) { item, _ in
          let url: URL? = {
            if let s = item as? String, let u = URL(string: s) { return u }
            return nil
          }()
          DispatchQueue.main.async {
            completion(url.flatMap { Self.isAppStoreURL($0) ? $0 : nil })
          }
        }
        return
      }
    }

    completion(nil)
  }

  private static func isAppStoreURL(_ url: URL) -> Bool {
    let host = url.host ?? ""
    return host == "apps.apple.com" || host == "itunes.apple.com"
  }

  // ── Deep link into main app ──────────────────────────────────────────────────

  private func handleAppStoreURL(_ appStoreURL: URL) {
    // Write to App Group UserDefaults as a belt-and-suspenders fallback.
    let defaults = UserDefaults(suiteName: Self.appGroupSuite)
    defaults?.set(appStoreURL.absoluteString, forKey: Self.pendingURLKey)
    defaults?.synchronize()

    // Build the deep-link URL with the App Store URL encoded as a query param.
    var components = URLComponents()
    components.scheme = "applevis"
    components.host   = "submit-app"
    components.queryItems = [URLQueryItem(name: "url", value: appStoreURL.absoluteString)]

    guard let deepLink = components.url else {
      extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
      return
    }

    // Open the main app. extensionContext?.open is the only API available in
    // a Share Extension (UIApplication.shared is not accessible).
    extensionContext?.open(deepLink, completionHandler: { [weak self] _ in
      self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    })
  }
}
