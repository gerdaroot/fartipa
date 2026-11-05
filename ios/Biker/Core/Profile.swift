import Foundation

enum PurchaseResult: Equatable {
    case bought
    case alreadyOwned
    case notEnoughCoins
    /// This skin only comes from an achievement.
    case lockedByAchievement
    case unknownItem
    /// The upgrade track is at its top level.
    case maxedOut
}

/// What a finished ride gave. Read it for the results screen.
struct RideReward: Equatable {
    /// Coins from the ride itself.
    let coinsEarned: Int
    /// Coins paid by achievements unlocked just now.
    let achievementCoins: Int
    let isNewRecord: Bool
    let unlocked: [AchievementID]
}

enum DailyClaim: Equatable {
    /// `reward` was paid; `streak` is the number of days in a row, this one included.
    case claimed(reward: Int, streak: Int)
    case alreadyClaimed
}

/// Everything saved between rides. Mutate only through these methods; they keep it consistent.
struct Profile: Codable, Equatable {
    /// Coins for day 1, 2, ... of a streak. Beyond the last day the last reward stays.
    static let dailyRewards = [20, 30, 40, 60, 80, 100, 200]
    private static let coinCap = 1_000_000_000
    private static let secondsPerDay = 86_400.0
    private static let largestDaySeconds = 1e14
    private static let largestSavedDay = 1_000_000_000_000
    private static let largestSavedStreak = 1_000_000

    private(set) var coins = 0
    private(set) var bestScore = 0
    private(set) var stats = ProfileStats()
    private(set) var owned: Set<String> = Profile.startingOwned
    private(set) var bikeId = Catalog.starterBikeId
    private(set) var riderId = Catalog.starterRiderId
    private(set) var trailId = Catalog.starterTrailId
    /// By `UpgradeTrack.rawValue`.
    private(set) var upgradeLevels: [String: Int] = [:]
    /// By `AchievementID.rawValue`.
    private(set) var achievements: Set<String> = []
    private(set) var lastDailyDay: Int?
    private(set) var dailyStreak = 0

    private static var startingOwned: Set<String> { Set(Catalog.freeIds) }

    private enum CodingKeys: String, CodingKey {
        case coins, bestScore, stats, owned, bikeId, riderId, trailId
        case upgradeLevels, achievements, lastDailyDay, dailyStreak
    }

    init() {}

