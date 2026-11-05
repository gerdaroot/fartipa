import Foundation

/// Something to avoid, as the autopilot sees it. Times are seconds from now.
private struct RoadThreat {
    let start: Double
    let end: Double
    let x: Double
    let halfWidth: Double

    func blocks(_ position: Double) -> Bool {
        abs(x - position) < halfWidth
    }
}

/// A careful rider. It sees only what a player sees: stream markers once they appear, never
/// streams still hidden. Used by tests to prove the road is fair, and usable for an attract mode.
extension BikeRun {
    private static let horizonSeconds = 2.5
    private static let streamMargin = 0.2
    private static let vehicleMargin = 0.25
    private static let pileMargin = 0.2
    private static let crossingSeconds = 0.04
    private static let smallestClosing = 1.0
    private static let distancePenalty = 0.02
    private static let baitSeconds = 1.3
    private static let baitSpareSeconds = 0.25

    /// Where a careful rider would steer now: the lane that stays open longest, and toward
    /// coins and pickups when there is time for that.
    func autopilotTarget() -> Double {
        let threats = roadThreats()
        let lane = safestLane(threats)
        return baitX(threats, safeLane: lane) ?? lane
    }

    private func roadThreats() -> [RoadThreat] {
        streamThreats() + vehicleThreats() + pileThreats()
    }

    private func streamThreats() -> [RoadThreat] {
        var threats: [RoadThreat] = []
        let currentSpeed = max(1, speed)
        for stream in streams where stream.isVisible {
            let eta = (stream.z - distance) / currentSpeed
            guard eta >= 0, eta <= Self.horizonSeconds else { continue }
            threats.append(
                RoadThreat(
                    start: eta - Self.crossingSeconds, end: eta + Self.crossingSeconds,
                    x: stream.x(atTime: time + eta), halfWidth: Self.streamReach + Self.streamMargin
                )
            )
        }
        return threats
    }

    private func vehicleThreats() -> [RoadThreat] {
        var threats: [RoadThreat] = []
        let currentSpeed = speed
        for vehicle in vehicles where !vehicle.isWrecked && !vehicle.wasPassed {
            let closing = max(Self.smallestClosing, currentSpeed - vehicle.drivingSpeed)
            let start = (vehicle.z - vehicle.kind.halfLength - distance) / closing
            let end = (vehicle.z + vehicle.kind.halfLength - distance) / closing
            guard end >= 0, start <= Self.horizonSeconds else { continue }
            threats.append(
                RoadThreat(
                    start: max(0, start), end: end, x: vehicle.x,
                    halfWidth: vehicle.kind.halfWidth + Self.bikeHalfWidth + Self.vehicleMargin
                )
            )
        }
        return threats
    }

    private func pileThreats() -> [RoadThreat] {
        var threats: [RoadThreat] = []
        let currentSpeed = max(1, speed)
        for pile in piles {
            let eta = (pile.z - distance) / currentSpeed
            guard eta >= 0, eta <= Self.horizonSeconds else { continue }
            threats.append(
                RoadThreat(
                    start: eta - Self.crossingSeconds, end: eta + Self.crossingSeconds,
                    x: pile.x, halfWidth: Self.pileReach + Self.pileMargin
                )
            )
        }
        return threats
    }

    /// Seconds until a place on the road is blocked; the horizon when nothing is coming.
    private func clearSeconds(at position: Double, _ threats: [RoadThreat]) -> Double {
        var earliest = Self.horizonSeconds
        for threat in threats where threat.blocks(position) {
            earliest = min(earliest, threat.start)
        }
        return earliest
    }

    /// Whether the bike can slide straight from here to there without touching anything on the way.
    private func isPathClear(to position: Double, _ threats: [RoadThreat]) -> Bool {
        let gap = position - x
        let rate = loadout.steerRate
        let travel = abs(gap) / rate
        let sign = gap < 0 ? -1.0 : 1.0
        let startX = x
        let bikeAt: (Double) -> Double = { moment in
            startX + sign * min(abs(gap), rate * max(0, moment))
        }
        for threat in threats where threat.start <= travel {
            let last = min(threat.end, travel)
            if threat.blocks(bikeAt(threat.start)) || threat.blocks(bikeAt(last)) { return false }
        }
        return true
    }

    private func safestLane(_ threats: [RoadThreat]) -> Double {
        var best = x
        var bestScore = -Double.infinity
        for lane in Self.laneX where isPathClear(to: lane, threats) {
            let score = clearSeconds(at: lane, threats) - abs(lane - x) * Self.distancePenalty
            if score > bestScore {
                bestScore = score
                best = lane
            }
        }
        return best
    }

    /// The next coin or pickup worth a detour, if the bike can still make the safe lane after it.
    private func baitX(_ threats: [RoadThreat], safeLane: Double) -> Double? {
        let currentSpeed = max(1, speed)
        var bait: [(x: Double, z: Double)] = roadPickups.map { (x: $0.x, z: $0.z) }
        bait += roadCoins.map { (x: $0.x, z: $0.z) }
        var chosen: Double?
        var chosenEta = Self.baitSeconds
        for item in bait {
            let eta = (item.z - distance) / currentSpeed
            guard eta > 0, eta < chosenEta else { continue }
            if isWorthChasing(x: item.x, eta: eta, threats, safeLane: safeLane) {
                chosen = item.x
                chosenEta = eta
            }
        }
        return chosen
    }

    private func isWorthChasing(x bait: Double, eta: Double, _ threats: [RoadThreat], safeLane: Double) -> Bool {
        let rate = loadout.steerRate
        guard abs(bait - x) <= rate * eta else { return false }
        let back = abs(bait - safeLane) / rate
        let needed = eta + back + Self.baitSpareSeconds
        guard isPathClear(to: bait, threats) else { return false }
        let low = min(bait, safeLane)
        let high = max(bait, safeLane)
        for threat in threats where threat.start < needed && threat.end > 0 {
            if threat.x + threat.halfWidth > low, threat.x - threat.halfWidth < high { return false }
        }
        return true
    }
}
