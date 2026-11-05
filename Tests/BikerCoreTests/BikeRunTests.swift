import XCTest
import Foundation
@testable import BikerCore

/// Helpers for riding in tests.
enum TestRide {
    static let frame = 1.0 / 60

    /// Keeps riding until the time is up or the ride ends.
    static func ride(
        _ start: BikeRun, seconds: Double, steer: (BikeRun) -> Double
    ) -> (run: BikeRun, events: [BikeEvent]) {
        var run = start
        var events: [BikeEvent] = []
        var elapsed = 0.0
        while elapsed < seconds, !run.isOver {
            events += run.update(dt: frame, targetX: steer(run))
            elapsed += frame
        }
        return (run, events)
    }

    /// An empty road for hand-placed objects.
    static func emptyRoad(loadout: RunLoadout = .base) -> BikeRun {
        BikeRun(seed: 1, loadout: loadout, populatesRoad: false)
    }
}

final class BikeRunCoreTests: XCTestCase {
    func testSameSeedAndInputGiveTheSameRide() {
        let steer: (BikeRun) -> Double = { sin($0.time) * 3 }
        let first = TestRide.ride(BikeRun(seed: 77), seconds: 60, steer: steer)
        let second = TestRide.ride(BikeRun(seed: 77), seconds: 60, steer: steer)
        XCTAssertEqual(first.events, second.events)
        XCTAssertEqual(first.run, second.run)
    }

    func testDifferentSeedsGiveDifferentRoads() {
        XCTAssertNotEqual(BikeRun(seed: 1).streams, BikeRun(seed: 2).streams)
    }

    func testCarefulRiderSurvivesFiveMinutesOnManySeeds() {
        for seed in UInt64(1)...24 {
            let (run, events) = TestRide.ride(BikeRun(seed: seed), seconds: 300) { $0.autopilotTarget() }
            XCTAssertFalse(events.contains(.hit), "seed \(seed) hit at \(Int(run.distance)) m")
            XCTAssertFalse(events.contains(.shieldBlocked), "seed \(seed)")
            XCTAssertFalse(run.isOver, "seed \(seed)")
            XCTAssertGreaterThan(run.summary.coinsPicked, 300, "seed \(seed)")
            XCTAssertEqual(run.cruisingSpeed, run.loadout.topSpeed, accuracy: 0.01)
            XCTAssertEqual(run.district.index, District.all.count - 1, "seed \(seed)")
        }
    }

    func testCarefulRiderSurvivesOnAFullyUpgradedBikeToo() {
        for seed in UInt64(1)...12 {
            let start = BikeRun(seed: seed, loadout: .maxed)
            let (run, events) = TestRide.ride(start, seconds: 300) { $0.autopilotTarget() }
            XCTAssertFalse(events.contains(.hit), "seed \(seed) hit at \(Int(run.distance)) m")
            XCTAssertFalse(events.contains(.shieldBlocked), "seed \(seed)")
        }
    }

    func testRiderWhoNeverSteersEventuallyLoses() {
        let (run, events) = TestRide.ride(BikeRun(seed: 3), seconds: 600) { _ in 0 }
        XCTAssertTrue(run.isOver)
        XCTAssertGreaterThanOrEqual(events.filter { $0 == .hit }.count, BikeRun(seed: 3).lives)
        XCTAssertEqual(events.last, .gameOver)
        XCTAssertEqual(run.lives, 0)
    }

    func testFinishedRunStopsChanging() {
        var (run, _) = TestRide.ride(BikeRun(seed: 3), seconds: 600) { _ in 0 }
        let distance = run.distance
        XCTAssertEqual(run.update(dt: 1, targetX: 0), [])
        XCTAssertEqual(run.distance, distance)
        XCTAssertFalse(run.activateBoost())
    }

    func testSpeedRampsUpToTheTop() {
        let start = BikeRun.cruisingSpeed(atDistance: 0, topSpeed: 55)
        let middle = BikeRun.cruisingSpeed(atDistance: BikeRun.rampDistance / 2, topSpeed: 55)
        let end = BikeRun.cruisingSpeed(atDistance: BikeRun.rampDistance * 2, topSpeed: 55)
        XCTAssertEqual(start, BikeRun.startSpeed)
        XCTAssertGreaterThan(middle, start)
        XCTAssertEqual(end, 55)
    }

