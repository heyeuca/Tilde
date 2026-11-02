// Tests for FontZoom, the pinch-to-zoom font size math (#4): direction,
// clamping to the settings range, whole-point snapping, and accumulation.

import Foundation

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ name: String) {
    if condition { passed += 1; print("  ok  \(name)") }
    else { failed += 1; print("FAIL  \(name)") }
}

let range = 9.0...36.0

func size(_ base: Double, _ m: Double) -> Double {
    FontZoom.fontSize(base: base, magnification: m, range: range)
}

// MARK: - Direction and snapping

expect(size(14, 0) == 14, "no magnification keeps the size")
expect(size(14, 0.2) == 16, "pinch out grows")
expect(size(14, -0.2) == 12, "pinch in shrinks")
expect(size(14, 0.04) == 14, "tiny pinch rounds back to the same size")
expect(size(14, 0.06) == 15, "just past half a point snaps up")
expect(size(14, 0.137).truncatingRemainder(dividingBy: 1) == 0, "result is a whole point")
expect(size(14.4, 0) == 14, "fractional stored size snaps to a whole point")

// MARK: - Clamping

expect(size(14, 10) == 36, "huge pinch out clamps at 36")
expect(size(14, -10) == 9, "huge pinch in clamps at 9")
expect(size(36, 0.3) == 36, "pinch out at max stays 36")
expect(size(9, -0.3) == 9, "pinch in at min stays 9")

// MARK: - Accumulation

do {
    var zoom = FontZoom(base: 14, range: range)
    var current = 14.0
    var writes: [Double] = []
    for _ in 0..<10 {
        if let s = zoom.apply(0.02, current: current) { writes.append(s); current = s }
    }
    expect(current == 16, "small events accumulate (10 × 0.02 → +2pt)")
    expect(writes == [15, 16], "writes only when the whole-point size changes")
    expect(zoom.apply(0, current: current) == nil, "no change, no write")
    for _ in 0..<10 { if let s = zoom.apply(-0.04, current: current) { current = s } }
    expect(current == 12, "pinch reverses within one gesture")
}

do {
    var zoom = FontZoom(base: 36, range: range)
    expect(zoom.apply(0.3, current: 36) == nil, "pinch out at max writes nothing")
    expect(zoom.apply(-0.2, current: 36) == 34, "reverse at max responds immediately")
    var low = FontZoom(base: 9, range: range)
    _ = low.apply(-0.5, current: 9)
    expect(low.apply(0.1, current: 9) == 10, "reverse at min responds immediately")
}

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
