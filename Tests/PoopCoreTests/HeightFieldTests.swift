import XCTest
import Foundation
@testable import PoopCore

final class HeightFieldTests: XCTestCase {
    private func makeField(seed: UInt32 = 7) -> HeightField {
        HeightField(widthPoints: 120, heightPoints: 160, scale: 2, seed: seed)
    }

    func testSizeFollowsScale() {
        let f = makeField()
        XCTAssertEqual(f.width, 240)
        XCTAssertEqual(f.height, 320)
    }

    func testSameSeedGivesSamePicture() {
        let a = makeField(); _ = a.flush()
        let b = makeField(); _ = b.flush()
        XCTAssertEqual(a.rgba(in: a.fullRect), b.rgba(in: b.fullRect))
    }

    func testDifferentSeedGivesDifferentPicture() {
        let a = makeField(seed: 1); _ = a.flush()
        let b = makeField(seed: 2); _ = b.flush()
        XCTAssertNotEqual(a.rgba(in: a.fullRect), b.rgba(in: b.fullRect))
    }

    func testCarvingLowersHeightUnderFinger() {
        let f = makeField()
        let before = f.heightAt(xPoints: 60, yPoints: 80)
        f.carve(fromX: 40, fromY: 80, toX: 80, toY: 80, radius: 12)
        XCTAssertLessThan(f.heightAt(xPoints: 60, yPoints: 80), before - 5)
    }

    func testCarvingTwiceDoesNotDigDeeper() {
        let f = makeField()
        f.carve(fromX: 40, fromY: 80, toX: 80, toY: 80, radius: 12)
        let once = f.heightAt(xPoints: 60, yPoints: 80)
        f.carve(fromX: 40, fromY: 80, toX: 80, toY: 80, radius: 12)
        XCTAssertEqual(f.heightAt(xPoints: 60, yPoints: 80), once, accuracy: 0.001)
    }

    func testRimOfNewStrokeDoesNotFillOldGroove() {
        let f = makeField()
        f.carve(fromX: 20, fromY: 80, toX: 100, toY: 80, radius: 8)
        let groove = f.heightAt(xPoints: 60, yPoints: 80)
        f.carve(fromX: 20, fromY: 90, toX: 100, toY: 90, radius: 6)
        XCTAssertLessThanOrEqual(f.heightAt(xPoints: 60, yPoints: 80), groove + 0.001)
    }

    func testSmoothingRestoresSurface() {
        let f = makeField()
        let original = f.heightAt(xPoints: 60, yPoints: 80)
        f.carve(fromX: 40, fromY: 80, toX: 80, toY: 80, radius: 12)
        for _ in 0..<40 { f.smooth(x: 60, y: 80, radius: 30) }
        XCTAssertEqual(f.heightAt(xPoints: 60, yPoints: 80), original, accuracy: 0.05)
    }

    func testResetRestoresEverything() {
        let f = makeField(); _ = f.flush()
        let clean = f.rgba(in: f.fullRect)
        f.carve(fromX: 10, fromY: 10, toX: 100, toY: 150, radius: 20)
        _ = f.flush()
        XCTAssertNotEqual(f.rgba(in: f.fullRect), clean)
        f.resetCarving(); _ = f.flush()
        XCTAssertEqual(f.rgba(in: f.fullRect), clean)
    }

    func testCarvingOffscreenDoesNotCrash() {
        let f = makeField()
        f.carve(fromX: -500, fromY: -500, toX: 900, toY: 900, radius: 30)
        f.smooth(x: -100, y: 9000, radius: 30)
        XCTAssertFalse(f.flush().isEmpty)
    }

    func testFlushReportsOnlyWhatChanged() {
        let f = makeField(); _ = f.flush()
        XCTAssertTrue(f.flush().isEmpty)
        f.carve(fromX: 20, fromY: 20, toX: 24, toY: 20, radius: 5)
        let rects = f.flush()
        XCTAssertEqual(rects.count, 1)
        XCTAssertLessThan(rects[0].maxX, f.width / 2)
    }

