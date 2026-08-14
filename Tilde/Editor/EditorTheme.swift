//
//  EditorTheme.swift
//  Tilde
//

import AppKit

/// Typography and layout tokens for the editor.
///
/// Colors are always macOS semantic colors; Tilde has no theme system.
enum EditorTheme {
    /// Body font size in points. User-adjustable in a later milestone (⌘+/⌘-).
    static let fontSize: CGFloat = 14

    /// Generous line height is the core of Tilde's readability.
    static let lineHeightMultiple: CGFloat = 1.5

    /// Horizontal and vertical breathing room around the text.
    static let padding: CGFloat = 28

    /// Markdown documents cap their content width so lines stay comfortable
    /// to read in a wide window. Plain text uses the full window width.
    static let maxContentWidth: CGFloat = 820

    /// Body font: proportional (SF Pro) for Markdown, monospaced (SF Mono)
    /// for plain text.
    static func bodyFont(monospaced: Bool) -> NSFont {
        monospaced
            ? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : .systemFont(ofSize: fontSize)
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        return style
    }

    /// The uniform attributes for body text.
    static func bodyAttributes(monospaced: Bool) -> [NSAttributedString.Key: Any] {
        [
            .font: bodyFont(monospaced: monospaced),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.textColor,
        ]
    }
}
