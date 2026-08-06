import AVFoundation
import SwiftUI

/// Speaks text aloud on demand for sighted/low-vision users who aren't
/// running VoiceOver — matches the old app's per-row "Read Aloud" custom
/// action, a convenience for browsing without needing to visually read
/// every row.
@MainActor
final class TextToSpeechReader {
    static let shared = TextToSpeechReader()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func read(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
    }
}

/// Adds a "Read Aloud" custom action only when VoiceOver isn't running —
/// with VoiceOver on, the user already has the row's content spoken via
/// its accessibility label, so this would just be a redundant, confusing
/// second way to hear the same thing.
private struct ReadAloudAction: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        if UIAccessibility.isVoiceOverRunning {
            content
        } else {
            content.accessibilityAction(named: Text("Read Aloud")) {
                TextToSpeechReader.shared.read(text)
            }
        }
    }
}

extension View {
    func readAloudAction(_ text: String) -> some View {
        modifier(ReadAloudAction(text: text))
    }
}
