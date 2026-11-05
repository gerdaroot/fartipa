/// Deals indices like a shuffled deck: none comes back until all the others have played, and a new round
/// never starts with the index that ended the last one. Reshuffles in place, so dealing never allocates.
struct ShuffleDeck {
    private var order: [Int]
    private var position: Int

    init(count: Int) {
        order = Array(0..<max(0, count))
        position = order.count
    }

    mutating func next() -> Int? {
        guard !order.isEmpty else { return nil }
        if position >= order.count { reshuffle() }
        let pick = order[position]
        position += 1
        return pick
    }

    private mutating func reshuffle() {
        let count = order.count
        let previous = order[count - 1]
        order.shuffle()
        if count > 1, order[0] == previous {
            order.swapAt(0, count - 1)
        }
        position = 0
    }
}

/// Picks a random variant of each effect, never the same one twice in a row. Fixed storage, no allocation.
struct VariantPicker {
    private var last: [Int]

    init(effectCount: Int) {
        last = [Int](repeating: -1, count: max(0, effectCount))
    }

    mutating func next(effect: Int, variants: Int) -> Int? {
        guard variants > 0, last.indices.contains(effect) else { return nil }
        guard variants > 1 else { return 0 }
        let previous = last[effect]
        var pick: Int
        if previous >= 0 && previous < variants {
            pick = Int.random(in: 0..<(variants - 1))
            if pick >= previous { pick += 1 }
        } else {
            pick = Int.random(in: 0..<variants)
        }
        last[effect] = pick
        return pick
    }
}
