import SceneKit
import UIKit

enum BikeCamera {
    case chase
    case showcase
}

/// The 3D scene. Things stay near the camera and the road slides past, so nothing can scroll the wrong way.
@MainActor
final class BikeWorld {
    let view = SCNView(frame: .zero)

    private static let tileLength = 40.0
    private static let tileCount = 8
    private static let sceneryLoop = 320.0
    private static let streamPool = 24
    private static let coinPool = 60
    private static let rutCount = 22
    private static let visibleAhead = 210.0
    private static let fog = UIColor(red: 0.34, green: 0.17, blue: 0.13, alpha: 1)

    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let cameraFocus = SCNNode()
    private let bikeHolder = SCNNode()
    private let roadMaterial = BikeModels.material(UIColor(red: 0.4, green: 0.25, blue: 0.12, alpha: 1), shine: 0.15)
    private let groundMaterial = BikeModels.material(UIColor(red: 0.2, green: 0.12, blue: 0.06, alpha: 1), shine: 0.05)
    private let posterMaterial = BikeModels.material(.white, shine: 0)
    private var rig: BikeRig?
    private var builtBike = ""
    private var builtRider = ""
    private var roadTiles: [SCNNode] = []
    private var groundTiles: [SCNNode] = []
    private var scenery: [(node: SCNNode, offset: Double, x: Double)] = []
    private var streams: [SCNNode] = []
    private var coins: [SCNNode] = []
    private var ruts: [SCNNode] = []
    private var rutHistory: [(distance: Double, x: Double)] = []
    private var cameraKind = BikeCamera.chase

    init() {
        view.scene = scene
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling2X
        view.backgroundColor = BikeWorld.fog
        scene.background.contents = BikeTextures.sky()
        scene.fogColor = BikeWorld.fog
        scene.fogStartDistance = 60
        scene.fogEndDistance = 200
        buildLights()
        buildCamera()
        buildRoad()
        buildScenery()
        buildPools()
        scene.rootNode.addChildNode(bikeHolder)
        posterMaterial.diffuse.contents = BikeTextures.defaultPoster()
        loadRoadTexture()
    }

    // MARK: - Setup

