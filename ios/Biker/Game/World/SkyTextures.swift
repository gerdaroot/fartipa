import UIKit

/// The night sky as an equirectangular picture (2:1): gradient, stars, moon, neon haze and a far
/// skyline along the horizon. The middle row is the horizon, painted in the fog colour.
enum SkyTextures {
    private static let width: CGFloat = 1024
    private static let height: CGFloat = 512
    private static let starCount = 260
    private static let skylineBlocks = 150
    /// The moon sits a little right of straight ahead (u 0.5 looks down -z).
    private static let moonCenter = CGPoint(x: 0.555, y: 0.3)
    private static let moonRadius: CGFloat = 15

    static func sky(_ palette: WorldPalette, seed: UInt64) -> UIImage {
        var random = SplitMix(seed: seed)
        return BikeTextures.renderer(CGSize(width: width, height: height)).image { context in
            let cg = context.cgContext
            paintGradient(cg, palette)
            paintStars(cg, &random)
            paintMoon(cg, palette)
            paintHaze(cg, palette, &random)
            paintSkyline(cg, palette, &random)
        }
    }

    private static func paintGradient(_ cg: CGContext, _ palette: WorldPalette) {
        let below = palette.horizon.scaled(0.75)
        Painter.verticalGradient(
            cg, rect: CGRect(x: 0, y: 0, width: width, height: height),
            colors: [palette.skyTop.ui, palette.skyHigh.ui, palette.horizon.ui, palette.horizon.ui, below.ui],
            locations: [0, 0.32, 0.5, 0.53, 1]
        )
    }

    private static func paintStars(_ cg: CGContext, _ random: inout SplitMix) {
        for _ in 0..<starCount {
            let x = CGFloat(random.unit()) * width
            let y = CGFloat(random.unit() * random.unit()) * height * 0.42
            let size = CGFloat(0.6 + random.unit() * 1.6)
            let alpha = CGFloat(0.25 + random.unit() * 0.75) * (1 - y / (height * 0.5))
            cg.setFillColor(UIColor(white: 1, alpha: alpha).cgColor)
            cg.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
    }

    private static func paintMoon(_ cg: CGContext, _ palette: WorldPalette) {
        let center = CGPoint(x: moonCenter.x * width, y: moonCenter.y * height)
        Painter.radialGlow(cg, center: center, radius: moonRadius * 6, color: palette.moon.ui, alpha: 0.28)
        cg.setFillColor(palette.moon.mixed(with: ColorValue(1, 1, 1), 0.6).ui.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - moonRadius, y: center.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2))
        cg.setFillColor(palette.moon.scaled(0.78).ui.withAlphaComponent(0.55).cgColor)
        let craters: [(CGFloat, CGFloat, CGFloat)] = [(-0.35, -0.2, 0.28), (0.3, 0.25, 0.22), (0.1, -0.45, 0.14), (-0.2, 0.4, 0.12)]
        for (dx, dy, r) in craters {
            let radius = moonRadius * r
            cg.fillEllipse(in: CGRect(
                x: center.x + dx * moonRadius - radius, y: center.y + dy * moonRadius - radius,
                width: radius * 2, height: radius * 2
            ))
        }
    }

    /// Neon light pollution glowing over the city.
    private static func paintHaze(_ cg: CGContext, _ palette: WorldPalette, _ random: inout SplitMix) {
        let horizonY = height * 0.5
        for index in 0..<14 {
            let color = index % 2 == 0 ? palette.neonA : palette.neonB
            let center = CGPoint(x: CGFloat(random.unit()) * width, y: horizonY - CGFloat(random.unit()) * 12)
            let radius = CGFloat(50 + random.unit() * 110)
            cg.saveGState()
            cg.translateBy(x: center.x, y: center.y)
            cg.scaleBy(x: 1.8, y: 0.45)
            Painter.radialGlow(cg, center: .zero, radius: radius, color: color.ui, alpha: 0.32)
            cg.restoreGState()
        }
    }

    /// Hazy tower silhouettes with tiny lit windows. They stand on the horizon so geometry
    /// that fades into the fog meets them without a seam.
    private static func paintSkyline(_ cg: CGContext, _ palette: WorldPalette, _ random: inout SplitMix) {
        let horizonY = height * 0.5
        let body = palette.horizon.mixed(with: palette.skyTop, 0.35)
        for _ in 0..<skylineBlocks {
            let blockWidth = CGFloat(6 + random.unit() * 22)
            let blockHeight = CGFloat(6 + random.unit() * random.unit() * 46)
            let x = CGFloat(random.unit()) * width
            let shade = 0.75 + random.unit() * 0.3
            cg.setFillColor(body.scaled(shade).ui.cgColor)
            let rect = CGRect(x: x, y: horizonY - blockHeight, width: blockWidth, height: blockHeight + 4)
            cg.fill(rect)
            paintWindows(cg, rect: rect, palette: palette, random: &random)
            if random.chance(0.12) {
                let tip = randomNeon(palette, &random)
                cg.setFillColor(tip.ui.cgColor)
                cg.fill(CGRect(x: rect.midX - 0.5, y: rect.minY - 4, width: 1, height: 4))
            }
        }
        cg.setFillColor(palette.horizon.ui.withAlphaComponent(0.35).cgColor)
        cg.fill(CGRect(x: 0, y: horizonY - 6, width: width, height: 10))
    }

    private static func randomNeon(_ palette: WorldPalette, _ random: inout SplitMix) -> ColorValue {
        random.chance(0.5) ? palette.neonA : palette.neonB
    }

    private static func paintWindows(_ cg: CGContext, rect: CGRect, palette: WorldPalette, random: inout SplitMix) {
        let color = palette.windows.ui.withAlphaComponent(0.55).cgColor
        cg.setFillColor(color)
        var y = rect.minY + 2
        while y < rect.maxY - 4 {
            var x = rect.minX + 1.5
            while x < rect.maxX - 1.5 {
                if random.chance(0.22) { cg.fill(CGRect(x: x, y: y, width: 1, height: 1)) }
                x += 3
            }
            y += 3
        }
    }
}
