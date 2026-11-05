import Foundation

/// A stretch of road handed to `BikeRun`: at most one obstacle pattern, plus coins and maybe a pickup.
struct RoadSegment: Equatable {
    var streams: [PissStream] = []
    var vehicles: [Vehicle] = []
    var piles: [PoopPile] = []
    var coins: [RoadCoin] = []
    var pickups: [RoadPickup] = []
    var ramps: [RoadRamp] = []
    var manholes: [Manhole] = []
    /// A road event that starts with this segment.
    var event: RoadEvent?
}

/// The numbers one segment is laid out with: the district's, changed by a road event under way.
struct RoadTuning: Equatable {
    static let busyTwoLaneChance = 0.5
    static let pissHourWarning = 1.5
    static let pissHourGap = 0.9
    static let coinRainGap = 1.15

    let difficulty: DistrictDifficulty
    let event: RoadEventKind?
    let gapSeconds: Double
    let twoLaneChance: Double
    let warningScale: Double

    init(_ difficulty: DistrictDifficulty, event: RoadEventKind?) {
        self.difficulty = difficulty
        self.event = event
        let busy = event == .pissHour || event == .trafficWave
        twoLaneChance = busy ? max(difficulty.twoLaneChance, Self.busyTwoLaneChance) : difficulty.twoLaneChance
        warningScale = difficulty.warningScale * (event == .pissHour ? Self.pissHourWarning : 1)
        switch event {
        case .coinRain?: gapSeconds = max(difficulty.gapSeconds, Self.coinRainGap)
        case .pissHour?: gapSeconds = difficulty.gapSeconds * Self.pissHourGap
        default: gapSeconds = difficulty.gapSeconds
        }
    }
}

/// Lays out the road from a seed. The layout depends only on the seed and loadout, never on how
/// the rider rides. Obstacle patterns never overlap along the road, and each one keeps a lane open,
/// so there is always a way through. The opening is fixed for a fun first half-minute: coins at
/// once, a ramp at `introRampAt`, and the coin rain as the first road event.
/// Pattern builders are in `RoadGenerator+Patterns.swift`, coins in `RoadGenerator+Coins.swift`;
/// their state is internal only so those files can share it.
struct RoadGenerator: Equatable {
    enum Pattern: Equatable {
        case empty, piles, traffic, sweep, doubleRow, streamRow, ramp, manholes
    }

    static let firstSegmentAt = 45.0
    static let introRampAt = 230.0
    static let shortestGap = 24.0
    static let laneCount = 3
    static let middleLane = 1
    static let evenOdds = 0.5
    static let fullCircle = 2 * Double.pi
    private static let rainPileChance = 0.3
    private static let pissHourDoubleChance = 0.3
    private static let waveRampChance = 0.3
    private static let holePileChance = 0.25

    var random: SplitMix
    var nextId = 1
    var nextRowId = 1
    var nextCoinsAt = 0.0
    /// Where the next segment starts.
    private(set) var nextZ = RoadGenerator.firstSegmentAt
    let topSpeed: Double
    let warningSeconds: Double
    let pickupRate: Double
    private var planner: RoadEventPlanner
    private var hasOpened = false
    private var hasIntroRamp = false

    init(seed: UInt64, loadout: RunLoadout) {
        random = SplitMix(seed: seed)
        planner = RoadEventPlanner(seed: seed)
        topSpeed = loadout.topSpeed
        warningSeconds = loadout.warningSeconds
        pickupRate = loadout.pickupRate
    }

    /// Makes the next stretch of road and moves `nextZ` past it.
    mutating func nextSegment() -> RoadSegment {
        let z = nextZ
        let speed = BikeRun.cruisingSpeed(atDistance: z, topSpeed: topSpeed)
        var segment = RoadSegment()
        segment.event = planner.startIfDue(at: z, speed: speed)
        let tuning = RoadTuning(District.at(distance: z).difficulty, event: planner.active(at: z)?.kind)
        let gap = max(Self.shortestGap, speed * tuning.gapSeconds)
        let opening = !hasOpened
        let pattern = choosePattern(tuning, at: z)
        hasOpened = true
        let extent = fill(&segment, with: pattern, at: z, speed: speed, tuning)
        segment.coins += makeCoinsIfDue(at: z + extent, gap: gap, speed: speed, tuning, forced: opening)
        segment.pickups = makePickupIfLucky(at: z + extent, gap: gap)
        nextZ = z + extent + gap
        return segment
    }

    private mutating func choosePattern(_ tuning: RoadTuning, at z: Double) -> Pattern {
        if !hasOpened { return .empty }
        if !hasIntroRamp, z >= Self.introRampAt, tuning.event == nil {
            hasIntroRamp = true
            return .ramp
        }
        switch tuning.event {
        case .coinRain?: return random.chance(Self.rainPileChance) ? .piles : .empty
        case .pissHour?:
            let doubles = tuning.difficulty.doubleRowShare > 0 && random.chance(Self.pissHourDoubleChance)
            return doubles ? .doubleRow : .streamRow
        case .trafficWave?: return random.chance(Self.waveRampChance) ? .ramp : .traffic
        case .manholes?: return random.chance(Self.holePileChance) ? .piles : .manholes
        case nil: return choosePlainPattern(tuning.difficulty)
        }
    }

    private mutating func choosePlainPattern(_ difficulty: DistrictDifficulty) -> Pattern {
        let roll = random.unit()
        let shares: [(pattern: Pattern, share: Double)] = [
            (pattern: .empty, share: difficulty.emptyShare),
            (pattern: .piles, share: difficulty.pileShare),
            (pattern: .traffic, share: difficulty.trafficShare),
            (pattern: .sweep, share: difficulty.sweepShare),
            (pattern: .doubleRow, share: difficulty.doubleRowShare),
            (pattern: .ramp, share: difficulty.rampShare),
            (pattern: .manholes, share: difficulty.manholeShare),
        ]
        var cumulative = 0.0
        for entry in shares {
            cumulative += entry.share
            if roll < cumulative { return entry.pattern }
        }
        return .streamRow
    }

    /// Puts the pattern's obstacles into the segment. Returns how far along the road they reach.
    private mutating func fill(
        _ segment: inout RoadSegment, with pattern: Pattern, at z: Double, speed: Double, _ tuning: RoadTuning
    ) -> Double {
        switch pattern {
        case .empty:
            return 0
        case .piles:
            segment.piles = makePiles(at: z, tuning)
            return 0
        case .traffic:
            let vehicles = makeTraffic(at: z, tuning)
            segment.vehicles = vehicles
            return Self.vehicleTravel + 2 * (vehicles.map { $0.kind.halfLength }.max() ?? 0)
        case .sweep:
            segment.streams = [makeSweep(at: z, tuning)]
            return 0
        case .doubleRow:
            let extent = max(Self.doubleRowShortest, speed * Self.doubleRowSeconds)
            segment.streams = makeDoubleRow(at: z, secondAt: z + extent, tuning)
            return extent
        case .streamRow:
            segment.streams = makeStreamRow(at: z, tuning)
            return 0
        case .ramp:
            return makeRampJump(into: &segment, at: z, speed: speed, tuning)
        case .manholes:
            segment.manholes = makeManholes(at: z, tuning)
            return 0
        }
    }

    mutating func takeId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }

    mutating func takeRowId() -> Int {
        let id = nextRowId
        nextRowId += 1
        return id
    }
}
