import SceneKit
import UIKit

/// The camera: chase behind the bike, pulled back and wider under gas, a slow orbit for the garage.
/// HDR with bloom, vignette and a slight grade; FOV widens with speed; shakes on hits.
@MainActor
final class CameraRig {
    private static let baseFov = 66.0
    private static let speedFov = 9.0
    private static let boostFov = 9.0
    private static let showcaseFov = 42.0
    private static let orbitRadius = 4.3
    private static let orbitSpeed = 0.32

    let node = SCNNode()
    let cameraNode = SCNNode()
    let camera = SCNCamera()
    private let speedLines = WorldParticles.speedLines()
    private var mode = BikeCamera.chase
    private var focus = SCNVector3(0, 1, -10)
    private var fov = CameraRig.baseFov
    private var shakeAmount = 0.0
    private var kick = 0.0
    private var orbit = 0.0
    private var isHigh = true
    var budget: CGFloat = 1

    init(root: SCNNode) {
        camera.zNear = 0.15
        camera.zFar = 460
        camera.fieldOfView = CGFloat(Self.baseFov)
        cameraNode.camera = camera
        node.addChildNode(cameraNode)
        node.position = SCNVector3(0, 3, 6.4)
        root.addChildNode(node)
        let linesNode = SCNNode()
        linesNode.position = SCNVector3(0, 0, -16)
        linesNode.eulerAngles.x = .pi / 2
        linesNode.addParticleSystem(speedLines)
        cameraNode.addChildNode(linesNode)
        configure(high: true)
    }

    func configure(high: Bool) {
        isHigh = high
        camera.wantsHDR = high
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = 0.25
        camera.bloomIntensity = high ? 1.1 : 0
        camera.bloomThreshold = 0.72
        camera.bloomBlurRadius = 9
        camera.vignettingIntensity = 0.55
        camera.vignettingPower = 0.85
        camera.saturation = 1.18
        camera.contrast = 0.12
        camera.motionBlurIntensity = 0
        camera.colorFringeIntensity = 0
        camera.colorFringeStrength = 0.8
    }

    func setMode(_ mode: BikeCamera) {
        if mode == .showcase, self.mode != .showcase { orbit = 0 }
        self.mode = mode
    }

    func shake(_ amount: Double) {
        shakeAmount = max(shakeAmount, amount)
    }

    /// A quick FOV punch: positive widens (boost, near miss), negative narrows (hit).
    func punch(_ degrees: Double) {
        kick += degrees
    }

    /// `lookAhead` is how far the road bends sideways a little ahead, to aim into the curve.
    func update(bikeX: Double, rev: Double, boosting: Bool, lookAhead: Double, dt: Double, clock: Double) {
        let effective: BikeCamera = mode == .chase && boosting ? .boost : mode
        let target = placement(effective, bikeX: bikeX, lookAhead: lookAhead, dt: dt)
        let follow = dt > 0 ? 1 - exp(-dt * (effective == .showcase ? 3 : 6)) : 0
        node.position = mix(node.position, target.eye, follow)
        focus = mix(focus, target.focus, follow)
        node.look(at: focus, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        updateFov(effective, rev: rev, dt: dt)
        updateShake(dt: dt, clock: clock, rev: rev)
        let rushing = effective == .boost && dt > 0
        speedLines.birthRate = rushing ? 90 * budget : 0
        camera.motionBlurIntensity = isHigh && rushing ? 0.3 : 0
        camera.colorFringeIntensity = isHigh && rushing ? 0.6 : 0
    }

    private func placement(_ mode: BikeCamera, bikeX: Double, lookAhead: Double, dt: Double) -> (eye: SCNVector3, focus: SCNVector3) {
        switch mode {
        case .chase:
            return (Shapes.v(bikeX * 0.7, 3.0, 6.4), Shapes.v(bikeX * 0.45 + lookAhead, 1.1, -10))
        case .boost:
            return (Shapes.v(bikeX * 0.75, 2.5, 7.9), Shapes.v(bikeX * 0.5 + lookAhead, 1.0, -12))
        case .showcase:
            orbit += dt * Self.orbitSpeed
            let angle = orbit + 0.6
            let eye = Shapes.v(Self.orbitRadius * sin(angle), 1.5 + 0.35 * sin(orbit * 0.7), Self.orbitRadius * cos(angle) - 0.2)
            return (eye, Shapes.v(0, 0.85, -0.2))
        }
    }

    private func updateFov(_ mode: BikeCamera, rev: Double, dt: Double) {
        let wanted: Double
        switch mode {
        case .showcase: wanted = Self.showcaseFov
        case .chase: wanted = Self.baseFov + Self.speedFov * min(1, max(0, rev))
        case .boost: wanted = Self.baseFov + Self.speedFov + Self.boostFov
        }
        let follow = dt > 0 ? 1 - exp(-dt * 3) : 0
        fov += (wanted - fov) * follow
        kick *= dt > 0 ? exp(-dt * 5) : 1
        camera.fieldOfView = CGFloat(fov + kick)
    }

    private func updateShake(dt: Double, clock: Double, rev: Double) {
        let rumble = mode == .showcase ? 0 : 0.012 * min(1.5, max(0, rev))
        let amount = shakeAmount + rumble
        cameraNode.position = SCNVector3(
            Float(amount * sin(clock * 47) * 0.6),
            Float(amount * sin(clock * 59 + 1.3) * 0.5),
            0
        )
        cameraNode.eulerAngles.z = Float(amount * 0.08 * sin(clock * 37))
        shakeAmount *= dt > 0 ? exp(-dt * 6) : 1
    }

    private func mix(_ a: SCNVector3, _ b: SCNVector3, _ t: Double) -> SCNVector3 {
        let k = Float(t)
        return SCNVector3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k)
    }
}
