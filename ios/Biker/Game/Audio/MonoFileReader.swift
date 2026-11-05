import AVFoundation

/// Reads a bundled audio file into mono float samples at the engine rate.
/// Slow (file decoding and resampling): call it off the main thread only.
enum MonoFileReader {
    private static let rate = GameAudioFormat.sampleRate

    /// Reads at most `maxSeconds` in the file's processing format (float, deinterleaved), averages the
    /// channels and converts the sample rate. Nil for a missing, empty or unreadable file.
    static func read(_ url: URL, maxSeconds: Double) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let maxFrames = AVAudioFramePosition(maxSeconds * format.sampleRate)
        let frames = AVAudioFrameCount(max(0, min(file.length, maxFrames)))
        guard
            frames > 0,
            format.channelCount > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return nil }
        do {
            try file.read(into: buffer, frameCount: frames)
        } catch {
            // Compressed files can report a slightly long length; keep whatever was decoded.
            guard buffer.frameLength > 0 else { return nil }
        }
        guard let mono = mixDown(buffer) else { return nil }
        return resample(mono, from: format.sampleRate)
    }

    private static func mixDown(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channels = buffer.floatChannelData else { return nil }
        let count = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard count > 1, channelCount > 0 else { return nil }
        var mono = [Float](repeating: 0, count: count)
        let scale = 1 / Float(channelCount)
        for channel in 0..<channelCount {
            let data = channels[channel]
            for index in 0..<count {
                mono[index] += data[index] * scale
            }
        }
        return mono
    }

    /// Linear interpolation; the bundled effects are already 44.1 kHz, so this only runs for the farts.
    private static func resample(_ samples: [Float], from sourceRate: Double) -> [Float] {
        guard sourceRate > 0, abs(sourceRate - rate) > 0.5 else { return samples }
        let step = sourceRate / rate
        let outCount = Int(Double(samples.count - 1) / step)
        guard outCount > 1 else { return [] }
        let last = samples.count - 1
        return (0..<outCount).map { index -> Float in
            let position = Double(index) * step
            let left = min(Int(position), last)
            let right = min(left + 1, last)
            let fraction = Float(position - Double(left))
            return samples[left] + (samples[right] - samples[left]) * fraction
        }
    }
}
