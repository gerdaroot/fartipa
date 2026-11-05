import UIKit

/// Small transparent pictures for particles and decals. Made once, on first use.
enum SpriteTextures {
    /// A soft round blob: clouds, smoke, glows.
    static let softDot: UIImage = radial(size: 64, inner: 1, falloff: 1)
    /// A small bright point with a halo: sparks, sparkles.
    static let spark: UIImage = radial(size: 32, inner: 1, falloff: 2.4)
    /// Light falling on the road under a lamp.
    static let lightPool: UIImage = radial(size: 128, inner: 0.55, falloff: 1.6)
    /// A dark blob, the shadow of what is about to fall.
    static let shadowDisc: UIImage = shadow()
    /// The target painted where a stream will land.
    static let warningRing: UIImage = ring()
    static let puddle: UIImage = puddleBlob()
    static let rut: UIImage = rutStrip()
    static let streamFlow: UIImage = flow()
    static let bubble: UIImage = bubbleRing()
    static let paper: UIImage = rectangle(size: CGSize(width: 32, height: 16))
    static let fly: UIImage = flyDot()

    private static func radial(size: CGFloat, inner: CGFloat, falloff: CGFloat) -> UIImage {
        BikeTextures.renderer(CGSize(width: size, height: size), opaque: false).image { context in
            let steps = 12
            var colors: [CGColor] = []
            var locations: [CGFloat] = []
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                locations.append(t)
                colors.append(UIColor(white: 1, alpha: inner * pow(1 - t, falloff)).cgColor)
            }
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else { return }
            let center = CGPoint(x: size / 2, y: size / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size / 2, options: [])
        }
    }

    private static func shadow() -> UIImage {
        BikeTextures.renderer(CGSize(width: 128, height: 128), opaque: false).image { context in
            Painter.radialGlow(context.cgContext, center: CGPoint(x: 64, y: 64), radius: 64, color: .black, alpha: 0.9)
        }
    }

    private static func ring() -> UIImage {
        let side: CGFloat = 256
        return BikeTextures.renderer(CGSize(width: side, height: side), opaque: false).image { context in
            let cg = context.cgContext
            Painter.radialGlow(cg, center: CGPoint(x: side / 2, y: side / 2), radius: side / 2, color: .white, alpha: 0.25)
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(14)
            cg.strokeEllipse(in: CGRect(x: 14, y: 14, width: side - 28, height: side - 28))
            cg.setLineWidth(7)
            cg.strokeEllipse(in: CGRect(x: 62, y: 62, width: side - 124, height: side - 124))
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(x: side / 2 - 9, y: 92, width: 18, height: 50))
            cg.fillEllipse(in: CGRect(x: side / 2 - 10, y: 150, width: 20, height: 20))
        }
    }

    private static func puddleBlob() -> UIImage {
        let side: CGFloat = 128
        var random = SplitMix(seed: 77)
        return BikeTextures.renderer(CGSize(width: side, height: side), opaque: false).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.85).cgColor)
            for _ in 0..<9 {
                let radius = CGFloat(18 + random.unit() * 22)
                let x = side / 2 + CGFloat(random.unit() - 0.5) * 50
                let y = side / 2 + CGFloat(random.unit() - 0.5) * 50
                cg.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            }
            Painter.radialGlow(cg, center: CGPoint(x: side * 0.42, y: side * 0.4), radius: side * 0.22, color: .white, alpha: 0.6)
        }
    }

    /// Across: lit rim, dark groove, lit rim. Repeats along its length.
    private static func rutStrip() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        return BikeTextures.renderer(size, opaque: false).image { context in
            let cg = context.cgContext
            let colors: [UIColor] = [
                UIColor(red: 0.5, green: 0.32, blue: 0.16, alpha: 0),
                UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 0.9),
                UIColor(red: 0.08, green: 0.04, blue: 0.02, alpha: 0.95),
                UIColor(red: 0.12, green: 0.06, blue: 0.02, alpha: 0.95),
                UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 0.9),
                UIColor(red: 0.5, green: 0.32, blue: 0.16, alpha: 0),
            ]
            let cgColors: [CGColor] = colors.map { $0.cgColor }
            let locations: [CGFloat] = [0, 0.18, 0.36, 0.64, 0.82, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: locations) else { return }
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
            cg.setFillColor(UIColor(white: 0, alpha: 0.35).cgColor)
            for row in stride(from: 0, to: Int(size.height), by: 8) {
                cg.fill(CGRect(x: 22, y: CGFloat(row), width: 20, height: 3))
            }
        }
    }

    /// Streaks running down a falling stream.
    private static func flow() -> UIImage {
        let size = CGSize(width: 64, height: 256)
        var random = SplitMix(seed: 1312)
        return BikeTextures.renderer(size, opaque: false).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 1, green: 0.86, blue: 0.18, alpha: 0.55).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<40 {
                let x = CGFloat(random.unit()) * size.width
                let y = CGFloat(random.unit()) * size.height
                let length = CGFloat(20 + random.unit() * 70)
                let bright = CGFloat(0.5 + random.unit() * 0.5)
                cg.setFillColor(UIColor(red: 1, green: 0.95, blue: 0.6, alpha: bright).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 2 + CGFloat(random.unit()) * 3, height: length))
                cg.fill(CGRect(x: x, y: y - size.height, width: 2, height: length))
            }
        }
    }

    private static func bubbleRing() -> UIImage {
        BikeTextures.renderer(CGSize(width: 64, height: 64), opaque: false).image { context in
            let cg = context.cgContext
            cg.setStrokeColor(UIColor(white: 1, alpha: 0.9).cgColor)
            cg.setLineWidth(4)
            cg.strokeEllipse(in: CGRect(x: 6, y: 6, width: 52, height: 52))
            cg.setFillColor(UIColor(white: 1, alpha: 0.8).cgColor)
            cg.fillEllipse(in: CGRect(x: 18, y: 16, width: 10, height: 8))
        }
    }

    private static func rectangle(size: CGSize) -> UIImage {
        BikeTextures.renderer(size, opaque: false).image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))
        }
    }

    private static func flyDot() -> UIImage {
        BikeTextures.renderer(CGSize(width: 32, height: 32), opaque: false).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(white: 0.85, alpha: 0.5).cgColor)
            cg.fillEllipse(in: CGRect(x: 4, y: 6, width: 12, height: 8))
            cg.fillEllipse(in: CGRect(x: 16, y: 6, width: 12, height: 8))
            cg.setFillColor(UIColor(white: 1, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 11, y: 11, width: 10, height: 12))
        }
    }
}
