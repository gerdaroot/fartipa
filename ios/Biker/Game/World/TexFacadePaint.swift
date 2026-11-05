import UIKit

/// One facade picture set: a style and one of its window grids.
struct TexFacadeLook: Hashable {
    let style: FacadeStyle
    let variant: Int
}

/// A raised or recessed part painted on a facade: the same list draws the colour and the bumps.
struct TexFacadeDetail {
    enum Kind {
        case spandrel, pilaster, balcony, railing, airCon, lintel, sill, mullion, transom
    }
    let rect: CGRect
    let kind: Kind
}

/// Facade pictures: a wall (photo or flat colour), a grid of windows, panel lines, balconies,
/// lintels and sills. Base, glow and bumps come from the same layout, so lit windows and
/// window recesses line up whatever the picture size.
enum TexFacadePaint {
    static let variants = 2
    static let floors = 8

    static func seed(_ look: TexFacadeLook) -> UInt64 {
        UInt64(look.style.rawValue) &+ 3 &+ UInt64(look.variant) &* 101
    }

    static func columns(_ look: TexFacadeLook) -> Int {
        guard look.variant > 0 else { return 4 }
        switch look.style {
        case .office: return 6
        case .flats: return 3
        case .glass: return 5
        case .brick: return 3
        }
    }

    static func wallColor(_ style: FacadeStyle) -> UIColor {
        switch style {
        case .office: return UIColor(red: 0.16, green: 0.17, blue: 0.2, alpha: 1)
        case .flats: return UIColor(red: 0.22, green: 0.19, blue: 0.17, alpha: 1)
        case .glass: return UIColor(red: 0.07, green: 0.1, blue: 0.14, alpha: 1)
        case .brick: return UIColor(red: 0.3, green: 0.14, blue: 0.1, alpha: 1)
        }
    }

