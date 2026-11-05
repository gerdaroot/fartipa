import Foundation

/// What touching things on the road does: coins, pickups, ramps, piles, manholes, traffic, streams,
/// and how a jump lands.
extension BikeRun {
    /// Everything the bike crossed between `previous` and `distance`, in a fixed order: a ramp
    /// launches before the vehicle behind it is checked, so the bike flies over it.
    mutating func contacts(after previous: Double) -> [BikeEvent] {
        var events = collectCoins(after: previous)
        events += collectPickups(after: previous)
        checkRamps(after: previous)
        events += checkPiles(after: previous)
        events += checkManholes(after: previous)
        events += checkVehicles(after: previous)
        events += checkStreams(after: previous)
        return events
    }

    // MARK: - Coins and pickups

    private mutating func collectCoins(after previous: Double) -> [BikeEvent] {
        let hasMagnet = powerUps.magnet > 0
        let reach = hasMagnet ? Self.magnetReach : loadout.coinReach
        let horizon = distance + (hasMagnet ? Self.magnetAhead : 0)
        let bikeX = x
        let height = air.height
        let isTaken: (RoadCoin) -> Bool = { coin in
            coin.z > previous && coin.z <= horizon && abs(coin.x - bikeX) < reach
                && coin.lift <= height + RoadCoin.liftReach
        }
        let taken = roadCoins.filter(isTaken)
        guard !taken.isEmpty else { return [] }
        roadCoins = roadCoins.filter { !isTaken($0) }
        var events: [BikeEvent] = []
        for coin in taken {
            bank(coin)
            events.append(coin.isGolden ? .goldenCoin : .coin)
        }
        return events
    }

    private mutating func bank(_ coin: RoadCoin) {
        let doubling = powerUps.doubler > 0 ? 2.0 : 1.0
        coinBank += Double(coin.value) * loadout.coinMultiplier * doubling
        coinScoreTotal += coin.value * Self.coinScore * combo
        tally.coinsPicked += 1
        tally.goldenCoins += coin.isGolden ? 1 : 0
        boostTank.add(loadout.boostPerCoin * (coin.isGolden ? Self.goldenBoostFactor : 1))
    }

    private mutating func collectPickups(after previous: Double) -> [BikeEvent] {
        let end = distance
        let bikeX = x
        let isTaken: (RoadPickup) -> Bool = { pickup in
            pickup.z > previous && pickup.z <= end && abs(pickup.x - bikeX) < Self.pickupReach
        }
        let taken = roadPickups.filter(isTaken)
        guard !taken.isEmpty else { return [] }
        roadPickups = roadPickups.filter { !isTaken($0) }
        var events: [BikeEvent] = []
        for pickup in taken {
            apply(pickup.kind)
            events.append(.pickup(pickup.kind))
        }
        return events
    }

    private mutating func apply(_ kind: PickupKind) {
        tally.pickups += 1
        switch kind {
        case .magnet: powerUps.magnet = loadout.magnetSeconds
        case .shield: powerUps.shield = loadout.shieldSeconds
        case .coinDoubler: powerUps.doubler = Self.doublerSeconds
        case .boostRefill: boostTank.refill()
        case .repair: lives = min(maxLives, lives + 1)
        }
    }

    // MARK: - Ramps and low obstacles

    private mutating func checkRamps(after previous: Double) {
        let end = distance
        let bikeX = x
        let crossed = ramps.contains { ramp in
            ramp.z > previous && ramp.z <= end && abs(ramp.x - bikeX) < RoadRamp.reach
        }
        guard crossed, air.kind != .ramp else { return }
        air.launch()
        tally.rampJumps += 1
        moments.append(.rampLaunch)
    }

    /// A pile makes the bike skid, unless it is in the air (cleared) or on gas (ploughed through).
    private mutating func checkPiles(after previous: Double) -> [BikeEvent] {
        let end = distance
        let bikeX = x
        let touched = piles.contains { pile in
            pile.z > previous && pile.z <= end && abs(pile.x - bikeX) < Self.pileReach
        }
        guard touched else { return [] }
        if air.isAirborne {
            tally.pilesJumped += 1
            moments.append(.pileCleared)
            return []
        }
        guard !boostTank.isActive else { return [] }
        startSkid()
        return [.skid]
    }

    private mutating func startSkid() {
        skidLeft = loadout.skidSeconds
        slowdownLeft = max(slowdownLeft, loadout.skidSeconds)
        slowdownFactor = loadout.skidSpeedFactor
        tally.skids += 1
    }

    /// A spouting geyser or a rolling lid costs a life on the road and nothing in the air.
    private mutating func checkManholes(after previous: Double) -> [BikeEvent] {
        let end = distance
        let moment = time
        let bikeX = x
        let crossed = manholes.filter { hole in
            hole.z > previous && hole.z <= end && hole.isDangerous(atTime: moment)
                && abs(hole.x(atTime: moment) - bikeX) < hole.kind.reach
        }
        var events: [BikeEvent] = []
        for hole in crossed {
            if air.isAirborne {
                tally.hazardsJumped += 1
                moments.append(.hazardCleared(hole.kind))
            } else if invulnerable == 0 {
                events += takeHit()
            }
        }
        return events
    }

