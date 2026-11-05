import Foundation
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

    static let maxNativeScale: CGFloat = 2

    static func of(_ tier: RenderTier) -> RenderSettings {
        switch tier {
        case .high:
            return RenderSettings(
                scaleShare: 1, multisampling: true, hdr: true, bloom: 1.1, bloomRadius: 9, grading: true,
                shadows: true, particleBudget: 1, fogEnd: 300, zFar: 420, decorAhead: 310
            )
        case .medium:
            return RenderSettings(
                scaleShare: 0.8, multisampling: false, hdr: true, bloom: 0.9, bloomRadius: 6, grading: true,
                shadows: false, particleBudget: 0.75, fogEnd: 300, zFar: 420, decorAhead: 300
            )
        case .low:
            return RenderSettings(
                scaleShare: 0.65, multisampling: false, hdr: false, bloom: 0, bloomRadius: 4, grading: false,
                shadows: false, particleBudget: 0.5, fogEnd: 240, zFar: 330, decorAhead: 245
            )
        }
    }
}

/// Watches frame times during live riding and says when to step down a tier.
/// Slow means the average frame over a window is clearly longer than a 60 fps frame,
/// or many frames in the window were long. Single hitches do not count.
struct FrameMonitor {
    private static let windowSeconds = 2.0
    private static let slowAverage = 1.0 / 50
    private static let longFrame = 1.0 / 40
    private static let longShare = 0.25
    private static let settleSeconds = 4.0

    private var elapsed = 0.0
    private var frames = 0
    private var longFrames = 0
    private var settle = FrameMonitor.settleSeconds

    /// Ignores a while after a tier change or a warm-up, while shaders and textures settle.
    mutating func restart() {
        elapsed = 0
        frames = 0
        longFrames = 0
        settle = Self.settleSeconds
    }

    /// Returns true once per window when the window was slow.
    mutating func record(_ dt: Double) -> Bool {
        guard dt > 0 else { return false }
        if settle > 0 {
            settle -= dt
            return false
        }
        elapsed += dt
        frames += 1
        if dt > Self.longFrame { longFrames += 1 }
        guard elapsed >= Self.windowSeconds else { return false }
        let average = elapsed / Double(max(1, frames))
        let share = Double(longFrames) / Double(max(1, frames))
        elapsed = 0
        frames = 0
        longFrames = 0
        return average > Self.slowAverage || share > Self.longShare
    }
}
