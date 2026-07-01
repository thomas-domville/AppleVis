// Foundation Models native module for AppleVis.
// Wraps iOS 26 FoundationModels framework so the JS intelligence service
// (src/services/intelligenceService.ts) can call on-device AI without a network
// request. Compiles cleanly against older SDKs via #if canImport guards.
//
// After prebuild: copy both this file and AppleVisIntelligence.m into the
// main Xcode target (ios/AppleVis/).

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@objc(AppleVisIntelligence)
class AppleVisIntelligence: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  // Exposed synchronously as NativeModules.AppleVisIntelligence.isAvailable.
  // Re-checked inside respond() so a settings change mid-session is safe.
  override func constantsToExport() -> [AnyHashable: Any]! {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return ["isAvailable": SystemLanguageModel.default.isAvailable]
    }
    #endif
    return ["isAvailable": false]
  }

  // Runs `prompt` through the on-device language model and resolves with the
  // response string, or nil when the model is unavailable.
  @objc func respond(
    _ prompt: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    #if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else { resolve(nil); return }
    guard SystemLanguageModel.default.isAvailable else { resolve(nil); return }
    Task {
      do {
        let session  = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        resolve(response.content)
      } catch {
        reject("FOUNDATION_MODEL_ERROR", error.localizedDescription, error)
      }
    }
    #else
    resolve(nil)
    #endif
  }

  // Streaming variant — resolves with the complete accumulated text once the
  // stream finishes. JS callers that want incremental updates should use a
  // NativeEventEmitter pattern in a future iteration.
  @objc func stream(
    _ prompt: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    #if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else { resolve(nil); return }
    guard SystemLanguageModel.default.isAvailable else { resolve(nil); return }
    Task {
      do {
        let session = LanguageModelSession()
        var accumulated = ""
        for try await partial in session.streamResponse(to: prompt) {
          accumulated = partial.content
        }
        resolve(accumulated)
      } catch {
        reject("FOUNDATION_MODEL_ERROR", error.localizedDescription, error)
      }
    }
    #else
    resolve(nil)
    #endif
  }
}
