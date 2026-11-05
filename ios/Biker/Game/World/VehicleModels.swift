import SceneKit
import UIKit

/// Traffic built from primitives: a car, a box lorry and a sewage tanker. Each faces -z with its
/// taillights at +z, where the rider sees them. Body paint is the material named `paint-*`.
@MainActor
enum VehicleModels {
    static let paints: [UIColor] = [
        UIColor(red: 0.75, green: 0.06, blue: 0.08, alpha: 1), UIColor(red: 0.08, green: 0.22, blue: 0.7, alpha: 1),
        UIColor(white: 0.85, alpha: 1), UIColor(white: 0.06, alpha: 1), UIColor(red: 1, green: 0.75, blue: 0.05, alpha: 1),
        UIColor(red: 0.1, green: 0.45, blue: 0.2, alpha: 1), UIColor(red: 0.4, green: 0.1, blue: 0.55, alpha: 1),
        UIColor(white: 0.55, alpha: 1),
    ]

    static func paint(_ index: Int, library: MaterialLibrary) -> SCNMaterial {
        let safe = abs(index) % paints.count
        return library.shared("paint-\(safe)", bend: false) {
            WorldMaterials.pbr(paints[safe], metalness: 0.65, roughness: 0.28)
        }
    }

    static func make(_ kind: VehicleKind, library: MaterialLibrary) -> SCNNode {
        let holder = SCNNode()
        switch kind {
        case .car: buildCar(holder, library)
        case .truck: buildTruck(holder, library)
        case .sewageTanker: buildTanker(holder, library)
        }
        let flat = library.flatten(holder, castsShadow: true)
        return flat
    }

    // MARK: - Materials

