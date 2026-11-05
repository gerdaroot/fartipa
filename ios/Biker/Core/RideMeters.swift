import Foundation

/// The gas tank. Holds seconds of boost.
struct BoostTank: Equatable {
    /// The least gas worth starting a boost with.
    static let minimumCharge = 0.75

    let capacity: Double
    private(set) var charge: Double
    private(set) var isActive = false

    init(capacity: Double, charge: Double) {
        self.capacity = capacity
        self.charge = max(0, min(capacity, charge))
    }

    var fraction: Double { capacity > 0 ? charge / capacity : 0 }
    var canActivate: Bool { !isActive && charge >= Self.minimumCharge }

    /// Returns false when it could not start.
    mutating func activate() -> Bool {
        guard canActivate else { return false }
        isActive = true
        return true
    }

    mutating func stop() {
        isActive = false
    }

    mutating func add(_ seconds: Double) {
        charge = min(capacity, charge + max(0, seconds))
    }

    mutating func refill() {
        charge = capacity
    }

    /// Burns gas while active. Returns true on the moment it runs out.
    mutating func burn(dt: Double) -> Bool {
        guard isActive else { return false }
        charge = max(0, charge - dt)
        guard charge == 0 else { return false }
        isActive = false
        return true
    }
}

/// The near-miss multiplier. It climbs with each near miss and drops by one each `window` seconds.
struct ComboMeter: Equatable {
    static let lowest = 1
    static let highest = 10

    let window: Double
    private(set) var combo = ComboMeter.lowest
    private(set) var timeLeft = 0.0

    init(window: Double) {
        self.window = window
    }

    /// How long until the next drop, 1 is just refreshed. For a shrinking bar on screen.
    var fraction: Double { combo > Self.lowest && window > 0 ? timeLeft / window : 0 }

    mutating func registerNearMiss() {
        combo = min(Self.highest, combo + 1)
        timeLeft = window
    }

    mutating func reset() {
        combo = Self.lowest
        timeLeft = 0
    }

    mutating func decay(dt: Double) {
        guard combo > Self.lowest else { return }
        timeLeft -= dt
        if timeLeft <= 0 {
            combo -= 1
            timeLeft = combo > Self.lowest ? window : 0
        }
    }
}

/// Seconds left of each timed pickup.
struct PowerUpTimers: Equatable {
    var magnet = 0.0
    var shield = 0.0
    var doubler = 0.0

    mutating func tick(dt: Double) {
        magnet = max(0, magnet - dt)
        shield = max(0, shield - dt)
        doubler = max(0, doubler - dt)
    }
}

/// What one ride added up to. `Profile.recordRide` takes it at the end.
struct RideSummary: Equatable {
    var seconds = 0.0
    var distance = 0
    var score = 0
    /// Coins banked, after the multipliers.
    var coins = 0
    /// How many coin objects were picked up.
    var coinsPicked = 0
    var goldenCoins = 0
    var nearMisses = 0
    var hits = 0
    var boosts = 0
    var pickups = 0
    var skids = 0
    var shieldBlocks = 0
    var vehiclesSmashed = 0
    var bestCombo = 1
    var districtIndex = 0
    /// Hops taken («пердёж-прыжки»).
    var hops = 0
    var pilesJumped = 0
    /// Geysers and rolling lids jumped over while they were dangerous.
    var hazardsJumped = 0
    var rampJumps = 0
    /// Vehicles flown over off a ramp.
    var vehiclesVaulted = 0
    /// Flips landed cleanly.
    var flips = 0
    /// The longest stretch in metres ridden without losing a life.
    var bestCleanStretch = 0
}
