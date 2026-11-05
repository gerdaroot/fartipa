import SceneKit
import UIKit

/// Road sizes the city builders need too.
enum RoadMetrics {
    static let sidewalkInner = BikeRun.roadHalfWidth + 0.3
    static let sidewalkWidth = 3.4
    static let sidewalkHeight = 0.2
}

/// The glossy poop highway: tiles of road with glowing lane markings, raised sidewalks with a
/// neon curb, crash barriers, and plain dirt beyond. Tiles recycle as the bike rides.
/// Few long tiles: each is one flattened node with one draw call per material, so the whole road
/// costs about 35 draw calls and still reaches past the end of the fog.
@MainActor
final class RoadLayer {
    static let tileLength = 80.0
    private static let tileCount = 5
    private static let tileSegments = 20
    private static let roadWidth = BikeRun.roadHalfWidth * 2 + 0.6
    private static let laneLineX: [Double] = [-1.3, 1.3]
    private static let edgeLineX = BikeRun.roadHalfWidth - 0.15
    private static let dashLength = 3.2
    private static let dashSpacing = 8.0
    private static let sidewalkInner = RoadMetrics.sidewalkInner
    private static let sidewalkWidth = RoadMetrics.sidewalkWidth
    private static let sidewalkHeight = RoadMetrics.sidewalkHeight
    private static let groundWidth = 110.0
    /// One road texture repeat is this long, so a tile holds a whole number of them.
    private static let roadRepeat = 5.0
    /// The road picture repeats this many times across the road (about 4.3 m each).
    private static let roadAcross: Float = 2
    private static let groundRepeat = 8.0

    private let row: SceneryRow
    private let library: MaterialLibrary

    init(root: SCNNode, library: MaterialLibrary) {
        self.library = library
        row = SceneryRow(period: Self.tileLength * Double(Self.tileCount), behind: Self.tileLength + 12, maxAhead: 1000)
        for index in 0..<Self.tileCount {
            row.add(makeTile(), offset: Double(index) * Self.tileLength, parent: root)
        }
    }

    func update(distance: Double) {
        row.update(distance: distance) { _, _, _, _ in true }
    }

    /// Puts the generated poop maps on the road, ground and sidewalks.
    func applySurfaces(road: SurfaceSet?, ground: SurfaceSet?) {
        if let road, let material = library.material(named: "road") {
            setMaps(material, road, scaleX: Self.roadAcross, scaleY: Float(Self.tileLength / Self.roadRepeat))
            material.diffuse.contents = road.albedo
        }
        if let ground, let material = library.material(named: "ground") {
            let across = Float((Self.groundWidth / Self.groundRepeat).rounded())
            setMaps(material, ground, scaleX: across, scaleY: Float(Self.tileLength / Self.groundRepeat))
            material.diffuse.contents = ground.albedo
        }
        if let ground, TexPhotos.shared.maps(.sidewalk) == nil, let material = library.material(named: "sidewalk") {
            material.normal.contents = ground.normal
            material.normal.intensity = 0.35
            WorldMaterials.repeating(material.normal, scaleX: 1, scaleY: Float(Self.tileLength / 4))
        }
        // The photo maps were decoded on the same background pass; put them on every other material.
        TexDress.dressAll(library)
    }

    private func setMaps(_ material: SCNMaterial, _ set: SurfaceSet, scaleX: Float, scaleY: Float) {
        material.diffuse.contents = set.albedo
        material.normal.contents = set.normal
        material.roughness.contents = set.roughness
        for property in [material.diffuse, material.normal, material.roughness] {
            WorldMaterials.repeating(property, scaleX: scaleX, scaleY: scaleY)
        }
    }

    // MARK: - Building a tile

    private func makeTile() -> SCNNode {
        let tile = SCNNode()
        tile.addChildNode(roadSurface())
        for side in [-1.0, 1.0] {
            tile.addChildNode(ground(side: side))
            for part in sidewalk(side: side) { tile.addChildNode(part) }
            tile.addChildNode(strip(x: side * Self.edgeLineX, width: 0.16, y: 0.012, material: edgeMaterial()))
        }
        for x in Self.laneLineX { addDashes(to: tile, x: x) }
        return library.flatten(tile)
    }

