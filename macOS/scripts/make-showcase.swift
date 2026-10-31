// Builds a README showcase image from Mac screenshots, in the same style as the Android ones:
// the screenshots side by side on a navy card, with a headline and a description line under each.
//
//   swift make-showcase.swift <output.png> "<screenshot.png>|<headline>|<description>[|<scale>[|<x,y,w,h>]]" ...
//
// Screenshots are Retina window captures (⌘⇧4, then Space), shadow included, so they're drawn
// as they are. <scale> enlarges one, e.g. 1.1 for the one in the middle. <x,y,w,h> crops a
// full-screen capture, in pixels from the top left, which is then drawn with rounded corners,
// e.g. the panel open under the menu bar.

import AppKit

struct Shot {
    let image: CGImage
    let headline: String
    let description: String
    let scale: CGFloat
    /// Cropped from a full-screen capture, so it needs its own rounded corners.
    let isCrop: Bool
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write("usage: make-showcase.swift <output.png> \"<screenshot>|<headline>|<description>[|<scale>[|<x,y,w,h>]]\" ...\n".data(using: .utf8)!)
    exit(1)
}

let shots: [Shot] = arguments.dropFirst(2).map { spec in
    let parts = spec.components(separatedBy: "|")
    guard parts.count >= 3, let data = FileManager.default.contents(atPath: parts[0]),
          let source = NSBitmapImageRep(data: data)?.cgImage else {
        FileHandle.standardError.write("can't read \(spec)\n".data(using: .utf8)!)
        exit(1)
    }
    var image = source
    if parts.count > 4 {
        let n = parts[4].split(separator: ",").compactMap { Int($0) }
        image = source.cropping(to: CGRect(x: n[0], y: n[1], width: n[2], height: n[3]))!
    }
    return Shot(image: image, headline: parts[1], description: parts[2],
                scale: parts.count > 3 ? CGFloat(Double(parts[3]) ?? 1) : 1, isCrop: parts.count > 4)
}

// MARK: - Layout

/// Each screenshot fits a box this size at scale 1, in points (half its Retina pixels at most).
let box = CGSize(width: 420, height: 560)
let headlineSize: CGFloat = 30
let descriptionSize: CGFloat = 22
let gap: CGFloat = 70
let margin: CGFloat = 70

func drawnSize(_ shot: Shot) -> CGSize {
    let width = CGFloat(shot.image.width), height = CGFloat(shot.image.height)
    let fit = min(box.width * shot.scale / width, box.height * shot.scale / height, 0.5 * shot.scale)
    return CGSize(width: width * fit, height: height * fit)
}

/// Each column is as wide as its screenshot, but never narrower than its captions need.
func columnWidth(_ shot: Shot) -> CGFloat { max(drawnSize(shot).width, 380) }

let tallest = shots.map { drawnSize($0).height }.max()!
let canvas = CGSize(width: margin * 2 + shots.map(columnWidth).reduce(0, +) + gap * CGFloat(shots.count - 1),
                    height: margin + tallest + 56 + headlineSize + descriptionSize + 24 + margin)

/// Pixels per point in the output: about as wide as the Android showcases.
let pixelScale: CGFloat = 1.4
let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * pixelScale), pixelsHigh: Int(canvas.height * pixelScale),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: output)!
NSGraphicsContext.current = context
context.imageInterpolation = .high
let cg = context.cgContext
cg.scaleBy(x: pixelScale, y: pixelScale)

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

// MARK: - Screenshots and captions

var left = margin
for shot in shots {
    let column = columnWidth(shot)
    let center = left + column / 2
    left += column + gap
    let size = drawnSize(shot)
    let frame = rect(center - size.width / 2, margin + (tallest - size.height) / 2, size.width, size.height)

    if shot.isCrop {
        // A piece of the screen: rounded, with a thin rim and a shadow like a window's.
        let radius: CGFloat = 18
        let path = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: color(0x000000, 0.45))
        cg.addPath(path)
        cg.setFillColor(color(0x000000))
        cg.fillPath()
        cg.restoreGState()
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        cg.draw(shot.image, in: frame)
        cg.restoreGState()
        cg.addPath(path)
        cg.setStrokeColor(color(0xFFFFFF, 0.18))
        cg.setLineWidth(1.5)
        cg.strokePath()
    } else {
        cg.draw(shot.image, in: frame)
    }

    // The headline and its description, centred under the screenshot.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let captionTop = margin + tallest + 56
    let width = column + gap
    NSAttributedString(string: shot.headline, attributes: [
        .font: NSFont.systemFont(ofSize: headlineSize, weight: .semibold),
        .foregroundColor: NSColor(cgColor: color(0xEFF0F2))!, .paragraphStyle: paragraph,
    ]).draw(in: rect(center - width / 2, captionTop, width, headlineSize * 1.3))
    NSAttributedString(string: shot.description, attributes: [
        .font: NSFont.systemFont(ofSize: descriptionSize),
        .foregroundColor: NSColor(cgColor: color(0xBCBFC5))!, .paragraphStyle: paragraph,
    ]).draw(in: rect(center - width / 2, captionTop + headlineSize * 1.35, width, descriptionSize * 1.4))
}

NSGraphicsContext.restoreGraphicsState()
try! output.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arguments[1]))
