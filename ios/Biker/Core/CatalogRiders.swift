import Foundation

extension Catalog {
    private static func makeRider(
        _ id: String, _ name: String, _ price: Int, _ rarity: Rarity,
        jacket: UInt32, pants: UInt32, helmet: UInt32, visor: UInt32,
        _ accessory: RiderAccessory = .none, unlockedBy: AchievementID? = nil
    ) -> RiderSkin {
        RiderSkin(
            info: SkinInfo(id: id, name: name, price: price, rarity: rarity, kind: .rider, unlockedBy: unlockedBy),
            style: RiderStyle(
                jacket: RGB(hex: jacket), pants: RGB(hex: pants), helmet: RGB(hex: helmet), visor: RGB(hex: visor),
                accessory: accessory
            )
        )
    }

    static let riders: [RiderSkin] = [
        // Обычные
        makeRider("leather", "Кожанка с рынка", 0, .common, jacket: 0x2A2420, pants: 0x25303F, helmet: 0x30302E, visor: 0x88B0C8),
        makeRider("tracksuit", "Гопник в трениках", 100, .common, jacket: 0x1C2E8C, pants: 0x1C2E8C, helmet: 0xEEEEEE, visor: 0x303030),
        makeRider("racer", "Гонщик районный", 200, .common, jacket: 0xC8322B, pants: 0x202020, helmet: 0xC8322B, visor: 0x101010),
        makeRider("dacha", "Дачник", 300, .common, jacket: 0x7FA65A, pants: 0x4C4A3A, helmet: 0xD8C9A0, visor: 0x6E8C70, .ushanka),
        makeRider("plumber", "Сантехник Михалыч", 450, .common, jacket: 0x28508C, pants: 0x28508C, helmet: 0xE05A1C, visor: 0xB8D0E0, .plunger),
        makeRider("courierguy", "Доставщик сортирный", 600, .common, jacket: 0x35B0A0, pants: 0x303030, helmet: 0x35B0A0, visor: 0xE0F0F0),
        makeRider("janitor", "Дворник Ашот", 750, .common, jacket: 0xE87B1C, pants: 0x3A3A3A, helmet: 0xE8E8E0, visor: 0x808080),
        makeRider("student", "Студент на кураже", 900, .common, jacket: 0x9060B0, pants: 0x2C3E70, helmet: 0xF0D060, visor: 0x303050, .propeller),
        makeRider("cowboy", "Ковбой из Мытищ", 1100, .common, jacket: 0x9C6B30, pants: 0x3B5B8C, helmet: 0x7B4F20, visor: 0x302010),
        makeRider("punk", "Панк Вонючка", 1300, .common, jacket: 0x151515, pants: 0x7A1020, helmet: 0x151515, visor: 0x40FF70, .mohawk),
        // Редкие
        makeRider("turdman", "Говночел", 1800, .rare, jacket: 0x6B4423, pants: 0x4A2E17, helmet: 0x6B4423, visor: 0xE8E040, .poopHat),
        makeRider("hazmat", "Химзащита", 2200, .rare, jacket: 0xE8D020, pants: 0xE8D020, helmet: 0xE8D020, visor: 0x305030, .gasMask),
        makeRider("devil", "Чертила", 2600, .rare, jacket: 0x9A1010, pants: 0x300808, helmet: 0xC81818, visor: 0xFFD040, .horns),
        makeRider("doctor", "Проктолог", 3000, .rare, jacket: 0xF4F4F4, pants: 0xD8E8F0, helmet: 0xF4F4F4, visor: 0x60C0E0, .gasMask),
        makeRider("sewerking", "Принц канализации", 3400, .rare, jacket: 0x38503A, pants: 0x20301F, helmet: 0x5A6A30, visor: 0x90FF60, .crown),
        makeRider("batman", "Ночной говносек", 3800, .rare, jacket: 0x14141C, pants: 0x14141C, helmet: 0x20202C, visor: 0xFFF080, .cape),
        makeRider("tourist", "Турист в сланцах", 4200, .rare, jacket: 0xFF70A0, pants: 0xF0E8C0, helmet: 0x60C8E0, visor: 0x101010),
        makeRider("loohead", "Голова в унитазе", 4600, .rare, jacket: 0xB0C0C8, pants: 0x505860, helmet: 0xF2F2EE, visor: 0x80D0FF, .toiletSeat),
        // Эпические
        makeRider("fartangel", "Ангел пердежа", 7000, .epic, jacket: 0xF8F4E0, pants: 0xE8E0B8, helmet: 0xFFF8D0, visor: 0x90E0FF, .wings),
        makeRider("hellrider", "Адский наездник", 8500, .epic, jacket: 0x220808, pants: 0x100404, helmet: 0x301010, visor: 0xFF4010, .horns),
        makeRider("astronaut", "Космонавт Гагарьев", 10000, .epic, jacket: 0xECECEC, pants: 0xECECEC, helmet: 0xFFFFFF, visor: 0xE0A040),
        makeRider("cyberpunk", "Киберпанк с унитаза", 12000, .epic, jacket: 0x1A1A2E, pants: 0x2E1A40, helmet: 0xFF2E93, visor: 0x00F0FF, .mohawk),
        makeRider("saint", "Святой засранец", 14000, .epic, jacket: 0xF0E8D0, pants: 0xD8C890, helmet: 0xF8F0D8, visor: 0xFFE060, .halo),
        // Легендарные
        makeRider("king", "Король кучи", 20000, .legendary, jacket: 0x6A1B9A, pants: 0x3A0F5A, helmet: 0xFFD700, visor: 0xFFF8C0, .crown),
        makeRider("goldenboy", "Золотая струя", 26000, .legendary, jacket: 0xFFD700, pants: 0xD4AF37, helmet: 0xFFE34D, visor: 0xFFFFFF, .cape),
        makeRider("demonlord", "Повелитель поноса", 34000, .legendary, jacket: 0x240A3A, pants: 0x12041E, helmet: 0x50108A, visor: 0xA8FF40, .wings),
        makeRider("emperorsuit", "Император Сортира", 45000, .legendary, jacket: 0xB8860B, pants: 0x7A0F0F, helmet: 0xFFD700, visor: 0xFF3030, .crown),
        // За достижения
        makeRider("firstblood", "Первый блин", 0, .common, jacket: 0xC89050, pants: 0x70502A, helmet: 0xE8C080, visor: 0x503010, unlockedBy: .firstRide),
        makeRider("dodger", "Мастер увёрток", 0, .rare, jacket: 0x2090A0, pants: 0x104850, helmet: 0x40C8D8, visor: 0x102030, .cape, unlockedBy: .nearMissHundred),
        makeRider("millionaire", "Говномиллионер", 0, .epic, jacket: 0x0F4A28, pants: 0x0A3019, helmet: 0xD4AF37, visor: 0x80FF80, .crown, unlockedBy: .coinsTenThousand),
        makeRider("untouchable", "Сухой Вася", 0, .epic, jacket: 0xF4F0D8, pants: 0xC8C0A0, helmet: 0xE0E8F0, visor: 0x60A0E0, .halo, unlockedBy: .cleanRide),
        makeRider("smasher", "Таран", 0, .rare, jacket: 0x707880, pants: 0x303840, helmet: 0xA0A8B0, visor: 0xFF8020, .horns, unlockedBy: .smashTwenty),
    ]
}
