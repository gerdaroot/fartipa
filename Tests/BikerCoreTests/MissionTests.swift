import XCTest
import Foundation
@testable import BikerCore

private func hasCyrillic(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
}

final class MissionTests: XCTestCase {
    func testNewPlayerHasThreeStarterMissions() {
        let profile = Profile()
        XCTAssertEqual(profile.missions, MissionDeck.starting)
        XCTAssertEqual(profile.missions.count, MissionDeck.activeCount)
        XCTAssertEqual(Set(profile.missions.map { $0.kind }).count, MissionDeck.activeCount)
        for mission in profile.missions {
            XCTAssertTrue(hasCyrillic(mission.title))
            XCTAssertGreaterThan(mission.reward, 0)
            XCTAssertEqual(mission.progress, 0)
        }
    }

    func testPerRideMissionKeepsTheBestRide() {
        let mission = Mission(id: 1, kind: .coinsInRide, goal: 80, reward: 50)
        let first = mission.progressed(by: RideSummary(coins: 50))
        XCTAssertEqual(first.progress, 50)
        let worse = first.progressed(by: RideSummary(coins: 30))
        XCTAssertEqual(worse.progress, 50, "a worse ride does not lower it")
        XCTAssertFalse(worse.isDone)
        let done = worse.progressed(by: RideSummary(coins: 90))
        XCTAssertEqual(done.progress, 80, "capped at the goal")
        XCTAssertTrue(done.isDone)
        XCTAssertEqual(done.fraction, 1)
    }

    func testTotalMissionAddsUpOverRides() {
        var mission = Mission(id: 1, kind: .pilesJumped, goal: 5, reward: 50)
        var ride = RideSummary()
        ride.pilesJumped = 2
        mission = mission.progressed(by: ride)
        mission = mission.progressed(by: ride)
        XCTAssertEqual(mission.progress, 4)
        XCTAssertEqual(mission.fraction, 0.8, accuracy: 0.0001)
        mission = mission.progressed(by: ride)
        XCTAssertTrue(mission.isDone)
        XCTAssertEqual(mission.progress, 5)
    }

    func testEachKindReadsItsNumber() {
        var ride = RideSummary(distance: 2100, score: 3300, coins: 310, goldenCoins: 4, nearMisses: 6,
                               vehiclesSmashed: 5, bestCombo: 7)
        ride.pilesJumped = 10
        ride.hazardsJumped = 3
        ride.rampJumps = 2
        ride.flips = 1
        ride.vehiclesVaulted = 2
        ride.bestCleanStretch = 2000
        let expected: [MissionKind: Int] = [
            .coinsInRide: 310, .distanceInRide: 2100, .cleanDistance: 2000, .scoreInRide: 3300, .comboInRide: 7,
            .pilesJumped: 10, .hazardsJumped: 3, .smashes: 5, .nearMisses: 6, .rampJumps: 2, .flips: 1,
            .goldenCoins: 4, .vaults: 2,
        ]
        XCTAssertEqual(Set(expected.keys), Set(MissionKind.allCases))
        for (kind, value) in expected {
            XCTAssertEqual(kind.value(in: ride), value, kind.rawValue)
        }
    }

    func testTitlesReadWell() {
        XCTAssertEqual(MissionKind.coinsInRide.title(goal: 300), "Собери 300 говнокоинов за заезд")
        XCTAssertEqual(MissionKind.pilesJumped.title(goal: 10), "Перепрыгни 10 куч")
        XCTAssertEqual(MissionKind.pilesJumped.title(goal: 3), "Перепрыгни 3 кучи")
        XCTAssertEqual(MissionKind.cleanDistance.title(goal: 2000), "Проедь 2 км без попаданий")
        XCTAssertEqual(MissionKind.distanceInRide.title(goal: 1500), "Проедь 1,5 км за заезд")
        XCTAssertEqual(MissionKind.smashes.title(goal: 5), "Сделай 5 таранов на газах")
        XCTAssertEqual(MissionKind.rampJumps.title(goal: 2), "Прыгни с трамплина 2 раза")
        for kind in MissionKind.allCases {
            XCTAssertTrue(hasCyrillic(kind.title(goal: 7)), kind.rawValue)
        }
    }

