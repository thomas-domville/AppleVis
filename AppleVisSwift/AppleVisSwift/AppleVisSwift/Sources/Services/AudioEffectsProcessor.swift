import AVFoundation
import CoreMedia
import MediaToolbox
import Accelerate

/// Real-time podcast audio processing — Voice Boost, the Equaliser presets,
/// and Trim Silence (Settings → Podcasts → Audio Enhancement) — applied via
/// an `MTAudioProcessingTap` on the player item's audio track.
///
/// Deliberately uses simple one-pole filters instead of a parametric biquad
/// EQ: less surgical, but unconditionally stable — no coefficient
/// combination here can ring, clip, or produce NaNs, which matters on a
/// real-time audio thread this code can't be interactively tuned on.
final class AudioEffectsProcessor {
    static let shared = AudioEffectsProcessor()
    private init() {}

    // Read on the audio render thread; written from the main thread when
    // Settings change. A torn read of a Bool/enum risks at most one
    // glitched buffer of stale settings, never a crash.
    var voiceBoostEnabled = false
    var eqPreset: PodcastEQ = .flat
    var trimSilenceEnabled = false

    /// Invoked (already hopped to the main actor) when a sustained silence
    /// run should be skipped forward. PlayerStore sets this.
    var onSilenceSkip: ((TimeInterval) -> Void)?

    private struct ChannelState {
        var rumble: Float = 0
        var presenceLow: Float = 0
        var presenceHigh: Float = 0
        var bass: Float = 0
        var treble: Float = 0
    }

    private var channels: [ChannelState] = []
    private var sampleRate: Double = 44100
    private var silentRunFrames = 0
    private var lastSkipAt: CFAbsoluteTime = 0

    private static let silenceThresholdDB: Float = -50
    private static let silenceHoldSeconds: Double = 0.7
    private static let skipAheadSeconds: TimeInterval = 0.5
    private static let skipCooldown: CFAbsoluteTime = 1.0

    // MARK: - Tap construction

    /// Builds an `AVAudioMix` wired to this processor. Attach the result to
    /// the `AVPlayerItem` (`item.audioMix = mix`) before playback starts.
    /// Settings can still be toggled live afterward — `process(_:frameCount:)`
    /// re-reads `voiceBoostEnabled`/`eqPreset`/`trimSilenceEnabled` on every
    /// buffer rather than baking them in at construction time.
    func makeAudioMix(for audioTrack: AVAssetTrack) -> AVAudioMix {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var tap: MTAudioProcessingTap?
        MTAudioProcessingTapCreate(
            kCFAllocatorDefault, &callbacks,
            kMTAudioProcessingTapCreationFlag_PreEffects, &tap
        )

        let params = AVMutableAudioMixInputParameters(track: audioTrack)
        params.audioTapProcessor = tap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }

    // MARK: - Called from the C trampolines below

    fileprivate func prepare(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        channels = Array(repeating: ChannelState(), count: max(channelCount, 1))
        silentRunFrames = 0
    }

    fileprivate func process(_ bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        guard voiceBoostEnabled || eqPreset != .flat || trimSilenceEnabled else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        var quietestDB: Float = .greatestFiniteMagnitude

        for (index, buffer) in buffers.enumerated() {
            guard let raw = buffer.mData, frameCount > 0 else { continue }
            let samples = raw.assumingMemoryBound(to: Float.self)
            var state = index < channels.count ? channels[index] : ChannelState()

            for i in 0..<frameCount {
                var x = samples[i]
                if voiceBoostEnabled { x = applyVoiceBoost(x, &state) }
                switch eqPreset {
                case .flat: break
                case .speech:      x = applyPresenceBoost(x, &state, gain: 0.9)
                case .bassBoost:   x = applyBassBoost(x, &state)
                case .trebleBoost: x = applyTrebleBoost(x, &state)
                }
                samples[i] = x
            }
            if index < channels.count { channels[index] = state }

            if trimSilenceEnabled {
                var meanSquare: Float = 0
                vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(frameCount))
                let db = meanSquare > 0 ? 10 * log10f(meanSquare) : -160
                quietestDB = min(quietestDB, db)
            }
        }

        if trimSilenceEnabled { handleSilence(db: quietestDB, frameCount: frameCount) }
    }

    // MARK: - One-pole filter primitives

    /// Exponential-moving-average lowpass. `a` is always in [0, 1], so this
    /// can never become unstable regardless of cutoff or input.
    private func lowpass(_ x: Float, _ y: inout Float, cutoffHz: Float) -> Float {
        let rc = 1 / (2 * Float.pi * cutoffHz)
        let dt = Float(1 / sampleRate)
        let a = dt / (rc + dt)
        y += a * (x - y)
        return y
    }

    /// Cuts sub-80Hz rumble, then boosts vocal presence (~600Hz–3kHz).
    private func applyVoiceBoost(_ x: Float, _ state: inout ChannelState) -> Float {
        let deRumbled = x - lowpass(x, &state.rumble, cutoffHz: 80)
        return applyPresenceBoost(deRumbled, &state, gain: 0.8)
    }

    /// Boosts the band between two lowpass corners via difference-of-lowpasses
    /// (a simple bandpass), added back on top of the original signal.
    private func applyPresenceBoost(_ x: Float, _ state: inout ChannelState, gain: Float) -> Float {
        let low = lowpass(x, &state.presenceLow, cutoffHz: 600)
        let high = lowpass(x, &state.presenceHigh, cutoffHz: 3000)
        return x + gain * (high - low)
    }

    private func applyBassBoost(_ x: Float, _ state: inout ChannelState) -> Float {
        x + 0.7 * lowpass(x, &state.bass, cutoffHz: 150)
    }

    private func applyTrebleBoost(_ x: Float, _ state: inout ChannelState) -> Float {
        x + 0.7 * (x - lowpass(x, &state.treble, cutoffHz: 4000))
    }

    // MARK: - Trim Silence

    private func handleSilence(db: Float, frameCount: Int) {
        guard db < Self.silenceThresholdDB else {
            silentRunFrames = 0
            return
        }
        silentRunFrames += frameCount

        guard Double(silentRunFrames) / sampleRate >= Self.silenceHoldSeconds else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSkipAt >= Self.skipCooldown else { return }
        lastSkipAt = now
        silentRunFrames = 0

        let callback = onSilenceSkip
        DispatchQueue.main.async { callback?(Self.skipAheadSeconds) }
    }
}

// MARK: - MTAudioProcessingTap C callbacks
//
// Must be free functions, not closures or methods — MTAudioProcessingTapCallbacks
// fields are plain C function pointers. The AudioEffectsProcessor instance
// crosses the boundary via `clientInfo`/tap storage using `Unmanaged`.

private func tapInit(
    tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func tapFinalize(tap: MTAudioProcessingTap) {}

private func tapPrepare(
    tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let processor = Unmanaged<AudioEffectsProcessor>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()
    processor.prepare(
        sampleRate: processingFormat.pointee.mSampleRate,
        channelCount: Int(processingFormat.pointee.mChannelsPerFrame)
    )
}

private func tapUnprepare(tap: MTAudioProcessingTap) {}

private func tapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    let status = MTAudioProcessingTapGetSourceAudio(
        tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut
    )
    guard status == noErr else { return }

    let processor = Unmanaged<AudioEffectsProcessor>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()
    processor.process(bufferListInOut, frameCount: Int(numberFrames))
}
