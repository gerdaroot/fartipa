import Foundation

/// A kicker ramp in a lane. Riding over its lip at `z` throws the bike high into the air, over
/// whatever stands behind it.
struct RoadRamp: Equatable {
    /// Metres from the foot of the ramp to its lip, for graphics. The ramp lies before `z`.
    static let length = 6.0
    static let width = 2.4
    /// Lip height in metres, for graphics.
    static let lipHeight = 1.1
    /// How far sideways from the ramp's middle the bike still catches it.
    static let reach = 1.3

    let id: Int
    let x: Double
    /// The lip: the bike takes off when it crosses this.
    let z: Double

    init(id: Int = 0, x: Double, z: Double) {
        self.id = id
        self.x = x
        self.z = z
    }
}

enum ManholeKind: String, CaseIterable, Equatable {
    /// An open manhole that spouts sewage in bursts. Only dangerous while it spouts.
    case geyser
    /// A manhole cover rolling on its edge across the road from side to side.
    case rollingLid

    /// How close to its middle the bike must be for it to hit.
    var reach: Double {
        switch self {
        case .geyser: return 1.1
        case .rollingLid: return 1.0
        }
    }
}

/// A low hazard on the road. A jump clears it; riding into it costs a life like a stream.
struct Manhole: Equatable {
    /// Seconds of one spout-and-rest cycle of a geyser.
    static let geyserCycle = 1.8
    /// The first part of each cycle a geyser spouts.
    static let sprayShare = 0.5
    static let lidAmplitude = 3.0
    /// Radians per second of the rolling lid's swing.
    static let lidRate = 1.25

    let id: Int
    let kind: ManholeKind
    let baseX: Double
    let z: Double
    /// 0..<1: where in its cycle (geyser) or swing (lid) it starts.
    let phase: Double

    init(id: Int = 0, kind: ManholeKind, baseX: Double, z: Double, phase: Double = 0) {
        self.id = id
        self.kind = kind
        self.baseX = baseX
        self.z = z
        self.phase = phase
    }

    /// Where the hazard is across the road at a moment of `BikeRun.time`.
    func x(atTime time: Double) -> Double {
        switch kind {
        case .geyser: return baseX
        case .rollingLid: return baseX + Self.lidAmplitude * sin(phase * 2 * Double.pi + time * Self.lidRate)
        }
    }

    /// 0..<1: how far into its cycle a geyser is. It spouts while this is below `sprayShare`.
    func cycle(atTime time: Double) -> Double {
        let raw = phase + time / Self.geyserCycle
        return raw - raw.rounded(.down)
    }

    /// The lid always hurts; a geyser only while it spouts.
    func isDangerous(atTime time: Double) -> Bool {
        switch kind {
        case .geyser: return cycle(atTime: time) < Self.sprayShare
        case .rollingLid: return true
        }
    }
}
