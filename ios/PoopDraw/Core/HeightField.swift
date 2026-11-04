import Foundation

/// A rectangle of field pixels; `max` edges are exclusive.
struct PixelRect: Equatable {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var isEmpty: Bool { maxX <= minX || maxY <= minY }
}

/// The poop itself: a height map lit per pixel. Fingers carve real grooves into it.
/// Buffers are raw memory updated in place: this runs for every finger move and must not allocate.
final class HeightField {
    let width: Int
    let height: Int
    let scale: Float

    private let heights: UnsafeMutablePointer<Float>
    private let base: UnsafeMutablePointer<Float>
    private let mottle: UnsafeMutablePointer<Float>
    private let gild: UnsafeMutablePointer<Float>
    private let corn: UnsafeMutablePointer<UInt8>
    private let pixels: UnsafeMutablePointer<UInt8>
    private var dirty: [PixelRect] = []

    private static let light = normalized(-0.5, -0.62, 0.6)
    private static let half = normalized(light.0, light.1, light.2 + 1)
    private static let rimReach: Float = 1.7

    var fullRect: PixelRect { PixelRect(minX: 0, minY: 0, maxX: width, maxY: height) }

    init(widthPoints: Int, heightPoints: Int, scale: Int, seed: UInt32) {
        width = max(2, widthPoints * scale)
        height = max(2, heightPoints * scale)
        self.scale = Float(scale)
        let count = width * height
        heights = .allocate(capacity: count)
        base = .allocate(capacity: count)
        mottle = .allocate(capacity: count)
        gild = .allocate(capacity: count)
        corn = .allocate(capacity: count)
        pixels = .allocate(capacity: count * 4)
        gild.initialize(repeating: 0, count: count)
        corn.initialize(repeating: 0, count: count)
        pixels.initialize(repeating: 0, count: count * 4)
        generate(seed: seed)
        heights.initialize(from: base, count: count)
        markDirty(fullRect)
    }

    deinit {
        heights.deallocate()
        base.deallocate()
        mottle.deallocate()
        gild.deallocate()
        corn.deallocate()
        pixels.deallocate()
    }

    func heightAt(xPoints: Float, yPoints: Float) -> Float {
        heights[Int(xPoints * scale) + Int(yPoints * scale) * width]
    }

    // MARK: - Generation

    private func generate(seed: UInt32) {
        var random = Mulberry32(seed: seed)
        let noise = ValueNoise(random: &random)
        defer { noise.free() }
        for y in 0..<height {
            let sy = Float(y) / scale
            for x in 0..<width {
                let sx = Float(x) / scale
                let warp = noise.sample(sx / 70, sy / 70) * 1.6
                let warp2 = noise.sample(sx / 31 + 40, sy / 31) * 0.8
                let lumps = noise.sample(sx / 120 + warp, sy / 120) * 26
                    + noise.sample(sx / 48 - warp, sy / 48 + warp) * 13
                let ridge = 1 - abs(2 * noise.sample(sx / 38 + warp2, sy / 38 - warp2) - 1)
                let crack = smooth01((ridge - 0.94) / 0.06) * 4.5
                let grain = noise.sample(sx / 7, sy / 7) * 2.6 + noise.sample(sx / 2.6, sy / 2.6) * 0.9
                let i = x + y * width
                base[i] = lumps + grain - crack
                mottle[i] = smooth01(noise.sample(sx / 55 + 9, sy / 55) * 0.75 + noise.sample(sx / 11, sy / 11) * 0.45 - 0.1)
            }
        }
        let kernels = Int((Float(width * height) / (scale * scale) / 26000).rounded())
        for _ in 0..<kernels {
            let cx = random.next() * Float(width)
            let cy = random.next() * Float(height)
            let angle = random.next() * .pi
            addKernel(cx: cx, cy: cy, angle: angle, radius: (3 + random.next() * 2) * scale)
        }
    }

    private func addKernel(cx: Float, cy: Float, angle: Float, radius: Float) {
        let cosA = cos(angle)
        let sinA = sin(angle)
        let box = clipped(cx - radius * 1.6, cy - radius * 1.6, cx + radius * 1.6, cy + radius * 1.6)
        forEachPixel(in: box) { x, y in
            let dx = Float(x) - cx
            let dy = Float(y) - cy
            let u = (dx * cosA + dy * sinA) / (radius * 1.5)
            let v = (-dx * sinA + dy * cosA) / radius
            let d = u * u + v * v
            if d < 1 {
                let i = x + y * width
                base[i] += (1 - d) * 2.4
                corn[i] = 1
            }
        }
    }

    // MARK: - Finger

