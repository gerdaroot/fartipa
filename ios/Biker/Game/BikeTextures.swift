import UIKit

/// Pictures painted in code that the menus share with the 3D world.
/// The world's own textures live in `World/` (surfaces, city, sky, sprites).
enum BikeTextures {
    private static let coinSide: CGFloat = 128

    /// The говнокоин, for the HUD and shop.
    static let coinImage: UIImage = coin(golden: false)
    /// The rare big one on the road.
    static let goldenCoinImage: UIImage = coin(golden: true)

    private static func coin(golden: Bool) -> UIImage {
        let side = coinSide
        return renderer(CGSize(width: side, height: side), opaque: false).image { context in
            let cg = context.cgContext
            let rim = golden ? UIColor(red: 1, green: 0.62, blue: 0.1, alpha: 1) : UIColor(red: 0.76, green: 0.5, blue: 0.1, alpha: 1)
            let face = golden ? UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1) : UIColor(red: 0.98, green: 0.76, blue: 0.24, alpha: 1)
            cg.setFillColor(rim.cgColor)
            cg.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            cg.saveGState()
            cg.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            cg.clip()
            Painter.radialGlow(cg, center: CGPoint(x: side * 0.42, y: side * 0.4), radius: side * 0.62, color: face, alpha: 1)
            cg.setStrokeColor(UIColor(red: 0.55, green: 0.34, blue: 0.05, alpha: 1).cgColor)
            cg.setLineWidth(side * 0.055)
            cg.strokeEllipse(in: CGRect(x: side * 0.07, y: side * 0.07, width: side * 0.86, height: side * 0.86))
            paintPoop(cg, side: side)
            cg.restoreGState()
        }
    }

    /// A three-tier pile with a curled tip, centred in a square of `side`.
    static func paintPoop(_ cg: CGContext, side: CGFloat) {
        let brown = UIColor(red: 0.36, green: 0.2, blue: 0.07, alpha: 1)
        let shine = UIColor(red: 0.62, green: 0.4, blue: 0.18, alpha: 1)
        let tiers: [CGRect] = [
            CGRect(x: 0.23, y: 0.56, width: 0.54, height: 0.22),
            CGRect(x: 0.31, y: 0.41, width: 0.38, height: 0.2),
            CGRect(x: 0.39, y: 0.29, width: 0.22, height: 0.17),
        ]
        cg.setFillColor(brown.cgColor)
        for tier in tiers {
            cg.fillEllipse(in: CGRect(x: tier.minX * side, y: tier.minY * side, width: tier.width * side, height: tier.height * side))
        }
        cg.move(to: CGPoint(x: side * 0.44, y: side * 0.33))
        cg.addQuadCurve(to: CGPoint(x: side * 0.56, y: side * 0.16), control: CGPoint(x: side * 0.6, y: side * 0.28))
        cg.addLine(to: CGPoint(x: side * 0.58, y: side * 0.33))
        cg.fillPath()
        cg.setFillColor(shine.cgColor)
        for tier in tiers {
            cg.fillEllipse(in: CGRect(
                x: (tier.minX + tier.width * 0.2) * side, y: (tier.minY + tier.height * 0.15) * side,
                width: tier.width * 0.3 * side, height: tier.height * 0.3 * side
            ))
        }
    }

    /// Shown on a roadside billboard until the player gives a picture of their own.
    static func defaultPoster() -> UIImage {
        renderer(CGSize(width: 512, height: 512)).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.14, green: 0.07, blue: 0.03, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            paintPoop(cg, side: 512)
            Painter.text(
                "ПИЗДЕЦ\nКРУТОЙ БАЙКЕР", in: CGRect(x: 16, y: 400, width: 480, height: 100),
                color: UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1), glow: nil, weight: .black
            )
        }
    }

    /// The player's picture, cut to a square that suits a billboard.
    static func posterFromDrawing(_ image: UIImage) -> UIImage {
        let side = max(1, min(image.size.width, image.size.height))
        let origin = CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2)
        let scale = 512 / side
        return renderer(CGSize(width: 512, height: 512)).image { _ in
            image.draw(in: CGRect(
                x: origin.x * scale, y: origin.y * scale,
                width: image.size.width * scale, height: image.size.height * scale
            ))
        }
    }

    /// A 1x renderer. `opaque` false keeps the alpha channel for sprites and decals.
    static func renderer(_ size: CGSize, opaque: Bool = true) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}

enum ImageMaker {
    /// Wraps tightly packed RGBA bytes into an image; the alpha byte is ignored.
    static func opaqueImage(_ data: Data, width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
