// CoreSpotlight indexing for AppleVis content.
// Forum topics, podcast episodes, and app listings indexed here appear in
// iOS system Search (swipe down from Home Screen).
// After prebuild: copy both this file and AppleVisSpotlight.m into the
// main Xcode target (ios/AppleVis/).

import CoreSpotlight
import Foundation

@objc(AppleVisSpotlight)
class AppleVisSpotlight: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  // Index an array of content items. Each item dict must have:
  //   id, title, description, contentType ('forumTopic'|'podcast'|'app'|'resource'), url
  @objc func index(
    _ items: NSArray,
    resolve: @escaping RCTPromiseResolveBlock,
    reject:  @escaping RCTPromiseRejectBlock
  ) {
    var searchableItems: [CSSearchableItem] = []
    for item in items {
      guard let dict = item as? NSDictionary else { continue }
      let attrs = CSSearchableItemAttributeSet(contentType: .text)
      attrs.title              = dict["title"]       as? String
      attrs.contentDescription = dict["description"] as? String
      attrs.relatedUniqueIdentifier = dict["url"]    as? String
      // Map contentType to a thumbnail keyword for grouped results
      if let type = dict["contentType"] as? String {
        attrs.keywords = [type, "AppleVis", "accessibility"]
      }
      let identifier = dict["id"] as? String ?? UUID().uuidString
      let searchable = CSSearchableItem(
        uniqueIdentifier: identifier,
        domainIdentifier: "com.applevis.app",
        attributeSet: attrs
      )
      searchable.expirationDate = Date.distantFuture
      searchableItems.append(searchable)
    }
    CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
      if let error = error { reject("SPOTLIGHT_INDEX_ERROR", error.localizedDescription, error) }
      else { resolve(nil) }
    }
  }

  // Remove a single item by ID.
  @objc func deindex(
    _ identifier: NSString,
    resolve: @escaping RCTPromiseResolveBlock,
    reject:  @escaping RCTPromiseRejectBlock
  ) {
    CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier as String]) { error in
      if let error = error { reject("SPOTLIGHT_DEINDEX_ERROR", error.localizedDescription, error) }
      else { resolve(nil) }
    }
  }

  // Remove all AppleVis items from Spotlight.
  @objc func deindexAll(
    _ resolve: @escaping RCTPromiseResolveBlock,
    reject:    @escaping RCTPromiseRejectBlock
  ) {
    CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.applevis.app"]) { error in
      if let error = error { reject("SPOTLIGHT_CLEAR_ERROR", error.localizedDescription, error) }
      else { resolve(nil) }
    }
  }
}
