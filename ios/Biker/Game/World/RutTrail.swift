import SceneKit
import UIKit

/// The groove the tyre leaves in the poop behind the bike. Short strips are laid along the bike's
/// path, so it stays put on pause and curves with the steering. Every strip shares one flat quad.
/// Strips sit in road coordinates under one holder that slides with the ride, so a frame costs a
/// single position write; a strip is only touched when it is laid. Lower tiers use fewer strips
/// (most of the groove is behind the chase camera anyway).
@MainActor
final class RutTrail {
    private static let segmentLength = 0.8
    private static let segmentCount = 30
    private static let width = 0.34
    /// Past this many metres from the anchor every strip is shifted, so floats stay precise.
    private static let rebaseMetres = 2000.0
    /// Strips in use, set by the render tier.
    static var activeSegments = segmentCount

    private let strip = SCNNode()
    private var segments: [SCNNode] = []
    private var last: (distance: Double, x: Double)?
    private var anchor = 0.0
    private var nextSlot = 0
    private var usedLimit = segmentCount
    private var stripZ = Float.nan

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
        strip.castsShadow = false
        parent.addChildNode(strip)
        for _ in 0..<Self.segmentCount {
            let node = SCNNode(geometry: quad)
            node.isHidden = true
            node.castsShadow = false
            strip.addChildNode(node)
            segments.append(node)
        }
    }

    func reset() {
        last = nil
        nextSlot = 0
        for node in segments { node.perfSetHidden(true) }
    }

    /// `record` false keeps the old groove without adding to it (paused, airborne, crashed).
    func update(distance: Double, x: Double, record: Bool) {
        if let last, last.distance > distance + 1 { reset() }
        if abs(distance - anchor) > Self.rebaseMetres { rebase(to: distance) }
        applyLimit()
        if record { lay(distance: distance, x: x) }
        let z = Float(distance - anchor)
        if z != stripZ {
            stripZ = z
            strip.position = SCNVector3(0, 0, z)
        }
    }

    private func lay(distance: Double, x: Double) {
        guard let previous = last else {
            last = (distance, x)
            return
        }
        guard distance - previous.distance >= Self.segmentLength else { return }
        let node = segments[nextSlot]
        nextSlot = (nextSlot + 1) % usedLimit
        let middle = (distance + previous.distance) / 2
        node.position = SCNVector3(Float((x + previous.x) / 2), 0.02, Float(anchor - middle))
        node.eulerAngles = SCNVector3(0, Float(-atan2(x - previous.x, distance - previous.distance)), 0)
        node.perfSetHidden(false)
        last = (distance, x)
    }

    private func rebase(to distance: Double) {
        let shift = Float(distance - anchor)
        anchor = distance
        for node in segments {
            var position = node.position
            position.z += shift
            node.position = position
        }
    }

    private func applyLimit() {
        let limit = max(1, min(Self.segmentCount, Self.activeSegments))
        guard limit != usedLimit else { return }
        usedLimit = limit
        nextSlot = 0
        for index in limit..<Self.segmentCount { segments[index].perfSetHidden(true) }
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
