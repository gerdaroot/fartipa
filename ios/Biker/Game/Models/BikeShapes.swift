import SceneKit
import UIKit

/// Curved body panels built from side profiles: tanks, seats, fenders and free-form panels.
/// All coordinates are absolute rig coordinates in the side view: `forward` is -z, `up` is y.
@MainActor
enum BikeShapes {
    private static func key(_ name: String, _ values: [Float]) -> String {
        name + values.map { String(format: "%.3f", $0) }.joined(separator: "_")
    }

    /// Teardrop fuel tank between `front` and `back` (forward coordinates, front > back).
    @discardableResult
    static func tank(
        _ node: SCNNode, front: Float, back: Float, base: Float, height: Float, width: Float,
        _ material: SCNMaterial
    ) -> SCNNode {
        let shapeKey = key("tank", [front, back, base, height])
        return ModelKit.profile(shapeKey, width: width, chamfer: width * 0.4, material, to: node) {
            let f = CGFloat(front), b = CGFloat(back), y = CGFloat(base), h = CGFloat(height)
            let length = f - b
            return RigPathStep.path(f, y + h * 0.15, [
                .quad(f - 0.12, y + h, controlX: f - 0.01, controlY: y + h * 0.95),
                .quad(b + 0.06, y + h * 0.72, controlX: b + length * 0.35, controlY: y + h * 1.08),
                .quad(b, y + h * 0.2, controlX: b - 0.025, controlY: y + h * 0.5),
                .line(f - 0.08, y),
            ])
        }
    }

    /// Padded seat with a raised back edge.
    @discardableResult
    static func seat(
        _ node: SCNNode, front: Float, back: Float, base: Float, height: Float, width: Float,
        _ material: SCNMaterial, rearRise: Float = 0.3
    ) -> SCNNode {
        let shapeKey = key("seat", [front, back, base, height, rearRise])
        return ModelKit.profile(shapeKey, width: width, chamfer: width * 0.3, material, to: node) {
            let f = CGFloat(front), b = CGFloat(back), y = CGFloat(base), h = CGFloat(height)
            let rise = h * (1 + CGFloat(rearRise))
            return RigPathStep.path(f, y, [
                .quad(f - 0.08, y + h, controlX: f + 0.01, controlY: y + h),
                .quad(b + 0.1, y + h * 0.92, controlX: (f + b) * 0.5, controlY: y + h * 0.82),
                .quad(b, y + rise, controlX: b + 0.05, controlY: y + h),
                .line(b - 0.02, y + h * 0.5),
                .line(b + 0.04, y),
            ])
        }
    }

    /// Mudguard arc around a wheel. Angles in degrees: 0 points forward, 90 straight up.
    @discardableResult
    static func fender(
        _ node: SCNNode, axle: RigVec, radius: Float, from startDegrees: Float, to endDegrees: Float,
        width: Float, _ material: SCNMaterial, thickness: Float = 0.025, x: Float = 0
    ) -> SCNNode {
        let shapeKey = key("fender", [axle.y, axle.z, radius, startDegrees, endDegrees, thickness])
        return ModelKit.profile(shapeKey, width: width, chamfer: min(width * 0.2, thickness * 0.45), material,
                                 to: node, x: x) {
            let center = CGPoint(x: CGFloat(-axle.z), y: CGFloat(axle.y))
            let start = CGFloat(startDegrees) * .pi / 180
            let end = CGFloat(endDegrees) * .pi / 180
            let path = UIBezierPath(arcCenter: center, radius: CGFloat(radius + thickness),
                                    startAngle: start, endAngle: end, clockwise: true)
            path.addArc(withCenter: center, radius: CGFloat(radius), startAngle: end, endAngle: start, clockwise: false)
            path.close()
            return path
        }
    }

    /// Free-form panel through straight-edged `points` (forward, up), rounded by the chamfer.
    @discardableResult
    static func panel(
        _ node: SCNNode, _ name: String, points: [(Float, Float)], width: Float, chamfer: Float,
        _ material: SCNMaterial, x: Float = 0
    ) -> SCNNode {
        let flat: [Float] = points.flatMap { [$0.0, $0.1] }
        let shapeKey = key("panel-\(name)", flat)
        return ModelKit.profile(shapeKey, width: width, chamfer: chamfer, material, to: node, x: x) {
            let path = UIBezierPath()
            guard let first = points.first else { return path }
            path.move(to: CGPoint(x: CGFloat(first.0), y: CGFloat(first.1)))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: CGFloat(point.0), y: CGFloat(point.1)))
            }
            path.close()
            return path
        }
    }

    /// Smooth panel: a closed path built from steps, for fairings and bodywork.
    @discardableResult
    static func curved(
        _ node: SCNNode, _ name: String, width: Float, chamfer: Float, _ material: SCNMaterial,
        x: Float = 0, start: (CGFloat, CGFloat), steps: [RigPathStep]
    ) -> SCNNode {
        ModelKit.profile("curved-\(name)", width: width, chamfer: chamfer, material, to: node, x: x) {
            RigPathStep.path(start.0, start.1, steps)
        }
    }
}
