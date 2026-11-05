import Foundation

enum AirKind: String, Equatable {
    /// «Пердёж-прыжок»: a short hop on a fart, over piles and manholes.
    case hop
    /// Off a ramp: high and long, over traffic.
    case ramp
}

/// How a jump ended.
struct AirLanding: Equatable {
    let kind: AirKind
    let seconds: Double
    /// Whole flips finished in the air.
    let flips: Int
    /// Came down in the middle of a flip: the trick does not count and the bike skids.
    let botchedFlip: Bool
}

/// The bike's jump: height over the road, the hop cooldown and flips.
/// Height follows a parabola from 0 at take-off to `peak` halfway and 0 at landing.
struct AirMeter: Equatable {
    static let hopSeconds = 0.62
    static let hopHeight = 1.5
    /// Seconds from one hop's take-off until the next hop is allowed.
    static let hopCooldown = 1.3
    static let rampSeconds = 1.3
    static let rampHeight = 3.6
    static let flipSeconds = 0.55

    private(set) var kind: AirKind?
    /// Seconds since take-off.
    private(set) var elapsed = 0.0
    private(set) var cooldown = 0.0
    /// Flips finished in this jump.
    private(set) var flips = 0
    /// Seconds into the flip in progress; nil when not flipping.
    private(set) var flipElapsed: Double?

    var isAirborne: Bool { kind != nil }

    /// Seconds the current jump lasts in all.
    var duration: Double { kind == .ramp ? Self.rampSeconds : Self.hopSeconds }

    var peak: Double { kind == .ramp ? Self.rampHeight : Self.hopHeight }

    /// Metres above the road.
    var height: Double {
        guard kind != nil else { return 0 }
        let share = max(0, min(1, elapsed / duration))
        return 4 * peak * share * (1 - share)
    }

    /// Turns of the bike in this jump for graphics: 1.0 is one whole flip.
    var turns: Double {
        let partial = flipElapsed.map { min(1, $0 / Self.flipSeconds) } ?? 0
        return Double(flips) + partial
    }

    var canHop: Bool { kind == nil && cooldown <= 0 }
    var canFlip: Bool { kind == .ramp && flipElapsed == nil }

    /// 1 when the jump button does something now; while recharging, how far the cooldown is.
    var readiness: Double {
        if canHop || canFlip { return 1 }
        if kind != nil { return 0 }
        return max(0, min(1, 1 - cooldown / Self.hopCooldown))
    }

    /// Returns false while in the air or recharging.
    mutating func hop() -> Bool {
        guard canHop else { return false }
        start(.hop)
        cooldown = Self.hopCooldown
        return true
    }

    /// A ramp throws the bike up even in the middle of a hop.
    mutating func launch() {
        start(.ramp)
    }

    /// Starts a flip; only in the air off a ramp, one at a time.
    mutating func startFlip() -> Bool {
        guard canFlip else { return false }
        flipElapsed = 0
        return true
    }

    /// Moves time on. Returns the landing when the bike touches down in this step.
    mutating func tick(dt: Double) -> AirLanding? {
        cooldown = max(0, cooldown - dt)
        guard let current = kind else { return nil }
        elapsed += dt
        if let flip = flipElapsed {
            let next = flip + dt
            if next >= Self.flipSeconds {
                flips += 1
                flipElapsed = nil
            } else {
                flipElapsed = next
            }
        }
        guard elapsed >= duration else { return nil }
        let landing = AirLanding(kind: current, seconds: duration, flips: flips, botchedFlip: flipElapsed != nil)
        start(nil)
        return landing
    }

    private mutating func start(_ newKind: AirKind?) {
        kind = newKind
        elapsed = 0
        flips = 0
        flipElapsed = nil
    }
}

/// What happened in a frame besides `BikeEvent`s. `BikeRun.moments` holds the latest frame's.
enum RideMoment: Equatable {
    /// A hop took off.
    case jumped
    case rampLaunch
    case flipStarted
    case landed(AirLanding)
    /// Jumped over a poop pile.
    case pileCleared
    /// Jumped over a geyser or a rolling lid while it was dangerous.
    case hazardCleared(ManholeKind)
    /// Flew over a vehicle off a ramp.
    case vaulted(VehicleKind)
    /// A road event is about to start: show its banner.
    case roadEvent(RoadEventKind)
}
