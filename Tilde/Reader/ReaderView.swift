//
//  ReaderView.swift
//  Tilde
//

import SwiftUI
import AppKit

/// Read-only rendered Markdown for Reader mode (⌘⇧R).
///
/// Shares the editor's content width, padding, and semantic colors so
/// entering Reader reads as the syntax markers dissolving. Selection,
/// copy, and ⌘F Find come from the underlying `NSTextView` for free.
struct ReaderView: NSViewRepresentable {
    var document: TextDocument
    var fontSize: CGFloat
    /// Asks the editor for its reading position (fraction of characters
    /// above the viewport top) so Reader opens at the same place instead of
    /// the top. Read at makeNSView time — the editor is still mounted
    /// underneath — so ANY entry path gets position restore for free.
    var entryFraction: () -> CGFloat = { 0 }
    /// Called when the user presses Esc to leave Reader.
    var onExit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        // Build the TextKit 1 stack explicitly: NSTextTable (used for
        // Markdown tables) is not supported by TextKit 2. The preview is
        // read-only and re-rendered per toggle, so TextKit 1 here is fine;
        // the editor stays on TextKit 2.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        // Read-only view: non-contiguous layout lets the entry-position
        // scroll estimate the height above its target instead of laying out
        // the whole prefix on the main thread.
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)
        // Width tracks the view; height is unbounded so the text view grows to
        // fit all content and the scroll view can reach the bottom.
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)

        let textView = ExitingTextView(frame: .zero, textContainer: container)
        textView.onExit = onExit
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: EditorTheme.padding, height: EditorTheme.padding)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        // Links open in the user's browser; nothing is editable.
        textView.isAutomaticLinkDetectionEnabled = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView

        context.coordinator.textView = textView
        // Capture the editor's position now; restore it only in the deferred
        // render below — at this point the view has no window and a zero
        // frame, so a scroll here would be computed against bogus geometry
        // and thrown away one runloop later anyway.
        let entry = entryFraction()
        context.coordinator.render(document: document, fontSize: fontSize)

        // Re-center the capped content column when the window resizes;
        // updateNSView alone doesn't fire on live resize.
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )

        // Become first responder so Esc (cancelOperation) reaches this view,
        // and re-render now that the window (and its represented URL, used to
        // resolve relative image paths) is available.
        // The find bar, when open, takes the responder chain first, so ⌘F's
        // own Esc still closes the search before this exits Reader.
        DispatchQueue.main.async { [weak textView] in
            textView?.window?.makeFirstResponder(textView)
            context.coordinator.render(document: document, fontSize: fontSize, restoringFraction: entry)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        (scrollView.documentView as? ExitingTextView)?.onExit = onExit
        context.coordinator.renderIfNeeded(document: document, fontSize: fontSize)
        context.coordinator.centerContent(in: scrollView)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var textView: NSTextView?
        private var renderedText: String?
        private var renderedSize: CGFloat?
        /// Bumped per render so a slow background render can tell if it has
        /// been superseded before it installs its result.
        private var generation = 0

        /// Documents at or below this size render synchronously (no flash);
        /// larger ones render off the main thread so ⌘⇧P never freezes.
        private static let syncThreshold = 256 * 1024

        func renderIfNeeded(document: TextDocument, fontSize: CGFloat) {
            if document.textStorage.string == renderedText, fontSize == renderedSize { return }
            render(document: document, fontSize: fontSize)
        }

        func render(document: TextDocument, fontSize: CGFloat, restoringFraction: CGFloat? = nil) {
            guard let textView else { return }
            let text = document.textStorage.string
            let baseURL = textView.window?.representedURL?.deletingLastPathComponent()
            renderedText = text
            renderedSize = fontSize
            generation += 1
            let token = generation
            let renderer = MarkdownRenderer(fontSize: fontSize, baseURL: baseURL)

            if text.utf8.count <= Self.syncThreshold {
                textView.textStorage?.setAttributedString(renderer.render(text))
                if let restoringFraction { scroll(toCharacterFraction: restoringFraction) }
                return
            }

            // Apple's Markdown parser dominates the cost on multi-hundred-KB
            // documents and cannot be sped up, so render off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let rendered = renderer.render(text)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == token, let textView = self.textView else { return }
                    textView.textStorage?.setAttributedString(rendered)
                    if let restoringFraction { self.scroll(toCharacterFraction: restoringFraction) }
                }
            }
        }

        /// Scrolls so the character at `fraction` of the rendered text sits at
        /// the top of the viewport — an approximate but cheap mapping of the
        /// editor's position (source and rendered lengths differ only by the
        /// dissolved markers).
        private func scroll(toCharacterFraction fraction: CGFloat) {
            guard
                fraction > 0,
                let textView,
                let layoutManager = textView.layoutManager
            else { return }
            let length = (textView.string as NSString).length
            guard length > 0 else { return }

            let target = min(length - 1, Int(CGFloat(length) * fraction))
            // Lay out only the target's own range: with non-contiguous
            // layout TextKit estimates the height above it, so a large
            // document doesn't pay a full main-thread layout pass here.
            layoutManager.ensureLayout(forCharacterRange: NSRange(location: target, length: 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: target)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            textView.scroll(NSPoint(x: 0, y: lineRect.minY + textView.textContainerInset.height))
        }

        /// Markdown content is capped and centered like the editor.
        func centerContent(in scrollView: NSScrollView) {
            guard let textView else { return }
            let excess = scrollView.contentSize.width - EditorTheme.maxContentWidth
            let horizontal = max(EditorTheme.padding, excess / 2)
            let inset = NSSize(width: horizontal, height: EditorTheme.padding)
            if textView.textContainerInset != inset {
                textView.textContainerInset = inset
            }
        }

        @objc func viewFrameDidChange(_ notification: Notification) {
            guard let scrollView = textView?.enclosingScrollView else { return }
            centerContent(in: scrollView)
        }
    }

    /// NSTextView that leaves Reader on Esc.
    private final class ExitingTextView: NSTextView {
        var onExit: (() -> Void)?
        override func cancelOperation(_ sender: Any?) { onExit?() }
    }
}
