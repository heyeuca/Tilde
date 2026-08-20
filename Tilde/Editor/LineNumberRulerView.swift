//
//  LineNumberRulerView.swift
//  Tilde
//

import AppKit

/// A minimal line-number gutter for a TextKit 2 `NSTextView`.
///
/// Off by default (PRODUCT.md §12); when enabled its UI stays as subtle
/// as possible — small tertiary-colored digits, no separator, background
/// matching the editor.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    /// Space left of the digits (the reading margin) and between the digits
    /// and the text.
    private let leadingPadding: CGFloat = 14
    private let trailingPadding: CGFloat = 10

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        updateThickness()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textChanged),
            name: NSText.didChangeNotification,
            object: textView
        )
        // Re-wrapping (word wrap toggle, window resize) changes the text
        // view's frame without a text change; redraw the numbers then too.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidate),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
        if let contentView = scrollView.contentView as NSClipView? {
            contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(invalidate),
                name: NSView.boundsDidChangeNotification,
                object: contentView
            )
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func invalidate() {
        needsDisplay = true
    }

    @objc private func textChanged() {
        updateThickness()
        needsDisplay = true
    }

    /// Width fits the document's largest line number: the gutter is snug for a
    /// short file and only widens when the line count grows another digit.
    /// Newlines are counted with a search loop — splitting the whole string
    /// into substrings per keystroke would thrash memory on large files.
    private func updateThickness() {
        var lineCount = 1
        if let string = textView?.string as NSString? {
            var location = 0
            while location < string.length {
                let found = string.range(
                    of: "\n",
                    range: NSRange(location: location, length: string.length - location)
                )
                guard found.location != NSNotFound else { break }
                lineCount += 1
                location = found.location + 1
            }
        }
        let digits = max(2, String(max(lineCount, 1)).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: EditorTheme.gutterFont]).width
        let thickness = (leadingPadding + digitWidth * CGFloat(digits) + trailingPadding).rounded(.up)
        if ruleThickness != thickness { ruleThickness = thickness }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.textLayoutManager,
            let contentManager = layoutManager.textContentManager
        else { return }

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let string = textView.string as NSString
        guard string.length > 0 else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: EditorTheme.gutterFont,
            .foregroundColor: EditorTheme.gutterColor,
        ]
        let insetY = textView.textContainerInset.height
        let visibleMaxY = textView.visibleRect.maxY
        let viewport = layoutManager.textViewportLayoutController.viewportRange
            ?? layoutManager.documentRange

        // Paragraph == line (fragments never span a newline), so number the
        // first visible fragment by counting, then increment per fragment.
        var lineNumber: Int? = nil

        layoutManager.enumerateTextLayoutFragments(from: viewport.location, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            let yInTextView = frame.minY + insetY
            guard yInTextView <= visibleMaxY else { return false }

            let offset = contentManager.offset(
                from: contentManager.documentRange.location,
                to: fragment.rangeInElement.location
            )
            if lineNumber == nil {
                lineNumber = Self.lineNumber(at: offset, in: string)
            }
            guard let current = lineNumber else { return false }

            let label = NSAttributedString(string: String(current), attributes: attributes)
            let labelSize = label.size()
            let y = convert(NSPoint(x: 0, y: yInTextView), from: textView).y
            // Align the number's baseline with the text baseline of the
            // fragment's first line (wrapped paragraphs are numbered once).
            var labelY = y
            if let firstLine = fragment.textLineFragments.first {
                // The LINE's own font (headings are larger, empty lines carry
                // body attributes) — alignment must follow it, not the body.
                let fallbackFont = (textView.typingAttributes[.font] as? NSFont)
                    ?? EditorTheme.bodyFont(monospaced: false, size: EditorTheme.defaultFontSize)
                let lineFont: NSFont = {
                    guard let storage = textView.textStorage, offset < storage.length else { return fallbackFont }
                    return storage.attribute(.font, at: offset, effectiveRange: nil) as? NSFont ?? fallbackFont
                }()

                let bounds = firstLine.typographicBounds
                let baseline: CGFloat
                if firstLine.characterRange.length > 1 || firstLine.glyphOrigin.y > 0 {
                    baseline = bounds.minY + firstLine.glyphOrigin.y
                } else {
                    // Empty line: no glyphs to anchor to, so derive the
                    // baseline from the line font's own metrics.
                    baseline = bounds.minY + lineFont.ascender
                }
                // Optical centering: the gutter font is smaller than the
                // line's text, so raw baseline alignment sits visually low.
                // Align the cap-height centers instead — this degrades to
                // plain baseline alignment when the sizes match.
                let capCentering = (lineFont.capHeight - EditorTheme.gutterFont.capHeight) / 2
                labelY = y + baseline - capCentering - EditorTheme.gutterFont.ascender
            }
            label.draw(at: NSPoint(
                x: ruleThickness - labelSize.width - trailingPadding,
                y: labelY
            ))

            lineNumber = current + 1
            return true
        }
    }

    /// 1-based line number for a character offset (count of preceding newlines).
    static func lineNumber(at offset: Int, in string: NSString) -> Int {
        var count = 1
        var location = 0
        while location < offset {
            let found = string.range(
                of: "\n",
                range: NSRange(location: location, length: offset - location)
            )
            guard found.location != NSNotFound else { break }
            count += 1
            location = found.location + 1
        }
        return count
    }
}