    /// What a photo wall is multiplied by, so each style keeps its own colour at night.
    static func photoTint(_ style: FacadeStyle) -> UIColor {
        switch style {
        case .office: return UIColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 1)
        case .flats: return UIColor(red: 0.62, green: 0.53, blue: 0.46, alpha: 1)
        case .glass: return UIColor(red: 0.32, green: 0.4, blue: 0.5, alpha: 1)
        case .brick: return UIColor(red: 0.62, green: 0.46, blue: 0.42, alpha: 1)
        }
    }

    /// Share of the picture width one tile of the wall photo covers.
    static func photoTileShare(_ style: FacadeStyle) -> CGFloat {
        style == .brick ? 0.25 : 0.5
    }

    // MARK: - Layout

    static func cell(_ look: TexFacadeLook, size: CGSize) -> CGSize {
        CGSize(width: size.width / CGFloat(columns(look)), height: size.height / CGFloat(floors))
    }

    static func windowInset(_ style: FacadeStyle, cell: CGSize) -> CGSize {
        switch style {
        case .office: return CGSize(width: cell.width * 0.06, height: cell.height * 0.18)
        case .flats: return CGSize(width: cell.width * 0.22, height: cell.height * 0.24)
        case .glass: return CGSize(width: cell.width * 0.03, height: cell.height * 0.05)
        case .brick: return CGSize(width: cell.width * 0.26, height: cell.height * 0.2)
        }
    }

    /// Window rectangles floor by floor, left to right.
    static func windowRects(_ look: TexFacadeLook, size: CGSize) -> [CGRect] {
        let box = cell(look, size: size)
        let inset = windowInset(look.style, cell: box)
        var rects: [CGRect] = []
        for floor in 0..<floors {
            for column in 0..<columns(look) {
                rects.append(CGRect(
                    x: CGFloat(column) * box.width + inset.width, y: CGFloat(floor) * box.height + inset.height,
                    width: box.width - inset.width * 2, height: box.height - inset.height * 2
                ))
            }
        }
        return rects
    }

    /// Panel lines, balconies, air conditioners, lintels and sills. Its own random sequence,
    /// so it never shifts which windows are lit.
    static func details(_ look: TexFacadeLook, size: CGSize) -> [TexFacadeDetail] {
        var random = SplitMix(seed: seed(look) &* 7 &+ 11)
        let box = cell(look, size: size)
        let windows = windowRects(look, size: size)
        var list: [TexFacadeDetail] = []
        let line = max(1, size.width * 0.008)
        switch look.style {
        case .office:
            for floor in 0..<floors {
                let y = CGFloat(floor + 1) * box.height - box.height * 0.12
                list.append(TexFacadeDetail(rect: CGRect(x: 0, y: y, width: size.width, height: box.height * 0.1), kind: .spandrel))
            }
            for column in 0...columns(look) {
                list.append(TexFacadeDetail(rect: CGRect(x: CGFloat(column) * box.width - line, y: 0, width: line * 2, height: size.height), kind: .pilaster))
            }
        case .flats:
            for window in windows {
                if random.chance(0.35) {
                    let slab = CGRect(x: window.minX - box.width * 0.08, y: window.maxY - window.height * 0.3,
                                      width: window.width + box.width * 0.16, height: window.height * 0.42)
                    list.append(TexFacadeDetail(rect: slab, kind: .balcony))
                    list.append(TexFacadeDetail(rect: slab.insetBy(dx: slab.width * 0.04, dy: slab.height * 0.2), kind: .railing))
                } else if random.chance(0.3) {
                    let side = box.width * 0.16
                    list.append(TexFacadeDetail(rect: CGRect(x: window.maxX + line, y: window.maxY - side, width: side, height: side * 0.8), kind: .airCon))
                }
            }
        case .glass:
            for column in 0...columns(look) {
                list.append(TexFacadeDetail(rect: CGRect(x: CGFloat(column) * box.width - line, y: 0, width: line * 2, height: size.height), kind: .mullion))
            }
            for floor in 0...floors {
                list.append(TexFacadeDetail(rect: CGRect(x: 0, y: CGFloat(floor) * box.height - line, width: size.width, height: line * 2), kind: .transom))
            }
        case .brick:
            for window in windows {
                list.append(TexFacadeDetail(rect: CGRect(x: window.minX - line * 2, y: window.minY - box.height * 0.07, width: window.width + line * 4, height: box.height * 0.07), kind: .lintel))
                list.append(TexFacadeDetail(rect: CGRect(x: window.minX - line * 2, y: window.maxY, width: window.width + line * 4, height: box.height * 0.05), kind: .sill))
            }
        }
        return list
    }

    // MARK: - Pictures

    /// The wall with its windows (`lit` false), or black with only the lit windows (`lit` true).
    static func picture(_ look: TexFacadeLook, size: CGSize, lit: Bool, wall: CGImage?) -> UIImage {
        var random = SplitMix(seed: seed(look) &* 31 &+ 7)
        return BikeTextures.renderer(size).image { context in
            let cg = context.cgContext
            let full = CGRect(origin: .zero, size: size)
            if lit {
                cg.setFillColor(UIColor.black.cgColor)
                cg.fill(full)
            } else {
                paintWall(cg, look: look, size: size, wall: wall)
            }
            paintWindows(cg, look: look, size: size, lit: lit, random: &random)
            if !lit {
                for detail in details(look, size: size) { paintDetail(cg, detail) }
            }
        }
    }

    private static func paintWall(_ cg: CGContext, look: TexFacadeLook, size: CGSize, wall: CGImage?) {
        let full = CGRect(origin: .zero, size: size)
        guard let wall else {
            cg.setFillColor(wallColor(look.style).cgColor)
            cg.fill(full)
            return
        }
        let tile = size.width * photoTileShare(look.style)
        cg.draw(wall, in: CGRect(x: 0, y: 0, width: tile, height: tile), byTiling: true)
        cg.setBlendMode(.multiply)
        cg.setFillColor(photoTint(look.style).cgColor)
        cg.fill(full)
        cg.setBlendMode(.normal)
    }

    private static func paintWindows(_ cg: CGContext, look: TexFacadeLook, size: CGSize, lit: Bool, random: inout SplitMix) {
        let rects = windowRects(look, size: size)
        let perFloor = columns(look)
        let office = look.style == .office
        let litChance = office ? 0.55 : 0.38
        var bandLit = false
        for (index, rect) in rects.enumerated() {
            if index % perFloor == 0 { bandLit = random.chance(office ? 0.6 : 0.4) }
            let on = office ? bandLit && random.chance(0.85) : random.chance(litChance)
            let tone = random.unit()
            paintWindow(cg, rect: rect, on: on, tone: tone, lit: lit, glass: look.style == .glass)
        }
    }

    private static func paintWindow(_ cg: CGContext, rect: CGRect, on: Bool, tone: Double, lit: Bool, glass: Bool) {
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
            return
        }
        let dark = UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1)
        let sky = UIColor(red: 0.16, green: 0.2, blue: 0.3, alpha: 1)
        if on {
            cg.setFillColor(UIColor(red: 0.5, green: 0.42, blue: 0.3, alpha: 1).cgColor)
            cg.fill(rect)
        } else {
            let colors: [UIColor] = glass ? [sky, dark, sky] : [sky, dark]
            let stops: [CGFloat] = glass ? [0, 0.6, 1] : [0, 1]
            Painter.verticalGradient(cg, rect: rect, colors: colors, locations: stops)
        }
        let frame = max(1, rect.width * 0.04)
        cg.setStrokeColor(UIColor(white: 0.62, alpha: 0.8).cgColor)
        cg.setLineWidth(frame)
        cg.stroke(rect.insetBy(dx: frame / 2, dy: frame / 2))
        cg.fill(CGRect(x: rect.midX - frame / 2, y: rect.minY, width: frame, height: rect.height))
    }

    private static func paintDetail(_ cg: CGContext, _ detail: TexFacadeDetail) {
        let rect = detail.rect
        switch detail.kind {
        case .spandrel:
            cg.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
            cg.fill(rect)
        case .pilaster, .mullion, .transom:
            cg.setFillColor(UIColor(white: 0.5, alpha: 0.75).cgColor)
            cg.fill(rect)
        case .balcony:
            cg.setFillColor(UIColor(white: 0.42, alpha: 0.9).cgColor)
            cg.fill(rect)
        case .railing:
            cg.setFillColor(UIColor(white: 0.18, alpha: 1).cgColor)
            let bars = 7
            let step = rect.width / CGFloat(bars)
            for bar in 0...bars {
                cg.fill(CGRect(x: rect.minX + CGFloat(bar) * step, y: rect.minY, width: max(1, step * 0.18), height: rect.height))
            }
            cg.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(1, rect.height * 0.12)))
        case .airCon:
            cg.setFillColor(UIColor(white: 0.66, alpha: 1).cgColor)
            cg.fill(rect)
            cg.setFillColor(UIColor(white: 0.3, alpha: 1).cgColor)
            cg.fillEllipse(in: rect.insetBy(dx: rect.width * 0.25, dy: rect.height * 0.2))
        case .lintel, .sill:
            cg.setFillColor(UIColor(red: 0.62, green: 0.58, blue: 0.5, alpha: 1).cgColor)
            cg.fill(rect)
        }
    }

    /// Height of each part for the bump map, 0 deep to 1 proud; the wall is 0.55.
    static func height(_ kind: TexFacadeDetail.Kind) -> CGFloat {
        switch kind {
        case .spandrel: return 0.45
        case .pilaster, .mullion: return 0.8
        case .transom: return 0.75
        case .balcony, .lintel, .sill, .airCon: return 0.9
        case .railing: return 1
        }
    }

    static let wallHeight: CGFloat = 0.55
    static let windowHeight: CGFloat = 0.12
}
