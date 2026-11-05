import XCTest
import Foundation
@testable import PoopCore

final class BikeRunTests: XCTestCase {
    private let frame = 1.0 / 60

    private func ride(seed: UInt64, seconds: Double, steer: (BikeRun) -> Double) -> (BikeRun, [BikeEvent]) {
        var run = BikeRun(seed: seed)
        var events: [BikeEvent] = []
        var elapsed = 0.0
        while elapsed < seconds, !run.isOver {
            events += run.update(dt: frame, targetX: steer(run))
            elapsed += frame
        }
        return (run, events)
    }

    func testCarefulRiderSurvivesFiveMinutesOnEverySeed() {
        for seed in UInt64(1)...12 {
            let (run, events) = ride(seed: seed, seconds: 300) { $0.autopilotTarget() }
            XCTAssertFalse(events.contains(.hit), "seed \(seed) hit at \(Int(run.distance)) m")
            XCTAssertGreaterThan(run.coins, 50, "seed \(seed)")
            XCTAssertEqual(run.speed, BikeRun.topSpeed, accuracy: 0.01)
        }
    }

    func testRiderWhoNeverSteersEventuallyLoses() {
        let (run, events) = ride(seed: 3, seconds: 600) { _ in 0 }
        XCTAssertTrue(run.isOver)
        XCTAssertEqual(events.filter { $0 == .hit }.count, BikeRun.startingLives)
        XCTAssertEqual(events.last, .gameOver)
        XCTAssertEqual(run.lives, 0)
    }

    func testNoRowBlocksAllThreeLanes() {
        var run = BikeRun(seed: 9)
        for _ in 0..<(60 * 240) {
            _ = run.update(dt: frame, targetX: run.autopilotTarget())
            let rows = Dictionary(grouping: run.streams) { Int($0.z) }
            for (_, row) in rows {
                XCTAssertLessThanOrEqual(row.count, 2)
            }
        }
    }

    func testHitGivesBriefInvulnerabilityAndSlowdown() {
        var run = BikeRun(seed: 3)
        var hit = false
        var before = 0.0
        while !hit, !run.isOver {
            before = run.speed
            hit = run.update(dt: frame, targetX: 0).contains(.hit)
        }
        XCTAssertTrue(hit)
        XCTAssertGreaterThan(run.invulnerable, 0)
        XCTAssertLessThan(run.speed, before)
        XCTAssertEqual(run.lives, BikeRun.startingLives - 1)
    }

    func testEachCoinCountsOnce() {
        let (run, events) = ride(seed: 5, seconds: 60) { $0.autopilotTarget() }
        XCTAssertEqual(events.filter { $0 == .coin }.count, run.coins)
        XCTAssertGreaterThan(run.coins, 0)
        XCTAssertEqual(run.score, Int(run.distance) + run.coins * 5)
    }

    func testBikeStaysOnRoadAndCannotTeleport() {
        var run = BikeRun(seed: 1)
        _ = run.update(dt: 0.1, targetX: 100)
        XCTAssertEqual(run.x, 1.2, accuracy: 0.001)
        for _ in 0..<200 { _ = run.update(dt: frame, targetX: 100) }
        XCTAssertLessThan(run.x, BikeRun.roadHalfWidth)
    }

    func testFinishedRunStopsChanging() {
        var (run, _) = ride(seed: 3, seconds: 600) { _ in 0 }
        let distance = run.distance
        XCTAssertEqual(run.update(dt: 1, targetX: 0), [])
        XCTAssertEqual(run.distance, distance)
    }

    func testOldObjectsAreRemoved() {
        let (run, _) = ride(seed: 2, seconds: 120) { $0.autopilotTarget() }
        XCTAssertLessThan(run.streams.count + run.pickups.count, 200)
        XCTAssertTrue(run.pickups.allSatisfy { $0.z >= run.distance - 12 })
    }
}

final class ShopTests: XCTestCase {
    private let sport = Shop.item(id: "sport")!
    private let rusty = Shop.item(id: "rusty")!
    private let king = Shop.item(id: "king")!

