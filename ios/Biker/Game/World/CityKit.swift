import SceneKit
import UIKit

/// Shared pictures and materials of the city, and names of the ones a palette recolours.
@MainActor
final class CityKit {
    static let neonColors: [ColorValue] = [
        ColorValue(hex: 0xFF2E93), ColorValue(hex: 0x19E6FF), ColorValue(hex: 0x8CFF2E),
        ColorValue(hex: 0xFFD21E), ColorValue(hex: 0xB040FF), ColorValue(hex: 0xFF7A10),
    ]
    /// Metres of facade one texture tile covers.
    static let facadeTileWidth = 10.0
    static let facadeTileHeight = 24.0

    let library: MaterialLibrary
    private(set) var signMaterials: [SCNMaterial] = []
    private(set) var facadeNames: [String] = []
    /// Stand-ins until the background pass paints the real facades (see `TexDress`): they keep
    /// the facade materials on their textured shader, so the swap is only a texture upload.
    private let facadeWall = BikeTextures.solid(UIColor(white: 0.12, alpha: 1))
    private let facadeDark = BikeTextures.solid(.black)

    init(library: MaterialLibrary) {
        self.library = library
        let placeholder = BikeTextures.solid(UIColor(white: 0.02, alpha: 1))
        for index in CityTextures.slogans.indices {
            signMaterials.append(library.shared("sign-\(index)") { WorldMaterials.screen(placeholder, boost: 1.1) })
        }
    }

    /// Paints the neon slogans on a background queue (text with blurred glow is slow) and puts them on
    /// the sign materials. `done` runs on the main actor once every sign has its picture.
    func paintSigns(done: @escaping @MainActor () -> Void) {
        let jobs: [(text: String, color: ColorValue, accent: ColorValue)] = CityTextures.slogans.indices.map { index in
            let color = Self.neonColors[index % Self.neonColors.count]
            let accent = Self.neonColors[(index + 2) % Self.neonColors.count]
            return (CityTextures.slogans[index], color, accent)
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let images: [UIImage] = jobs.map { CityTextures.neonSign($0.text, color: $0.color, accent: $0.accent) }
            Task { @MainActor in
                if let self {
                    for (material, image) in zip(self.signMaterials, images) {
                        material.diffuse.contents = image
                        material.emission.contents = image
                    }
                }
                done()
            }
        }
    }

    /// The facade of one style (and window grid `variant`) stretched over `width` x `height` metres
    /// without distorting windows. The pictures arrive from the background pass.
    func facade(_ style: FacadeStyle, width: Double, height: Double, variant: Int = 0) -> SCNMaterial {
        let across = max(0.25, (width / Self.facadeTileWidth * 4).rounded() / 4)
        let up = max(0.125, (height / Self.facadeTileHeight * 8).rounded() / 8)
        let look = TexFacadeLook(style: style, variant: max(0, min(TexFacadePaint.variants - 1, variant)))
        let suffix = look.variant > 0 ? "-v\(look.variant)" : ""
        let name = "facade-\(style.rawValue)-\(across)-\(up)\(suffix)"
        library.registerFacade(name, look: look)
        let glass = style == .glass
        let wall = facadeWall
        let dark = facadeDark
        let material = library.shared(name) {
            let made = WorldMaterials.pbr(.white, metalness: glass ? 0.45 : 0.05, roughness: glass ? 0.2 : 0.75)
            made.diffuse.contents = wall
            made.emission.contents = dark
            made.emission.intensity = 1.15
            for property in [made.diffuse, made.emission] {
                WorldMaterials.repeating(property, scaleX: Float(across), scaleY: Float(up))
            }
            return made
        }
        if !facadeNames.contains(name) { facadeNames.append(name) }
        return material
    }

    /// The game's own poster for building walls.
    var gamePoster: SCNMaterial {
        library.shared("gamePoster") { WorldMaterials.screen(BikeTextures.defaultPoster(), boost: 0.55) }
    }

