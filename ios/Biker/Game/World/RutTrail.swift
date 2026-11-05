import SceneKit
import UIKit

/// The groove the tyre leaves in the poop behind the bike. It remembers where the bike was and
/// lays short strips along that path, so it stays put on pause and curves with the steering.
@MainActor
final class RutTrail {
    private static let segmentLength = 0.6
    private static let segmentCount = 40
    private static let width = 0.34

    private var segments: [SCNNode] = []
    private var history: [(distance: Double, x: Double)] = []

    init(parent: SCNNode, library: MaterialLibrary) {
        let material = library.shared("rut", bend: false) {
            let made = WorldMaterials.decal(SpriteTextures.rut, additive: false, lit: true)
            made.roughness.contents = NSNumber(value: 0.2)
            WorldMaterials.repeating(made.diffuse, scaleX: 1, scaleY: 1)
            return made
        }
        for _ in 0..<Self.segmentCount {
            let shape = SCNBox(width: CGFloat(Self.width), height: 0.004, length: CGFloat(Self.segmentLength + 0.04), chamferRadius: 0)
            shape.firstMaterial = material
            let node = SCNNode(geometry: shape)
            node.isHidden = true
            node.castsShadow = false
            parent.addChildNode(node)
            segments.append(node)
        }
    }

    func reset() {
        history.removeAll(keepingCapacity: true)
        for node in segments { node.isHidden = true }
    }

    /// `record` false keeps the old groove without adding to it (paused, airborne, idle garage).
    func update(distance: Double, x: Double, record: Bool) {
        if let last = history.last, last.distance > distance + 1 { reset() }
        if record, history.last.map({ distance - $0.distance >= Self.segmentLength }) ?? true {
            history.append((distance, x))
        }
        let oldest = distance - Double(Self.segmentCount + 2) * Self.segmentLength
        if let first = history.first, first.distance < oldest { history.removeFirst() }
        let count = history.count
        for (index, node) in segments.enumerated() {
            let newer = count - 1 - index
            guard newer >= 1 else {
                node.isHidden = true
                continue
            }
            let a = history[newer]
            let b = history[newer - 1]
            let midDistance = (a.distance + b.distance) / 2
            node.isHidden = false
            node.position = SCNVector3(Float((a.x + b.x) / 2), 0.02, Float(distance - midDistance))
            node.eulerAngles.y = Float(-atan2(a.x - b.x, a.distance - b.distance))
        }
    }
}
