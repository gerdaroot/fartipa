import Foundation

/// Texts and prices of one upgrade track.
struct UpgradeInfo: Equatable {
    let name: String
    let description: String
    let maxLevel: Int
    let basePrice: Double
    let priceGrowth: Double
}

/// The garage upgrades. Levels run from 0 (stock) to `info.maxLevel`.
enum UpgradeTrack: String, CaseIterable, Codable, Equatable {
    case engine
    case handling
    case tires
    case magnet
    case armor
    case shield
    case tank
    case beans
    case piggy
    case combo
    case luck
    case raincoat

    private static let priceStep = 5.0

    var info: UpgradeInfo {
        switch self {
        case .engine:
            return UpgradeInfo(
                name: "Движок", description: "Больше дури, выше предельная скорость.",
                maxLevel: 10, basePrice: 60, priceGrowth: 1.5)
        case .handling:
            return UpgradeInfo(
                name: "Тормоза и руль", description: "Байк шустрее виляет между струями.",
                maxLevel: 8, basePrice: 50, priceGrowth: 1.5)
        case .tires:
            return UpgradeInfo(
                name: "Покрышки", description: "На куче заносит меньше и не так надолго.",
                maxLevel: 6, basePrice: 40, priceGrowth: 1.7)
        case .magnet:
            return UpgradeInfo(
                name: "Магнит", description: "Шире сбор монет, говномагнит работает дольше.",
                maxLevel: 8, basePrice: 50, priceGrowth: 1.5)
        case .armor:
            return UpgradeInfo(
                name: "Бронекуртка", description: "Запасные жизни и дольше неуязвимость после удара.",
                maxLevel: 5, basePrice: 200, priceGrowth: 2.0)
        case .shield:
            return UpgradeInfo(
                name: "Щит", description: "Лопух держится дольше.",
                maxLevel: 6, basePrice: 60, priceGrowth: 1.7)
        case .tank:
            return UpgradeInfo(
                name: "Газовый баллон", description: "Больше газов влезает, дольше летишь.",
                maxLevel: 8, basePrice: 60, priceGrowth: 1.5)
        case .beans:
            return UpgradeInfo(
                name: "Ядрёная фасоль", description: "Каждая монета пучит сильнее, баллон полнится быстрее.",
                maxLevel: 8, basePrice: 50, priceGrowth: 1.5)
        case .piggy:
            return UpgradeInfo(
                name: "Копилка", description: "Каждая говномонета стоит дороже.",
                maxLevel: 10, basePrice: 80, priceGrowth: 1.5)
        case .combo:
            return UpgradeInfo(
                name: "Комбо", description: "Множитель за опасные манёвры гаснет медленнее.",
                maxLevel: 6, basePrice: 40, priceGrowth: 1.7)
        case .luck:
            return UpgradeInfo(
                name: "Удача", description: "Подарки на дороге попадаются чаще.",
                maxLevel: 8, basePrice: 60, priceGrowth: 1.5)
        case .raincoat:
            return UpgradeInfo(
                name: "Дождевик", description: "Метка на дороге появляется раньше, чем польёт.",
                maxLevel: 6, basePrice: 60, priceGrowth: 1.7)
        }
    }

    /// What it costs to go from `level - 1` to `level`. Nil when there is no such level.
    func price(ofLevel level: Int) -> Int? {
        guard level >= 1, level <= info.maxLevel else { return nil }
        let raw = info.basePrice * pow(info.priceGrowth, Double(level - 1))
        return Int((raw / Self.priceStep).rounded()) * Int(Self.priceStep)
    }

    /// The whole track from stock to the top.
    var totalPrice: Int {
        (1...info.maxLevel).reduce(0) { $0 + (price(ofLevel: $1) ?? 0) }
    }

    /// Every track from stock to the top.
    static var totalPriceOfEverything: Int {
        allCases.reduce(0) { $0 + $1.totalPrice }
    }

    func clamped(level: Int) -> Int {
        min(info.maxLevel, max(0, level))
    }