    func testRussianPlurals() {
        XCTAssertEqual(RussianWords.plural(1, "куча", "кучи", "куч"), "куча")
        XCTAssertEqual(RussianWords.plural(3, "куча", "кучи", "куч"), "кучи")
        XCTAssertEqual(RussianWords.plural(5, "куча", "кучи", "куч"), "куч")
        XCTAssertEqual(RussianWords.plural(11, "куча", "кучи", "куч"), "куч")
        XCTAssertEqual(RussianWords.plural(21, "куча", "кучи", "куч"), "куча")
        XCTAssertEqual(RussianWords.plural(112, "куча", "кучи", "куч"), "куч")
        XCTAssertEqual(RussianWords.metres(800), "800 м")
        XCTAssertEqual(RussianWords.metres(2000), "2 км")
        XCTAssertEqual(RussianWords.metres(1500), "1,5 км")
    }

    /// 90 coins finish the 80-coin mission: 90 + 20 (first ride achievement) + 50 (mission) = 160.
    /// Score 100 gives 10 experience, far from level 2.
    func testFinishedMissionPaysAndIsReplacedInPlace() {
        var profile = Profile()
        let reward = profile.recordRide(RideSummary(distance: 100, score: 100, coins: 90))
        XCTAssertEqual(reward.missionCoins, 50)
        XCTAssertEqual(reward.completedMissions.map { $0.kind }, [.coinsInRide])
        XCTAssertEqual(profile.coins, 160)
        XCTAssertEqual(reward.totalCoins, 160)
        XCTAssertEqual(profile.missions.count, MissionDeck.activeCount)
        XCTAssertEqual(profile.missions[0].id, MissionDeck.starting.count + 1)
        XCTAssertEqual(profile.missions[0].progress, 0)
        XCTAssertFalse([.coinsInRide, .pilesJumped, .rampJumps].contains(profile.missions[0].kind))
        XCTAssertEqual(profile.missions[1], MissionDeck.starting[1])
        XCTAssertEqual(profile.missionSerial, MissionDeck.starting.count + 1)
    }

    func testUnfinishedMissionsKeepTheirProgress() {
        var profile = Profile()
        var ride = RideSummary(coins: 10)
        ride.pilesJumped = 2
        ride.rampJumps = 1
        let reward = profile.recordRide(ride)
        XCTAssertEqual(reward.missionCoins, 0)
        XCTAssertEqual(profile.missions.map { $0.progress }, [10, 2, 1])
        let preview = profile.missionsPreview(after: ride)
        XCTAssertEqual(preview.map { $0.isDone }, [false, true, true])
        XCTAssertEqual(profile.missions.map { $0.progress }, [10, 2, 1], "a preview changes nothing")
    }

    func testDeckIsDeterministicAndGrowsWithLevel() {
        XCTAssertEqual(MissionDeck.make(serial: 10, level: 1, avoiding: []), MissionDeck.make(serial: 10, level: 1, avoiding: []))
        let easy = MissionDeck.make(serial: 10, level: 1, avoiding: [])
        let hard = MissionDeck.make(serial: 10, level: 8, avoiding: [])
        XCTAssertEqual(easy.kind, hard.kind)
        XCTAssertGreaterThanOrEqual(hard.goal, easy.goal)
        XCTAssertGreaterThan(hard.reward, easy.reward)
        XCTAssertEqual(hard.reward % 5, 0)
        let only = MissionDeck.make(serial: 3, level: 1, avoiding: MissionKind.allCases.filter { $0 != .flips })
        XCTAssertEqual(only.kind, .flips)
        let combo = MissionDeck.make(serial: 1, level: 99, avoiding: MissionKind.allCases.filter { $0 != .comboInRide })
        XCTAssertLessThanOrEqual(combo.goal, ComboMeter.highest)
    }

    func testMissionsSurviveASave() {
        var profile = Profile()
        var ride = RideSummary(distance: 100, score: 4000, coins: 90)
        ride.pilesJumped = 1
        _ = profile.recordRide(ride)
        XCTAssertEqual(Profile.parse(profile.encoded()), profile)
    }

    func testOldSaveWithoutMissionsStillLoads() {
        let profile = Profile.parse(Data("{\"coins\":5,\"bestScore\":9}".utf8))
        XCTAssertEqual(profile.coins, 5)
        XCTAssertEqual(profile.missions, MissionDeck.starting)
        XCTAssertEqual(profile.xp, 0)
        XCTAssertEqual(profile.level, 1)
    }

