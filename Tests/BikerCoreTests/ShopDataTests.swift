import XCTest
import Foundation
@testable import BikerCore

private func hasCyrillic(_ text: String) -> Bool {
    text.unicodeScalars.contains { $0.value >= 0x0400 && $0.value <= 0x04FF }
}

final class UpgradeTests: XCTestCase {
    func testThereAreEnoughTracksWithRussianTexts() {
        XCTAssertGreaterThanOrEqual(UpgradeTrack.allCases.count, 10)
        let names = UpgradeTrack.allCases.map { $0.info.name }
        XCTAssertEqual(Set(names).count, names.count)
        for track in UpgradeTrack.allCases {
            XCTAssertTrue(hasCyrillic(track.info.name), track.rawValue)
            XCTAssertTrue(hasCyrillic(track.info.description), track.rawValue)
            XCTAssertGreaterThanOrEqual(track.info.maxLevel, 5, track.rawValue)
            XCTAssertLessThanOrEqual(track.info.maxLevel, 10, track.rawValue)
            XCTAssertFalse(track.effectText(level: 1).isEmpty)
        }
    }

    func testPricesEscalate() {
        for track in UpgradeTrack.allCases {
            var previous = 0
            for level in 1...track.info.maxLevel {
                let price = track.price(ofLevel: level) ?? 0
                XCTAssertGreaterThan(price, previous, "\(track.rawValue) level \(level)")
                previous = price
            }
            XCTAssertNil(track.price(ofLevel: 0))
            XCTAssertNil(track.price(ofLevel: track.info.maxLevel + 1))
        }
    }

    func testFirstUpgradeIsWithinOneRideAndEverythingTakesManyRides() {
        let cheapest = UpgradeTrack.allCases.compactMap { $0.price(ofLevel: 1) }.min() ?? 0
        XCTAssertLessThanOrEqual(cheapest, 100)
        let total = UpgradeTrack.totalPriceOfEverything
        XCTAssertGreaterThan(total / 300, 100, "more than a hundred rides at the upper end of a ride's pay")
        XCTAssertLessThan(total / 100, 1000, "but not a thousand rides at the lower end")
    }

    func testEachTrackImprovesItsMetricAndNothingElse() {
        for track in UpgradeTrack.allCases {
            var previous = track.effectValue(level: 0)
            XCTAssertEqual(previous, RunLoadout.base[keyPath: track.keyMetric])
            for level in 1...track.info.maxLevel {
                let value = track.effectValue(level: level)
                XCTAssertGreaterThan(value, previous, "\(track.rawValue) level \(level)")
                previous = value
            }
            let upgraded = RunLoadout(levels: [track: track.info.maxLevel])
            for other in UpgradeTrack.allCases where other != track {
                XCTAssertEqual(
                    upgraded[keyPath: other.keyMetric], RunLoadout.base[keyPath: other.keyMetric],
                    "\(track.rawValue) changed \(other.rawValue)"
                )
            }
        }
    }

    func testSecondaryEffects() {
        var lives = RunLoadout.base.startingLives
        for level in 1...UpgradeTrack.armor.info.maxLevel {
            let next = RunLoadout(levels: [.armor: level]).startingLives
            XCTAssertGreaterThanOrEqual(next, lives)
            lives = next
        }
        XCTAssertEqual(RunLoadout.base.startingLives, 3)
        XCTAssertEqual(lives, 6)
        XCTAssertGreaterThan(RunLoadout(levels: [.magnet: 8]).coinReach, RunLoadout.base.coinReach)
        XCTAssertLessThan(RunLoadout(levels: [.tires: 6]).skidSeconds, RunLoadout.base.skidSeconds)
        XCTAssertGreaterThan(RunLoadout(levels: [.tires: 6]).skidSeconds, 0)
    }

    func testLevelsOutOfRangeAreClamped() {
        XCTAssertEqual(RunLoadout(levels: [.engine: -5]), RunLoadout.base)
        XCTAssertEqual(
            RunLoadout(levels: [.engine: 999]).topSpeed,
            RunLoadout(levels: [.engine: UpgradeTrack.engine.info.maxLevel]).topSpeed
        )
    }

    func testFullyUpgradedBikeIsClearlyStronger() {
        let base = RunLoadout.base
        let top = RunLoadout.maxed
        XCTAssertGreaterThan(top.topSpeed, base.topSpeed * 1.3)
        XCTAssertGreaterThan(top.steerRate, base.steerRate * 1.5)
        XCTAssertGreaterThan(top.boostCapacity, base.boostCapacity * 2)
        XCTAssertEqual(top.coinMultiplier, 2, accuracy: 0.0001)
        XCTAssertGreaterThan(top.startingLives, base.startingLives)
    }
}