    func testBikeStaysOnRoadAndCannotTeleport() {
        var run = TestRide.emptyRoad()
        _ = run.update(dt: 0.1, targetX: 100)
        XCTAssertEqual(run.x, RunLoadout.base.steerRate * 0.1, accuracy: 0.001)
        for _ in 0..<200 { _ = run.update(dt: TestRide.frame, targetX: 100) }
        XCTAssertEqual(run.x, BikeRun.bikeLimit, accuracy: 0.001)
        XCTAssertLessThan(run.x, BikeRun.roadHalfWidth)
    }

    func testBadInputDoesNotBreakTheRide() {
        var run = TestRide.emptyRoad()
        XCTAssertEqual(run.update(dt: .nan, targetX: 0), [])
        XCTAssertEqual(run.update(dt: -1, targetX: 0), [])
        _ = run.update(dt: 0.01, targetX: .nan)
        XCTAssertEqual(run.x, 0)
        let before = run.distance
        _ = run.update(dt: 1000, targetX: 0)
        XCTAssertLessThan(run.distance - before, 10, "a long stall counts as one short step")
    }

    func testOldObjectsAreRemoved() {
        let (run, _) = TestRide.ride(BikeRun(seed: 2), seconds: 120) { $0.autopilotTarget() }
        let count = run.streams.count + run.vehicles.count + run.piles.count + run.roadCoins.count
        XCTAssertLessThan(count, 300)
        XCTAssertTrue(run.roadCoins.allSatisfy { $0.z >= run.distance - BikeRun.behind })
        XCTAssertTrue(run.streams.allSatisfy { $0.z >= run.distance - BikeRun.behind })
    }

    func testEachCoinCountsOnceAndSummaryAddsUp() {
        let (run, events) = TestRide.ride(BikeRun(seed: 5), seconds: 60) { $0.autopilotTarget() }
        let plain = events.filter { $0 == .coin }.count
        let golden = events.filter { $0 == .goldenCoin }.count
        XCTAssertGreaterThan(plain, 0)
        XCTAssertEqual(plain + golden, run.summary.coinsPicked)
        XCTAssertEqual(golden, run.summary.goldenCoins)
        XCTAssertEqual(run.summary.score, run.score)
        XCTAssertEqual(run.summary.distance, Int(run.distance))
    }
}

final class StreamRuleTests: XCTestCase {
    func testStreamWarnsThenPoursThenHits() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 100, warningSeconds: 1))
        XCTAssertEqual(run.streams[0].warning, 0)
        XCTAssertFalse(run.streams[0].isVisible)
        var sawMarker = false
        var pouredBeforeArrival = false
        var hit = false
        while !hit, run.distance < 110 {
            let events = run.update(dt: TestRide.frame, targetX: 0)
            hit = events.contains(.hit)
            if !hit, let stream = run.streams.first {
                if stream.isVisible, !stream.isPouring { sawMarker = true }
                if stream.isPouring { pouredBeforeArrival = true }
            }
        }
        XCTAssertTrue(sawMarker)
        XCTAssertTrue(pouredBeforeArrival)
        XCTAssertTrue(hit)
    }

    func testStreamStillAMarkerCannotHurt() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 2, warningSeconds: 5))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives)
    }

    func testHitGivesBriefInvulnerabilityAndSlowdown() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 5, warning: 1))
        run.place(PissStream(baseX: 0, z: 8, warning: 1))
        let before = run.speed
        var events: [BikeEvent] = []
        while !events.contains(.hit) {
            events = run.update(dt: TestRide.frame, targetX: 0)
        }
        XCTAssertGreaterThan(run.invulnerable, 0)
        XCTAssertLessThan(run.speed, before)
        XCTAssertEqual(run.lives, RunLoadout.base.startingLives - 1)
        let (after, later) = TestRide.ride(run, seconds: 0.5) { _ in 0 }
        XCTAssertFalse(later.contains(.hit), "the second stream falls inside the safe time")
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives - 1)
    }

    func testRaincoatShowsTheMarkerEarlier() {
        let raincoat = RunLoadout(levels: [.raincoat: 6])
        XCTAssertGreaterThan(raincoat.warningSeconds, RunLoadout.base.warningSeconds)
        var plain = BikeRun(seed: 4)
        var covered = BikeRun(seed: 4, loadout: raincoat)
        _ = plain.update(dt: TestRide.frame, targetX: 0)
        _ = covered.update(dt: TestRide.frame, targetX: 0)
        XCTAssertGreaterThan(
            covered.streams.first?.warningSeconds ?? 0, plain.streams.first?.warningSeconds ?? 0
        )
    }

    func testMovingStreamsStayOnTheRoad() {
        let sway = PissStream(motion: .sway, baseX: 2.6, z: 10, phase: 0.3)
        let sweep = PissStream(motion: .sweep, baseX: 0, z: 10, phase: 0.3)
        var moved = false
        for step in 0..<400 {
            let time = Double(step) * 0.05
            XCTAssertLessThanOrEqual(abs(sway.x(atTime: time) - 2.6), PissStream.swayAmplitude + 0.0001)
            XCTAssertLessThanOrEqual(abs(sweep.x(atTime: time)), BikeRun.roadHalfWidth)
            if sweep.x(atTime: time) != sweep.x(atTime: 0) { moved = true }
        }
        XCTAssertTrue(moved)
    }
}

