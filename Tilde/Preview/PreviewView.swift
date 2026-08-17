//
//  PreviewView.swift
//  Tilde
//

import SwiftUI
import AppKit

/// Read-only rendered Markdown for Preview mode (⌘⇧P).
///
/// Shares the editor's content width, padding, and semantic colors so
/// entering Preview reads as the syntax markers dissolving. Selection,
/// copy, and ⌘F Find come from the underlying `NSTextView` for free.
struct PreviewView: NSViewRepresentable {
    var document: TextDocument
    var fontSize: CGFloat
    /// Called when the user presses Esc to leave Preview.
    var onExit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        // Build the TextKit 1 stack explicitly: NSTextTable (used for
        // Markdown tables) is not supported by TextKit 2. The preview is
        // read-only and re-rendered per toggle, so TextKit 1 here is fine;
        // the editor stays on TextKit 2.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer()
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = ExitingTextView(frame: .zero, textContainer: container)
        textView.onExit = onExit
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: EditorTheme.padding, height: EditorTheme.padding)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        // Links open in the user's browser; nothing is editable.
        textView.isAutomaticLinkDetectionEnabled = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.render(document: document, fontSize: fontSize)

        // Become first responder so Esc (cancelOperation) reaches this view.
        // The find bar, when open, takes the responder chain first, so ⌘F's
        // own Esc still closes the search before this exits Preview.
        DispatchQueue.main.async { [weak textView] in
            textView?.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        (scrollView.documentView as? ExitingTextView)?.onExit = onExit
        context.coordinator.renderIfNeeded(document: document, fontSize: fontSize)
        context.coordinator.centerContent(in: scrollView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var textView: NSTextView?
        private var renderedText: String?
        private var renderedSize: CGFloat?

        func renderIfNeeded(document: TextDocument, fontSize: CGFloat) {
            if document.textStorage.string == renderedText, fontSize == renderedSize { return }
            render(document: document, fontSize: fontSize)
        }

        func render(document: TextDocument, fontSize: CGFloat) {
            guard let textView else { return }
            let rendered = MarkdownRenderer(fontSize: fontSize).render(document.textStorage.string)
            textView.textStorage?.setAttributedString(rendered)
            renderedText = document.textStorage.string
            renderedSize = fontSize
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
    }

    /// NSTextView that leaves Preview on Esc.
    private final class ExitingTextView: NSTextView {
        var onExit: (() -> Void)?
        override func cancelOperation(_ sender: Any?) { onExit?() }
    }
}
