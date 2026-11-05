import Foundation

enum AchievementID: String, CaseIterable, Codable, Equatable {
    case firstRide
    case rideHundred
    case distanceTenKm
    case distanceMarathon
    case coinsThousand
    case coinsTenThousand
    case goldenFifty
    case nearMissHundred
    case comboFive
    case comboMax
    case boostFifty
    case smashTwenty
    case skidFifty
    case shieldTen
    case surviveSewer
    case reachGoldenLoo
    case reachWorldEnd
    case cleanRide
    case dailySeven
    case upgradeTwenty
    case shopaholic
}

/// A goal measured by one number of `ProfileStats`. Some pay coins, some give a skin
/// (see `Catalog.skinIds(unlockedBy:)`).
struct Achievement: Equatable {
    let id: AchievementID
    let name: String
    let description: String
    let reward: Int
    let metric: KeyPath<ProfileStats, Int>
    let goal: Int

    func isMet(by stats: ProfileStats) -> Bool {
        stats[keyPath: metric] >= goal
    }

    /// How close the player is, 0...1, for a progress bar.
    func progress(for stats: ProfileStats) -> Double {
        guard goal > 0 else { return 1 }
        return min(1, Double(max(0, stats[keyPath: metric])) / Double(goal))
    }

    static func find(_ id: AchievementID) -> Achievement? {
        all.first { $0.id == id }
    }

    static let all: [Achievement] = [
        Achievement(id: .firstRide, name: "Первый блин", description: "Закончи первый заезд.", reward: 20, metric: \ProfileStats.rides, goal: 1),
        Achievement(id: .rideHundred, name: "Ветеран говнодорог", description: "Откатай 100 заездов.", reward: 0, metric: \ProfileStats.rides, goal: 100),
        Achievement(id: .distanceTenKm, name: "Дальнобойщик", description: "Проедь 10 км всего.", reward: 100, metric: \ProfileStats.totalDistance, goal: 10_000),
        Achievement(id: .distanceMarathon, name: "Говномарафон", description: "Проедь 200 км всего.", reward: 1000, metric: \ProfileStats.totalDistance, goal: 200_000),
        Achievement(id: .coinsThousand, name: "Первая штука", description: "Собери 1000 говнокоинов.", reward: 100, metric: \ProfileStats.totalCoins, goal: 1000),
        Achievement(id: .coinsTenThousand, name: "Говномиллионер", description: "Собери 10 000 говнокоинов.", reward: 0, metric: \ProfileStats.totalCoins, goal: 10_000),
        Achievement(id: .goldenFifty, name: "Золотарь", description: "Подбери 50 золотых монет.", reward: 300, metric: \ProfileStats.goldenCoins, goal: 50),
        Achievement(id: .nearMissHundred, name: "Мастер увёрток", description: "100 раз проскочи на волоске.", reward: 0, metric: \ProfileStats.nearMisses, goal: 100),
        Achievement(id: .comboFive, name: "На кураже", description: "Разгони комбо до ×5.", reward: 100, metric: \ProfileStats.bestCombo, goal: 5),
        Achievement(id: .comboMax, name: "Псих", description: "Разгони комбо до ×10.", reward: 500, metric: \ProfileStats.bestCombo, goal: ComboMeter.highest),
        Achievement(id: .boostFifty, name: "Святой дух", description: "Пусти газы 50 раз.", reward: 0, metric: \ProfileStats.boosts, goal: 50),
        Achievement(id: .smashTwenty, name: "Таран", description: "Протарань 20 машин на газах.", reward: 0, metric: \ProfileStats.vehiclesSmashed, goal: 20),
        Achievement(id: .skidFifty, name: "Коричневый дрифт", description: "50 раз поскользнись на куче.", reward: 150, metric: \ProfileStats.skids, goal: 50),
        Achievement(id: .shieldTen, name: "Лопух спас", description: "Щит спасёт тебя 10 раз.", reward: 200, metric: \ProfileStats.shieldBlocks, goal: 10),
        Achievement(id: .surviveSewer, name: "Бронесортир", description: "Доберись до Промзоны.", reward: 0, metric: \ProfileStats.bestDistrict, goal: 2),
        Achievement(id: .reachGoldenLoo, name: "Трон близко", description: "Доберись до Золотого Сортира.", reward: 500, metric: \ProfileStats.bestDistrict, goal: 3),
        Achievement(id: .reachWorldEnd, name: "Конец Света", description: "Доберись до Жопы Мира.", reward: 0, metric: \ProfileStats.bestDistrict, goal: 4),
        Achievement(id: .cleanRide, name: "Сухой Вася", description: "Проедь 3 км за заезд и не обоссысь.", reward: 0, metric: \ProfileStats.bestCleanDistance, goal: 3000),
        Achievement(id: .dailySeven, name: "Ежедневная вонь", description: "Заходи за наградой 7 дней подряд.", reward: 0, metric: \ProfileStats.bestDailyStreak, goal: 7),
        Achievement(id: .upgradeTwenty, name: "Механик-самоучка", description: "Купи 20 улучшений.", reward: 300, metric: \ProfileStats.upgradesBought, goal: 20),
        Achievement(id: .shopaholic, name: "Модник с помойки", description: "Купи 10 скинов.", reward: 400, metric: \ProfileStats.skinsBought, goal: 10),
    ]
}

