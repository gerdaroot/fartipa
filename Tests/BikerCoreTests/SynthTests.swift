import XCTest
import Foundation
@testable import BikerCore

final class SynthTests: XCTestCase {
    private let rate = 44100.0

    func testEveryEffectIsAudibleAndBounded() {
        let effects: [[Float]] = [
            Synth.coin(sampleRate: rate), Synth.goldenCoin(sampleRate: rate), Synth.plop(sampleRate: rate),
            Synth.fanfare(sampleRate: rate), Synth.hit(sampleRate: rate), Synth.skid(sampleRate: rate),
            Synth.nearMiss(sampleRate: rate), Synth.pickup(sampleRate: rate), Synth.shieldBlocked(sampleRate: rate),
        ]
        for samples in effects {
            XCTAssertGreaterThan(samples.count, 1000)
            XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
            XCTAssertTrue(samples.contains { abs($0) > 0.01 })
        }
    }

    func testCoinSoundFadesOut() {
        let samples = Synth.coin(sampleRate: rate)
        XCTAssertLessThan(abs(samples[samples.count - 1]), 0.01)
    }

    func testSquelchIsBoundedAndSilentWhenOff() {
        var squelch = SquelchGenerator(sampleRate: rate)
        var buffer = [Float](repeating: 1, count: 4096)
        buffer.withUnsafeMutableBufferPointer { squelch.fill($0, gain: 0, frequency: 400) }
        XCTAssertTrue(buffer.allSatisfy { abs($0) < 0.0001 })
        buffer.withUnsafeMutableBufferPointer { squelch.fill($0, gain: 0.5, frequency: 400) }
        XCTAssertTrue(buffer.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }
}

final class SoundBagTests: XCTestCase {
    func testEmptyBagGivesNothing() {
        var bag = SoundBag(count: 0)
        XCTAssertNil(bag.next())
    }

    func testBagOfOneKeepsGivingIt() {
        var bag = SoundBag(count: 1)
        XCTAssertEqual(bag.next(), 0)
        XCTAssertEqual(bag.next(), 0)
    }

    func testNoSoundRepeatsUntilAllHavePlayed() {
        var bag = SoundBag(count: 5)
        for _ in 0..<50 {
            var round: [Int] = []
            for _ in 0..<5 {
                round.append(bag.next() ?? -1)
            }
            XCTAssertEqual(Set(round), Set(0..<5))
        }
    }

    func testRoundsDoNotJoinOnTheSameSound() {
        var bag = SoundBag(count: 3)
        var previous = bag.next()
        for _ in 0..<500 {
            let current = bag.next()
            XCTAssertNotEqual(current, previous)
            previous = current
        }
    }
}
