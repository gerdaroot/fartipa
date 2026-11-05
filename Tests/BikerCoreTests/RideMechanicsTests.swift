import XCTest
import Foundation
@testable import BikerCore

final class TrafficAndPileTests: XCTestCase {
    /// A vehicle that stands still, so the arithmetic in these tests stays simple.
    private func parkedCar(x: Double, z: Double) -> Vehicle {
        Vehicle(kind: .car, x: x, z: z, limitZ: z)
    }

    func testCarInYourLaneCostsOneLifeOnce() {
        var run = TestRide.emptyRoad()
        run.place(parkedCar(x: 0, z: 30))
        let (after, events) = TestRide.ride(run, seconds: 4) { _ in 0 }
        XCTAssertEqual(events.filter { $0 == .hit }.count, 1)
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives - 1)
        XCTAssertTrue(after.vehicles.first?.isWrecked ?? true)
    }

    func testCarInAnotherLaneIsPassedSafely() {
        var run = TestRide.emptyRoad()
        run.place(parkedCar(x: 2.6, z: 30))
        let (after, events) = TestRide.ride(run, seconds: 2) { _ in 0 }
        XCTAssertFalse(events.contains(.hit))
        XCTAssertFalse(events.contains(.nearMiss), "a whole lane away is not close")
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives)
    }

    func testVehicleDrivesWhenRiderIsCloseAndBrakesAtItsLimit() {
        var run = TestRide.emptyRoad()
        run.place(Vehicle(kind: .truck, x: 2.6, z: 200, limitZ: 230))
        _ = run.update(dt: TestRide.frame, targetX: 0)
        XCTAssertEqual(run.vehicles[0].z, 200, "too far away to move yet")
        let (after, _) = TestRide.ride(run, seconds: 8) { _ in 0 }
        XCTAssertGreaterThan(after.vehicles[0].z, 200)
        XCTAssertLessThanOrEqual(after.vehicles[0].z, 230)
    }

    func testPileSkidsWithoutLosingALife() {
        var run = TestRide.emptyRoad()
        run.place(PoopPile(x: 0, z: 20))
        let cruising = run.speed
        var events: [BikeEvent] = []
        while !events.contains(.skid), run.distance < 40 {
            events = run.update(dt: TestRide.frame, targetX: 0)
        }
        XCTAssertTrue(events.contains(.skid))
        XCTAssertTrue(run.isSkidding)
        XCTAssertLessThan(run.speed, cruising)
        XCTAssertEqual(run.speed, run.cruisingSpeed * RunLoadout.base.skidSpeedFactor, accuracy: 0.001)
        XCTAssertEqual(run.lives, RunLoadout.base.startingLives)
        XCTAssertEqual(run.invulnerable, 0)
        let (after, _) = TestRide.ride(run, seconds: RunLoadout.base.skidSeconds + 0.1) { _ in 0 }
        XCTAssertFalse(after.isSkidding)
        XCTAssertEqual(after.speed, after.cruisingSpeed, accuracy: 0.001)
    }

    func testBetterTiresSkidLess() {
        let tires = RunLoadout(levels: [.tires: 6])
        var run = TestRide.emptyRoad(loadout: tires)
        run.place(PoopPile(x: 0, z: 10))
        var events: [BikeEvent] = []
        while !events.contains(.skid), run.distance < 20 {
            events = run.update(dt: TestRide.frame, targetX: 0)
        }
        XCTAssertEqual(run.speed, run.cruisingSpeed * tires.skidSpeedFactor, accuracy: 0.001)
        XCTAssertGreaterThan(tires.skidSpeedFactor, RunLoadout.base.skidSpeedFactor)
    }
}

final class CoinAndPickupTests: XCTestCase {
    func testCoinInReachIsWorthOneAndFarCoinIsLeft() {
        var run = TestRide.emptyRoad()
        run.place(RoadCoin(x: 0, z: 5))
        run.place(RoadCoin(x: 3, z: 6))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertEqual(events.filter { $0 == .coin }.count, 1)
        XCTAssertEqual(after.coins, 1)
    }