    /// Missing or broken keys get defaults, so old saves and hand-edited ones still load.
    /// `parse` then repairs anything impossible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = Self.lenient(c, Int.self, .coins) ?? 0
        bestScore = Self.lenient(c, Int.self, .bestScore) ?? 0
        stats = Self.lenient(c, ProfileStats.self, .stats) ?? ProfileStats()
        owned = Self.lenient(c, Set<String>.self, .owned) ?? Self.startingOwned
        bikeId = Self.lenient(c, String.self, .bikeId) ?? Catalog.starterBikeId
        riderId = Self.lenient(c, String.self, .riderId) ?? Catalog.starterRiderId
        trailId = Self.lenient(c, String.self, .trailId) ?? Catalog.starterTrailId
        upgradeLevels = Self.lenient(c, [String: Int].self, .upgradeLevels) ?? [:]
        achievements = Self.lenient(c, Set<String>.self, .achievements) ?? []
        lastDailyDay = Self.lenient(c, Int.self, .lastDailyDay)
        dailyStreak = Self.lenient(c, Int.self, .dailyStreak) ?? 0
    }

    private static func lenient<T: Decodable>(
        _ container: KeyedDecodingContainer<CodingKeys>, _ type: T.Type, _ key: CodingKeys
    ) -> T? {
        try? container.decodeIfPresent(type, forKey: key)
    }

    // MARK: - Reading

    func owns(id: String) -> Bool { owned.contains(id) }

    func isSelected(id: String) -> Bool {
        id == bikeId || id == riderId || id == trailId
    }

    func level(of track: UpgradeTrack) -> Int {
        track.clamped(level: upgradeLevels[track.rawValue] ?? 0)
    }

    /// What the next level costs; nil at the top.
    func nextPrice(of track: UpgradeTrack) -> Int? {
        track.price(ofLevel: level(of: track) + 1)
    }

    /// Pass this to `BikeRun`.
    var loadout: RunLoadout {
        var levels: [UpgradeTrack: Int] = [:]
        for track in UpgradeTrack.allCases {
            levels[track] = level(of: track)
        }
        return RunLoadout(levels: levels)
    }

    func hasAchievement(_ id: AchievementID) -> Bool {
        achievements.contains(id.rawValue)
    }

    var selectedBike: BikeSkin? { Catalog.bike(id: bikeId) }
    var selectedRider: RiderSkin? { Catalog.rider(id: riderId) }
    var selectedTrail: TrailSkin? { Catalog.trail(id: trailId) }

    // MARK: - Coins and records

    mutating func earn(_ amount: Int) {
        coins = min(Self.coinCap, coins + min(Self.coinCap, max(0, amount)))
    }

    /// Returns true when this score is a new record.
    mutating func recordScore(_ score: Int) -> Bool {
        guard score > bestScore else { return false }
        bestScore = score
        return true
    }

    /// Call once when a ride ends: banks the coins, adds up the stats, unlocks achievements.
    mutating func recordRide(_ ride: RideSummary) -> RideReward {
        let before = coins
        earn(ride.coins)
        let earned = coins - before
        let isRecord = recordScore(ride.score)
        stats = stats.adding(ride)
        let (unlocked, paid) = unlockAchievements()
        return RideReward(coinsEarned: earned, achievementCoins: paid, isNewRecord: isRecord, unlocked: unlocked)
    }

    /// Unlocks whatever the stats have reached, pays for it and hands over its skins.
    private mutating func unlockAchievements() -> (unlocked: [AchievementID], paid: Int) {
        var unlocked: [AchievementID] = []
        var paid = 0
        for achievement in Achievement.all
        where !hasAchievement(achievement.id) && achievement.isMet(by: stats) {
            achievements.insert(achievement.id.rawValue)
            earn(achievement.reward)
            owned.formUnion(Catalog.skinIds(unlockedBy: achievement.id))
            unlocked.append(achievement.id)
            paid += achievement.reward
        }
        return (unlocked, paid)
    }

    // MARK: - Buying

    /// Spends coins only when the whole price is there.
    mutating func buySkin(id: String) -> PurchaseResult {
        guard let info = Catalog.info(id: id) else { return .unknownItem }
        if owns(id: id) { return .alreadyOwned }
        if info.unlockedBy != nil { return .lockedByAchievement }
        guard coins >= info.price else { return .notEnoughCoins }
        coins -= info.price
        owned.insert(id)
        stats.skinsBought += 1
        _ = unlockAchievements()
        return .bought
    }

    /// Spends coins only when the whole price is there.
    mutating func buyUpgrade(_ track: UpgradeTrack) -> PurchaseResult {
        let current = level(of: track)
        guard let price = track.price(ofLevel: current + 1) else { return .maxedOut }
        guard coins >= price else { return .notEnoughCoins }
        coins -= price
        upgradeLevels[track.rawValue] = current + 1
        stats.upgradesBought += 1
        _ = unlockAchievements()
        return .bought
    }

    /// Returns false for an unknown or not owned skin.
    @discardableResult
    mutating func select(id: String) -> Bool {
        guard owns(id: id), let info = Catalog.info(id: id) else { return false }
        switch info.kind {
        case .bike: bikeId = id
        case .rider: riderId = id
        case .trail: trailId = id
        }
        return true
    }

    // MARK: - Daily reward

    /// A calendar day number. `secondsFromGMT` makes the day turn over at the player's midnight.
    static func dayNumber(now: Date, secondsFromGMT: Int = 0) -> Int {
        let seconds = now.timeIntervalSince1970 + Double(secondsFromGMT)
        guard seconds.isFinite, abs(seconds) < largestDaySeconds else { return 0 }
        return Int((seconds / secondsPerDay).rounded(.down))
    }

    func canClaimDaily(now: Date, secondsFromGMT: Int = 0) -> Bool {
        guard let last = lastDailyDay else { return true }
        let today = Self.dayNumber(now: now, secondsFromGMT: secondsFromGMT)
        return today != last && today != last - 1
    }

    /// What claiming now would pay.
    func nextDailyReward(now: Date, secondsFromGMT: Int = 0) -> Int {
        let today = Self.dayNumber(now: now, secondsFromGMT: secondsFromGMT)
        return Self.dailyReward(streak: streakAfterClaim(today: today))
    }

    /// Next-day claims grow the streak, a missed day starts over. A clock that went back a day
    /// (travel) cannot claim again, one that went back further starts a new streak.
    mutating func claimDaily(now: Date, secondsFromGMT: Int = 0) -> DailyClaim {
        guard canClaimDaily(now: now, secondsFromGMT: secondsFromGMT) else { return .alreadyClaimed }
        let today = Self.dayNumber(now: now, secondsFromGMT: secondsFromGMT)
        let streak = streakAfterClaim(today: today)
        let reward = Self.dailyReward(streak: streak)
        dailyStreak = streak
        lastDailyDay = today
        earn(reward)
        stats.bestDailyStreak = max(stats.bestDailyStreak, streak)
        _ = unlockAchievements()
        return .claimed(reward: reward, streak: streak)
    }

    private func streakAfterClaim(today: Int) -> Int {
        lastDailyDay.map { $0 + 1 == today } == true ? dailyStreak + 1 : 1
    }

    static func dailyReward(streak: Int) -> Int {
        let index = min(dailyRewards.count - 1, max(0, streak - 1))
        return dailyRewards[index]
    }

    // MARK: - Saving

    /// Reads saved data. Broken data gives a new profile; anything impossible in a save that
    /// loads (negative coins, unknown ids, skins not paid for) is repaired.
    static func parse(_ data: Data?) -> Profile {
        guard let data, let saved = try? JSONDecoder().decode(Profile.self, from: data) else { return Profile() }
        return saved.repaired()
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    private func repaired() -> Profile {
        var clean = Profile()
        clean.coins = min(Self.coinCap, max(0, coins))
        clean.bestScore = max(0, bestScore)
        clean.stats = stats
        clean.upgradeLevels = repairedLevels()
        clean.achievements = achievements.filter { AchievementID(rawValue: $0) != nil }
        clean.owned = repairedOwned(achievements: clean.achievements)
        clean.lastDailyDay = lastDailyDay.flatMap { $0 > -Self.largestSavedDay && $0 < Self.largestSavedDay ? $0 : nil }
        clean.dailyStreak = min(Self.largestSavedStreak, max(0, dailyStreak))
        clean.selectIfValid(bikeId, kind: .bike)
        clean.selectIfValid(riderId, kind: .rider)
        clean.selectIfValid(trailId, kind: .trail)
        return clean
    }

    private func repairedLevels() -> [String: Int] {
        var levels: [String: Int] = [:]
        for track in UpgradeTrack.allCases {
            let stored = level(of: track)
            if stored > 0 { levels[track.rawValue] = stored }
        }
        return levels
    }

    /// Paid-for skins stay; skins that belong to an achievement stay only with that achievement.
    private func repairedOwned(achievements earned: Set<String>) -> Set<String> {
        var result = Self.startingOwned
        for id in owned {
            guard let info = Catalog.info(id: id) else { continue }
            if let source = info.unlockedBy, !earned.contains(source.rawValue) { continue }
            result.insert(id)
        }
        for id in earned {
            guard let achievement = AchievementID(rawValue: id) else { continue }
            result.formUnion(Catalog.skinIds(unlockedBy: achievement))
        }
        return result
    }

    private mutating func selectIfValid(_ id: String, kind: SkinKind) {
        guard Catalog.info(id: id)?.kind == kind else { return }
        select(id: id)
    }
}
