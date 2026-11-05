import Foundation
import SceneKit
import UIKit

/// How much the GPU is asked to do. Picked at launch from the device, lowered at runtime when
/// frames run slow or the phone gets hot. Never raised automatically during a session.
enum RenderTier: Int, Comparable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: RenderTier, rhs: RenderTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// One step down, or nil at the bottom.
    var lower: RenderTier? { RenderTier(rawValue: rawValue - 1) }

    /// Short Russian name for the performance overlay.
    var title: String {
        switch self {
        case .low: return "низкий"
        case .medium: return "средний"
        case .high: return "высокий"
        }
    }

    /// A guess from the hardware: memory separates the generations well enough
    /// (3 GB: XR/XS and older, 4 GB: 11/12/13, 6 GB and up: Pro models and 14+).
    static func detect(_ info: ProcessInfo = .processInfo) -> RenderTier {
        let gibibytes = Double(info.physicalMemory) / 1_073_741_824
        var tier: RenderTier
        if gibibytes >= 5.2 {
            tier = .high
        } else if gibibytes >= 3.2 {
            tier = .medium
        } else {
            tier = .low
        }
        if info.activeProcessorCount < 6 { tier = .low }
        if info.isLowPowerModeEnabled { tier = tier.lower ?? .low }
        switch info.thermalState {
        case .serious, .critical: tier = .low
        default: break
        }
        return tier
    }
}

/// Everything a tier changes. Values are read once when the tier is applied.
/// The iPhone 11 (4 GB) lands on `.medium`; XR/XS and older on `.low`.
struct RenderSettings {
    /// Share of the screen's native scale the 3D view renders at (capped at 2x first).
    let scaleShare: CGFloat
    let multisampling: Bool
    let hdr: Bool
    let bloom: CGFloat
    let bloomRadius: CGFloat
    /// Vignette, saturation and contrast. Off means no colour post pass at all.
    let grading: Bool
    let shadows: Bool
    /// Multiplies every particle birth rate.
    let particleBudget: CGFloat
    let fogEnd: CGFloat
    let zFar: CGFloat
    /// How far ahead roadside decor is shown.
    let decorAhead: Double
    /// Pooled road objects further ahead than this are hidden instead of drawn into the fog.
    let objectsAhead: Float
    /// Streams further ahead than this skip their splash, ripples and drops.
    let detailAhead: Float
    /// Groove strips drawn behind the bike.
    let rutSegments: Int
    /// World materials use cheap Lambert shading instead of physically based shading.
    let cheapMaterials: Bool

    static let maxNativeScale: CGFloat = 2

    static func of(_ tier: RenderTier) -> RenderSettings {
        switch tier {
        case .high:
            return RenderSettings(
                scaleShare: 1, multisampling: true, hdr: true, bloom: 1.1, bloomRadius: 9, grading: true,
                shadows: true, particleBudget: 1, fogEnd: 300, zFar: 420, decorAhead: 310,
                objectsAhead: 230, detailAhead: 110, rutSegments: 30, cheapMaterials: false
            )
        case .medium:
            return RenderSettings(
                scaleShare: 0.75, multisampling: false, hdr: true, bloom: 0.8, bloomRadius: 5, grading: true,
                shadows: false, particleBudget: 0.6, fogEnd: 250, zFar: 330, decorAhead: 255,
                objectsAhead: 205, detailAhead: 75, rutSegments: 20, cheapMaterials: false
            )
        case .low:
            return RenderSettings(
                scaleShare: 0.5, multisampling: false, hdr: false, bloom: 0, bloomRadius: 4, grading: false,
                shadows: false, particleBudget: 0.35, fogEnd: 185, zFar: 240, decorAhead: 190,
                objectsAhead: 165, detailAhead: 50, rutSegments: 12, cheapMaterials: true
            )
        }
    }
}

/// Distances the pooled road objects read every frame, set when a tier is applied, plus a cheap
/// count of what was drawn for the performance overlay.
@MainActor
enum PoolCulling {
    /// Pooled items placed further ahead than this (scene z below its negative) are hidden.
    static var aheadLimit: Float = 230
    /// Streams nearer than this show their full splash detail.
    static var detailAhead: Float = 110
    /// Pooled items shown in the last finished frame, summed over every pool.
    private(set) static var shown = 0
    private static var counting = 0

    static func beginFrame() {
        shown = counting
        counting = 0
    }

    static func count(_ items: Int) {
        counting += items
    }
}

/// Swaps physically based world materials to Lambert on the low tier (no image-based lighting, far
/// fewer instructions per pixel) and back. Only materials with nothing but a geometry modifier are
/// touched, so no shader reads a property Lambert lacks. Changing the lighting model recompiles
/// shaders, so the world only calls this outside a live ride and warms the result up afterwards.
@MainActor
enum PerfMaterialThrift {
    private static var originals: [ObjectIdentifier: SCNMaterial.LightingModel] = [:]

    /// True while some materials are on the cheap model.
    static var isCheap: Bool { !originals.isEmpty }

    /// Returns true when any material changed.
    static func apply(cheap: Bool, to materials: [SCNMaterial]) -> Bool {
        var changed = false
        for material in materials {
            let id = ObjectIdentifier(material)
            if cheap {
                guard material.lightingModel == .physicallyBased, isPlain(material) else { continue }
                originals[id] = material.lightingModel
                material.lightingModel = .lambert
                changed = true
            } else if let original = originals.removeValue(forKey: id) {
                material.lightingModel = original
                changed = true
            }
        }
        return changed
    }

    private static func isPlain(_ material: SCNMaterial) -> Bool {
        guard let modifiers = material.shaderModifiers else { return true }
        for key in modifiers.keys where key != .geometry { return false }
        return true
    }
}

/// Watches frame times during live riding and says when to step down a tier.
/// Slow means the average frame over a window is clearly longer than a 60 fps frame,
/// or many frames in the window were long. Single hitches do not count.
struct SlowFrameMonitor {
    private static let windowSeconds = 2.0
    private static let slowAverage = 1.0 / 50
    private static let longFrame = 1.0 / 40
    private static let longShare = 0.25
    private static let settleSeconds = 4.0

    private var elapsed = 0.0
    private var frames = 0
    private var longFrames = 0
    private var settle = SlowFrameMonitor.settleSeconds

    /// Ignores a while after a tier change or a warm-up, while shaders and textures settle.
    mutating func restart() {
        elapsed = 0
        frames = 0
        longFrames = 0
        settle = Self.settleSeconds
    }

    /// Returns true once per window when the window was slow. `frameBudget` is the frame time
    /// the view is asked for (1/60 normally, 1/30 when the phone is hot), so a deliberate 30 fps
    /// cap does not read as slow.
    mutating func record(_ dt: Double, frameBudget: Double = 1.0 / 60) -> Bool {
        guard dt > 0 else { return false }
        if settle > 0 {
            settle -= dt
            return false
        }
        let scale = max(1, frameBudget * 60)
        elapsed += dt
        frames += 1
        if dt > Self.longFrame * scale { longFrames += 1 }
        guard elapsed >= Self.windowSeconds else { return false }
        let average = elapsed / Double(max(1, frames))
        let share = Double(longFrames) / Double(max(1, frames))
        elapsed = 0
        frames = 0
        longFrames = 0
        return average > Self.slowAverage * scale || share > Self.longShare
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
