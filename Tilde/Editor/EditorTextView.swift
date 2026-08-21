//
//  EditorTextView.swift
//  Tilde
//

import AppKit

/// The editor's `NSTextView`, subclassed only to paint one continuous
/// background behind fenced code blocks.
///
/// Code lines are tagged with `EditorTheme.codeBlockMarker` by the styler;
/// a per-character `.backgroundColor` would render as ragged per-line
/// strips, so instead the layout fragments of each contiguous marked run
/// are unioned and filled as a single rounded rectangle.
final class EditorTextView: NSTextView {
    /// Shifts the text container left of the symmetric `textContainerInset`
    /// so the two horizontal margins can differ: with the line-number gutter
    /// shown, the text needs only a small gap on the left (the gutter is the
    /// reading margin) but the full padding on the right.
    var textOriginShiftX: CGFloat = 0 {
        didSet {
            guard oldValue != textOriginShiftX else { return }
            needsLayout = true
            needsDisplay = true
        }
    }

    override var textContainerOrigin: NSPoint {
        var origin = super.textContainerOrigin
        origin.x -= textOriginShiftX
        return origin
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard
            let layoutManager = textLayoutManager,
            let contentManager = layoutManager.textContentManager,
            let textStorage,
            textStorage.length > 0
        else { return }

        // The band spans from the (possibly shifted) text origin on the left
        // to the mirrored margin on the right; total side margins stay
        // 2 × inset.width regardless of the shift.
        let inset = textContainerInset
        let originX = textContainerOrigin.x
        let fillRect = { (union: CGRect) -> NSRect in
            NSRect(
                x: originX,
                y: union.minY + inset.height,
                width: max(0, self.bounds.width - inset.width * 2),
                height: union.height
            )
        }

        EditorTheme.codeBackgroundColor.setFill()

        var union = CGRect.null
        func flush() {
            guard !union.isNull else { return }
            NSBezierPath(
                roundedRect: fillRect(union),
                xRadius: EditorTheme.codeCornerRadius,
                yRadius: EditorTheme.codeCornerRadius
            ).fill()
            union = .null
        }

        // Only walk the visible viewport so scrolling stays cheap.
        let viewport = layoutManager.textViewportLayoutController.viewportRange
            ?? layoutManager.documentRange
        let maxY = rect.maxY

        layoutManager.enumerateTextLayoutFragments(from: viewport.location, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            if frame.minY + inset.height > maxY { return false }

            let offset = contentManager.offset(
                from: contentManager.documentRange.location,
                to: fragment.rangeInElement.location
            )
            let isCode = offset < textStorage.length
                && textStorage.attribute(EditorTheme.codeBlockMarker, at: offset, effectiveRange: nil) != nil

            if isCode {
                union = union.union(frame)
            } else {
                flush()
            }
            return true
        }
        flush()
    }
}
