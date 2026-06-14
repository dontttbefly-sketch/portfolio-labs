import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var cgColor: CGColor {
        CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }
}

private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}

private func scaleRect(_ source: CGRect, by scale: CGFloat) -> CGRect {
    CGRect(
        x: source.origin.x * scale,
        y: source.origin.y * scale,
        width: source.size.width * scale,
        height: source.size.height * scale
    )
}

private func rounded(_ source: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: source, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func drawLinearGradient(_ context: CGContext, in area: CGRect, colors: [RGBA], start: CGPoint, end: CGPoint) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    context.saveGState()
    context.clip(to: area)
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

private func drawRadialGradient(_ context: CGContext, center: CGPoint, radius: CGFloat, colors: [RGBA]) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    context.saveGState()
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()
}

private func regularPolygon(center: CGPoint, radius: CGFloat, sides: Int, rotation: CGFloat = 0) -> CGPath {
    let path = CGMutablePath()
    for index in 0..<sides {
        let angle = rotation + CGFloat(index) * 2 * CGFloat.pi / CGFloat(sides)
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        index == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

private func drawLine(_ context: CGContext, _ points: [CGPoint], color: RGBA, width: CGFloat, glow: CGFloat = 0) {
    guard let first = points.first else {
        return
    }

    context.saveGState()
    if glow > 0 {
        context.setShadow(offset: .zero, blur: glow, color: color.cgColor)
    }
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
    context.restoreGState()
}

private func drawNode(_ context: CGContext, center: CGPoint, radius: CGFloat, color: RGBA) {
    context.saveGState()
    context.setShadow(offset: .zero, blur: radius * 2.4, color: color.cgColor)
    context.setFillColor(color.cgColor)
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.restoreGState()
}

private func drawBackground(_ context: CGContext, scale: CGFloat, bounds: CGRect) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -34 * scale), blur: 60 * scale, color: RGBA(0, 0, 0, 0.38).cgColor)
    context.addPath(rounded(bounds, 198 * scale))
    context.clip()
    drawLinearGradient(
        context,
        in: bounds,
        colors: [RGBA(7, 12, 28), RGBA(18, 22, 58), RGBA(2, 45, 58)],
        start: CGPoint(x: bounds.minX, y: bounds.maxY),
        end: CGPoint(x: bounds.maxX, y: bounds.minY)
    )
    drawRadialGradient(
        context,
        center: CGPoint(x: 704 * scale, y: 712 * scale),
        radius: 520 * scale,
        colors: [RGBA(66, 245, 220, 0.34), RGBA(32, 38, 87, 0.08), RGBA(0, 0, 0, 0)]
    )
    drawRadialGradient(
        context,
        center: CGPoint(x: 316 * scale, y: 298 * scale),
        radius: 450 * scale,
        colors: [RGBA(155, 93, 255, 0.28), RGBA(0, 0, 0, 0)]
    )
    context.restoreGState()
}

