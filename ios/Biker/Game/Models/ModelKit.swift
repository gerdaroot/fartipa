import SceneKit
import UIKit
import simd

/// A point or direction in rig space: metres, y up, the bike faces -z.
typealias RigVec = SIMD3<Float>

/// Small helpers for building models out of cached primitives.
///
/// Geometries are cached by shape and handed out as shallow copies, so vertex data is shared
/// while every copy can carry its own material.
@MainActor
enum ModelKit {
    private static var geometryCache: [String: SCNGeometry] = [:]

    nonisolated static let up = RigVec(0, 1, 0)
    private static let pathFlatness: CGFloat = 0.004
    private static let roundSegments = 24

    // MARK: - Cache

    private static func lookup(_ key: String) -> SCNGeometry? {
        guard let hit = geometryCache[key] else { return nil }
        return (hit.copy() as? SCNGeometry) ?? hit
    }

    private static func remember(_ key: String, _ geometry: SCNGeometry) -> SCNGeometry {
        geometryCache[key] = geometry
        return (geometry.copy() as? SCNGeometry) ?? geometry
    }

    private static func dims(_ values: [Float]) -> String {
        values.map { String(format: "%.4f", $0) }.joined(separator: "_")
    }

    // MARK: - Primitives

    static func sphere(_ radius: Float) -> SCNGeometry {
        let key = "sphere-" + dims([radius])
        if let hit = lookup(key) { return hit }
        let sphere = SCNSphere(radius: CGFloat(radius))
        sphere.segmentCount = roundSegments
        return remember(key, sphere)
    }

    static func cylinder(_ radius: Float, _ height: Float) -> SCNGeometry {
        let key = "cyl-" + dims([radius, height])
        if let hit = lookup(key) { return hit }
        let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        cylinder.radialSegmentCount = roundSegments
        return remember(key, cylinder)
    }

    static func capsule(_ radius: Float, _ height: Float) -> SCNGeometry {
        let key = "cap-" + dims([radius, height])
        if let hit = lookup(key) { return hit }
        let capsule = SCNCapsule(capRadius: CGFloat(radius), height: CGFloat(max(height, radius * 2)))
        capsule.radialSegmentCount = roundSegments
        return remember(key, capsule)
    }

