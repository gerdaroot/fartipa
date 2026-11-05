import Foundation

/// What each effect sounds like. Hits use a real fart recording; `hitThump` only adds weight under it.
extension EffectSynth {
    /// Pitch factors for the coin chime variants, dealt in turn so a stream of coins sparkles.
    static let coinPitches: [Double] = [1.0, 1.06, 1.12]

    static func samples(for effect: SoundEffect) -> [Float] {
        switch effect {
        case .coin: return coin(pitch: 1)
        case .goldenCoin: return goldenCoin()
        case .hit: return hitThump()
        case .skid: return skid()
        case .nearMiss: return nearMiss()
        case .pickup: return pickup()
        case .shield: return shield()
        case .boostStart: return boostStart()
        case .purchase: return purchase()
        case .upgrade: return upgrade()
        case .gameOver: return gameOver()
        case .button: return button()
        }
    }

    static func coin(pitch: Double) -> [Float] {
        let low = Tone(from: 1319 * pitch, to: 1319 * pitch, seconds: 0.07, volume: 0.12)
        let high = Tone(from: 1976 * pitch, to: 1976 * pitch, seconds: 0.2, volume: 0.12)
        return mix([(at: 0, samples: render(low)), (at: 0.055, samples: render(high))])
    }

    static func goldenCoin() -> [Float] {
        let ring = Tone(from: 1047, to: 1047, seconds: 0.3, volume: 0.11)
        let notes: [Double] = [1047, 1319, 1568, 2093]
        let sparkle = Tone(from: 4186, to: 4186, seconds: 0.4, volume: 0.04, wave: .sine)
        return mix([
            (at: 0, samples: arpeggio(notes, gap: 0.05, tone: ring)),
            (at: 0.15, samples: render(sparkle)),
        ])
    }

    static func hitThump() -> [Float] {
        render(Tone(from: 150, to: 38, seconds: 0.32, volume: 0.5, wave: .sine))
    }

    /// A wet squelch: resonant low noise sliding down with a sagging tone under it.
    static func skid() -> [Float] {
        let squish = Noise(seconds: 0.42, volume: 0.45, cutoffFrom: 900, cutoffTo: 160, damping: 0.18, bandPass: true)
        let sag = Tone(from: 210, to: 80, seconds: 0.4, volume: 0.16, envelope: .bell, vibratoDepth: 0.12, vibratoRate: 23)
        return mix([(at: 0, samples: render(squish)), (at: 0.02, samples: render(sag))])
    }

    static func nearMiss() -> [Float] {
        render(Noise(seconds: 0.34, volume: 0.9, cutoffFrom: 500, cutoffTo: 2600, damping: 0.9, seed: 0x5151_A3C7))
    }

    static func pickup() -> [Float] {
        let note = Tone(from: 523, to: 523, seconds: 0.2, volume: 0.12)
        let notes: [Double] = [523, 659, 784, 1047]
        let sweep = Tone(from: 400, to: 1300, seconds: 0.26, volume: 0.05, wave: .sine, envelope: .bell)
        return mix([(at: 0, samples: arpeggio(notes, gap: 0.06, tone: note)), (at: 0, samples: render(sweep))])
    }

    /// A metallic bwong: two inharmonic partials falling together, plus a short clank.
    static func shield() -> [Float] {
        let body = Tone(from: 880, to: 440, seconds: 0.4, volume: 0.16, wave: .sine)
        let partial = Tone(from: 1294, to: 647, seconds: 0.35, volume: 0.09, wave: .sine)
        let clank = Noise(seconds: 0.06, volume: 0.5, cutoffFrom: 3200, cutoffTo: 2400, envelope: .pluck)
        return mix([(at: 0, samples: render(body)), (at: 0, samples: render(partial)), (at: 0, samples: render(clank))])
    }

    /// «Газы»: a rising rush of air over a growl.
    static func boostStart() -> [Float] {
        let rush = Noise(seconds: 0.55, volume: 0.8, cutoffFrom: 300, cutoffTo: 2800, damping: 0.7, envelope: .bell)
        let growl = Tone(from: 70, to: 150, seconds: 0.5, volume: 0.16, wave: .square, envelope: .bell)
        return mix([(at: 0, samples: render(rush)), (at: 0, samples: render(growl))])
    }

    /// Ka-ching: a bright noise burst then two high bells.
    static func purchase() -> [Float] {
        let burst = Noise(seconds: 0.06, volume: 0.5, cutoffFrom: 5000, cutoffTo: 4000, envelope: .pluck)
        let first = Tone(from: 1568, to: 1568, seconds: 0.1, volume: 0.12)
        let second = Tone(from: 2093, to: 2093, seconds: 0.36, volume: 0.12)
        return mix([
            (at: 0, samples: render(burst)),
            (at: 0.03, samples: render(first)),
            (at: 0.1, samples: render(second)),
        ])
    }

    static func upgrade() -> [Float] {
        let note = Tone(from: 523, to: 523, seconds: 0.3, volume: 0.1)
        let notes: [Double] = [523, 659, 784, 1047, 1319]
        let chord = Tone(from: 1047, to: 1047, seconds: 0.6, volume: 0.06, wave: .sine)
        return mix([(at: 0, samples: arpeggio(notes, gap: 0.08, tone: note)), (at: 0.4, samples: render(chord))])
    }

    /// A sad trombone: three falling notes and a long wobbling last one.
    static func gameOver() -> [Float] {
        let step = Tone(from: 392, to: 392, seconds: 0.3, volume: 0.13, wave: .saw, envelope: .flat)
        let notes: [Double] = [392, 370, 349]
        let last = Tone(from: 330, to: 300, seconds: 0.95, volume: 0.13, wave: .saw, envelope: .flat,
                        vibratoDepth: 0.03, vibratoRate: 5.5)
        return mix([(at: 0, samples: arpeggio(notes, gap: 0.32, tone: step)), (at: 0.96, samples: render(last))])
    }

    static func button() -> [Float] {
        render(Tone(from: 1800, to: 1300, seconds: 0.035, volume: 0.14, wave: .sine))
    }
}