private func drawTechGrid(_ context: CGContext, scale: CGFloat, bounds: CGRect) {
    context.saveGState()
    context.addPath(rounded(bounds, 198 * scale))
    context.clip()

    context.setLineWidth(1.0 * scale)
    for index in 0...13 {
        let offset = (128 + index * 60)
        let alpha: CGFloat = index % 3 == 0 ? 0.12 : 0.06
        context.setStrokeColor(RGBA(121, 235, 255, alpha).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: CGFloat(offset) * scale, y: 110 * scale))
        context.addLine(to: CGPoint(x: CGFloat(offset) * scale, y: 914 * scale))
        context.strokePath()
        context.beginPath()
        context.move(to: CGPoint(x: 110 * scale, y: CGFloat(offset) * scale))
        context.addLine(to: CGPoint(x: 914 * scale, y: CGFloat(offset) * scale))
        context.strokePath()
    }

    let traces: [[CGPoint]] = [
        [CGPoint(x: 166, y: 742), CGPoint(x: 252, y: 742), CGPoint(x: 252, y: 650), CGPoint(x: 352, y: 650)],
        [CGPoint(x: 154, y: 512), CGPoint(x: 262, y: 512), CGPoint(x: 316, y: 566), CGPoint(x: 398, y: 566)],
        [CGPoint(x: 850, y: 614), CGPoint(x: 752, y: 614), CGPoint(x: 704, y: 566), CGPoint(x: 626, y: 566)],
        [CGPoint(x: 802, y: 270), CGPoint(x: 710, y: 270), CGPoint(x: 662, y: 342), CGPoint(x: 594, y: 342)],
        [CGPoint(x: 220, y: 262), CGPoint(x: 314, y: 262), CGPoint(x: 352, y: 340), CGPoint(x: 430, y: 340)]
    ]
    let colors = [RGBA(74, 232, 255, 0.72), RGBA(157, 105, 255, 0.58), RGBA(51, 255, 192, 0.66)]
    for (index, trace) in traces.enumerated() {
        drawLine(
            context,
            trace.map { CGPoint(x: $0.x * scale, y: $0.y * scale) },
            color: colors[index % colors.count],
            width: 3.2 * scale,
            glow: 9 * scale
        )
        for point in trace where point == trace.first || point == trace.last {
            drawNode(context, center: CGPoint(x: point.x * scale, y: point.y * scale), radius: 6 * scale, color: colors[index % colors.count])
        }
    }

    context.restoreGState()
}

private func drawHologramPhoto(_ context: CGContext, scale: CGFloat) {
    let card = scaleRect(rect(186, 614, 238, 174), by: scale)
    let inset = card.insetBy(dx: 18 * scale, dy: 18 * scale)

    context.saveGState()
    context.setShadow(offset: .zero, blur: 24 * scale, color: RGBA(97, 239, 255, 0.28).cgColor)
    context.setFillColor(RGBA(12, 29, 45, 0.58).cgColor)
    context.addPath(rounded(card, 30 * scale))
    context.fillPath()

    context.setStrokeColor(RGBA(127, 238, 255, 0.58).cgColor)
    context.setLineWidth(2.2 * scale)
    context.addPath(rounded(card, 30 * scale))
    context.strokePath()

    context.addPath(rounded(inset, 18 * scale))
    context.clip()
    drawLinearGradient(
        context,
        in: inset,
        colors: [RGBA(47, 118, 209, 0.55), RGBA(49, 227, 193, 0.42)],
        start: CGPoint(x: inset.minX, y: inset.maxY),
        end: CGPoint(x: inset.maxX, y: inset.minY)
    )
    context.setFillColor(RGBA(255, 212, 96, 0.85).cgColor)
    context.fillEllipse(in: scaleRect(rect(332, 708, 34, 34), by: scale))

    let mountain = CGMutablePath()
    mountain.move(to: CGPoint(x: 204 * scale, y: 632 * scale))
    mountain.addLine(to: CGPoint(x: 284 * scale, y: 706 * scale))
    mountain.addLine(to: CGPoint(x: 344 * scale, y: 652 * scale))
    mountain.addLine(to: CGPoint(x: 406 * scale, y: 720 * scale))
    mountain.addLine(to: CGPoint(x: 406 * scale, y: 632 * scale))
    mountain.closeSubpath()
    context.setFillColor(RGBA(39, 247, 174, 0.58).cgColor)
    context.addPath(mountain)
    context.fillPath()
    context.restoreGState()
}