    func testGoldenCoinIsWorthTen() {
        var run = TestRide.emptyRoad()
        run.place(RoadCoin(x: 0, z: 5, isGolden: true))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertEqual(events.filter { $0 == .goldenCoin }.count, 1)
        XCTAssertEqual(after.coins, 10)
        XCTAssertEqual(after.summary.goldenCoins, 1)
    }

    func testPiggyBankMultipliesCoins() {
        var run = TestRide.emptyRoad(loadout: RunLoadout(levels: [.piggy: 10]))
        run.place(RoadCoin(x: 0, z: 5))
        run.place(RoadCoin(x: 0, z: 6, isGolden: true))
        let (after, _) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertEqual(after.coins, 22)
    }

    func testDoublerDoublesCoins() {
        var run = TestRide.emptyRoad()
        run.place(RoadPickup(kind: .coinDoubler, x: 0, z: 5))
        run.place(RoadCoin(x: 0, z: 10))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertTrue(events.contains(.pickup(.coinDoubler)))
        XCTAssertEqual(after.coins, 2)
    }

    func testMagnetPullsCoinsFromAcrossTheRoad() {
        var run = TestRide.emptyRoad()
        run.place(RoadPickup(kind: .magnet, x: 0, z: 5))
        run.place(RoadCoin(x: 3, z: 15))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertTrue(events.contains(.pickup(.magnet)))
        XCTAssertEqual(after.coins, 1)
        XCTAssertGreaterThan(after.powerUps.magnet, 0)
    }

    func testShieldEatsABlowAndIsSpent() {
        var run = TestRide.emptyRoad()
        run.place(RoadPickup(kind: .shield, x: 0, z: 5))
        run.place(PissStream(baseX: 0, z: 15, warning: 1))
        let (after, events) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertTrue(events.contains(.shieldBlocked))
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives)
        XCTAssertEqual(after.powerUps.shield, 0)
    }

    func testShieldRunsOutWithTime() {
        var run = TestRide.emptyRoad()
        run.place(RoadPickup(kind: .shield, x: 0, z: 5))
        let (after, _) = TestRide.ride(run, seconds: RunLoadout.base.shieldSeconds + 1) { _ in 0 }
        XCTAssertEqual(after.powerUps.shield, 0)
    }

    func testRepairAddsALifeUpToTheCap() {
        var run = TestRide.emptyRoad()
        for index in 1...5 {
            run.place(RoadPickup(kind: .repair, x: 0, z: Double(index) * 4))
        }
        let (after, events) = TestRide.ride(run, seconds: 2) { _ in 0 }
        XCTAssertEqual(events.filter { $0 == .pickup(.repair) }.count, 5)
        XCTAssertEqual(after.lives, after.maxLives)
        XCTAssertEqual(after.maxLives, RunLoadout.base.startingLives + BikeRun.extraLivesCap)
    }

    func testBoostRefillFillsTheTank() {
        var run = TestRide.emptyRoad()
        XCTAssertLessThan(run.boostFraction, 1)
        run.place(RoadPickup(kind: .boostRefill, x: 0, z: 5))
        let (after, _) = TestRide.ride(run, seconds: 1) { _ in 0 }
        XCTAssertEqual(after.boostFraction, 1, accuracy: 0.0001)
    }
}

final class BoostTests: XCTestCase {
    func testBoostStartsRaisesSpeedDrainsAndEnds() {
        var run = TestRide.emptyRoad()
        let plainSpeed = run.speed
        XCTAssertTrue(run.canBoost)
        XCTAssertTrue(run.activateBoost())
        XCTAssertTrue(run.isBoosting)
        XCTAssertFalse(run.activateBoost(), "already on")
        let first = run.update(dt: TestRide.frame, targetX: 0)
        XCTAssertEqual(first.filter { $0 == .boostStart }.count, 1)
        XCTAssertGreaterThan(run.speed, plainSpeed * 1.5)
        let charge = run.boostCharge
        let (after, events) = TestRide.ride(run, seconds: charge + 0.1) { _ in 0 }
        XCTAssertEqual(events.filter { $0 == .boostEnd }.count, 1)
        XCTAssertFalse(after.isBoosting)
        XCTAssertEqual(after.boostCharge, 0)
        XCTAssertEqual(after.speed, after.cruisingSpeed, accuracy: 0.001)
        XCTAssertEqual(after.summary.boosts, 1)
    }