final class CatalogTests: XCTestCase {
    func testSizesMeetTheMinimums() {
        XCTAssertGreaterThanOrEqual(Catalog.bikes.count, 24)
        XCTAssertGreaterThanOrEqual(Catalog.riders.count, 30)
        XCTAssertGreaterThanOrEqual(Catalog.trails.count, 12)
    }

    func testIdsAreUniqueAcrossTheWholeCatalog() {
        let ids = Catalog.allInfos.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testLookupsFindTheRightKind() {
        for skin in Catalog.bikes {
            XCTAssertEqual(skin.info.kind, .bike)
            XCTAssertEqual(Catalog.bike(id: skin.id), skin)
            XCTAssertEqual(Catalog.info(id: skin.id), skin.info)
        }
        for skin in Catalog.riders {
            XCTAssertEqual(skin.info.kind, .rider)
            XCTAssertEqual(Catalog.rider(id: skin.id), skin)
        }
        for skin in Catalog.trails {
            XCTAssertEqual(skin.info.kind, .trail)
            XCTAssertEqual(Catalog.trail(id: skin.id), skin)
        }
        XCTAssertNil(Catalog.info(id: "nope"))
    }

    func testNamesAreRussianAndAllRaritiesPresent() {
        for info in Catalog.allInfos {
            XCTAssertTrue(hasCyrillic(info.name), info.id)
        }
        XCTAssertEqual(Set(Catalog.bikes.map { $0.info.rarity }), Set(Rarity.allCases))
        XCTAssertEqual(Set(Catalog.riders.map { $0.info.rarity }), Set(Rarity.allCases))
        XCTAssertEqual(Set(Catalog.trails.map { $0.info.rarity }), Set(Rarity.allCases))
    }

    func testPricesSpreadFromFreeToVeryExpensive() {
        let prices = Catalog.allInfos.map { $0.price }
        XCTAssertEqual(prices.min(), 0)
        XCTAssertGreaterThanOrEqual(prices.max() ?? 0, 40000)
        XCTAssertTrue(prices.allSatisfy { $0 >= 0 })
        XCTAssertEqual(Set(Catalog.freeIds), [Catalog.starterBikeId, Catalog.starterRiderId, Catalog.starterTrailId])
    }

    func testDearerRaritiesCostMoreOnAverage() {
        func average(_ rarity: Rarity) -> Int {
            let prices = Catalog.allInfos.filter { $0.rarity == rarity && $0.unlockedBy == nil }.map { $0.price }
            return prices.reduce(0, +) / max(1, prices.count)
        }
        XCTAssertLessThan(average(.common), average(.rare))
        XCTAssertLessThan(average(.rare), average(.epic))
        XCTAssertLessThan(average(.epic), average(.legendary))
    }

    func testSomeSkinsComeFromAchievements() {
        let earned = Catalog.allInfos.filter { $0.unlockedBy != nil }
        XCTAssertGreaterThanOrEqual(earned.count, 3)
        for info in earned {
            XCTAssertEqual(info.price, 0, info.id)
            XCTAssertNotNil(info.unlockedBy.flatMap { Achievement.find($0) }, info.id)
        }
    }

    func testEveryStyleOptionIsUsedForTheGraphicsToModel() {
        XCTAssertEqual(Set(Catalog.bikes.map { $0.style.body }), Set(BikeBody.allCases))
        XCTAssertEqual(Set(Catalog.bikes.map { $0.style.wheels }), Set(WheelStyle.allCases))
        XCTAssertEqual(Set(Catalog.riders.map { $0.style.accessory }), Set(RiderAccessory.allCases))
        XCTAssertEqual(Set(Catalog.trails.map { $0.style.pattern }), Set(TrailPattern.allCases))
    }

    func testColoursAreInRange() {
        var colours: [RGB] = []
        for skin in Catalog.bikes {
            colours += [skin.style.primary, skin.style.secondary, skin.style.glow]
        }
        for skin in Catalog.riders {
            colours += [skin.style.jacket, skin.style.pants, skin.style.helmet, skin.style.visor]
        }
        for skin in Catalog.trails {
            colours += [skin.style.primary, skin.style.secondary]
        }
        for colour in colours {
            XCTAssertTrue((0...1).contains(colour.r))
            XCTAssertTrue((0...1).contains(colour.g))
            XCTAssertTrue((0...1).contains(colour.b))
        }
        XCTAssertEqual(RGB(hex: 0xFF0000), RGB(r: 1, g: 0, b: 0))
    }
}

final class AchievementTests: XCTestCase {
    func testListIsCompleteAndSomePay() {
        XCTAssertGreaterThanOrEqual(Achievement.all.count, 15)
        XCTAssertEqual(Achievement.all.map { $0.id }, AchievementID.allCases)
        XCTAssertGreaterThanOrEqual(Achievement.all.filter { $0.reward > 0 }.count, 5)
        for achievement in Achievement.all {
            XCTAssertTrue(hasCyrillic(achievement.name))
            XCTAssertTrue(hasCyrillic(achievement.description))
            XCTAssertGreaterThan(achievement.goal, 0)
        }
    }

