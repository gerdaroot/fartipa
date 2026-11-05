import SceneKit
import UIKit
import simd

/// Meshes of the stream, built once at load and shared by every pooled stream.
@MainActor
enum PissGeometry {
    static let radialCount = 10
    private static let crownSegments = 20
    private static let crownHeight = 0.6
    private static let crownRadii: [Double] = [0.2, 0.36, 0.8]
    private static let crownLevels: [Double] = [0, 0.45, 1]

    /// A tapered tube along the arc over rings `first...last`. Rings above `PissArc.breakRing` use
    /// `liquid`, the rest `beads`, so a tube can have one or two parts.
    static func tube(first: Int, last: Int, liquid: SCNMaterial, beads: SCNMaterial) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var coords: [CGPoint] = []
        for ring in first...last { appendRing(ring, &vertices, &normals, &coords) }
        var upper: [UInt16] = []
        var lower: [UInt16] = []
        for ring in first..<last {
            if ring < PissArc.breakRing {
                appendQuads(ring - first, stride: radialCount + 1, count: radialCount, into: &upper)
            } else {
                appendQuads(ring - first, stride: radialCount + 1, count: radialCount, into: &lower)
            }
        }
        var elements: [SCNGeometryElement] = []
        var materials: [SCNMaterial] = []
        if !upper.isEmpty {
            elements.append(SCNGeometryElement(indices: upper, primitiveType: .triangles))
            materials.append(liquid)
        }
        if !lower.isEmpty {
            elements.append(SCNGeometryElement(indices: lower, primitiveType: .triangles))
            materials.append(beads)
        }
        let sources: [SCNGeometrySource] = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals),
            SCNGeometrySource(textureCoordinates: coords),
        ]
        let geometry = SCNGeometry(sources: sources, elements: elements)
        geometry.materials = materials
        return geometry
    }

    private static func appendRing(
        _ ring: Int, _ vertices: inout [SCNVector3], _ normals: inout [SCNVector3], _ coords: inout [CGPoint]
    ) {
        let table = PissArc.rings
        let u = table.u[ring]
        let center = PissArc.point(u)
        let across = SIMD3<Double>(0, 0, 1)
        let inPlane = simd_cross(PissArc.tangent(u), across)
        let radius = PissArc.radius(u)
        let v = table.length[ring] / PissArc.textureLength
        for step in 0...radialCount {
            let angle = Double(step) / Double(radialCount) * 2 * Double.pi
            let radial = across * cos(angle) + inPlane * sin(angle)
            vertices.append(PissArc.vector(center + radial * radius))
            normals.append(PissArc.vector(radial))
            coords.append(CGPoint(x: Double(step) / Double(radialCount), y: v))
        }
    }

    /// Two triangles per quad between ring `ring` and the next, facing outwards.
    private static func appendQuads(_ ring: Int, stride: Int, count: Int, into indices: inout [UInt16]) {
        for step in 0..<count {
            let a = UInt16(ring * stride + step)
            let b = UInt16(ring * stride + step + 1)
            let c = UInt16((ring + 1) * stride + step)
            let d = UInt16((ring + 1) * stride + step + 1)
            let quad: [UInt16] = [a, b, c, b, d, c]
            indices.append(contentsOf: quad)
        }
    }

    /// An open flaring cup of liquid thrown up where the stream hits the road. Drawn double sided.
    static func crown(material: SCNMaterial) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var coords: [CGPoint] = []
        for (index, level) in crownLevels.enumerated() {
            let radius = crownRadii[index]
            for step in 0...crownSegments {
                let angle = Double(step) / Double(crownSegments) * 2 * Double.pi
                let x = cos(angle)
                let z = sin(angle)
                vertices.append(SCNVector3(Float(x * radius), Float(level * crownHeight), Float(z * radius)))
                normals.append(SCNVector3(Float(x * 0.8), 0.6, Float(z * 0.8)))
                coords.append(CGPoint(x: Double(step) / Double(crownSegments) * 3, y: 1 - level))
            }
        }
        var indices: [UInt16] = []
        for ring in 0..<(crownLevels.count - 1) {
            appendQuads(ring, stride: crownSegments + 1, count: crownSegments, into: &indices)
        }
        let sources: [SCNGeometrySource] = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals),
            SCNGeometrySource(textureCoordinates: coords),
        ]
        let geometry = SCNGeometry(sources: sources, elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        geometry.materials = [material]
        return geometry
    }
}
