// Builds a README showcase image from Android screenshots, in the same style as the Mac ones:
// each screenshot in a Galaxy S24 Ultra frame, side by side on a navy card, with a headline
// and a description line under each.
//
//   swift make-showcase.swift <output.png> "<screenshot.png>|<headline>|<description>[|<scale>]" ...
//
// Screenshots are full-resolution captures from an S24 Ultra (1440 × 3120, `adb exec-out
// screencap -p`). The status bar is redrawn clean, and the One UI edge-panel handle along the
// right edge is painted out. <scale> enlarges a screenshot, e.g. 1.1 for the one in the middle.

import AppKit

struct Shot {
    let image: NSBitmapImageRep
    let headline: String
    let description: String
    let scale: CGFloat
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write("usage: make-showcase.swift <output.png> \"<screenshot>|<headline>|<description>[|<scale>]\" ...\n".data(using: .utf8)!)
    exit(1)
}

let shots: [Shot] = arguments.dropFirst(2).map { spec in
    let parts = spec.components(separatedBy: "|")
    guard parts.count >= 3, let data = FileManager.default.contents(atPath: parts[0]),
          let image = NSBitmapImageRep(data: data) else {
        FileHandle.standardError.write("can't read \(spec)\n".data(using: .utf8)!)
        exit(1)
    }
    return Shot(image: cleaned(image), headline: parts[1], description: parts[2],
                scale: parts.count > 3 ? CGFloat(Double(parts[3]) ?? 1) : 1)
}

// MARK: - Screenshot clean-up

/// The screenshot with a clean status bar and without the edge-panel handle.
func cleaned(_ source: NSBitmapImageRep) -> NSBitmapImageRep {
    let width = source.pixelsWide, height = source.pixelsHigh
    let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    source.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()

    // The status bar: each column filled with the colour just below it, so the app's
    // background carries on up, then a plain clock, signal, Wi-Fi and battery.
    let statusBar = height * 140 / 3120
    for x in 0..<width {
        let color = image.colorAt(x: x, y: statusBar + 6)!
        for y in 0..<statusBar { image.setColor(color, atX: x, y: y) }
    }
    // The edge-panel handle sits in the last ~20 pixels on the right: carry on the column
    // just inside it.
    let edge = width - width * 22 / 1440
    for y in 0..<height {
        let color = image.colorAt(x: edge - 2, y: y)!
        for x in edge..<width { image.setColor(color, atX: x, y: y) }
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    let unit = CGFloat(width) / 1440
    let top = CGFloat(height)
    let clock = NSAttributedString(string: "12:30", attributes: [
        .font: NSFont.systemFont(ofSize: 44 * unit, weight: .semibold),
        .foregroundColor: NSColor.white,
    ])
    clock.draw(at: NSPoint(x: 72 * unit, y: top - 104 * unit))
    var x = CGFloat(width) - 72 * unit
    for symbol in ["battery.100percent", "wifi", "cellularbars"] {
        let config = NSImage.SymbolConfiguration(pointSize: 40 * unit, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        guard let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { continue }
        x -= icon.size.width
        icon.draw(in: NSRect(x: x, y: top - 92 * unit, width: icon.size.width, height: icon.size.height))
        x -= 22 * unit
    }
    NSGraphicsContext.restoreGraphicsState()
    return image
}

// MARK: - Layout

/// The width of a screen at scale 1, and the frame around it in proportion to that.
let screenWidth: CGFloat = 380
let bezel: CGFloat = 0.03
let headlineSize: CGFloat = 30
let descriptionSize: CGFloat = 22
let column: CGFloat = screenWidth * 1.65
let margin: CGFloat = 70

func screenSize(_ shot: Shot) -> CGSize {
    let width = screenWidth * shot.scale
    return CGSize(width: width, height: width * CGFloat(shot.image.pixelsHigh) / CGFloat(shot.image.pixelsWide))
}

func bodySize(_ shot: Shot) -> CGSize {
    let screen = screenSize(shot)
    let border = screen.width * bezel
    return CGSize(width: screen.width + border * 2, height: screen.height + border * 2)
}

let tallest = shots.map { bodySize($0).height }.max()!
let canvas = CGSize(width: column * CGFloat(shots.count) + margin * 2 - column * 0.12 * CGFloat(shots.count - 1),
                    height: margin + tallest + 56 + headlineSize + descriptionSize + 24 + margin)

let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: output)!
NSGraphicsContext.current = context
context.imageInterpolation = .high
let cg = context.cgContext

/// A rect given from the top-left, as the layout is worked out, in AppKit's bottom-up space.
func rect(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: canvas.height - top - height, width: width, height: height)
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// MARK: - The card

let card = CGPath(roundedRect: CGRect(origin: .zero, size: canvas), cornerWidth: 44, cornerHeight: 44, transform: nil)
cg.saveGState()
cg.addPath(card)
cg.clip()
let space = CGColorSpace(name: CGColorSpace.sRGB)!
cg.drawLinearGradient(
    CGGradient(colorsSpace: space, colors: [color(0x4B5B78), color(0x2B374E), color(0x0E1425)] as CFArray,
               locations: [0, 0.5, 1])!,
    start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: 0, y: 0), options: [])
