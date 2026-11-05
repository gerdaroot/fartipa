import AVFoundation

/// The recorded effects bundled from `ios/Biker/Sounds` (CC0; sources in CREDITS.txt there), decoded once
/// into buffers in the engine's mono format. Hits layer one of these under a real fart recording.
enum EffectLibrary {
    /// No effect file is anywhere near this long; it only bounds a broken file.
    private static let maxSeconds: Double = 3

    static func fileNames(for effect: SoundEffect) -> [String] {
        switch effect {
        case .coin: return ["sfx-coin-1.caf", "sfx-coin-2.caf", "sfx-coin-3.caf"]
        case .goldenCoin: return ["sfx-golden-1.caf"]
        case .hit: return ["sfx-hit-1.caf", "sfx-hit-2.caf"]
        case .skid: return ["sfx-skid-1.caf", "sfx-skid-2.caf"]
        case .nearMiss: return ["sfx-whoosh-1.caf", "sfx-whoosh-2.caf", "sfx-whoosh-3.caf"]
        case .pickup: return ["sfx-pickup-1.caf", "sfx-pickup-2.caf"]
        case .shield: return ["sfx-shield-1.caf"]
        case .boostStart: return ["sfx-boost-1.caf", "sfx-boost-2.caf"]
        case .purchase: return ["sfx-purchase-1.caf"]
        case .upgrade: return ["sfx-upgrade-1.caf"]
        case .gameOver: return ["sfx-gameover-1.caf"]
        case .button: return ["sfx-button-1.caf", "sfx-button-2.caf"]
        case .vehicleSmash: return ["sfx-smash-1.caf"]
        case .district: return ["sfx-district-1.caf"]
        case .dailyReward: return ["sfx-reward-1.caf"]
        }
    }

    /// Playback level per effect; the files are already loudness-matched, this only sets the mix.
    static func volume(for effect: SoundEffect) -> Float {
        switch effect {
        case .coin: return 0.75
        case .button: return 0.6
        case .skid, .nearMiss, .pickup, .shield: return 0.8
        case .hit, .vehicleSmash, .boostStart: return 0.9
        case .goldenCoin, .purchase, .upgrade, .gameOver, .district, .dailyReward: return 0.85
        }
    }

    /// Every variant that decodes, indexed by `SoundEffect.rawValue`; a missing file only shortens its list.
    /// Slow (file decoding): call off the main thread.
    static func decodeAll(bundle: Bundle = .main) -> [[AVAudioPCMBuffer]] {
        var library = [[AVAudioPCMBuffer]](repeating: [], count: SoundEffect.allCases.count)
        for effect in SoundEffect.allCases where library.indices.contains(effect.rawValue) {
            library[effect.rawValue] = fileNames(for: effect).compactMap { name -> AVAudioPCMBuffer? in
                guard
                    let url = bundle.url(forResource: name, withExtension: nil),
                    let samples = MonoFileReader.read(url, maxSeconds: maxSeconds)
                else { return nil }
                return GameAudioFormat.buffer(samples)
            }
        }
        return library
    }
}
