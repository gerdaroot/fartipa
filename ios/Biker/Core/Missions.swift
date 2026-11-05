import Foundation

/// What a mission counts. Per-ride kinds keep the best single ride; the others add up over rides.
enum MissionKind: String, CaseIterable, Codable, Equatable {
    case coinsInRide
    case distanceInRide
    case cleanDistance
    case scoreInRide
    case comboInRide
    case pilesJumped
    case hazardsJumped
    case smashes
    case nearMisses
    case rampJumps
    case flips
    case goldenCoins
    case vaults

    var isPerRide: Bool {
        switch self {
        case .coinsInRide, .distanceInRide, .cleanDistance, .scoreInRide, .comboInRide: return true
        default: return false
        }
    }

    /// This kind's number in one ride.
    func value(in ride: RideSummary) -> Int {
        switch self {
        case .coinsInRide: return ride.coins
        case .distanceInRide: return ride.distance
        case .cleanDistance: return ride.bestCleanStretch
        case .scoreInRide: return ride.score
        case .comboInRide: return ride.bestCombo
        case .pilesJumped: return ride.pilesJumped
        case .hazardsJumped: return ride.hazardsJumped
        case .smashes: return ride.vehiclesSmashed
        case .nearMisses: return ride.nearMisses
        case .rampJumps: return ride.rampJumps
        case .flips: return ride.flips
        case .goldenCoins: return ride.goldenCoins
        case .vaults: return ride.vehiclesVaulted
        }
    }

    /// Goal and reward at tier 0, and what each tier adds: (goal, goal step, reward, reward step).
    var tuning: (goal: Int, goalStep: Int, reward: Int, rewardStep: Int) {
        switch self {
        case .coinsInRide: return (80, 40, 50, 15)
        case .distanceInRide: return (1500, 500, 40, 15)
        case .cleanDistance: return (800, 300, 60, 15)
        case .scoreInRide: return (3000, 1500, 50, 15)
        case .comboInRide: return (3, 1, 50, 15)
        case .pilesJumped: return (5, 2, 50, 10)
        case .hazardsJumped: return (3, 2, 60, 15)
        case .smashes: return (3, 1, 60, 15)
        case .nearMisses: return (15, 5, 40, 10)
        case .rampJumps: return (2, 1, 40, 10)
        case .flips: return (2, 1, 70, 15)
        case .goldenCoins: return (3, 1, 50, 10)
        case .vaults: return (3, 1, 60, 15)
        }
    }

    /// The highest goal that makes sense (the combo stops at ×10).
    var goalCap: Int {
        self == .comboInRide ? ComboMeter.highest : Int.max
    }

    /// The task in Russian, e.g. «Перепрыгни 10 куч».
    func title(goal n: Int) -> String {
        switch self {
        case .coinsInRide: return "Собери \(n) \(RussianWords.plural(n, "говнокоин", "говнокоина", "говнокоинов")) за заезд"
        case .distanceInRide: return "Проедь \(RussianWords.metres(n)) за заезд"
        case .cleanDistance: return "Проедь \(RussianWords.metres(n)) без попаданий"
        case .scoreInRide: return "Набери \(n) \(RussianWords.plural(n, "очко", "очка", "очков")) за заезд"
        case .comboInRide: return "Разгони комбо до ×\(n)"
        case .pilesJumped: return "Перепрыгни \(n) \(RussianWords.plural(n, "кучу", "кучи", "куч"))"
        case .hazardsJumped: return "Перепрыгни \(n) \(RussianWords.plural(n, "люк", "люка", "люков"))"
        case .smashes: return "Сделай \(n) \(RussianWords.plural(n, "таран", "тарана", "таранов")) на газах"
        case .nearMisses: return "Проскочи на волоске \(n) \(RussianWords.plural(n, "раз", "раза", "раз"))"
        case .rampJumps: return "Прыгни с трамплина \(n) \(RussianWords.plural(n, "раз", "раза", "раз"))"
        case .flips: return "Сделай \(n) сальто"
        case .goldenCoins:
            return "Подбери \(n) \(RussianWords.plural(n, "золотую монету", "золотые монеты", "золотых монет"))"
        case .vaults: return "Перелети \(n) \(RussianWords.plural(n, "машину", "машины", "машин")) с трамплина"
        }
    }
}

/// One task with a coin reward. Three are active at a time; a done one is paid and replaced
/// when the ride ends.
struct Mission: Codable, Equatable, Identifiable {
    let id: Int
    let kind: MissionKind
    let goal: Int
    let reward: Int
    private(set) var progress: Int

    init(id: Int, kind: MissionKind, goal: Int, reward: Int, progress: Int = 0) {
        self.id = id
        self.kind = kind
        self.goal = goal
        self.reward = reward
        self.progress = progress
    }

