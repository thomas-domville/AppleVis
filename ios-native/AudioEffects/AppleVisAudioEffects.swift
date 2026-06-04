import AVFoundation
import React

/// Applies audio processing effects (voice boost EQ + silence trimming)
/// to the active AVAudioSession output using AVAudioEngine.
///
/// Because expo-av manages its own AVAudioEngine instance, this module
/// operates as a post-processing layer that intercepts the rendered PCM
/// stream via an output-tap approach. For voice boost it applies a
/// high-pass shelf and mid-range boost via AVAudioUnitEQ. Trim silence
/// monitors the RMS of incoming buffers and skips ahead when the level
/// drops below a configurable threshold.
///
/// NOTE: Full integration requires that expo-av exposes its internal
/// AVAudioEngine (planned for a future expo-av version). Until then, the
/// module is wired and ready but operates in a stub mode that logs intent.
/// Wire `setVoiceBoost` and `setTrimSilence` from JS whenever the native
/// engine reference becomes available.

@objc(AppleVisAudioEffects)
class AppleVisAudioEffects: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  private var voiceBoostEnabled = false
  private var trimSilenceEnabled = false

  // ── EQ nodes ──────────────────────────────────────────────────────────────
  private lazy var eq: AVAudioUnitEQ = {
    let unit = AVAudioUnitEQ(numberOfBands: 4)
    // High-pass: roll off rumble below 80 Hz
    unit.bands[0].filterType  = .highPass
    unit.bands[0].frequency   = 80
    unit.bands[0].bypass      = false
    // Low-mid boost: warmth 200–500 Hz
    unit.bands[1].filterType  = .parametric
    unit.bands[1].frequency   = 300
    unit.bands[1].bandwidth   = 1.0
    unit.bands[1].gain        = 2.0
    unit.bands[1].bypass      = false
    // Speech clarity boost: 1 kHz–4 kHz presence range
    unit.bands[2].filterType  = .parametric
    unit.bands[2].frequency   = 2500
    unit.bands[2].bandwidth   = 2.0
    unit.bands[2].gain        = 4.0
    unit.bands[2].bypass      = false
    // High shelf: subtle air 8 kHz+
    unit.bands[3].filterType  = .highShelf
    unit.bands[3].frequency   = 8000
    unit.bands[3].gain        = 1.5
    unit.bands[3].bypass      = false
    unit.bypass = true // start bypassed
    return unit
  }()

  @objc func setVoiceBoost(_ enabled: Bool) {
    voiceBoostEnabled = enabled
    eq.bypass = !enabled
    // When the native expo-av engine bridge is available, attach/detach
    // the eq node here. For now, log state change.
    if #available(iOS 17.0, *) {
      // AVAudioSession.sharedInstance().voiceProcessingEnabled = enabled
      // (requires iOS 17+ and record permission; use as alternative path)
    }
    print("[AudioEffects] Voice boost \(enabled ? "ON" : "OFF")")
  }

  /// Silence threshold in dBFS (-50 dBFS means "essentially silent").
  private let silenceThresholdDB: Float = -50.0
  /// How many consecutive silent frames before skipping forward.
  private let silenceFrameThreshold = 10
  private var silentFrameCount = 0

  @objc func setTrimSilence(_ enabled: Bool) {
    trimSilenceEnabled = enabled
    print("[AudioEffects] Trim silence \(enabled ? "ON" : "OFF")")
    // When the native engine bridge is available, install/remove a
    // render observer that measures RMS per buffer and posts a
    // 'skipForward500ms' notification to JS when silent runs exceed
    // `silenceFrameThreshold` buffers.
  }

  // ── RMS helper ────────────────────────────────────────────────────────────
  private func rmsLevel(buffer: AVAudioPCMBuffer) -> Float {
    guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return -160 }
    var rms: Float = 0
    let frames = Int(buffer.frameLength)
    vDSP_measqv(data[0], 1, &rms, vDSP_Length(frames))
    return rms > 0 ? 10 * log10f(rms) : -160
  }
}
