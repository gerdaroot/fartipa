import Foundation

/// One ride: all the rules, no graphics. Same seed, loadout and input give the same ride.
///
/// Call `update` every frame with the finger's target and react to the returned events and to
/// `moments`. Draw `streams`, `vehicles`, `piles`, `roadCoins`, `roadPickups`, `ramps` and `manholes`
/// relative to `distance`, and lift the bike by `airHeight`.
/// What the screen reads is in `BikeRun+Readout.swift`, what touching things does in
/// `BikeRun+Contacts.swift`. State that is not `private(set)` is written only by those two files.
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
    /// Flying over a vehicle off a ramp.
    static let vaultScore = 150
    /// Each clean flip, times the combo.
    static let flipScore = 250
    /// Score for each second in the air off a ramp.
    static let airScorePerSecond = 100.0
    static let coinScore = 5
    static let lookAhead = 320.0
    static let behind = 12.0
    /// Repairs can raise lives this far above the starting number.
    static let extraLivesCap = 2
    static let doublerSeconds = 10.0
    static let magnetReach = 6.0
    static let magnetAhead = 6.0
    /// A road event's banner shows this many seconds before it starts.
    static let eventLeadSeconds = 1.5

    static let maxStep = 0.1
    static let hitSlowdownSeconds = 1.0
    static let hitSlowdownFactor = 0.6
    static let shieldGraceSeconds = 0.8
    static let startingBoostShare = 1.0 / 3
    static let goldenBoostFactor = 5.0
    static let wholeCoinTolerance = 1e-9

    let loadout: RunLoadout
    private(set) var x = 0.0
    private(set) var distance = 0.0
    /// Seconds since the start.
    private(set) var time = 0.0
    var lives: Int
    var invulnerable = 0.0
    private(set) var isOver = false
    private(set) var streams: [PissStream] = []
    var vehicles: [Vehicle] = []
    private(set) var piles: [PoopPile] = []
    var roadCoins: [RoadCoin] = []
    var roadPickups: [RoadPickup] = []
    private(set) var ramps: [RoadRamp] = []
    private(set) var manholes: [Manhole] = []
    /// Road events ahead and the one under way, in order.
    private(set) var roadEvents: [RoadEvent] = []
    var powerUps = PowerUpTimers()
    /// The jump: height, cooldown and flips.
    var air = AirMeter()
    /// What the latest `update` saw besides its events: jumps, landings, tricks, road events.
    var moments: [RideMoment] = []

    var boostTank: BoostTank
    var comboMeter: ComboMeter
    private var generator: RoadGenerator
    private let populatesRoad: Bool
    var slowdownLeft = 0.0
    var slowdownFactor = 1.0
    var skidLeft = 0.0
    var coinBank = 0.0
    var coinScoreTotal = 0
    var bonusScore = 0
    var tally = RideSummary()
    /// Where the current stretch without a lost life began.
    var cleanSince = 0.0
    private var lastAnnouncedEvent = 0
    private var pendingEvents: [BikeEvent] = []
    private var pendingMoments: [RideMoment] = []

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

    // MARK: - Input

    /// Opens the gas. Returns false when the tank is too empty. `boostStart` comes with the next update.
    @discardableResult
    mutating func activateBoost() -> Bool {
        guard !isOver, boostTank.activate() else { return false }
        tally.boosts += 1
        pendingEvents.append(.boostStart)
        return true
    }

    /// Swipe up: a fart hop on the road, or a flip in the air off a ramp. Returns false when
    /// nothing happens (recharging, already flipping, ride over). The moment comes with the next update.
    @discardableResult
    mutating func jump() -> Bool {
        guard !isOver else { return false }
        if air.kind == .ramp {
            guard air.startFlip() else { return false }
            pendingMoments.append(.flipStarted)
            return true
        }
        guard air.hop() else { return false }
        tally.hops += 1
        pendingMoments.append(.jumped)
        return true
    }

    /// Puts something on the road by hand.
    mutating func place(_ stream: PissStream) { streams.append(stream) }
    mutating func place(_ vehicle: Vehicle) { vehicles.append(vehicle) }
    mutating func place(_ pile: PoopPile) { piles.append(pile) }
    mutating func place(_ coin: RoadCoin) { roadCoins.append(coin) }
    mutating func place(_ pickup: RoadPickup) { roadPickups.append(pickup) }
    mutating func place(_ ramp: RoadRamp) { ramps.append(ramp) }
    mutating func place(_ manhole: Manhole) { manholes.append(manhole) }
    mutating func place(_ event: RoadEvent) { roadEvents.append(event) }

    // MARK: - The frame

    /// Moves the ride forward and reports what happened. `targetX` is where the finger steers.
    mutating func update(dt: Double, targetX: Double) -> [BikeEvent] {
        guard !isOver, dt > 0 else {
            if !moments.isEmpty { moments = [] }
            return []
        }
        let step = min(dt, Self.maxStep)
        let previous = distance
        let districtBefore = district.index
        moments = pendingMoments
        pendingMoments = []
        steer(toward: targetX, dt: step)
        distance += speed * step
        time += step
        var events = pendingEvents
        pendingEvents = []
        events += tickMeters(dt: step)
        advanceObjects(dt: step)
        events += contacts(after: previous)
        if district.index != districtBefore { events.append(.districtEntered(district.index)) }
        announceRoadEvents()
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
        var events: [BikeEvent] = boostTank.burn(dt: dt) ? [.boostEnd] : []
        if let landing = air.tick(dt: dt) {
            events += land(landing)
        }
        return events
    }

    private mutating func advanceObjects(dt: Double) {
        let riderDistance = distance
        let riderSpeed = speed
        streams = streams.map { $0.advanced(dt: dt, riderDistance: riderDistance, riderSpeed: riderSpeed) }
        vehicles = vehicles.map { $0.advanced(dt: dt, riderDistance: riderDistance, riderSpeed: riderSpeed) }
    }

    /// Shows each road event's banner once, a moment before it starts.
    private mutating func announceRoadEvents() {
        let lead = speed * Self.eventLeadSeconds
        let upcoming = roadEvents
        for event in upcoming where event.id > lastAnnouncedEvent && distance + lead >= event.startZ {
            lastAnnouncedEvent = event.id
            moments.append(.roadEvent(event.kind))
        }
    }

    private mutating func removePassedObjects() {
        let cutoff = distance - Self.behind
        streams = streams.filter { $0.z >= cutoff }
        vehicles = vehicles.filter { $0.z >= cutoff }
        piles = piles.filter { $0.z >= cutoff }
        roadCoins = roadCoins.filter { $0.z >= cutoff }
        roadPickups = roadPickups.filter { $0.z >= cutoff }
        ramps = ramps.filter { $0.z >= cutoff }
        manholes = manholes.filter { $0.z >= cutoff }
        roadEvents = roadEvents.filter { $0.endZ >= cutoff }
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
            ramps += segment.ramps
            manholes += segment.manholes
            if let event = segment.event { roadEvents.append(event) }
        }
    }
}