final class RoadLayoutTests: XCTestCase {
    private let roadEnd = 20000.0

    private func segments(seed: UInt64, loadout: RunLoadout = .base) -> [(z: Double, next: Double, road: RoadSegment)] {
        var generator = RoadGenerator(seed: seed, loadout: loadout)
        var result: [(z: Double, next: Double, road: RoadSegment)] = []
        while generator.nextZ < roadEnd {
            let z = generator.nextZ
            let road = generator.nextSegment()
            result.append((z: z, next: generator.nextZ, road: road))
        }
        return result
    }

    private func openLanes(_ row: [PissStream], atTime time: Double) -> [Double] {
        BikeRun.laneX.filter { lane in
            row.allSatisfy { abs($0.x(atTime: time) - lane) >= BikeRun.streamReach }
        }
    }

    func testLayoutDependsOnlyOnTheSeed() {
        var first = RoadGenerator(seed: 8, loadout: .base)
        var second = RoadGenerator(seed: 8, loadout: .base)
        for _ in 0..<300 {
            XCTAssertEqual(first.nextSegment(), second.nextSegment())
        }
    }

    func testEveryRowOfStreamsAlwaysLeavesALaneOpen() {
        for seed in UInt64(1)...8 {
            let streams = segments(seed: seed).flatMap { $0.road.streams }
            XCTAssertFalse(streams.isEmpty)
            for (_, row) in Dictionary(grouping: streams, by: { $0.rowId }) {
                XCTAssertLessThanOrEqual(row.count, 2)
                for step in 0..<60 {
                    let open = openLanes(row, atTime: Double(step) * 0.25)
                    XCTAssertFalse(open.isEmpty, "seed \(seed) row at \(row[0].z)")
                }
            }
        }
    }

    func testTrafficAndPilesLeaveALaneOpen() {
        for seed in UInt64(1)...8 {
            for entry in segments(seed: seed) {
                let vehicleLanes = Set(entry.road.vehicles.map { $0.x })
                XCTAssertEqual(vehicleLanes.count, entry.road.vehicles.count)
                XCTAssertLessThanOrEqual(entry.road.vehicles.count, 2)
                XCTAssertLessThanOrEqual(entry.road.piles.count, 2)
                for pile in entry.road.piles {
                    let touched = BikeRun.laneX.filter { abs($0 - pile.x) < BikeRun.pileReach }
                    XCTAssertEqual(touched.count, 1)
                }
                for vehicle in entry.road.vehicles {
                    let width = vehicle.kind.halfWidth + BikeRun.bikeHalfWidth
                    XCTAssertLessThan(width, BikeRun.laneX[2] - BikeRun.laneX[1])
                }
            }
        }
    }