private func drawAperture(_ context: CGContext, scale: CGFloat) {
    let center = CGPoint(x: 544 * scale, y: 504 * scale)
    let outerRadius = 214 * scale
    let innerRadius = 84 * scale

    context.saveGState()
    context.setShadow(offset: .zero, blur: 32 * scale, color: RGBA(54, 235, 255, 0.48).cgColor)
    context.setStrokeColor(RGBA(94, 242, 255, 0.9).cgColor)
    context.setLineWidth(8 * scale)
    context.addPath(regularPolygon(center: center, radius: outerRadius, sides: 6, rotation: CGFloat.pi / 6))
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(RGBA(157, 105, 255, 0.66).cgColor)
    context.setLineWidth(2.5 * scale)
    context.addPath(regularPolygon(center: center, radius: 248 * scale, sides: 6, rotation: CGFloat.pi / 6))
    context.strokePath()
    context.restoreGState()

    let bladeColors = [
        RGBA(35, 232, 255, 0.75), RGBA(69, 255, 196, 0.70), RGBA(156, 104, 255, 0.68),
        RGBA(46, 147, 255, 0.66), RGBA(52, 255, 214, 0.72), RGBA(188, 111, 255, 0.62)
    ]

    for index in 0..<6 {
        let angle = CGFloat(index) * CGFloat.pi / 3 + CGFloat.pi / 6
        let next = angle + CGFloat.pi / 3
        let mid = angle + CGFloat.pi / 6
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x + cos(angle) * innerRadius, y: center.y + sin(angle) * innerRadius))
        path.addLine(to: CGPoint(x: center.x + cos(mid) * 186 * scale, y: center.y + sin(mid) * 186 * scale))
        path.addLine(to: CGPoint(x: center.x + cos(next) * innerRadius, y: center.y + sin(next) * innerRadius))
        path.closeSubpath()

        context.saveGState()
        context.setFillColor(bladeColors[index].cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    context.saveGState()
    context.setBlendMode(.screen)
    drawRadialGradient(
        context,
        center: center,
        radius: 178 * scale,
        colors: [RGBA(190, 255, 255, 0.62), RGBA(57, 246, 255, 0.18), RGBA(0, 0, 0, 0)]
    )
    context.restoreGState()

    context.saveGState()
    context.setFillColor(RGBA(4, 10, 20, 0.92).cgColor)
    context.fillEllipse(in: CGRect(x: center.x - 78 * scale, y: center.y - 78 * scale, width: 156 * scale, height: 156 * scale))
    context.setStrokeColor(RGBA(205, 255, 255, 0.92).cgColor)
    context.setLineWidth(4 * scale)
    context.strokeEllipse(in: CGRect(x: center.x - 80 * scale, y: center.y - 80 * scale, width: 160 * scale, height: 160 * scale))
    context.setStrokeColor(RGBA(79, 247, 255, 0.36).cgColor)
    context.setLineWidth(18 * scale)
    context.strokeEllipse(in: CGRect(x: center.x - 116 * scale, y: center.y - 116 * scale, width: 232 * scale, height: 232 * scale))
    context.restoreGState()
}

private func drawImportArrow(_ context: CGContext, scale: CGFloat) {
    let shaft = scaleRect(rect(486, 180, 74, 222), by: scale)
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 414 * scale, y: 390 * scale))
    head.addLine(to: CGPoint(x: 523 * scale, y: 500 * scale))
    head.addLine(to: CGPoint(x: 632 * scale, y: 390 * scale))
    head.addLine(to: CGPoint(x: 570 * scale, y: 390 * scale))
    head.addLine(to: CGPoint(x: 570 * scale, y: 334 * scale))
    head.addLine(to: CGPoint(x: 476 * scale, y: 334 * scale))
    head.addLine(to: CGPoint(x: 476 * scale, y: 390 * scale))
    head.closeSubpath()

    context.saveGState()
    context.setShadow(offset: .zero, blur: 26 * scale, color: RGBA(54, 255, 207, 0.72).cgColor)
    context.addPath(rounded(shaft, 36 * scale))
    context.addPath(head)
    context.clip()
    drawLinearGradient(
        context,
        in: scaleRect(rect(390, 170, 270, 340), by: scale),
        colors: [RGBA(86, 255, 214), RGBA(91, 209, 255), RGBA(179, 111, 255)],
        start: CGPoint(x: 430 * scale, y: 184 * scale),
        end: CGPoint(x: 620 * scale, y: 496 * scale)
    )
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(RGBA(221, 255, 255, 0.7).cgColor)
    context.setLineWidth(2.2 * scale)
    context.addPath(rounded(shaft.insetBy(dx: 18 * scale, dy: 18 * scale), 18 * scale))
    context.strokePath()
    context.restoreGState()
}

