//
//  FontZoom.swift
//  Tilde
//

import Foundation

/// Trackpad pinch → font size (#4), kept free of AppKit so the math is
/// testable with plain swiftc.
///
/// A pinch is accumulated from its start, so it feels continuous, but the
/// size it yields is always a whole point inside `range` — the same values
/// ⌘= / ⌘- and the Settings slider produce.
struct FontZoom {
    /// Points per unit of accumulated `NSEvent.magnification`. Conservative:
    /// a full "double the size" pinch (≈ 1.0) moves about 10pt.
    static let pointsPerMagnification = 10.0

    /// The size a pinch lands on: `base` moved by `magnification`, clamped
    /// to `range`, rounded to a whole point.
    static func fontSize(
        base: Double,
        magnification: Double,
        range: ClosedRange<Double>
    ) -> Double {
        let raw = base + magnification * pointsPerMagnification
        let clamped = min(max(raw, range.lowerBound), range.upperBound)
        return min(max(clamped.rounded(), range.lowerBound.rounded(.up)), range.upperBound.rounded(.down))
    }

    private var base: Double
    private var accumulated = 0.0
    private let range: ClosedRange<Double>

    /// Starts a pinch from the currently stored size.
    init(base: Double, range: ClosedRange<Double>) {
        self.base = base
        self.range = range
    }

    /// Adds one event's magnification and returns the new whole-point size
    /// only when it differs from `current`, so defaults aren't rewritten on
    /// every event.
    mutating func apply(_ magnification: Double, current: Double) -> Double? {
        // Clamp so overshooting a limit doesn't have to be unwound before
        // a reverse pinch takes effect.
        let k = Self.pointsPerMagnification
        accumulated = min(max(accumulated + magnification, (range.lowerBound - base) / k), (range.upperBound - base) / k)
        let size = Self.fontSize(base: base, magnification: accumulated, range: range)
        return size == current ? nil : size
    }
}
