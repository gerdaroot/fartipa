import UIKit

/// Small Core Graphics helpers shared by the texture painters.
enum Painter {
    /// A soft round light: full colour in the middle fading to nothing at `radius`.
    static func radialGlow(_ cg: CGContext, center: CGPoint, radius: CGFloat, color: UIColor, alpha: CGFloat) {
        let colors: [CGColor] = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor]
        let locations: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations
        ) else { return }
        cg.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: []
        )
    }

    /// A vertical gradient through `colors` at `locations` (0 top, 1 bottom) over `rect`.
    static func verticalGradient(_ cg: CGContext, rect: CGRect, colors: [UIColor], locations: [CGFloat]) {
        let cgColors: [CGColor] = colors.map { $0.cgColor }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: locations
        ) else { return }
        cg.saveGState()
        cg.clip(to: rect)
        cg.drawLinearGradient(
            gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: []
        )
        cg.restoreGState()
    }

    /// Centred text shrunk until it fits `rect`. With `glow` it is drawn three times with a blurred halo.
    static func text(
        _ string: String, in rect: CGRect, color: UIColor, glow: UIColor?, weight: UIFont.Weight = .heavy
    ) {
        let lines = max(1, string.components(separatedBy: "\n").count)
        var size = rect.height / CGFloat(lines) * 0.82
        var attributed = styled(string, size: size, color: color, weight: weight)
        let minimumSize: CGFloat = 8
        while size > minimumSize, attributed.size().width > rect.width * 0.94 {
            size *= 0.92
            attributed = styled(string, size: size, color: color, weight: weight)
        }
        let measured = attributed.size()
        let box = CGRect(
            x: rect.midX - measured.width / 2 - 2, y: rect.midY - measured.height / 2,
            width: measured.width.rounded(.up) + 4, height: measured.height.rounded(.up) + 2
        )
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        if let glow {
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: size * 0.5, color: glow.cgColor)
            attributed.draw(in: box)
            cg.setShadow(offset: .zero, blur: size * 0.18, color: glow.cgColor)
            attributed.draw(in: box)
            cg.restoreGState()
        }
        attributed.draw(in: box)
    }

    private static func styled(_ string: String, size: CGFloat, color: UIColor, weight: UIFont.Weight) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 0
        return NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    /// A rounded rectangle outline.
    static func roundedFrame(_ cg: CGContext, rect: CGRect, radius: CGFloat, color: UIColor, width: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.addPath(path.cgPath)
        cg.strokePath()
    }
}
