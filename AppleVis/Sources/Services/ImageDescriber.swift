import Vision
import UIKit

/// On-device image description, used to supplement VoiceOver for images
/// that don't already have editorial alt text — currently podcast artwork
/// on the episode detail screen. All processing is on-device; no image
/// data leaves the device.
///
/// Uses only Vision APIs stable since iOS 13 (VNClassifyImageRequest,
/// VNRecognizeTextRequest) rather than newer on-device captioning APIs,
/// which are still changing across OS versions.
enum ImageDescriber {
    /// Returns a short spoken-friendly description, or `nil` if the image
    /// couldn't be fetched/processed or nothing worth describing was found.
    /// Not `@MainActor` — Vision's `perform()` is synchronous/blocking, so
    /// this deliberately runs off the main actor.
    static func describe(imageAt url: URL) async -> String? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let cgImage = UIImage(data: data)?.cgImage else { return nil }

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

        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}