    /// Presses a groove with raised rims along a segment. All arguments are in points.
    func carve(fromX ax: Float, fromY ay: Float, toX bx: Float, toY by: Float, radius: Float) {
        let r = radius * scale
        let x0 = ax * scale
        let y0 = ay * scale
        let dx = bx * scale - x0
        let dy = by * scale - y0
        let length2 = dx * dx + dy * dy
        let length = length2 > 0 ? length2.squareRoot() : 1
        let reach = r * Self.rimReach
        let depth = radius * 0.8
        let rimHeight = radius * 0.3
        let box = clipped(
            min(x0, x0 + dx) - reach, min(y0, y0 + dy) - reach,
            max(x0, x0 + dx) + reach, max(y0, y0 + dy) + reach
        )
        forEachPixel(in: box) { x, y in
            let px = Float(x) - x0
            let py = Float(y) - y0
            let t = length2 > 0 ? min(1, max(0, (px * dx + py * dy) / length2)) : 0
            let ox = px - t * dx
            let oy = py - t * dy
            let d = (ox * ox + oy * oy).squareRoot()
            guard d < reach else { return }
            let i = x + y * width
            if d < r {
                let across = (px * dy - py * dx) / length / scale
                let fingerprint = length2 > 0 ? sin(across * 1.5) * 0.35 : 0
                let ratio = d / r
                heights[i] = min(heights[i], base[i] - depth * (1 - ratio * ratio) - fingerprint)
            } else if heights[i] >= base[i] - 0.3 {
                let bump = sin(.pi * (d - r) / (reach - r)) * rimHeight * (0.45 + mottle[i])
                heights[i] = max(heights[i], base[i] + bump)
            }
        }
        markDirty(expanded(box))
    }

    /// Pulls the surface back toward its untouched shape around a point.
    func smooth(x cx: Float, y cy: Float, radius: Float) {
        let r = radius * scale
        let x0 = cx * scale
        let y0 = cy * scale
        let box = clipped(x0 - r, y0 - r, x0 + r, y0 + r)
        forEachPixel(in: box) { x, y in
            let dx = Float(x) - x0
            let dy = Float(y) - y0
            let d = (dx * dx + dy * dy).squareRoot() / r
            if d < 1 {
                let i = x + y * width
                heights[i] += (base[i] - heights[i]) * 0.45 * (1 - d)
            }
        }
        markDirty(expanded(box))
    }

    func resetCarving() {
        heights.update(from: base, count: width * height)
        gild.update(repeating: 0, count: width * height)
        markDirty(fullRect)
    }

    /// Presses gold letters into the surface. `mask` holds one byte per pixel, 255 inside the letters.
    func applyTitle(mask: [UInt8]) {
        precondition(mask.count == width * height, "Title mask must match the field size")
        let source = mask.map { Float($0) / 255 }
        let press = blurred(source, radius: max(1, Int((1.1 * scale).rounded())))
        let halo = blurred(source, radius: max(2, Int((5 * scale).rounded())))
        for i in 0..<(width * height) {
            heights[i] = base[i] - press[i] * 10 + max(0, halo[i] - press[i]) * 7
            gild[i] = press[i]
        }
        markDirty(fullRect)
    }

    // MARK: - Output

    /// Re-lights everything that changed and reports which rectangles did.
    func flush() -> [PixelRect] {
        let rects = dirty
        dirty.removeAll(keepingCapacity: true)
        for rect in rects where !rect.isEmpty {
            for y in rect.minY..<rect.maxY {
                for x in rect.minX..<rect.maxX { shade(x, y) }
            }
        }
        return rects.filter { !$0.isEmpty }
    }

