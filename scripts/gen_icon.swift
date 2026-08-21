// Generates Tilde's app icon: a quiet paper-like rounded rect with a ~ glyph.
//
// Emits the exact filenames AppIcon.appiconset consumes (icon_16.png,
// icon_16@2x.png, … icon_512@2x.png), so regeneration is one command with
// no manual renaming:
//   swift gen_icon.swift ../Tilde/Assets.xcassets/AppIcon.appiconset
//
// Two size-specific treatments, per Apple's guidance to simplify small sizes:
// - Standard (point size ≥ 128): medium-weight glyph on the paper gradient.
// - Small (point size ≤ 32): heavier, larger glyph on a slightly darker
//   plate so the tilde still reads at 16 px in Finder lists and Open With.
// Both bake Apple's standard soft drop shadow into the artwork (the Big Sur
// template look) so the plate's near-white top edge keeps its silhouette on
// light backgrounds — Finder, Spotlight, the About panel.

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// macOS icon grid: 1024 canvas, rounded rect 824x824 centered, radius ~185.
let canvas: CGFloat = 1024
let plateRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let plateRadius: CGFloat = 185

struct Treatment {
    var glyphWeight: NSFont.Weight
    var glyphSize: CGFloat
    var plateTop: NSColor
    var plateBottom: NSColor
}

let standard = Treatment(
    glyphWeight: .medium,
    glyphSize: 860,
    plateTop: NSColor(calibratedRed: 0.985, green: 0.984, blue: 0.980, alpha: 1),
    plateBottom: NSColor(calibratedRed: 0.925, green: 0.922, blue: 0.913, alpha: 1)
)

// Small sizes: the standard tilde's ink is only ~427x131 on the 1024 grid —
// a ~7x2 px smear at 16 px. Draw it heavier and wider (~76% of the plate)
// on a slightly darker plate so the waveform survives antialiasing.
let small = Treatment(
    glyphWeight: .heavy,
    glyphSize: 1240,
    plateTop: NSColor(calibratedRed: 0.965, green: 0.963, blue: 0.958, alpha: 1),
    plateBottom: NSColor(calibratedRed: 0.895, green: 0.892, blue: 0.882, alpha: 1)
)

func drawIcon(pixels: Int, treatment: Treatment) -> NSBitmapImageRep {
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
    treatment.plateBottom.setFill()
    plate.fill()
    cg.restoreGState()

    // Plate: soft paper gradient, top slightly lighter.
    let gradient = NSGradient(starting: treatment.plateBottom, ending: treatment.plateTop)!
    gradient.draw(in: plate, angle: 90)

    // The ~ glyph, drawn as text and optically centered.
    let font = NSFont.systemFont(ofSize: treatment.glyphSize, weight: treatment.glyphWeight)
    let glyph = NSAttributedString(string: "~", attributes: [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1),
    ])
    // Use the tight glyph bounds, not the font's line box, to center.
    let line = CTLineCreateWithAttributedString(glyph)
    let bounds = CTLineGetImageBounds(line, cg)
    let x = plateRect.midX - bounds.midX
    let y = plateRect.midY - bounds.midY
    cg.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, cg)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// (filename, pixel size, treatment) — @2x slots use the artwork of their
// POINT size: icon_16@2x is seen at 16 pt on Retina, so it gets the small
// treatment drawn at 32 px.
let slots: [(String, Int, Treatment)] = [
    ("icon_16.png", 16, small),
    ("icon_16@2x.png", 32, small),
    ("icon_32.png", 32, small),
    ("icon_32@2x.png", 64, small),
    ("icon_128.png", 128, standard),
    ("icon_128@2x.png", 256, standard),
    ("icon_256.png", 256, standard),
    ("icon_256@2x.png", 512, standard),
    ("icon_512.png", 512, standard),
    ("icon_512@2x.png", 1024, standard),
]

for (name, pixels, treatment) in slots {
    let rep = drawIcon(pixels: pixels, treatment: treatment)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent)")
}
