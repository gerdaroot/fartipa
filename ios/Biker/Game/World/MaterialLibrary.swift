import SceneKit
import UIKit

/// Every shared material of the world, by name. Bendable ones get the road-curve shader and
/// receive the bend every frame. Flattened decor is remapped back to these exact instances,
/// so a palette change or a late texture reaches every copy.
@MainActor
final class MaterialLibrary {
    private var byName: [String: SCNMaterial] = [:]
    private var bendable: [SCNMaterial] = []
    private var lastBend = BendAmount(x: .nan, y: .nan)

    /// The material called `name`, made on first use.
    func shared(_ name: String, bend: Bool = true, make: () -> SCNMaterial) -> SCNMaterial {
        if let existing = byName[name] { return existing }
        let material = make()
        material.name = name
        byName[name] = material
        if bend {
            WorldBend.attach(to: material)
            WorldBend.apply(lastBend.x.isNaN ? .flat : lastBend, to: material)
            bendable.append(material)
        }
        return material
    }

    func material(named name: String) -> SCNMaterial? { byName[name] }

    /// Every material made so far, for warming up the renderer.
    var allMaterials: [SCNMaterial] { Array(byName.values) }

    func applyBend(_ amount: BendAmount) {
        guard amount != lastBend else { return }
        lastBend = amount
        for material in bendable { WorldBend.apply(amount, to: material) }
    }

    /// One draw call per material instead of one per part. Shadows are off for decor.
    func flatten(_ node: SCNNode, castsShadow: Bool = false) -> SCNNode {
        let flat = node.flattenedClone()
        remap(flat)
        flat.castsShadow = castsShadow
        return flat
    }

    private func remap(_ node: SCNNode) {
        if let geometry = node.geometry {
            geometry.materials = geometry.materials.map { material in
                guard let name = material.name, let canonical = byName[name] else { return material }
                return canonical
            }
        }
        for child in node.childNodes { remap(child) }
    }
}

/// Recipes for the kinds of material the world uses.
enum WorldMaterials {
    /// A physically based surface.
    static func pbr(_ color: UIColor, metalness: CGFloat = 0, roughness: CGFloat = 0.5) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = NSNumber(value: Double(metalness))
        material.roughness.contents = NSNumber(value: Double(roughness))
        return material
    }

    /// Unlit and bright, for neon, lamps and markings. `boost` above 0 pushes it past white for bloom.
    static func glow(_ color: UIColor, boost: CGFloat = 0.6) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = boost
        return material
    }

    /// A transparent picture laid on something, drawn after it without writing depth.
    static func decal(_ image: UIImage, additive: Bool, lit: Bool = false) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = lit ? .physicallyBased : .constant
        material.diffuse.contents = image
        mipmapped(material.diffuse)
        material.blendMode = additive ? .add : .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.transparencyMode = .aOne
        if lit {
            material.roughness.contents = NSNumber(value: 0.12)
            material.metalness.contents = NSNumber(value: 0.0)
        }
        return material
    }

    /// A picture that glows by itself, like a neon sign or a lit road sign.
    static func screen(_ image: UIImage, boost: CGFloat = 0.8) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = image
        material.emission.contents = image
        material.emission.intensity = boost
        mipmapped(material.diffuse)
        mipmapped(material.emission)
        return material
    }

    /// Far-away pictures read from small mip levels: sharper at a distance and far less memory traffic.
    static func mipmapped(_ property: SCNMaterialProperty) {
        property.mipFilter = .linear
        property.minificationFilter = .linear
        property.magnificationFilter = .linear
    }

    static func repeating(_ property: SCNMaterialProperty, scaleX: Float, scaleY: Float) {
        property.wrapS = .repeat
        property.wrapT = .repeat
        property.mipFilter = .linear
        property.maxAnisotropy = 8
        property.contentsTransform = SCNMatrix4MakeScale(scaleX, scaleY, 1)
    }
}

extension ColorValue {
    var ui: UIColor { UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }
}

extension SCNNode {
    /// Turns shadow casting off for this node and everything under it.
    func disableShadows() {
        castsShadow = false
        for child in childNodes { child.disableShadows() }
    }
}
