import Foundation

/// One ride: all the rules, no graphics. Same seed, loadout and input give the same ride.
///
/// Call `update` every frame with the finger's target and react to the returned events.
/// Draw `streams`, `vehicles`, `piles`, `roadCoins`, `roadPickups` relative to `distance`.
struct BikeRun: Equatable {
    static let laneX = [-2.6, 0.0, 2.6]
    static let roadHalfWidth = 4.0
    static let bikeLimit = 3.4
    static let startSpeed = 22.0
    /// Metres over which the speed climbs from `startSpeed` to the top speed.
    static let rampDistance = 5800.0
    /// Under gas the cruising speed is multiplied by this.
    static let boostFactor = 1.7
    /// How close to a stream's centre the bike must be for it to hit.
    static let streamReach = 1.35
    static let bikeHalfWidth = 0.45
    static let pileReach = 1.1
    static let pickupReach = 1.5
    /// Extra sideways room outside a hit that still counts as a near miss.
    static let streamNearMissMargin = 1.1
    static let vehicleNearMissMargin = 1.0
    static let nearMissScore = 50
    static let smashScore = 100
    static let coinScore = 5
    static let lookAhead = 320.0
    static let behind = 12.0
    /// Repairs can raise lives this far above the starting number.
    static let extraLivesCap = 2
    static let doublerSeconds = 10.0
    static let magnetReach = 6.0
    static let magnetAhead = 6.0

    private static let maxStep = 0.1
    private static let hitSlowdownSeconds = 1.0
    private static let hitSlowdownFactor = 0.6
    private static let shieldGraceSeconds = 0.8
    private static let startingBoostShare = 1.0 / 3
    private static let goldenBoostFactor = 5.0
    private static let wholeCoinTolerance = 1e-9

    let loadout: RunLoadout
    private(set) var x = 0.0
    private(set) var distance = 0.0
    /// Seconds since the start.
    private(set) var time = 0.0
    private(set) var lives: Int
    private(set) var invulnerable = 0.0
    private(set) var isOver = false
    private(set) var streams: [PissStream] = []
    private(set) var vehicles: [Vehicle] = []
    private(set) var piles: [PoopPile] = []
    private(set) var roadCoins: [RoadCoin] = []
    private(set) var roadPickups: [RoadPickup] = []
    private(set) var powerUps = PowerUpTimers()

    private var boostTank: BoostTank
    private var comboMeter: ComboMeter
    private var generator: RoadGenerator
    private let populatesRoad: Bool
    private var slowdownLeft = 0.0
    private var slowdownFactor = 1.0
    private var skidLeft = 0.0
    private var coinBank = 0.0
    private var coinScoreTotal = 0
    private var bonusScore = 0
    private var tally = RideSummary()
    private var pendingEvents: [BikeEvent] = []

    /// `populatesRoad: false` gives an empty road for tests and tutorials: fill it with `place`.
    init(seed: UInt64, loadout: RunLoadout = .base, populatesRoad: Bool = true) {
        self.loadout = loadout
        self.populatesRoad = populatesRoad
        lives = loadout.startingLives
        boostTank = BoostTank(
            capacity: loadout.boostCapacity, charge: loadout.boostCapacity * Self.startingBoostShare
        )
        comboMeter = ComboMeter(window: loadout.comboSeconds)
        generator = RoadGenerator(seed: seed, loadout: loadout)
        spawnAhead()
    }

    // MARK: - What the screen reads

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

    /// What the ride added up to so far.
    var summary: RideSummary {
        var result = tally
        result.seconds = time
        result.distance = Int(distance)
        result.score = score
        result.coins = coins
        result.districtIndex = district.index
        return result
    }

    // MARK: - Input

    /// Opens the gas. Returns false when the tank is too empty. `boostStart` comes with the next update.
    @discardableResult
    mutating func activateBoost() -> Bool {
        guard !isOver, boostTank.activate() else { return false }
        tally.boosts += 1
        pendingEvents.append(.boostStart)
        return true
    }

    /// Puts something on the road by hand.
    mutating func place(_ stream: PissStream) { streams.append(stream) }
    mutating func place(_ vehicle: Vehicle) { vehicles.append(vehicle) }
    mutating func place(_ pile: PoopPile) { piles.append(pile) }
    mutating func place(_ coin: RoadCoin) { roadCoins.append(coin) }
    mutating func place(_ pickup: RoadPickup) { roadPickups.append(pickup) }

    // MARK: - The frame

