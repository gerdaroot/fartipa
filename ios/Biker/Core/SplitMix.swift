import Foundation

/// Small seeded generator, so a run can be replayed exactly in tests.
struct SplitMix: Equatable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }

    /// A number in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// A whole number in 0..<limit. `limit` must be positive.
    mutating func int(below limit: Int) -> Int {
        Int(next() % UInt64(limit))
    }

    /// True with the given probability.
    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }
}
