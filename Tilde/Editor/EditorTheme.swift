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

    // MARK: - Markdown styling tokens

    /// Syntax markers (`#`, `**`, `` ` ``…) stay visible but recede.
    static var markerColor: NSColor { .tertiaryLabelColor }

    static var quoteColor: NSColor { .secondaryLabelColor }

    static var linkColor: NSColor { .linkColor }

    /// Subtle fill behind inline code and code blocks.
    static var codeBackgroundColor: NSColor { .quaternarySystemFill }

    /// Code spans/blocks sit a point smaller so the monospaced face
    /// doesn't look oversized next to SF Pro.
    static var codeFont: NSFont {
        .monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
    }

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: .systemFont(ofSize: (fontSize * 1.6).rounded(), weight: .bold)
        case 2: .systemFont(ofSize: (fontSize * 1.45).rounded(), weight: .bold)
        case 3: .systemFont(ofSize: (fontSize * 1.25).rounded(), weight: .bold)
        default: .systemFont(ofSize: (fontSize * 1.05).rounded(), weight: .semibold)
        }
    }

    static var boldBodyFont: NSFont {
        .systemFont(ofSize: fontSize, weight: .bold)
    }

    static var italicBodyFont: NSFont {
        NSFontManager.shared.convert(bodyFont(monospaced: false), toHaveTrait: .italicFontMask)
    }

    static var listMarkerFont: NSFont {
        .systemFont(ofSize: fontSize, weight: .semibold)
    }
}
