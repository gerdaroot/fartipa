import Foundation

/// Filtered noise that follows the finger. Runs on the audio thread, so `fill` never allocates.
struct SquelchGenerator {
    private let sampleRate: Float
    private var low: Float = 0
    private var band: Float = 0
    private var currentGain: Float = 0
    private var randomState: UInt32 = 0x9e37_79b9

    init(sampleRate: Double) {
        self.sampleRate = Float(sampleRate)
    }

    mutating func fill(_ output: UnsafeMutableBufferPointer<Float>, gain: Float, frequency: Float) {
        let tune = 2 * sin(.pi * min(frequency, sampleRate / 8) / sampleRate)
        let damping: Float = 0.45
        let glide = 1 - exp(-1 / (0.02 * sampleRate))
        for i in 0..<output.count {
            randomState ^= randomState << 13
            randomState ^= randomState >> 17
            randomState ^= randomState << 5
            let noise = Float(randomState) / Float(UInt32.max) * 2 - 1
            currentGain += (gain - currentGain) * glide
            low += tune * band
            let high = noise - low - damping * band
            band += tune * high
            output[i] = gain == 0 && currentGain < 0.0001 ? 0 : max(-1, min(1, band * currentGain))
        }
    }
}

/// Short effects built from sine and triangle waves when the app starts.
enum Synth {
    static func plop(sampleRate: Double) -> [Float] {
        tone(from: 340, to: 70, seconds: 0.13, volume: 0.32, sampleRate: sampleRate, triangle: false)
    }

    static func fanfare(sampleRate: Double) -> [Float] {
        let notes: [Double] = [392, 523, 659, 784]
        let gap = Int(0.11 * sampleRate)
        let note = 0.26
        var mix = [Float](repeating: 0, count: gap * (notes.count - 1) + Int(note * sampleRate))
        for (index, pitch) in notes.enumerated() {
            let samples = tone(from: pitch, to: pitch, seconds: note, volume: 0.2, sampleRate: sampleRate, triangle: true)
            for (offset, sample) in samples.enumerated() {
                mix[index * gap + offset] += sample
            }
        }
        return mix
    }

    private static func tone(
        from: Double, to: Double, seconds: Double, volume: Double, sampleRate: Double, triangle: Bool
    ) -> [Float] {
        let count = Int(seconds * sampleRate)
        var phase = 0.0
        return (0..<count).map { i in
            let t = Double(i) / Double(count)
            phase += from * pow(to / from, t) / sampleRate
            let cycle = phase - phase.rounded(.down)
            let wave = triangle ? 4 * abs(cycle - 0.5) - 1 : sin(2 * .pi * cycle)
            return Float(wave * volume * pow(0.001, t))
        }
    }
}

enum SoundPick {
    /// A random index that differs from the last one played, whenever there is a choice.
    static func next(count: Int, avoiding last: Int?) -> Int {
        guard count > 1 else { return 0 }
        guard let last else { return Int.random(in: 0..<count) }
        let pick = Int.random(in: 0..<(count - 1))
        return pick >= last ? pick + 1 : pick
    }
}