    static func box(_ width: Float, _ height: Float, _ length: Float, chamfer: Float = 0) -> SCNGeometry {
        let key = "box-" + dims([width, height, length, chamfer])
        if let hit = lookup(key) { return hit }
        let safeChamfer = min(chamfer, min(width, min(height, length)) * 0.49)
        let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(length),
                         chamferRadius: CGFloat(safeChamfer))
        box.chamferSegmentCount = safeChamfer > 0 ? 4 : 1
        return remember(key, box)
    }

    static func cone(_ top: Float, _ bottom: Float, _ height: Float) -> SCNGeometry {
        let key = "cone-" + dims([top, bottom, height])
        if let hit = lookup(key) { return hit }
        let cone = SCNCone(topRadius: CGFloat(top), bottomRadius: CGFloat(bottom), height: CGFloat(height))
        cone.radialSegmentCount = roundSegments
        return remember(key, cone)
    }

    static func torus(_ ring: Float, _ pipe: Float) -> SCNGeometry {
        let key = "torus-" + dims([ring, pipe])
        if let hit = lookup(key) { return hit }
        let torus = SCNTorus(ringRadius: CGFloat(ring), pipeRadius: CGFloat(pipe))
        torus.ringSegmentCount = 36
        torus.pipeSegmentCount = 14
        return remember(key, torus)
    }

    static func tube(_ inner: Float, _ outer: Float, _ height: Float) -> SCNGeometry {
        let key = "tube-" + dims([inner, outer, height])
        if let hit = lookup(key) { return hit }
        let tube = SCNTube(innerRadius: CGFloat(inner), outerRadius: CGFloat(outer), height: CGFloat(height))
        tube.radialSegmentCount = 36
        return remember(key, tube)
    }

    /// A side profile extruded across the bike. `key` must be unique per path.
    /// Path coordinates are (forward, up) in metres, where forward is -z.
    static func shape(_ key: String, width: Float, chamfer: Float, path: () -> UIBezierPath) -> SCNGeometry {
        let fullKey = "shape-\(key)-" + dims([width, chamfer])
        if let hit = lookup(fullKey) { return hit }
        let bezier = path()
        bezier.flatness = pathFlatness
        let shape = SCNShape(path: bezier, extrusionDepth: CGFloat(width))
        shape.chamferRadius = CGFloat(min(chamfer, width * 0.49))
        shape.chamferMode = .both
        return remember(fullKey, shape)
    }

    // MARK: - Placement

    @discardableResult
    static func add(
        _ geometry: SCNGeometry, _ material: SCNMaterial, to parent: SCNNode, at position: RigVec,
        euler: RigVec = .zero, scale: RigVec = RigVec(repeating: 1)
    ) -> SCNNode {
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.simdPosition = position
        node.simdEulerAngles = euler
        node.simdScale = scale
        parent.addChildNode(node)
        return node
    }

    /// Rotation that turns the +y axis onto `direction` (which must be normalised).
    static func orientation(alongY direction: RigVec) -> simd_quatf {
        if simd_dot(up, direction) < -0.9999 {
            return simd_quatf(angle: .pi, axis: RigVec(1, 0, 0))
        }
        return simd_quatf(from: up, to: direction)
    }

    /// A rounded tube (or a flat-ended one) from `start` to `end`.
    @discardableResult
    static func rod(
        _ start: RigVec, _ end: RigVec, radius: Float, _ material: SCNMaterial, to parent: SCNNode,
        rounded: Bool = true, scale: RigVec = RigVec(repeating: 1)
    ) -> SCNNode {
        let delta = end - start
        let length = max(simd_length(delta), 0.001)
        let geometry = rounded ? capsule(radius, length + radius * 2) : cylinder(radius, length)
        let node = add(geometry, material, to: parent, at: (start + end) * 0.5, scale: scale)
        node.simdOrientation = orientation(alongY: delta / length)
        return node
    }

    /// A chain of rods through `points`.
    static func pipe(_ points: [RigVec], radius: Float, _ material: SCNMaterial, to parent: SCNNode) {
        guard points.count > 1 else { return }
        for index in 1..<points.count {
            rod(points[index - 1], points[index], radius: radius, material, to: parent)
        }
    }

    /// An extruded side profile placed so that path x maps to -z and the extrusion spans x.
    @discardableResult
    static func profile(
        _ key: String, width: Float, chamfer: Float, _ material: SCNMaterial, to parent: SCNNode,
        x: Float = 0, path: () -> UIBezierPath
    ) -> SCNNode {
        let geometry = shape(key, width: width, chamfer: chamfer, path: path)
        return add(geometry, material, to: parent, at: RigVec(x, 0, 0), euler: RigVec(0, .pi / 2, 0))
    }

    /// Mirror helper: the same point on the other side of the bike.
    nonisolated static func mirrored(_ point: RigVec) -> RigVec {
        RigVec(-point.x, point.y, point.z)
    }

    /// Bakes a built subtree into one node; the template keeps no transform of its own.
    static func flatten(_ content: SCNNode, name: String) -> SCNNode {
        let flat = content.flattenedClone()
        flat.name = name
        return flat
    }
}

/// One step of a closed side-profile path; coordinates are (forward, up) in metres.
enum RigPathStep {
    case line(CGFloat, CGFloat)
    case quad(CGFloat, CGFloat, controlX: CGFloat, controlY: CGFloat)

    @MainActor
    static func path(_ startX: CGFloat, _ startY: CGFloat, _ steps: [RigPathStep]) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: startX, y: startY))
        for step in steps {
            switch step {
            case let .line(x, y):
                path.addLine(to: CGPoint(x: x, y: y))
            case let .quad(x, y, controlX, controlY):
                path.addQuadCurve(to: CGPoint(x: x, y: y), controlPoint: CGPoint(x: controlX, y: controlY))
            }
        }
        path.close()
        return path
    }
}
