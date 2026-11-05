import SwiftUI
import UIKit

enum GameScreen: Equatable {
    case menu
    case levels
    case free
    case trace
    case result
    case bike
}

/// Screens, scoring and saved progress. The board and the sound player do the work they are told to.
@MainActor
final class GameModel: ObservableObject {
    private enum Key {
        static let progress = "pd.progress"
        static let muted = "pd.muted"
    }

    private static let traceRadius: CGFloat = 9
    private static let hapticEveryPoints: CGFloat = 38
    private static let idleFartChance = 0.08

    @Published private(set) var screen: GameScreen = .menu
    @Published private(set) var isReady = false
    @Published private(set) var progress: [String: Int]
    @Published private(set) var levelIndex = 0
    @Published private(set) var percent = 0
    @Published private(set) var result: TraceResult?
    @Published private(set) var fingerRadius: CGFloat = 12
    @Published private(set) var isSmoothing = false
    @Published private(set) var isMuted: Bool
    @Published var sharedImage: ShareImage?
    @Published private(set) var starReward = 0

    let board = BoardView()
    let bike: BikeGame
    private let sound: SoundPlayer
    private let haptic = UIImpactFeedbackGenerator(style: .soft)
    private let defaults = UserDefaults.standard
    private var targets: [Point] = []
    private var covered: [Bool] = []
    private var strokes: [[Point]] = []
    private var activeStrokes: [ObjectIdentifier: [Point]] = [:]
    private var hapticDistance: CGFloat = 0
    private var hasNewDrawing = false

    var currentFigure: Figure { Figure.all[levelIndex] }
    var totalStars: Int { progress.values.reduce(0, +) }
    var maxStars: Int { Figure.all.count * 3 }
    var hasNextLevel: Bool { levelIndex + 1 < Figure.all.count }
    var canOpenNextLevel: Bool { hasNextLevel && Progress.isUnlocked(progress, index: levelIndex + 1) }

    init() {
        let muted = UserDefaults.standard.bool(forKey: Key.muted)
        isMuted = muted
        progress = Progress.parse(UserDefaults.standard.data(forKey: Key.progress))
        let player = SoundPlayer(muted: muted)
        sound = player
        bike = BikeGame(sound: player)
        wireBoard()
    }

    private func wireBoard() {
        board.onReady = { [weak self] in
            guard let self else { return }
            self.isReady = true
            #if DEBUG
            self.applyDemoArgument()
            #endif
        }
        board.onTouchBegan = { [weak self] in
            guard let self else { return }
            self.sound.ensureEngineRunning()
            self.sound.playPlop()
            self.haptic.impactOccurred(intensity: 0.6)
        }
        board.onMove = { [weak self] id, from, to in self?.fingerMoved(id: id, from: from, to: to) }
        board.onTouchEnded = { [weak self] id in self?.fingerLifted(id: id) }
        board.onSpeed = { [weak self] speed in self?.sound.setSquelch(speed: speed) }
    }

    // MARK: - Navigation

    func goToBike() {
        board.isPaused = true
        board.tool = .none
        bike.enter()
        screen = .bike
    }

    func leaveBike() {
        bike.leave()
        board.isPaused = false
        goToMenu()
    }

    func goToMenu() {
        shareNewDrawingWithBike()
        targets = []
        board.hideGuide()
        board.tool = .none
        board.showsTitle = true
        board.resetSurface()
        board.applyTitle()
        screen = .menu
    }

    func goToLevels() {
        screen = .levels
    }

    func startFreeDrawing() {
        targets = []
        board.hideGuide()
        board.showsTitle = false
        board.resetSurface()
        applyTool()
        screen = .free
    }

    func startLevel(_ index: Int) {
        levelIndex = index
        targets = Figure.all[index].samples()
        covered = [Bool](repeating: false, count: targets.count)
        strokes = []
        activeStrokes = [:]
        percent = 0
        board.showsTitle = false
        board.resetSurface()
        board.tool = .carve(radius: Self.traceRadius)
        refreshGuide()
        screen = .trace
    }

    func retryLevel() {
        startLevel(levelIndex)
    }

    func nextLevel() {
        if canOpenNextLevel { startLevel(levelIndex + 1) }
    }

    func finishLevel() {
        let figure = currentFigure
        let oldStars = progress[figure.id] ?? 0
        let allStrokes = strokes + Array(activeStrokes.values)
        let outcome = TraceScoring.score(targets: targets, strokes: allStrokes, tolerance: TraceScoring.tolerance)
        progress = Progress.mergeBest(progress, id: figure.id, stars: outcome.stars)
        defaults.set(Progress.encode(progress), forKey: Key.progress)
        result = outcome
        starReward = Shop.starReward(oldStars: oldStars, newStars: outcome.stars)
        bike.award(coins: starReward)
        hasNewDrawing = true
        shareNewDrawingWithBike()
        board.tool = .none
        if outcome.stars == 0 { sound.playNextFart() }
        if outcome.stars == 3 { sound.playFanfare() }
        haptic.impactOccurred()
        screen = .result
    }

