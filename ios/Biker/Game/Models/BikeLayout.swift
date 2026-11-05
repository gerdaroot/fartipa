import Foundation
import simd

/// Where the important points of each body type sit, in rig space (metres, y up, facing -z,
/// origin on the ground under the bike centre). The rider pose is solved from these points,
/// so hands land on `grip` and feet on `peg` whatever the bike.
struct BikeLayout {
    let frontAxle: RigVec
    let rearAxle: RigVec
    let frontRadius: Float
    let rearRadius: Float
    let frontWidth: Float
    let rearWidth: Float
    /// Top of the fork legs (the triple clamp). Fork tubes run from the front axle to here,
    /// so the top always leans back towards the rider.
    let forkTop: RigVec
    /// Right grip (x > 0); the left one is mirrored.
    let grip: RigVec
    /// Rider pelvis centre, just above the seat.
    let hip: RigVec
    /// Right foot rest (x > 0); the left one is mirrored.
    let peg: RigVec
    /// Torso pitch forward from vertical, radians. Negative leans back (chopper).
    let torsoLean: Float
    /// Muffler tip.
    let exhaust: RigVec
    /// Front of the main headlight lens.
    let headlight: RigVec

    static func of(_ body: BikeBody) -> BikeLayout {
        switch body {
        case .naked: return naked
        case .sport: return sport
        case .chopper: return chopper
        case .dirt: return dirt
        case .scooter: return scooter
        case .cruiser: return cruiser
        case .toilet: return toilet
        case .turd: return turd
        case .tractor: return tractor
        case .rocket: return rocket
        }
    }

    private static let naked = BikeLayout(
        frontAxle: RigVec(0, 0.34, -0.72), rearAxle: RigVec(0, 0.34, 0.72),
        frontRadius: 0.34, rearRadius: 0.34, frontWidth: 0.13, rearWidth: 0.17,
        forkTop: RigVec(0, 1.0, -0.47), grip: RigVec(0.34, 1.06, -0.4),
        hip: RigVec(0, 0.95, 0.14), peg: RigVec(0.19, 0.42, 0.14), torsoLean: 0.35,
        exhaust: RigVec(0.22, 0.62, 0.9), headlight: RigVec(0, 0.92, -0.66)
    )

    private static let sport = BikeLayout(
        frontAxle: RigVec(0, 0.34, -0.74), rearAxle: RigVec(0, 0.34, 0.7),
        frontRadius: 0.34, rearRadius: 0.34, frontWidth: 0.12, rearWidth: 0.19,
        forkTop: RigVec(0, 0.92, -0.5), grip: RigVec(0.27, 0.9, -0.42),
        hip: RigVec(0, 0.99, 0.18), peg: RigVec(0.19, 0.56, 0.3), torsoLean: 0.85,
        exhaust: RigVec(0.2, 0.68, 0.8), headlight: RigVec(0, 0.8, -0.86)
    )

    private static let chopper = BikeLayout(
        frontAxle: RigVec(0, 0.34, -1.12), rearAxle: RigVec(0, 0.36, 0.74),
        frontRadius: 0.34, rearRadius: 0.36, frontWidth: 0.1, rearWidth: 0.2,
        forkTop: RigVec(0, 0.98, -0.58), grip: RigVec(0.36, 1.42, -0.24),
        hip: RigVec(0, 0.8, 0.22), peg: RigVec(0.26, 0.4, -0.46), torsoLean: -0.15,
        exhaust: RigVec(0.24, 0.44, 1.02), headlight: RigVec(0, 0.84, -0.8)
    )

    private static let dirt = BikeLayout(
        frontAxle: RigVec(0, 0.36, -0.76), rearAxle: RigVec(0, 0.34, 0.7),
        frontRadius: 0.36, rearRadius: 0.34, frontWidth: 0.11, rearWidth: 0.14,
        forkTop: RigVec(0, 1.12, -0.48), grip: RigVec(0.38, 1.3, -0.4),
        hip: RigVec(0, 1.08, 0.08), peg: RigVec(0.19, 0.5, 0.06), torsoLean: 0.25,
        exhaust: RigVec(0.2, 0.94, 0.84), headlight: RigVec(0, 1.06, -0.64)
    )

