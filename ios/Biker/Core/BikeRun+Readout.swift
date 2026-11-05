import Foundation

/// What the screen, the sound and the profile read from a ride.
extension BikeRun {
    /// The speed at a point of the road without slowdowns or gas. It climbs with distance, so
    /// the road generator knows exactly how fast the rider will come to any place.
    static func cruisingSpeed(atDistance distance: Double, topSpeed: Double) -> Double {
        let ramp = max(0, min(1, distance / rampDistance))
        return startSpeed + (topSpeed - startSpeed) * ramp
    }

    var cruisingSpeed: Double {
        Self.cruisingSpeed(atDistance: distance, topSpeed: loadout.topSpeed)
    }

    var speed: Double {
        if boostTank.isActive { return cruisingSpeed * Self.boostFactor }
        return slowdownLeft > 0 ? cruisingSpeed * slowdownFactor : cruisingSpeed
    }

    /// 0 at the start of a ride, 1 at top speed, above 1 under gas. For the engine sound and camera.
    var rev: Double {
        (speed - Self.startSpeed) / max(1, loadout.topSpeed - Self.startSpeed)
    }

    var score: Int { Int(distance) + coinScoreTotal + bonusScore }
    /// Coins earned this ride, multipliers included.
    var coins: Int { Int(coinBank + Self.wholeCoinTolerance) }
    var district: District { District.at(distance: distance) }
    /// The current multiplier, 1 when there is no combo.
    var combo: Int { comboMeter.combo }
    /// Time left before the combo drops, 0...1.
    var comboFraction: Double { comboMeter.fraction }
    var isBoosting: Bool { boostTank.isActive }
    var canBoost: Bool { !isOver && boostTank.canActivate }
    /// How full the gas tank is, 0...1.
    var boostFraction: Double { boostTank.fraction }
    /// Seconds of gas in the tank.
    var boostCharge: Double { boostTank.charge }
    var isSkidding: Bool { skidLeft > 0 }
    var maxLives: Int { loadout.startingLives + Self.extraLivesCap }

    // MARK: - Jumps

    /// Metres above the road.
    var airHeight: Double { air.height }
    var isAirborne: Bool { air.isAirborne }
    /// Whether `jump()` would do something now (a hop, or a flip off a ramp).
    var canJump: Bool { !isOver && (air.canHop || air.canFlip) }
    /// 0...1 for the jump button's ring: 1 is ready.
    var jumpReadiness: Double { isOver ? 0 : air.readiness }
    /// Whole turns of the bike in the current jump, for graphics.
    var airTurns: Double { air.turns }

    // MARK: - Road events

    /// The road event the rider is in now.
    var currentRoadEvent: RoadEvent? {
        roadEvents.first { $0.contains(distance) }
    }

    /// Seconds of the current road event left at the present speed; 0 when none.
    var roadEventSecondsLeft: Double {
        guard let event = currentRoadEvent else { return 0 }
        return max(0, event.endZ - distance) / max(1, speed)
    }

    /// What the ride added up to so far.
    var summary: RideSummary {
        var result = tally
        result.seconds = time
        result.distance = Int(distance)
        result.score = score
        result.coins = coins
        result.districtIndex = district.index
        result.bestCleanStretch = max(tally.bestCleanStretch, Int(distance - cleanSince))
        return result
    }
}
