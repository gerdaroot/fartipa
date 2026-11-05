import UIKit

/// The pictures of one facade look.
struct TexFacadeSet {
    let base: UIImage
    let glow: UIImage
    let normal: UIImage?
}

/// Paints every facade look once, with a photo wall when the photo is bundled.
enum TexFacadeBuilder {
    private static let photoBaseSize = CGSize(width: 512, height: 1024)

    static func wallKind(_ style: FacadeStyle) -> TexPhotoKind {
        switch style {
        case .office, .flats: return .concrete
        case .glass: return .metal
        case .brick: return .brick
        }
    }

    static func all(photos: [TexPhotoKind: TexMaps]) -> [TexFacadeLook: TexFacadeSet] {
        var result: [TexFacadeLook: TexFacadeSet] = [:]
        for style in FacadeStyle.allCases {
            let wall = photos[wallKind(style)]
            for variant in 0..<TexFacadePaint.variants {
                let look = TexFacadeLook(style: style, variant: variant)
                let size = wall == nil ? CityTextures.facadeSize : photoBaseSize
                let pictures = CityTextures.facade(look, wall: wall?.color, baseSize: size)
                let normal = TexNormals.facade(look, wallNormal: wall?.normal)
                result[look] = TexFacadeSet(base: pictures.base, glow: pictures.glow, normal: normal)
            }
        }
        return result
    }
}

/// Car body panel lines and the lorry's cargo livery.
struct TexVehicleParts {
    let panelNormal: UIImage?
    let cargoLivery: UIImage

    private static let liverySize = CGSize(width: 1024, height: 512)
    static let gameTitle = "ПИЗДЕЦ СУПЕР КРУТОЙ\nБАЙКЕР 3Д"

    static func make(photos: [TexPhotoKind: TexMaps]) -> TexVehicleParts {
        TexVehicleParts(panelNormal: TexNormals.carPanels(), cargoLivery: livery(photos[.corrugated]?.color))
    }

    /// Corrugated side of the box lorry with the game's name on it.
    private static func livery(_ steel: CGImage?) -> UIImage {
        let size = liverySize
        return BikeTextures.renderer(size).image { context in
            let cg = context.cgContext
            let full = CGRect(origin: .zero, size: size)
            if let steel {
                cg.draw(steel, in: CGRect(x: 0, y: 0, width: size.height, height: size.height), byTiling: true)
                cg.setBlendMode(.multiply)
                cg.setFillColor(UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1).cgColor)
                cg.fill(full)
                cg.setBlendMode(.normal)
            } else {
                cg.setFillColor(UIColor(white: 0.82, alpha: 1).cgColor)
                cg.fill(full)
            }
            let band = CGRect(x: 0, y: size.height * 0.2, width: size.width, height: size.height * 0.6)
            cg.setFillColor(UIColor(red: 0.2, green: 0.1, blue: 0.04, alpha: 0.92).cgColor)
            cg.fill(band)
            cg.setFillColor(UIColor(red: 1, green: 0.78, blue: 0.1, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: band.minY - 10, width: size.width, height: 10))
            cg.fill(CGRect(x: 0, y: band.maxY, width: size.width, height: 10))
            cg.saveGState()
            cg.translateBy(x: 30, y: band.minY + 10)
            BikeTextures.paintPoop(cg, side: band.height - 20)
            cg.restoreGState()
            Painter.text(
                gameTitle, in: CGRect(x: band.height, y: band.minY + 14, width: size.width - band.height - 24, height: band.height - 28),
                color: UIColor(red: 1, green: 0.84, blue: 0.3, alpha: 1), glow: nil, weight: .black
            )
        }
    }
}

/// Normal maps made from painted height maps.
enum TexNormals {
    private static let facadeWidth = 256
    private static let facadeHeight = 512
    private static let panelSide = 256

