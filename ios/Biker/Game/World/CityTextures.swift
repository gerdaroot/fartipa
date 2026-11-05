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
    static let facadeSize = CGSize(width: 256, height: 512)

    /// Crude neon slogans for the roadside.
    static let slogans: [String] = [
        "ГОВНО-БАР 24/7", "ПЕРДИ СВОБОДНО", "СВЕЖИЙ НАВОЗ", "ДРИСТ-ШОП", "ЗАСОР? ЗВОНИ!",
        "ПОНОС-ЭКСПРЕСС", "СОРТИР-ОТЕЛЬ ★★★", "ГОВНОКОИН ↑300%", "КУЧА ДНЯ", "БИО-ГАЗ",
        "ВОНЯЕТ? ЕДЬ!", "ШАУРМА «ПОСЛЕДСТВИЯ»", "ПИЗДЕЦ СУПЕР КРУТОЙ БАЙКЕР 3Д",
    ]

    /// Wall and window colours (`base`) plus a black picture with only the lit windows (`glow`).
    /// The first window grid of the style, plain walls; `seed` is kept for older callers.
    static func facade(_ style: FacadeStyle, seed: UInt64) -> (base: UIImage, glow: UIImage) {
        facade(TexFacadeLook(style: style, variant: 0), wall: nil)
    }

    /// One look of a facade. `wall` is a photo tiled under the windows (nil: flat colour).
    static func facade(_ look: TexFacadeLook, wall: CGImage?, baseSize: CGSize? = nil) -> (base: UIImage, glow: UIImage) {
        let base = TexFacadePaint.picture(look, size: baseSize ?? facadeSize, lit: false, wall: wall)
        let glow = TexFacadePaint.picture(look, size: facadeSize, lit: true, wall: nil)
        return (base, glow)
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
