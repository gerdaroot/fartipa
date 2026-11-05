#if DEBUG
import Foundation

/// `--demo=hub|ride|garage|upgrades|over` opens a screen with sample data for CI screenshots.
/// Nothing is saved: the real profile stays as it was.
extension BikeGame {
    private static let demoRideSeed: UInt64 = 7
    private static let demoOverSeed: UInt64 = 3
    private static let demoRideLeadSeconds = 3.0
    /// The demo ride looks for the intro ramp this long at most.
    private static let demoRampSearchSeconds = 40.0
    /// Seconds before a ramp when the demo rider lines up with it.
    private static let demoRampLineUpSeconds = 2.5
    /// The hold comes this far into the flip, with the bike half upside down.
    private static let demoFlipHoldSeconds = 0.24
    private static let demoOverCleanSeconds = 45.0
    private static let demoOverCrashSeconds = 600.0
    private static let demoCoins = 48_750
    private static let demoBikeId = "hellchopper"
    private static let demoRiderId = "devil"
    private static let demoTrailId = "fire"
    private static let demoBought = [
        "sport", "toilet", "turdmobile", "hellchopper", "goldtoilet",
        "racer", "turdman", "devil", "king", "sparks", "fire", "rainbow",
    ]

    func applyDemo(_ name: String) {
        persists = false
        sound.isMuted = true
        commit(Self.demoProfile())
        dressWorld()
        switch name {
        case "ride":
            startRide(seed: Self.demoRideSeed)
            fastForward(seconds: Self.demoRideLeadSeconds, autopilot: true)
            demoAutopilot = true
            demoHold = fastForwardToRampFlip()
        case "garage":
            openGarage()
        case "upgrades":
            openUpgrades()
        case "over":
            startRide(seed: Self.demoOverSeed)
            fastForward(seconds: Self.demoOverCleanSeconds, autopilot: true)
            fastForward(seconds: Self.demoOverCrashSeconds, autopilot: false)
            if phase != .over { finishRide() }
        default:
            goHub()
        }
    }

    /// Plays the ride ahead without drawing it, for demo screenshots.
    func fastForward(seconds: Double, autopilot: Bool) {
        guard phase == .riding, var current = run else { return }
        let step = Self.defaultStep
        var left = seconds
        while left > 0, !current.isOver {
            if autopilot, current.autopilotWantsJump() { current.jump() }
            _ = current.update(dt: step, targetX: autopilot ? current.autopilotTarget() : 0)
            left -= step
        }
        adoptDemoRun(current)
    }

    /// Rides on to the first ramp, takes it, starts a flip and stops mid-flip. False when no
    /// ramp came in time (the demo then just rides on).
    private func fastForwardToRampFlip() -> Bool {
        guard phase == .riding, var current = run else { return false }
        let step = Self.defaultStep
        var left = Self.demoRampSearchSeconds
        while left > 0, !current.isOver {
            if current.air.kind == .ramp {
                if current.air.canFlip { current.jump() }
                if (current.air.flipElapsed ?? 0) >= Self.demoFlipHoldSeconds { break }
            }
            _ = current.update(dt: step, targetX: demoTarget(current))
            left -= step
        }
        adoptDemoRun(current)
        return current.air.kind == .ramp && !current.isOver
    }

    /// Lines up with the next ramp shortly before it; otherwise the autopilot drives.
    private func demoTarget(_ current: BikeRun) -> Double {
        let reach = current.speed * Self.demoRampLineUpSeconds
        for ramp in current.ramps {
            let ahead = ramp.z - current.distance
            if ahead > 0, ahead < reach { return ramp.x }
        }
        return current.autopilotTarget()
    }

    /// A player a few evenings in: coins, half the upgrades, some skins and achievements.
    private static func demoProfile() -> Profile {
        var profile = Profile()
        profile.earn(demoCoins + demoSpending())
        var ride = RideSummary()
        ride.seconds = 140
        ride.distance = 4_100
        ride.score = 1_250
        ride.coins = 640
        ride.coinsPicked = 520
        ride.goldenCoins = 12
        ride.nearMisses = 38
        ride.bestCombo = 6
        ride.districtIndex = 2
        ride.boosts = 9
        _ = profile.recordRide(ride)
        for track in UpgradeTrack.allCases {
            let levels = track.info.maxLevel / 2
            for _ in 0..<levels { _ = profile.buyUpgrade(track) }
        }
        for id in demoBought { _ = profile.buySkin(id: id) }
        for id in [demoBikeId, demoRiderId, demoTrailId] { profile.select(id: id) }
        return profile
    }

    /// Exactly what the demo purchases cost, so the wallet ends near `demoCoins`.
    private static func demoSpending() -> Int {
        let skins = demoBought.reduce(0) { $0 + (Catalog.info(id: $1)?.price ?? 0) }
        let upgrades = UpgradeTrack.allCases.reduce(0) { (total: Int, track: UpgradeTrack) -> Int in
            let levels = track.info.maxLevel / 2
            guard levels > 0 else { return total }
            return total + (1...levels).reduce(0) { $0 + (track.price(ofLevel: $1) ?? 0) }
        }
        return skins + upgrades
    }
}
#endif
