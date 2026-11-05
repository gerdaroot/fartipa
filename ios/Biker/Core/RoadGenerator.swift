import Foundation

/// A stretch of road handed to `BikeRun`: at most one obstacle pattern, plus coins and maybe a pickup.
struct RoadSegment: Equatable {
    var streams: [PissStream] = []
    var vehicles: [Vehicle] = []
    var piles: [PoopPile] = []
    var coins: [RoadCoin] = []
    var pickups: [RoadPickup] = []
}

/// Lays out the road from a seed. The layout depends only on the seed and loadout, never on how
/// the rider rides. Obstacle patterns never overlap along the road, and each one keeps a lane open,
/// so there is always a way through.
struct RoadGenerator: Equatable {
    private enum Pattern {
        case empty, piles, traffic, sweep, doubleRow, streamRow
    }

    private enum CoinShape {
        case line, weave, arc
    }

    private static let firstSegmentAt = 70.0
    private static let shortestGap = 24.0
    private static let laneCount = 3
    private static let middleLane = 1
    private static let evenOdds = 0.5
    private static let fullCircle = 2 * Double.pi
    /// Seconds between the two rows of a double row: enough to shift by one lane.
    private static let doubleRowSeconds = 0.7
    private static let doubleRowShortest = 14.0
    /// How far a vehicle may roll from where it was placed.
    private static let vehicleTravel = 35.0
    private static let pileJitter = 0.4
    private static let coinChance = 0.7
    private static let coinSpacingSeconds = 0.09
    private static let coinSpacingShortest = 3.0
    private static let coinPatternGap = 8.0
    private static let coinStartShare = 0.25
    private static let lineShare = 0.4
    private static let weaveShare = 0.35
    private static let lineCoins = 8
    private static let weaveCoins = 10
    private static let arcCoins = 9
    private static let weaveAmplitude = 2.4
    private static let weaveWaves = 1.5
    private static let goldenChance = 0.12
    private static let pickupChance = 0.06
    private static let pickupStartShare = 0.5
    /// The relative odds of each pickup, in the order of `PickupKind.allCases`.
    private static let pickupOdds: [(kind: PickupKind, odds: Double)] = [
        (kind: .magnet, odds: 3), (kind: .shield, odds: 3), (kind: .coinDoubler, odds: 2),
        (kind: .boostRefill, odds: 3), (kind: .repair, odds: 1),
    ]

    private var random: SplitMix
    private var nextId = 1
    private var nextRowId = 1
    private var nextCoinsAt = 0.0
    /// Where the next segment starts.
    private(set) var nextZ = RoadGenerator.firstSegmentAt
    private let topSpeed: Double
    private let warningSeconds: Double
    private let pickupRate: Double

    init(seed: UInt64, loadout: RunLoadout) {
        random = SplitMix(seed: seed)
        topSpeed = loadout.topSpeed
        warningSeconds = loadout.warningSeconds
        pickupRate = loadout.pickupRate
    }

    /// Makes the next stretch of road and moves `nextZ` past it.
    mutating func nextSegment() -> RoadSegment {
        let z = nextZ
        let difficulty = District.at(distance: z).difficulty
        let speed = BikeRun.cruisingSpeed(atDistance: z, topSpeed: topSpeed)
        let gap = max(Self.shortestGap, speed * difficulty.gapSeconds)
        var segment = RoadSegment()
        var extent = 0.0
        switch choosePattern(difficulty) {
        case .empty:
            break
        case .piles:
            segment.piles = makePiles(at: z, difficulty)
        case .traffic:
            let vehicles = makeTraffic(at: z, difficulty)
            segment.vehicles = vehicles
            extent = Self.vehicleTravel + 2 * (vehicles.map { $0.kind.halfLength }.max() ?? 0)
        case .sweep:
            segment.streams = [makeSweep(at: z, difficulty)]
        case .doubleRow:
            extent = max(Self.doubleRowShortest, speed * Self.doubleRowSeconds)
            segment.streams = makeDoubleRow(at: z, secondAt: z + extent, difficulty)
        case .streamRow:
            segment.streams = makeStreamRow(at: z, difficulty)
        }
        segment.coins = makeCoinsIfDue(at: z + extent, gap: gap, speed: speed)
        segment.pickups = makePickupIfLucky(at: z + extent, gap: gap)
        nextZ = z + extent + gap
        return segment
    }

