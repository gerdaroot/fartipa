import Foundation

extension Catalog {
    private static func makeTrail(
        _ id: String, _ name: String, _ price: Int, _ rarity: Rarity, _ pattern: TrailPattern,
        _ primary: UInt32, _ secondary: UInt32, unlockedBy: AchievementID? = nil
    ) -> TrailSkin {
        TrailSkin(
            info: SkinInfo(id: id, name: name, price: price, rarity: rarity, kind: .trail, unlockedBy: unlockedBy),
            style: TrailStyle(pattern: pattern, primary: RGB(hex: primary), secondary: RGB(hex: secondary))
        )
    }

    static let trails: [TrailSkin] = [
        makeTrail("greenfart", "Зелёный пердёж", 0, .common, .cloud, 0x7FBF3F, 0xC8E070),
        makeTrail("greysmoke", "Выхлоп дедовского движка", 200, .common, .smoke, 0x707070, 0xB0B0B0),
        makeTrail("flybuzz", "Рой навозных мух", 500, .common, .flies, 0x202020, 0x70A040),
        makeTrail("bubbles", "Пузыри из канализации", 900, .common, .bubbles, 0x70D0C0, 0xD0FFF0),
        makeTrail("papertail", "Хвост туалетной бумаги", 1500, .rare, .toiletPaper, 0xF8F8F0, 0xD8D8C8),
        makeTrail("sparks", "Искры из-под жопы", 2500, .rare, .sparks, 0xFFB020, 0xFFF080),
        makeTrail("fire", "Огненный понос", 4000, .rare, .fire, 0xFF5A10, 0xFFD020),
        makeTrail("confetti", "Праздничный залп", 6000, .epic, .confetti, 0xFF40A0, 0x40D0FF),
        makeTrail("lightning", "Молния в штанах", 9000, .epic, .lightning, 0x80A0FF, 0xFFFFFF),
        makeTrail("rainbow", "Радужная струя", 14000, .epic, .rainbow, 0xFF3030, 0x3060FF),
        makeTrail("coinrain", "Денежный фонтан", 24000, .legendary, .coins, 0xFFD700, 0xB8860B),
        makeTrail("plasma", "Плазма из кишечника", 40000, .legendary, .plasma, 0xB040FF, 0x40FFE0),
        makeTrail("holyfart", "Святой дух", 0, .epic, .cloud, 0xFFF8D0, 0xFFE070, unlockedBy: .boostFifty),
        makeTrail("dailygas", "Ежедневная вонь", 0, .rare, .smoke, 0x90B050, 0x506020, unlockedBy: .dailySeven),
    ]
}
