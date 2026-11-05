import SceneKit
import UIKit
import simd

/// One built bike and rider. Origin on the road under the bike centre, facing -z, y up.
struct BikeRig {
    let root: SCNNode
    /// Spin around its own x axis; origin is on the axle.
    let frontWheel: SCNNode
    let rearWheel: SCNNode
    /// Empty node at the muffler tip. Its local +z points out of the pipe
    /// (backwards on most bikes, straight up on the tractor's smoke stack).
    let exhaust: SCNNode
    /// Rider root, placed at the pelvis so rotations lean the rider around the seat.
    let rider: SCNNode
    /// Empty node at the front of the main headlight, facing -z (for an optional spot light).
    let headlight: SCNNode
    /// Wheel radii in metres, for converting road speed to spin (angle = distance / radius).
    let frontWheelRadius: Float
    let rearWheelRadius: Float
}

/// Builds every bike and outfit in the shop out of cached procedural parts.
enum BikeModels {
    @MainActor
    static func makeRig(bike: BikeStyle, rider: RiderStyle) -> BikeRig {
        let layout = BikeLayout.of(bike.body)
        let root = SCNNode()
        root.name = "bikeRig"
        root.addChildNode(RigTemplates.chassis(bike, layout))
        let front = RigTemplates.wheel(bike, layout, front: true)
        let rear = RigTemplates.wheel(bike, layout, front: false)
        root.addChildNode(front)
        root.addChildNode(rear)
        let riderNode = RigTemplates.rider(rider, layout, body: bike.body)
        RigTemplates.animate(riderNode)
        root.addChildNode(riderNode)

        let exhaust = SCNNode()
        exhaust.name = "exhaust"
        exhaust.simdPosition = layout.exhaust
        let pipeDirection = bike.body == .tractor ? RigVec(0, 1, 0) : RigVec(0, 0, 1)
        exhaust.simdOrientation = simd_quatf(from: RigVec(0, 0, 1), to: pipeDirection)
        root.addChildNode(exhaust)

        let headlight = SCNNode()
        headlight.name = "headlight"
        headlight.simdPosition = layout.headlight
        root.addChildNode(headlight)

        return BikeRig(
            root: root, frontWheel: front, rearWheel: rear, exhaust: exhaust, rider: riderNode,
            headlight: headlight, frontWheelRadius: layout.frontRadius, rearWheelRadius: layout.rearRadius
        )
    }

    /// Builds and caches the templates of this bike and rider without returning a rig, so a later
    /// `makeRig` (garage preview, ride start) is only a few node clones. Call while loading.
    @MainActor
    static func prewarm(bike: BikeStyle, rider: RiderStyle) {
        _ = makeRig(bike: bike, rider: rider)
    }

    /// Looks the skins up in the catalog; unknown ids fall back to the starter bike and rider.
    @MainActor
    static func makeRig(bikeId: String, riderId: String) -> BikeRig {
        let bike = Catalog.bike(id: bikeId)?.style ?? Catalog.bike(id: Catalog.starterBikeId)?.style ?? fallbackBike
        let rider = Catalog.rider(id: riderId)?.style ?? Catalog.rider(id: Catalog.starterRiderId)?.style ?? fallbackRider
        return makeRig(bike: bike, rider: rider)
    }

    private static let fallbackBike = BikeStyle(
        body: .naked, primary: RGB(hex: 0x8A5A2B), secondary: RGB(hex: 0x4A3A2A), glow: RGB(hex: 0xFFB347),
        wheels: .standard
    )

    private static let fallbackRider = RiderStyle(
        jacket: RGB(hex: 0x2A2420), pants: RGB(hex: 0x25303F), helmet: RGB(hex: 0x30302E), visor: RGB(hex: 0x88B0C8),
        accessory: .none
    )

    // MARK: - Simple helpers kept for world decor

    /// A plain Blinn material (cheap, for world props).
    static func material(_ color: UIColor, shine: CGFloat = 0.4, glow: UIColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = color
        material.specular.contents = UIColor(white: shine, alpha: 1)
        material.shininess = 0.5
        if let glow {
            material.emission.contents = glow
        }
        return material
    }

    /// A geometry node with a plain material, positioned and pitched/rolled.
    static func part(
        _ geometry: SCNGeometry, _ color: UIColor, x: Double = 0, y: Double, z: Double,
        pitch: Double = 0, roll: Double = 0, shine: CGFloat = 0.4, glow: UIColor? = nil
    ) -> SCNNode {
        geometry.firstMaterial = material(color, shine: shine, glow: glow)
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(Float(x), Float(y), Float(z))
        node.eulerAngles = SCNVector3(Float(pitch), 0, Float(roll))
        return node
    }
}
