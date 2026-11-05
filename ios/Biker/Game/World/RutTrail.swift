import SceneKit
import UIKit

/// The groove the tyre leaves in the poop behind the bike. It remembers where the bike was and
/// lays short strips along that path, so it stays put on pause and curves with the steering.
/// Every strip shares one flat quad (one draw call each; a box would be six).
@MainActor
final class RutTrail {
    private static let segmentLength = 0.8
    private static let segmentCount = 30
    private static let width = 0.34

    private var segments: [SCNNode] = []
    private var history: [(distance: Double, x: Double)] = []

    init(parent: SCNNode, library: MaterialLibrary) {
        let material = library.shared("rut", bend: false) {
            let made = WorldMaterials.decal(SpriteTextures.rut, additive: false, lit: true)
            made.roughness.contents = NSNumber(value: 0.2)
            WorldMaterials.repeating(made.diffuse, scaleX: 1, scaleY: 1)
            made.isDoubleSided = true
            return made
        }
        let quad = FlatQuad.make(width: Float(Self.width), length: Float(Self.segmentLength + 0.04))
        quad.firstMaterial = material
        for _ in 0..<Self.segmentCount {
            let node = SCNNode(geometry: quad)
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

/// A flat rectangle on the ground (y = 0, normal up), centred on the origin, length along z.
enum FlatQuad {
    static func make(width: Float, length: Float) -> SCNGeometry {
        let x = width / 2
        let z = length / 2
        let vertices: [SCNVector3] = [
            SCNVector3(-x, 0, -z), SCNVector3(x, 0, -z), SCNVector3(x, 0, z), SCNVector3(-x, 0, z),
        ]
        let normals: [SCNVector3] = [
            SCNVector3(0, 1, 0), SCNVector3(0, 1, 0), SCNVector3(0, 1, 0), SCNVector3(0, 1, 0),
        ]
        let uvs: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)]
        let indices: [Int32] = [0, 3, 2, 0, 2, 1]
        let sources: [SCNGeometrySource] = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals),
            SCNGeometrySource(textureCoordinates: uvs),
        ]
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: sources, elements: [element])
    }
}