// The lighter glow at the top centre.
cg.drawRadialGradient(
    CGGradient(colorsSpace: space, colors: [color(0x5C7398, 0.55), color(0x5C7398, 0)] as CFArray, locations: [0, 1])!,
    startCenter: CGPoint(x: canvas.width / 2, y: canvas.height), startRadius: 0,
    endCenter: CGPoint(x: canvas.width / 2, y: canvas.height), endRadius: canvas.width * 0.55, options: [])
cg.restoreGState()

// MARK: - Phones and captions

let step = (canvas.width - margin * 2) / CGFloat(shots.count)
for (index, shot) in shots.enumerated() {
    let center = margin + step * (CGFloat(index) + 0.5)
    let body = bodySize(shot)
    let screen = screenSize(shot)
    let border = screen.width * bezel
    let bodyRect = rect(center - body.width / 2, margin + (tallest - body.height) / 2, body.width, body.height)

    // Side keys on the right: the volume rocker, then the power key.
    let key = screen.width * 0.012
    for (from, length) in [(0.21, 0.13), (0.37, 0.06)] as [(CGFloat, CGFloat)] {
        let keyRect = CGRect(x: bodyRect.maxX - key * 0.4, y: bodyRect.maxY - body.height * (from + length),
                             width: key, height: body.height * length)
        cg.addPath(CGPath(roundedRect: keyRect, cornerWidth: key / 2, cornerHeight: key / 2, transform: nil))
        cg.setFillColor(color(0x55575C))
        cg.fillPath()
    }

    // The titanium body: squarer corners than most phones, with a lighter rim.
    let radius = body.width * 0.055
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: color(0x000000, 0.45))
    cg.addPath(bodyPath)
    cg.setFillColor(color(0x1A1B1E))
    cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()
    cg.drawLinearGradient(
        CGGradient(colorsSpace: space, colors: [color(0x6E7076), color(0x3C3E43), color(0x5D5F64)] as CFArray,
                   locations: [0, 0.5, 1])!,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY), end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY), options: [])
    cg.restoreGState()
    let rim = border * 0.32
    let inner = bodyRect.insetBy(dx: rim, dy: rim)
    cg.addPath(CGPath(roundedRect: inner, cornerWidth: radius - rim, cornerHeight: radius - rim, transform: nil))
    cg.setFillColor(color(0x050505))
    cg.fillPath()

    // The screen, then its centred punch-hole camera.
    let screenRect = bodyRect.insetBy(dx: border, dy: border)
    let screenRadius = radius - border * 0.75
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: screenRect, cornerWidth: screenRadius, cornerHeight: screenRadius, transform: nil))
    cg.clip()
    shot.image.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
    cg.restoreGState()
    let hole = screen.width * 0.032
    cg.addEllipse(in: CGRect(x: screenRect.midX - hole / 2, y: screenRect.maxY - screen.height * 0.0225 - hole / 2,
                             width: hole, height: hole))
    cg.setFillColor(color(0x000000))
    cg.fillPath()

    // The headline and its description, centred under the phone.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let captionTop = margin + tallest + 56
    NSAttributedString(string: shot.headline, attributes: [
        .font: NSFont.systemFont(ofSize: headlineSize, weight: .semibold),
        .foregroundColor: NSColor(cgColor: color(0xEFF0F2))!, .paragraphStyle: paragraph,
    ]).draw(in: rect(center - column / 2, captionTop, column, headlineSize * 1.3))
    NSAttributedString(string: shot.description, attributes: [
        .font: NSFont.systemFont(ofSize: descriptionSize),
        .foregroundColor: NSColor(cgColor: color(0xBCBFC5))!, .paragraphStyle: paragraph,
    ]).draw(in: rect(center - column / 2, captionTop + headlineSize * 1.35, column, descriptionSize * 1.4))
}

NSGraphicsContext.restoreGraphicsState()
try! output.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arguments[1]))