    private static let scooter = BikeLayout(
        frontAxle: RigVec(0, 0.26, -0.68), rearAxle: RigVec(0, 0.26, 0.62),
        frontRadius: 0.26, rearRadius: 0.26, frontWidth: 0.12, rearWidth: 0.13,
        forkTop: RigVec(0, 1.0, -0.42), grip: RigVec(0.32, 1.1, -0.3),
        hip: RigVec(0, 0.86, 0.16), peg: RigVec(0.14, 0.34, -0.16), torsoLean: 0.05,
        exhaust: RigVec(0.19, 0.3, 0.76), headlight: RigVec(0, 1.08, -0.47)
    )

    private static let cruiser = BikeLayout(
        frontAxle: RigVec(0, 0.34, -0.86), rearAxle: RigVec(0, 0.34, 0.76),
        frontRadius: 0.34, rearRadius: 0.34, frontWidth: 0.15, rearWidth: 0.19,
        forkTop: RigVec(0, 0.98, -0.56), grip: RigVec(0.42, 1.12, -0.22),
        hip: RigVec(0, 0.8, 0.26), peg: RigVec(0.24, 0.36, -0.34), torsoLean: 0,
        exhaust: RigVec(0.25, 0.32, 1.04), headlight: RigVec(0, 0.92, -0.76)
    )

    private static let toilet = BikeLayout(
        frontAxle: RigVec(0, 0.34, -0.8), rearAxle: RigVec(0, 0.34, 0.62),
        frontRadius: 0.34, rearRadius: 0.34, frontWidth: 0.14, rearWidth: 0.15,
        forkTop: RigVec(0, 1.02, -0.5), grip: RigVec(0.34, 1.16, -0.36),
        hip: RigVec(0, 0.98, 0.16), peg: RigVec(0.2, 0.46, -0.14), torsoLean: 0.15,
        exhaust: RigVec(0.2, 0.42, 0.86), headlight: RigVec(0, 0.9, -0.66)
    )

    private static let turd = BikeLayout(
        frontAxle: RigVec(0, 0.34, -0.8), rearAxle: RigVec(0, 0.34, 0.72),
        frontRadius: 0.34, rearRadius: 0.34, frontWidth: 0.16, rearWidth: 0.18,
        forkTop: RigVec(0, 1.04, -0.5), grip: RigVec(0.34, 1.2, -0.4),
        hip: RigVec(0, 1.04, 0.14), peg: RigVec(0.22, 0.52, 0.04), torsoLean: 0.3,
        exhaust: RigVec(0, 0.6, 1.12), headlight: RigVec(0, 0.86, -0.78)
    )

    private static let tractor = BikeLayout(
        frontAxle: RigVec(0, 0.28, -0.86), rearAxle: RigVec(0, 0.48, 0.52),
        frontRadius: 0.28, rearRadius: 0.48, frontWidth: 0.15, rearWidth: 0.24,
        forkTop: RigVec(0, 0.9, -0.3), grip: RigVec(0.17, 1.24, -0.06),
        hip: RigVec(0, 1.12, 0.42), peg: RigVec(0.18, 0.62, 0.1), torsoLean: 0.1,
        exhaust: RigVec(0.22, 1.62, -0.6), headlight: RigVec(0.15, 0.98, -1.03)
    )

    private static let rocket = BikeLayout(
        frontAxle: RigVec(0, 0.3, -0.8), rearAxle: RigVec(0, 0.3, 0.74),
        frontRadius: 0.3, rearRadius: 0.3, frontWidth: 0.12, rearWidth: 0.13,
        forkTop: RigVec(0, 0.64, -0.7), grip: RigVec(0.3, 1.18, -0.46),
        hip: RigVec(0, 1.1, 0.1), peg: RigVec(0.28, 0.72, 0.18), torsoLean: 0.6,
        exhaust: RigVec(0, 0.82, 1.26), headlight: RigVec(0, 0.82, -1.34)
    )
}
