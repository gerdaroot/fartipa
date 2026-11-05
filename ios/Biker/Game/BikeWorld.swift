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
/// Loading and warm-up live in `BikeWorld+Prepare.swift`; quality tiers in `World/RenderQuality.swift`.
@MainActor
final class BikeWorld {
    private static let idleSpeed = 15.0
    private static let lookAheadMetres = 30.0
    private static let lookAheadShare = 0.5
    private static let fogStart: CGFloat = 45
    private static let thermalCheckSeconds = 2.0
    private static let downgradeCooldown = 3.0

    let view: SCNView
    private let sceneView: BikeSceneView
    let scene: SCNScene
    let library: MaterialLibrary
    let lighting: WorldLighting
    let road: RoadLayer
    let city: CityLayer
    let objects: ObjectsLayer
    let bike: BikeEffects
    let bursts: BurstPool
    let cameraRig: CameraRig
    private var palette = PaletteBlender()
    private var skies: [Int: UIImage] = [:]
    private var idleDistance = 0.0
    private var clock = 0.0
    private var lastDistance = 0.0

    /// The tier the device was judged to manage at launch.
    let deviceTier: RenderTier
    /// The tier in use now.
    private(set) var tier: RenderTier
    /// When on, a run of slow frames while riding (or a hot phone) steps the tier down by itself.
    var autoQuality = true
    private var monitor = FrameMonitor()
    private var thermalClock = 0.0
    private var lastDowngrade = -Double.infinity

    // Loading state, driven by `prepare(completion:)`.
    var prepareState = PrepareState.idle
    var prepareCallbacks: [() -> Void] = []
    private var pendingAssets = 0
    private var assetWaiters: [() -> Void] = []

    init() {
        let scene = SCNScene()
        let library = MaterialLibrary()
        let made = BikeSceneView(frame: .zero)
        sceneView = made
        view = made
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
        deviceTier = RenderTier.detect()
        tier = deviceTier
        configureView()
        setFirstSky()
        applyPalette(WorldPalette.district(0))
        root.disableShadows()
        applyTier(deviceTier)
        loadSurfaces()
        prepareSkies()
        beginAsset()
        city.paintSigns { [weak self] in self?.endAsset() }
    }

    private func configureView() {
        view.scene = scene
        view.pointOfView = cameraRig.cameraNode
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.antialiasingMode = .none
        scene.fogStartDistance = Self.fogStart
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
        setPaused(!isLive && !run.isOver)
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
        if isLive { watchFrame(dt) }
    }

    /// Hub and garage: the bike cruises an empty road.
    func renderIdle(dt: Double) {
        idleDistance += dt * Self.idleSpeed
        clock += dt
        setPaused(false)
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

    /// `true` uses the tier picked for this device at launch, `false` the lowest tier.
    func setQuality(high: Bool) {
        applyTier(high ? deviceTier : .low)
    }

    /// Steps one tier down (at most once every few seconds). For the game loop when frames run slow.
    func reportSlowFrames() {
        let now = CACurrentMediaTime()
        guard now - lastDowngrade >= Self.downgradeCooldown, let lower = tier.lower else { return }
        lastDowngrade = now
        applyTier(lower)
    }

    /// Switches every quality setting at once: render scale, MSAA, HDR and bloom, colour grading,
    /// shadows, particle budgets, fog and draw distance.
    func applyTier(_ newTier: RenderTier) {
        tier = newTier
        let settings = RenderSettings.of(newTier)
        view.antialiasingMode = settings.multisampling ? .multisampling4X : .none
        sceneView.renderScale = settings.scaleShare
        cameraRig.configure(settings)
        lighting.setShadows(settings.shadows)
        scene.fogEndDistance = settings.fogEnd
        city.setDrawDistance(settings.decorAhead)
        let budget = settings.particleBudget
        bursts.budget = budget
        objects.budget = budget
        bike.budget = budget
        cameraRig.budget = budget
        monitor.restart()
    }

    /// Extra: shows the player's picture on some roadside billboards.
    func setPoster(_ image: UIImage) {
        city.setPoster(BikeTextures.posterFromDrawing(image))
    }

    // MARK: - Frame

    private func setPaused(_ paused: Bool) {
        if scene.isPaused != paused { scene.isPaused = paused }
    }

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

    /// Automatic quality: slow windows of live frames, or a hot phone, step the tier down.
    private func watchFrame(_ dt: Double) {
        guard autoQuality, prepareState != .running else { return }
        if monitor.record(dt) { reportSlowFrames() }
        thermalClock += dt
        guard thermalClock >= Self.thermalCheckSeconds else { return }
        thermalClock = 0
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical: reportSlowFrames()
        default: break
        }
    }

