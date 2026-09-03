// Generates Tilde's app icon: a quiet paper-like rounded rect with a ~ glyph.
//
// Emits the exact filenames AppIcon.appiconset consumes (icon_16.png,
// icon_16@2x.png, … icon_512@2x.png), so regeneration is one command with
// no manual renaming:
//   swift gen_icon.swift ../Tilde/Assets.xcassets/AppIcon.appiconset
//
// One drawing, every size: the medium-weight "~" on the paper gradient,
// rasterized as-is for each slot. No small-size variant — the 16 px icon is
// the 1024 px icon, smaller (at 16 px the tilde is a soft two-pixel mark;
// Retina's 32 px already shows the wave). The artwork bakes Apple's standard
// soft drop shadow (the Big Sur template look) so the plate's near-white top
// edge keeps its silhouette on light backgrounds — Finder, Spotlight, the
// About panel.

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// macOS icon grid: 1024 canvas, rounded rect 824x824 centered, radius ~185.
let canvas: CGFloat = 1024
let plateRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let plateRadius: CGFloat = 185

let inkColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
let glyphWeight = NSFont.Weight.medium
let glyphSize: CGFloat = 860
let plateTop = NSColor(calibratedRed: 0.985, green: 0.984, blue: 0.980, alpha: 1)
let plateBottom = NSColor(calibratedRed: 0.925, green: 0.922, blue: 0.913, alpha: 1)

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext

    let scale = CGFloat(pixels) / canvas
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    // Baked drop shadow behind the plate, matching Apple's icon template
    // (~28% black, 10 px down, 20 px blur at 1024). CGContext shadow
    // parameters live in base space, so scale them with the render size.
    let plate = NSBezierPath(roundedRect: plateRect, xRadius: plateRadius, yRadius: plateRadius)
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -10 * scale),
        blur: 20 * scale,
        color: CGColor(gray: 0, alpha: 0.28)
    )
    // Fill once (flat) to cast the shadow; the gradient is painted over it.
    plateBottom.setFill()
    plate.fill()
    cg.restoreGState()

    // Plate: soft paper gradient, top slightly lighter.
    let gradient = NSGradient(starting: plateBottom, ending: plateTop)!
    gradient.draw(in: plate, angle: 90)

    // The ~ glyph, drawn as text and optically centered.
    let font = NSFont.systemFont(ofSize: glyphSize, weight: glyphWeight)
    let glyph = NSAttributedString(string: "~", attributes: [
        .font: font,
        .foregroundColor: inkColor,
    ])
    // Use the tight glyph bounds, not the font's line box, to center.
    let line = CTLineCreateWithAttributedString(glyph)
    let bounds = CTLineGetImageBounds(line, cg)
    cg.textPosition = CGPoint(x: plateRect.midX - bounds.midX, y: plateRect.midY - bounds.midY)
    CTLineDraw(line, cg)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// (filename, pixel size)
let slots: [(String, Int)] = [
    ("icon_16.png", 16),
    ("icon_16@2x.png", 32),
    ("icon_32.png", 32),
    ("icon_32@2x.png", 64),
    ("icon_128.png", 128),
    ("icon_128@2x.png", 256),
    ("icon_256.png", 256),
    ("icon_256@2x.png", 512),
    ("icon_512.png", 512),
    ("icon_512@2x.png", 1024),
]

for (name, pixels) in slots {
    let rep = drawIcon(pixels: pixels)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent)")
}
