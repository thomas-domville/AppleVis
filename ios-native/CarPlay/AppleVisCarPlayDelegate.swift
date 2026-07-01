import CarPlay
import React

/// CarPlay integration for AppleVis podcast playback.
///
/// Implements CPTemplateApplicationSceneDelegate to present a browsable
/// episode list (CPListTemplate) and the system Now Playing screen
/// (CPNowPlayingTemplate). Episodes are fed from JS via the
/// `AppleVisCarPlay` React Native module whenever the feed loads.
///
/// Setup in app.config.ts / Info.plist:
///   UIApplicationSceneManifest → UISceneConfigurations →
///   CPTemplateApplicationSceneSessionRoleApplication entry.
///
/// The JS layer calls updateEpisodes([...]) after every feed refresh.
/// Tapping an item sends a 'carPlayPlayEpisode' event back to JS so the
/// player can load it without the user touching their phone.

// ── JS → Native module ────────────────────────────────────────────────────────
@objc(AppleVisCarPlay)
class AppleVisCarPlayModule: RCTEventEmitter {

  static var shared: AppleVisCarPlayModule?

  private var episodes: [[String: Any]] = []

  override init() {
    super.init()
    AppleVisCarPlayModule.shared = self
  }

  override static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! {
    return ["carPlayPlayEpisode", "carPlayConnected", "carPlayDisconnected"]
  }

  @objc func updateEpisodes(_ items: NSArray) {
    episodes = items.compactMap { $0 as? [String: Any] }
    // Reload the CarPlay list template if one is currently displayed.
    DispatchQueue.main.async {
      AppleVisCarPlaySceneDelegate.shared?.reloadList(episodes: self.episodes)
    }
  }
}

// ── CarPlay scene delegate ────────────────────────────────────────────────────
class AppleVisCarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

  static weak var shared: AppleVisCarPlaySceneDelegate?
  private var interfaceController: CPInterfaceController?
  // Retain the list template so we can update its sections in-place
  // rather than pushing a new root and blowing away the navigation stack.
  private var listTemplate: CPListTemplate?

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    self.interfaceController = interfaceController
    AppleVisCarPlaySceneDelegate.shared = self

    AppleVisCarPlayModule.shared?.sendEvent(
      withName: "carPlayConnected", body: nil)

    let episodes = AppleVisCarPlayModule.shared.map { m in
      m.value(forKey: "episodes") as? [[String: Any]] ?? []
    } ?? []
    let template = makeListTemplate(episodes: episodes)
    listTemplate = template
    interfaceController.setRootTemplate(template, animated: false, completion: nil)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
  ) {
    self.interfaceController = nil
    listTemplate = nil
    AppleVisCarPlayModule.shared?.sendEvent(
      withName: "carPlayDisconnected", body: nil)
  }

  func reloadList(episodes: [[String: Any]]) {
    let items = makeListItems(episodes: episodes)
    if let existing = listTemplate {
      // Update sections in-place — preserves the nav stack (e.g. Now Playing screen)
      existing.updateSections([CPListSection(items: items)])
    } else if let controller = interfaceController {
      let template = CPListTemplate(title: "AppleVis Podcasts",
                                   sections: [CPListSection(items: items)])
      listTemplate = template
      controller.setRootTemplate(template, animated: false, completion: nil)
    }
  }

  // ── Build the episode browse list ─────────────────────────────────────────

  private func makeListItems(episodes: [[String: Any]]) -> [CPListItem] {
    episodes.prefix(100).map { ep in
      let title     = ep["title"]     as? String ?? "Episode"
      let showTitle = ep["showTitle"] as? String ?? ""
      let duration  = ep["duration"]  as? Double ?? 0
      let mins      = Int(duration / 60)
      let downloaded = ep["isDownloaded"] as? Bool ?? false
      var detail    = mins > 0 ? "\(showTitle) · \(mins) min" : showTitle
      if downloaded { detail += " · Downloaded" }

      let item = CPListItem(text: title, detailText: detail)
      item.accessoryType = .disclosureIndicator
      item.handler = { [weak self] _, completion in
        self?.playEpisode(ep)
        completion()
      }
      return item
    }
  }

  private func makeListTemplate(episodes: [[String: Any]]) -> CPListTemplate {
    let template = CPListTemplate(title: "AppleVis Podcasts",
                                  sections: [CPListSection(items: makeListItems(episodes: episodes))])
    return template
  }

  private func playEpisode(_ ep: [String: Any]) {
    AppleVisCarPlayModule.shared?.sendEvent(
      withName: "carPlayPlayEpisode",
      body: ep
    )
    // Switch to Now Playing screen
    if let controller = interfaceController {
      let nowPlaying = CPNowPlayingTemplate.shared
      controller.pushTemplate(nowPlaying, animated: true, completion: nil)
    }
  }
}