    // MARK: - Palette and sky

    /// The district colours fade in over a few seconds through fog, light and neon colours only.
    /// The reflection environment is set once at launch and never swapped (refiltering it stalls
    /// the GPU for hundreds of milliseconds); only the backdrop picture changes, and every district's
    /// backdrop is painted and uploaded during loading.
    private func updatePalette(district: Int, dt: Double) {
        let changed = palette.target(district)
        if let mixed = palette.advance(dt: dt) {
            applyPalette(mixed)
        }
        if changed { showSky(for: district) }
    }

    private func applyPalette(_ value: WorldPalette) {
        scene.fogColor = value.horizon.ui
        view.backgroundColor = value.horizon.ui
        lighting.apply(value)
        city.apply(value)
    }

    private func setFirstSky() {
        let image = SkyTextures.sky(WorldPalette.district(0), seed: 7)
        skies[0] = image
        scene.background.contents = image
        scene.lightingEnvironment.contents = SkyTextures.environment(from: image)
    }

    private func showSky(for district: Int) {
        guard let image = skies[district], scene.background.contents as? UIImage !== image else { return }
        scene.background.contents = image
    }

    /// Backdrops of every district, for uploading them during loading.
    var skyImages: [UIImage] { Array(skies.values) }

    /// The other districts' skies are painted in the background and swapped in when reached.
    private func prepareSkies() {
        let count = WorldPalette.districts.count
        beginAsset()
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
                self.endAsset()
            }
        }
    }

    /// The poop maps take a moment to compute, so the road starts plain and gets them when ready.
    private func loadSurfaces() {
        beginAsset()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let roadSet = SurfaceTextures.roadSurface(seed: 42)
            let groundSet = SurfaceTextures.groundSurface(seed: 1337)
            Task { @MainActor in
                guard let self else { return }
                self.road.applySurfaces(road: roadSet, ground: groundSet)
                if let roadSet { self.applyPileSurface(roadSet) }
                self.endAsset()
            }
        }
    }

    private func applyPileSurface(_ set: SurfaceSet) {
        guard let pile = library.material(named: "pileBrown") else { return }
        pile.normal.contents = set.normal
        pile.normal.intensity = 0.7
        WorldMaterials.repeating(pile.normal, scaleX: 1, scaleY: 1)
    }

    // MARK: - Background assets

    private func beginAsset() {
        pendingAssets += 1
    }

    private func endAsset() {
        pendingAssets = max(0, pendingAssets - 1)
        guard pendingAssets == 0 else { return }
        let waiting = assetWaiters
        assetWaiters.removeAll()
        for body in waiting { body() }
    }

    /// Runs `body` once every texture painted in the background is on its material.
    func whenAssetsReady(_ body: @escaping () -> Void) {
        if pendingAssets == 0 {
            body()
        } else {
            assetWaiters.append(body)
        }
    }
}

/// An `SCNView` that renders below the screen's native resolution when asked. On a 3x screen it
/// never goes above 2x; lower tiers use a share of that. Fewer pixels is the biggest GPU saving.
final class BikeSceneView: SCNView {
    /// Share of the (2x-capped) native scale to render at.
    var renderScale: CGFloat = 1 {
        didSet { applyScale() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyScale()
    }

    private func applyScale() {
        let native = window?.screen.scale ?? traitCollection.displayScale
        let capped = min(max(native, 1), RenderSettings.maxNativeScale)
        let wanted = max(1, (capped * renderScale * 4).rounded() / 4)
        if abs(contentScaleFactor - wanted) > 0.01 { contentScaleFactor = wanted }
    }
}
