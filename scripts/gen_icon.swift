// Generates Tilde's app icon: a quiet paper-like rounded rect with a ~ glyph.
// Usage: swift gen_icon.swift <output-dir>

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// macOS icon grid: 1024 canvas, rounded rect 824x824 centered, radius ~185.
let canvas: CGFloat = 1024
let plateRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let plateRadius: CGFloat = 185

func drawIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let scale = CGFloat(size) / canvas
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    // Plate: soft paper gradient, top slightly lighter.
    let plate = NSBezierPath(roundedRect: plateRect, xRadius: plateRadius, yRadius: plateRadius)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.925, green: 0.922, blue: 0.913, alpha: 1),
        ending: NSColor(calibratedRed: 0.985, green: 0.984, blue: 0.980, alpha: 1)
    )!
    gradient.draw(in: plate, angle: 90)

    // No edge treatment: real-world icons sit on the translucent Dock and
    // blurred backdrops, and the subtle gradient keeps the plate readable.
    // (Apple bakes a soft shadow instead; strokes are used by no one.)

    // The ~ glyph, drawn as text and optically centered.
    let font = NSFont.systemFont(ofSize: 860, weight: .medium)
    let glyph = NSAttributedString(string: "~", attributes: [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1),
    ])
    // Use the tight glyph bounds, not the font's line box, to center.
    let line = CTLineCreateWithAttributedString(glyph)
    let bounds = CTLineGetImageBounds(line, NSGraphicsContext.current!.cgContext)
    let x = plateRect.midX - bounds.midX
    let y = plateRect.midY - bounds.midY
    NSGraphicsContext.current!.cgContext.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, NSGraphicsContext.current!.cgContext)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = drawIcon(size: size)
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("icon_\(size).png")
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent)")
}
