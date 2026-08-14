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

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidate),
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
            // Center against the fragment's first text line (wrapped
            // paragraphs are numbered once, at their top).
            let firstLineHeight = fragment.textLineFragments.first?.typographicBounds.height ?? frame.height
            label.draw(at: NSPoint(
                x: ruleThickness - labelSize.width - 8,
                y: y + (firstLineHeight - labelSize.height) / 2
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
