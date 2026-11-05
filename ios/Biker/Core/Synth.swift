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
    static func coin(sampleRate: Double) -> [Float] {
        let first = tone(from: 988, to: 988, seconds: 0.07, volume: 0.16, sampleRate: sampleRate, triangle: true)
        let second = tone(from: 1319, to: 1319, seconds: 0.16, volume: 0.16, sampleRate: sampleRate, triangle: true)
        return first + second
    }

    static func plop(sampleRate: Double) -> [Float] {
        tone(from: 340, to: 70, seconds: 0.13, volume: 0.32, sampleRate: sampleRate, triangle: false)
    }

    static func fanfare(sampleRate: Double) -> [Float] {
        arpeggio([392, 523, 659, 784], gapSeconds: 0.11, noteSeconds: 0.26, volume: 0.2, sampleRate: sampleRate)
    }

    /// A brighter, longer ring for a golden coin.
    static func goldenCoin(sampleRate: Double) -> [Float] {
        arpeggio([988, 1319, 1760], gapSeconds: 0.06, noteSeconds: 0.22, volume: 0.15, sampleRate: sampleRate)
    }

    /// A dull thump for a lost life.
    static func hit(sampleRate: Double) -> [Float] {
        tone(from: 180, to: 40, seconds: 0.3, volume: 0.45, sampleRate: sampleRate, triangle: false)
    }

    /// A wet slide on a poop pile.
    static func skid(sampleRate: Double) -> [Float] {
        tone(from: 520, to: 110, seconds: 0.35, volume: 0.22, sampleRate: sampleRate, triangle: true)
    }

    /// A quick rising chirp for a near miss.
    static func nearMiss(sampleRate: Double) -> [Float] {
        tone(from: 660, to: 1480, seconds: 0.14, volume: 0.16, sampleRate: sampleRate, triangle: true)
    }

    static func pickup(sampleRate: Double) -> [Float] {
        arpeggio([523, 784, 1047], gapSeconds: 0.07, noteSeconds: 0.18, volume: 0.17, sampleRate: sampleRate)
    }

    static func shieldBlocked(sampleRate: Double) -> [Float] {
        tone(from: 1200, to: 300, seconds: 0.25, volume: 0.24, sampleRate: sampleRate, triangle: true)
    }

    private static func arpeggio(
        _ notes: [Double], gapSeconds: Double, noteSeconds: Double, volume: Double, sampleRate: Double
    ) -> [Float] {
        let gap = Int(gapSeconds * sampleRate)
        var mix = [Float](repeating: 0, count: gap * (notes.count - 1) + Int(noteSeconds * sampleRate))
        for (index, pitch) in notes.enumerated() {
            let samples = tone(
                from: pitch, to: pitch, seconds: noteSeconds, volume: volume, sampleRate: sampleRate, triangle: true
            )
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

/// Deals sounds like a shuffled deck: none comes back until all the others have played.
struct SoundBag {
    private let count: Int
    private var remaining: [Int] = []
    private var last: Int?

    init(count: Int) {
        self.count = count
    }

    mutating func next() -> Int? {
        guard count > 0 else { return nil }
        if remaining.isEmpty { refill() }
        let pick = remaining.removeLast()
        last = pick
        return pick
    }

    /// The deck is dealt from its end, so the end must not repeat the sound that just finished a round.
    private mutating func refill() {
        remaining = Array(0..<count).shuffled()
        if count > 1, remaining.last == last {
            remaining.swapAt(0, count - 1)
        }
    }
}
