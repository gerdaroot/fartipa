import Foundation

/// What each ride event sounds, buzzes and pops up like. Called from the frame loop only when
/// events happened, so nothing here runs on quiet frames.
extension BikeGame {
    func handle(_ event: BikeEvent, run current: BikeRun, now time: Double) {
        switch event {
        case .coin:
            sound.play(.coin)
            haptics.coin(now: time, golden: false)
        case .goldenCoin:
            sound.play(.goldenCoin)
            haptics.coin(now: time, golden: true)
            feed.pop("+\(RoadCoin.goldenValue) ЗОЛОТОЙ!", tone: .gold, now: time)
        case .hit:
            sound.play(.hit) // the hit sound is a real fart recording already
            haptics.hit()
            feed.flashHit()
            feed.pop(current.lives > 0 ? "ОБОССАН!" : "ВСЁ, ПРИЕХАЛ", tone: .bad, now: time)
        case .skid:
            sound.play(.skid)
            haptics.bump()
            feed.pop("ЗАНОС НА КУЧЕ!", tone: .bad, now: time)
        case .nearMiss:
            sound.play(.nearMiss)
            haptics.tick()
            let combo = current.combo > 1 ? " ×\(current.combo)" : ""
            feed.pop("НА ВОЛОСКЕ!\(combo)", tone: .good, now: time)
        case .pickup(let kind):
            sound.play(kind == .shield ? .shield : .pickup)
            haptics.bump()
            feed.pop(kind.title.uppercased(), tone: .gold, now: time)
        case .boostStart:
            sound.play(.boostStart)
            haptics.hit()
            world.setCamera(.boost)
        case .boostEnd:
            world.setCamera(.chase)
        case .shieldBlocked:
            sound.play(.shield)
            haptics.bump()
            feed.pop("ЛОПУХ СПАС!", tone: .good, now: time)
        case .vehicleSmashed:
            sound.play(.vehicleSmash)
            haptics.smash()
            feed.pop("ТАРАН! +\(BikeRun.smashScore)", tone: .gold, now: time)
        case .districtEntered(let index):
            guard District.all.indices.contains(index) else { return }
            sound.play(.district)
            feed.pop(District.all[index].name.uppercased(), tone: .district, now: time)
        case .gameOver:
            endRide()
        }
    }
}
