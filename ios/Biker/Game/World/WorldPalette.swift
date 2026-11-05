import Foundation

/// A colour that can be mixed, in 0...1 channels (may go above 1 for glow).
struct ColorValue: Equatable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(_ rgb: RGB) {
        r = rgb.r
        g = rgb.g
        b = rgb.b
    }

    func mixed(with other: ColorValue, _ t: Double) -> ColorValue {
        ColorValue(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    func scaled(_ k: Double) -> ColorValue { ColorValue(r * k, g * k, b * k) }

    func distance(to other: ColorValue) -> Double {
        abs(r - other.r) + abs(g - other.g) + abs(b - other.b)
    }
}

/// The look of a district ("район"): sky, fog, neon, windows and lamps.
struct WorldPalette: Equatable {
    let skyTop: ColorValue
    let skyHigh: ColorValue
    /// Also the fog colour, so far buildings melt into the sky instead of popping in.
    let horizon: ColorValue
    let neonA: ColorValue
    let neonB: ColorValue
    /// Multiplies building facades and windows.
    let windows: ColorValue
    let lamp: ColorValue
    let moon: ColorValue
    let ambient: ColorValue

    static let districts: [WorldPalette] = [
        // Говнотаун: classic violet night, pink and cyan neon.
        WorldPalette(
            skyTop: ColorValue(hex: 0x05030E), skyHigh: ColorValue(hex: 0x1B0E33), horizon: ColorValue(hex: 0x4A2448),
            neonA: ColorValue(hex: 0xFF2E93), neonB: ColorValue(hex: 0x19E6FF), windows: ColorValue(hex: 0xFFE2B8),
            lamp: ColorValue(hex: 0xFFB45A), moon: ColorValue(hex: 0xBFC8FF), ambient: ColorValue(hex: 0x30244A)
        ),
        // Канализация: toxic green haze.
        WorldPalette(
            skyTop: ColorValue(hex: 0x020A06), skyHigh: ColorValue(hex: 0x0C2418), horizon: ColorValue(hex: 0x2E4A26),
            neonA: ColorValue(hex: 0x8CFF2E), neonB: ColorValue(hex: 0x2EFFB8), windows: ColorValue(hex: 0xD8FFB0),
            lamp: ColorValue(hex: 0xC8F060), moon: ColorValue(hex: 0xD0FFC0), ambient: ColorValue(hex: 0x1E3420)
        ),
        // Промзона: orange smog and sodium lamps.
        WorldPalette(
            skyTop: ColorValue(hex: 0x0E0603), skyHigh: ColorValue(hex: 0x2E1408), horizon: ColorValue(hex: 0x6A3418),
            neonA: ColorValue(hex: 0xFF7A10), neonB: ColorValue(hex: 0xFFD21E), windows: ColorValue(hex: 0xFFC890),
            lamp: ColorValue(hex: 0xFF9030), moon: ColorValue(hex: 0xFFD8A0), ambient: ColorValue(hex: 0x3A2214)
        ),
        // Золотой Сортир: purple luxury with gold.
        WorldPalette(
            skyTop: ColorValue(hex: 0x07020F), skyHigh: ColorValue(hex: 0x24083A), horizon: ColorValue(hex: 0x5A2A5C),
            neonA: ColorValue(hex: 0xFFD23A), neonB: ColorValue(hex: 0xC040FF), windows: ColorValue(hex: 0xFFE070),
            lamp: ColorValue(hex: 0xFFD870), moon: ColorValue(hex: 0xFFF0C0), ambient: ColorValue(hex: 0x3A2048)
        ),
        // Жопа Мира: hellish red.
        WorldPalette(
            skyTop: ColorValue(hex: 0x0A0102), skyHigh: ColorValue(hex: 0x2A0508), horizon: ColorValue(hex: 0x5E1410),
            neonA: ColorValue(hex: 0xFF1E3C), neonB: ColorValue(hex: 0xFF7A00), windows: ColorValue(hex: 0xFF9A80),
            lamp: ColorValue(hex: 0xFF5A30), moon: ColorValue(hex: 0xFF8A70), ambient: ColorValue(hex: 0x3A1010)
        ),
    ]

    static func district(_ index: Int) -> WorldPalette {
        districts[max(0, min(districts.count - 1, index))]
    }

    func mixed(with other: WorldPalette, _ t: Double) -> WorldPalette {
        WorldPalette(
            skyTop: skyTop.mixed(with: other.skyTop, t), skyHigh: skyHigh.mixed(with: other.skyHigh, t),
            horizon: horizon.mixed(with: other.horizon, t), neonA: neonA.mixed(with: other.neonA, t),
            neonB: neonB.mixed(with: other.neonB, t), windows: windows.mixed(with: other.windows, t),
            lamp: lamp.mixed(with: other.lamp, t), moon: moon.mixed(with: other.moon, t),
            ambient: ambient.mixed(with: other.ambient, t)
        )
    }
}

/// Fades from one district's palette to the next over a few seconds.
struct PaletteBlender {
    private static let fadeSeconds = 2.5

    private(set) var targetIndex = 0
    private var from = WorldPalette.district(0)
    private var progress = 1.0
    private(set) var current = WorldPalette.district(0)

    /// Starts a fade if the district changed. Returns true when it did.
    mutating func target(_ index: Int) -> Bool {
        guard index != targetIndex else { return false }
        from = current
        targetIndex = index
        progress = 0
        return true
    }

    /// Advances the fade. Returns the new palette while it is changing, nil when settled.
    mutating func advance(dt: Double) -> WorldPalette? {
        guard progress < 1 else { return nil }
        progress = min(1, progress + max(dt, 0.001) / Self.fadeSeconds)
        let eased = progress * progress * (3 - 2 * progress)
        current = from.mixed(with: WorldPalette.district(targetIndex), eased)
        return current
    }
}