    /// Copies a rectangle out as tightly packed RGBA bytes.
    func rgba(in rect: PixelRect) -> Data {
        let rowBytes = (rect.maxX - rect.minX) * 4
        var out = Data(count: rowBytes * (rect.maxY - rect.minY))
        out.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            guard let target = raw.baseAddress else { return }
            for (row, y) in (rect.minY..<rect.maxY).enumerated() {
                target.advanced(by: row * rowBytes)
                    .copyMemory(from: pixels + (rect.minX + y * width) * 4, byteCount: rowBytes)
            }
        }
        return out
    }

    @inline(__always)
    private func shade(_ x: Int, _ y: Int) {
        let i = x + y * width
        let left = heights[x > 0 ? i - 1 : i]
        let right = heights[x < width - 1 ? i + 1 : i]
        let up = heights[y > 0 ? i - width : i]
        let down = heights[y < height - 1 ? i + width : i]
        let sx = (left - right) * scale * 0.5
        let sy = (up - down) * scale * 0.5
        let invLength = 1 / (sx * sx + sy * sy + 1).squareRoot()
        let nx = sx * invLength
        let ny = sy * invLength
        let light = Self.light
        let half = Self.half
        let diffuse = max(0, nx * light.0 + ny * light.1 + invLength * light.2)
        let facing = max(0, nx * half.0 + ny * half.1 + invLength * half.2)
        let dug = base[i] - heights[i]
        let gilded = gild[i]
        let occlusion = 1 - smooth01(dug / 9) * 0.5 * (1 - gilded)
        let m = mottle[i]
        let wet = 0.2 + smooth01(dug / 5) * 0.28 + (1 - m) * 0.12
        let f2 = facing * facing
        let f4 = f2 * f2
        let f8 = f4 * f4
        let f16 = f8 * f8
        let shine = f16 * f16 * f2 * wet * 255
        let brightness = (0.34 + diffuse * 1.02) * occlusion
        let isCorn = corn[i] == 1
        let target = pixels + i * 4
        target[0] = channel(66, 139, 214, 240, m, isCorn, gilded, brightness, shine)
        target[1] = channel(39, 92, 170, 190, m, isCorn, gilded, brightness, shine)
        target[2] = channel(18, 47, 66, 72, m, isCorn, gilded, brightness, shine)
        target[3] = 255
    }

    @inline(__always)
    private func channel(
        _ dark: Float, _ lightBrown: Float, _ cornColor: Float, _ gold: Float,
        _ m: Float, _ isCorn: Bool, _ gilded: Float, _ brightness: Float, _ shine: Float
    ) -> UInt8 {
        let albedo = isCorn ? cornColor : dark + (lightBrown - dark) * m
        let value = (albedo + (gold - albedo) * gilded) * brightness + shine
        return UInt8(max(0, min(255, value)))
    }

    // MARK: - Helpers

    @inline(__always)
    private func forEachPixel(in box: PixelRect, _ body: (Int, Int) -> Void) {
        guard !box.isEmpty else { return }
        for y in box.minY..<box.maxY {
            for x in box.minX..<box.maxX { body(x, y) }
        }
    }

    private func clipped(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float) -> PixelRect {
        let limitX = Float(width)
        let limitY = Float(height)
        return PixelRect(
            minX: Int(max(0, min(limitX, x0.rounded(.down)))),
            minY: Int(max(0, min(limitY, y0.rounded(.down)))),
            maxX: Int(max(0, min(limitX, x1.rounded(.up)))),
            maxY: Int(max(0, min(limitY, y1.rounded(.up))))
        )
    }

    /// Lighting reads neighbours, so a pixel beside a change needs re-lighting too.
    private func expanded(_ box: PixelRect) -> PixelRect {
        PixelRect(
            minX: max(0, box.minX - 1), minY: max(0, box.minY - 1),
            maxX: min(width, box.maxX + 1), maxY: min(height, box.maxY + 1)
        )
    }

    private func markDirty(_ rect: PixelRect) {
        if !rect.isEmpty { dirty.append(rect) }
    }

    private func blurred(_ source: [Float], radius: Int) -> [Float] {
        let horizontal = boxPass(source, along: width, across: height, stepAlong: 1, stepAcross: width, radius: radius)
        return boxPass(horizontal, along: height, across: width, stepAlong: width, stepAcross: 1, radius: radius)
    }

    private func boxPass(
        _ input: [Float], along: Int, across: Int, stepAlong: Int, stepAcross: Int, radius: Int
    ) -> [Float] {
        var out = [Float](repeating: 0, count: input.count)
        let norm = 1 / Float(2 * radius + 1)
        input.withUnsafeBufferPointer { source in
            out.withUnsafeMutableBufferPointer { target in
                for b in 0..<across {
                    let offset = b * stepAcross
                    let at: (Int) -> Float = { source[min(along - 1, max(0, $0)) * stepAlong + offset] }
                    var sum: Float = 0
                    for a in -radius...radius { sum += at(a) }
                    for a in 0..<along {
                        target[a * stepAlong + offset] = sum * norm
                        sum += at(a + radius + 1) - at(a - radius)
                    }
                }
            }
        }
        return out
    }

    private static func normalized(_ x: Float, _ y: Float, _ z: Float) -> (Float, Float, Float) {
        let length = (x * x + y * y + z * z).squareRoot()
        return (x / length, y / length, z / length)
    }
}

@inline(__always)
private func smooth01(_ t: Float) -> Float {
    if t <= 0 { return 0 }
    if t >= 1 { return 1 }
    return t * t * (3 - 2 * t)
}

/// Small seeded generator, so one seed always yields the same pile.
private struct Mulberry32 {
    private var state: UInt32

    init(seed: UInt32) {
        state = seed
    }

    mutating func next() -> Float {
        state = state &+ 0x6d2b_79f5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Float((t ^ (t >> 14)) >> 8) / 16_777_216
    }
}

/// Bilinear value noise over a 256x256 lattice that wraps around.
private struct ValueNoise {
    private let grid: UnsafeMutablePointer<Float>

    init(random: inout Mulberry32) {
        grid = .allocate(capacity: 65536)
        for i in 0..<65536 { grid[i] = random.next() }
    }

    func free() {
        grid.deallocate()
    }

    @inline(__always)
    func sample(_ x: Float, _ y: Float) -> Float {
        let fx = x.rounded(.down)
        let fy = y.rounded(.down)
        let u = x - fx
        let v = y - fy
        let su = u * u * (3 - 2 * u)
        let sv = v * v * (3 - 2 * v)
        let xi = Int(fx)
        let yi = Int(fy)
        let x0 = xi & 255
        let x1 = (xi + 1) & 255
        let y0 = (yi & 255) << 8
        let y1 = ((yi + 1) & 255) << 8
        let a = grid[x0 | y0]
        let b = grid[x1 | y0]
        let c = grid[x0 | y1]
        let d = grid[x1 | y1]
        let top = a + (b - a) * su
        let bottom = c + (d - c) * su
        return top + (bottom - top) * sv
    }
}
