//
//  EditorTheme.swift
//  Tilde
//

import AppKit

/// Typography and layout tokens for the editor.
///
/// Colors are always macOS semantic colors; Tilde has no theme system.
/// Font-producing functions take the user's body size (⌘+/⌘-) as `size`.
enum EditorTheme {
    /// Default body font size in points.
    static let defaultFontSize: CGFloat = 14

    /// Generous line height is the core of Tilde's readability.
    static let lineHeightMultiple: CGFloat = 1.5

    /// Horizontal and vertical breathing room around the text.
    static let padding: CGFloat = 28

    /// Markdown documents cap their content width so lines stay comfortable
    /// to read in a wide window. Plain text uses the full window width.
    static let maxContentWidth: CGFloat = 820

    /// Body font: proportional (SF Pro) for Markdown, monospaced (SF Mono)
    /// for plain text.
    static func bodyFont(monospaced: Bool, size: CGFloat) -> NSFont {
        monospaced
            ? .monospacedSystemFont(ofSize: size, weight: .regular)
            : .systemFont(ofSize: size)
    }

    static func lineSpacing(for font: NSFont) -> CGFloat {
        let lineHeight = font.ascender - font.descender + font.leading
        return ((lineHeightMultiple - 1) * lineHeight).rounded()
    }

    /// Line rhythm via `lineSpacing` (space between lines) rather than
    /// `lineHeightMultiple` (taller line boxes): a taller line box makes the
    /// insertion point 1.5× the text height, which looks wrong.
    static func paragraphStyle(for font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing(for: font)
        return style
    }

    /// Empty lines carry their extra space as `paragraphSpacingBefore`
    /// instead of `lineSpacing`: TextKit 2 places lineSpacing above each
    /// line but swallows it INTO an empty line's line box (oversized caret,
    /// baseline hugging the previous line). spacingBefore keeps the
    /// baseline rhythm perfectly uniform and the caret text-height —
    /// verified empirically with a layout probe over all five spacing
    /// placements.
    static func emptyLineParagraphStyle(for font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = lineSpacing(for: font)
        return style
    }

    /// The uniform attributes for body text.
    static func bodyAttributes(monospaced: Bool, size: CGFloat) -> [NSAttributedString.Key: Any] {
        let font = bodyFont(monospaced: monospaced, size: size)
        return [
            .font: font,
            .paragraphStyle: paragraphStyle(for: font),
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
    static func codeFont(size: CGFloat) -> NSFont {
        .monospacedSystemFont(ofSize: size - 1, weight: .regular)
    }

    static func headingFont(level: Int, size: CGFloat) -> NSFont {
        switch level {
        case 1: .systemFont(ofSize: (size * 1.6).rounded(), weight: .bold)
        case 2: .systemFont(ofSize: (size * 1.45).rounded(), weight: .bold)
        case 3: .systemFont(ofSize: (size * 1.25).rounded(), weight: .bold)
        default: .systemFont(ofSize: (size * 1.05).rounded(), weight: .semibold)
        }
    }

    static func boldBodyFont(size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    static func italicBodyFont(size: CGFloat) -> NSFont {
        NSFontManager.shared.convert(bodyFont(monospaced: false, size: size), toHaveTrait: .italicFontMask)
    }

    static func listMarkerFont(size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .semibold)
    }

    // MARK: - Line number gutter

    static var gutterFont: NSFont {
        .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    }

    static var gutterColor: NSColor { .tertiaryLabelColor }

    /// When the gutter is shown it provides the left reading margin, so the
    /// text view's own horizontal inset shrinks to a small gap beside the
    /// numbers instead of the full `padding`.
    static let gutterTextInset: CGFloat = 6
}
