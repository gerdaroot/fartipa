import XCTest
import Foundation
@testable import BikerCore

// Numbers worked out by hand: at the start the bike does 22 m/s, so a hop (0.62 s) covers
// about 13.6 m of road and a ramp flight (1.3 s) about 28.6 m.

final class HopTests: XCTestCase {
    func testHopClearsAPileWithoutSkidding() {
        var run = TestRide.emptyRoad()
        run.place(PoopPile(x: 0, z: 10))
        XCTAssertTrue(run.jump())
        let (after, events, moments) = TestRide.rideWithMoments(run, seconds: 1) { _ in 0 }
        XCTAssertFalse(events.contains(.skid))
        XCTAssertFalse(after.isSkidding)
        XCTAssertEqual(after.summary.pilesJumped, 1)
        XCTAssertEqual(after.summary.hops, 1)
        XCTAssertTrue(moments.contains(.pileCleared))
        XCTAssertEqual(moments.first, .jumped)
    }

    /// 19 frames is 0.317 s, just past the top at 0.31 s: 4 × 1.5 × 0.511 × 0.489 ≈ 1.499 m.
    func testHopGoesUpAndComesDown() {
        var run = TestRide.emptyRoad()
        XCTAssertEqual(run.airHeight, 0)
        run.jump()
        let middle = TestRide.ride(run, seconds: AirMeter.hopSeconds / 2) { _ in 0 }.run
        XCTAssertTrue(middle.isAirborne)
        XCTAssertEqual(middle.airHeight, AirMeter.hopHeight, accuracy: 0.05)
        let (landed, _, moments) = TestRide.rideWithMoments(middle, seconds: AirMeter.hopSeconds) { _ in 0 }
        XCTAssertFalse(landed.isAirborne)
        XCTAssertEqual(landed.airHeight, 0)
        XCTAssertTrue(moments.contains { moment in
            if case .landed(let landing) = moment { return landing.kind == .hop }
            return false
        })
    }

    func testHopHasACooldown() {
        var run = TestRide.emptyRoad()
        XCTAssertTrue(run.canJump)
        XCTAssertTrue(run.jump())
        XCTAssertFalse(run.jump(), "already in the air")
        var later = TestRide.ride(run, seconds: 0.7) { _ in 0 }.run
        XCTAssertFalse(later.isAirborne)
        XCTAssertFalse(later.canJump, "landed, but 0.6 s of the 1.3 s cooldown are left")
        XCTAssertFalse(later.jump())
        XCTAssertLessThan(later.jumpReadiness, 1)
        var ready = TestRide.ride(later, seconds: 0.7) { _ in 0 }.run
        XCTAssertEqual(ready.jumpReadiness, 1)
        XCTAssertTrue(ready.jump())
    }

    /// The car's rear (9.8 m) comes at 0.45 s, still in the hop, but a hop is too low for a car.
    func testHopIsTooLowForACar() {
        var run = TestRide.emptyRoad()
        run.place(Vehicle(kind: .car, x: 0, z: 12, limitZ: 12))
        run.jump()
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertTrue(events.contains(.hit))
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives - 1)
    }

    func testStreamsHitInTheAirToo() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 8, warning: 1))
        run.jump()
        let (_, events) = TestRide.ride(run, seconds: 0.6) { _ in 0 }
        XCTAssertTrue(events.contains(.hit))
    }

    func testMomentsLastOneFrame() {
        var run = TestRide.emptyRoad()
        run.jump()
        _ = run.update(dt: TestRide.frame, targetX: 0)
        XCTAssertEqual(run.moments, [.jumped])
        _ = run.update(dt: TestRide.frame, targetX: 0)
        XCTAssertEqual(run.moments, [])
    }

    func testNoJumpAfterTheEnd() {
        var (run, _) = TestRide.ride(BikeRun(seed: 3), seconds: 600) { _ in 0 }
        XCTAssertTrue(run.isOver)
        XCTAssertFalse(run.canJump)
        XCTAssertFalse(run.jump())
    }
}

