import XCTest
import Foundation
@testable import BikerCore

final class PurchaseTests: XCTestCase {
    private let sportPrice = Catalog.info(id: "sport")?.price ?? 0

    func testStartingKitIsFreeAndSelected() {
        let profile = Profile()
        XCTAssertEqual(profile.coins, 0)
        XCTAssertEqual(profile.bikeId, Catalog.starterBikeId)
        XCTAssertEqual(profile.riderId, Catalog.starterRiderId)
        XCTAssertEqual(profile.trailId, Catalog.starterTrailId)
        XCTAssertTrue(profile.owns(id: Catalog.starterBikeId))
        XCTAssertTrue(profile.owns(id: Catalog.starterRiderId))
        XCTAssertTrue(profile.owns(id: Catalog.starterTrailId))
        XCTAssertTrue(profile.isSelected(id: Catalog.starterBikeId))
        XCTAssertEqual(profile.selectedBike?.id, Catalog.starterBikeId)
        XCTAssertEqual(profile.selectedRider?.id, Catalog.starterRiderId)
        XCTAssertEqual(profile.selectedTrail?.id, Catalog.starterTrailId)
        XCTAssertEqual(profile.loadout, RunLoadout.base)
    }

    func testCannotBuyWithoutCoins() {
        var profile = Profile()
        profile.earn(sportPrice - 1)
        XCTAssertEqual(profile.buySkin(id: "sport"), .notEnoughCoins)
        XCTAssertFalse(profile.owns(id: "sport"))
        XCTAssertEqual(profile.coins, sportPrice - 1)
    }

    func testBuyingSpendsCoinsOnce() {
        var profile = Profile()
        profile.earn(sportPrice + 5)
        XCTAssertEqual(profile.buySkin(id: "sport"), .bought)
        XCTAssertEqual(profile.coins, 5)
        XCTAssertEqual(profile.buySkin(id: "sport"), .alreadyOwned)
        XCTAssertEqual(profile.coins, 5)
        XCTAssertEqual(profile.stats.skinsBought, 1)
    }

    func testUnknownAndAchievementSkinsCannotBeBought() {
        var profile = Profile()
        profile.earn(1000)
        XCTAssertEqual(profile.buySkin(id: "nope"), .unknownItem)
        XCTAssertEqual(profile.buySkin(id: "worldendbike"), .lockedByAchievement)
        XCTAssertEqual(profile.coins, 1000)
        XCTAssertFalse(profile.owns(id: "worldendbike"))
    }

    func testCannotSelectWhatYouDoNotOwn() {
        var profile = Profile()
        XCTAssertFalse(profile.select(id: "king"))
        XCTAssertFalse(profile.select(id: "nope"))
        XCTAssertEqual(profile.riderId, Catalog.starterRiderId)
        profile.earn(Catalog.info(id: "king")?.price ?? 0)
        _ = profile.buySkin(id: "king")
        XCTAssertTrue(profile.select(id: "king"))
        XCTAssertEqual(profile.riderId, "king")
        XCTAssertEqual(profile.bikeId, Catalog.starterBikeId)
    }

    func testSelectionGoesToTheRightSlot() {
        var profile = Profile()
        profile.earn(100_000)
        _ = profile.buySkin(id: "sport")
        _ = profile.buySkin(id: "fire")
        profile.select(id: "sport")
        profile.select(id: "fire")
        XCTAssertEqual(profile.bikeId, "sport")
        XCTAssertEqual(profile.trailId, "fire")
        XCTAssertEqual(profile.riderId, Catalog.starterRiderId)
    }