    var isDone: Bool { progress >= goal }
    var title: String { kind.title(goal: goal) }
    var fraction: Double { goal > 0 ? min(1, Double(max(0, progress)) / Double(goal)) : 1 }

    /// Sane numbers: anything else in a save is thrown away.
    var isValid: Bool { goal > 0 && reward >= 0 && progress >= 0 && id > 0 }

    /// The mission after `ride`: the best ride for per-ride kinds, the sum for the others.
    func progressed(by ride: RideSummary) -> Mission {
        let value = max(0, kind.value(in: ride))
        let next = kind.isPerRide ? max(progress, value) : progress + min(goal, value)
        var result = self
        result.progress = min(goal, next)
        return result
    }
}

/// Makes missions. Deterministic: the same serial and level always give the same mission.
enum MissionDeck {
    static let activeCount = 3
    static let maxTier = 15
    private static let rewardStep = 5
    private static let seedFactor: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// What a new player starts with: easy, and each one teaches something.
    static let starting: [Mission] = [
        Mission(id: 1, kind: .coinsInRide, goal: 80, reward: 50),
        Mission(id: 2, kind: .pilesJumped, goal: 3, reward: 40),
        Mission(id: 3, kind: .rampJumps, goal: 2, reward: 40),
    ]

    /// A fresh mission of a kind not in `avoiding`, sized for the player's level.
    static func make(serial: Int, level: Int, avoiding: [MissionKind]) -> Mission {
        var random = SplitMix(seed: UInt64(truncatingIfNeeded: serial) &* seedFactor)
        let open = MissionKind.allCases.filter { !avoiding.contains($0) }
        let choices = open.isEmpty ? MissionKind.allCases : open
        let kind = choices[random.int(below: choices.count)]
        let tier = min(maxTier, max(0, level - 1))
        let tuning = kind.tuning
        let goal = min(kind.goalCap, tuning.goal + tuning.goalStep * tier)
        let rawReward = tuning.reward + tuning.rewardStep * tier
        let reward = (rawReward + rewardStep / 2) / rewardStep * rewardStep
        return Mission(id: serial, kind: kind, goal: goal, reward: reward)
    }
}

/// Russian word forms for numbers.
enum RussianWords {
    /// `one` for 1, 21..., `few` for 2-4, 22-24..., `many` for the rest.
    static func plural(_ number: Int, _ one: String, _ few: String, _ many: String) -> String {
        let value = abs(number)
        let lastTwo = value % 100
        let last = value % 10
        if lastTwo >= 11 && lastTwo <= 14 { return many }
        if last == 1 { return one }
        if last >= 2 && last <= 4 { return few }
        return many
    }

    /// «800 м», «2 км», «1,5 км».
    static func metres(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value) м" }
        let whole = value / 1000
        let tenths = (value % 1000) / 100
        return tenths == 0 ? "\(whole) км" : "\(whole),\(tenths) км"
    }
}

/// The player's level, from experience. Experience comes from score; each new level pays coins.
enum PlayerLevel {
    static let topLevel = 99
    static let scorePerXP = 10
    static let firstStepXP = 200
    static let stepGrowthXP = 100
    static let baseReward = 20
    static let rewardPerLevel = 10

    static func xp(forScore score: Int) -> Int {
        max(0, score) / scorePerXP
    }

    /// Experience needed to go from `level` to the next one.
    static func xpToNext(level: Int) -> Int {
        firstStepXP + stepGrowthXP * max(0, level - 1)
    }

    static func progress(forXP xp: Int) -> LevelProgress {
        var level = 1
        var left = max(0, xp)
        while level < topLevel, left >= xpToNext(level: level) {
            left -= xpToNext(level: level)
            level += 1
        }
        return LevelProgress(level: level, xpIntoLevel: left, xpForLevel: xpToNext(level: level))
    }

    static func level(forXP xp: Int) -> Int {
        progress(forXP: xp).level
    }

    /// Coins for reaching `level`.
    static func reward(reaching level: Int) -> Int {
        baseReward + rewardPerLevel * level
    }

    /// Coins for every level after `from` up to and including `to`.
    static func rewards(from: Int, to: Int) -> Int {
        guard to > from else { return 0 }
        return ((from + 1)...to).reduce(0) { $0 + Self.reward(reaching: $1) }
    }
}

struct LevelProgress: Equatable {
    let level: Int
    let xpIntoLevel: Int
    let xpForLevel: Int

    var fraction: Double {
        xpForLevel > 0 ? min(1, Double(xpIntoLevel) / Double(xpForLevel)) : 1
    }
}
