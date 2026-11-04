import XCTest
import Foundation
@testable import PoopCore

final class TraceScoringTests: XCTestCase {
    private let tol = TraceScoring.tolerance

    func testDensifySpacing() {
        let out = TraceScoring.densify([Point(x: 0, y: 0), Point(x: 1, y: 0)], step: 0.1)
        XCTAssertGreaterThanOrEqual(out.count, 11)
        for (a, b) in zip(out, out.dropFirst()) {
            XCTAssertLessThanOrEqual(hypot(b.x - a.x, b.y - a.y), 0.1 + 1e-9)
        }
    }

    func testDensifyKeepsSingleTap() {
        XCTAssertEqual(TraceScoring.densify([Point(x: 0.5, y: 0.5)], step: 0.1).count, 1)
    }

    func testFiguresStayInUnitSquare() {
        XCTAssertEqual(Figure.all.count, 6)
        for figure in Figure.all {
            for p in figure.samples() {
                XCTAssertTrue((0...1).contains(p.x) && (0...1).contains(p.y), "\(figure.id): \(p)")
            }
        }
    }

    func testPerfectTraceEarnsThreeStars() {
        for figure in Figure.all {
            let r = TraceScoring.score(targets: figure.samples(), strokes: figure.paths, tolerance: tol)
            XCTAssertEqual(r.stars, 3, figure.id)
            XCTAssertEqual(r.score, 100, figure.id)
        }
    }

    func testNoStrokesEarnNothing() {
        let r = TraceScoring.score(targets: Figure.all[0].samples(), strokes: [], tolerance: tol)
        XCTAssertEqual(r.score, 0)
        XCTAssertEqual(r.stars, 0)
    }

    func testScribbleDoesNotBeatTheGame() {
        let zigzag = (0...20).map { Point(x: Double($0 % 2), y: Double($0) / 20) }
        let heart = Figure.all.first { $0.id == "heart" }!
        let r = TraceScoring.score(targets: heart.samples(), strokes: [zigzag], tolerance: tol)
        XCTAssertLessThanOrEqual(r.stars, 1, "score \(r.score)")
    }

    func testHalfTraceCannotReachTwoStars() {
        let star = Figure.all.first { $0.id == "star" }!
        let half = Array(star.paths[0].prefix((star.paths[0].count + 1) / 2))
        let r = TraceScoring.score(targets: star.samples(), strokes: [half], tolerance: tol)
        XCTAssertLessThanOrEqual(r.stars, 1)
    }

    func testMarkCoveredOnlyMarksCloseTargets() {
        let targets = [Point(x: 0, y: 0), Point(x: 1, y: 1)]
        let after = TraceScoring.markCovered(
            targets: targets, covered: [false, false], points: [Point(x: 0.01, y: 0)], tolerance: tol
        )
        XCTAssertEqual(after, [true, false])
    }

    func testVerdictExistsForEveryStarCount() {
        XCTAssertEqual(TraceScoring.verdicts.count, 4)
    }
}

final class ProgressTests: XCTestCase {
    func testBestStarsAreKept() {
        XCTAssertEqual(Progress.mergeBest(["heart": 2], id: "heart", stars: 1), ["heart": 2])
        XCTAssertEqual(Progress.mergeBest(["heart": 2], id: "heart", stars: 3), ["heart": 3])
    }

    func testLevelsUnlockInOrder() {
        let first = Figure.all[0].id
        XCTAssertTrue(Progress.isUnlocked([:], index: 0))
        XCTAssertFalse(Progress.isUnlocked([:], index: 1))
        XCTAssertFalse(Progress.isUnlocked([first: 0], index: 1))
        XCTAssertTrue(Progress.isUnlocked([first: 1], index: 1))
        XCTAssertFalse(Progress.isUnlocked([first: 1], index: 2))
    }

    func testParseSurvivesGarbage() {
        XCTAssertEqual(Progress.parse(nil), [:])
        XCTAssertEqual(Progress.parse(Data("not json".utf8)), [:])
        XCTAssertEqual(Progress.parse(Data("[1,2]".utf8)), [:])
        let mixed = Data("{\"heart\":2,\"star\":99,\"fish\":\"x\",\"nope\":1}".utf8)
        XCTAssertEqual(Progress.parse(mixed), ["heart": 2])
    }

    func testEncodeRoundTrips() {
        XCTAssertEqual(Progress.parse(Progress.encode(["heart": 2, "star": 3])), ["heart": 2, "star": 3])
    }
}