    // MARK: - Tools

    func selectFinger(radius: CGFloat) {
        fingerRadius = radius
        isSmoothing = false
        applyTool()
    }

    func toggleSmoothing() {
        isSmoothing.toggle()
        applyTool()
    }

    private func applyTool() {
        board.tool = isSmoothing ? .smooth : .carve(radius: fingerRadius)
    }

    func newPile() {
        board.showsTitle = false
        board.buildPile()
        sound.playNextFart()
    }

    func fart() {
        sound.playNextFart()
        haptic.impactOccurred()
    }

    func toggleSound() {
        isMuted.toggle()
        sound.isMuted = isMuted
        defaults.set(isMuted, forKey: Key.muted)
    }

    func shareDrawing() {
        if let image = board.snapshot() {
            sharedImage = ShareImage(image: image)
        }
    }

    // MARK: - Finger

    private func fingerMoved(id: ObjectIdentifier, from: CGPoint, to: CGPoint) {
        hapticDistance += hypot(to.x - from.x, to.y - from.y)
        if hapticDistance >= Self.hapticEveryPoints {
            hapticDistance = 0
            haptic.impactOccurred(intensity: 0.4)
        }
        if screen == .free { hasNewDrawing = true }
        guard screen == .trace else { return }
        let start = unit(from)
        let end = unit(to)
        activeStrokes[id, default: []].append(end)
        let samples = TraceScoring.densify([start, end], step: TraceScoring.sampleStep)
        let updated = TraceScoring.markCovered(
            targets: targets, covered: covered, points: samples, tolerance: TraceScoring.tolerance
        )
        if updated != covered {
            covered = updated
            percent = Int((Double(covered.filter { $0 }.count) / Double(max(1, targets.count)) * 100).rounded())
            refreshGuide()
        }
    }

    private func fingerLifted(id: ObjectIdentifier) {
        if let stroke = activeStrokes.removeValue(forKey: id) {
            strokes.append(stroke)
        }
        if screen == .free, Double.random(in: 0..<1) < Self.idleFartChance {
            sound.playNextFart()
        }
    }

    /// The picture the player just made goes up on the billboards along the bike road.
    private func shareNewDrawingWithBike() {
        guard hasNewDrawing, let image = board.snapshot() else { return }
        hasNewDrawing = false
        bike.usePoster(image)
    }

    private func unit(_ point: CGPoint) -> Point {
        let box = board.figureBox
        return Point(x: Double((point.x - box.minX) / box.width), y: Double((point.y - box.minY) / box.height))
    }

    private func refreshGuide() {
        board.showGuide(targets: targets.map { screenPoint($0) }, covered: covered)
    }

    private func screenPoint(_ point: Point) -> CGPoint {
        let box = board.figureBox
        return CGPoint(x: box.minX + CGFloat(point.x) * box.width, y: box.minY + CGFloat(point.y) * box.height)
    }

    #if DEBUG
    /// Opens one screen with sample content so CI can photograph it: `--demo=levels`.
    private func applyDemoArgument() {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--demo=") }) else { return }
        sound.isMuted = true
        progress = ["smile": 3, "heart": 2, "house": 1]
        let demo = String(argument.dropFirst("--demo=".count))
        if demo.hasPrefix("bike") || demo == "garage" {
            goToBike()
            bike.applyDemo(demo)
            return
        }
        switch demo {
        case "levels":
            goToLevels()
        case "free":
            startFreeDrawing()
            let wave = (0..<36).map { CGPoint(x: 30 + CGFloat($0) * 9, y: 300 + sin(CGFloat($0) / 3) * 34) }
            board.carveDemoLine(wave, radius: fingerRadius)
        case "trace":
            demoTrace(pathCount: 2)
        case "result":
            demoTrace(pathCount: Figure.all[0].paths.count)
            finishLevel()
        default:
            break
        }
    }

    private func demoTrace(pathCount: Int) {
        startLevel(0)
        for path in currentFigure.paths.prefix(pathCount) {
            let points = path.map { screenPoint($0) }
            board.carveDemoLine(points, radius: Self.traceRadius)
            let id = ObjectIdentifier(NSObject())
            for (from, to) in zip(points, points.dropFirst()) {
                fingerMoved(id: id, from: from, to: to)
            }
            fingerLifted(id: id)
        }
    }
    #endif
}

struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
