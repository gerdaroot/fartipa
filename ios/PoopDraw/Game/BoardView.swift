import UIKit

enum BoardTool: Equatable {
    case none
    case carve(radius: CGFloat)
    case smooth
}

/// Shows the height field as a grid of layers and turns touches into grooves.
/// Only tiles under the finger are re-uploaded, so drawing stays smooth at full resolution.
final class BoardView: UIView {
    private static let fieldScale = 2
    private static let tilePixels = 128
    private static let smoothRadius: CGFloat = 30
    private static let flyCount = 4
    private static let topSpace: CGFloat = 70
    private static let bottomSpace: CGFloat = 96

    var tool: BoardTool = .none
    var showsTitle = true
    var onReady: (() -> Void)?
    /// Finger moved: stroke id, previous and current position in points.
    var onMove: ((ObjectIdentifier, CGPoint, CGPoint) -> Void)?
    var onTouchBegan: (() -> Void)?
    var onTouchEnded: ((ObjectIdentifier) -> Void)?
    /// Finger speed in points per second, for the squelch.
    var onSpeed: ((Double) -> Void)?

    private(set) var figureBox = CGRect(x: 0, y: 0, width: 1, height: 1)

    private var field: HeightField?
    private var builtSize: CGSize = .zero
    private var isBuilding = false
    private var tiles: [Tile] = []
    private let flyLayer = FlyLayerGroup()
    private let guideLayer = CAShapeLayer()
    private let coveredGuideLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?
    private var lastPoints: [ObjectIdentifier: (point: CGPoint, time: TimeInterval)] = [:]
    private var lastMoveTime: TimeInterval = 0
    private var squelching = false

