import SceneKit

/// Turns ride events into particles, camera shake and FOV punches. The yellow screen tint on a hit
/// and the pop-up texts belong to the UI.
@MainActor
enum WorldReactions {
    static func apply(_ event: BikeEvent, at bike: SCNVector3, exhaust: SCNVector3, bursts: BurstPool, camera: CameraRig) {
        let above = SCNVector3(bike.x, bike.y + 0.3, bike.z - 0.4)
        let ground = SCNVector3(bike.x, 0.2, bike.z)
        switch event {
        case .coin:
            bursts.fire(.coin, at: above)
        case .goldenCoin:
            bursts.fire(.goldenCoin, at: above)
            camera.shake(0.06)
            camera.punch(2)
        case .hit:
            bursts.fire(.hitSplash, at: above)
            camera.shake(0.45)
            camera.punch(-5)
        case .skid:
            bursts.fire(.skid, at: SCNVector3(bike.x, 0.3, bike.z + 0.7))
            camera.shake(0.15)
        case .nearMiss:
            bursts.fire(.nearMiss(side: -1), at: SCNVector3(bike.x - 1.2, 1, bike.z - 1))
            bursts.fire(.nearMiss(side: 1), at: SCNVector3(bike.x + 1.2, 1, bike.z - 1))
            camera.punch(3)
        case .pickup(let kind):
            bursts.fire(.pickup(PickupIcons.color(kind)), at: above)
            camera.shake(0.05)
        case .boostStart:
            bursts.fire(.boostFlash, at: exhaust)
            camera.shake(0.2)
            camera.punch(7)
        case .boostEnd:
            camera.punch(-2)
        case .shieldBlocked:
            bursts.fire(.shieldBreak, at: above)
            camera.shake(0.3)
        case .vehicleSmashed:
            bursts.fire(.debris, at: SCNVector3(bike.x, 1.2, bike.z - 1.5))
            camera.shake(0.4)
            camera.punch(4)
        case .districtEntered:
            camera.punch(4)
        case .gameOver:
            bursts.fire(.bigSplash, at: ground)
            camera.shake(0.7)
        }
    }
}
