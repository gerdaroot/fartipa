import SwiftUI

/// Extra colours for the menus: neon accents and a violet button set. Only adds to `Palette`.
extension Palette {
    static let neonPink = Color(red: 1.00, green: 0.30, blue: 0.80)
    static let neonCyan = Color(red: 0.35, green: 0.90, blue: 1.00)
    static let violetTop = Color(red: 0.62, green: 0.40, blue: 1.00)
    static let violetBottom = Color(red: 0.36, green: 0.14, blue: 0.74)
    static let violetEdge = Color(red: 0.15, green: 0.04, blue: 0.34)
    static let night = Color(red: 0.07, green: 0.03, blue: 0.14)

    /// A darker shade of a rarity colour, for card lips and frames.
    static func rarityEdge(_ rarity: Rarity) -> Color {
        switch rarity {
        case .common: return Color(red: 0.20, green: 0.24, blue: 0.30)
        case .rare: return Color(red: 0.05, green: 0.20, blue: 0.45)
        case .epic: return Color(red: 0.25, green: 0.07, blue: 0.42)
        case .legendary: return Color(red: 0.45, green: 0.22, blue: 0.00)
        }
    }
}

/// Names of the menu bitmaps in `Assets.xcassets` and the fixed menu strings.
enum MenuArt {
    static let logo = "MenuLogo"
    static let vignette = "MenuVignette"
    static let backdrop = "MenuBackdrop"
    static let gameTitle = "Пиздец супер крутой байкер 3Д"
    static let authors = "Авторы: gerda, okurok51, yamoo, xanaxx55"
    /// Width over height of `menu-logo.png`.
    static let logoAspect: CGFloat = 1705.0 / 900.0
}

/// Loading screen tips. One is picked per launch.
enum MenuTips {
    static let all: [String] = [
        "Струя с неба сначала мигает. Успей свернуть, пока не обоссали.",
        "Газы копятся от говнокоинов. Жми, когда дорога пустая, и лети.",
        "Проскочил впритирку к машине — получи бонус за наглость.",
        "Дождевик в прокачке: метка под струёй загорается раньше.",
        "Магнит тянет говнокоины сам, руки не пачкаешь.",
        "Заходи каждый день: награда растёт с каждым днём подряд.",
        "Щит держит один удар. Потом снова сам за себя.",
        "Золотой говнокоин заливает в бак впятеро больше газов.",
    ]

    static let launchTip: String = all.randomElement() ?? "Не ешь жёлтый снег."
}

/// Numbers the hub shows that the profile does not keep directly.
enum MenuProgress {
    /// The biker's level: one plus every upgrade level bought.
    static func level(of profile: Profile) -> Int {
        UpgradeTrack.allCases.reduce(1) { total, track in total + profile.level(of: track) }
    }

    static var maxLevel: Int {
        UpgradeTrack.allCases.reduce(1) { total, track in total + track.info.maxLevel }
    }
}
