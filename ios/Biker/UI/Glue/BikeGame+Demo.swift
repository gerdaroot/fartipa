#if DEBUG
import Foundation

/// `--demo=hub|ride|garage|upgrades|over` opens a screen with sample data for CI screenshots.
/// Nothing is saved: the real profile stays as it was.
extension BikeGame {
    private static let demoRideSeed: UInt64 = 7
    private static let demoOverSeed: UInt64 = 3
    private static let demoRideLeadSeconds = 3.0
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
