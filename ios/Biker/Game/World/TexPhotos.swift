import ImageIO
import UIKit

/// The photo textures bundled as `tex-<name>-color|normal|rough.jpg` (CC0, see Textures/CREDITS.txt).
enum TexPhotoKind: String, CaseIterable {
    case asphalt, mud, sidewalk, brick, concrete, metal, rust, corrugated
}

/// Decoded maps of one photo material, already in a plain 8-bit RGBA format SceneKit uploads as is.
struct TexMaps {
    let color: CGImage
    let normal: CGImage?
    let roughness: CGImage?

    /// One wrapper per picture, so materials sharing a photo share one GPU texture.
    let colorImage: UIImage
    let normalImage: UIImage?
    let roughnessImage: UIImage?

    init(color: CGImage, normal: CGImage?, roughness: CGImage?) {
        self.color = color
        self.normal = normal
        self.roughness = roughness
        colorImage = UIImage(cgImage: color)
        normalImage = normal.map { UIImage(cgImage: $0) }
        roughnessImage = roughness.map { UIImage(cgImage: $0) }
    }
}

/// Everything painted for the world off the main thread: photo maps, facade pictures and vehicle
/// details. Filled once by `loadIfNeeded()` on a background queue; read on the main actor after the
/// hand-off. A missing or broken file leaves its entry empty and the procedural look stays.
final class TexPhotos: @unchecked Sendable {
    static let shared = TexPhotos()

    private let lock = NSLock()
    private var loaded = false
    private var maps: [TexPhotoKind: TexMaps] = [:]
    private var facades: [TexFacadeLook: TexFacadeSet] = [:]
    private var vehicleParts: TexVehicleParts?

    /// True once `loadIfNeeded()` has finished (whether or not every file was found).
    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return loaded
    }

    func maps(_ kind: TexPhotoKind) -> TexMaps? {
        lock.lock()
        defer { lock.unlock() }
        return maps[kind]
    }

    func facade(_ look: TexFacadeLook) -> TexFacadeSet? {
        lock.lock()
        defer { lock.unlock() }
        return facades[look]
    }

    var vehicles: TexVehicleParts? {
        lock.lock()
        defer { lock.unlock() }
        return vehicleParts
    }

    /// Heavy (decodes about a dozen JPEGs and paints the facades): call off the main thread.
    /// Later calls return at once.
    func loadIfNeeded() {
        lock.lock()
        let done = loaded
        lock.unlock()
        guard !done else { return }
        var found: [TexPhotoKind: TexMaps] = [:]
        for kind in TexPhotoKind.allCases {
            if let set = Self.load(kind) { found[kind] = set }
        }
        let paintedFacades = TexFacadeBuilder.all(photos: found)
        let parts = TexVehicleParts.make(photos: found)
        lock.lock()
        maps = found
        facades = paintedFacades
        vehicleParts = parts
        loaded = true
        lock.unlock()
    }

    private static func load(_ kind: TexPhotoKind) -> TexMaps? {
        guard let color = TexPixels.bundled("tex-\(kind.rawValue)-color") else { return nil }
        return TexMaps(
            color: color,
            normal: TexPixels.bundled("tex-\(kind.rawValue)-normal"),
            roughness: TexPixels.bundled("tex-\(kind.rawValue)-rough")
        )
    }
}

/// Raw pixel helpers for the photo textures.
enum TexPixels {
    /// A bundled JPEG decoded now (not lazily on first draw) and redrawn as 8-bit RGBA.
    static func bundled(_ name: String) -> CGImage? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: true]
        guard let decoded = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else { return nil }
        return normalized(decoded)
    }

    /// Redraws any image into tightly packed RGBA (alpha 255), the format SceneKit always takes.
    static func normalized(_ image: CGImage) -> CGImage? {
        guard let bytes = rgba(image, width: image.width, height: image.height) else { return nil }
        return ImageMaker.opaqueImage(bytes, width: image.width, height: image.height)
    }

    /// The image scaled to `width` x `height` as RGBA bytes.
    static func rgba(_ image: CGImage, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0 else { return nil }
        var data = Data(count: width * height * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> Bool in
            guard
                let base = raw.baseAddress,
                let context = CGContext(
                    data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? data : nil
    }
}
