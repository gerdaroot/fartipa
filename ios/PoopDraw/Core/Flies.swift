import Foundation

struct Fly {
    var x: Double
    var y: Double
    var heading: Double
    var airborne: Double
    var pause: Double
}

/// Flies crawl over the pile, stop to rest, and scatter when a finger comes close.
struct FlySwarm {
    private(set) var flies: [Fly]
    private let width: Double
    private let height: Double
    private static let scareDistance = 56.0

    init(flies: [Fly], width: Double, height: Double) {
        self.flies = flies
        self.width = width
        self.height = height
    }

    init(count: Int, width: Double, height: Double) {
        let spawned = (0..<count).map { _ in
            Fly(
                x: Double.random(in: 0..<width),
                y: Double.random(in: 0..<height),
                heading: Double.random(in: 0..<(2 * .pi)),
                airborne: 0,
                pause: Double.random(in: 0..<2)
            )
        }
        self.init(flies: spawned, width: width, height: height)
    }

    mutating func update(dt: Double) {
        flies = flies.map { step($0, dt: dt) }
    }

    mutating func scare(x: Double, y: Double) {
        flies = flies.map { fly in
            guard hypot(fly.x - x, fly.y - y) <= Self.scareDistance else { return fly }
            var scared = fly
            scared.airborne = Double.random(in: 0.5...1.2)
            scared.heading = atan2(fly.y - y, fly.x - x)
            scared.pause = 0
            return scared
        }
    }

    private func step(_ fly: Fly, dt: Double) -> Fly {
        let wasAirborne = fly.airborne > 0
        let airborne = max(0, fly.airborne - dt)
        let pause = wasAirborne ? fly.pause : fly.pause - dt
        let resting = airborne == 0 && pause > 0
        let speed = airborne > 0 ? 340.0 : 34.0
        let wander = airborne > 0 ? 9.0 : 3.5
        var next = fly
        next.airborne = airborne
        next.heading = fly.heading + Double.random(in: -0.5...0.5) * wander * dt
        next.pause = pause <= -1.4 - Double.random(in: 0..<3) ? Double.random(in: 0.4..<2.8) : pause
        if !resting {
            next.x = wrap(fly.x + cos(next.heading) * speed * dt, limit: width)
            next.y = wrap(fly.y + sin(next.heading) * speed * dt, limit: height)
        }
        return next
    }

    private func wrap(_ value: Double, limit: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: limit)
        let positive = wrapped < 0 ? wrapped + limit : wrapped
        return positive >= limit ? 0 : positive
    }
}
