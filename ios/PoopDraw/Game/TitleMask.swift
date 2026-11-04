import UIKit

/// Renders the game's title into a byte mask, which the height field then presses in as gold letters.
enum TitleMask {
    private static let lines = ["РИСУЙ", "НА ГОВНЕ"]
    private static let maxFontPixels: CGFloat = 148

    static func render(width: Int, height: Int, centerY: CGFloat) -> [UInt8]? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Flip so UIKit text draws upright and row 0 of the buffer is the top of the screen.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        drawLines(canvasWidth: CGFloat(width), middle: CGFloat(height) * centerY)

        guard let data = context.data else { return nil }
        let bytesPerRow = context.bytesPerRow
        let source = data.assumingMemoryBound(to: UInt8.self)
        var mask = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                mask[x + y * width] = source[x + y * bytesPerRow]
            }
        }
        return mask
    }

    private static func drawLines(canvasWidth: CGFloat, middle: CGFloat) {
        let longest = lines.max { $0.count < $1.count } ?? ""
        let probeSize = longestWidth(longest, fontSize: 100)
        let fontSize = min(100 * canvasWidth * 0.88 / probeSize, maxFontPixels)
        let attributes = textAttributes(fontSize: fontSize)
        let lineGap = fontSize * 1.08
        let firstMiddle = middle - CGFloat(lines.count - 1) * lineGap / 2
        for (index, line) in lines.enumerated() {
            let size = (line as NSString).size(withAttributes: attributes)
            let origin = CGPoint(
                x: (canvasWidth - size.width) / 2,
                y: firstMiddle + CGFloat(index) * lineGap - size.height / 2
            )
            (line as NSString).draw(at: origin, withAttributes: attributes)
        }
    }

    private static func longestWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        max(1, (text as NSString).size(withAttributes: textAttributes(fontSize: fontSize)).width)
    }

    private static func textAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let plain = UIFont.systemFont(ofSize: fontSize, weight: .black)
        let rounded = plain.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: fontSize) } ?? plain
        return [.font: rounded, .foregroundColor: UIColor.white]
    }
}
