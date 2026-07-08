// On-device image description for AppleVis (Vision framework).
//
// Used to auto-describe images that don't already have editorial alt text —
// currently podcast artwork on the episode detail screen (app/episode/[id].tsx).
// All processing is on-device; no image data leaves the device.
//
// Uses only Vision APIs available since iOS 13 (VNClassifyImageRequest,
// VNRecognizeTextRequest) rather than newer on-device captioning APIs, since
// those are still changing across OS versions and a wrong guess here would
// fail to compile for the whole app, not just this feature.

import Vision
import UIKit

@objc(AppleVisVision)
class AppleVisVision: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  @objc func describeImage(
    _ imageUrl: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let url = URL(string: imageUrl) else { resolve(NSNull()); return }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data, let cgImage = UIImage(data: data)?.cgImage else {
        resolve(NSNull())
        return
      }

      let classifyRequest = VNClassifyImageRequest()
      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate

      let handler = VNImageRequestHandler(cgImage: cgImage)
      try? handler.perform([classifyRequest, textRequest])

      let topLabels = (classifyRequest.results ?? [])
        .filter { $0.confidence > 0.3 }
        .prefix(3)
        .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

      let recognizedText = (textRequest.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")

      var parts: [String] = []
      if !topLabels.isEmpty { parts.append("Image likely containing: \(topLabels.joined(separator: ", "))") }
      if !recognizedText.isEmpty { parts.append("Text in image: \(recognizedText)") }

      resolve(parts.isEmpty ? NSNull() : parts.joined(separator: ". "))
    }.resume()
  }
}
