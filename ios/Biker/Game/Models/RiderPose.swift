import Foundation
import simd

/// Joint positions of a seated rider, solved from a bike layout: pelvis on the seat,
/// hands on the grips and feet on the pegs, with two-bone IK for arms and legs.
/// Index 0 of every pair is the right side (x > 0), index 1 the left.
struct RiderPose {
    static let neckDistance: Float = 0.52
    static let shoulderDistance: Float = 0.45
    static let shoulderHalfWidth: Float = 0.19
    static let hipHalfWidth: Float = 0.11
    static let upperArm: Float = 0.31
    static let forearm: Float = 0.3
    static let thigh: Float = 0.45
    static let shin: Float = 0.44
    static let ankleHeight: Float = 0.09
    static let helmetRadius: Float = 0.16

    let hip: RigVec
    /// Unit vector from pelvis to neck.
    let torsoDirection: RigVec
    /// Unit vector out of the rider's back (perpendicular to the torso, pointing backwards).
    let backDirection: RigVec
    let neck: RigVec
    /// Helmet centre. The head stays upright to look down the road.
    let head: RigVec
    let shoulders: [RigVec]
    let elbows: [RigVec]
    let hands: [RigVec]
    let hipJoints: [RigVec]
    let knees: [RigVec]
    let ankles: [RigVec]
    /// Where each boot sole rests (on the peg).
    let feet: [RigVec]

    /// Upper-back anchor for capes and wings.
    var upperBack: RigVec {
        hip + torsoDirection * 0.4 + backDirection * 0.13
    }

    init(layout: BikeLayout) {
        let sides: [Float] = [1, -1]
        let lean = layout.torsoLean
        let torso = RigVec(0, cos(lean), -sin(lean))
        hip = layout.hip
        torsoDirection = torso
        backDirection = RigVec(0, sin(lean), cos(lean))
        let neckPoint = layout.hip + torso * RiderPose.neckDistance
        neck = neckPoint
        head = neckPoint + RigVec(0, 0.17, -0.02)

        let shoulderCenter = layout.hip + torso * RiderPose.shoulderDistance
        let shoulderPoints = sides.map { shoulderCenter + RigVec($0 * RiderPose.shoulderHalfWidth, 0, 0) }
        let arms = sides.indices.map { index -> (RigVec, RigVec) in
            let side = sides[index]
            let grip = RigVec(side * layout.grip.x, layout.grip.y, layout.grip.z)
            let pole = simd_normalize(RigVec(side * 0.7, -0.5, 0.5))
            return RiderPose.solve(root: shoulderPoints[index], target: grip,
                                   upper: RiderPose.upperArm, lower: RiderPose.forearm, pole: pole)
        }
        shoulders = shoulderPoints
        elbows = arms.map { $0.0 }
        hands = arms.map { $0.1 }

        let hipPoints = sides.map { layout.hip + RigVec($0 * RiderPose.hipHalfWidth, -0.02, 0) }
        let footPoints = sides.map { RigVec($0 * layout.peg.x, layout.peg.y, layout.peg.z) }
        let legs = sides.indices.map { index -> (RigVec, RigVec) in
            let side = sides[index]
            let ankle = footPoints[index] + RigVec(0, RiderPose.ankleHeight, 0.03)
            let pole = simd_normalize(RigVec(side * 0.35, 0.6, -1))
            return RiderPose.solve(root: hipPoints[index], target: ankle,
                                   upper: RiderPose.thigh, lower: RiderPose.shin, pole: pole)
        }
        hipJoints = hipPoints
        knees = legs.map { $0.0 }
        ankles = legs.map { $0.1 }
        feet = footPoints
    }

    /// Two-bone IK. Returns the middle joint and the reached end point (the target, or as close
    /// as the limb allows). The joint bends towards `pole`.
    static func solve(root: RigVec, target: RigVec, upper: Float, lower: Float, pole: RigVec) -> (RigVec, RigVec) {
        let delta = target - root
        let rawDistance = simd_length(delta)
        let direction = rawDistance > 0.0001 ? delta / rawDistance : RigVec(0, -1, 0)
        let distance = min(max(rawDistance, abs(upper - lower) + 0.01), upper + lower - 0.002)
        let end = root + direction * distance
        let along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
        let height = sqrt(max(upper * upper - along * along, 0))
        let sideways = pole - direction * simd_dot(pole, direction)
        let sideLength = simd_length(sideways)
        let bend = sideLength > 0.0001 ? sideways / sideLength : RigVec(0, 0, -1)
        return (root + direction * along + bend * height, end)
    }
}