    func testCannotBoostOnAnEmptyTank() {
        var run = TestRide.emptyRoad()
        run.activateBoost()
        var (after, _) = TestRide.ride(run, seconds: 2) { _ in 0 }
        XCTAssertFalse(after.canBoost)
        XCTAssertFalse(after.activateBoost())
        XCTAssertFalse(after.update(dt: TestRide.frame, targetX: 0).contains(.boostStart))
    }

    func testBoostRamsTrafficWithoutLosingALife() {
        var run = TestRide.emptyRoad()
        run.place(Vehicle(kind: .truck, x: 0, z: 15, limitZ: 15))
        run.activateBoost()
        let (after, events) = TestRide.ride(run, seconds: 0.8) { _ in 0 }
        XCTAssertTrue(events.contains(.vehicleSmashed(.truck)))
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.lives, RunLoadout.base.startingLives)
        XCTAssertEqual(after.summary.vehiclesSmashed, 1)
        XCTAssertEqual(after.bonusScoreForTests, BikeRun.smashScore)
    }

    func testBoostDoesNotStopPiss() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 15, warning: 1))
        run.activateBoost()
        let (after, events) = TestRide.ride(run, seconds: 0.8) { _ in 0 }
        XCTAssertTrue(events.contains(.hit))
        XCTAssertTrue(events.contains(.boostEnd))
        XCTAssertFalse(after.isBoosting)
    }

    func testCoinsFillTheTankAndGoldenFillsMore() {
        var run = TestRide.emptyRoad()
        let start = run.boostCharge
        XCTAssertEqual(start, RunLoadout.base.boostCapacity / 3, accuracy: 0.0001)
        run.place(RoadCoin(x: 0, z: 5))
        let afterPlain = TestRide.ride(run, seconds: 0.5) { _ in 0 }.run
        XCTAssertEqual(afterPlain.boostCharge, start + RunLoadout.base.boostPerCoin, accuracy: 0.0001)

        var goldenRun = TestRide.emptyRoad()
        goldenRun.place(RoadCoin(x: 0, z: 5, isGolden: true))
        let afterGolden = TestRide.ride(goldenRun, seconds: 0.5) { _ in 0 }.run
        XCTAssertGreaterThan(afterGolden.boostCharge, afterPlain.boostCharge)
    }

    func testBeansFillFaster() {
        let beans = RunLoadout(levels: [.beans: 8])
        var run = TestRide.emptyRoad(loadout: beans)
        let start = run.boostCharge
        run.place(RoadCoin(x: 0, z: 5))
        let after = TestRide.ride(run, seconds: 0.5) { _ in 0 }.run
        XCTAssertEqual(after.boostCharge, start + beans.boostPerCoin, accuracy: 0.0001)
        XCTAssertGreaterThan(beans.boostPerCoin, RunLoadout.base.boostPerCoin)
    }

    func testBoostEventsCannotHappenAfterTheEnd() {
        let (run, events) = TestRide.ride(BikeRun(seed: 3), seconds: 600) { _ in 0 }
        XCTAssertTrue(run.isOver)
        XCTAssertEqual(events.last, .gameOver)
        XCTAssertEqual(events.filter { $0 == .gameOver }.count, 1)
    }
}

