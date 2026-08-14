//
//  AppSettings.swift
//  Tilde
//

import AppKit
import SwiftUI

/// UserDefaults keys and defaults, in one place.
///
/// Settings are deliberately tiny (PRODUCT.md §22) — everything fits
/// on a single screen and lives in `@AppStorage`.
enum AppSettings {
    static let appearanceKey = "appearance"
    static let fontSizeKey = "fontSize"
    static let wordWrapKey = "wordWrap"
    static let lineNumbersKey = "lineNumbers"
    static let markdownStylingKey = "markdownStyling"

    static let defaultFontSize = 14.0
    static let fontSizeRange = 9.0...36.0
    static let defaultWordWrap = true
    static let defaultLineNumbers = false
    static let defaultMarkdownStyling = true
}

/// Light / Dark / System, applied app-wide via `NSApplication.appearance`.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    private var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    func apply() {
        NSApplication.shared.appearance = nsAppearance
    }

    static func applyAtLaunch() {
        let stored = UserDefaults.standard.string(forKey: AppSettings.appearanceKey)
        (stored.flatMap(AppearanceSetting.init(rawValue:)) ?? .system).apply()
    }
}
