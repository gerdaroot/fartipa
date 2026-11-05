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

    /// Every bike of the shop with the dressed rider, and every rider on the dressed bike,
    /// one per main-thread turn so the loading screen keeps animating.
    private func prewarmRigs() async {
        let starter: (bike: BikeStyle, rider: RiderStyle)?
        if let bikeSkin = Catalog.bike(id: Catalog.starterBikeId), let riderSkin = Catalog.rider(id: Catalog.starterRiderId) {
            starter = (bikeSkin.style, riderSkin.style)
        } else {
            starter = nil
        }
        guard let dressed = bike.dressedStyles ?? starter else { return }
        var pairs: [(bike: BikeStyle, rider: RiderStyle)] = [dressed]
        for skin in Catalog.bikes { pairs.append((skin.style, dressed.rider)) }
        for skin in Catalog.riders { pairs.append((dressed.bike, skin.style)) }
        for pair in pairs {
            BikeModels.prewarm(bike: pair.bike, rider: pair.rider)
            try? await Task.sleep(nanoseconds: Self.stepPauseNanos)
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
