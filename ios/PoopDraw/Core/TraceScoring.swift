import Foundation

struct TraceResult: Equatable {
    let coverage: Double
    let accuracy: Double
    let score: Int
    let stars: Int
}

enum TraceScoring {
    static let tolerance = 0.05
    static let sampleStep = 0.02
    private static let accuracySlack = 1.5
    private static let starThresholds = [30, 55, 80]

    static let verdicts = [
        "Обосрался",
        "Говновато, но с душой",
        "Крепкий стул",
        "Мастер кисти и кучи",
    ]

    /// Resamples a polyline so neighbouring points are at most `step` apart.
    static func densify(_ points: [Point], step: Double) -> [Point] {
        guard var previous = points.first, points.count > 1 else { return points }
        var out = [previous]
        for next in points.dropFirst() {
            let length = hypot(next.x - previous.x, next.y - previous.y)
            let count = max(1, Int((length / step).rounded(.up)))
            for k in 1...count {
                let t = Double(k) / Double(count)
                out.append(Point(x: previous.x + (next.x - previous.x) * t, y: previous.y + (next.y - previous.y) * t))
            }
            previous = next
        }
        return out
    }

    private static func isNear(_ p: Point, _ points: [Point], _ tolerance2: Double) -> Bool {
        points.contains { q in
            let dx = p.x - q.x
            let dy = p.y - q.y
            return dx * dx + dy * dy <= tolerance2
        }
    }

    /// Returns `covered` with every target near any of `points` switched on.
    static func markCovered(targets: [Point], covered: [Bool], points: [Point], tolerance: Double) -> [Bool] {
        let tolerance2 = tolerance * tolerance
        return zip(targets, covered).map { target, done in done || isNear(target, points, tolerance2) }
    }

    static func stars(forScore score: Int) -> Int {
        starThresholds.filter { score >= $0 }.count
    }

    static func score(targets: [Point], strokes: [[Point]], tolerance: Double) -> TraceResult {
        let drawn = strokes.flatMap { densify($0, step: sampleStep) }
        guard !drawn.isEmpty, !targets.isEmpty else {
            return TraceResult(coverage: 0, accuracy: 0, score: 0, stars: 0)
        }
        let blank = [Bool](repeating: false, count: targets.count)
        let covered = markCovered(targets: targets, covered: blank, points: drawn, tolerance: tolerance)
        let coverage = Double(covered.filter { $0 }.count) / Double(targets.count)
        let slack = tolerance * accuracySlack
        let accurate = drawn.filter { isNear($0, targets, slack * slack) }.count
        let accuracy = Double(accurate) / Double(drawn.count)
        let score = Int((coverage * accuracy * 100).rounded())
        return TraceResult(coverage: coverage, accuracy: accuracy, score: score, stars: stars(forScore: score))
    }
}

/// Best stars per level. Stored as JSON; anything unknown or malformed is dropped on read.
enum Progress {
    static func mergeBest(_ progress: [String: Int], id: String, stars: Int) -> [String: Int] {
        var merged = progress
        merged[id] = max(progress[id] ?? 0, stars)
        return merged
    }

    static func isUnlocked(_ progress: [String: Int], index: Int) -> Bool {
        index == 0 || (progress[Figure.all[index - 1].id] ?? 0) >= 1
    }

    static func parse(_ data: Data?) -> [String: Int] {
        guard
            let data,
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else { return [:] }
        let known = Set(Figure.all.map(\.id))
        var result: [String: Int] = [:]
        for (id, value) in dictionary {
            if known.contains(id), let stars = value as? Int, (0...3).contains(stars) {
                result[id] = stars
            }
        }
        return result
    }

    static func encode(_ progress: [String: Int]) -> Data {
        (try? JSONSerialization.data(withJSONObject: progress)) ?? Data()
    }
}
