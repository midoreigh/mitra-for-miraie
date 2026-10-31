// Draws Mitra's app icon: every macOS size into the asset catalog, the Android adaptive icon's
// layers, and the README's copy. Both apps share one drawing.
// Usage, from macOS/: swift scripts/make-icon.swift
import AppKit
import CoreText

let macOutput = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset")
let androidOutput = URL(fileURLWithPath: "../android/app/src/main/res/drawable-nodpi")
let readmeOutput = URL(fileURLWithPath: "../docs/media/icon.png")

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// The drawing works on a 1024 grid from the top left; macOS's 824 squircle sits at 100–924.

/// The app's graphite night sky, with a soft glow behind the unit.
func drawBackground(_ ctx: CGContext) {
    ctx.drawLinearGradient(gradient([color(0x2C3650), color(0x141A2A), color(0x070A13)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.drawRadialGradient(gradient([color(0x4F6FA8, 0.55), color(0x4F6FA8, 0)], [0, 1]),
                           startCenter: CGPoint(x: 512, y: 340), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 340), endRadius: 420, options: [])
}

let unit = CGRect(x: 297, y: 250, width: 430, height: 150)

/// The air: five rays, one in each mode's colour as the app draws its air, from Heat on the
/// left through Auto, Cool in the middle and Dry, to Fan on the right.
let modeTints: [(base: UInt32, glow: UInt32)] = [
    (0xFF8C3D, 0xFFC76B), (0x9E8CFF, 0xDB9EFF), (0x54ADFF, 0x7DE3FF), (0x38D4C2, 0x8CF2CC), (0xC7D6ED, 0xF2F7FF),
]

func airRays() -> [(from: CGPoint, to: CGPoint, tint: (base: UInt32, glow: UInt32))] {
    modeTints.enumerated().map { i, tint in
        let t = CGFloat(i) / 4 - 0.5
        return (CGPoint(x: 512 + t * 290, y: 450), CGPoint(x: 512 + t * 560, y: 790), tint)
    }
}

let rayWidth: CGFloat = 44

/// The unit and its air, in colour, with glows.
func drawForeground(_ ctx: CGContext) {
    ctx.setLineCap(.round)
    for ray in airRays() {
        // A glow in the mode's colour, then the ray, brightest at the outlet.
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 22, color: color(ray.tint.base, 0.75))
        ctx.setStrokeColor(color(ray.tint.base, 0.45))
        ctx.setLineWidth(rayWidth)
        ctx.move(to: ray.from)
        ctx.addLine(to: ray.to)
        ctx.strokePath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.setLineWidth(rayWidth)
        ctx.move(to: ray.from)
        ctx.addLine(to: ray.to)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(gradient([color(ray.tint.glow, 0.95), color(ray.tint.base, 0.6)], [0, 1]),
                               start: ray.from, end: ray.to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // The casing: white, shaded a little towards the bottom, with a soft shadow.
    let body = CGPath(roundedRect: unit, cornerWidth: 54, cornerHeight: 54, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: color(0x000000, 0.5))
    ctx.addPath(body)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawLinearGradient(gradient([color(0xFFFFFF), color(0xF1F4F8), color(0xD5DCE6)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: unit.minY), end: CGPoint(x: 0, y: unit.maxY), options: [])
    ctx.restoreGState()

    // The outlet along the bottom.
    let outlet = CGRect(x: unit.minX + unit.width * 0.06, y: unit.minY + unit.height * 0.66,
                        width: unit.width * 0.88, height: unit.height * 0.14)
    ctx.addPath(CGPath(roundedRect: outlet, cornerWidth: outlet.height / 2, cornerHeight: outlet.height / 2, transform: nil))
    ctx.setFillColor(color(0x1A1E27))
    ctx.fillPath()

    // The green light, and the display showing the set temperature.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 14, color: color(0x34C759, 0.9))
    let light = unit.height * 0.13
    ctx.setFillColor(color(0x34C759))
    ctx.fillEllipse(in: CGRect(x: unit.minX + unit.width * 0.075, y: unit.minY + unit.height * 0.22, width: light, height: light))
    ctx.restoreGState()
    let font = NSFont.systemFont(ofSize: unit.height * 0.26, weight: .semibold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "24", attributes: [
        .font: font, .foregroundColor: NSColor(cgColor: color(0x1A73F2))!,
    ]))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.textPosition = CGPoint(x: unit.maxX - unit.width * 0.075 - CGFloat(width), y: unit.minY + unit.height * 0.4)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// One colour, for Android's themed icons: the unit with its outlet cut out, and the air.
func drawMonochrome(_ ctx: CGContext) {
    ctx.setFillColor(color(0xFFFFFF))
    ctx.addPath(CGPath(roundedRect: unit, cornerWidth: 54, cornerHeight: 54, transform: nil))
    ctx.fillPath()
    let outlet = CGRect(x: unit.minX + unit.width * 0.06, y: unit.minY + unit.height * 0.66,
                        width: unit.width * 0.88, height: unit.height * 0.14)
    ctx.setBlendMode(.clear)
    ctx.addPath(CGPath(roundedRect: outlet, cornerWidth: outlet.height / 2, cornerHeight: outlet.height / 2, transform: nil))
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.setLineCap(.round)
    for ray in airRays() {
        ctx.setStrokeColor(color(0xFFFFFF))
        ctx.setLineWidth(rayWidth)
        ctx.move(to: ray.from)
        ctx.addLine(to: ray.to)
        ctx.strokePath()
    }
}

/// A square image of [pixels], showing [units] of the 1024 grid around its centre.
func render(pixels: Int, units: CGFloat = 1024, _ draw: (CGContext) -> Void) -> Data {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let scale = CGFloat(pixels) / units
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.translateBy(x: (units - 1024) / 2, y: (units - 1024) / 2)
    draw(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

/// The macOS icon: the squircle with a drop shadow, the night sky and the unit.
func macIcon(_ ctx: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: color(0x000000, 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x000000))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    drawBackground(ctx)
    drawForeground(ctx)
    ctx.restoreGState()
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! render(pixels: points * scale, macIcon).write(to: macOutput.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: macOutput.appendingPathComponent("Contents.json"))
try! render(pixels: 256, macIcon).write(to: readmeOutput)

// Android's adaptive icon: 108 dp layers, of which launchers mask off all but the middle 66 dp
// or so, depending on their shape. The macOS squircle fits that safe zone, so nothing is
// clipped. 432 px is the xxxhdpi size; Android scales it down.
let androidUnits: CGFloat = 824 * 108 / 66
try! FileManager.default.createDirectory(at: androidOutput, withIntermediateDirectories: true)
try! render(pixels: 432, units: androidUnits, drawBackground)
    .write(to: androidOutput.appendingPathComponent("ic_launcher_background.png"))
try! render(pixels: 432, units: androidUnits, drawForeground).write(to: androidOutput.appendingPathComponent("ic_launcher_foreground.png"))
try! render(pixels: 432, units: androidUnits, drawMonochrome).write(to: androidOutput.appendingPathComponent("ic_launcher_monochrome.png"))
print("Wrote \(images.count) macOS icons, the README icon and the Android icon layers")