/// Lifetime numbers. Decoding tolerates missing and broken keys.
struct ProfileStats: Codable, Equatable {
    var rides = 0
    var totalDistance = 0
    var totalCoins = 0
    var goldenCoins = 0
    var nearMisses = 0
    var hits = 0
    var boosts = 0
    var pickups = 0
    var skids = 0
    var shieldBlocks = 0
    var vehiclesSmashed = 0
    var bestDistance = 0
    var bestCombo = 1
    var bestDistrict = 0
    var bestCleanDistance = 0
    var bestDailyStreak = 0
    var upgradesBought = 0
    var skinsBought = 0
    var pilesJumped = 0
    var hazardsJumped = 0
    var rampJumps = 0
    var vehiclesVaulted = 0
    var flips = 0

    private static let cap = 1_000_000_000_000

    private enum CodingKeys: String, CodingKey {
        case rides, totalDistance, totalCoins, goldenCoins, nearMisses, hits, boosts, pickups, skids
        case shieldBlocks, vehiclesSmashed, bestDistance, bestCombo, bestDistrict, bestCleanDistance
        case bestDailyStreak, upgradesBought, skinsBought
        case pilesJumped, hazardsJumped, rampJumps, vehiclesVaulted, flips
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func read(_ key: CodingKeys, _ fallback: Int) -> Int {
            let value = try? container.decodeIfPresent(Int.self, forKey: key)
            return Self.clamp(value ?? fallback)
        }
        rides = read(.rides, 0)
        totalDistance = read(.totalDistance, 0)
        totalCoins = read(.totalCoins, 0)
        goldenCoins = read(.goldenCoins, 0)
        nearMisses = read(.nearMisses, 0)
        hits = read(.hits, 0)
        boosts = read(.boosts, 0)
        pickups = read(.pickups, 0)
        skids = read(.skids, 0)
        shieldBlocks = read(.shieldBlocks, 0)
        vehiclesSmashed = read(.vehiclesSmashed, 0)
        bestDistance = read(.bestDistance, 0)
        bestCombo = max(1, read(.bestCombo, 1))
        bestDistrict = read(.bestDistrict, 0)
        bestCleanDistance = read(.bestCleanDistance, 0)
        bestDailyStreak = read(.bestDailyStreak, 0)
        upgradesBought = read(.upgradesBought, 0)
        skinsBought = read(.skinsBought, 0)
        pilesJumped = read(.pilesJumped, 0)
        hazardsJumped = read(.hazardsJumped, 0)
        rampJumps = read(.rampJumps, 0)
        vehiclesVaulted = read(.vehiclesVaulted, 0)
        flips = read(.flips, 0)
    }

    private static func clamp(_ value: Int) -> Int {
        min(cap, max(0, value))
    }

    /// The numbers after one more ride.
    func adding(_ ride: RideSummary) -> ProfileStats {
        var next = self
        next.rides = Self.clamp(rides + 1)
        next.totalDistance = Self.clamp(totalDistance + Self.clamp(ride.distance))
        next.totalCoins = Self.clamp(totalCoins + Self.clamp(ride.coins))
        next.goldenCoins = Self.clamp(goldenCoins + Self.clamp(ride.goldenCoins))
        next.nearMisses = Self.clamp(nearMisses + Self.clamp(ride.nearMisses))
        next.hits = Self.clamp(hits + Self.clamp(ride.hits))
        next.boosts = Self.clamp(boosts + Self.clamp(ride.boosts))
        next.pickups = Self.clamp(pickups + Self.clamp(ride.pickups))
        next.skids = Self.clamp(skids + Self.clamp(ride.skids))
        next.shieldBlocks = Self.clamp(shieldBlocks + Self.clamp(ride.shieldBlocks))
        next.vehiclesSmashed = Self.clamp(vehiclesSmashed + Self.clamp(ride.vehiclesSmashed))
        next.bestDistance = max(bestDistance, Self.clamp(ride.distance))
        next.bestCombo = max(bestCombo, Self.clamp(ride.bestCombo))
        next.bestDistrict = max(bestDistrict, Self.clamp(ride.districtIndex))
        next.pilesJumped = Self.clamp(pilesJumped + Self.clamp(ride.pilesJumped))
        next.hazardsJumped = Self.clamp(hazardsJumped + Self.clamp(ride.hazardsJumped))
        next.rampJumps = Self.clamp(rampJumps + Self.clamp(ride.rampJumps))
        next.vehiclesVaulted = Self.clamp(vehiclesVaulted + Self.clamp(ride.vehiclesVaulted))
        next.flips = Self.clamp(flips + Self.clamp(ride.flips))
        if ride.hits == 0 {
            next.bestCleanDistance = max(bestCleanDistance, Self.clamp(ride.distance))
        }
        return next
    }
}
