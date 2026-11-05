import SceneKit
import UIKit

enum BikeCamera {
    case chase
    case showcase
    case boost
}

/// The 3D scene: a night neon city on a glossy poop highway. The bike stays at the origin facing -z
/// and the world slides past; the road ahead is bent on the GPU so it curves and climbs.
/// Parts live in `World/`: road, city, objects, bike effects, camera, lighting and textures.
@MainActor
final class BikeWorld {
    private static let idleSpeed = 15.0
    private static let lookAheadMetres = 30.0
    private static let lookAheadShare = 0.5
    private static let fogStart: CGFloat = 45
    private static let fogEnd: CGFloat = 300

    let view = SCNView(frame: .zero)
    private let scene: SCNScene
    private let library: MaterialLibrary
    private let lighting: WorldLighting
    private let road: RoadLayer
    private let city: CityLayer
    private let objects: ObjectsLayer
    private let bike: BikeEffects
    private let bursts: BurstPool
    private let cameraRig: CameraRig
    private var palette = PaletteBlender()
    private var skies: [Int: UIImage] = [:]
    private var idleDistance = 0.0
    private var clock = 0.0
    private var lastDistance = 0.0

    init() {
        let scene = SCNScene()
        let library = MaterialLibrary()
        self.scene = scene
        self.library = library
        let root = scene.rootNode
        lighting = WorldLighting(root: root)
        road = RoadLayer(root: root, library: library)
        city = CityLayer(parent: root, library: library)
        objects = ObjectsLayer(parent: root, library: library)
        bike = BikeEffects(parent: root, library: library, headlight: lighting.headlightNode)
        bursts = BurstPool(parent: root)
        cameraRig = CameraRig(root: root)
        configureView()
        applyPalette(WorldPalette.district(0), swapSky: true)
        loadSurfaces()
        prepareSkies()
    }

    private func configureView() {
        view.scene = scene
        view.pointOfView = cameraRig.cameraNode
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        scene.fogStartDistance = Self.fogStart
        scene.fogEndDistance = Self.fogEnd
        scene.fogDensityExponent = 1.3
        scene.lightingEnvironment.intensity = 1.3
    }

    // MARK: - Public API

    func dress(bike bikeStyle: BikeStyle, rider: RiderStyle, trail: TrailStyle) {
        bike.dress(bike: bikeStyle, rider: rider, trail: trail)
    }

    func setCamera(_ camera: BikeCamera) {
        cameraRig.setMode(camera)
    }

    /// Every frame during a ride, paused ride or game over. `isLive` false freezes motion effects.
    func render(_ run: BikeRun, dt: Double, isLive: Bool) {
        let distance = run.distance
        if distance + 1 < lastDistance {
            objects.releaseAll()
            bike.resetRuts()
        }
        lastDistance = distance
        let step = isLive ? dt : 0
        clock += step
        scene.isPaused = !isLive && !run.isOver
        var frame = BikeFrame()
        frame.x = run.x
        frame.distance = distance
        frame.speed = isLive ? run.speed : 0
        frame.rev = run.rev
        frame.boosting = run.isBoosting && isLive
        frame.blinking = isLive && run.invulnerable > 0
        frame.shield = run.powerUps.shield
        frame.magnet = run.powerUps.magnet
        frame.doubler = run.powerUps.doubler
        frame.skidding = isLive && run.isSkidding
        frame.crashed = run.isOver
        frame.live = isLive
        frame.clock = clock
        draw(frame, dt: dt, step: step, district: run.district.index) { bend in
            objects.update(run, bend: bend, clock: clock, dt: step, live: isLive)
        }
    }

    /// Hub and garage: the bike cruises an empty road.
    func renderIdle(dt: Double) {
        idleDistance += dt * Self.idleSpeed
        clock += dt
        scene.isPaused = false
        if lastDistance > 0 {
            objects.releaseAll()
            bike.resetRuts()
            lastDistance = 0
        }
        var frame = BikeFrame()
        frame.distance = idleDistance
        frame.speed = Self.idleSpeed
        frame.rev = 0
        frame.clock = clock
        draw(frame, dt: dt, step: dt, district: 0) { _ in }
    }

