import SceneKit
import UIKit

/// Physically based materials shared by every rig. The same inputs return the same instance,
/// so rigs never allocate duplicate materials and SceneKit can batch them.
///
/// Metal finishes look best when the scene has `lightingEnvironment.contents` set (any sky image).
@MainActor
enum ModelMaterials {
    private static var cache: [String: SCNMaterial] = [:]

    private static let clearCoatRoughness = 0.06
    private static let warmWhite = UIColor(red: 1, green: 0.95, blue: 0.82, alpha: 1)

    // MARK: - Colour helpers

    static func color(_ rgb: RGB, scale: Double = 1) -> UIColor {
        UIColor(
            red: CGFloat(min(max(rgb.r * scale, 0), 1)),
            green: CGFloat(min(max(rgb.g * scale, 0), 1)),
            blue: CGFloat(min(max(rgb.b * scale, 0), 1)),
            alpha: 1
        )
    }

    static func key(_ rgb: RGB) -> String {
        String(format: "%.3f_%.3f_%.3f", rgb.r, rgb.g, rgb.b)
    }

    /// Yellow-orange colours with little blue read as gold and get a metal finish.
    static func isGoldLike(_ rgb: RGB) -> Bool {
        rgb.r > 0.68 && rgb.g > 0.5 && rgb.b < 0.45 && rgb.r - rgb.b > 0.4
    }

    // MARK: - Core builder

    static func pbr(
        _ name: String, diffuse: UIColor, metal: Double, rough: Double,
        clearCoat: Double = 0, emission: UIColor? = nil, doubleSided: Bool = false
    ) -> SCNMaterial {
        if let hit = cache[name] { return hit }
        let material = SCNMaterial()
        material.name = name
        material.lightingModel = .physicallyBased
        material.diffuse.contents = diffuse
        material.metalness.contents = NSNumber(value: metal)
        material.roughness.contents = NSNumber(value: rough)
        if clearCoat > 0 {
            material.clearCoat.contents = NSNumber(value: clearCoat)
            material.clearCoatRoughness.contents = NSNumber(value: clearCoatRoughness)
        }
        if let emission {
            material.emission.contents = emission
        }
        material.isDoubleSided = doubleSided
        cache[name] = material
        return material
    }

    // MARK: - Paints and finishes

    /// Glossy car paint with a clear coat; gold colours become polished metal.
    static func paint(_ rgb: RGB) -> SCNMaterial {
        if isGoldLike(rgb) {
            return pbr("gold-\(key(rgb))", diffuse: color(rgb), metal: 1, rough: 0.2)
        }
        return pbr("paint-\(key(rgb))", diffuse: color(rgb), metal: 0.15, rough: 0.32, clearCoat: 1)
    }

    /// Metal-flake paint for frames, rims and trim.
    static func candy(_ rgb: RGB) -> SCNMaterial {
        pbr("candy-\(key(rgb))", diffuse: color(rgb), metal: 0.6, rough: 0.3, clearCoat: 0.6)
    }

    static func plastic(_ rgb: RGB) -> SCNMaterial {
        pbr("plastic-\(key(rgb))", diffuse: color(rgb), metal: 0, rough: 0.45)
    }

    static func leather(_ rgb: RGB) -> SCNMaterial {
        pbr("leather-\(key(rgb))", diffuse: color(rgb), metal: 0, rough: 0.55, clearCoat: 0.25)
    }

    static func fabric(_ rgb: RGB, doubleSided: Bool = false) -> SCNMaterial {
        pbr("fabric-\(key(rgb))-\(doubleSided)", diffuse: color(rgb), metal: 0, rough: 0.82, doubleSided: doubleSided)
    }

    /// Glossy ceramic for toilets; gold toilets stay gold.
    static func porcelain(_ rgb: RGB) -> SCNMaterial {
        if isGoldLike(rgb) { return paint(rgb) }
        return pbr("porcelain-\(key(rgb))", diffuse: color(rgb), metal: 0, rough: 0.1, clearCoat: 1)
    }

    /// Wet-looking poop.
    static func poop(_ rgb: RGB) -> SCNMaterial {
        if isGoldLike(rgb) { return paint(rgb) }
        return pbr("poop-\(key(rgb))", diffuse: color(rgb), metal: 0, rough: 0.38, clearCoat: 0.7)
    }