    private func buildLights() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.58, green: 0.5, blue: 0.5, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(red: 1, green: 0.84, blue: 0.62, alpha: 1)
        sun.intensity = 950
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.85, 0.5, 0)
        scene.rootNode.addChildNode(sunNode)
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 62
        camera.zFar = 400
        camera.zNear = 0.2
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 3.3, 6.2)
        let lookAt = SCNLookAtConstraint(target: cameraFocus)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        cameraFocus.position = SCNVector3(0, 1, -9)
        scene.rootNode.addChildNode(cameraFocus)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func buildRoad() {
        for _ in 0..<Self.tileCount {
            roadTiles.append(addTile(width: BikeRun.roadHalfWidth * 2, y: 0, material: roadMaterial))
            groundTiles.append(addTile(width: 120, y: -0.15, material: groundMaterial))
        }
    }

    private func addTile(width: Double, y: Float, material: SCNMaterial) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(Self.tileLength))
        plane.firstMaterial = material
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        node.position.y = y
        scene.rootNode.addChildNode(node)
        return node
    }

    private func loadRoadTexture() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tile = BikeTextures.roadTile(seed: 42)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.applyRoad(tile)
                }
            }
        }
    }

    private func applyRoad(_ tile: UIImage?) {
        guard let tile else { return }
        for material in [roadMaterial, groundMaterial] {
            material.diffuse.contents = tile
            material.diffuse.mipFilter = .linear
            material.diffuse.maxAnisotropy = 8
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
        }
        roadMaterial.diffuse.intensity = 1
        groundMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(6, 1, 1)
        groundMaterial.multiply.contents = UIColor(white: 0.5, alpha: 1)
    }

    private func buildScenery() {
        var random = SplitMix(seed: 2024)
        for index in 0..<16 {
            let side = index % 2 == 0 ? -1.0 : 1.0
            addScenery(makePile(random.unit()), offset: Double(index) * 20, x: side * (5.2 + random.unit() * 4))
        }
        for index in 0..<4 {
            let side = index % 2 == 0 ? -1.0 : 1.0
            addScenery(makeBillboard(side: side), offset: 35 + Double(index) * 80, x: side * 7.4)
        }
        for index in 0..<14 {
            let side = index % 2 == 0 ? -1.0 : 1.0
            let height = 16 + random.unit() * 26
            addScenery(makeBuilding(height: height, seed: index), offset: Double(index) * 23, x: side * (19 + random.unit() * 14))
        }
    }

    private func addScenery(_ node: SCNNode, offset: Double, x: Double) {
        scene.rootNode.addChildNode(node)
        scenery.append((node, offset, x))
    }

    private func makePile(_ variation: Double) -> SCNNode {
        let color = UIColor(red: 0.3 + variation * 0.1, green: 0.17 + variation * 0.06, blue: 0.07, alpha: 1)
        let pile = SCNNode()
        let tiers: [(CGFloat, Double)] = [(0.95, 0.42), (0.68, 1.05), (0.42, 1.55)]
        for (radius, y) in tiers {
            let tier = BikeModels.part(SCNSphere(radius: radius), color, y: y, z: 0, shine: 0.55)
            tier.scale = SCNVector3(1, 0.7, 1)
            pile.addChildNode(tier)
        }
        pile.addChildNode(BikeModels.part(SCNCone(topRadius: 0, bottomRadius: 0.24, height: 0.55), color, y: 2.05, z: 0, shine: 0.55))
        let size = Float(0.8 + variation * 0.9)
        pile.scale = SCNVector3(size, size, size)
        return pile
    }

    private func makeBillboard(side: Double) -> SCNNode {
        let board = SCNNode()
        board.addChildNode(BikeModels.part(SCNCylinder(radius: 0.14, height: 4), UIColor(white: 0.2, alpha: 1), y: 2, z: 0))
        board.addChildNode(BikeModels.part(SCNBox(width: 5.4, height: 5.4, length: 0.2, chamferRadius: 0.05), UIColor(white: 0.12, alpha: 1), y: 6.2, z: -0.13))
        let plane = SCNPlane(width: 5, height: 5)
        plane.firstMaterial = posterMaterial
        let poster = SCNNode(geometry: plane)
        poster.position = SCNVector3(0, 6.2, 0)
        board.addChildNode(poster)
        board.eulerAngles.y = Float(side > 0 ? -0.35 : 0.35)
        return board
    }

    private func makeBuilding(height: Double, seed: Int) -> SCNNode {
        let box = SCNBox(width: 11, height: CGFloat(height), length: 11, chamferRadius: 0)
        let material = BikeModels.material(.white, shine: 0)
        let windows = BikeTextures.building(seed: seed)
        material.diffuse.contents = windows
        material.emission.contents = windows
        box.firstMaterial = material
        let node = SCNNode(geometry: box)
        node.pivot = SCNMatrix4MakeTranslation(0, Float(-height / 2), 0)
        return node
    }

    private func buildPools() {
        for _ in 0..<Self.streamPool {
            let stream = makeStream()
            stream.isHidden = true
            scene.rootNode.addChildNode(stream)
            streams.append(stream)
        }
        let coinPicture = BikeTextures.coinImage
        for _ in 0..<Self.coinPool {
            let coin = makeCoin(picture: coinPicture)
            coin.isHidden = true
            scene.rootNode.addChildNode(coin)
            coins.append(coin)
        }
        for _ in 0..<Self.rutCount {
            let rut = makeRut()
            rut.isHidden = true
            scene.rootNode.addChildNode(rut)
            ruts.append(rut)
        }
    }

    private func makeStream() -> SCNNode {
        let yellow = UIColor(red: 1, green: 0.84, blue: 0.1, alpha: 1)
        let holder = SCNNode()
        let column = BikeModels.part(SCNCylinder(radius: 0.34, height: 70), yellow, y: 35, z: 0, shine: 1, glow: UIColor(red: 0.6, green: 0.46, blue: 0, alpha: 1))
        column.opacity = 0.82
        column.name = "column"
        holder.addChildNode(column)
        let puddle = BikeModels.part(SCNCylinder(radius: 1.35, height: 0.04), yellow, y: 0.04, z: 0, shine: 1, glow: UIColor(red: 0.42, green: 0.32, blue: 0, alpha: 1))
        puddle.opacity = 0.75
        holder.addChildNode(puddle)
        let splash = SCNParticleSystem()
        splash.birthRate = 70
        splash.particleLifeSpan = 0.45
        splash.particleSize = 0.09
        splash.particleColor = yellow
        splash.particleVelocity = 4
        splash.spreadingAngle = 70
        splash.emittingDirection = SCNVector3(0, 1, 0)
        splash.acceleration = SCNVector3(0, -11, 0)
        splash.isAffectedByGravity = false
        splash.loops = true
        let emitter = SCNNode()
        emitter.position = SCNVector3(0, 0.1, 0)
        emitter.addParticleSystem(splash)
        holder.addChildNode(emitter)
        return holder
    }

    private func makeCoin(picture: UIImage) -> SCNNode {
        let disc = SCNCylinder(radius: 0.58, height: 0.1)
        let edge = BikeModels.material(UIColor(red: 0.86, green: 0.6, blue: 0.14, alpha: 1), shine: 1)
        let face = BikeModels.material(.white, shine: 1, glow: UIColor(white: 0.25, alpha: 1))
        face.diffuse.contents = picture
        disc.materials = [edge, face, face]
        let shape = SCNNode(geometry: disc)
        shape.eulerAngles.x = .pi / 2
        let holder = SCNNode()
        holder.addChildNode(shape)
        return holder
    }

    /// The same groove a finger leaves in the drawing mode: dark floor with raised lit edges.
    private func makeRut() -> SCNNode {
        let rut = SCNNode()
        let floor = UIColor(red: 0.1, green: 0.05, blue: 0.02, alpha: 1)
        let rim = UIColor(red: 0.62, green: 0.4, blue: 0.2, alpha: 1)
        rut.addChildNode(BikeModels.part(SCNBox(width: 0.3, height: 0.01, length: 0.92, chamferRadius: 0), floor, y: 0.015, z: 0, shine: 0.8))
        rut.addChildNode(BikeModels.part(SCNBox(width: 0.07, height: 0.04, length: 0.92, chamferRadius: 0), rim, x: -0.19, y: 0.02, z: 0))
        rut.addChildNode(BikeModels.part(SCNBox(width: 0.07, height: 0.04, length: 0.92, chamferRadius: 0), rim, x: 0.19, y: 0.02, z: 0))
        return rut
    }

    // MARK: - Per frame

    func dressBike(bikeId: String, riderId: String) {
        guard bikeId != builtBike || riderId != builtRider else { return }
        builtBike = bikeId
        builtRider = riderId
        rig?.root.removeFromParentNode()
        let fresh = BikeModels.makeRig(bikeId: bikeId, riderId: riderId)
        bikeHolder.addChildNode(fresh.root)
        rig = fresh
    }

    func setPoster(_ image: UIImage) {
        posterMaterial.diffuse.contents = BikeTextures.posterFromDrawing(image)
    }

    func setCamera(_ kind: BikeCamera) {
        cameraKind = kind
    }

    /// Moves the world to match the ride. `blink` makes the bike flicker after a hit.
    func sync(
        distance: Double, x: Double, steerRate: Double, time: Double, speed: Double,
        streams runStreams: [PissStream], coins runCoins: [RoadCoin], blink: Bool
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        slideRoad(distance: distance)
        placeBike(x: x, steerRate: steerRate, distance: distance, blink: blink, time: time)
        placeStreams(runStreams, distance: distance, time: time)
        placeCoins(runCoins, distance: distance, time: time)
        placeRuts(distance: distance, x: x, speed: speed)
        moveCamera(x: x, time: time)
        SCNTransaction.commit()
        CATransaction.commit()
    }

    private func slideRoad(distance: Double) {
        let length = Self.tileLength
        let total = length * Double(Self.tileCount)
        for (index, tile) in roadTiles.enumerated() {
            let z = loopedZ(ahead: Double(index) * length - distance, loop: total, behind: 40)
            tile.position.z = Float(z)
            groundTiles[index].position.z = Float(z)
        }
        for item in scenery {
            let z = loopedZ(ahead: item.offset - distance, loop: Self.sceneryLoop, behind: 30)
            item.node.position = SCNVector3(Float(item.x), 0, Float(z))
        }
    }

    /// Scene z of something `ahead` metres up the road, wrapped so it always stays in view.
    private func loopedZ(ahead: Double, loop: Double, behind: Double) -> Double {
        let wrapped = (ahead + behind).truncatingRemainder(dividingBy: loop)
        let positive = wrapped < 0 ? wrapped + loop : wrapped
        return -(positive - behind)
    }

    private func placeBike(x: Double, steerRate: Double, distance: Double, blink: Bool, time: Double) {
        bikeHolder.position.x = Float(x)
        bikeHolder.eulerAngles.z = Float(-steerRate * 0.042)
        bikeHolder.eulerAngles.y = Float(-steerRate * 0.018)
        bikeHolder.opacity = blink && Int(time * 12) % 2 == 0 ? 0.3 : 1
        let turn = Float(-distance / 0.36)
        rig?.frontWheel.eulerAngles.x = turn
        rig?.rearWheel.eulerAngles.x = turn
    }

    private func placeStreams(_ list: [PissStream], distance: Double, time: Double) {
        let near = list.filter { $0.z - distance < Self.visibleAhead }
        for (index, node) in streams.enumerated() {
            guard index < near.count else {
                node.isHidden = true
                continue
            }
            let stream = near[index]
            node.isHidden = false
            node.position = SCNVector3(Float(stream.x(atTime: time)), 0, Float(distance - stream.z))
            let wobble = Float(1 + sin(time * 17 + stream.phase) * 0.14)
            node.childNodes.first?.scale = SCNVector3(wobble, 1, wobble)
        }
    }

    private func placeCoins(_ list: [RoadCoin], distance: Double, time: Double) {
        let near = list.filter { $0.z - distance < Self.visibleAhead }
        for (index, node) in coins.enumerated() {
            guard index < near.count else {
                node.isHidden = true
                continue
            }
            node.isHidden = false
            node.position = SCNVector3(Float(near[index].x), 1, Float(distance - near[index].z))
            node.eulerAngles.y = Float(time * 3.2)
        }
    }

    private func placeRuts(distance: Double, x: Double, speed: Double) {
        if let last = rutHistory.last, last.distance > distance { rutHistory.removeAll() }
        if rutHistory.last.map({ $0.distance < distance }) ?? true { rutHistory.append((distance, x)) }
        rutHistory.removeAll { $0.distance < distance - Double(Self.rutCount) - 3 }
        for (index, rut) in ruts.enumerated() {
            let back = 0.7 + Double(index) * 0.9
            guard speed > 0, let past = rutHistory.last(where: { $0.distance <= distance - back }) else {
                rut.isHidden = true
                continue
            }
            rut.isHidden = false
            rut.position = SCNVector3(Float(past.x), 0, Float(back))
        }
    }

    private func moveCamera(x: Double, time: Double) {
        switch cameraKind {
        case .chase:
            ease(cameraNode, to: SCNVector3(Float(x * 0.72), 3.3, 6.2))
            ease(cameraFocus, to: SCNVector3(Float(x * 0.5), 1, -9))
        case .showcase:
            ease(cameraNode, to: SCNVector3(Float(3.1 * cos(time * 0.35)), 1.5, Float(3.1 * sin(time * 0.35))))
            ease(cameraFocus, to: SCNVector3(0, 0.75, 0))
        }
    }

    private func ease(_ node: SCNNode, to target: SCNVector3) {
        let p = node.position
        node.position = SCNVector3(p.x + (target.x - p.x) * 0.12, p.y + (target.y - p.y) * 0.12, p.z + (target.z - p.z) * 0.12)
    }
}
