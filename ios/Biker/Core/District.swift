import Foundation

/// How nasty the road generator is in a district.
struct DistrictDifficulty: Equatable {
    /// Scales the warning before a stream pours.
    let warningScale: Double
    /// Seconds of riding between obstacles at the speed there.
    let gapSeconds: Double
    /// Chance that a row covers two lanes instead of one.
    let twoLaneChance: Double
    /// Chance that a plain stream row sways.
    let swayChance: Double
    // Share of road segments of each kind. What is left over goes to plain stream rows.
    let emptyShare: Double
    let pileShare: Double
    let trafficShare: Double
    let sweepShare: Double
    let doubleRowShare: Double
    /// A ramp with parked traffic behind it.
    let rampShare: Double
    /// Geysers or a rolling lid.
    let manholeShare: Double
}

/// A stretch of the road ("район"). Graphics change colours by `index`.
struct District: Equatable {
    let index: Int
    let name: String
    let startDistance: Double
    let difficulty: DistrictDifficulty

    static let all: [District] = [
        District(
            index: 0, name: "Говнотаун", startDistance: 0,
            difficulty: DistrictDifficulty(
                warningScale: 1, gapSeconds: 1.2, twoLaneChance: 0.15, swayChance: 0,
                emptyShare: 0.08, pileShare: 0.17, trafficShare: 0.15, sweepShare: 0, doubleRowShare: 0,
                rampShare: 0.05, manholeShare: 0
            )
        ),
        District(
            index: 1, name: "Канализация", startDistance: 1200,
            difficulty: DistrictDifficulty(
                warningScale: 0.95, gapSeconds: 1.1, twoLaneChance: 0.35, swayChance: 0.3,
                emptyShare: 0.08, pileShare: 0.18, trafficShare: 0.18, sweepShare: 0, doubleRowShare: 0,
                rampShare: 0.05, manholeShare: 0.05
            )
        ),
        District(
            index: 2, name: "Промзона", startDistance: 3500,
            difficulty: DistrictDifficulty(
                warningScale: 0.9, gapSeconds: 1, twoLaneChance: 0.45, swayChance: 0.35,
                emptyShare: 0.06, pileShare: 0.13, trafficShare: 0.22, sweepShare: 0.12, doubleRowShare: 0,
                rampShare: 0.05, manholeShare: 0.07
            )
        ),
        District(
            index: 3, name: "Золотой Сортир", startDistance: 7000,
            difficulty: DistrictDifficulty(
                warningScale: 0.85, gapSeconds: 0.92, twoLaneChance: 0.55, swayChance: 0.4,
                emptyShare: 0.05, pileShare: 0.1, trafficShare: 0.24, sweepShare: 0.15, doubleRowShare: 0.12,
                rampShare: 0.05, manholeShare: 0.07
            )
        ),
        District(
            index: 4, name: "Жопа Мира", startDistance: 12000,
            difficulty: DistrictDifficulty(
                warningScale: 0.8, gapSeconds: 0.85, twoLaneChance: 0.65, swayChance: 0.45,
                emptyShare: 0.04, pileShare: 0.08, trafficShare: 0.25, sweepShare: 0.17, doubleRowShare: 0.2,
                rampShare: 0.05, manholeShare: 0.08
            )
        ),
    ]

    /// The district at a point of the road. Anything before the start counts as the first one.
    static func at(distance: Double) -> District {
        all.last { distance >= $0.startDistance } ?? all[0]
    }
}
