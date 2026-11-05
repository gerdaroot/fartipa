import UIKit

/// Pictures for the piss stream. Painted once, on first use, during loading.
enum PissTextures {
    /// Translucent yellow with long brighter and darker streaks; repeats along the stream.
    static let liquid: UIImage = liquidStreaks()
    /// Falling beads of liquid with gaps between them, for the lower part where the stream breaks up.
    static let beads: UIImage = beadRows()
    /// The jagged rim of the splash crown, solid at the bottom and spiky at the top.
    static let crown: UIImage = crownRim()
    /// A dark storm cloud with a bare butt poking out of its bottom. The source of everything.
    static let cloudButt: UIImage = cloudWithButt()

    private static let yellow = UIColor(red: 1, green: 0.84, blue: 0.2, alpha: 1)

    private static func liquidStreaks() -> UIImage {
        let size = CGSize(width: 64, height: 256)
        var random = SplitMix(seed: 4242)
        return BikeTextures.renderer(size, opaque: false).image { context in
            let cg = context.cgContext
            cg.setFillColor(yellow.withAlphaComponent(0.52).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for index in 0..<46 {
                let x = CGFloat(random.unit()) * size.width
                let y = CGFloat(random.unit()) * size.height
                let width = CGFloat(1 + random.unit() * 4)
                let length = CGFloat(30 + random.unit() * 110)
                let color: UIColor = index % 3 == 0
                    ? UIColor(red: 0.85, green: 0.6, blue: 0.05, alpha: 0.45)
                    : UIColor(red: 1, green: 0.97, blue: 0.7, alpha: CGFloat(0.35 + random.unit() * 0.5))
                cg.setFillColor(color.cgColor)
                // Drawn twice, one tile apart, so the picture repeats without a seam.
                cg.fill(CGRect(x: x, y: y, width: width, height: length))
                cg.fill(CGRect(x: x, y: y - size.height, width: width, height: length))
            }
        }
    }

    private static func beadRows() -> UIImage {
        let size = CGSize(width: 64, height: 128)
        var random = SplitMix(seed: 911)
        return BikeTextures.renderer(size, opaque: false).image { context in
            let cg = context.cgContext
            cg.setFillColor(yellow.withAlphaComponent(0.12).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<26 {
                let x = CGFloat(random.unit()) * size.width
                let y = CGFloat(random.unit()) * size.height
                let width = CGFloat(8 + random.unit() * 14)
                let height = width * CGFloat(1.3 + random.unit() * 1.4)
                let offsets: [CGPoint] = [.zero, CGPoint(x: 0, y: -size.height), CGPoint(x: -size.width, y: 0)]
                for offset in offsets {
                    let rect = CGRect(x: x + offset.x, y: y + offset.y, width: width, height: height)
                    cg.setFillColor(yellow.withAlphaComponent(0.8).cgColor)
                    cg.fillEllipse(in: rect)
                    let shine = CGRect(x: rect.minX + width * 0.25, y: rect.minY + height * 0.2, width: width * 0.25, height: height * 0.3)
                    cg.setFillColor(UIColor(white: 1, alpha: 0.7).cgColor)
                    cg.fillEllipse(in: shine)
                }
            }
        }
    }

    private static func crownRim() -> UIImage {
        let size = CGSize(width: 128, height: 64)
        var random = SplitMix(seed: 31)
        return BikeTextures.renderer(size, opaque: false).image { context in
            let cg = context.cgContext
            let spikes = 9
            let step = size.width / CGFloat(spikes)
            cg.setFillColor(UIColor(red: 1, green: 0.92, blue: 0.5, alpha: 0.75).cgColor)
            for index in 0..<spikes {
                let left = CGFloat(index) * step
                let tip = CGFloat(4 + random.unit() * 22)
                cg.beginPath()
                cg.move(to: CGPoint(x: left, y: size.height))
                cg.addLine(to: CGPoint(x: left + step * 0.5, y: tip))
                cg.addLine(to: CGPoint(x: left + step, y: size.height))
                cg.closePath()
                cg.fillPath()
                cg.fillEllipse(in: CGRect(x: left + step * 0.5 - 4, y: max(0, tip - 9), width: 8, height: 8))
            }
            Painter.verticalGradient(
                cg, rect: CGRect(x: 0, y: size.height * 0.55, width: size.width, height: size.height * 0.45),
                colors: [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 0.5)], locations: [0, 1]
            )
        }
    }

    private static func cloudWithButt() -> UIImage {
        let size = CGSize(width: 256, height: 192)
        var random = SplitMix(seed: 666)
        return BikeTextures.renderer(size, opaque: false).image { context in
            let cg = context.cgContext
            drawButt(cg, size: size)
            for index in 0..<14 {
                let radius = CGFloat(30 + random.unit() * 32)
                let x = CGFloat(30 + random.unit() * 196)
                let y = CGFloat(40 + random.unit() * 60) + (index < 5 ? 20 : 0)
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 1.6)
                cg.setFillColor(UIColor(red: 0.2, green: 0.17, blue: 0.24, alpha: 0.96).cgColor)
                cg.fillEllipse(in: rect)
                cg.setFillColor(UIColor(red: 0.42, green: 0.38, blue: 0.5, alpha: 0.5).cgColor)
                cg.fillEllipse(in: rect.insetBy(dx: radius * 0.35, dy: radius * 0.1).offsetBy(dx: -radius * 0.2, dy: -radius * 0.3))
            }
        }
    }

    /// Two pink cheeks hanging under the cloud, with a crack and a warm yellow glow at the bottom.
    private static func drawButt(_ cg: CGContext, size: CGSize) {
        let centerX = size.width / 2
        let skin = UIColor(red: 1, green: 0.66, blue: 0.62, alpha: 1)
        let shade = UIColor(red: 0.82, green: 0.42, blue: 0.42, alpha: 1)
        for side in [CGFloat(-1), CGFloat(1)] {
            let cheek = CGRect(x: centerX + side * 30 - 32, y: 98, width: 64, height: 62)
            cg.setFillColor(shade.cgColor)
            cg.fillEllipse(in: cheek)
            cg.setFillColor(skin.cgColor)
            cg.fillEllipse(in: cheek.insetBy(dx: 5, dy: 5).offsetBy(dx: -side * 2, dy: -3))
            cg.setFillColor(UIColor(white: 1, alpha: 0.55).cgColor)
            cg.fillEllipse(in: CGRect(x: cheek.midX - 4 + side * 6, y: cheek.minY + 14, width: 14, height: 10))
        }
        cg.setStrokeColor(shade.cgColor)
        cg.setLineWidth(4)
        cg.move(to: CGPoint(x: centerX, y: 110))
        cg.addLine(to: CGPoint(x: centerX, y: 158))
        cg.strokePath()
        Painter.radialGlow(cg, center: CGPoint(x: centerX, y: 158), radius: 22, color: yellow, alpha: 0.9)
    }
}
