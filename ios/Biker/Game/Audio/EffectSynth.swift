import Foundation

/// Building blocks for the short effects. Everything renders once at launch into plain sample arrays,
/// never on the audio thread.
enum EffectSynth {
    enum Wave { case sine, triangle, square, saw }
    enum Envelope { case pluck, bell, swell, flat }

    struct Tone {
        var from: Double
        var to: Double
        var seconds: Double
        var volume: Double
        var wave: Wave = .triangle
        var envelope: Envelope = .pluck
        var vibratoDepth: Double = 0
        var vibratoRate: Double = 6
    }

    /// Filtered white noise; the cutoff glides exponentially from `cutoffFrom` to `cutoffTo`.
    struct Noise {
        var seconds: Double
        var volume: Double
        var cutoffFrom: Double
        var cutoffTo: Double
        var damping: Double = 0.6
        var bandPass: Bool = true
        var envelope: Envelope = .bell
        var seed: UInt32 = 0x9E37_79B9
    }

    typealias Part = (at: Double, samples: [Float])

    static let sampleRate = GameAudioFormat.sampleRate
    private static let attackSeconds: Double = 0.004
    private static let releaseSeconds: Double = 0.02
    private static let pluckFloor: Double = 0.001

    static func render(_ tone: Tone) -> [Float] {
        let count = max(1, Int(tone.seconds * sampleRate))
        let from = max(1, tone.from)
        let ratio = max(1, tone.to) / from
        var output = [Float](repeating: 0, count: count)
        var phase = 0.0
        for index in 0..<count {
            let t = Double(index) / Double(count)
            let wobble = 1 + tone.vibratoDepth * sin(2 * Double.pi * tone.vibratoRate * Double(index) / sampleRate)
            phase += from * pow(ratio, t) * wobble / sampleRate
            let cycle = phase - phase.rounded(.down)
            let level = envelope(tone.envelope, t: t, seconds: tone.seconds) * tone.volume
            output[index] = Float(wave(tone.wave, cycle: cycle) * level)
        }
        return output
    }

    static func render(_ noise: Noise) -> [Float] {
        let count = max(1, Int(noise.seconds * sampleRate))
        let from = max(20, noise.cutoffFrom)
        let ratio = max(20, noise.cutoffTo) / from
        let nyquistGuard = sampleRate / 6
        var output = [Float](repeating: 0, count: count)
        var state = noise.seed == 0 ? 1 : noise.seed
        var low = 0.0
        var band = 0.0
        for index in 0..<count {
            let t = Double(index) / Double(count)
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            let white = Double(state) / Double(UInt32.max) * 2 - 1
            let cutoff = min(from * pow(ratio, t), nyquistGuard)
            let tune = 2 * sin(Double.pi * cutoff / sampleRate)
            low += tune * band
            let high = white - low - noise.damping * band
            band += tune * high
            let filtered = noise.bandPass ? band : low
            let level = envelope(noise.envelope, t: t, seconds: noise.seconds) * noise.volume
            output[index] = Float(max(-1, min(1, filtered * level)))
        }
        return output
    }

    /// Sums parts, each starting `at` seconds in.
    static func mix(_ parts: [Part]) -> [Float] {
        let length = parts.map { Int($0.at * sampleRate) + $0.samples.count }.max() ?? 0
        var output = [Float](repeating: 0, count: length)
        for part in parts {
            let offset = Int(part.at * sampleRate)
            for (index, sample) in part.samples.enumerated() {
                output[offset + index] += sample
            }
        }
        return output
    }

    /// The same tone played on each note in turn, `gap` seconds apart.
    static func arpeggio(_ notes: [Double], gap: Double, tone: Tone) -> [Float] {
        let parts = notes.enumerated().map { item -> Part in
            var voice = tone
            voice.from = item.element
            voice.to = item.element
            return (at: Double(item.offset) * gap, samples: render(voice))
        }
        return mix(parts)
    }

    private static func wave(_ kind: Wave, cycle: Double) -> Double {
        switch kind {
        case .sine: return sin(2 * Double.pi * cycle)
        case .triangle: return 4 * abs(cycle - 0.5) - 1
        case .square: return cycle < 0.5 ? 0.6 : -0.6
        case .saw: return (2 * cycle - 1) * 0.7
        }
    }

    private static func envelope(_ kind: Envelope, t: Double, seconds: Double) -> Double {
        let elapsed = t * seconds
        let attack = min(1, elapsed / attackSeconds)
        let release = min(1, (seconds - elapsed) / releaseSeconds)
        switch kind {
        case .pluck:
            return attack * pow(pluckFloor, t)
        case .bell:
            let rise = sin(Double.pi * t)
            return rise * rise
        case .swell:
            return pow(t, 1.5) * max(0, release)
        case .flat:
            return attack * max(0, release)
        }
    }
}