    private static func glass(_ library: MaterialLibrary) -> SCNMaterial {
        library.shared("carGlass", bend: false) { WorldMaterials.pbr(UIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1), metalness: 0.9, roughness: 0.08) }
    }

    private static func tyre(_ library: MaterialLibrary) -> SCNMaterial {
        library.shared("tyre", bend: false) { WorldMaterials.pbr(UIColor(white: 0.05, alpha: 1), roughness: 0.85) }
    }

    private static func chassis(_ library: MaterialLibrary) -> SCNMaterial {
        library.shared("chassis", bend: false) { WorldMaterials.pbr(UIColor(white: 0.12, alpha: 1), metalness: 0.5, roughness: 0.6) }
    }

    private static func tailLight(_ library: MaterialLibrary) -> SCNMaterial {
        library.shared("tailLight", bend: false) { WorldMaterials.glow(UIColor(red: 1, green: 0.05, blue: 0.05, alpha: 1), boost: 2.2) }
    }

    private static func headLight(_ library: MaterialLibrary) -> SCNMaterial {
        library.shared("headLight", bend: false) { WorldMaterials.glow(UIColor(red: 1, green: 0.96, blue: 0.85, alpha: 1), boost: 2) }
    }

    private static func amber(_ library: MaterialLibrary) -> SCNMaterial {
        library.shared("amberLight", bend: false) { WorldMaterials.glow(UIColor(red: 1, green: 0.6, blue: 0.05, alpha: 1), boost: 1.6) }
    }

    private static func picture(_ name: String, _ library: MaterialLibrary, make: () -> UIImage) -> SCNMaterial {
        library.shared(name, bend: false) {
            let material = WorldMaterials.pbr(.white, roughness: 0.5)
            material.diffuse.contents = make()
            material.emission.contents = UIColor(white: 0.12, alpha: 1)
            return material
        }
    }

    // MARK: - Parts

    private static func box(_ w: Double, _ h: Double, _ l: Double, _ chamfer: Double, _ material: SCNMaterial, _ x: Double, _ y: Double, _ z: Double) -> SCNNode {
        let shape = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l), chamferRadius: CGFloat(chamfer))
        shape.firstMaterial = material
        let node = SCNNode(geometry: shape)
        node.position = Shapes.v(x, y, z)
        return node
    }

    private static func wheels(_ holder: SCNNode, _ library: MaterialLibrary, radius: Double, x: Double, zs: [Double]) {
        for z in zs {
            for side in [-1.0, 1.0] {
                let shape = SCNCylinder(radius: CGFloat(radius), height: 0.3)
                shape.radialSegmentCount = 14
                shape.firstMaterial = tyre(library)
                let wheel = SCNNode(geometry: shape)
                wheel.position = Shapes.v(side * x, radius, z)
                wheel.eulerAngles.z = .pi / 2
                holder.addChildNode(wheel)
            }
        }
    }

    private static func lights(_ holder: SCNNode, _ library: MaterialLibrary, x: Double, y: Double, rear: Double, front: Double) {
        for side in [-1.0, 1.0] {
            holder.addChildNode(box(0.42, 0.16, 0.06, 0, tailLight(library), side * x, y, rear))
            holder.addChildNode(box(0.36, 0.14, 0.06, 0, headLight(library), side * x, y - 0.04, front))
        }
    }

    private static func buildCar(_ holder: SCNNode, _ library: MaterialLibrary) {
        let half = VehicleKind.car.halfLength
        holder.addChildNode(box(2.0, 0.62, half * 2, 0.18, paint(0, library: library), 0, 0.66, 0))
        holder.addChildNode(box(1.68, 0.58, 2.3, 0.24, glass(library), 0, 1.22, 0.2))
        holder.addChildNode(box(1.7, 0.06, 2.0, 0.03, paint(0, library: library), 0, 1.52, 0.2))
        wheels(holder, library, radius: 0.36, x: 0.92, zs: [-1.4, 1.4])
        lights(holder, library, x: 0.66, y: 0.8, rear: half + 0.01, front: -half - 0.01)
        holder.addChildNode(box(1.3, 0.05, 0.05, 0, tailLight(library), 0, 0.84, half + 0.01))
        let plate = picture("plate", library) {
            CityTextures.plate("Г 000 ВН 77", background: .white, foreground: .black, size: CGSize(width: 256, height: 64))
        }
        holder.addChildNode(Shapes.panel(0.56, 0.14, plate, at: Shapes.v(0, 0.48, half + 0.02)))
    }

    private static func buildTruck(_ holder: SCNNode, _ library: MaterialLibrary) {
        let half = VehicleKind.truck.halfLength
        holder.addChildNode(box(2.2, 0.45, half * 2 - 0.2, 0, chassis(library), 0, 0.75, 0))
        holder.addChildNode(box(2.4, 2.3, 2.2, 0.15, paint(1, library: library), 0, 1.75, -half + 1.15))
        holder.addChildNode(box(2.2, 0.85, 0.08, 0.02, glass(library), 0, 2.3, -half + 0.03))
        let cargoLength = half * 2 - 2.5
        let cargo = library.shared("cargo", bend: false) { WorldMaterials.pbr(UIColor(white: 0.82, alpha: 1), metalness: 0.3, roughness: 0.45) }
        holder.addChildNode(box(2.5, 3.0, cargoLength, 0.05, cargo, 0, 2.3, half - cargoLength / 2))
        let door = picture("truckDoor", library) {
            CityTextures.plate("ПЕРДИТ!\nНЕ ОБГОНЯТЬ", background: UIColor(red: 0.95, green: 0.95, blue: 0.9, alpha: 1),
                               foreground: UIColor(red: 0.5, green: 0.25, blue: 0.08, alpha: 1), size: CGSize(width: 256, height: 320))
        }
        holder.addChildNode(Shapes.panel(2.3, 2.8, door, at: Shapes.v(0, 2.3, half + 0.01)))
        wheels(holder, library, radius: 0.5, x: 1.05, zs: [-half + 1.2, half - 2.4, half - 1.2])
        lights(holder, library, x: 0.95, y: 0.95, rear: half + 0.02, front: -half - 0.01)
        for side in [-1.0, 1.0] {
            holder.addChildNode(box(0.14, 0.14, 0.06, 0, amber(library), side * 1.15, 3.7, half + 0.02))
        }
    }

    private static func buildTanker(_ holder: SCNNode, _ library: MaterialLibrary) {
        let half = VehicleKind.sewageTanker.halfLength
        holder.addChildNode(box(2.2, 0.45, half * 2 - 0.2, 0, chassis(library), 0, 0.75, 0))
        holder.addChildNode(box(2.4, 2.3, 2.1, 0.15, paint(4, library: library), 0, 1.75, -half + 1.1))
        holder.addChildNode(box(2.2, 0.85, 0.08, 0.02, glass(library), 0, 2.3, -half + 0.03))
        let tankLength = half * 2 - 2.4
        let tankMaterial = library.shared("tank", bend: false) {
            WorldMaterials.pbr(UIColor(red: 0.42, green: 0.27, blue: 0.1, alpha: 1), metalness: 0.7, roughness: 0.3)
        }
        let tankShape = SCNCylinder(radius: 1.15, height: CGFloat(tankLength))
        tankShape.radialSegmentCount = 20
        tankShape.firstMaterial = tankMaterial
        let tank = SCNNode(geometry: tankShape)
        tank.eulerAngles.x = .pi / 2
        tank.position = Shapes.v(0, 2.15, half - tankLength / 2)
        holder.addChildNode(tank)
        let sign = picture("tankerSign", library) {
            CityTextures.plate("ГОВНОВОЗ", background: UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1), foreground: .black, size: CGSize(width: 256, height: 128))
        }
        holder.addChildNode(Shapes.panel(1.5, 0.75, sign, at: Shapes.v(0, 2.15, half + 0.02)))
        let hose = SCNTorus(ringRadius: 0.35, pipeRadius: 0.08)
        hose.firstMaterial = chassis(library)
        let hoseNode = SCNNode(geometry: hose)
        hoseNode.position = Shapes.v(1.3, 1.1, 0.6)
        hoseNode.eulerAngles.z = .pi / 2
        holder.addChildNode(hoseNode)
        wheels(holder, library, radius: 0.5, x: 1.05, zs: [-half + 1.1, half - 1.3])
        lights(holder, library, x: 0.95, y: 0.95, rear: half + 0.02, front: -half - 0.01)
    }

    /// Gives a pooled vehicle a new body colour.
    static func repaint(_ node: SCNNode, with material: SCNMaterial) {
        guard let geometry = node.geometry else { return }
        geometry.materials = geometry.materials.map { existing in
            (existing.name ?? "").hasPrefix("paint-") ? material : existing
        }
    }
}