    func testTitleMaskPressesAndGilds() {
        let f = makeField(); _ = f.flush()
        var mask = [UInt8](repeating: 0, count: f.width * f.height)
        for y in 140..<180 { for x in 80..<160 { mask[x + y * f.width] = 255 } }
        let before = f.heightAt(xPoints: 60, yPoints: 80)
        f.applyTitle(mask: mask)
        XCTAssertLessThan(f.heightAt(xPoints: 60, yPoints: 80), before - 5)
        _ = f.flush()
        let i = (120 + 160 * f.width) * 4
        let bytes = [UInt8](f.rgba(in: f.fullRect))
        XCTAssertGreaterThan(bytes[i], bytes[i + 2], "gold has more red than blue")
    }

    func testRgbaSubRectHasExpectedSizeAndOpaqueAlpha() {
        let f = makeField(); _ = f.flush()
        let data = [UInt8](f.rgba(in: PixelRect(minX: 10, minY: 20, maxX: 30, maxY: 25)))
        XCTAssertEqual(data.count, 20 * 5 * 4)
        XCTAssertTrue(stride(from: 3, to: data.count, by: 4).allSatisfy { data[$0] == 255 })
    }
}

final class FlyTests: XCTestCase {
    func testFliesStayOnBoard() {
        var swarm = FlySwarm(count: 5, width: 300, height: 500)
        for _ in 0..<2000 { swarm.update(dt: 0.05) }
        for fly in swarm.flies {
            XCTAssertTrue((0..<300).contains(fly.x) && (0..<500).contains(fly.y), "\(fly)")
        }
    }

    func testFingerScaresNearbyFlyOnly() {
        var swarm = FlySwarm(flies: [
            Fly(x: 100, y: 100, heading: 0, airborne: 0, pause: 1),
            Fly(x: 280, y: 480, heading: 0, airborne: 0, pause: 1),
        ], width: 300, height: 500)
        swarm.scare(x: 110, y: 100)
        XCTAssertGreaterThan(swarm.flies[0].airborne, 0)
        XCTAssertEqual(swarm.flies[1].airborne, 0)
    }
}

final class SynthTests: XCTestCase {
    func testSquelchSilentAtZeroGainAndBoundedWhenLoud() {
        var gen = SquelchGenerator(sampleRate: 44100)
        var buf = [Float](repeating: 1, count: 4096)
        buf.withUnsafeMutableBufferPointer { gen.fill($0, gain: 0, frequency: 400) }
        XCTAssertTrue(buf.allSatisfy { abs($0) < 0.0001 })
        buf.withUnsafeMutableBufferPointer { gen.fill($0, gain: 0.34, frequency: 800) }
        XCTAssertTrue(buf.allSatisfy { $0.isFinite && abs($0) <= 1 })
        XCTAssertTrue(buf.contains { abs($0) > 0.005 })
    }

    func testTonesHaveSoundAndFadeOut() {
        for samples in [Synth.plop(sampleRate: 44100), Synth.fanfare(sampleRate: 44100)] {
            XCTAssertGreaterThan(samples.count, 1000)
            XCTAssertTrue(samples.allSatisfy { abs($0) <= 1 })
            XCTAssertTrue(samples.contains { abs($0) > 0.05 })
            XCTAssertLessThan(abs(samples.last!), 0.01)
        }
    }

    func testRandomPickNeverRepeatsImmediately() {
        var last: Int? = nil
        for _ in 0..<500 {
            let next = SoundPick.next(count: 6, avoiding: last)
            XCTAssertTrue((0..<6).contains(next))
            XCTAssertNotEqual(next, last)
            last = next
        }
        XCTAssertEqual(SoundPick.next(count: 1, avoiding: 0), 0)
    }
}
