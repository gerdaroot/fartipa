import UIKit

/// Mixes the bundled photos with the poop pile: the road is stained wet asphalt with poop lying on
/// it (low places hold shiny puddles, high places are poop), and the ground is dark tinted mud.
/// Runs off the main thread, once, while loading.
enum TexRoadBlend {
    private static let roadSide = 1024
    private static let roughSide = 512
    private static let groundSide = 512
    /// Stain multiplied into the grey asphalt photo.
    private static let stain: (r: Float, g: Float, b: Float) = (0.66, 0.5, 0.37)
    private static let mudTint: (r: Float, g: Float, b: Float) = (0.46, 0.32, 0.2)

    static func road(_ tile: TexPoopTile, asphalt: TexMaps, normalStrength: Float) -> SurfaceSet? {
        let n = roadSide
        guard
            tile.side > 1, tile.heights.count == tile.side * tile.side,
            let colorData = TexPixels.rgba(asphalt.color, width: n, height: n)
        else { return nil }
        let photo = [UInt8](colorData)
        let photoNormal: [UInt8]? = asphalt.normal.flatMap { TexPixels.rgba($0, width: n, height: n) }.map { [UInt8]($0) }
        let poop = [UInt8](tile.albedo)
        let poopNormal = [UInt8](SurfaceTextures.normals(tile.heights, side: tile.side, strength: normalStrength))
        let levels = normalizedHeights(tile.heights)
        var albedo = [UInt8](repeating: 255, count: n * n * 4)
        var normal = [UInt8](repeating: 255, count: n * n * 4)
        let side = tile.side
        for y in 0..<n {
            let py = y * side / n
            for x in 0..<n {
                let p = x * side / n + py * side
                let t = levels[p]
                let mask = smooth((t - 0.38) / 0.3)
                let wet = 0.72 + 0.28 * smooth(t / 0.3)
                let i = (x + y * n) * 4
                let k = mask * 0.88
                albedo[i] = byte(Float(photo[i]) * stain.r * wet * (1 - k) + Float(poop[p * 4]) * k)
                albedo[i + 1] = byte(Float(photo[i + 1]) * stain.g * wet * (1 - k) + Float(poop[p * 4 + 1]) * k)
                albedo[i + 2] = byte(Float(photo[i + 2]) * stain.b * wet * (1 - k) + Float(poop[p * 4 + 2]) * k)
                writeNormal(&normal, at: i, poop: poopNormal, p: p * 4, photo: photoNormal, photoWeight: 1 - 0.65 * mask)
            }
        }
        let rough = roughness(tile, levels: levels, photo: asphalt.roughness)
        guard
            let albedoImage = ImageMaker.opaqueImage(Data(albedo), width: n, height: n),
            let normalImage = ImageMaker.opaqueImage(Data(normal), width: n, height: n),
            let roughImage = ImageMaker.opaqueImage(Data(rough), width: roughSide, height: roughSide)
        else { return nil }
        return SurfaceSet(albedo: UIImage(cgImage: albedoImage), normal: UIImage(cgImage: normalImage), roughness: UIImage(cgImage: roughImage))
    }

    /// Whiteout blend of the pile's normal and the asphalt's.
    private static func writeNormal(_ out: inout [UInt8], at i: Int, poop: [UInt8], p: Int, photo: [UInt8]?, photoWeight: Float) {
        var nx = Float(poop[p]) / 127.5 - 1
        var ny = Float(poop[p + 1]) / 127.5 - 1
        var nz = Float(poop[p + 2]) / 127.5 - 1
        if let photo {
            nx += (Float(photo[i]) / 127.5 - 1) * photoWeight
            ny += (Float(photo[i + 1]) / 127.5 - 1) * photoWeight
            nz *= max(0.2, Float(photo[i + 2]) / 127.5 - 1)
        }
        let inverse = 1 / max(0.0001, (nx * nx + ny * ny + nz * nz).squareRoot())
        out[i] = byte((nx * inverse * 0.5 + 0.5) * 255)
        out[i + 1] = byte((ny * inverse * 0.5 + 0.5) * 255)
        out[i + 2] = byte((nz * inverse * 0.5 + 0.5) * 255)
    }

    /// Puddles in the hollows are mirror-like, bare asphalt is satin, poop tops are dull.
    private static func roughness(_ tile: TexPoopTile, levels: [Float], photo: CGImage?) -> [UInt8] {
        let n = roughSide
        let photoRough: [UInt8]? = photo.flatMap { TexPixels.rgba($0, width: n, height: n) }.map { [UInt8]($0) }
        var out = [UInt8](repeating: 255, count: n * n * 4)
        let side = tile.side
        for y in 0..<n {
            let py = y * side / n
            for x in 0..<n {
                let t = levels[x * side / n + py * side]
                let i = (x + y * n) * 4
                let base = photoRough.map { Float($0[i]) / 255 } ?? 0.55
                let mask = smooth((t - 0.38) / 0.3)
                let puddle = 1 - smooth((t - 0.12) / 0.2)
                let dry = base * 0.7 * (1 - mask) + (0.3 + 0.25 * t) * mask
                let value = byte((dry * (1 - puddle) + 0.05 * puddle) * 255)
                out[i] = value
                out[i + 1] = value
                out[i + 2] = value
            }
        }
        return out
    }

    /// Dark wet mud from the ground photo; glossy where the photo is dark.
    static func ground(_ mud: TexMaps) -> SurfaceSet? {
        let n = groundSide
        guard let normal = mud.normal, let data = TexPixels.rgba(mud.color, width: n, height: n) else { return nil }
        let photo = [UInt8](data)
        var albedo = [UInt8](repeating: 255, count: n * n * 4)
        var rough = [UInt8](repeating: 255, count: n * n * 4)
        for i in stride(from: 0, to: n * n * 4, by: 4) {
            let r = Float(photo[i])
            let g = Float(photo[i + 1])
            let b = Float(photo[i + 2])
            albedo[i] = byte(r * mudTint.r)
            albedo[i + 1] = byte(g * mudTint.g)
            albedo[i + 2] = byte(b * mudTint.b)
            let light = (r * 0.3 + g * 0.55 + b * 0.15) / 255
            let value = byte((0.2 + 0.6 * light) * 255)
            rough[i] = value
            rough[i + 1] = value
            rough[i + 2] = value
        }
        guard
            let albedoImage = ImageMaker.opaqueImage(Data(albedo), width: n, height: n),
            let roughImage = ImageMaker.opaqueImage(Data(rough), width: n, height: n)
        else { return nil }
        return SurfaceSet(albedo: UIImage(cgImage: albedoImage), normal: UIImage(cgImage: normal), roughness: UIImage(cgImage: roughImage))
    }

    private static func normalizedHeights(_ heights: [Float]) -> [Float] {
        var low = Float.greatestFiniteMagnitude
        var high = -Float.greatestFiniteMagnitude
        for value in heights {
            low = min(low, value)
            high = max(high, value)
        }
        let range = max(0.001, high - low)
        return heights.map { ($0 - low) / range }
    }

    @inline(__always)
    private static func smooth(_ t: Float) -> Float {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }

    @inline(__always)
    private static func byte(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, value)))
    }
}