    // MARK: - Obstacles

    private mutating func choosePattern(_ difficulty: DistrictDifficulty) -> Pattern {
        let roll = random.unit()
        let shares: [(pattern: Pattern, share: Double)] = [
            (pattern: .empty, share: difficulty.emptyShare),
            (pattern: .piles, share: difficulty.pileShare),
            (pattern: .traffic, share: difficulty.trafficShare),
            (pattern: .sweep, share: difficulty.sweepShare),
            (pattern: .doubleRow, share: difficulty.doubleRowShare),
        ]
        var cumulative = 0.0
        for entry in shares {
            cumulative += entry.share
            if roll < cumulative { return entry.pattern }
        }
        return .streamRow
    }

    /// One or two of the three lanes, never all of them.
    private mutating func chooseBlockedLanes(twoLaneChance: Double) -> [Int] {
        let openLane = random.int(below: Self.laneCount)
        if random.chance(twoLaneChance) {
            return (0..<Self.laneCount).filter { $0 != openLane }
        }
        return [(openLane + 1 + random.int(below: Self.laneCount - 1)) % Self.laneCount]
    }

    private mutating func takeId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }

    private mutating func takeRowId() -> Int {
        let id = nextRowId
        nextRowId += 1
        return id
    }

    private mutating func makeStream(
        lane: Int, z: Double, rowId: Int, motion: StreamMotion, _ difficulty: DistrictDifficulty
    ) -> PissStream {
        let baseX = motion == .sweep ? 0.0 : BikeRun.laneX[lane]
        return PissStream(
            id: takeId(), rowId: rowId, motion: motion, baseX: baseX, z: z,
            phase: random.unit() * Self.fullCircle,
            warningSeconds: warningSeconds * difficulty.warningScale
        )
    }

    private mutating func makeStreamRow(at z: Double, _ difficulty: DistrictDifficulty) -> [PissStream] {
        let lanes = chooseBlockedLanes(twoLaneChance: difficulty.twoLaneChance)
        let motion: StreamMotion = random.chance(difficulty.swayChance) ? .sway : .still
        let rowId = takeRowId()
        var row: [PissStream] = []
        for lane in lanes {
            row.append(makeStream(lane: lane, z: z, rowId: rowId, motion: motion, difficulty))
        }
        return row
    }

    private mutating func makeSweep(at z: Double, _ difficulty: DistrictDifficulty) -> PissStream {
        let rowId = takeRowId()
        return makeStream(lane: Self.middleLane, z: z, rowId: rowId, motion: .sweep, difficulty)
    }

    /// Two close rows of two streams each. The open lane shifts by exactly one.
    private mutating func makeDoubleRow(
        at z: Double, secondAt secondZ: Double, _ difficulty: DistrictDifficulty
    ) -> [PissStream] {
        let firstOpen = random.int(below: Self.laneCount)
        let shift = random.chance(Self.evenOdds) ? 1 : -1
        let secondOpen = firstOpen == Self.middleLane ? Self.middleLane + shift : Self.middleLane
        let first = makeTwoStreamRow(openLane: firstOpen, z: z, difficulty)
        let second = makeTwoStreamRow(openLane: secondOpen, z: secondZ, difficulty)
        return first + second
    }

    private mutating func makeTwoStreamRow(
        openLane: Int, z: Double, _ difficulty: DistrictDifficulty
    ) -> [PissStream] {
        let rowId = takeRowId()
        var row: [PissStream] = []
        for lane in 0..<Self.laneCount where lane != openLane {
            row.append(makeStream(lane: lane, z: z, rowId: rowId, motion: .still, difficulty))
        }
        return row
    }

    private mutating func makeTraffic(at z: Double, _ difficulty: DistrictDifficulty) -> [Vehicle] {
        let lanes = chooseBlockedLanes(twoLaneChance: difficulty.twoLaneChance)
        var vehicles: [Vehicle] = []
        for lane in lanes {
            let kind = VehicleKind.allCases[random.int(below: VehicleKind.allCases.count)]
            let start = z + kind.halfLength
            vehicles.append(
                Vehicle(id: takeId(), kind: kind, x: BikeRun.laneX[lane], z: start, limitZ: start + Self.vehicleTravel)
            )
        }
        return vehicles
    }

    private mutating func makePiles(at z: Double, _ difficulty: DistrictDifficulty) -> [PoopPile] {
        let lanes = chooseBlockedLanes(twoLaneChance: difficulty.twoLaneChance)
        var piles: [PoopPile] = []
        for lane in lanes {
            let jitter = (random.unit() * 2 - 1) * Self.pileJitter
            piles.append(PoopPile(id: takeId(), x: BikeRun.laneX[lane] + jitter, z: z))
        }
        return piles
    }

    // MARK: - Coins and pickups

    private mutating func makeCoinsIfDue(at z: Double, gap: Double, speed: Double) -> [RoadCoin] {
        let wanted = random.chance(Self.coinChance)
        let start = z + gap * Self.coinStartShare
        guard wanted, start >= nextCoinsAt else { return [] }
        let spacing = max(Self.coinSpacingShortest, speed * Self.coinSpacingSeconds)
        let roll = random.unit()
        let shape: CoinShape = roll < Self.lineShare ? .line : (roll < Self.lineShare + Self.weaveShare ? .weave : .arc)
        let coins = makeCoins(shape, from: start, spacing: spacing)
        nextCoinsAt = (coins.last?.z ?? start) + Self.coinPatternGap
        return coins
    }

    private mutating func makeCoins(_ shape: CoinShape, from start: Double, spacing: Double) -> [RoadCoin] {
        let count = coinCount(shape)
        let lane = BikeRun.laneX[random.int(below: Self.laneCount)]
        let endLane = BikeRun.laneX[random.int(below: Self.laneCount)]
        let goldenIndex = random.chance(Self.goldenChance) ? count / 2 : -1
        var coins: [RoadCoin] = []
        for index in 0..<count {
            let progress = Double(index) / Double(count - 1)
            coins.append(
                RoadCoin(
                    id: takeId(),
                    x: Self.coinX(shape, progress: progress, lane: lane, endLane: endLane),
                    z: start + Double(index) * spacing,
                    isGolden: index == goldenIndex
                )
            )
        }
        return coins
    }

    private func coinCount(_ shape: CoinShape) -> Int {
        switch shape {
        case .line: return Self.lineCoins
        case .weave: return Self.weaveCoins
        case .arc: return Self.arcCoins
        }
    }

    private static func coinX(_ shape: CoinShape, progress: Double, lane: Double, endLane: Double) -> Double {
        switch shape {
        case .line:
            return lane
        case .weave:
            return weaveAmplitude * sin(progress * weaveWaves * fullCircle)
        case .arc:
            return lane + (endLane - lane) * sin(progress * Double.pi / 2)
        }
    }

    private mutating func makePickupIfLucky(at z: Double, gap: Double) -> [RoadPickup] {
        guard random.chance(Self.pickupChance * pickupRate) else { return [] }
        let lane = BikeRun.laneX[random.int(below: Self.laneCount)]
        let total = Self.pickupOdds.reduce(0.0) { $0 + $1.odds }
        var roll = random.unit() * total
        var chosen = PickupKind.magnet
        for entry in Self.pickupOdds {
            chosen = entry.kind
            roll -= entry.odds
            if roll < 0 { break }
        }
        return [RoadPickup(id: takeId(), kind: chosen, x: lane, z: z + gap * Self.pickupStartShare)]
    }
}
