// Draws Mitra's app icon and writes every macOS size into the asset catalog.
// Usage: swift scripts/make-icon.swift
import AppKit

let output = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset")

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 1024

    // macOS icon grid: an 824pt squircle centred in 1024.
    let tile = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185 * s, cornerHeight: 185 * s, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(shape)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(red: 0.07, green: 0.12, blue: 0.35, alpha: 1).cgColor,
        NSColor(red: 0.12, green: 0.38, blue: 0.92, alpha: 1).cgColor,
        NSColor(red: 0.35, green: 0.86, blue: 1.00, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: tile.minX, y: tile.minY),
                           end: CGPoint(x: tile.maxX, y: tile.maxY), options: [])

    // The indoor unit.
    let unit = CGRect(x: 232 * s, y: 610 * s, width: 560 * s, height: 170 * s)
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * s), blur: 30 * s, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(CGPath(roundedRect: unit, cornerWidth: 54 * s, cornerHeight: 54 * s, transform: nil))
    ctx.setFillColor(NSColor(white: 0.98, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let slot = CGRect(x: 280 * s, y: 640 * s, width: 464 * s, height: 22 * s)
    ctx.addPath(CGPath(roundedRect: slot, cornerWidth: 11 * s, cornerHeight: 11 * s, transform: nil))
    ctx.setFillColor(NSColor(red: 0.16, green: 0.22, blue: 0.40, alpha: 1).cgColor)
    ctx.fillPath()
    let led = CGRect(x: 716 * s, y: 726 * s, width: 22 * s, height: 22 * s)
    ctx.setFillColor(NSColor(red: 0.35, green: 0.86, blue: 1.0, alpha: 1).cgColor)
    ctx.fillEllipse(in: led)

    // Air streaming down and fanning out, as in the app.
    ctx.setLineCap(.round)
    for index in 0..<5 {
        let u = CGFloat(index) / 4 - 0.5
        let start = CGPoint(x: 512 * s + u * 380 * s, y: 600 * s)
        let end = CGPoint(x: 512 * s + u * 600 * s, y: 250 * s)
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: end,
                      control1: CGPoint(x: start.x + 50 * s, y: 480 * s),
                      control2: CGPoint(x: end.x - 50 * s, y: 380 * s))
        ctx.addPath(path)
        ctx.setLineWidth(30 * s)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92 - abs(u) * 0.5).cgColor)
        ctx.strokePath()
    }
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! drawIcon(size: CGFloat(pixels)).representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