    /// The loadout number this track mainly drives. It strictly grows with each level.
    var keyMetric: KeyPath<RunLoadout, Double> {
        switch self {
        case .engine: return \RunLoadout.topSpeed
        case .handling: return \RunLoadout.steerRate
        case .tires: return \RunLoadout.skidSpeedFactor
        case .magnet: return \RunLoadout.magnetSeconds
        case .armor: return \RunLoadout.invulnerableSeconds
        case .shield: return \RunLoadout.shieldSeconds
        case .tank: return \RunLoadout.boostCapacity
        case .beans: return \RunLoadout.boostPerCoin
        case .piggy: return \RunLoadout.coinMultiplier
        case .combo: return \RunLoadout.comboSeconds
        case .luck: return \RunLoadout.pickupRate
        case .raincoat: return \RunLoadout.warningSeconds
        }
    }

    /// The value of `keyMetric` at a level, with every other track stock.
    func effectValue(level: Int) -> Double {
        RunLoadout(levels: [self: level])[keyPath: keyMetric]
    }

    /// A short Russian line for the garage, such as "59 м/с".
    func effectText(level: Int) -> String {
        let loadout = RunLoadout(levels: [self: level])
        let value = loadout[keyPath: keyMetric]
        switch self {
        case .engine: return "\(Int(value.rounded())) м/с"
        case .handling: return "\(Int(value.rounded())) м/с вбок"
        case .tires: return "теряешь \(Int(((1 - value) * 100).rounded()))% скорости"
        case .magnet: return "магнит \(Int(value.rounded())) с"
        case .armor: return "жизней: \(loadout.startingLives)"
        case .shield: return String(format: "щит %.1f с", value)
        case .tank: return String(format: "газы %.1f с", value)
        case .beans: return String(format: "+%.1f с газов за 10 монет", value * 10)
        case .piggy: return String(format: "монеты ×%.1f", value)
        case .combo: return String(format: "комбо %.1f с", value)
        case .luck: return String(format: "подарки ×%.2f", value)
        case .raincoat: return String(format: "метка %.1f с", value)
        }
    }
}

/// What the bike can do in one ride. Computed from upgrade levels and passed to `BikeRun`.
struct RunLoadout: Equatable {
    /// Top speed, metres per second.
    let topSpeed: Double
    /// Sideways speed, metres per second.
    let steerRate: Double
    /// How long a poop pile holds the bike back.
    let skidSeconds: Double
    /// Share of speed kept while skidding.
    let skidSpeedFactor: Double
    /// How far sideways a coin is picked up without the magnet.
    let coinReach: Double
    let magnetSeconds: Double
    let startingLives: Int
    /// Safe time after a hit.
    let invulnerableSeconds: Double
    let shieldSeconds: Double
    /// Seconds of gas in a full tank.
    let boostCapacity: Double
    /// Seconds of gas one coin adds.
    let boostPerCoin: Double
    let coinMultiplier: Double
    /// Seconds before the combo drops by one.
    let comboSeconds: Double
    /// Multiplies how often pickups appear.
    let pickupRate: Double
    /// Seconds a stream's marker shows before it pours, before the district scales it.
    let warningSeconds: Double

    static let base = RunLoadout()

    /// Every track at its top level.
    static let maxed = RunLoadout(
        levels: Dictionary(uniqueKeysWithValues: UpgradeTrack.allCases.map { ($0, $0.info.maxLevel) })
    )

    /// Levels out of range are clamped; a missing track is stock.
    init(levels: [UpgradeTrack: Int] = [:]) {
        func level(_ track: UpgradeTrack) -> Double {
            Double(track.clamped(level: levels[track] ?? 0))
        }
        topSpeed = 55 + 2 * level(.engine)
        steerRate = 10 + level(.handling)
        skidSeconds = 1.4 - 0.18 * level(.tires)
        skidSpeedFactor = 0.55 + 0.05 * level(.tires)
        coinReach = 1.2 + 0.1 * level(.magnet)
        magnetSeconds = 6 + level(.magnet)
        startingLives = 3 + (Int(level(.armor)) + 1) / 2
        invulnerableSeconds = 1.4 + 0.2 * level(.armor)
        shieldSeconds = 6 + 1.5 * level(.shield)
        boostCapacity = 3 + 0.5 * level(.tank)
        boostPerCoin = 0.03 + 0.01 * level(.beans)
        coinMultiplier = 1 + 0.1 * level(.piggy)
        comboSeconds = 3 + 0.5 * level(.combo)
        pickupRate = 1 + 0.15 * level(.luck)
        warningSeconds = 1.1 + 0.2 * level(.raincoat)
    }
}