    var neonA: SCNMaterial { library.shared("neonA") { WorldMaterials.glow(UIColor(red: 1, green: 0.2, blue: 0.6, alpha: 1), boost: 1.2) } }
    var neonB: SCNMaterial { library.shared("neonB") { WorldMaterials.glow(UIColor(red: 0.1, green: 0.9, blue: 1, alpha: 1), boost: 1.2) } }
    var beacon: SCNMaterial { library.shared("beacon") { WorldMaterials.glow(UIColor(red: 1, green: 0.1, blue: 0.08, alpha: 1), boost: 1.5) } }
    var lampHead: SCNMaterial { library.shared("lampHead") { WorldMaterials.glow(UIColor(red: 1, green: 0.75, blue: 0.4, alpha: 1), boost: 2) } }
    var lightPool: SCNMaterial { library.shared("lightPool") { WorldMaterials.decal(SpriteTextures.lightPool, additive: true) } }
    var tubeLight: SCNMaterial { library.shared("tubeLight") { WorldMaterials.glow(UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 1), boost: 1.4) } }

    var steel: SCNMaterial {
        library.shared("steel") { WorldMaterials.pbr(UIColor(white: 0.36, alpha: 1), metalness: 0.55, roughness: 0.4) }
    }

    var concrete: SCNMaterial {
        library.shared("concrete") { WorldMaterials.pbr(UIColor(red: 0.3, green: 0.29, blue: 0.3, alpha: 1), roughness: 0.8) }
    }

    var roof: SCNMaterial {
        library.shared("roof") { WorldMaterials.pbr(UIColor(white: 0.08, alpha: 1), roughness: 0.9) }
    }

    func randomSign(_ random: inout SplitMix) -> SCNMaterial {
        signMaterials[random.int(below: signMaterials.count)]
    }

    /// A material showing a picture that is made once and named.
    func screen(named name: String, boost: CGFloat = 0.9, image: () -> UIImage) -> SCNMaterial {
        library.shared(name) { WorldMaterials.screen(image(), boost: boost) }
    }

    /// Recolours everything that follows the district palette.
    func apply(_ palette: WorldPalette) {
        let tint = palette.windows.ui
        for name in facadeNames { library.material(named: name)?.multiply.contents = tint }
        setGlow(neonA, palette.neonA)
        setGlow(neonB, palette.neonB)
        setGlow(lampHead, palette.lamp)
        if let curb = library.material(named: "curbGlow") { setGlow(curb, palette.neonA) }
        lightPool.multiply.contents = palette.lamp.ui
    }

    private func setGlow(_ material: SCNMaterial, _ color: ColorValue) {
        material.diffuse.contents = color.ui
        material.emission.contents = color.ui
    }

    /// Breathes the red aircraft beacons on the roofs.
    func pulse(time: Double) {
        beacon.emission.intensity = CGFloat(0.2 + 1.6 * max(0, sin(time * 3)))
    }
}

/// Shorthand for building decor out of primitives.
enum Shapes {
    static func box(
        _ width: Double, _ height: Double, _ length: Double, _ material: SCNMaterial,
        at position: SCNVector3, segments: Int = 1
    ) -> SCNNode {
        let shape = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(length), chamferRadius: 0)
        shape.lengthSegmentCount = segments
        shape.firstMaterial = material
        let node = SCNNode(geometry: shape)
        node.position = position
        return node
    }

    static func cylinder(_ radius: Double, _ height: Double, _ material: SCNMaterial, at position: SCNVector3) -> SCNNode {
        let shape = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        shape.radialSegmentCount = 12
        shape.firstMaterial = material
        let node = SCNNode(geometry: shape)
        node.position = position
        return node
    }

    /// A plane facing +z (towards the camera) or turned by `yaw`.
    static func panel(_ width: Double, _ height: Double, _ material: SCNMaterial, at position: SCNVector3, yaw: Double = 0) -> SCNNode {
        let shape = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        shape.firstMaterial = material
        let node = SCNNode(geometry: shape)
        node.position = position
        node.eulerAngles.y = Float(yaw)
        return node
    }

    /// A plane lying on the ground.
    static func decal(_ width: Double, _ length: Double, _ material: SCNMaterial, at position: SCNVector3) -> SCNNode {
        let shape = SCNPlane(width: CGFloat(width), height: CGFloat(length))
        shape.firstMaterial = material
        let node = SCNNode(geometry: shape)
        node.eulerAngles.x = -.pi / 2
        node.position = position
        return node
    }

    static func v(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
        SCNVector3(Float(x), Float(y), Float(z))
    }
}