private func drawCornerGlyphs(_ context: CGContext, scale: CGFloat) {
    let glyphColor = RGBA(125, 237, 255, 0.52)
    let accent = RGBA(178, 117, 255, 0.48)
    let corners = [
        scaleRect(rect(164, 164, 128, 128), by: scale),
        scaleRect(rect(732, 740, 128, 128), by: scale)
    ]
    for (index, area) in corners.enumerated() {
        context.saveGState()
        context.setStrokeColor((index == 0 ? glyphColor : accent).cgColor)
        context.setLineWidth(4 * scale)
        context.addPath(regularPolygon(center: CGPoint(x: area.midX, y: area.midY), radius: 54 * scale, sides: 6, rotation: CGFloat.pi / 6))
        context.strokePath()
        drawNode(context, center: CGPoint(x: area.midX, y: area.midY), radius: 5 * scale, color: index == 0 ? glyphColor : accent)
        context.restoreGState()
    }
}

private func drawIcon(size: Int) throws -> CGImage {
    let scale = CGFloat(size) / 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "ImportToPhotosIcon", code: 1)
    }

    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let bounds = CGRect(x: 72 * scale, y: 72 * scale, width: 880 * scale, height: 880 * scale)

    context.saveGState()
    context.addPath(rounded(bounds, 198 * scale))
    context.clip()
    drawBackground(context, scale: scale, bounds: bounds)
    drawTechGrid(context, scale: scale, bounds: bounds)
    drawCornerGlyphs(context, scale: scale)
    drawHologramPhoto(context, scale: scale)
    drawAperture(context, scale: scale)
    drawImportArrow(context, scale: scale)
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(RGBA(255, 255, 255, 0.12).cgColor)
    context.setLineWidth(2 * scale)
    context.addPath(rounded(bounds.insetBy(dx: 14 * scale, dy: 14 * scale), 184 * scale))
    context.strokePath()
    context.restoreGState()

    guard let image = context.makeImage() else {
        throw NSError(domain: "ImportToPhotosIcon", code: 2)
    }
    return image
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "ImportToPhotosIcon", code: 3)
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "ImportToPhotosIcon", code: 4)
    }
}

private extension Data {
    mutating func appendOSType(_ type: String) {
        append(type.data(using: .ascii)!)
    }

    mutating func appendBigEndianUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }
}

private func writeICNS(chunks: [(type: String, url: URL)], to outputURL: URL) throws {
    let chunkData = try chunks.map { chunk in
        (chunk.type, try Data(contentsOf: chunk.url))
    }
    let totalLength = 8 + chunkData.reduce(0) { $0 + 8 + $1.1.count }

    var data = Data()
    data.appendOSType("icns")
    data.appendBigEndianUInt32(UInt32(totalLength))

    for (type, payload) in chunkData {
        data.appendOSType(type)
        data.appendBigEndianUInt32(UInt32(payload.count + 8))
        data.append(payload)
    }

    try data.write(to: outputURL, options: .atomic)
}

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let iconset = outputRoot.appendingPathComponent("ImportToPhotos.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in iconFiles {
    try writePNG(try drawIcon(size: size), to: iconset.appendingPathComponent(filename))
}

try writeICNS(
    chunks: [
        ("icp4", iconset.appendingPathComponent("icon_16x16.png")),
        ("icp5", iconset.appendingPathComponent("icon_32x32.png")),
        ("icp6", iconset.appendingPathComponent("icon_32x32@2x.png")),
        ("ic07", iconset.appendingPathComponent("icon_128x128.png")),
        ("ic08", iconset.appendingPathComponent("icon_256x256.png")),
        ("ic09", iconset.appendingPathComponent("icon_512x512.png")),
        ("ic10", iconset.appendingPathComponent("icon_512x512@2x.png")),
        ("ic11", iconset.appendingPathComponent("icon_16x16@2x.png")),
        ("ic12", iconset.appendingPathComponent("icon_32x32@2x.png")),
        ("ic13", iconset.appendingPathComponent("icon_128x128@2x.png")),
        ("ic14", iconset.appendingPathComponent("icon_256x256@2x.png"))
    ],
    to: outputRoot.appendingPathComponent("ImportToPhotos.icns")
)