    func testVehiclesNeverRollIntoTheNextObstacle() {
        for seed in UInt64(1)...8 {
            for entry in segments(seed: seed) {
                for vehicle in entry.road.vehicles {
                    XCTAssertLessThan(vehicle.limitZ + vehicle.kind.halfLength, entry.next, "seed \(seed)")
                    XCTAssertGreaterThanOrEqual(vehicle.z - vehicle.kind.halfLength, entry.z - 0.0001)
                }
            }
        }
    }

    func testObstaclesGetHarderWithEachDistrict() {
        var sawSway = false
        var sawSweep = false
        var sawDoubleRow = false
        for seed in UInt64(1)...6 {
            for entry in segments(seed: seed) {
                let rows = Set(entry.road.streams.map { $0.rowId })
                let motions = entry.road.streams.map { $0.motion }
                if motions.contains(.sway) {
                    XCTAssertGreaterThanOrEqual(entry.z, District.all[1].startDistance)
                    sawSway = true
                }
                if motions.contains(.sweep) {
                    XCTAssertGreaterThanOrEqual(entry.z, District.all[2].startDistance)
                    sawSweep = true
                }
                if rows.count > 1 {
                    XCTAssertGreaterThanOrEqual(entry.z, District.all[3].startDistance)
                    sawDoubleRow = true
                }
            }
        }
        XCTAssertTrue(sawSway)
        XCTAssertTrue(sawSweep)
        XCTAssertTrue(sawDoubleRow)
    }

    func testAllKindsOfObjectsAppear() {
        let road = segments(seed: 11) + segments(seed: 12) + segments(seed: 13)
        let vehicles = Set(road.flatMap { $0.road.vehicles }.map { $0.kind })
        XCTAssertEqual(vehicles, Set(VehicleKind.allCases))
        let pickups = Set(road.flatMap { $0.road.pickups }.map { $0.kind })
        XCTAssertEqual(pickups, Set(PickupKind.allCases))
        XCTAssertTrue(road.contains { !$0.road.piles.isEmpty })
        XCTAssertTrue(road.contains { $0.road.coins.contains { $0.isGolden } })
    }

    func testCoinPatternsDoNotOverlapAlongTheRoad() {
        let coinRuns = segments(seed: 5).map { $0.road.coins }.filter { !$0.isEmpty }
        XCTAssertGreaterThan(coinRuns.count, 50)
        for (earlier, later) in zip(coinRuns, coinRuns.dropFirst()) {
            XCTAssertLessThan(earlier.last?.z ?? 0, later.first?.z ?? 0)
        }
    }

    func testLuckBringsMorePickups() {
        let plain = segments(seed: 9).flatMap { $0.road.pickups }.count
        let lucky = segments(seed: 9, loadout: RunLoadout(levels: [.luck: 8])).flatMap { $0.road.pickups }.count
        XCTAssertGreaterThan(lucky, plain)
    }

    func testDistrictsByDistance() {
        XCTAssertGreaterThanOrEqual(District.all.count, 4)
        XCTAssertEqual(District.at(distance: 0).name, "Говнотаун")
        XCTAssertEqual(District.at(distance: -5).index, 0)
        for (index, district) in District.all.enumerated() {
            XCTAssertEqual(district.index, index)
            XCTAssertEqual(District.at(distance: district.startDistance).index, index)
        }
        for (easier, harder) in zip(District.all, District.all.dropFirst()) {
            XCTAssertLessThan(easier.startDistance, harder.startDistance)
            XCTAssertLessThan(harder.difficulty.gapSeconds, easier.difficulty.gapSeconds)
            XCTAssertLessThan(harder.difficulty.warningScale, easier.difficulty.warningScale)
            XCTAssertGreaterThan(harder.difficulty.twoLaneChance, easier.difficulty.twoLaneChance)
        }
    }

    func testRideAnnouncesEachDistrictOnce() {
        let (_, events) = TestRide.ride(BikeRun(seed: 6), seconds: 300) { $0.autopilotTarget() }
        let entered = events.compactMap { event -> Int? in
            if case .districtEntered(let index) = event { return index }
            return nil
        }
        XCTAssertEqual(entered, Array(1..<District.all.count))
    }
}