    /// Helmet visor: dark glossy glass tinted by the visor colour, faintly lit so it reads at night.
    static func visor(_ rgb: RGB) -> SCNMaterial {
        pbr("visor-\(key(rgb))", diffuse: color(rgb, scale: 0.7), metal: 0.4, rough: 0.05,
            clearCoat: 1, emission: color(rgb, scale: 0.22))
    }

    /// Self-lit colour: neon strips, nozzle glow, gems.
    static func glow(_ rgb: RGB, strength: Double = 1) -> SCNMaterial {
        pbr("glow-\(key(rgb))-\(strength)", diffuse: color(rgb, scale: 0.3), metal: 0, rough: 0.4,
            emission: color(rgb, scale: strength))
    }

    // MARK: - Fixed finishes

    static var chrome: SCNMaterial {
        pbr("chrome", diffuse: UIColor(white: 0.96, alpha: 1), metal: 1, rough: 0.12)
    }

    static var brushed: SCNMaterial {
        pbr("brushed", diffuse: UIColor(white: 0.68, alpha: 1), metal: 0.9, rough: 0.38)
    }

    static var darkMetal: SCNMaterial {
        pbr("darkMetal", diffuse: UIColor(white: 0.13, alpha: 1), metal: 0.75, rough: 0.42)
    }

    static var rubber: SCNMaterial {
        pbr("rubber", diffuse: UIColor(white: 0.045, alpha: 1), metal: 0, rough: 0.92)
    }

    static var blackPlastic: SCNMaterial {
        pbr("blackPlastic", diffuse: UIColor(white: 0.07, alpha: 1), metal: 0, rough: 0.5)
    }

    static var gold: SCNMaterial {
        pbr("pureGold", diffuse: UIColor(red: 1, green: 0.79, blue: 0.28, alpha: 1), metal: 1, rough: 0.18)
    }

    static var headlightLens: SCNMaterial {
        pbr("headlight", diffuse: .white, metal: 0, rough: 0.1, emission: warmWhite)
    }

    static var taillightLens: SCNMaterial {
        pbr("taillight", diffuse: UIColor(red: 0.5, green: 0, blue: 0, alpha: 1), metal: 0, rough: 0.2,
            emission: UIColor(red: 1, green: 0.06, blue: 0.04, alpha: 1))
    }

    static var indicator: SCNMaterial {
        pbr("indicator", diffuse: UIColor(red: 0.6, green: 0.35, blue: 0, alpha: 1), metal: 0, rough: 0.2,
            emission: UIColor(red: 1, green: 0.55, blue: 0.05, alpha: 1))
    }

    static var whiteRubber: SCNMaterial {
        pbr("whiteRubber", diffuse: UIColor(white: 0.93, alpha: 1), metal: 0, rough: 0.7)
    }

    static var paper: SCNMaterial {
        pbr("paper", diffuse: UIColor(white: 0.97, alpha: 1), metal: 0, rough: 0.95)
    }

    static var cardboard: SCNMaterial {
        pbr("cardboard", diffuse: UIColor(red: 0.62, green: 0.45, blue: 0.27, alpha: 1), metal: 0, rough: 0.9)
    }

    static var wood: SCNMaterial {
        pbr("wood", diffuse: UIColor(red: 0.66, green: 0.45, blue: 0.24, alpha: 1), metal: 0, rough: 0.6)
    }

    static var bone: SCNMaterial {
        pbr("bone", diffuse: UIColor(red: 0.92, green: 0.86, blue: 0.72, alpha: 1), metal: 0, rough: 0.4, clearCoat: 0.4)
    }

    static var fur: SCNMaterial {
        pbr("fur", diffuse: UIColor(red: 0.36, green: 0.27, blue: 0.2, alpha: 1), metal: 0, rough: 1)
    }

    static var eyeWhite: SCNMaterial {
        pbr("eyeWhite", diffuse: .white, metal: 0, rough: 0.15, clearCoat: 1)
    }

    static var water: SCNMaterial {
        pbr("water", diffuse: UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1), metal: 0.2, rough: 0.05,
            clearCoat: 1, emission: UIColor(red: 0.05, green: 0.18, blue: 0.3, alpha: 1))
    }
}