    // MARK: - Traffic and streams

    private mutating func checkVehicles(after previous: Double) -> [BikeEvent] {
        var events: [BikeEvent] = []
        for index in vehicles.indices where !vehicles[index].wasPassed && !vehicles[index].isWrecked {
            events += resolveVehicle(at: index, after: previous)
        }
        return events
    }

    private mutating func resolveVehicle(at index: Int, after previous: Double) -> [BikeEvent] {
        let vehicle = vehicles[index]
        let front = vehicle.z + vehicle.kind.halfLength
        let rear = vehicle.z - vehicle.kind.halfLength
        let sideways = abs(vehicle.x - x)
        let touchWidth = vehicle.kind.halfWidth + Self.bikeHalfWidth
        let isAlongside = distance >= rear && distance <= front
        let jumpedOver = previous < rear && distance > front
        if sideways < touchWidth, isAlongside || jumpedOver {
            return air.kind == .ramp ? vault(vehicleAt: index) : strike(vehicleAt: index)
        }
        guard distance > front else { return [] }
        vehicles[index] = vehicle.passed()
        guard sideways >= touchWidth, sideways < touchWidth + Self.vehicleNearMissMargin else { return [] }
        return [registerNearMiss()]
    }

    private mutating func vault(vehicleAt index: Int) -> [BikeEvent] {
        let vehicle = vehicles[index]
        vehicles[index] = vehicle.passed()
        bonusScore += Self.vaultScore
        tally.vehiclesVaulted += 1
        moments.append(.vaulted(vehicle.kind))
        return []
    }

    private mutating func strike(vehicleAt index: Int) -> [BikeEvent] {
        let vehicle = vehicles[index]
        if boostTank.isActive {
            vehicles[index] = vehicle.wrecked()
            bonusScore += Self.smashScore
            tally.vehiclesSmashed += 1
            return [.vehicleSmashed(vehicle.kind)]
        }
        guard invulnerable == 0 else { return [] }
        vehicles[index] = vehicle.wrecked()
        return takeHit()
    }

    /// Streams pour from the sky: being in the air does not help.
    private mutating func checkStreams(after previous: Double) -> [BikeEvent] {
        let end = distance
        let crossed = streams.filter { $0.isPouring && $0.z > previous && $0.z <= end }
        var events: [BikeEvent] = []
        for stream in crossed {
            let sideways = abs(stream.x(atTime: time) - x)
            if sideways >= Self.streamReach {
                if sideways < Self.streamReach + Self.streamNearMissMargin {
                    events.append(registerNearMiss())
                }
            } else if invulnerable == 0 {
                events += takeHit()
            }
        }
        return events
    }

    private mutating func registerNearMiss() -> BikeEvent {
        comboMeter.registerNearMiss()
        bonusScore += Self.nearMissScore * combo
        tally.nearMisses += 1
        tally.bestCombo = max(tally.bestCombo, combo)
        return .nearMiss
    }

    /// A shield eats the blow; otherwise it costs a life, the combo and any gas in progress.
    mutating func takeHit() -> [BikeEvent] {
        if powerUps.shield > 0 {
            powerUps.shield = 0
            invulnerable = max(invulnerable, Self.shieldGraceSeconds)
            tally.shieldBlocks += 1
            return [.shieldBlocked]
        }
        lives -= 1
        tally.hits += 1
        tally.bestCleanStretch = max(tally.bestCleanStretch, Int(distance - cleanSince))
        cleanSince = distance
        invulnerable = loadout.invulnerableSeconds
        slowdownLeft = Self.hitSlowdownSeconds
        slowdownFactor = Self.hitSlowdownFactor
        comboMeter.reset()
        guard boostTank.isActive else { return [.hit] }
        boostTank.stop()
        return [.hit, .boostEnd]
    }

    // MARK: - Landing

    /// Off a ramp: score for the air time, and for each clean flip, which also feeds the combo.
    /// Landing in the middle of a flip loses the trick and skids.
    mutating func land(_ landing: AirLanding) -> [BikeEvent] {
        moments.append(.landed(landing))
        guard landing.kind == .ramp else { return [] }
        if landing.botchedFlip {
            startSkid()
            return [.skid]
        }
        bonusScore += Int(landing.seconds * Self.airScorePerSecond)
        guard landing.flips > 0 else { return [] }
        for _ in 0..<landing.flips { comboMeter.registerNearMiss() }
        tally.flips += landing.flips
        tally.bestCombo = max(tally.bestCombo, combo)
        bonusScore += Self.flipScore * landing.flips * combo
        return []
    }
}
