import Foundation

/// Coin runs and pickups. Coin runs never overlap along the road (`nextCoinsAt`).
extension RoadGenerator {
    enum CoinShape: Equatable {
        case line, weave, arc
        /// Two parallel lines in two lanes, for the coin rain.
        case twinLines
    }

    static let coinChance = 0.7
    static let coinSpacingSeconds = 0.09
    static let coinSpacingShortest = 3.0
    static let coinPatternGap = 8.0
    static let coinStartShare = 0.25
    static let lineShare = 0.4
    static let weaveShare = 0.35
    static let lineCoins = 8
    static let weaveCoins = 10
    static let arcCoins = 9
    static let twinCoins = 7
    static let weaveAmplitude = 2.4
    static let weaveWaves = 1.5
    static let goldenChance = 0.12
    static let rainGoldenChance = 0.3
    static let rainTwinShare = 0.5
    /// Coins hanging along a ramp's flight; the middle one is golden.
    static let airCoins = 7
    static let pickupChance = 0.06
    static let pickupStartShare = 0.5
    /// The relative odds of each pickup, in the order of `PickupKind.allCases`.
    static let pickupOdds: [(kind: PickupKind, odds: Double)] = [
        (kind: .magnet, odds: 3), (kind: .shield, odds: 3), (kind: .coinDoubler, odds: 2),
        (kind: .boostRefill, odds: 3), (kind: .repair, odds: 1),
    ]

    /// `forced` lays a straight line in the middle lane, for the very start of the ride.
    mutating func makeCoinsIfDue(
        at z: Double, gap: Double, speed: Double, _ tuning: RoadTuning, forced: Bool
    ) -> [RoadCoin] {
        let isRain = tuning.event == .coinRain
        let wanted = random.chance(isRain ? 1 : Self.coinChance)
        let start = z + gap * Self.coinStartShare
        guard wanted || forced, start >= nextCoinsAt else { return [] }
        let spacing = max(Self.coinSpacingShortest, speed * Self.coinSpacingSeconds)
        let shape = forced ? CoinShape.line : chooseShape(rain: isRain)
        let golden = isRain ? Self.rainGoldenChance : Self.goldenChance
        let coins = makeCoins(shape, from: start, spacing: spacing, goldenChance: golden, forced: forced)
        nextCoinsAt = (coins.last?.z ?? start) + Self.coinPatternGap
        return coins
    }

    private mutating func chooseShape(rain: Bool) -> CoinShape {
        let roll = random.unit()
        if rain { return roll < Self.rainTwinShare ? .twinLines : .weave }
        if roll < Self.lineShare { return .line }
        return roll < Self.lineShare + Self.weaveShare ? .weave : .arc
    }

    private mutating func makeCoins(
        _ shape: CoinShape, from start: Double, spacing: Double, goldenChance: Double, forced: Bool
    ) -> [RoadCoin] {
        let count = coinCount(shape)
        let laneIndex = forced ? Self.middleLane : random.int(below: Self.laneCount)
        let endIndex = random.int(below: Self.laneCount)
        let twinIndex = (laneIndex + 1 + random.int(below: Self.laneCount - 1)) % Self.laneCount
        let lane = BikeRun.laneX[laneIndex]
        let endLane = shape == .twinLines ? BikeRun.laneX[twinIndex] : BikeRun.laneX[endIndex]
        let goldenIndex = random.chance(goldenChance) ? count / 2 : -1
        var coins: [RoadCoin] = []
        for index in 0..<count {
            let progress = Double(index) / Double(count - 1)
            let z = start + Double(index) * spacing
            let isGolden = index == goldenIndex
            coins.append(RoadCoin(
                id: takeId(), x: Self.coinX(shape, progress: progress, lane: lane, endLane: endLane), z: z, isGolden: isGolden
            ))
            if shape == .twinLines {
                coins.append(RoadCoin(id: takeId(), x: endLane, z: z, isGolden: isGolden))
            }
        }
        return coins
    }

    private func coinCount(_ shape: CoinShape) -> Int {
        switch shape {
        case .line: return Self.lineCoins
        case .weave: return Self.weaveCoins
        case .arc: return Self.arcCoins
        case .twinLines: return Self.twinCoins
        }
    }

    private static func coinX(_ shape: CoinShape, progress: Double, lane: Double, endLane: Double) -> Double {
        switch shape {
        case .line, .twinLines:
            return lane
        case .weave:
            return weaveAmplitude * sin(progress * weaveWaves * fullCircle)
        case .arc:
            return lane + (endLane - lane) * sin(progress * Double.pi / 2)
        }
    }

    /// Coins along the flight off a ramp, at the height the bike will be at each of them.
    mutating func makeAirCoins(lane: Int, from z: Double, flight: Double) -> [RoadCoin] {
        guard z >= nextCoinsAt else { return [] }
        var coins: [RoadCoin] = []
        for index in 0..<Self.airCoins {
            let share = Double(index + 1) / Double(Self.airCoins + 1)
            let lift = 4 * AirMeter.rampHeight * share * (1 - share)
            coins.append(RoadCoin(
                id: takeId(), x: BikeRun.laneX[lane], z: z + flight * share,
                isGolden: index == Self.airCoins / 2, lift: lift
            ))
        }
        nextCoinsAt = (coins.last?.z ?? z) + Self.coinPatternGap
        return coins
    }

    mutating func makePickupIfLucky(at z: Double, gap: Double) -> [RoadPickup] {
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