    func testStartingKitIsFreeAndSelected() {
        let profile = Profile()
        XCTAssertTrue(profile.owns(rusty))
        XCTAssertTrue(profile.isSelected(rusty))
        XCTAssertEqual(profile.coins, 0)
    }

    func testCannotBuyWithoutCoins() {
        var profile = Profile()
        profile.earn(sport.price - 1)
        XCTAssertEqual(profile.buy(sport), .notEnoughCoins)
        XCTAssertFalse(profile.owns(sport))
        XCTAssertEqual(profile.coins, sport.price - 1)
    }

    func testBuyingSpendsCoinsOnce() {
        var profile = Profile()
        profile.earn(sport.price + 5)
        XCTAssertEqual(profile.buy(sport), .bought)
        XCTAssertEqual(profile.coins, 5)
        XCTAssertEqual(profile.buy(sport), .alreadyOwned)
        XCTAssertEqual(profile.coins, 5)
    }

    func testCannotSelectWhatYouDoNotOwn() {
        var profile = Profile()
        profile.select(king)
        XCTAssertEqual(profile.riderId, "leather")
        profile.earn(king.price)
        _ = profile.buy(king)
        profile.select(king)
        XCTAssertEqual(profile.riderId, "king")
        XCTAssertEqual(profile.bikeId, "rusty")
    }

    func testRoundTripsThroughStorage() {
        var profile = Profile()
        profile.earn(500)
        _ = profile.buy(sport)
        profile.select(sport)
        _ = profile.recordScore(1234)
        XCTAssertEqual(Profile.parse(profile.encoded()), profile)
    }

    func testBrokenSavesFallBackSafely() {
        XCTAssertEqual(Profile.parse(nil), Profile())
        XCTAssertEqual(Profile.parse(Data("junk".utf8)), Profile())
        let cheat = "{\"coins\":-50,\"bestScore\":1,\"owned\":[\"nope\"],\"bikeId\":\"king\",\"riderId\":\"king\"}"
        let parsed = Profile.parse(Data(cheat.utf8))
        XCTAssertEqual(parsed.coins, 0)
        XCTAssertEqual(parsed.bikeId, "rusty")
        XCTAssertEqual(parsed.riderId, "leather")
        XCTAssertFalse(parsed.owned.contains("nope"))
    }

    func testRecordOnlyGoesUp() {
        var profile = Profile()
        XCTAssertTrue(profile.recordScore(10))
        XCTAssertFalse(profile.recordScore(5))
        XCTAssertEqual(profile.bestScore, 10)
    }

    func testOnlyNewStarsPay() {
        XCTAssertEqual(Shop.starReward(oldStars: 0, newStars: 3), 3 * Shop.coinsPerStar)
        XCTAssertEqual(Shop.starReward(oldStars: 2, newStars: 3), Shop.coinsPerStar)
        XCTAssertEqual(Shop.starReward(oldStars: 3, newStars: 1), 0)
    }

    func testCatalogIdsAreUnique() {
        XCTAssertEqual(Set(Shop.all.map(\.id)).count, Shop.all.count)
    }
}

final class EngineSoundTests: XCTestCase {
    func testEngineIsBoundedAndSilentWhenOff() {
        var engine = EngineGenerator(sampleRate: 44100)
        var buffer = [Float](repeating: 1, count: 4096)
        buffer.withUnsafeMutableBufferPointer { engine.fill($0, level: 0, rev: 0) }
        XCTAssertTrue(buffer.allSatisfy { abs($0) < 0.0001 })
        buffer.withUnsafeMutableBufferPointer { engine.fill($0, level: 0.3, rev: 1) }
        XCTAssertTrue(buffer.allSatisfy { $0.isFinite && abs($0) <= 1 })
        XCTAssertTrue(buffer.contains { abs($0) > 0.01 })
    }

    func testCoinSoundFadesOut() {
        let samples = Synth.coin(sampleRate: 44100)
        XCTAssertGreaterThan(samples.count, 1000)
        XCTAssertLessThan(abs(samples.last!), 0.01)
    }
}
