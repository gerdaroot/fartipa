import AVFoundation

/// The one format every buffer and effect player shares: mono float at 44.1 kHz.
/// Player nodes are connected with exactly these objects, so scheduled buffers always match.
enum GameAudioFormat {
    static let sampleRate: Double = 44_100
    static let mono: AVAudioFormat? = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    static let stereo: AVAudioFormat? = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)

    /// Copies samples into a mono buffer; nil for empty input or if the buffer cannot be made.
    static func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard
            !samples.isEmpty,
            let format = mono,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        samples.withUnsafeBufferPointer { source in
            if let address = source.baseAddress {
                channel.update(from: address, count: samples.count)
            }
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }

    static func seconds(of buffer: AVAudioPCMBuffer) -> Double {
        Double(buffer.frameLength) / buffer.format.sampleRate
    }
}