    func testProgressStaysInRange() {
        guard let achievement = Achievement.find(.rideHundred) else { return XCTFail("missing") }
        var stats = ProfileStats()
        XCTAssertEqual(achievement.progress(for: stats), 0)
        XCTAssertFalse(achievement.isMet(by: stats))
        stats.rides = 50
        XCTAssertEqual(achievement.progress(for: stats), 0.5, accuracy: 0.0001)
        stats.rides = 500
        XCTAssertEqual(achievement.progress(for: stats), 1)
        XCTAssertTrue(achievement.isMet(by: stats))
    }

    func testFirstRidePaysOnceAndGivesItsSkin() {
        var profile = Profile()
        let first = profile.recordRide(RideSummary(distance: 100, score: 130, coins: 10))
        XCTAssertEqual(first.coinsEarned, 10)
        XCTAssertEqual(first.achievementCoins, 20)
        XCTAssertTrue(first.isNewRecord)
        XCTAssertEqual(first.unlocked, [.firstRide])
        XCTAssertEqual(profile.coins, 30)
        XCTAssertTrue(profile.owns(id: "firstblood"))
        XCTAssertTrue(profile.hasAchievement(.firstRide))

        let second = profile.recordRide(RideSummary(distance: 50, score: 60, coins: 5))
        XCTAssertEqual(second.unlocked, [])
        XCTAssertFalse(second.isNewRecord)
        XCTAssertEqual(profile.coins, 35)
    }

    func testStatsAddUpOverRides() {
        var profile = Profile()
        let ride = RideSummary(
            seconds: 60, distance: 2000, score: 3000, coins: 100, coinsPicked: 90, goldenCoins: 1, nearMisses: 4,
            hits: 3, boosts: 2, pickups: 1, skids: 1, shieldBlocks: 1, vehiclesSmashed: 2, bestCombo: 3, districtIndex: 1
        )
        _ = profile.recordRide(ride)
        _ = profile.recordRide(ride)
        XCTAssertEqual(profile.stats.rides, 2)
        XCTAssertEqual(profile.stats.totalDistance, 4000)
        XCTAssertEqual(profile.stats.totalCoins, 200)
        XCTAssertEqual(profile.stats.nearMisses, 8)
        XCTAssertEqual(profile.stats.bestDistance, 2000)
        XCTAssertEqual(profile.stats.bestCombo, 3)
        XCTAssertEqual(profile.stats.bestDistrict, 1)
        XCTAssertEqual(profile.stats.bestCleanDistance, 0, "these rides had hits")
        XCTAssertEqual(profile.bestScore, 3000)
    }

    func testCleanRideCountsOnlyWithoutHits() {
        var profile = Profile()
        _ = profile.recordRide(RideSummary(distance: 3500, score: 3500, hits: 1))
        XCTAssertFalse(profile.hasAchievement(.cleanRide))
        let reward = profile.recordRide(RideSummary(distance: 3500, score: 3500, hits: 0))
        XCTAssertEqual(profile.stats.bestCleanDistance, 3500)
        XCTAssertTrue(reward.unlocked.contains(.cleanRide))
        XCTAssertTrue(profile.owns(id: "untouchable"))
    }

    func testDistrictAchievementsGiveTheirSkins() {
        var profile = Profile()
        let reward = profile.recordRide(RideSummary(distance: 12500, score: 1, districtIndex: 4))
        XCTAssertTrue(reward.unlocked.contains(.surviveSewer))
        XCTAssertTrue(reward.unlocked.contains(.reachGoldenLoo))
        XCTAssertTrue(reward.unlocked.contains(.reachWorldEnd))
        XCTAssertTrue(profile.owns(id: "worldendbike"))
        XCTAssertTrue(profile.owns(id: "armoredloo"))
        XCTAssertTrue(profile.select(id: "worldendbike"))
    }

    func testRealRideFeedsTheProfile() {
        let (run, _) = TestRide.ride(BikeRun(seed: 5), seconds: 30) { $0.autopilotTarget() }
        var profile = Profile()
        let reward = profile.recordRide(run.summary)
        XCTAssertEqual(reward.coinsEarned, run.coins)
        XCTAssertEqual(profile.bestScore, run.score)
    }
}