    private struct Tile {
        let rect: PixelRect
        let layer: CALayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.227, green: 0.133, blue: 0.063, alpha: 1)
        isMultipleTouchEnabled = true
        guideLayer.fillColor = UIColor(red: 0.96, green: 0.89, blue: 0.71, alpha: 0.62).cgColor
        coveredGuideLayer.fillColor = UIColor(red: 0.9, green: 0.69, blue: 0.24, alpha: 0.92).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BoardView is created in code")
    }

    // MARK: - Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard window != nil, bounds.width > 0, bounds.height > 0, bounds.size != builtSize else { return }
        builtSize = bounds.size
        updateFigureBox()
        buildPile()
    }

    private func updateFigureBox() {
        let insets = window?.safeAreaInsets ?? .zero
        let top = insets.top + Self.topSpace
        let usable = bounds.height - top - insets.bottom - Self.bottomSpace
        let side = min(bounds.width * 0.88, usable * 0.94)
        figureBox = CGRect(x: (bounds.width - side) / 2, y: top + (usable - side) / 2, width: side, height: side)
    }

    /// Makes a fresh pile away from the main thread, then swaps it in.
    func buildPile() {
        guard builtSize.width > 0, !isBuilding else { return }
        isBuilding = true
        let widthPoints = Int(builtSize.width.rounded())
        let heightPoints = Int(builtSize.height.rounded())
        let seed = UInt32.random(in: .min ... .max)
        let scale = Self.fieldScale
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fresh = HeightField(widthPoints: widthPoints, heightPoints: heightPoints, scale: scale, seed: seed)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.install(fresh, widthPoints: widthPoints, heightPoints: heightPoints)
                }
            }
        }
    }

    private func install(_ fresh: HeightField, widthPoints: Int, heightPoints: Int) {
        isBuilding = false
        field = fresh
        rebuildTiles(for: fresh)
        if showsTitle { applyTitle() }
        flyLayer.configure(in: layer, width: Double(widthPoints), height: Double(heightPoints))
        layer.addSublayer(guideLayer)
        layer.addSublayer(coveredGuideLayer)
        layer.addSublayer(flyLayer.container)
        renderChanges()
        onReady?()
        onReady = nil
        if Int(builtSize.width.rounded()) != widthPoints || Int(builtSize.height.rounded()) != heightPoints {
            buildPile()
        }
    }

    private func rebuildTiles(for field: HeightField) {
        tiles.forEach { $0.layer.removeFromSuperlayer() }
        let pointsPerPixel = 1 / CGFloat(Self.fieldScale)
        var made: [Tile] = []
        for y in stride(from: 0, to: field.height, by: Self.tilePixels) {
            for x in stride(from: 0, to: field.width, by: Self.tilePixels) {
                let rect = PixelRect(
                    minX: x, minY: y,
                    maxX: min(field.width, x + Self.tilePixels),
                    maxY: min(field.height, y + Self.tilePixels)
                )
                let tileLayer = CALayer()
                tileLayer.actions = ["contents": NSNull()]
                tileLayer.isOpaque = true
                tileLayer.frame = CGRect(
                    x: CGFloat(rect.minX) * pointsPerPixel,
                    y: CGFloat(rect.minY) * pointsPerPixel,
                    width: CGFloat(rect.maxX - rect.minX) * pointsPerPixel,
                    height: CGFloat(rect.maxY - rect.minY) * pointsPerPixel
                )
                layer.insertSublayer(tileLayer, at: UInt32(made.count))
                made.append(Tile(rect: rect, layer: tileLayer))
            }
        }
        tiles = made
    }

    // MARK: - Commands from the game

    func resetSurface() {
        field?.resetCarving()
    }

    func applyTitle() {
        guard let field, let mask = TitleMask.render(width: field.width, height: field.height, centerY: 0.3) else { return }
        field.applyTitle(mask: mask)
    }

    /// Draws the figure's dots. `covered` marks the ones the finger has already reached.
    func showGuide(targets: [CGPoint], covered: [Bool]) {
        let open = UIBezierPath()
        let done = UIBezierPath()
        for (point, isDone) in zip(targets, covered) {
            let radius: CGFloat = isDone ? 2.6 : 2
            let dot = UIBezierPath(
                ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            )
            (isDone ? done : open).append(dot)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        guideLayer.path = open.cgPath
        coveredGuideLayer.path = done.cgPath
        CATransaction.commit()
    }

    func hideGuide() {
        showGuide(targets: [], covered: [])
    }

    func snapshot() -> UIImage? {
        guard let field else { return nil }
        renderChanges()
        guard let image = Self.makeImage(field.rgba(in: field.fullRect), width: field.width, height: field.height) else {
            return nil
        }
        return UIImage(cgImage: image, scale: CGFloat(Self.fieldScale), orientation: .up)
    }

    #if DEBUG
    /// Presses a line without a finger, for the screenshots CI takes.
    func carveDemoLine(_ points: [CGPoint], radius: CGFloat) {
        for (from, to) in zip(points, points.dropFirst()) {
            field?.carve(
                fromX: Float(from.x), fromY: Float(from.y),
                toX: Float(to.x), toY: Float(to.y),
                radius: Float(radius)
            )
        }
    }
    #endif

    // MARK: - Frame

    @objc private func tick(_ link: CADisplayLink) {
        renderChanges()
        if squelching, link.timestamp - lastMoveTime > 0.07 {
            squelching = false
            onSpeed?(0)
        }
        flyLayer.advance(dt: min(0.05, link.targetTimestamp - link.timestamp), time: link.timestamp)
    }

    private func renderChanges() {
        guard let field else { return }
        let changed = field.flush()
        guard !changed.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for tile in tiles where changed.contains(where: { Self.overlaps(tile.rect, $0) }) {
            tile.layer.contents = Self.makeImage(
                field.rgba(in: tile.rect),
                width: tile.rect.maxX - tile.rect.minX,
                height: tile.rect.maxY - tile.rect.minY
            )
        }
        CATransaction.commit()
    }

    private static func overlaps(_ a: PixelRect, _ b: PixelRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    private static func makeImage(_ data: Data, width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tool != .none else { return }
        onTouchBegan?()
        for touch in touches {
            let point = touch.location(in: self)
            lastPoints[ObjectIdentifier(touch)] = (point, touch.timestamp)
            apply(from: point, to: point, id: ObjectIdentifier(touch))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tool != .none else { return }
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let last = lastPoints[id] else { continue }
            let samples = event?.coalescedTouches(for: touch) ?? [touch]
            var previous = last.point
            for sample in samples {
                let point = sample.location(in: self)
                apply(from: previous, to: point, id: id)
                previous = point
            }
            let elapsed = max(0.001, touch.timestamp - last.time)
            onSpeed?(Double(hypot(previous.x - last.point.x, previous.y - last.point.y) / elapsed))
            squelching = true
            lastMoveTime = touch.timestamp
            lastPoints[id] = (previous, touch.timestamp)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard lastPoints.removeValue(forKey: id) != nil else { continue }
            onTouchEnded?(id)
        }
        if lastPoints.isEmpty {
            squelching = false
            onSpeed?(0)
        }
    }

    private func apply(from: CGPoint, to: CGPoint, id: ObjectIdentifier) {
        guard let field else { return }
        switch tool {
        case .none:
            return
        case .carve(let radius):
            field.carve(
                fromX: Float(from.x), fromY: Float(from.y),
                toX: Float(to.x), toY: Float(to.y),
                radius: Float(radius)
            )
        case .smooth:
            let distance = hypot(to.x - from.x, to.y - from.y)
            let steps = max(1, Int((distance / (Self.smoothRadius / 3)).rounded(.up)))
            for k in 1...steps {
                let t = CGFloat(k) / CGFloat(steps)
                field.smooth(
                    x: Float(from.x + (to.x - from.x) * t),
                    y: Float(from.y + (to.y - from.y) * t),
                    radius: Float(Self.smoothRadius)
                )
            }
        }
        flyLayer.scare(x: Double(to.x), y: Double(to.y))
        onMove?(id, from, to)
    }
}