    /// Moves the ride forward and reports what happened. `targetX` is where the finger steers.
    mutating func update(dt: Double, targetX: Double) -> [BikeEvent] {
        guard !isOver, dt > 0 else { return [] }
        let step = min(dt, Self.maxStep)
        let previous = distance
        let districtBefore = district.index
        steer(toward: targetX, dt: step)
        distance += speed * step
        time += step
        var events = pendingEvents
        pendingEvents = []
        events += tickMeters(dt: step)
        advanceObjects(dt: step)
        events += collectCoins(after: previous)
        events += collectPickups(after: previous)
        events += checkPiles(after: previous)
        events += checkVehicles(after: previous)
        events += checkStreams(after: previous)
        if district.index != districtBefore { events.append(.districtEntered(district.index)) }
        spawnAhead()
        removePassedObjects()
        if lives <= 0 {
            isOver = true
            events.append(.gameOver)
        }
        return events
    }

    private mutating func steer(toward targetX: Double, dt: Double) {
        guard targetX.isFinite else { return }
        let limit = loadout.steerRate * dt
        let wanted = min(Self.bikeLimit, max(-Self.bikeLimit, targetX))
        x += min(limit, max(-limit, wanted - x))
    }

    private mutating func tickMeters(dt: Double) -> [BikeEvent] {
        invulnerable = max(0, invulnerable - dt)
        slowdownLeft = max(0, slowdownLeft - dt)
        skidLeft = max(0, skidLeft - dt)
        powerUps.tick(dt: dt)
        comboMeter.decay(dt: dt)
        return boostTank.burn(dt: dt) ? [.boostEnd] : []
    }

    private mutating func advanceObjects(dt: Double) {
        let riderDistance = distance
        let riderSpeed = speed
        streams = streams.map { $0.advanced(dt: dt, riderDistance: riderDistance, riderSpeed: riderSpeed) }
        vehicles = vehicles.map { $0.advanced(dt: dt, riderDistance: riderDistance, riderSpeed: riderSpeed) }
    }

    private mutating func removePassedObjects() {
        let cutoff = distance - Self.behind
        streams = streams.filter { $0.z >= cutoff }
        vehicles = vehicles.filter { $0.z >= cutoff }
        piles = piles.filter { $0.z >= cutoff }
        roadCoins = roadCoins.filter { $0.z >= cutoff }
        roadPickups = roadPickups.filter { $0.z >= cutoff }
    }

    private mutating func spawnAhead() {
        guard populatesRoad else { return }
        while generator.nextZ < distance + Self.lookAhead {
            let segment = generator.nextSegment()
            streams += segment.streams
            vehicles += segment.vehicles
            piles += segment.piles
            roadCoins += segment.coins
            roadPickups += segment.pickups
        }
    }

    // MARK: - Coins and pickups

    private mutating func collectCoins(after previous: Double) -> [BikeEvent] {
        let hasMagnet = powerUps.magnet > 0
        let reach = hasMagnet ? Self.magnetReach : loadout.coinReach
        let horizon = distance + (hasMagnet ? Self.magnetAhead : 0)
        let bikeX = x
        let isTaken: (RoadCoin) -> Bool = { coin in
            coin.z > previous && coin.z <= horizon && abs(coin.x - bikeX) < reach
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

    // MARK: - Obstacles

    private mutating func checkPiles(after previous: Double) -> [BikeEvent] {
        guard !boostTank.isActive else { return [] }
        let end = distance
        let bikeX = x
        let skidded = piles.contains { pile in
            pile.z > previous && pile.z <= end && abs(pile.x - bikeX) < Self.pileReach
        }
        guard skidded else { return [] }
        skidLeft = loadout.skidSeconds
        slowdownLeft = max(slowdownLeft, loadout.skidSeconds)
        slowdownFactor = loadout.skidSpeedFactor
        tally.skids += 1
        return [.skid]
    }

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
            return strike(vehicleAt: index)
        }
        guard distance > front else { return [] }
        vehicles[index] = vehicle.passed()
        guard sideways >= touchWidth, sideways < touchWidth + Self.vehicleNearMissMargin else { return [] }
        return [registerNearMiss()]
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
    private mutating func takeHit() -> [BikeEvent] {
        if powerUps.shield > 0 {
            powerUps.shield = 0
            invulnerable = max(invulnerable, Self.shieldGraceSeconds)
            tally.shieldBlocks += 1
            return [.shieldBlocked]
        }
        lives -= 1
        tally.hits += 1
        invulnerable = loadout.invulnerableSeconds
        slowdownLeft = Self.hitSlowdownSeconds
        slowdownFactor = Self.hitSlowdownFactor
        comboMeter.reset()
        guard boostTank.isActive else { return [.hit] }
        boostTank.stop()
        return [.hit, .boostEnd]
    }
}
