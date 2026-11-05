import SceneKit
import UIKit

/// The falling part of one stream: the liquid arc from the cloud to the road, its loose drops and
/// the cloud with the butt it comes from. Its origin is the landing point. All nodes are made once;
/// every frame only moves, turns, shows or hides them.
@MainActor
final class PissBody {
    /// Largest lean of the arc, in radians, while the source catches up with a swinging stream.
    private static let maxLean = 0.3
    /// Seconds the source takes to follow the landing point, so a swaying stream visibly swings.
    private static let followSeconds = 1.4
    /// The source sits a little beyond the landing point, so the arc is seen slightly from the side.
    private static let yawBase = 0.22
    private static let yawSpread = 0.14
    /// Where loose drops leave the stream while it pours.
    private static let dripU = 0.7

    /// Leans the whole arc about the landing point; the item adds it to its root.
    let lean = SCNNode()
    let drips = PissParticles.drips()
    private let arc = SCNNode()
    private let tube: SCNNode
    private let pieces: [SCNNode]
    private let pieceStart: [Double]
    private let pieceEnd: [Double]
    private let head: SCNNode
    private let dripNode = SCNNode()
    private let cloud: SCNNode
    private var center = 0.0
    private var hasCenter = false

    init(kit: StreamKit) {
        tube = SCNNode(geometry: kit.fullTube)
        var made: [SCNNode] = []
        for geometry in kit.pieces { made.append(SCNNode(geometry: geometry)) }
        pieces = made
        pieceStart = kit.pieceStart
        pieceEnd = kit.pieceEnd
        head = SCNNode(geometry: kit.head)
        cloud = SCNNode(geometry: kit.cloudPlane)
        let source = PissArc.point(0)
        cloud.position = SCNVector3(Float(source.x), Float(source.y + kit.cloudLift), Float(source.z))
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        cloud.constraints = [billboard]
        dripNode.addParticleSystem(drips)
        arc.addChildNode(tube)
        for piece in pieces { arc.addChildNode(piece) }
        arc.addChildNode(head)
        arc.addChildNode(dripNode)
        arc.addChildNode(cloud)
        lean.addChildNode(arc)
        reset()
    }

    func reset() {
        hasCenter = false
        drips.birthRate = 0
        drips.reset()
        tube.isHidden = true
        for piece in pieces { piece.isHidden = true }
        head.isHidden = true
        cloud.opacity = 0
        lean.eulerAngles = SCNVector3(0, 0, 0)
    }

    /// Which side of the road the stream comes from (+1 right, -1 left), varied a little by `phase`.
    func aim(side: Double, phase: Double) {
        let yaw = PissBody.yawBase + PissBody.yawSpread * sin(phase)
        arc.eulerAngles = SCNVector3(0, Float(side > 0 ? yaw : Double.pi - yaw), 0)
    }

    /// Leans the arc so its source lags behind a landing point that moves sideways.
    func follow(landingX: Double, dt: Double) {
        if !hasCenter {
            center = landingX
            hasCenter = true
        } else if dt > 0 {
            center += (landingX - center) * min(1, dt / PissBody.followSeconds)
        }
        let angle = atan((landingX - center) / PissArc.height)
        let clamped = max(-PissBody.maxLean, min(PissBody.maxLean, angle))
        lean.eulerAngles = SCNVector3(0, 0, Float(clamped))
    }

    /// Shows the liquid between `tail` and `front`, both as `u` along the arc.
    func show(front: Double, tail: Double, cloudOpacity: Double, dripRate: CGFloat) {
        let full = front >= 1 && tail <= 0
        let empty = front <= 0 || tail >= 1
        tube.isHidden = !full
        for index in pieces.indices {
            let inside = pieceStart[index] < front && pieceEnd[index] > tail
            pieces[index].isHidden = full || empty || !inside
        }
        let arriving = !full && !empty && front < 1
        head.isHidden = !arriving
        cloud.opacity = CGFloat(max(0, min(1, cloudOpacity)))
        if arriving {
            place(head, at: front)
            aimDrips(at: front)
        } else if full {
            aimDrips(at: PissBody.dripU)
        }
        drips.birthRate = empty ? 0 : dripRate
    }

    private func place(_ node: SCNNode, at u: Double) {
        node.position = PissArc.vector(PissArc.point(u))
    }

    private func aimDrips(at u: Double) {
        place(dripNode, at: u)
        drips.emittingDirection = PissArc.vector(PissArc.tangent(u))
    }
}
