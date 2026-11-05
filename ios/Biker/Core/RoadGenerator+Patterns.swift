import Foundation

/// The obstacle patterns. Every one of them leaves at least one lane open.
extension RoadGenerator {
    /// Seconds between the two rows of a double row: enough to shift by one lane.
    static let doubleRowSeconds = 0.7
    static let doubleRowShortest = 14.0
    /// How far a vehicle may roll from where it was placed.
    static let vehicleTravel = 35.0
    static let pileJitter = 0.4
    /// In a traffic wave, the share of sewage tankers.
    static let waveTankerChance = 0.5
    /// Parked traffic behind a ramp stands this share of the flight past the lip...
    static let rampVehicleShare = 0.4
    /// ...so that even a bike slowed to the worst skid factor still clears it.
    static let rampSlowestShare = 0.55
    /// A rolling lid instead of geysers, where the district has moving streams.
    static let lidChance = 0.35

    /// One or two of the three lanes, never all of them.
    mutating func chooseBlockedLanes(twoLaneChance: Double) -> [Int] {
        let openLane = random.int(below: Self.laneCount)
        if random.chance(twoLaneChance) {
            return (0..<Self.laneCount).filter { $0 != openLane }
        }
        return [(openLane + 1 + random.int(below: Self.laneCount - 1)) % Self.laneCount]
    }

    // MARK: - Streams

    mutating func makeStream(
        lane: Int, z: Double, rowId: Int, motion: StreamMotion, _ tuning: RoadTuning
    ) -> PissStream {
        let baseX = motion == .sweep ? 0.0 : BikeRun.laneX[lane]
        return PissStream(
            id: takeId(), rowId: rowId, motion: motion, baseX: baseX, z: z,
            phase: random.unit() * Self.fullCircle,
            warningSeconds: warningSeconds * tuning.warningScale
        )
    }

    mutating func makeStreamRow(at z: Double, _ tuning: RoadTuning) -> [PissStream] {
        let lanes = chooseBlockedLanes(twoLaneChance: tuning.twoLaneChance)
        let motion: StreamMotion = random.chance(tuning.difficulty.swayChance) ? .sway : .still
        let rowId = takeRowId()
        var row: [PissStream] = []
        for lane in lanes {
            row.append(makeStream(lane: lane, z: z, rowId: rowId, motion: motion, tuning))
        }
        return row
    }

    mutating func makeSweep(at z: Double, _ tuning: RoadTuning) -> PissStream {
        let rowId = takeRowId()
        return makeStream(lane: Self.middleLane, z: z, rowId: rowId, motion: .sweep, tuning)
    }

    /// Two close rows of two streams each. The open lane shifts by exactly one.
    mutating func makeDoubleRow(at z: Double, secondAt secondZ: Double, _ tuning: RoadTuning) -> [PissStream] {
        let firstOpen = random.int(below: Self.laneCount)
        let shift = random.chance(Self.evenOdds) ? 1 : -1
        let secondOpen = firstOpen == Self.middleLane ? Self.middleLane + shift : Self.middleLane
        let first = makeTwoStreamRow(openLane: firstOpen, z: z, tuning)
        let second = makeTwoStreamRow(openLane: secondOpen, z: secondZ, tuning)
        return first + second
    }

    private mutating func makeTwoStreamRow(openLane: Int, z: Double, _ tuning: RoadTuning) -> [PissStream] {
        let rowId = takeRowId()
        var row: [PissStream] = []
        for lane in 0..<Self.laneCount where lane != openLane {
            row.append(makeStream(lane: lane, z: z, rowId: rowId, motion: .still, tuning))
        }
        return row
    }

    // MARK: - Ground obstacles

    mutating func makeTraffic(at z: Double, _ tuning: RoadTuning) -> [Vehicle] {
        let lanes = chooseBlockedLanes(twoLaneChance: tuning.twoLaneChance)
        var vehicles: [Vehicle] = []
        for lane in lanes {
            let kind = chooseVehicleKind(tankers: tuning.event == .trafficWave)
            let start = z + kind.halfLength
            vehicles.append(
                Vehicle(id: takeId(), kind: kind, x: BikeRun.laneX[lane], z: start, limitZ: start + Self.vehicleTravel)
            )
        }
        return vehicles
    }

    private mutating func chooseVehicleKind(tankers: Bool) -> VehicleKind {
        if tankers, random.chance(Self.waveTankerChance) { return .sewageTanker }
        return VehicleKind.allCases[random.int(below: VehicleKind.allCases.count)]
    }

    mutating func makePiles(at z: Double, _ tuning: RoadTuning) -> [PoopPile] {
        let lanes = chooseBlockedLanes(twoLaneChance: tuning.twoLaneChance)
        var piles: [PoopPile] = []
        for lane in lanes {
            let jitter = (random.unit() * 2 - 1) * Self.pileJitter
            piles.append(PoopPile(id: takeId(), x: BikeRun.laneX[lane] + jitter, z: z))
        }
        return piles
    }

    /// Geysers in one or two lanes, or one lid rolling across the whole road.
    mutating func makeManholes(at z: Double, _ tuning: RoadTuning) -> [Manhole] {
        let rolls = tuning.difficulty.swayChance > 0 && random.chance(Self.lidChance)
        if rolls {
            return [Manhole(id: takeId(), kind: .rollingLid, baseX: 0, z: z, phase: random.unit())]
        }
        var holes: [Manhole] = []
        for lane in chooseBlockedLanes(twoLaneChance: tuning.twoLaneChance) {
            holes.append(Manhole(id: takeId(), kind: .geyser, baseX: BikeRun.laneX[lane], z: z, phase: random.unit()))
        }
        return holes
    }

    // MARK: - Ramp jump

    /// A ramp with its lip at `z`, a parked vehicle in its lane under the middle of the flight,
    /// maybe a second one beside it, and coins along the arc. Returns the flight length.
    mutating func makeRampJump(
        into segment: inout RoadSegment, at z: Double, speed: Double, _ tuning: RoadTuning
    ) -> Double {
        let flight = speed * AirMeter.rampSeconds
        let lane = random.int(below: Self.laneCount)
        segment.ramps = [RoadRamp(id: takeId(), x: BikeRun.laneX[lane], z: z)]
        let centre = z + flight * Self.rampVehicleShare
        let room = flight * (Self.rampSlowestShare - Self.rampVehicleShare)
        var vehicles = [parkedVehicle(lane: lane, centre: centre, room: room)]
        if random.chance(tuning.twoLaneChance) {
            let other = (lane + 1 + random.int(below: Self.laneCount - 1)) % Self.laneCount
            vehicles.append(parkedVehicle(lane: other, centre: centre, room: room))
        }
        segment.vehicles = vehicles
        segment.coins = makeAirCoins(lane: lane, from: z, flight: flight)
        return flight
    }

    /// A vehicle standing still, short enough to fit in `room` metres past `centre`.
    private mutating func parkedVehicle(lane: Int, centre: Double, room: Double) -> Vehicle {
        let fitting = VehicleKind.allCases.filter { $0.halfLength <= room }
        let kinds = fitting.isEmpty ? [VehicleKind.car] : fitting
        let kind = kinds[random.int(below: kinds.count)]
        return Vehicle(id: takeId(), kind: kind, x: BikeRun.laneX[lane], z: centre, limitZ: centre)
    }
}