    /// One-shot effects for this frame's events.
    func react(to events: [BikeEvent], run: BikeRun) {
        let bikeAt = SCNVector3(Float(run.x), 1, 0)
        for event in events {
            WorldReactions.apply(event, at: bikeAt, exhaust: bike.exhaustPosition, bursts: bursts, camera: cameraRig)
        }
    }

    func setQuality(high: Bool) {
        cameraRig.configure(high: high)
        lighting.setShadows(high)
        view.antialiasingMode = high ? .multisampling4X : .none
        let budget: CGFloat = high ? 1 : 0.5
        bursts.budget = budget
        objects.budget = budget
        bike.budget = budget
        cameraRig.budget = budget
    }

    /// Extra: shows the player's picture on some roadside billboards.
    func setPoster(_ image: UIImage) {
        city.setPoster(BikeTextures.posterFromDrawing(image))
    }

    // MARK: - Frame

    private func draw(_ frame: BikeFrame, dt: Double, step: Double, district: Int, objectsUpdate: (BendAmount) -> Void) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        SCNTransaction.animationDuration = 0
        let bend = WorldBend.amount(atDistance: frame.distance)
        library.applyBend(bend)
        road.update(distance: frame.distance)
        city.update(distance: frame.distance, time: clock)
        objectsUpdate(bend)
        bike.update(frame, dt: step)
        lighting.follow(bikeX: frame.x)
        let look = bend.offset(ahead: Self.lookAheadMetres).x * Self.lookAheadShare
        cameraRig.update(bikeX: frame.x, rev: frame.rev, boosting: frame.boosting, lookAhead: look, dt: dt, clock: clock)
        updatePalette(district: district, dt: dt)
        SCNTransaction.commit()
    }

    // MARK: - Palette and sky

    private func updatePalette(district: Int, dt: Double) {
        let changed = palette.target(district)
        if let mixed = palette.advance(dt: dt) {
            applyPalette(mixed, swapSky: false)
        }
        if changed { showSky(for: district) }
    }

    private func applyPalette(_ value: WorldPalette, swapSky: Bool) {
        scene.fogColor = value.horizon.ui
        view.backgroundColor = value.horizon.ui
        lighting.apply(value)
        city.apply(value)
        if swapSky {
            let image = SkyTextures.sky(value, seed: 7)
            skies[0] = image
            scene.background.contents = image
            scene.lightingEnvironment.contents = image
        }
    }

    private func showSky(for district: Int) {
        guard let image = skies[district] else { return }
        scene.background.contents = image
        scene.lightingEnvironment.contents = image
    }

    /// The other districts' skies are painted in the background and swapped in when reached.
    private func prepareSkies() {
        let count = WorldPalette.districts.count
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var made: [Int: UIImage] = [:]
            for index in 1..<count {
                made[index] = SkyTextures.sky(WorldPalette.district(index), seed: 7 &+ UInt64(index))
            }
            let finished = made
            Task { @MainActor in
                guard let self else { return }
                for (index, image) in finished { self.skies[index] = image }
                if self.palette.targetIndex != 0 { self.showSky(for: self.palette.targetIndex) }
            }
        }
    }

    /// The poop maps take a moment to compute, so the road starts plain and gets them when ready.
    private func loadSurfaces() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let roadSet = SurfaceTextures.roadSurface(seed: 42)
            let groundSet = SurfaceTextures.groundSurface(seed: 1337)
            Task { @MainActor in
                self?.road.applySurfaces(road: roadSet, ground: groundSet)
                if let roadSet { self?.applyPileSurface(roadSet) }
            }
        }
    }

    private func applyPileSurface(_ set: SurfaceSet) {
        guard let pile = library.material(named: "pileBrown") else { return }
        pile.normal.contents = set.normal
        pile.normal.intensity = 0.7
        WorldMaterials.repeating(pile.normal, scaleX: 1, scaleY: 1)
    }
}
