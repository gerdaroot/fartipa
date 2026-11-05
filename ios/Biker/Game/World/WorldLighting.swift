import SceneKit
import UIKit

/// Moonlight (the one shadow-casting light, following the bike), a dim ambient fill
/// and the bike's headlight. Everything else that glows is emissive.
@MainActor
final class WorldLighting {
    private static let moonIntensity: CGFloat = 520
    private static let ambientIntensity: CGFloat = 180
    private static let headlightIntensity: CGFloat = 2600
    private static let shadowArea = 9.0
    private static let moonOffset = SCNVector3(-6, 22, 6)

    let moonNode = SCNNode()
    let headlightNode = SCNNode()
    private let moon = SCNLight()
    private let ambient = SCNLight()
    private let headlight = SCNLight()

    init(root: SCNNode) {
        moon.type = .directional
        moon.intensity = Self.moonIntensity
        moon.castsShadow = true
        moon.shadowMode = .forward
        moon.automaticallyAdjustsShadowProjection = false
        moon.orthographicScale = Self.shadowArea
        moon.shadowMapSize = CGSize(width: 1024, height: 1024)
        moon.shadowSampleCount = 4
        moon.shadowRadius = 2.5
        moon.shadowColor = UIColor(white: 0, alpha: 0.65)
        moon.shadowBias = 0.05
        moon.zNear = 1
        moon.zFar = 60
        moonNode.light = moon
        moonNode.position = Self.moonOffset
        moonNode.look(at: SCNVector3(0, 0, -3))
        root.addChildNode(moonNode)

        ambient.type = .ambient
        ambient.intensity = Self.ambientIntensity
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        headlight.type = .spot
        headlight.intensity = Self.headlightIntensity
        headlight.color = UIColor(red: 1, green: 0.93, blue: 0.78, alpha: 1)
        headlight.spotInnerAngle = 18
        headlight.spotOuterAngle = 48
        headlight.attenuationStartDistance = 2
        headlight.attenuationEndDistance = 38
        headlight.castsShadow = false
        headlightNode.light = headlight
        headlightNode.position = SCNVector3(0, 1.05, -0.7)
        headlightNode.eulerAngles = SCNVector3(-0.22, 0, 0)
    }

    func apply(_ palette: WorldPalette) {
        moon.color = palette.moon.mixed(with: ColorValue(1, 1, 1), 0.3).ui
        ambient.color = palette.ambient.ui
    }

    func setShadows(_ enabled: Bool) {
        moon.castsShadow = enabled
    }

    /// Keeps the shadow map centred on the bike.
    func follow(bikeX: Double) {
        let offset = Self.moonOffset
        moonNode.position = SCNVector3(Float(bikeX) + offset.x, offset.y, offset.z)
    }
}
