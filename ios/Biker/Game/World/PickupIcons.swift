import UIKit

/// The glowing badge floating over each pickup, and its colour.
enum PickupIcons {
    private static let side: CGFloat = 256

    static func color(_ kind: PickupKind) -> ColorValue {
        switch kind {
        case .magnet: return ColorValue(hex: 0xFF3B5C)
        case .shield: return ColorValue(hex: 0x4CFF6A)
        case .coinDoubler: return ColorValue(hex: 0xFFD21E)
        case .boostRefill: return ColorValue(hex: 0xFF8A1E)
        case .repair: return ColorValue(hex: 0x3CC8FF)
        }
    }

    static func image(_ kind: PickupKind) -> UIImage {
        BikeTextures.renderer(CGSize(width: side, height: side), opaque: false).image { context in
            let cg = context.cgContext
            let tint = color(kind).ui
            let center = CGPoint(x: side / 2, y: side / 2)
            Painter.radialGlow(cg, center: center, radius: side / 2, color: tint, alpha: 0.75)
            cg.setFillColor(UIColor(white: 0.06, alpha: 0.92).cgColor)
            cg.fillEllipse(in: CGRect(x: side * 0.17, y: side * 0.17, width: side * 0.66, height: side * 0.66))
            cg.setStrokeColor(tint.cgColor)
            cg.setLineWidth(side * 0.045)
            cg.strokeEllipse(in: CGRect(x: side * 0.17, y: side * 0.17, width: side * 0.66, height: side * 0.66))
            cg.setFillColor(tint.cgColor)
            cg.setStrokeColor(tint.cgColor)
            switch kind {
            case .magnet: paintMagnet(cg)
            case .shield: paintLeaf(cg)
            case .coinDoubler: Painter.text("×2", in: CGRect(x: 60, y: 70, width: 136, height: 116), color: tint, glow: nil, weight: .black)
            case .boostRefill: paintCan(cg)
            case .repair: paintTape(cg)
            }
        }
    }

    private static func paintMagnet(_ cg: CGContext) {
        cg.setLineWidth(30)
        cg.setLineCap(.butt)
        cg.addArc(center: CGPoint(x: 128, y: 118), radius: 40, startAngle: .pi, endAngle: 0, clockwise: true)
        cg.strokePath()
        cg.setLineWidth(30)
        cg.move(to: CGPoint(x: 88, y: 118))
        cg.addLine(to: CGPoint(x: 88, y: 170))
        cg.move(to: CGPoint(x: 168, y: 118))
        cg.addLine(to: CGPoint(x: 168, y: 170))
        cg.strokePath()
        cg.setFillColor(UIColor.white.cgColor)
        cg.fill(CGRect(x: 73, y: 156, width: 30, height: 16))
        cg.fill(CGRect(x: 153, y: 156, width: 30, height: 16))
    }

    /// The burdock leaf ("лопух") that works as a shield.
    private static func paintLeaf(_ cg: CGContext) {
        cg.move(to: CGPoint(x: 128, y: 62))
        cg.addQuadCurve(to: CGPoint(x: 128, y: 196), control: CGPoint(x: 220, y: 110))
        cg.addQuadCurve(to: CGPoint(x: 128, y: 62), control: CGPoint(x: 36, y: 110))
        cg.fillPath()
        cg.setStrokeColor(UIColor(white: 0.05, alpha: 0.8).cgColor)
        cg.setLineWidth(6)
        cg.move(to: CGPoint(x: 128, y: 74))
        cg.addLine(to: CGPoint(x: 128, y: 190))
        for y in stride(from: 100, through: 160, by: 30) {
            cg.move(to: CGPoint(x: 128, y: CGFloat(y)))
            cg.addLine(to: CGPoint(x: 160, y: CGFloat(y) - 20))
            cg.move(to: CGPoint(x: 128, y: CGFloat(y)))
            cg.addLine(to: CGPoint(x: 96, y: CGFloat(y) - 20))
        }
        cg.strokePath()
    }

    /// A can of beans: fuel for the farts.
    private static func paintCan(_ cg: CGContext) {
        cg.fill(CGRect(x: 92, y: 70, width: 72, height: 118))
        cg.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor)
        cg.fill(CGRect(x: 92, y: 104, width: 72, height: 48))
        cg.setFillColor(UIColor(red: 0.55, green: 0.25, blue: 0.1, alpha: 1).cgColor)
        for (x, y) in [(108, 118), (126, 126), (144, 116), (118, 136), (138, 138)] {
            cg.fillEllipse(in: CGRect(x: x, y: y, width: 14, height: 10))
        }
    }

    /// A roll of duct tape ("изолента").
    private static func paintTape(_ cg: CGContext) {
        cg.setLineWidth(26)
        cg.strokeEllipse(in: CGRect(x: 82, y: 82, width: 92, height: 92))
        cg.move(to: CGPoint(x: 128, y: 172))
        cg.addLine(to: CGPoint(x: 196, y: 200))
        cg.setLineWidth(20)
        cg.strokePath()
    }
}