    func testUpgradePurchaseRaisesLevelAndLoadout() {
        var profile = Profile()
        let price = UpgradeTrack.engine.price(ofLevel: 1) ?? 0
        XCTAssertEqual(profile.nextPrice(of: .engine), price)
        XCTAssertEqual(profile.buyUpgrade(.engine), .notEnoughCoins)
        XCTAssertEqual(profile.level(of: .engine), 0)
        profile.earn(price)
        XCTAssertEqual(profile.buyUpgrade(.engine), .bought)
        XCTAssertEqual(profile.coins, 0)
        XCTAssertEqual(profile.level(of: .engine), 1)
        XCTAssertEqual(profile.loadout, RunLoadout(levels: [.engine: 1]))
        XCTAssertEqual(profile.nextPrice(of: .engine), UpgradeTrack.engine.price(ofLevel: 2))
    }

    func testUpgradeStopsAtTheTopAndKeepsCoins() {
        var profile = Profile()
        profile.earn(1_000_000)
        let top = UpgradeTrack.tires.info.maxLevel
        for _ in 0..<top {
            XCTAssertEqual(profile.buyUpgrade(.tires), .bought)
        }
        XCTAssertEqual(profile.level(of: .tires), top)
        XCTAssertNil(profile.nextPrice(of: .tires))
        let coins = profile.coins
        XCTAssertEqual(profile.buyUpgrade(.tires), .maxedOut)
        XCTAssertEqual(profile.coins, coins)
    }

    private func affordableTrack(_ profile: Profile) -> UpgradeTrack? {
        UpgradeTrack.allCases.first { track in
            guard let price = profile.nextPrice(of: track) else { return false }
            return profile.coins >= price
        }
    }

    func testBuyingUpgradesNeverOverdraws() {
        var profile = Profile()
        profile.earn(UpgradeTrack.totalPriceOfEverything / 2)
        var purchases = 0
        while let track = affordableTrack(profile) {
            XCTAssertEqual(profile.buyUpgrade(track), .bought)
            XCTAssertGreaterThanOrEqual(profile.coins, 0)
            purchases += 1
        }
        XCTAssertGreaterThan(purchases, 20)
        XCTAssertEqual(profile.stats.upgradesBought, purchases)
        XCTAssertTrue(profile.hasAchievement(.upgradeTwenty))
    }

    func testCoinsCannotOverflow() {
        var profile = Profile()
        profile.earn(Int.max)
        profile.earn(Int.max)
        XCTAssertGreaterThan(profile.coins, 0)
        profile.earn(-100)
        XCTAssertGreaterThan(profile.coins, 0)
    }

    func testRecordOnlyGoesUp() {
        var profile = Profile()
        XCTAssertTrue(profile.recordScore(10))
        XCTAssertFalse(profile.recordScore(5))
        XCTAssertEqual(profile.bestScore, 10)
    }
}

final class SaveTests: XCTestCase {
    private func parse(_ json: String) -> Profile {
        Profile.parse(Data(json.utf8))
    }

    func testRoundTripsThroughStorage() {
        var profile = Profile()
        profile.earn(50_000)
        _ = profile.buySkin(id: "sport")
        _ = profile.buySkin(id: "fire")
        profile.select(id: "sport")
        profile.select(id: "fire")
        _ = profile.buyUpgrade(.piggy)
        _ = profile.buyUpgrade(.piggy)
        _ = profile.recordRide(RideSummary(distance: 1234, score: 1500, coins: 12, nearMisses: 2, bestCombo: 3))
        _ = profile.claimDaily(now: Date(timeIntervalSince1970: 864_000))
        XCTAssertEqual(Profile.parse(profile.encoded()), profile)
    }

    func testBrokenSavesFallBackSafely() {
        XCTAssertEqual(Profile.parse(nil), Profile())
        XCTAssertEqual(parse("junk"), Profile())
        XCTAssertEqual(parse("[1,2,3]"), Profile())
        XCTAssertEqual(Profile.parse(Data()), Profile())
    }

    func testMissingKeysGetDefaults() {
        XCTAssertEqual(parse("{}"), Profile())
        let partial = parse("{\"coins\":77}")
        XCTAssertEqual(partial.coins, 77)
        XCTAssertEqual(partial.bikeId, Catalog.starterBikeId)
        XCTAssertEqual(partial.stats, ProfileStats())
        XCTAssertEqual(partial.loadout, RunLoadout.base)
    }

