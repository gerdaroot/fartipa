import Foundation

enum ShopKind: String, Codable {
    case bike
    case rider
}

struct ShopItem: Equatable {
    let id: String
    let name: String
    let price: Int
    let kind: ShopKind
}

enum Shop {
    static let coinsPerStar = 20

    static let bikes = [
        ShopItem(id: "rusty", name: "Ржавчик", price: 0, kind: .bike),
        ShopItem(id: "sport", name: "Спорт", price: 80, kind: .bike),
        ShopItem(id: "chopper", name: "Чоппер", price: 200, kind: .bike),
        ShopItem(id: "turdmobile", name: "Говномобиль", price: 350, kind: .bike),
        ShopItem(id: "toilet", name: "Золотой унитаз", price: 1000, kind: .bike),
    ]

    static let riders = [
        ShopItem(id: "leather", name: "Кожанка", price: 0, kind: .rider),
        ShopItem(id: "racer", name: "Гонщик", price: 50, kind: .rider),
        ShopItem(id: "turdman", name: "Говночел", price: 120, kind: .rider),
        ShopItem(id: "hazmat", name: "Химзащита", price: 250, kind: .rider),
        ShopItem(id: "king", name: "Король кучи", price: 600, kind: .rider),
    ]

    static let all = bikes + riders

    static func item(id: String) -> ShopItem? {
        all.first { $0.id == id }
    }

    /// Coins for stars the player had not earned on that level before.
    static func starReward(oldStars: Int, newStars: Int) -> Int {
        max(0, newStars - oldStars) * coinsPerStar
    }
}

enum PurchaseResult: Equatable {
    case bought
    case alreadyOwned
    case notEnoughCoins
}

/// Everything saved between rides.
struct Profile: Codable, Equatable {
    private(set) var coins = 0
    private(set) var bestScore = 0
    private(set) var owned: Set<String> = ["rusty", "leather"]
    private(set) var bikeId = "rusty"
    private(set) var riderId = "leather"

    func owns(_ item: ShopItem) -> Bool {
        owned.contains(item.id)
    }

    func isSelected(_ item: ShopItem) -> Bool {
        item.id == (item.kind == .bike ? bikeId : riderId)
    }

    mutating func earn(_ amount: Int) {
        coins += max(0, amount)
    }

    /// Returns true when this score is a new record.
    mutating func recordScore(_ score: Int) -> Bool {
        guard score > bestScore else { return false }
        bestScore = score
        return true
    }

    mutating func buy(_ item: ShopItem) -> PurchaseResult {
        if owns(item) { return .alreadyOwned }
        guard coins >= item.price else { return .notEnoughCoins }
        coins -= item.price
        owned.insert(item.id)
        return .bought
    }

    mutating func select(_ item: ShopItem) {
        guard owns(item) else { return }
        switch item.kind {
        case .bike: bikeId = item.id
        case .rider: riderId = item.id
        }
    }

    /// Reads saved data; anything broken or unknown falls back to the starting kit.
    static func parse(_ data: Data?) -> Profile {
        guard let data, let saved = try? JSONDecoder().decode(Profile.self, from: data) else { return Profile() }
        var clean = Profile()
        clean.coins = max(0, saved.coins)
        clean.bestScore = max(0, saved.bestScore)
        clean.owned.formUnion(saved.owned.filter { Shop.item(id: $0) != nil })
        if let bike = Shop.item(id: saved.bikeId), bike.kind == .bike, clean.owned.contains(bike.id) {
            clean.bikeId = bike.id
        }
        if let rider = Shop.item(id: saved.riderId), rider.kind == .rider, clean.owned.contains(rider.id) {
            clean.riderId = rider.id
        }
        return clean
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