    /// Window recesses, balconies, sills and panel lines, with the wall photo's bumps on the wall.
    static func facade(_ look: TexFacadeLook, wallNormal: CGImage?) -> UIImage? {
        let width = facadeWidth
        let height = facadeHeight
        let size = CGSize(width: width, height: height)
        let heights = paintHeights(width: width, height: height) { cg in
            cg.setFillColor(gray: TexFacadePaint.wallHeight, alpha: 1)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setFillColor(gray: TexFacadePaint.windowHeight, alpha: 1)
            for rect in TexFacadePaint.windowRects(look, size: size) { cg.fill(rect) }
            for detail in TexFacadePaint.details(look, size: size) {
                cg.setFillColor(gray: TexFacadePaint.height(detail.kind), alpha: 1)
                cg.fill(detail.rect)
            }
        }
        guard let heights else { return nil }
        let tile = max(1, Int(CGFloat(width) * TexFacadePaint.photoTileShare(look.style)))
        let photo = wallNormal.flatMap { TexPixels.rgba($0, width: tile, height: tile) }
        let wallLevel = UInt8(TexFacadePaint.wallHeight * 255)
        let bytes = normals(heights, width: width, height: height, strength: 3) { x, y, level in
            guard let photo, level >= wallLevel &- 2 else { return nil }
            // The wall photo is drawn upside down in a UIKit context, so flip it here too.
            let px = x % tile
            let py = tile - 1 - (y % tile)
            let i = (px + py * tile) * 4
            return (Float(photo[i]) / 127.5 - 1, 1 - Float(photo[i + 1]) / 127.5)
        }
        return ImageMaker.opaqueImage(bytes, width: width, height: height).map { UIImage(cgImage: $0) }
    }

    /// Door seams, a waist line and handles for the car bodies (each box face shows the whole picture).
    static func carPanels() -> UIImage? {
        let side = panelSide
        let length = CGFloat(side)
        let heights = paintHeights(width: side, height: side) { cg in
            cg.setFillColor(gray: 0.6, alpha: 1)
            cg.fill(CGRect(x: 0, y: 0, width: length, height: length))
            cg.setFillColor(gray: 0.2, alpha: 1)
            let seam: CGFloat = 3
            for x in [length / 3, length * 2 / 3] {
                cg.fill(CGRect(x: x - seam / 2, y: length * 0.12, width: seam, height: length * 0.76))
            }
            cg.fill(CGRect(x: length * 0.04, y: length * 0.4, width: length * 0.92, height: seam * 0.7))
            cg.setStrokeColor(gray: 0.2, alpha: 1)
            cg.stroke(CGRect(x: 4, y: 4, width: length - 8, height: length - 8), width: seam)
            cg.setFillColor(gray: 0.9, alpha: 1)
            for x in [length / 3 - 22, length * 2 / 3 - 22] {
                cg.fill(CGRect(x: x, y: length * 0.3, width: 14, height: 4))
            }
        }
        guard let heights else { return nil }
        let bytes = normals(heights, width: side, height: side, strength: 2.5) { _, _, _ in nil }
        return ImageMaker.opaqueImage(bytes, width: side, height: side).map { UIImage(cgImage: $0) }
    }

    /// Paints in a grey bitmap with UIKit's top-left origin and returns its bytes (row 0 on top).
    private static func paintHeights(width: Int, height: Int, draw: (CGContext) -> Void) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: width * height)
        let painted: Bool = data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> Bool in
            guard
                let base = raw.baseAddress,
                let cg = CGContext(
                    data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            else { return false }
            cg.translateBy(x: 0, y: CGFloat(height))
            cg.scaleBy(x: 1, y: -1)
            draw(cg)
            return true
        }
        return painted ? data : nil
    }

    /// Tangent-space normals (OpenGL convention, green up) from heights, wrapping at the edges.
    /// `detail` may add a second normal's x and y at a pixel (whiteout blend).
    private static func normals(
        _ heights: [UInt8], width: Int, height: Int, strength: Float,
        detail: (Int, Int, UInt8) -> (Float, Float)?
    ) -> Data {
        var data = Data(count: width * height * 4)
        let scale = strength / 255
        data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let target = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                let up = ((y - 1 + height) % height) * width
                let down = ((y + 1) % height) * width
                for x in 0..<width {
                    let left = (x - 1 + width) % width
                    let right = (x + 1) % width
                    let row = y * width
                    var nx = (Float(heights[left + row]) - Float(heights[right + row])) * scale
                    var ny = (Float(heights[x + down]) - Float(heights[x + up])) * scale
                    if let extra = detail(x, y, heights[x + row]) {
                        nx += extra.0
                        ny += extra.1
                    }
                    let inverse = 1 / (nx * nx + ny * ny + 1).squareRoot()
                    let to = (x + row) * 4
                    target[to] = byte((nx * inverse * 0.5 + 0.5) * 255)
                    target[to + 1] = byte((ny * inverse * 0.5 + 0.5) * 255)
                    target[to + 2] = byte((inverse * 0.5 + 0.5) * 255)
                    target[to + 3] = 255
                }
            }
        }
        return data
    }

    @inline(__always)
    private static func byte(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, value)))
    }
}
