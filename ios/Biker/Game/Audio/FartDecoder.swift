import AVFoundation

/// One recording ready to schedule: a short loudness-matched slice for the motor, the whole thing for hits.
struct FartClip {
    let engine: AVAudioPCMBuffer
    let full: AVAudioPCMBuffer
}

/// Turns the bundled fart recordings into mono 44.1 kHz buffers. Slow (file decoding): call off the main thread.
enum FartDecoder {
    static let names: [String] = [
        "perdezh-40.mp3", "perdezh-puk-puk.mp3", "farts-42.mp3", "farts-8.mp3", "farts-4.mp3", "long-fart.mp3",
        "hard-01.m4a", "hard-02.m4a", "hard-03.m4a", "hard-04.m4a", "hard-05.m4a",
        "hard-06.m4a", "hard-07.m4a", "hard-08.m4a", "hard-09.m4a", "hard-10.m4a",
    ]

    private static let rate = GameAudioFormat.sampleRate
    private static let maxSourceSeconds: Double = 20
    private static let engineMaxSeconds: Double = 1.1
    private static let engineMinSeconds: Double = 0.2
    private static let fullMaxSeconds: Double = 2.8
    private static let fadeInSeconds: Double = 0.006
    private static let engineFadeOutSeconds: Double = 0.07
    private static let fullFadeOutSeconds: Double = 0.12
    private static let engineTargetRMS: Float = 0.2
    private static let peakLimit: Float = 0.95
    private static let silenceFraction: Float = 0.04
    private static let trimMarginSeconds: Double = 0.004

    /// Every recording that decodes; a missing or broken file is simply skipped.
    static func decodeAll(bundle: Bundle = .main) -> [FartClip] {
        names.compactMap { name -> FartClip? in
            guard
                let url = bundle.url(forResource: name, withExtension: nil),
                let samples = MonoFileReader.read(url, maxSeconds: maxSourceSeconds),
                let trimmed = trimSilence(samples)
            else { return nil }
            return makeClip(trimmed)
        }
    }

    private static func makeClip(_ samples: [Float]) -> FartClip? {
        let engineCount = min(samples.count, Int(engineMaxSeconds * rate))
        guard engineCount >= Int(engineMinSeconds * rate) else { return nil }
        let engineSlice = Array(samples.prefix(engineCount))
        let fullSlice = Array(samples.prefix(Int(fullMaxSeconds * rate)))
        let engineSamples = normalised(faded(engineSlice, fadeOut: engineFadeOutSeconds), matchRMS: true)
        let fullSamples = normalised(faded(fullSlice, fadeOut: fullFadeOutSeconds), matchRMS: false)
        guard
            let engine = GameAudioFormat.buffer(engineSamples),
            let full = GameAudioFormat.buffer(fullSamples)
        else { return nil }
        return FartClip(engine: engine, full: full)
    }

    private static func trimSilence(_ samples: [Float]) -> [Float]? {
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0.0001 else { return nil }
        let threshold = peak * silenceFraction
        guard
            let first = samples.firstIndex(where: { abs($0) > threshold }),
            let last = samples.lastIndex(where: { abs($0) > threshold }),
            last > first
        else { return nil }
        let margin = Int(trimMarginSeconds * rate)
        return Array(samples[max(0, first - margin)...min(samples.count - 1, last + margin)])
    }

    /// Raised-cosine fades, so overlapping farts crossfade instead of clicking.
    private static func faded(_ samples: [Float], fadeOut: Double) -> [Float] {
        let count = samples.count
        let fadeIn = min(count / 2, Int(fadeInSeconds * rate))
        let fadeOutCount = min(count / 2, Int(fadeOut * rate))
        var output = samples
        for index in 0..<fadeIn {
            output[index] *= ramp(Double(index) / Double(fadeIn))
        }
        for index in 0..<fadeOutCount {
            output[count - 1 - index] *= ramp(Double(index) / Double(fadeOutCount))
        }
        return output
    }

    private static func ramp(_ x: Double) -> Float {
        Float(0.5 - 0.5 * cos(Double.pi * x))
    }

    /// Engine slices are matched by loudness so the motor sounds even; hits are peak-normalised.
    private static func normalised(_ samples: [Float], matchRMS: Bool) -> [Float] {
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0.0001 else { return samples }
        var gain = peakLimit / peak
        if matchRMS {
            let energy = samples.reduce(Float(0)) { $0 + $1 * $1 }
            let rms = (energy / Float(samples.count)).squareRoot()
            if rms > 0.00001 {
                gain = min(gain, max(0.25, min(6, engineTargetRMS / rms)))
            }
        }
        return samples.map { $0 * gain }
    }
}
