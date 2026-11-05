import SceneKit
import UIKit

/// Where loading stands.
enum PrepareState: Equatable {
    case idle
    case running
    case done
}

/// Loading: everything SceneKit would otherwise compile, build or upload on first use happens here,
/// behind the loading screen, so the first coin, stream, crash or boost of a ride does not stall.
extension BikeWorld {
    private static let warmSeconds: UInt64 = 450_000_000
    private static let stepPauseNanos: UInt64 = 2_000_000
    /// Shop bikes and riders built during loading, from the start of each list (the cheap ones).
    private static let loadingRigsPerList = 3
    /// Idle seconds between two lazily built shop rigs.
    private static let lazyRigSeconds = 1.0
    /// A frame slower than this postpones the next lazy build.
    private static let lazyRigFrameLimit = 1.0 / 45
    private static var warmSpot: SCNVector3 { SCNVector3(0, 1.2, -9) }

    /// Waits for the background textures, builds the bike templates of the shop, compiles every
    /// material, shader modifier and particle system with `SCNView.prepare`, then draws a few frames
    /// with every pooled object, power-up and burst on screen. `completion` runs on the main actor
    /// (once; later calls complete right away). Safe to call more than once.
    func prepare(completion: @escaping () -> Void) {
        prepareCallbacks.append(completion)
        switch prepareState {
        case .done:
            flushPrepareCallbacks()
            return
        case .running:
            return
        case .idle:
            prepareState = .running
        }
        whenAssetsReady { [weak self] in
            Task { @MainActor in await self?.runPreparation() }
        }
    }

    private func runPreparation() async {
        await prewarmRigs()
        city.prepareSigns()
        startWarming()
        view.prepare(warmupObjects(), completionHandler: { @Sendable [weak self] _ in
            Task { @MainActor in await self?.finishWarming() }
        })
    }

    /// Keeps everything on screen a moment longer so the first real draws happen while hidden.
    private func finishWarming() async {
        try? await Task.sleep(nanoseconds: Self.warmSeconds)
        stopWarming()
        prepareState = .done
        flushPrepareCallbacks()
    }

    /// Loading builds only the dressed bike and rider plus the first few of each shop list (about
    /// 60 rigs in all would take seconds). The rest wait in `lazyRigs` and are built one at a time
    /// on smooth idle frames in the hub and garage; a garage tap on one not built yet builds it then.
    private func prewarmRigs() async {
        let starter: (bike: BikeStyle, rider: RiderStyle)?
        if let bikeSkin = Catalog.bike(id: Catalog.starterBikeId), let riderSkin = Catalog.rider(id: Catalog.starterRiderId) {
            starter = (bikeSkin.style, riderSkin.style)
        } else {
            starter = nil
        }
        guard let dressed = bike.dressedStyles ?? starter else { return }
        var now: [(bike: BikeStyle, rider: RiderStyle)] = [dressed]
        var later: [(bike: BikeStyle, rider: RiderStyle)] = []
        for (index, skin) in Catalog.bikes.enumerated() {
            let pair = (bike: skin.style, rider: dressed.rider)
            if index < Self.loadingRigsPerList { now.append(pair) } else { later.append(pair) }
        }
        for (index, skin) in Catalog.riders.enumerated() {
            let pair = (bike: dressed.bike, rider: skin.style)
            if index < Self.loadingRigsPerList { now.append(pair) } else { later.append(pair) }
        }
        lazyRigs = later
        for pair in now {
            BikeModels.prewarm(bike: pair.bike, rider: pair.rider)
            try? await Task.sleep(nanoseconds: Self.stepPauseNanos)
        }
    }

    /// Builds one waiting shop rig when enough idle time has passed and the last frame was smooth,
    /// so it never lands on top of a hitch. When the list runs out, the new templates are compiled
    /// in the background.
    func buildLazyRig(dt: Double) {
        guard prepareState == .done, !lazyRigs.isEmpty else { return }
        lazyRigClock += max(0, dt)
        guard lazyRigClock >= Self.lazyRigSeconds, dt < Self.lazyRigFrameLimit else { return }
        lazyRigClock = 0
        let pair = lazyRigs.removeFirst()
        BikeModels.prewarm(bike: pair.bike, rider: pair.rider)
        if lazyRigs.isEmpty {
            view.prepare(RigTemplates.allTemplates as [Any], completionHandler: nil)
        }
    }

    private func warmupObjects() -> [Any] {
        var list: [Any] = [scene]
        list.append(contentsOf: library.allMaterials as [Any])
        list.append(contentsOf: RigTemplates.allTemplates as [Any])
        list.append(contentsOf: PissWarmup.objects)
        for image in skyImages {
            let holder = SCNMaterial()
            holder.lightingModel = .constant
            holder.diffuse.contents = image
            list.append(holder)
        }
        return list
    }

    private func startWarming() {
        objects.setWarming(true)
        bike.warming = true
        cameraRig.warming = true
        bursts.warmUp(at: Self.warmSpot)
    }

    private func stopWarming() {
        objects.setWarming(false)
        bike.warming = false
        cameraRig.warming = false
    }

    private func flushPrepareCallbacks() {
        let callbacks = prepareCallbacks
        prepareCallbacks.removeAll()
        for callback in callbacks { callback() }
    }
}
