import UIKit

/// Colour, normal and roughness maps of one surface. All three tile without a seam.
struct SurfaceSet {
    let albedo: UIImage
    let normal: UIImage
    let roughness: UIImage
}

/// The poop road and ground, made from the same height field as the drawing mode.
/// The field is mirrored in both directions so the tile repeats seamlessly; normals come from
/// its slopes and roughness from its height, so the hollows read as wet and glossy.
enum SurfaceTextures {
    private struct Recipe {
        let brightness: Float
        let warmth: Float
        let normalStrength: Float
        let wetBase: Float
        let dryRange: Float
    }

    private static let fieldPoints = 256
    private static let road = Recipe(brightness: 1.05, warmth: 1.05, normalStrength: 2.4, wetBase: 0.06, dryRange: 0.4)
    private static let dirt = Recipe(brightness: 0.55, warmth: 0.95, normalStrength: 3.2, wetBase: 0.3, dryRange: 0.5)

    /// Heavy: run it off the main thread.
    static func roadSurface(seed: UInt32) -> SurfaceSet? { make(seed: seed, recipe: road) }
    static func groundSurface(seed: UInt32) -> SurfaceSet? { make(seed: seed, recipe: dirt) }

    private static func make(seed: UInt32, recipe: Recipe) -> SurfaceSet? {
        let field = HeightField(widthPoints: fieldPoints, heightPoints: fieldPoints, scale: 1, seed: seed)
        _ = field.flush()
        let side = field.width
        let colors = field.rgba(in: field.fullRect)
        var heights = [Float](repeating: 0, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                heights[x + y * side] = field.heightAt(xPoints: Float(x), yPoints: Float(y))
            }
        }
        let out = side * 2
        let albedo = mirroredAlbedo(colors, side: side, recipe: recipe)
        let mirrored = mirroredHeights(heights, side: side)
        guard
            let albedoImage = ImageMaker.opaqueImage(albedo, width: out, height: out),
            let normalImage = ImageMaker.opaqueImage(normals(mirrored, side: out, strength: recipe.normalStrength), width: out, height: out),
            let roughImage = ImageMaker.opaqueImage(roughness(mirrored, side: out, recipe: recipe), width: out, height: out)
        else { return nil }
        return SurfaceSet(albedo: UIImage(cgImage: albedoImage), normal: UIImage(cgImage: normalImage), roughness: UIImage(cgImage: roughImage))
    }

    @inline(__always)
    private static func source(_ i: Int, _ side: Int) -> Int { i < side ? i : 2 * side - 1 - i }

    private static func mirroredAlbedo(_ colors: Data, side: Int, recipe: Recipe) -> Data {
        let out = side * 2
        var data = Data(count: out * out * 4)
        let bytes = [UInt8](colors)
        data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let target = raw.bindMemory(to: UInt8.self).baseAddress, bytes.count >= side * side * 4 else { return }
            for y in 0..<out {
                let sy = source(y, side)
                for x in 0..<out {
                    let from = (source(x, side) + sy * side) * 4
                    let to = (x + y * out) * 4
                    target[to] = clampByte(Float(bytes[from]) * recipe.brightness * recipe.warmth)
                    target[to + 1] = clampByte(Float(bytes[from + 1]) * recipe.brightness)
                    target[to + 2] = clampByte(Float(bytes[from + 2]) * recipe.brightness / recipe.warmth)
                    target[to + 3] = 255
                }
            }
        }
        return data
    }

    private static func mirroredHeights(_ heights: [Float], side: Int) -> [Float] {
        let out = side * 2
        var result = [Float](repeating: 0, count: out * out)
        for y in 0..<out {
            let sy = source(y, side)
            for x in 0..<out {
                result[x + y * out] = heights[source(x, side) + sy * side]
            }
        }
        return result
    }

    /// Tangent-space normals from central differences, wrapping at the edges.
    private static func normals(_ heights: [Float], side: Int, strength: Float) -> Data {
        var data = Data(count: side * side * 4)
        let scale = strength / 16
        data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let target = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<side {
                let up = ((y - 1 + side) % side) * side
                let down = ((y + 1) % side) * side
                for x in 0..<side {
                    let left = (x - 1 + side) % side
                    let right = (x + 1) % side
                    let dx = (heights[left + y * side] - heights[right + y * side]) * scale
                    let dy = (heights[x + down] - heights[x + up]) * scale
                    let inverse = 1 / (dx * dx + dy * dy + 1).squareRoot()
                    let to = (x + y * side) * 4
                    target[to] = clampByte((dx * inverse * 0.5 + 0.5) * 255)
                    target[to + 1] = clampByte((dy * inverse * 0.5 + 0.5) * 255)
                    target[to + 2] = clampByte((inverse * 0.5 + 0.5) * 255)
                    target[to + 3] = 255
                }
            }
        }
        return data
    }

    /// Low places hold liquid and shine; the tops of the lumps are dull.
    private static func roughness(_ heights: [Float], side: Int, recipe: Recipe) -> Data {
        var low = Float.greatestFiniteMagnitude
        var high = -Float.greatestFiniteMagnitude
        for value in heights {
            low = min(low, value)
            high = max(high, value)
        }
        let range = max(0.001, high - low)
        var data = Data(count: side * side * 4)
        data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let target = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for i in 0..<(side * side) {
                let t = (heights[i] - low) / range
                let dry = smooth((t - 0.3) / 0.45)
                let value = (recipe.wetBase + recipe.dryRange * dry) * 255
                let byte = clampByte(value)
                target[i * 4] = byte
                target[i * 4 + 1] = byte
                target[i * 4 + 2] = byte
                target[i * 4 + 3] = 255
            }
        }
        return data
    }

    @inline(__always)
    private static func smooth(_ t: Float) -> Float {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }

    @inline(__always)
    private static func clampByte(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, value)))
    }
}
