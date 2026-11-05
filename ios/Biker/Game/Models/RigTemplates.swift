import SceneKit
import UIKit
import simd

/// Caches flattened templates of chassis, wheels and riders. `makeRig` clones them, so
/// building the same bike twice costs a few node copies and shares all geometry.
@MainActor
enum RigTemplates {
    private static var chassisCache: [String: SCNNode] = [:]
    private static var wheelCache: [String: SCNNode] = [:]
    private static var riderCache: [String: SCNNode] = [:]
    private static let cacheLimit = 96
    /// Rear wheels of the tractor are a pair, this far from the centre line.
    static let tractorTwinOffset: Float = 0.32

    /// Drops one entry when a cache is full instead of throwing away every built template.
    private static func evict(_ cache: inout [String: SCNNode]) {
        guard cache.count >= cacheLimit, let victim = cache.keys.first else { return }
        cache.removeValue(forKey: victim)
    }

    /// Every cached template, so loading can upload their geometry and compile their materials.
    static var allTemplates: [SCNNode] {
        Array(chassisCache.values) + Array(wheelCache.values) + Array(riderCache.values)
    }

    private static func colorKey(_ colors: [RGB]) -> String {
        colors.map { ModelMaterials.key($0) }.joined(separator: "|")
    }

    // MARK: - Chassis

    static func chassis(_ style: BikeStyle, _ layout: BikeLayout) -> SCNNode {
        let key = style.body.rawValue + "|" + colorKey([style.primary, style.secondary, style.glow])
        if let hit = chassisCache[key] { return hit.clone() }
        let palette = BikePalette(style)
        let content = body(style.body, palette, layout)
        let flat = ModelKit.flatten(content, name: "chassis")
        evict(&chassisCache)
        chassisCache[key] = flat
        return flat.clone()
    }

    private static func body(_ body: BikeBody, _ palette: BikePalette, _ layout: BikeLayout) -> SCNNode {
        switch body {
        case .naked: return BikeBodiesStreet.naked(palette, layout)
        case .sport: return BikeBodiesStreet.sport(palette, layout)
        case .chopper: return BikeBodiesStreet.chopper(palette, layout)
        case .cruiser: return BikeBodiesStreet.cruiser(palette, layout)
        case .dirt: return BikeBodiesOdd.dirt(palette, layout)
        case .scooter: return BikeBodiesOdd.scooter(palette, layout)
        case .tractor: return BikeBodiesOdd.tractor(palette, layout)
        case .rocket: return BikeBodiesOdd.rocket(palette, layout)
        case .toilet: return BikeBodiesPotty.toilet(palette, layout)
        case .turd: return BikeBodiesPotty.turd(palette, layout)
        }
    }

    // MARK: - Wheels

    /// A spinning holder at the axle with the wheel geometry inside.
    static func wheel(_ style: BikeStyle, _ layout: BikeLayout, front: Bool) -> SCNNode {
        let radius = front ? layout.frontRadius : layout.rearRadius
        let width = front ? layout.frontWidth : layout.rearWidth
        let twin = !front && style.body == .tractor
        let knobby = style.body == .dirt
        let key = [style.wheels.rawValue, String(format: "%.3f_%.3f", Double(radius), Double(width)),
                   "\(twin)", "\(knobby)", colorKey([style.secondary, style.glow])].joined(separator: "|")
        let template: SCNNode
        if let hit = wheelCache[key] {
            template = hit
        } else {
            let palette = BikePalette(style)
            let content = SCNNode()
            let offsets: [Float] = twin ? [tractorTwinOffset, -tractorTwinOffset] : [0]
            for offset in offsets {
                let single = BikeWheels.build(style: style.wheels, radius: radius, width: width, knobby: knobby, palette: palette)
                single.simdPosition = RigVec(offset, 0, 0)
                content.addChildNode(single)
            }
            template = ModelKit.flatten(content, name: "wheelGeometry")
            evict(&wheelCache)
            wheelCache[key] = template
        }
        let holder = SCNNode()
        holder.name = front ? "frontWheel" : "rearWheel"
        holder.simdPosition = front ? layout.frontAxle : layout.rearAxle
        holder.addChildNode(template.clone())
        return holder
    }

    // MARK: - Rider

    /// Rider root placed at the pelvis, so rotating it leans the rider around the seat.
    static func rider(_ style: RiderStyle, _ layout: BikeLayout, body: BikeBody) -> SCNNode {
        let key = body.rawValue + "|" + style.accessory.rawValue + "|"
            + colorKey([style.jacket, style.pants, style.helmet, style.visor])
        if let hit = riderCache[key] { return hit.clone() }
        let parts = RiderBuilder.build(style: style, layout: layout)
        let root = SCNNode()
        root.name = "rider"
        root.simdPosition = layout.hip
        let flat = ModelKit.flatten(parts.body, name: "riderBody")
        flat.simdPosition = -layout.hip
        root.addChildNode(flat)
        if let moving = parts.moving {
            let holder = SCNNode()
            holder.name = "riderMoving"
            holder.simdPosition = -layout.hip
            holder.addChildNode(moving)
            root.addChildNode(holder)
        }
        evict(&riderCache)
        riderCache[key] = root
        return root.clone()
    }

    /// Starts accessory animations on a cloned rider (clones do not inherit actions).
    static func animate(_ rider: SCNNode) {
        if let rotor = rider.childNode(withName: RiderMotion.spin, recursively: true) {
            rotor.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 0.45)))
        }
        if let cape = rider.childNode(withName: RiderMotion.sway, recursively: true) {
            cape.runAction(swing(x: 0.16, z: 0, duration: 0.32))
        }
        if let wing = rider.childNode(withName: RiderMotion.flapRight, recursively: true) {
            wing.runAction(swing(x: 0, z: 0.3, duration: 0.5))
        }
        if let wing = rider.childNode(withName: RiderMotion.flapLeft, recursively: true) {
            wing.runAction(swing(x: 0, z: -0.3, duration: 0.5))
        }
    }

    private static func swing(x: CGFloat, z: CGFloat, duration: TimeInterval) -> SCNAction {
        let out = SCNAction.rotateBy(x: x, y: 0, z: z, duration: duration)
        out.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([out, out.reversed()]))
    }
}
