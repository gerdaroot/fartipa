import SceneKit
import UIKit

/// Materials and meshes shared by every stream, made once at load.
@MainActor
final class StreamKit {
    static let warningSteps = 8
    private static let liquidFlowRate = 1.6
    private static let beadFlowRate = 3.1
    private static let cloudWidth = 15.0
    private static let cloudHeight = 11.25
    private static let headRadius = 0.32

    let warning: [SCNMaterial]
    let shadow: SCNMaterial
    let puddle: SCNMaterial
    let ripple: SCNMaterial
    let liquid: SCNMaterial
    let beads: SCNMaterial
    let crown: SCNMaterial
    let cloud: SCNMaterial

    /// The whole stream while it pours: one mesh, two parts.
    let fullTube: SCNGeometry
    /// The same stream cut into pieces, shown one by one while it arrives or drains.
    let pieces: [SCNGeometry]
    /// `u` where each piece starts and ends.
    let pieceStart: [Double]
    let pieceEnd: [Double]
    let head: SCNGeometry
    let crownMesh: SCNGeometry
    let cloudPlane: SCNGeometry

    init(library: MaterialLibrary) {
        warning = StreamKit.warningMaterials(library)
        shadow = library.shared("streamShadow", bend: false) { WorldMaterials.decal(SpriteTextures.shadowDisc, additive: false) }
        puddle = library.shared("puddle", bend: false) { WorldMaterials.decal(SpriteTextures.puddle, additive: false, lit: true) }
        ripple = library.shared("pissRipple", bend: false) {
            let material = WorldMaterials.decal(SpriteTextures.bubble, additive: false)
            material.multiply.contents = UIColor(red: 1, green: 0.95, blue: 0.62, alpha: 1)
            return material
        }
        let liquidMaterial = library.shared("pissLiquid", bend: false) { StreamKit.makeLiquid(PissTextures.liquid) }
        let beadMaterial = library.shared("pissBeads", bend: false) { StreamKit.makeLiquid(PissTextures.beads) }
        liquid = liquidMaterial
        beads = beadMaterial
        let crownMaterial = library.shared("pissCrown", bend: false) {
            let material = WorldMaterials.decal(PissTextures.crown, additive: false)
            material.isDoubleSided = true
            material.emission.contents = UIColor(red: 0.5, green: 0.42, blue: 0.1, alpha: 1)
            return material
        }
        crown = crownMaterial
        let cloudMaterial = library.shared("pissCloud", bend: false) { WorldMaterials.decal(PissTextures.cloudButt, additive: false) }
        cloud = cloudMaterial
        let (meshes, starts, ends) = StreamKit.makePieces(liquid: liquidMaterial, beads: beadMaterial)
        pieces = meshes
        pieceStart = starts
        pieceEnd = ends
        fullTube = PissGeometry.tube(first: 0, last: PissArc.ringCount, liquid: liquidMaterial, beads: beadMaterial)
        let sphere = SCNSphere(radius: CGFloat(StreamKit.headRadius))
        sphere.segmentCount = 10
        sphere.firstMaterial = liquidMaterial
        head = sphere
        crownMesh = PissGeometry.crown(material: crownMaterial)
        let plane = SCNPlane(width: CGFloat(StreamKit.cloudWidth), height: CGFloat(StreamKit.cloudHeight))
        plane.firstMaterial = cloudMaterial
        cloudPlane = plane
        PissWarmup.register(warmupObjects())
    }

    /// Height above the source of the cloud's centre, so the butt's glowing crack sits on the source.
    var cloudLift: Double { Self.cloudHeight * 0.32 }

    /// Runs the streaks and beads down every stream. Called once per frame.
    func flow(clock: Double) {
        let liquidShift = Float(-(clock * Self.liquidFlowRate).truncatingRemainder(dividingBy: 1))
        let beadShift = Float(-(clock * Self.beadFlowRate).truncatingRemainder(dividingBy: 1))
        let liquidMove = SCNMatrix4MakeTranslation(0, liquidShift, 0)
        let beadMove = SCNMatrix4MakeTranslation(0, beadShift, 0)
        liquid.diffuse.contentsTransform = liquidMove
        liquid.emission.contentsTransform = liquidMove
        beads.diffuse.contentsTransform = beadMove
        beads.emission.contentsTransform = beadMove
    }

    /// Translucent yellow, lit with a sharp highlight, glowing a little so it reads at night.
    private static func makeLiquid(_ image: UIImage) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = image
        material.emission.contents = image
        material.emission.intensity = 0.45
        material.specular.contents = UIColor.white
        material.shininess = 60
        material.blendMode = .alpha
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        for property in [material.diffuse, material.emission] {
            property.wrapS = .repeat
            property.wrapT = .repeat
            property.mipFilter = .linear
        }
        PissShader.attach(to: material)
        return material
    }

    private static func warningMaterials(_ library: MaterialLibrary) -> [SCNMaterial] {
        var steps: [SCNMaterial] = []
        let yellow = ColorValue(1, 0.9, 0.15)
        let red = ColorValue(1, 0.08, 0.05)
        for index in 0..<warningSteps {
            let color = yellow.mixed(with: red, Double(index) / Double(warningSteps - 1))
            steps.append(library.shared("warning-\(index)", bend: false) {
                let material = WorldMaterials.decal(SpriteTextures.warningRing, additive: true)
                material.multiply.contents = color.ui
                return material
            })
        }
        return steps
    }

    private static func makePieces(liquid: SCNMaterial, beads: SCNMaterial) -> ([SCNGeometry], [Double], [Double]) {
        var meshes: [SCNGeometry] = []
        var starts: [Double] = []
        var ends: [Double] = []
        let table = PissArc.rings
        for piece in 0..<PissArc.pieceCount {
            let first = piece * PissArc.ringsPerPiece
            let last = first + PissArc.ringsPerPiece
            meshes.append(PissGeometry.tube(first: first, last: last, liquid: liquid, beads: beads))
            starts.append(table.u[first])
            ends.append(table.u[last])
        }
        return (meshes, starts, ends)
    }

    /// Materials plus one node holding every mesh and particle system, for `SCNView.prepare`.
    private func warmupObjects() -> [Any] {
        let sample = SCNNode()
        let geometries: [SCNGeometry] = [fullTube, head, crownMesh, cloudPlane] + Array(pieces.prefix(1))
        for geometry in geometries { sample.addChildNode(SCNNode(geometry: geometry)) }
        let systems: [SCNParticleSystem] = [PissParticles.spray(), PissParticles.hops(), PissParticles.drips()]
        for system in systems { sample.addParticleSystem(system) }
        let materials: [Any] = [liquid, beads, crown, cloud, ripple, puddle, shadow]
        return materials + [sample]
    }
}
