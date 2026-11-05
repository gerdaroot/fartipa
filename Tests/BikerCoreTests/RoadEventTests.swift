import XCTest
import Foundation
@testable import BikerCore

private func hasCyrillic(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
}

final class RoadEventTests: XCTestCase {
    private let roadEnd = 20000.0

    private func segments(seed: UInt64) -> [(z: Double, next: Double, road: RoadSegment)] {
        var generator = RoadGenerator(seed: seed, loadout: .base)
        var result: [(z: Double, next: Double, road: RoadSegment)] = []
        while generator.nextZ < roadEnd {
            let z = generator.nextZ
            let road = generator.nextSegment()
            result.append((z: z, next: generator.nextZ, road: road))
        }
        return result
    }

    private func events(seed: UInt64) -> [RoadEvent] {
        segments(seed: seed).compactMap { $0.road.event }
    }

    func testFirstEventIsTheCoinRainAndOthersFollow() {
        for seed in UInt64(1)...8 {
            let list = events(seed: seed)
            XCTAssertGreaterThanOrEqual(list.count, 5, "seed \(seed)")
            XCTAssertEqual(list.first?.kind, .coinRain)
            XCTAssertGreaterThanOrEqual(list.first?.startZ ?? 0, RoadEventPlanner.firstAt)
            for (earlier, later) in zip(list, list.dropFirst()) {
                XCTAssertNotEqual(earlier.kind, later.kind, "the same event twice in a row")
                XCTAssertGreaterThan(later.startZ, earlier.endZ, "events never overlap")
                XCTAssertGreaterThan(later.id, earlier.id)
            }
        }
        let kinds = Set((UInt64(1)...8).flatMap { events(seed: $0) }.map { $0.kind })
        XCTAssertEqual(kinds, Set(RoadEventKind.allCases))
    }

    func testEventsHaveRussianBanners() {
        for kind in RoadEventKind.allCases {
            XCTAssertTrue(hasCyrillic(kind.title))
            XCTAssertTrue(hasCyrillic(kind.subtitle))
            XCTAssertGreaterThan(kind.seconds, 0)
        }
        XCTAssertEqual(RoadEventKind.coinRain.title, "ГОВНОЛИВЕНЬ")
        XCTAssertEqual(RoadEventKind.pissHour.title, "ЧАС ССАНЬЯ")
        XCTAssertEqual(RoadEventKind.trafficWave.title, "ГОВНОВОЗЫ ПОПЁРЛИ")
    }

    func testRideAnnouncesTheCoinRainEarly() {
        let (_, _, moments) = TestRide.rideWithMoments(BikeRun(seed: 4), seconds: 40) { $0.autopilotTarget() }
        let banners = moments.compactMap { moment -> RoadEventKind? in
            if case .roadEvent(let kind) = moment { return kind }
            return nil
        }
        XCTAssertEqual(banners.first, .coinRain)
    }

    func testEventSegmentsFollowTheirRules() {
        var rainCoins = 0
        var rainLength = 0.0
        var plainCoins = 0
        var plainLength = 0.0
        for seed in UInt64(1)...6 {
            let road = segments(seed: seed)
            let list = events(seed: seed)
            for entry in road {
                let event = list.first { $0.contains(entry.z) }
                let length = entry.next - entry.z
                switch event?.kind {
                case .coinRain?:
                    XCTAssertTrue(entry.road.streams.isEmpty && entry.road.vehicles.isEmpty && entry.road.manholes.isEmpty)
                    rainCoins += entry.road.coins.count
                    rainLength += length
                case .pissHour?:
                    XCTAssertFalse(entry.road.streams.isEmpty)
                    let base = RunLoadout.base.warningSeconds * District.at(distance: entry.z).difficulty.warningScale
                    for stream in entry.road.streams {
                        XCTAssertGreaterThan(stream.warningSeconds, base * 1.4, "longer warnings")
                    }
                case .trafficWave?:
                    XCTAssertFalse(entry.road.vehicles.isEmpty)
                case .manholes?:
                    XCTAssertTrue(!entry.road.manholes.isEmpty || !entry.road.piles.isEmpty)
                case nil:
                    plainCoins += entry.road.coins.count
                    plainLength += length
                }
            }
        }
        XCTAssertGreaterThan(Double(rainCoins) / max(1, rainLength), 1.5 * Double(plainCoins) / max(1, plainLength))
    }