    /// One mission has goal 0 (dropped); the other is kept with its progress capped at its goal;
    /// two new ones fill the board with serials 9 and 10.
    func testBrokenMissionsAreRepaired() {
        let json = """
        {"missionSerial":8,"xp":-5,"missions":[{"id":7,"kind":"flips","goal":0,"reward":10,"progress":0},\
        {"id":8,"kind":"vaults","goal":3,"reward":60,"progress":9}]}
        """
        let profile = Profile.parse(Data(json.utf8))
        XCTAssertEqual(profile.xp, 0)
        XCTAssertEqual(profile.missions.count, MissionDeck.activeCount)
        XCTAssertEqual(profile.missions[0].id, 8)
        XCTAssertEqual(profile.missions[0].progress, 3)
        XCTAssertEqual(profile.missions.map { $0.id }, [8, 9, 10])
        XCTAssertEqual(profile.missionSerial, 10)
        XCTAssertEqual(Set(profile.missions.map { $0.kind }).count, MissionDeck.activeCount)
    }

    func testUnknownMissionKindFallsBackToStarters() {
        let json = "{\"missions\":[{\"id\":4,\"kind\":\"bogus\",\"goal\":3,\"reward\":5,\"progress\":0}]}"
        XCTAssertEqual(Profile.parse(Data(json.utf8)).missions, MissionDeck.starting)
    }
}

final class PlayerLevelTests: XCTestCase {
    /// Steps of 200, 300, 400...: level 2 at 200 XP, 3 at 500, 4 at 900.
    func testLevelsFromExperience() {
        XCTAssertEqual(PlayerLevel.level(forXP: 0), 1)
        XCTAssertEqual(PlayerLevel.level(forXP: 199), 1)
        XCTAssertEqual(PlayerLevel.level(forXP: 200), 2)
        XCTAssertEqual(PlayerLevel.level(forXP: 499), 2)
        XCTAssertEqual(PlayerLevel.level(forXP: 500), 3)
        XCTAssertEqual(PlayerLevel.level(forXP: 900), 4)
        XCTAssertEqual(PlayerLevel.level(forXP: -50), 1)
        XCTAssertEqual(PlayerLevel.level(forXP: Int.max / 2), PlayerLevel.topLevel)
        let progress = PlayerLevel.progress(forXP: 350)
        XCTAssertEqual(progress.level, 2)
        XCTAssertEqual(progress.xpIntoLevel, 150)
        XCTAssertEqual(progress.xpForLevel, 300)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.0001)
    }

    /// Level 2 pays 20 + 10 × 2 = 40, level 3 pays 50.
    func testLevelRewards() {
        XCTAssertEqual(PlayerLevel.reward(reaching: 2), 40)
        XCTAssertEqual(PlayerLevel.rewards(from: 1, to: 3), 90)
        XCTAssertEqual(PlayerLevel.rewards(from: 3, to: 3), 0)
        XCTAssertEqual(PlayerLevel.xp(forScore: 5000), 500)
        XCTAssertEqual(PlayerLevel.xp(forScore: -3), 0)
    }

    /// Score 5000 is 500 XP: level 3, paying 90; plus 20 for the first ride achievement.
    func testRideRaisesTheLevelAndPays() {
        var profile = Profile()
        let reward = profile.recordRide(RideSummary(score: 5000))
        XCTAssertEqual(reward.xpGained, 500)
        XCTAssertEqual(reward.levelBefore, 1)
        XCTAssertEqual(reward.levelAfter, 3)
        XCTAssertEqual(reward.levelCoins, 90)
        XCTAssertEqual(profile.level, 3)
        XCTAssertEqual(profile.coins, 110)
        XCTAssertEqual(profile.levelProgress.xpIntoLevel, 0)
    }

    /// The income target: a beginner's ride (about 120 coins, score 3000) plus level and mission pay
    /// buys a cheap upgrade every ride and a first skin within two or three rides.
    func testBeginnerCanBuySomethingEveryFewRides() {
        var profile = Profile()
        for _ in 0..<3 {
            var ride = RideSummary(distance: 1500, score: 3000, coins: 120)
            ride.pilesJumped = 1
            ride.rampJumps = 1
            _ = profile.recordRide(ride)
        }
        let cheapestSkin = Catalog.allInfos.filter { $0.price > 0 && $0.unlockedBy == nil }.map { $0.price }.min() ?? 0
        XCTAssertGreaterThanOrEqual(profile.coins, cheapestSkin + (UpgradeTrack.engine.price(ofLevel: 1) ?? 0))
        XCTAssertLessThan(profile.coins, 3000, "but not everything at once")
    }
}