final class ManholeTests: XCTestCase {
    /// Phase 0: a geyser spouts for the first 0.9 s of every 1.8 s; the bike gets to z 10 at ~0.45 s.
    func testSpoutingGeyserCostsALife() {
        var run = TestRide.emptyRoad()
        run.place(Manhole(kind: .geyser, baseX: 0, z: 10, phase: 0))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertTrue(events.contains(.hit))
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives - 1)
    }

    func testHopClearsASpoutingGeyser() {
        var run = TestRide.emptyRoad()
        run.place(Manhole(kind: .geyser, baseX: 0, z: 10, phase: 0))
        run.jump()
        let (after, events, moments) = TestRide.rideWithMoments(run, seconds: 1) { _ in 0 }
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.summary.hazardsJumped, 1)
        XCTAssertTrue(moments.contains(.hazardCleared(.geyser)))
    }

    /// Phase 0.5: at 0.45 s the cycle is at 0.75, in the resting half.
    func testRestingGeyserIsSafe() {
        var run = TestRide.emptyRoad()
        run.place(Manhole(kind: .geyser, baseX: 0, z: 10, phase: 0.5))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.summary.hazardsJumped, 0)
    }

    func testGeyserCycle() {
        let geyser = Manhole(kind: .geyser, baseX: 2.6, z: 0, phase: 0)
        XCTAssertTrue(geyser.isDangerous(atTime: 0.1))
        XCTAssertFalse(geyser.isDangerous(atTime: 1.0))
        XCTAssertTrue(geyser.isDangerous(atTime: 1.9))
        XCTAssertEqual(geyser.x(atTime: 5), 2.6)
    }

    /// Phase 0: the lid is at 3 × sin(1.25 × 0.45) ≈ 1.6 m when the bike gets to z 10.
    func testRollingLidHitsWhereItRolls() {
        var run = TestRide.emptyRoad()
        run.place(Manhole(kind: .rollingLid, baseX: 0, z: 10, phase: 0))
        let (_, events) = TestRide.ride(run, seconds: 1) { _ in 1.6 }
        XCTAssertTrue(events.contains(.hit))
        var other = TestRide.emptyRoad()
        other.place(Manhole(kind: .rollingLid, baseX: 0, z: 10, phase: 0))
        let (_, missed) = TestRide.ride(other, seconds: 1) { _ in -2.6 }
        XCTAssertFalse(missed.contains(.hit))
    }

    func testRollingLidStaysOnTheRoadAndLeavesALane() {
        let lid = Manhole(kind: .rollingLid, baseX: 0, z: 0, phase: 0.2)
        var moved = false
        for step in 0..<400 {
            let x = lid.x(atTime: Double(step) * 0.05)
            XCTAssertLessThanOrEqual(abs(x), BikeRun.roadHalfWidth)
            let blocked = BikeRun.laneX.filter { abs($0 - x) < ManholeKind.rollingLid.reach }
            XCTAssertLessThanOrEqual(blocked.count, 1)
            if x != lid.x(atTime: 0) { moved = true }
        }
        XCTAssertTrue(moved)
    }

    /// Geysers in all three lanes, spouting when the bike arrives (phase 0.3: at 1.36 s the cycle is
    /// at 0.06). The careful rider cannot steer round them, so it must hop.
    func testAutopilotHopsWhatItCannotDodge() {
        var run = TestRide.emptyRoad()
        for lane in BikeRun.laneX {
            run.place(Manhole(kind: .geyser, baseX: lane, z: 30, phase: 0.3))
        }
        let (after, events) = TestRide.autopilot(run, seconds: 2.5)
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.summary.hazardsJumped, 1)
    }
}

final class RampTests: XCTestCase {
    private let flightBonus = Int(AirMeter.rampSeconds * BikeRun.airScorePerSecond)

