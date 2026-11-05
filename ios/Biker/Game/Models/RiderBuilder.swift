import SceneKit
import UIKit
import simd

/// Names of accessory nodes that the rig animates after cloning.
enum RiderMotion {
    static let spin = "motion.spin"
    static let sway = "motion.sway"
    static let flapRight = "motion.flapRight"
    static let flapLeft = "motion.flapLeft"
}

/// Builds the seated rider from a `RiderPose`: jacket, pants, gloves, boots, helmet and visor.
@MainActor
enum RiderBuilder {
    struct Parts {
        /// Static body in rig space, ready to flatten.
        let body: SCNNode
        /// Moving accessory parts in rig space (propeller, cape, wings), or nil.
        let moving: SCNNode?
    }

    private static var gloveLeather: SCNMaterial { ModelMaterials.leather(RGB(r: 0.06, g: 0.06, b: 0.07)) }
    private static var bootLeather: SCNMaterial { ModelMaterials.leather(RGB(r: 0.09, g: 0.07, b: 0.06)) }

    static func build(style: RiderStyle, layout: BikeLayout) -> Parts {
        let pose = RiderPose(layout: layout)
        let body = SCNNode()
        let jacket = ModelMaterials.leather(style.jacket)
        let pants = ModelMaterials.fabric(style.pants)
        torso(body, pose, jacket: jacket, pants: pants, accent: style.visor)
        arms(body, pose, jacket: jacket)
        legs(body, pose, pants: pants)
        head(body, pose, style)
        let moving = RiderAccessories.add(style.accessory, style: style, pose: pose, to: body)
        return Parts(body: body, moving: moving)
    }

    private static func torso(_ node: SCNNode, _ pose: RiderPose, jacket: SCNMaterial, pants: SCNMaterial, accent: RGB) {
        let torsoStart = pose.hip + pose.torsoDirection * 0.06
        let torsoEnd = pose.neck - pose.torsoDirection * 0.05
        ModelKit.rod(torsoStart, torsoEnd, radius: 0.15, jacket, to: node, scale: RigVec(1.3, 1, 0.85))
        ModelKit.add(ModelKit.sphere(0.15), pants, to: node, at: pose.hip, scale: RigVec(1.25, 0.8, 1.1))
        let belt = ModelKit.add(ModelKit.torus(0.155, 0.022), ModelMaterials.blackPlastic, to: node,
                                at: pose.hip + pose.torsoDirection * 0.08, scale: RigVec(1.22, 1, 0.98))
        belt.simdOrientation = ModelKit.orientation(alongY: pose.torsoDirection)
        let stripe = ModelMaterials.plastic(accent)
        for side: Float in [-1, 1] {
            let offset = RigVec(side * 0.07, 0, 0) + pose.backDirection * 0.128
            ModelKit.rod(torsoStart + offset + pose.torsoDirection * 0.1, torsoEnd + offset, radius: 0.012, stripe, to: node)
        }
        for shoulder in pose.shoulders {
            ModelKit.add(ModelKit.sphere(0.085), jacket, to: node, at: shoulder)
        }
    }

    private static func arms(_ node: SCNNode, _ pose: RiderPose, jacket: SCNMaterial) {
        for index in 0..<2 {
            let shoulder = pose.shoulders[index]
            let elbow = pose.elbows[index]
            let hand = pose.hands[index]
            let forearmDirection = simd_normalize(hand - elbow)
            ModelKit.rod(shoulder, elbow, radius: 0.062, jacket, to: node)
            ModelKit.add(ModelKit.sphere(0.06), jacket, to: node, at: elbow)
            ModelKit.rod(elbow, hand - forearmDirection * 0.06, radius: 0.053, jacket, to: node)
            let glove = ModelKit.add(ModelKit.sphere(0.058), gloveLeather, to: node, at: hand,
                                     scale: RigVec(1.15, 0.85, 1.2))
            glove.simdOrientation = ModelKit.orientation(alongY: forearmDirection)
            ModelKit.rod(hand - forearmDirection * 0.075, hand - forearmDirection * 0.03, radius: 0.06,
                         gloveLeather, to: node, rounded: false)
        }
    }

    private static func legs(_ node: SCNNode, _ pose: RiderPose, pants: SCNMaterial) {
        for index in 0..<2 {
            let hipJoint = pose.hipJoints[index]
            let knee = pose.knees[index]
            let ankle = pose.ankles[index]
            let foot = pose.feet[index]
            ModelKit.rod(hipJoint, knee, radius: 0.085, pants, to: node)
            ModelKit.add(ModelKit.sphere(0.078), pants, to: node, at: knee)
            ModelKit.rod(knee, ankle, radius: 0.068, pants, to: node)
            ModelKit.rod(ankle - RigVec(0, 0.02, 0), ankle + RigVec(0, 0.12, 0), radius: 0.068, bootLeather,
                         to: node, rounded: false)
            ModelKit.add(ModelKit.box(0.11, 0.11, 0.28, chamfer: 0.04), bootLeather, to: node,
                         at: foot + RigVec(0, 0.045, -0.02))
            ModelKit.add(ModelKit.box(0.115, 0.02, 0.29, chamfer: 0.008), ModelMaterials.rubber, to: node,
                         at: foot + RigVec(0, -0.005, -0.02))
        }
    }

    private static func head(_ node: SCNNode, _ pose: RiderPose, _ style: RiderStyle) {
        let helmet = ModelMaterials.paint(style.helmet)
        let radius = RiderPose.helmetRadius
        ModelKit.rod(pose.neck, pose.head - RigVec(0, 0.1, 0), radius: 0.055, ModelMaterials.blackPlastic, to: node)
        ModelKit.add(ModelKit.sphere(radius), helmet, to: node, at: pose.head, scale: RigVec(1, 1.02, 1.12))
        ModelKit.add(ModelKit.sphere(0.13), ModelMaterials.visor(style.visor), to: node,
                     at: pose.head + RigVec(0, 0.01, -0.1), scale: RigVec(1.05, 0.52, 0.7))
        ModelKit.add(ModelKit.box(0.15, 0.07, 0.08, chamfer: 0.03), helmet, to: node,
                     at: pose.head + RigVec(0, -0.1, -0.12))
        ModelKit.add(ModelKit.torus(radius + 0.002, 0.014), ModelMaterials.plastic(style.visor), to: node,
                     at: pose.head, euler: RigVec(0, 0, .pi / 2), scale: RigVec(1.02, 1, 1.12))
    }
}
