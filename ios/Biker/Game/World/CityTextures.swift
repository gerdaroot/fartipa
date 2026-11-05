import UIKit

/// How a tower's windows are laid out.
enum FacadeStyle: Int, CaseIterable {
    case office
    case flats
    case glass
    case brick
}

/// Building facades, neon signs and road signs.
enum CityTextures {
    /// One facade tile is 4 windows across and 8 floors up.
    static let facadeColumns = 4
    static let facadeFloors = 8
    private static let facadeSize = CGSize(width: 256, height: 512)

    /// Crude neon slogans for the roadside.
    static let slogans: [String] = [
        "ГОВНО-БАР 24/7", "ПЕРДИ СВОБОДНО", "СВЕЖИЙ НАВОЗ", "ДРИСТ-ШОП", "ЗАСОР? ЗВОНИ!",
        "ПОНОС-ЭКСПРЕСС", "СОРТИР-ОТЕЛЬ ★★★", "ГОВНОКОИН ↑300%", "КУЧА ДНЯ", "БИО-ГАЗ",
        "ВОНЯЕТ? ЕДЬ!", "ШАУРМА «ПОСЛЕДСТВИЯ»",
    ]

    /// Wall and window colours (`base`) plus a black picture with only the lit windows (`glow`).
    static func facade(_ style: FacadeStyle, seed: UInt64) -> (base: UIImage, glow: UIImage) {
        var baseRandom = SplitMix(seed: seed &* 31 &+ 7)
        var glowRandom = baseRandom
        let base = BikeTextures.renderer(facadeSize).image { context in
            paintFacade(context.cgContext, style: style, lit: false, random: &baseRandom)
        }
        let glow = BikeTextures.renderer(facadeSize).image { context in
            paintFacade(context.cgContext, style: style, lit: true, random: &glowRandom)
        }
        return (base, glow)
    }

    private static func wallColor(_ style: FacadeStyle) -> UIColor {
        switch style {
        case .office: return UIColor(red: 0.16, green: 0.17, blue: 0.2, alpha: 1)
        case .flats: return UIColor(red: 0.22, green: 0.19, blue: 0.17, alpha: 1)
        case .glass: return UIColor(red: 0.07, green: 0.1, blue: 0.14, alpha: 1)
        case .brick: return UIColor(red: 0.3, green: 0.14, blue: 0.1, alpha: 1)
        }
    }

    /// Paints the same window grid twice with the same random sequence: once as the wall, once as light.
    private static func paintFacade(_ cg: CGContext, style: FacadeStyle, lit: Bool, random: inout SplitMix) {
        let size = facadeSize
        cg.setFillColor(lit ? UIColor.black.cgColor : wallColor(style).cgColor)
        cg.fill(CGRect(origin: .zero, size: size))
        let cellW = size.width / CGFloat(facadeColumns)
        let cellH = size.height / CGFloat(facadeFloors)
        let inset = windowInset(style, cellW: cellW, cellH: cellH)
        let litChance = style == .office ? 0.55 : 0.38
        for floor in 0..<facadeFloors {
            let bandLit = random.chance(style == .office ? 0.6 : 0.4)
            for column in 0..<facadeColumns {
                let on = style == .office ? bandLit && random.chance(0.85) : random.chance(litChance)
                let tone = random.unit()
                let rect = CGRect(
                    x: CGFloat(column) * cellW + inset.width, y: CGFloat(floor) * cellH + inset.height,
                    width: cellW - inset.width * 2, height: cellH - inset.height * 2
                )
                paintWindow(cg, rect: rect, on: on, tone: tone, lit: lit)
            }
        }
        if !lit, style == .glass { paintMullions(cg, size: size, cellW: cellW) }
    }

    private static func windowInset(_ style: FacadeStyle, cellW: CGFloat, cellH: CGFloat) -> CGSize {
        switch style {
        case .office: return CGSize(width: cellW * 0.06, height: cellH * 0.18)
        case .flats: return CGSize(width: cellW * 0.22, height: cellH * 0.24)
        case .glass: return CGSize(width: cellW * 0.03, height: cellH * 0.05)
        case .brick: return CGSize(width: cellW * 0.26, height: cellH * 0.2)
        }
    }

    private static func paintWindow(_ cg: CGContext, rect: CGRect, on: Bool, tone: Double, lit: Bool) {
        if lit {
            guard on else { return }
            let warm = UIColor(red: 1, green: CGFloat(0.72 + tone * 0.2), blue: CGFloat(0.38 + tone * 0.2), alpha: 1)
            let cool = UIColor(red: CGFloat(0.65 + tone * 0.2), green: 0.85, blue: 1, alpha: 1)
            let color = tone > 0.72 ? cool : warm
            Painter.verticalGradient(cg, rect: rect, colors: [color.withAlphaComponent(0.7), color], locations: [0, 1])
            if tone < 0.25 {
                cg.setFillColor(UIColor(white: 0, alpha: 0.55).cgColor)
                cg.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.4, height: rect.height))
            }
        } else {
            let glass = UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1)
            cg.setFillColor((on ? UIColor(red: 0.5, green: 0.42, blue: 0.3, alpha: 1) : glass).cgColor)
            cg.fill(rect)
        }
    }

    private static func paintMullions(_ cg: CGContext, size: CGSize, cellW: CGFloat) {
        cg.setFillColor(UIColor(white: 0.32, alpha: 1).cgColor)
        for column in 0...facadeColumns {
            cg.fill(CGRect(x: CGFloat(column) * cellW - 1.5, y: 0, width: 3, height: size.height))
        }
    }

    /// Glowing letters in a neon tube frame on a black board.
    static func neonSign(_ text: String, color: ColorValue, accent: ColorValue) -> UIImage {
        let size = CGSize(width: 512, height: 144)
        return BikeTextures.renderer(size).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(white: 0.02, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            let frame = CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 10, color: accent.ui.cgColor)
            Painter.roundedFrame(cg, rect: frame, radius: 18, color: accent.ui, width: 5)
            cg.restoreGState()
            let core = color.mixed(with: ColorValue(1, 1, 1), 0.55).ui
            Painter.text(text, in: frame.insetBy(dx: 16, dy: 14), color: core, glow: color.ui)
        }
    }

    /// A green motorway sign: big title over a smaller line.
    static func roadSign(title: String, detail: String) -> UIImage {
        let size = CGSize(width: 512, height: 208)
        return BikeTextures.renderer(size).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.02, green: 0.36, blue: 0.2, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            Painter.roundedFrame(cg, rect: CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16), radius: 14, color: .white, width: 6)
            Painter.text(title, in: CGRect(x: 20, y: 22, width: size.width - 40, height: 96), color: .white, glow: nil, weight: .bold)
            Painter.text(detail, in: CGRect(x: 20, y: 118, width: size.width - 40, height: 66), color: UIColor(red: 1, green: 0.92, blue: 0.5, alpha: 1), glow: nil, weight: .semibold)
        }
    }

    /// Flat text on a coloured plate: lorry doors, number plates, tunnel and bridge names.
    static func plate(_ text: String, background: UIColor, foreground: UIColor, size: CGSize) -> UIImage {
        BikeTextures.renderer(size).image { context in
            let cg = context.cgContext
            cg.setFillColor(background.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            let border = max(2, size.height * 0.04)
            Painter.roundedFrame(cg, rect: CGRect(origin: .zero, size: size).insetBy(dx: border, dy: border), radius: border * 2, color: foreground, width: border)
            Painter.text(text, in: CGRect(origin: .zero, size: size).insetBy(dx: border * 4, dy: border * 3), color: foreground, glow: nil, weight: .black)
        }
    }
}
