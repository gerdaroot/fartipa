import UIKit

/// Pictures for the 3D world, painted in code. The road is the same pile as the drawing mode.
enum BikeTextures {
    private static let tileWidth = 256
    private static let tileHeight = 256

    /// A road tile that repeats without a seam: the pile, then the same pile mirrored.
    static func roadTile(seed: UInt32) -> UIImage? {
        guard let pile = pileImage(seed: seed) else { return nil }
        let size = CGSize(width: tileWidth * 2, height: tileHeight * 4)
        return renderer(size).image { context in
            let cg = context.cgContext
            let half = size.height / 2
            cg.saveGState()
            cg.translateBy(x: 0, y: half)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(pile, in: CGRect(x: 0, y: 0, width: size.width, height: half))
            cg.restoreGState()
            cg.draw(pile, in: CGRect(x: 0, y: half, width: size.width, height: half))
            paintMarkings(cg, size: size)
        }
    }

    private static func pileImage(seed: UInt32) -> CGImage? {
        let field = HeightField(widthPoints: tileWidth, heightPoints: tileHeight, scale: 2, seed: seed)
        _ = field.flush()
        return ImageMaker.opaqueImage(field.rgba(in: field.fullRect), width: field.width, height: field.height)
    }

    /// Dashes between lanes and solid edge lines, in the colour of what falls from the sky.
    private static func paintMarkings(_ cg: CGContext, size: CGSize) {
        cg.setFillColor(UIColor(red: 0.96, green: 0.78, blue: 0.16, alpha: 0.85).cgColor)
        let edge = size.width * 0.015
        cg.fill(CGRect(x: size.width * 0.01, y: 0, width: edge, height: size.height))
        cg.fill(CGRect(x: size.width * 0.99 - edge, y: 0, width: edge, height: size.height))
        for lane in [CGFloat(1) / 3, 2.0 / 3] {
            for start in stride(from: size.height / 16, to: size.height, by: size.height / 4) {
                cg.fill(CGRect(x: size.width * lane - edge / 2, y: start, width: edge, height: size.height / 8))
            }
        }
    }

    static let coinImage = coin()

    private static func coin() -> UIImage {
        renderer(CGSize(width: 128, height: 128)).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.96, green: 0.72, blue: 0.2, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            cg.setStrokeColor(UIColor(red: 0.58, green: 0.38, blue: 0.06, alpha: 1).cgColor)
            cg.setLineWidth(7)
            cg.strokeEllipse(in: CGRect(x: 8, y: 8, width: 112, height: 112))
            cg.setFillColor(UIColor(red: 0.36, green: 0.2, blue: 0.07, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: 30, y: 72, width: 68, height: 28))
            cg.fillEllipse(in: CGRect(x: 40, y: 52, width: 48, height: 26))
            cg.fillEllipse(in: CGRect(x: 50, y: 36, width: 28, height: 22))
            cg.move(to: CGPoint(x: 56, y: 42))
            cg.addLine(to: CGPoint(x: 66, y: 22))
            cg.addLine(to: CGPoint(x: 73, y: 42))
            cg.fillPath()
        }
    }

    /// Shown on the roadside until the player has drawn something of their own.
    static func defaultPoster() -> UIImage {
        renderer(CGSize(width: 512, height: 512)).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.22, green: 0.12, blue: 0.05, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let text = NSAttributedString(string: "РИСУЙ\nНА ГОВНЕ\nИ ТВОЯ КАРТИНА\nБУДЕТ ТУТ", attributes: [
                .font: UIFont.systemFont(ofSize: 60, weight: .black),
                .foregroundColor: UIColor(red: 0.96, green: 0.74, blue: 0.28, alpha: 1),
                .paragraphStyle: paragraph,
            ])
            text.draw(in: CGRect(x: 10, y: 110, width: 492, height: 340))
        }
    }

    /// A dark tower with scattered lit windows.
    static func building(seed: Int) -> UIImage {
        var random = SplitMix(seed: UInt64(seed) &+ 11)
        return renderer(CGSize(width: 128, height: 256)).image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.1, green: 0.07, blue: 0.06, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: 128, height: 256))
            for row in 0..<12 {
                for column in 0..<6 where random.unit() < 0.35 {
                    let warmth = 0.5 + random.unit() * 0.45
                    cg.setFillColor(UIColor(red: 0.95, green: CGFloat(warmth) * 0.75, blue: 0.25, alpha: 1).cgColor)
                    cg.fill(CGRect(x: 8 + column * 20, y: 8 + row * 20, width: 12, height: 13))
                }
            }
        }
    }

    /// A dusk sky from the horizon glow up to dark.
    static func sky() -> UIImage {
        renderer(CGSize(width: 16, height: 256)).image { context in
            let colors = [
                UIColor(red: 0.07, green: 0.05, blue: 0.12, alpha: 1).cgColor,
                UIColor(red: 0.24, green: 0.11, blue: 0.16, alpha: 1).cgColor,
                UIColor(red: 0.62, green: 0.31, blue: 0.13, alpha: 1).cgColor,
            ]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.72, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }

    /// The player's picture, cut to a square that suits a billboard.
    static func posterFromDrawing(_ image: UIImage) -> UIImage {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2)
        let scale = 512 / side
        return renderer(CGSize(width: 512, height: 512)).image { _ in
            image.draw(in: CGRect(
                x: origin.x * scale, y: origin.y * scale,
                width: image.size.width * scale, height: image.size.height * scale
            ))
        }
    }

    private static func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
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
