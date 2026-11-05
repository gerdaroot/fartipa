import SceneKit
import simd

/// The shape of one piss stream in its own frame. The landing point is the origin, the source
/// (a cloud with a bare butt) hangs `height` metres up and `reach` metres out along +x, and the
/// liquid falls on a parabola: constant sideways speed plus gravity. So the arc parameter `u`
/// (0 at the source, 1 on the road) is also the time the liquid has been falling.
enum PissArc {
    static let height = 22.0
    static let reach = 18.0
    /// How far the stream first rises after leaving the source, as a share of `height`.
    static let lift = 0.25
    static let topRadius = 0.44
    static let bottomRadius = 0.13
    /// Rings of vertices along the whole stream.
    static let ringCount = 72
    /// The arriving stream is cut into pieces of this many ring gaps.
    static let ringsPerPiece = 4
    static let pieceCount = ringCount / ringsPerPiece
    /// Rings from here down use the beaded material: the stream breaks into drops.
    static let breakRing = 46
    /// Metres of stream per repeat of the liquid texture.
    static let textureLength = 3.0
    private static let samples = 480
    /// A bend costs rings like this many metres per radian, so the tight top of the arc stays round.
    private static let turnWeight = 6.0

    /// Where the liquid is at `u`.
    static func point(_ u: Double) -> SIMD3<Double> {
        let y = height * (1 + lift * u - (1 + lift) * u * u)
        return SIMD3<Double>(reach * (1 - u), y, 0)
    }

    /// Unit direction the liquid moves at `u`.
    static func tangent(_ u: Double) -> SIMD3<Double> {
        let dy = height * (lift - 2 * (1 + lift) * u)
        return simd_normalize(SIMD3<Double>(-reach, dy, 0))
    }

    /// Thick at the source, thin where it hits the road.
    static func radius(_ u: Double) -> Double {
        topRadius + (bottomRadius - topRadius) * u
    }

    static func vector(_ value: SIMD3<Double>) -> SCNVector3 {
        SCNVector3(Float(value.x), Float(value.y), Float(value.z))
    }

    /// `u` and the distance along the stream at each ring.
    struct Rings {
        let u: [Double]
        let length: [Double]
    }

    static let rings: Rings = makeRings()

    private static func makeRings() -> Rings {
        let (metric, lengths) = sampledMetric()
        var us: [Double] = []
        var ringLengths: [Double] = []
        us.reserveCapacity(ringCount + 1)
        ringLengths.reserveCapacity(ringCount + 1)
        let total = metric[samples]
        var cursor = 0
        for ring in 0...ringCount {
            let target = total * Double(ring) / Double(ringCount)
            while cursor < samples - 1 && metric[cursor + 1] < target { cursor += 1 }
            let span = max(1e-9, metric[cursor + 1] - metric[cursor])
            let fraction = max(0, min(1, (target - metric[cursor]) / span))
            us.append((Double(cursor) + fraction) / Double(samples))
            ringLengths.append(lengths[cursor] + fraction * (lengths[cursor + 1] - lengths[cursor]))
        }
        return Rings(u: us, length: ringLengths)
    }

    /// Cumulative length plus weighted turning, and plain length, at every sample.
    private static func sampledMetric() -> ([Double], [Double]) {
        var metric: [Double] = [0]
        var lengths: [Double] = [0]
        metric.reserveCapacity(samples + 1)
        lengths.reserveCapacity(samples + 1)
        var previous = point(0)
        var previousTangent = tangent(0)
        for step in 1...samples {
            let u = Double(step) / Double(samples)
            let current = point(u)
            let direction = tangent(u)
            let length = simd_length(current - previous)
            let turn = acos(max(-1, min(1, simd_dot(direction, previousTangent))))
            metric.append(metric[step - 1] + length + turnWeight * turn)
            lengths.append(lengths[step - 1] + length)
            previous = current
            previousTangent = direction
        }
        return (metric, lengths)
    }
}