    /// The ramp lip at 5 m is crossed at 0.23 s; the flight lasts to ~1.53 s (about z 33.6), so the
    /// parked car at 17.8...22.2 m passes underneath.
    func testRampLaunchesOverTraffic() {
        var run = TestRide.emptyRoad()
        run.place(RoadRamp(x: 0, z: 5))
        run.place(Vehicle(kind: .car, x: 0, z: 20, limitZ: 20))
        let (after, events, moments) = TestRide.rideWithMoments(run, seconds: 2) { _ in 0 }
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives)
        XCTAssertEqual(after.summary.rampJumps, 1)
        XCTAssertEqual(after.summary.vehiclesVaulted, 1)
        XCTAssertTrue(moments.contains(.rampLaunch))
        XCTAssertTrue(moments.contains(.vaulted(.car)))
        XCTAssertFalse(after.isAirborne)
        XCTAssertEqual(after.score - Int(after.distance), BikeRun.vaultScore + flightBonus)
    }

    func testRampFlightIsHighAndLong() {
        var run = TestRide.emptyRoad()
        run.place(RoadRamp(x: 0, z: 5))
        let launched = ride(run, untilRampAir: true)
        XCTAssertTrue(launched.isAirborne)
        let top = TestRide.ride(launched, seconds: AirMeter.rampSeconds / 2) { _ in 0 }.run
        XCTAssertGreaterThan(top.airHeight, AirMeter.rampHeight - 0.1)
        XCTAssertGreaterThan(top.airHeight, AirMeter.hopHeight * 2)
    }

    func testMissingTheRampMeansNoFlight() {
        var run = TestRide.emptyRoad()
        run.place(RoadRamp(x: 2.6, z: 5))
        let (after, _) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertEqual(after.summary.rampJumps, 0)
        XCTAssertFalse(after.isAirborne)
    }

    /// A clean flip: 250 × combo, and the flip itself lifts the combo from 1 to 2: 130 + 500.
    func testSwipeInTheAirIsAFlip() {
        var run = TestRide.emptyRoad()
        run.place(RoadRamp(x: 0, z: 5))
        var flying = ride(run, untilRampAir: true)
        XCTAssertTrue(flying.canJump)
        XCTAssertTrue(flying.jump())
        XCTAssertFalse(flying.jump(), "one flip at a time")
        let (after, events, moments) = TestRide.rideWithMoments(flying, seconds: 2) { _ in 0 }
        XCTAssertFalse(events.contains(.skid))
        XCTAssertEqual(after.summary.flips, 1)
        XCTAssertEqual(after.combo, 2)
        XCTAssertEqual(after.score - Int(after.distance), flightBonus + BikeRun.flipScore * 2)
        XCTAssertTrue(moments.contains(.flipStarted))
    }

    /// A flip started with less than its 0.55 s left lands half-way round: no score, a skid.
    func testLateFlipIsBotched() {
        var run = TestRide.emptyRoad()
        run.place(RoadRamp(x: 0, z: 5))
        var late = ride(run, untilRampAir: true)
        while late.air.elapsed < AirMeter.rampSeconds - 0.3 {
            _ = late.update(dt: TestRide.frame, targetX: 0)
        }
        XCTAssertTrue(late.jump())
        let (after, events) = TestRide.ride(late, seconds: 1) { _ in 0 }
        XCTAssertTrue(events.contains(.skid))
        XCTAssertEqual(after.summary.flips, 0)
        XCTAssertEqual(after.summary.skids, 1)
        XCTAssertEqual(after.score - Int(after.distance), 0)
    }

    /// At z 15 the bike is 0.45 s into the flight: 4 × 3.6 × 0.35 × 0.65 ≈ 3.3 m up.
    func testCoinsInTheAirNeedTheRamp() {
        var ground = TestRide.emptyRoad()
        ground.place(RoadCoin(x: 0, z: 15, lift: 3))
        XCTAssertEqual(TestRide.ride(ground, seconds: 1) { _ in 0 }.run.coins, 0)
        var flying = TestRide.emptyRoad()
        flying.place(RoadRamp(x: 0, z: 5))
        flying.place(RoadCoin(x: 0, z: 15, lift: 3))
        XCTAssertEqual(TestRide.ride(flying, seconds: 1) { _ in 0 }.run.coins, 1)
    }

    private func ride(_ start: BikeRun, untilRampAir: Bool) -> BikeRun {
        var run = start
        var frames = 0
        while run.air.kind != .ramp, frames < 120 {
            _ = run.update(dt: TestRide.frame, targetX: 0)
            frames += 1
        }
        return run
    }
}