    func testOldSaveFromTheFirstVersionStillLoads() {
        let old = "{\"coins\":50,\"bestScore\":7,\"owned\":[\"rusty\",\"leather\",\"sport\"],\"bikeId\":\"sport\",\"riderId\":\"leather\"}"
        let profile = parse(old)
        XCTAssertEqual(profile.coins, 50)
        XCTAssertEqual(profile.bestScore, 7)
        XCTAssertEqual(profile.bikeId, "sport")
        XCTAssertEqual(profile.trailId, Catalog.starterTrailId)
        XCTAssertTrue(profile.owns(id: Catalog.starterTrailId))
    }

    func testAKeyOfTheWrongTypeOnlyLosesThatKey() {
        let profile = parse("{\"coins\":\"много\",\"bestScore\":12,\"stats\":{\"rides\":\"x\",\"hits\":4},\"owned\":5}")
        XCTAssertEqual(profile.coins, 0)
        XCTAssertEqual(profile.bestScore, 12)
        XCTAssertEqual(profile.stats.rides, 0)
        XCTAssertEqual(profile.stats.hits, 4)
        XCTAssertTrue(profile.owns(id: Catalog.starterBikeId))
    }

    func testTamperedValuesAreRepaired() {
        let cheat = """
        {"coins":-50,"bestScore":-1,"owned":["nope","worldendbike","sport"],"bikeId":"king","riderId":"sport",\
        "trailId":"plasma","upgradeLevels":{"engine":99,"piggy":-3,"bogus":5},\
        "achievements":["hacked","firstRide"],"dailyStreak":-4,"stats":{"rides":-9,"bestCombo":-2}}
        """
        let profile = parse(cheat)
        XCTAssertEqual(profile.coins, 0)
        XCTAssertEqual(profile.bestScore, 0)
        XCTAssertFalse(profile.owns(id: "nope"))
        XCTAssertFalse(profile.owns(id: "worldendbike"), "achievement skin without its achievement")
        XCTAssertTrue(profile.owns(id: "sport"))
        XCTAssertTrue(profile.owns(id: "firstblood"), "the kept achievement brings its skin")
        XCTAssertEqual(profile.bikeId, Catalog.starterBikeId, "king is not a bike")
        XCTAssertEqual(profile.riderId, Catalog.starterRiderId, "sport is not a rider")
        XCTAssertEqual(profile.trailId, Catalog.starterTrailId, "plasma is not owned")
        XCTAssertEqual(profile.level(of: .engine), UpgradeTrack.engine.info.maxLevel)
        XCTAssertEqual(profile.level(of: .piggy), 0)
        XCTAssertNil(profile.upgradeLevels["bogus"])
        XCTAssertEqual(profile.achievements, ["firstRide"])
        XCTAssertEqual(profile.dailyStreak, 0)
        XCTAssertEqual(profile.stats.rides, 0)
        XCTAssertEqual(profile.stats.bestCombo, 1)
    }

    func testHugeNumbersCannotCrashAnything() {
        var profile = parse(
            "{\"coins\":9223372036854775807,\"lastDailyDay\":9223372036854775807,\"dailyStreak\":9223372036854775807}"
        )
        profile.earn(100)
        XCTAssertGreaterThan(profile.coins, 0)
        XCTAssertNil(profile.lastDailyDay)
        let claim = profile.claimDaily(now: Date(timeIntervalSince1970: 864_000))
        XCTAssertEqual(claim, .claimed(reward: Profile.dailyRewards[0], streak: 1))
    }

    func testSavedTextIsPlainJSON() {
        let data = Profile().encoded()
        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: data))
    }
}

final class DailyRewardTests: XCTestCase {
    private let day = 86_400.0
    private let firstDay = 20_000.0

    private func moment(_ dayOffset: Double, hour: Double = 12) -> Date {
        Date(timeIntervalSince1970: (firstDay + dayOffset) * day + hour * 3600)
    }

