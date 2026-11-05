import Foundation

extension Catalog {
    private static func makeBike(
        _ id: String, _ name: String, _ price: Int, _ rarity: Rarity, _ body: BikeBody,
        _ primary: UInt32, _ secondary: UInt32, _ glow: UInt32,
        wheels: WheelStyle = .standard, unlockedBy: AchievementID? = nil
    ) -> BikeSkin {
        BikeSkin(
            info: SkinInfo(id: id, name: name, price: price, rarity: rarity, kind: .bike, unlockedBy: unlockedBy),
            style: BikeStyle(
                body: body, primary: RGB(hex: primary), secondary: RGB(hex: secondary), glow: RGB(hex: glow),
                wheels: wheels
            )
        )
    }

    static let bikes: [BikeSkin] = [
        // Обычные
        makeBike("rusty", "Ржавчик", 0, .common, .naked, 0x8A5A2B, 0x4A3A2A, 0xFFB347),
        makeBike("mopedik", "Мопед деда Вити", 150, .common, .scooter, 0x6FA8A0, 0xD8D0B8, 0xFFE9A0),
        makeBike("sport", "Спорт-понос", 250, .common, .sport, 0xC8322B, 0x202020, 0xFF6A4D),
        makeBike("dirtbag", "Грязный ублюдок", 400, .common, .dirt, 0x7A6A30, 0x2E2A1A, 0xC8E040, wheels: .chunky),
        makeBike("chopper", "Чоппер Петровича", 600, .common, .chopper, 0x2B2B33, 0xB8B8C0, 0xFF8C42, wheels: .spoked),
        makeBike("pensioner", "Пенсионный круизёр", 800, .common, .cruiser, 0x5B6E8C, 0xE0D8C8, 0xA0C8FF, wheels: .whitewall),
        makeBike("colkhoz", "Трактор «Колхозник»", 1000, .common, .tractor, 0x3F7D3A, 0xD9A520, 0xE8E060, wheels: .chunky),
        makeBike("courier", "Говнокурьер", 1200, .common, .scooter, 0x35B0A0, 0xFFFFFF, 0x60FFD8),
        // Редкие
        makeBike("turdmobile", "Говномобиль", 1800, .rare, .turd, 0x6B4423, 0x3D2613, 0xA8E040),
        makeBike("toilet", "Белый унитаз", 2400, .rare, .toilet, 0xF2F2EE, 0x9AA8B0, 0x80D0FF, wheels: .toiletRolls),
        makeBike("sewerrat", "Канализационная крыса", 3000, .rare, .naked, 0x4F5B4A, 0x8F8F70, 0x90FF60),
        makeBike("hooligan", "Гопник на спорте", 3600, .rare, .sport, 0xEDEDED, 0x1A3FAA, 0x5C8CFF, wheels: .neon),
        makeBike("donutcop", "Участковый", 4200, .rare, .cruiser, 0x1C3A78, 0xF4F4F4, 0xFF3030, wheels: .donuts),
        makeBike("mudpig", "Свинья в грязи", 4800, .rare, .dirt, 0xE89AA8, 0x5B3A1E, 0xFFC0D0, wheels: .chunky),
        // Эпические
        makeBike("plasmaturd", "Плазменная какашка", 7000, .epic, .turd, 0x3C1E70, 0x18C8B8, 0x40FFE0, wheels: .neon),
        makeBike("hellchopper", "Адский чоппер", 8500, .epic, .chopper, 0x7A0F0F, 0x151515, 0xFF4A10, wheels: .flaming),
        makeBike("cybertoilet", "Киберунитаз 2077", 10000, .epic, .toilet, 0x1A1A2E, 0xFF2E93, 0x00F0FF, wheels: .neon),
        makeBike("gasrocket", "Газовая ракета", 12000, .epic, .rocket, 0xC0C6CC, 0xD62828, 0xFF9F1C, wheels: .flaming),
        makeBike("goldtractor", "Позолоченный комбайн", 14000, .epic, .tractor, 0xD4AF37, 0x5A4410, 0xFFE27A, wheels: .chunky),
        // Легендарные
        makeBike("goldtoilet", "Золотой унитаз", 20000, .legendary, .toilet, 0xFFD700, 0xB8860B, 0xFFF2A0, wheels: .toiletRolls),
        makeBike("ghostrider", "Призрачный дристун", 28000, .legendary, .chopper, 0x0E1014, 0xA8FF60, 0x80FF40, wheels: .flaming),
        makeBike("spaceshit", "Космический дерьмолёт", 38000, .legendary, .rocket, 0x101840, 0xE8E8FF, 0x8080FF, wheels: .neon),
        makeBike("emperor", "Трон Императора Кучи", 50000, .legendary, .turd, 0xFFC107, 0x6A1B9A, 0xFFEA70, wheels: .donuts),
        // За достижения
        makeBike("veteranbike", "Ветеран говнодорог", 0, .rare, .cruiser, 0x4B5320, 0xC2B280, 0xE0D060, wheels: .spoked, unlockedBy: .rideHundred),
        makeBike("armoredloo", "Бронесортир", 0, .epic, .toilet, 0x556B2F, 0x2F2F2F, 0xB0FF40, wheels: .chunky, unlockedBy: .surviveSewer),
        makeBike("worldendbike", "Конец Света", 0, .legendary, .rocket, 0x220000, 0xFF2200, 0xFF6000, wheels: .flaming, unlockedBy: .reachWorldEnd),
    ]
}