    /// A flat strip lying on the road from z 0 to -tileLength, split so it bends smoothly.
    private func strip(x: Double, width: Double, y: Double, material: SCNMaterial) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(Self.tileLength))
        plane.heightSegmentCount = Self.tileSegments
        plane.firstMaterial = material
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(Float(x), Float(y), Float(-Self.tileLength / 2))
        return node
    }

    private func roadSurface() -> SCNNode {
        let material = library.shared("road") {
            let road = WorldMaterials.pbr(UIColor(red: 0.3, green: 0.18, blue: 0.08, alpha: 1), roughness: 0.25)
            road.normal.intensity = 0.9
            return road
        }
        return strip(x: 0, width: Self.roadWidth, y: 0, material: material)
    }

    private func ground(side: Double) -> SCNNode {
        let material = library.shared("ground") {
            WorldMaterials.pbr(UIColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1), roughness: 0.6)
        }
        let center = Self.sidewalkInner + Self.sidewalkWidth + Self.groundWidth / 2
        let node = strip(x: side * center, width: Self.groundWidth, y: -0.02, material: material)
        if let plane = node.geometry as? SCNPlane { plane.widthSegmentCount = 4 }
        return node
    }

    private func sidewalk(side: Double) -> [SCNNode] {
        let concrete = library.shared("sidewalk") {
            WorldMaterials.pbr(UIColor(red: 0.2, green: 0.19, blue: 0.2, alpha: 1), roughness: 0.45)
        }
        let curbGlow = library.shared("curbGlow") { WorldMaterials.glow(UIColor(red: 1, green: 0.2, blue: 0.6, alpha: 1), boost: 0.9) }
        let rail = library.shared("rail") {
            WorldMaterials.pbr(UIColor(white: 0.55, alpha: 1), metalness: 0.55, roughness: 0.35)
        }
        let width = Self.sidewalkWidth
        let height = Self.sidewalkHeight
        let slab = box(width: width, height: height, material: concrete)
        slab.position = SCNVector3(Float(side * (Self.sidewalkInner + width / 2)), Float(height / 2), Float(-Self.tileLength / 2))
        let glow = box(width: 0.05, height: 0.07, material: curbGlow)
        glow.position = SCNVector3(Float(side * (Self.sidewalkInner - 0.02)), Float(height * 0.6), Float(-Self.tileLength / 2))
        let barrier = box(width: 0.12, height: 0.45, material: rail)
        barrier.position = SCNVector3(Float(side * (Self.sidewalkInner + width - 0.2)), Float(height + 0.5), Float(-Self.tileLength / 2))
        return [slab, glow, barrier]
    }

    private func box(width: Double, height: Double, material: SCNMaterial) -> SCNNode {
        let shape = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(Self.tileLength), chamferRadius: 0)
        shape.lengthSegmentCount = Self.tileSegments
        shape.firstMaterial = material
        return SCNNode(geometry: shape)
    }

    private func edgeMaterial() -> SCNMaterial {
        library.shared("edgeLine") { WorldMaterials.glow(UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1), boost: 0.5) }
    }

    private func addDashes(to tile: SCNNode, x: Double) {
        let material = library.shared("laneDash") {
            WorldMaterials.glow(UIColor(red: 1, green: 0.82, blue: 0.12, alpha: 1), boost: 1.1)
        }
        let count = Int(Self.tileLength / Self.dashSpacing)
        for index in 0..<count {
            let plane = SCNPlane(width: 0.16, height: CGFloat(Self.dashLength))
            plane.firstMaterial = material
            let dash = SCNNode(geometry: plane)
            dash.eulerAngles.x = -.pi / 2
            dash.position = SCNVector3(Float(x), 0.014, Float(-(Double(index) * Self.dashSpacing + Self.dashLength / 2 + 1)))
            tile.addChildNode(dash)
        }
    }
}