    func testFirstClaimPaysTheFirstReward() {
        var profile = Profile()
        XCTAssertTrue(profile.canClaimDaily(now: moment(0)))
        XCTAssertEqual(profile.nextDailyReward(now: moment(0)), Profile.dailyRewards[0])
        XCTAssertEqual(profile.claimDaily(now: moment(0)), .claimed(reward: Profile.dailyRewards[0], streak: 1))
        XCTAssertEqual(profile.coins, Profile.dailyRewards[0])
    }

    func testOnlyOneClaimPerDay() {
        var profile = Profile()
        _ = profile.claimDaily(now: moment(0, hour: 1))
        let coins = profile.coins
        XCTAssertFalse(profile.canClaimDaily(now: moment(0, hour: 23)))
        XCTAssertEqual(profile.claimDaily(now: moment(0, hour: 23)), .alreadyClaimed)
        XCTAssertEqual(profile.coins, coins)
    }

    func testStreakGrowsDayByDayAndPaysMore() {
        var profile = Profile()
        for (index, reward) in Profile.dailyRewards.enumerated() {
            XCTAssertEqual(
                profile.claimDaily(now: moment(Double(index))), .claimed(reward: reward, streak: index + 1)
            )
        }
        XCTAssertEqual(profile.coins, Profile.dailyRewards.reduce(0, +))
        let last = Profile.dailyRewards.count
        XCTAssertEqual(
            profile.claimDaily(now: moment(Double(last))),
            .claimed(reward: Profile.dailyRewards[last - 1], streak: last + 1),
            "beyond the table the top reward stays"
        )
        XCTAssertEqual(Array(Profile.dailyRewards.sorted()), Profile.dailyRewards)
    }

    func testSevenDaysUnlockTheTrail() {
        var profile = Profile()
        for index in 0..<7 {
            _ = profile.claimDaily(now: moment(Double(index)))
        }
        XCTAssertTrue(profile.hasAchievement(.dailySeven))
        XCTAssertTrue(profile.owns(id: "dailygas"))
        XCTAssertEqual(profile.stats.bestDailyStreak, 7)
    }

    func testMissedDayRestartsTheStreak() {
        var profile = Profile()
        _ = profile.claimDaily(now: moment(0))
        _ = profile.claimDaily(now: moment(1))
        XCTAssertEqual(profile.dailyStreak, 2)
        XCTAssertEqual(profile.claimDaily(now: moment(3)), .claimed(reward: Profile.dailyRewards[0], streak: 1))
        XCTAssertEqual(profile.stats.bestDailyStreak, 2)
    }

    func testClockGoingBackADayCannotClaimAgain() {
        var profile = Profile()
        _ = profile.claimDaily(now: moment(5))
        XCTAssertEqual(profile.claimDaily(now: moment(4)), .alreadyClaimed)
        XCTAssertEqual(profile.claimDaily(now: moment(1)), .claimed(reward: Profile.dailyRewards[0], streak: 1))
    }

    func testMidnightFollowsTheTimeZone() {
        let lateEvening = moment(0, hour: 22)
        let moscow = 3 * 3600
        XCTAssertEqual(Profile.dayNumber(now: lateEvening), Int(firstDay))
        XCTAssertEqual(Profile.dayNumber(now: lateEvening, secondsFromGMT: moscow), Int(firstDay) + 1)
    }

    func testBrokenClockGivesNoCrash() {
        XCTAssertEqual(Profile.dayNumber(now: Date(timeIntervalSince1970: .infinity)), 0)
        XCTAssertEqual(Profile.dayNumber(now: Date(timeIntervalSince1970: 1e300)), 0)
    }

    func testStreakSurvivesASave() {
        var profile = Profile()
        _ = profile.claimDaily(now: moment(0))
        var loaded = Profile.parse(profile.encoded())
        XCTAssertEqual(loaded.claimDaily(now: moment(1)), .claimed(reward: Profile.dailyRewards[1], streak: 2))
    }
}
