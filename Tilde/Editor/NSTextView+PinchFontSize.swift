//
//  NSTextView+PinchFontSize.swift
//  Tilde
//

import AppKit

/// Shared `magnify(with:)` body for the editor and Reader text views (#4).
/// Writes through the same `fontSizeKey` default that `@AppStorage`, the
/// View menu, and the Settings slider use, so all stay one source of truth.
final class PinchFontSizeTracker {
    private var zoom: FontZoom?

    func handle(_ event: NSEvent) {
        let defaults = UserDefaults.standard
        let stored = defaults.object(forKey: AppSettings.fontSizeKey) as? Double ?? AppSettings.defaultFontSize
        if event.phase == .began || zoom == nil {
            zoom = FontZoom(base: stored, range: AppSettings.fontSizeRange)
        }
        if let size = zoom?.apply(Double(event.magnification), current: stored) {
            defaults.set(size, forKey: AppSettings.fontSizeKey)
        }
        if event.phase == .ended || event.phase == .cancelled {
            zoom = nil
        }
    }
}