    /// Ground obstacles of one segment (piles, geysers, vehicles) never cover all three lanes, and a
    /// rolling lid comes alone.
    func testEverySegmentStillLeavesALaneOpen() {
        for seed in UInt64(1)...8 {
            for entry in segments(seed: seed) {
                var lanes = Set<Int>()
                for pile in entry.road.piles { lanes.formUnion(touchedLanes(pile.x, reach: BikeRun.pileReach)) }
                for vehicle in entry.road.vehicles {
                    lanes.formUnion(touchedLanes(vehicle.x, reach: vehicle.kind.halfWidth + BikeRun.bikeHalfWidth))
                }
                for hole in entry.road.manholes where hole.kind == .geyser {
                    lanes.formUnion(touchedLanes(hole.baseX, reach: hole.kind.reach))
                }
                XCTAssertLessThan(lanes.count, BikeRun.laneX.count, "seed \(seed) at \(entry.z)")
                let lids = entry.road.manholes.filter { $0.kind == .rollingLid }
                if !lids.isEmpty {
                    XCTAssertEqual(entry.road.manholes.count, 1)
                    XCTAssertGreaterThanOrEqual(entry.z, District.all[1].startDistance, "lids roll from the second district")
                }
                XCTAssertLessThanOrEqual(entry.road.ramps.count, 1)
            }
        }
    }

    private func touchedLanes(_ x: Double, reach: Double) -> Set<Int> {
        Set(BikeRun.laneX.indices.filter { abs(BikeRun.laneX[$0] - x) < reach })
    }

    func testOpeningIsFun() {
        for seed in UInt64(1)...8 {
            let road = segments(seed: seed)
            let firstCoin = road.first?.road.coins.first
            XCTAssertNotNil(firstCoin)
            XCTAssertLessThan(firstCoin?.z ?? .infinity, 70, "coins within three seconds")
            let early = road.flatMap { $0.road.ramps }.filter { $0.z >= RoadGenerator.introRampAt && $0.z < 330 }
            XCTAssertFalse(early.isEmpty, "a ramp in the first quarter minute, seed \(seed)")
        }
    }

    /// Parked traffic behind a ramp stands inside the flight even for a bike slowed by a skid.
    func testRampTrafficFitsUnderTheFlight() {
        var ramps = 0
        for seed in UInt64(1)...8 {
            for entry in segments(seed: seed) {
                guard let ramp = entry.road.ramps.first else { continue }
                ramps += 1
                let speed = BikeRun.cruisingSpeed(atDistance: ramp.z, topSpeed: RunLoadout.base.topSpeed)
                let slowest = speed * RunLoadout.base.skidSpeedFactor * AirMeter.rampSeconds
                let inLane = entry.road.vehicles.filter { $0.x == ramp.x }
                XCTAssertEqual(inLane.count, 1)
                for vehicle in entry.road.vehicles {
                    XCTAssertEqual(vehicle.z, vehicle.limitZ, "parked")
                    XCTAssertGreaterThan(vehicle.z - vehicle.kind.halfLength, ramp.z)
                    XCTAssertLessThanOrEqual(vehicle.z + vehicle.kind.halfLength, ramp.z + slowest + 0.001)
                }
                let air = entry.road.coins.filter { $0.lift > 0 }
                XCTAssertTrue(air.allSatisfy { $0.x == ramp.x && $0.lift <= AirMeter.rampHeight + 0.001 })
            }
        }
        XCTAssertGreaterThan(ramps, 20)
    }

    func testDistrictSharesLeaveRoomForStreamRows() {
        for district in District.all {
            let d = district.difficulty
            let total = d.emptyShare + d.pileShare + d.trafficShare + d.sweepShare + d.doubleRowShare
                + d.rampShare + d.manholeShare
            XCTAssertLessThan(total, 0.9, district.name)
        }
    }

    func testPlannerIsDeterministic() {
        var first = RoadEventPlanner(seed: 9)
        var second = RoadEventPlanner(seed: 9)
        for step in 0..<200 {
            let z = Double(step) * 50
            XCTAssertEqual(first.startIfDue(at: z, speed: 30), second.startIfDue(at: z, speed: 30))
        }
    }

    func testRunReportsTheEventItIsIn() {
        var run = TestRide.emptyRoad()
        run.place(RoadEvent(id: 1, kind: .pissHour, startZ: 40, endZ: 200))
        XCTAssertNil(run.currentRoadEvent)
        let (inside, _, moments) = TestRide.rideWithMoments(run, seconds: 3) { _ in 0 }
        XCTAssertEqual(moments.filter { $0 == .roadEvent(.pissHour) }.count, 1)
        XCTAssertEqual(inside.currentRoadEvent?.kind, .pissHour)
        XCTAssertGreaterThan(inside.roadEventSecondsLeft, 0)
    }
}
