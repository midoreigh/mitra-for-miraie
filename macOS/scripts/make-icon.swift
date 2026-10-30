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
    func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        NSColor(red: r, green: g, blue: b, alpha: a).cgColor
    }
    func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
    }

    // macOS icon grid: an 824pt squircle centred in 1024.
    let tile = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185 * s, cornerHeight: 185 * s, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: color(0, 0, 0, 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(color(0, 0, 0))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // The panel's graphite night sky, with a cool glow where the air comes out.
    ctx.drawLinearGradient(gradient([color(0.03, 0.04, 0.08), color(0.15, 0.18, 0.24), color(0.32, 0.36, 0.44)], [0, 0.55, 1]),
                           start: CGPoint(x: 512 * s, y: 100 * s), end: CGPoint(x: 512 * s, y: 924 * s), options: [])
    let glow = CGPoint(x: 512 * s, y: 560 * s)
    ctx.drawRadialGradient(gradient([color(0.35, 0.6, 1, 0.5), color(0.35, 0.6, 1, 0)], [0, 1]),
                           startCenter: glow, startRadius: 0, endCenter: glow, endRadius: 440 * s, options: [])

    // Air streaming out of the outlet and fanning out, brightest near the unit.
    ctx.setLineCap(.round)
    for stream in 0..<9 {
        let u = CGFloat(stream) / 8 - 0.5
        for dash in 0..<3 {
            let start = 0.1 + CGFloat(dash) * 0.3 + CGFloat(stream % 3) * 0.05
            let point = { (t: CGFloat) in CGPoint(x: 512 * s + u * (330 + 430 * t) * s, y: (560 - 420 * t) * s) }
            ctx.move(to: point(start))
            ctx.addLine(to: point(start + 0.16))
            ctx.setLineWidth((12 + 9 * CGFloat(dash)) * s)
            ctx.setStrokeColor(color(0.49, 0.89, 1, 0.95 - CGFloat(dash) * 0.22 - abs(u) * 0.4))
            ctx.strokePath()
        }
    }

    // The indoor unit: white casing, dark outlet with the flap swung open below it, green light.
    let unit = CGRect(x: 232 * s, y: 610 * s, width: 560 * s, height: 175 * s)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 30 * s, color: color(0, 0, 0, 0.45))
    ctx.addPath(CGPath(roundedRect: unit, cornerWidth: 52 * s, cornerHeight: 52 * s, transform: nil))
    ctx.setFillColor(color(0.98, 0.98, 0.99))
    ctx.fillPath()
    ctx.restoreGState()
    let outlet = CGRect(x: unit.minX + 40 * s, y: unit.minY + 18 * s, width: unit.width - 80 * s, height: 30 * s)
    ctx.addPath(CGPath(roundedRect: outlet, cornerWidth: 15 * s, cornerHeight: 15 * s, transform: nil))
    ctx.setFillColor(color(0.12, 0.12, 0.14))
    ctx.fillPath()
    let flap = CGRect(x: outlet.minX + 6 * s, y: outlet.minY - 22 * s, width: outlet.width - 12 * s, height: 26 * s)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: flap, cornerWidth: 13 * s, cornerHeight: 13 * s, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(gradient([color(0.8, 0.8, 0.82), color(0.97, 0.97, 0.98)], [0, 1]),
                           start: CGPoint(x: 0, y: flap.minY), end: CGPoint(x: 0, y: flap.maxY), options: [])
    ctx.restoreGState()
    let light = CGRect(x: unit.minX + 48 * s, y: unit.maxY - 62 * s, width: 24 * s, height: 24 * s)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18 * s, color: color(0.2, 0.95, 0.45))
    ctx.setFillColor(color(0.25, 0.92, 0.45))
    ctx.fillEllipse(in: light)
    ctx.restoreGState()

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
