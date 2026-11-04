import UIKit

/// Draws the swarm with one small layer per fly, plus a soft shadow that drifts away in flight.
@MainActor
final class FlyLayerGroup {
    let container = CALayer()

    private var swarm: FlySwarm?
    private var bodies: [CALayer] = []
    private var shadows: [CALayer] = []
    private let flyImage = FlyLayerGroup.renderFly(wingSpread: 0.45)
    private let flutterImage = FlyLayerGroup.renderFly(wingSpread: 0.95)
    private let motionAllowed = !UIAccessibility.isReduceMotionEnabled

    func configure(in host: CALayer, width: Double, height: Double) {
        bodies.forEach { $0.removeFromSuperlayer() }
        shadows.forEach { $0.removeFromSuperlayer() }
        container.frame = host.bounds
        container.isHidden = !motionAllowed
        let created = FlySwarm(count: 4, width: width, height: height)
        swarm = created
        shadows = created.flies.map { _ in Self.makeShadow() }
        bodies = created.flies.map { _ in Self.makeBody() }
        shadows.forEach { container.addSublayer($0) }
        bodies.forEach { container.addSublayer($0) }
    }

    func scare(x: Double, y: Double) {
        swarm?.scare(x: x, y: y)
    }

    func advance(dt: Double, time: Double) {
        guard motionAllowed, var moved = swarm else { return }
        moved.update(dt: dt)
        swarm = moved
        let fastWings = Int(time * 40) % 2 == 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, fly) in moved.flies.enumerated() {
            let flying = fly.airborne > 0
            let lift: CGFloat = flying ? 9 : 1.5
            bodies[index].position = CGPoint(x: fly.x, y: fly.y)
            bodies[index].setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(fly.heading)))
            bodies[index].contents = flying && fastWings ? flutterImage : flyImage
            shadows[index].position = CGPoint(x: CGFloat(fly.x) + lift, y: CGFloat(fly.y) + lift)
        }
        CATransaction.commit()
    }

    private static func makeBody() -> CALayer {
        let body = CALayer()
        body.bounds = CGRect(x: 0, y: 0, width: 22, height: 18)
        body.actions = ["contents": NSNull(), "position": NSNull(), "transform": NSNull()]
        return body
    }

    private static func makeShadow() -> CALayer {
        let shadow = CALayer()
        shadow.bounds = CGRect(x: 0, y: 0, width: 9, height: 6)
        shadow.cornerRadius = 3
        shadow.backgroundColor = UIColor(red: 0.06, green: 0.03, blue: 0.01, alpha: 0.4).cgColor
        shadow.actions = ["position": NSNull()]
        return shadow
    }

    /// Facing right, so rotating the layer by the fly's heading points it the right way.
    private static func renderFly(wingSpread: CGFloat) -> CGImage? {
        let size = CGSize(width: 22, height: 18)
        let image = UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            context.translateBy(x: 11, y: 9)
            context.setFillColor(UIColor(red: 0.85, green: 0.89, blue: 0.91, alpha: 0.5).cgColor)
            for side: CGFloat in [-1, 1] {
                context.saveGState()
                context.translateBy(x: -3.5, y: side * 3.2)
                context.rotate(by: side * wingSpread)
                context.fillEllipse(in: CGRect(x: -5, y: -2.3, width: 10, height: 4.6))
                context.restoreGState()
            }
            context.setFillColor(UIColor(red: 0.09, green: 0.07, blue: 0.06, alpha: 1).cgColor)
            context.fillEllipse(in: CGRect(x: -4.6, y: -2.7, width: 9.2, height: 5.4))
            context.setFillColor(UIColor(red: 0.43, green: 0.12, blue: 0.09, alpha: 1).cgColor)
            context.fillEllipse(in: CGRect(x: 1.9, y: -1.9, width: 3.8, height: 3.8))
        }
        return image.cgImage
    }
}
