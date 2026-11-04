import Foundation

struct Point: Equatable {
    var x: Double
    var y: Double
}

/// A shape to trace. Coordinates live in a unit square so any screen size can show it.
struct Figure {
    let id: String
    let name: String
    let paths: [[Point]]

    func samples(step: Double = TraceScoring.sampleStep) -> [Point] {
        paths.flatMap { TraceScoring.densify($0, step: step) }
    }

    static let all: [Figure] = [
        Figure(id: "smile", name: "Улыбка", paths: [
            ellipse(0.5, 0.5, 0.44, 0.44),
            ellipse(0.5, 0.5, 0.27, 0.27, from: 0.2, to: .pi - 0.2, segments: 24),
            ellipse(0.35, 0.37, 0.04, 0.04, segments: 12),
            ellipse(0.65, 0.37, 0.04, 0.04, segments: 12),
        ]),
        Figure(id: "heart", name: "Сердечко", paths: [heart()]),
        Figure(id: "house", name: "Домик", paths: [
            polyline([(0.14, 0.92), (0.14, 0.44), (0.5, 0.08), (0.86, 0.44), (0.86, 0.92), (0.14, 0.92)]),
            polyline([(0.4, 0.92), (0.4, 0.62), (0.6, 0.62), (0.6, 0.92)]),
        ]),
        Figure(id: "star", name: "Звезда", paths: [star()]),
        Figure(id: "fish", name: "Рыба", paths: [
            ellipse(0.42, 0.5, 0.36, 0.24),
            polyline([(0.76, 0.42), (0.96, 0.26), (0.96, 0.74), (0.76, 0.58)]),
            ellipse(0.24, 0.44, 0.035, 0.035, segments: 12),
        ]),
        Figure(id: "pile", name: "Сама куча", paths: [
            ellipse(0.5, 0.8, 0.42, 0.14),
            ellipse(0.5, 0.56, 0.3, 0.12),
            ellipse(0.5, 0.36, 0.18, 0.09),
            polyline([(0.42, 0.3), (0.5, 0.07), (0.58, 0.3)]),
        ]),
    ]

    private static func polyline(_ points: [(Double, Double)]) -> [Point] {
        points.map { Point(x: $0.0, y: $0.1) }
    }

    private static func ellipse(
        _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
        from: Double = 0, to: Double = 2 * .pi, segments: Int = 48
    ) -> [Point] {
        (0...segments).map { i in
            let t = from + (to - from) * Double(i) / Double(segments)
            return Point(x: cx + rx * cos(t), y: cy + ry * sin(t))
        }
    }

    private static func heart() -> [Point] {
        (0...72).map { i in
            let t = Double(i) / 72 * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return Point(x: 0.5 + x / 38, y: 0.46 - y / 38)
        }
    }

    private static func star() -> [Point] {
        (0...10).map { i in
            let r = i % 2 == 0 ? 0.46 : 0.19
            let t = -Double.pi / 2 + Double(i) * .pi / 5
            return Point(x: 0.5 + r * cos(t), y: 0.53 + r * sin(t))
        }
    }
}
