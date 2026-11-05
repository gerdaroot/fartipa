import SceneKit
import UIKit

/// Puts the photo maps and baked pictures from `TexPhotos` on the world's shared materials, by
/// material name. Runs on the main actor once the background load is done (from
/// `RoadLayer.applySurfaces`, before the warm-up compiles shaders) and for any material made later.
/// Only cheap property assignments happen here; every picture was decoded in the background.
@MainActor
enum TexDress {
    /// How one material wears a photo: which photo and how often it repeats across its faces.
    private struct Recipe {
        let kind: TexPhotoKind
        let scaleX: Float
        let scaleY: Float
        let normalIntensity: CGFloat
        let colorToo: Bool
        let tint: UIColor?
        let metalness: Double?
    }

    private static let recipes: [String: Recipe] = [
        "sidewalk": Recipe(kind: .sidewalk, scaleX: 2.5, scaleY: 60, normalIntensity: 1, colorToo: true,
                           tint: UIColor(red: 0.62, green: 0.6, blue: 0.62, alpha: 1), metalness: nil),
        "rail": Recipe(kind: .metal, scaleX: 40, scaleY: 1, normalIntensity: 1, colorToo: true,
                       tint: UIColor(white: 1.0, alpha: 1), metalness: 0.55),
        "steel": Recipe(kind: .metal, scaleX: 1, scaleY: 3, normalIntensity: 0.8, colorToo: true,
                        tint: UIColor(white: 0.85, alpha: 1), metalness: 0.55),
        "concrete": Recipe(kind: .concrete, scaleX: 3, scaleY: 3, normalIntensity: 1, colorToo: true,
                           tint: UIColor(white: 0.5, alpha: 1), metalness: nil),
        "tunnelWall": Recipe(kind: .concrete, scaleX: 22, scaleY: 2, normalIntensity: 1, colorToo: true,
                             tint: UIColor(red: 0.6, green: 0.64, blue: 0.58, alpha: 1), metalness: nil),
        "roof": Recipe(kind: .concrete, scaleX: 2, scaleY: 2, normalIntensity: 0.8, colorToo: true,
                       tint: UIColor(white: 0.18, alpha: 1), metalness: nil),
        "chassis": Recipe(kind: .rust, scaleX: 3, scaleY: 1, normalIntensity: 1, colorToo: true,
                          tint: UIColor(white: 0.35, alpha: 1), metalness: 0.4),
        "tank": Recipe(kind: .rust, scaleX: 2, scaleY: 3, normalIntensity: 1, colorToo: true,
                       tint: UIColor(red: 0.62, green: 0.45, blue: 0.28, alpha: 1), metalness: 0.45),
    ]

    /// Every material the library holds now.
    static func dressAll(_ library: MaterialLibrary) {
        guard TexPhotos.shared.isReady else { return }
        for material in library.allMaterials { dress(material, library: library) }
    }

    /// One material, by its name. Does nothing for names it does not know or photos not bundled.
    static func dress(_ material: SCNMaterial, library: MaterialLibrary) {
        guard let name = material.name, TexPhotos.shared.isReady else { return }
        if let look = library.facadeLook(named: name) {
            dressFacade(material, look: look)
        } else if name.hasPrefix("paint-") {
            dressPaint(material)
        } else if name == "cargo" {
            dressCargo(material)
        } else if let recipe = recipes[name], let maps = TexPhotos.shared.maps(recipe.kind) {
            apply(recipe, maps: maps, to: material)
        }
    }

    private static func apply(_ recipe: Recipe, maps: TexMaps, to material: SCNMaterial) {
        if recipe.colorToo {
            material.diffuse.contents = maps.colorImage
            WorldMaterials.repeating(material.diffuse, scaleX: recipe.scaleX, scaleY: recipe.scaleY)
            material.multiply.contents = recipe.tint
        }
        if let normal = maps.normalImage {
            material.normal.contents = normal
            material.normal.intensity = recipe.normalIntensity
            WorldMaterials.repeating(material.normal, scaleX: recipe.scaleX, scaleY: recipe.scaleY)
        }
        if let roughness = maps.roughnessImage {
            material.roughness.contents = roughness
            WorldMaterials.repeating(material.roughness, scaleX: recipe.scaleX, scaleY: recipe.scaleY)
        }
        if let metalness = recipe.metalness {
            material.metalness.contents = NSNumber(value: metalness)
        }
    }

    /// The facade's own window grid on a photo wall, with recessed windows in the normal map.
    private static func dressFacade(_ material: SCNMaterial, look: TexFacadeLook) {
        guard let set = TexPhotos.shared.facade(look) else { return }
        material.diffuse.contents = set.base
        material.emission.contents = set.glow
        WorldMaterials.mipmapped(material.diffuse)
        WorldMaterials.mipmapped(material.emission)
        guard let normal = set.normal else { return }
        material.normal.contents = normal
        material.normal.intensity = 1
        material.normal.contentsTransform = material.diffuse.contentsTransform
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        WorldMaterials.mipmapped(material.normal)
    }

    /// Door seams and a waist line on every car paint.
    private static func dressPaint(_ material: SCNMaterial) {
        guard let panels = TexPhotos.shared.vehicles?.panelNormal else { return }
        material.normal.contents = panels
        material.normal.intensity = 0.9
        WorldMaterials.mipmapped(material.normal)
    }

    /// Corrugated steel sides with the game's name; the ribs come from the photo normal.
    private static func dressCargo(_ material: SCNMaterial) {
        guard let parts = TexPhotos.shared.vehicles else { return }
        material.diffuse.contents = parts.cargoLivery
        WorldMaterials.mipmapped(material.diffuse)
        material.metalness.contents = NSNumber(value: 0.25)
        guard let ribs = TexPhotos.shared.maps(.corrugated)?.normalImage else { return }
        material.normal.contents = ribs
        material.normal.intensity = 1
        WorldMaterials.repeating(material.normal, scaleX: 6, scaleY: 1)
    }
}
