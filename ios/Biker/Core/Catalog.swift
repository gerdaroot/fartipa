import Foundation

/// A colour with channels from 0 to 1. Graphics turn it into whatever they need.
struct RGB: Equatable, Codable {
    let r: Double
    let g: Double
    let b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// From a web-style number such as 0xFF8800.
    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
}

enum Rarity: String, CaseIterable, Codable, Equatable {
    case common
    case rare
    case epic
    case legendary

    var title: String {
        switch self {
        case .common: return "обычный"
        case .rare: return "редкий"
        case .epic: return "эпический"
        case .legendary: return "легендарный"
        }
    }
}

enum SkinKind: String, CaseIterable, Codable, Equatable {
    case bike
    case rider
    case trail
}

/// What the shop needs to know about any skin.
struct SkinInfo: Equatable {
    let id: String
    let name: String
    /// In coins. Ignored when `unlockedBy` is set: then the achievement gives it for free.
    let price: Int
    let rarity: Rarity
    let kind: SkinKind
    let unlockedBy: AchievementID?
}

enum BikeBody: String, CaseIterable, Equatable {
    case naked, sport, chopper, dirt, scooter, cruiser, toilet, turd, tractor, rocket
}

enum WheelStyle: String, CaseIterable, Equatable {
    case standard, spoked, chunky, whitewall, flaming, toiletRolls, donuts, neon
}

struct BikeStyle: Equatable {
    let body: BikeBody
    let primary: RGB
    let secondary: RGB
    let glow: RGB
    let wheels: WheelStyle
}

struct BikeSkin: Equatable {
    let info: SkinInfo
    let style: BikeStyle

    var id: String { info.id }
    var name: String { info.name }
}

enum RiderAccessory: String, CaseIterable, Equatable {
    case none, crown, horns, poopHat, mohawk, cape, gasMask, wings, plunger, halo, toiletSeat, propeller, ushanka
}

struct RiderStyle: Equatable {
    let jacket: RGB
    let pants: RGB
    let helmet: RGB
    let visor: RGB
    let accessory: RiderAccessory
}

struct RiderSkin: Equatable {
    let info: SkinInfo
    let style: RiderStyle

    var id: String { info.id }
    var name: String { info.name }
}

enum TrailPattern: String, CaseIterable, Equatable {
    case cloud, rainbow, fire, sparks, bubbles, smoke, lightning, confetti, flies, toiletPaper, coins, plasma
}

struct TrailStyle: Equatable {
    let pattern: TrailPattern
    let primary: RGB
    let secondary: RGB
}

/// A boost exhaust ("выхлоп").
struct TrailSkin: Equatable {
    let info: SkinInfo
    let style: TrailStyle

    var id: String { info.id }
    var name: String { info.name }
}

/// All skins. The lists themselves live in `CatalogBikes`, `CatalogRiders` and `CatalogTrails`.
enum Catalog {
    static let starterBikeId = "rusty"
    static let starterRiderId = "leather"
    static let starterTrailId = "greenfart"

    static let allInfos: [SkinInfo] = {
        var infos: [SkinInfo] = bikes.map { $0.info }
        infos += riders.map { $0.info }
        infos += trails.map { $0.info }
        return infos
    }()

    private static let infosById: [String: SkinInfo] = Dictionary(
        allInfos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    static func info(id: String) -> SkinInfo? { infosById[id] }
    static func bike(id: String) -> BikeSkin? { bikes.first { $0.id == id } }
    static func rider(id: String) -> RiderSkin? { riders.first { $0.id == id } }
    static func trail(id: String) -> TrailSkin? { trails.first { $0.id == id } }

    /// Skins that come free with a new profile.
    static var freeIds: [String] {
        allInfos.filter { $0.price == 0 && $0.unlockedBy == nil }.map { $0.id }
    }

    /// Skins an achievement gives.
    static func skinIds(unlockedBy achievement: AchievementID) -> [String] {
        allInfos.filter { $0.unlockedBy == achievement }.map { $0.id }
    }
}