final class ComboTests: XCTestCase {
    func testNearMissOfStreamRaisesComboAndScore() {
        var run = TestRide.emptyRoad()
        XCTAssertEqual(run.combo, 1)
        run.place(PissStream(baseX: 0, z: 30, warning: 1))
        let (after, events) = TestRide.ride(run, seconds: 2) { _ in 2.0 }
        XCTAssertEqual(events.filter { $0 == .nearMiss }.count, 1)
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.combo, 2)
        XCTAssertEqual(after.score, Int(after.distance) + BikeRun.nearMissScore * 2)
        XCTAssertEqual(after.summary.nearMisses, 1)
        XCTAssertEqual(after.summary.bestCombo, 2)
    }

    func testNearMissOfVehicleCounts() {
        var run = TestRide.emptyRoad()
        run.place(Vehicle(kind: .car, x: 0, z: 30, limitZ: 30))
        let (after, events) = TestRide.ride(run, seconds: 2) { _ in 2.0 }
        XCTAssertEqual(events.filter { $0 == .nearMiss }.count, 1)
        XCTAssertFalse(events.contains(.hit))
        XCTAssertEqual(after.combo, 2)
    }

    func testAWholeLaneAwayIsNotANearMiss() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 30, warning: 1))
        let (_, events) = TestRide.ride(run, seconds: 2) { _ in 2.6 }
        XCTAssertFalse(events.contains(.nearMiss))
    }

    func testComboStacksAndIsCapped() {
        var meter = ComboMeter(window: 3)
        for _ in 0..<20 { meter.registerNearMiss() }
        XCTAssertEqual(meter.combo, ComboMeter.highest)
    }

    func testComboDecaysOneStepPerWindow() {
        var meter = ComboMeter(window: 3)
        meter.registerNearMiss()
        meter.registerNearMiss()
        XCTAssertEqual(meter.combo, 3)
        XCTAssertEqual(meter.fraction, 1, accuracy: 0.0001)
        meter.decay(dt: 2.9)
        XCTAssertEqual(meter.combo, 3)
        meter.decay(dt: 0.2)
        XCTAssertEqual(meter.combo, 2)
        meter.decay(dt: 3.1)
        XCTAssertEqual(meter.combo, 1)
        XCTAssertEqual(meter.fraction, 0)
        meter.decay(dt: 100)
        XCTAssertEqual(meter.combo, 1)
    }

    func testRideComboDropsAfterItsWindow() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 10, warning: 1))
        let passed = TestRide.ride(run, seconds: 1) { _ in 2.0 }.run
        XCTAssertEqual(passed.combo, 2)
        XCTAssertGreaterThan(passed.comboFraction, 0)
        let later = TestRide.ride(passed, seconds: RunLoadout.base.comboSeconds) { _ in 2.0 }.run
        XCTAssertEqual(later.combo, 1)
    }

    func testComboUpgradeHoldsItLonger() {
        let loadout = RunLoadout(levels: [.combo: 6])
        XCTAssertGreaterThan(loadout.comboSeconds, RunLoadout.base.comboSeconds)
        var run = TestRide.emptyRoad(loadout: loadout)
        run.place(PissStream(baseX: 0, z: 10, warning: 1))
        let passed = TestRide.ride(run, seconds: 1) { _ in 2.0 }.run
        let later = TestRide.ride(passed, seconds: RunLoadout.base.comboSeconds) { _ in 2.0 }.run
        XCTAssertEqual(later.combo, 2)
    }

    func testHitResetsCombo() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 15, warning: 1))
        let passed = TestRide.ride(run, seconds: 1) { _ in 2.0 }.run
        XCTAssertEqual(passed.combo, 2)
        var next = passed
        next.place(PissStream(baseX: passed.x, z: passed.distance + 3, warning: 1))
        let (after, events) = TestRide.ride(next, seconds: 0.5) { _ in passed.x }
        XCTAssertTrue(events.contains(.hit))
        XCTAssertEqual(after.combo, 1)
    }

    func testComboMultipliesCoinScore() {
        var run = TestRide.emptyRoad()
        run.place(PissStream(baseX: 0, z: 10, warning: 1))
        let passed = TestRide.ride(run, seconds: 1) { _ in 2.0 }.run
        XCTAssertEqual(passed.combo, 2)
        let scoreBefore = passed.score - Int(passed.distance)
        var next = passed
        next.place(RoadCoin(x: passed.x, z: passed.distance + 2))
        let after = TestRide.ride(next, seconds: 0.3) { _ in 2.0 }.run
        XCTAssertEqual(after.score - Int(after.distance), scoreBefore + BikeRun.coinScore * 2)
    }
}

extension BikeRun {
    /// The bonus part of the score, on a road with no coins.
    fileprivate var bonusScoreForTests: Int { score - Int(distance) }
}
