//
//  TextEditorView.swift
//  Tilde
//

import SwiftUI
import AppKit

/// Wraps an AppKit `NSTextView` (TextKit 2) for SwiftUI.
///
/// Undo, Find, spell checking, IME, and drag & drop all come from the
/// system text view — Tilde switches them on rather than building them.
struct TextEditorView: NSViewRepresentable {
    @ObservedObject var document: TextDocument

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.delegate = context.coordinator

        // Editing behavior
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        // Plain-text editor: smart quotes/dashes would corrupt code and config files.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Appearance
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: EditorTheme.padding, height: EditorTheme.padding)

        // Layout: grow vertically, wrap to the view's width.
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        if document.isMarkdown {
            let styler = MarkdownStyler()
            context.coordinator.styler = styler
            textView.textStorage?.delegate = styler
        }

        context.coordinator.applyTypography(to: textView)
        textView.string = document.text
        context.coordinator.restyleAll(textView)

        // Markdown caps its content width; recompute the insets as the
        // window resizes.
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.undoManager = context.environment.undoManager

        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Push external changes (e.g. Revert To) into the view
        // without clobbering in-flight local edits.
        if !context.coordinator.isEditing, textView.string != document.text {
            textView.string = document.text
            context.coordinator.restyleAll(textView)
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorView
        /// The document's undo manager (from the SwiftUI environment), so text
        /// edits drive the window's dirty state, autosave, and ⌘Z.
        var undoManager: UndoManager?
        var isEditing = false
        /// Attribute-only Markdown styling; present only for Markdown documents.
        var styler: MarkdownStyler?

        init(parent: TextEditorView) {
            self.parent = parent
        }

        // MARK: - Typography

        /// Sets up body typography for future typing.
        func applyTypography(to textView: NSTextView) {
            textView.typingAttributes = EditorTheme.bodyAttributes(monospaced: !parent.document.isMarkdown)
            textView.defaultParagraphStyle = EditorTheme.paragraphStyle
            updateContentInsets(of: textView)
        }

        /// Restyles the whole buffer: Markdown via the styler, plain text flat.
        func restyleAll(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            if let styler {
                styler.restyleAll(textStorage)
            } else {
                let attributes = EditorTheme.bodyAttributes(monospaced: !parent.document.isMarkdown)
                textStorage.setAttributes(attributes, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        /// Markdown documents keep their content no wider than
        /// `EditorTheme.maxContentWidth`, centered; plain text uses the full width.
        func updateContentInsets(of textView: NSTextView) {
            var horizontal = EditorTheme.padding
            if parent.document.isMarkdown {
                let excess = textView.frame.width - EditorTheme.maxContentWidth
                horizontal = max(EditorTheme.padding, excess / 2)
            }
            let inset = NSSize(width: horizontal, height: EditorTheme.padding)
            if textView.textContainerInset != inset {
                textView.textContainerInset = inset
            }
        }

        @objc func viewFrameDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateContentInsets(of: textView)
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.document.text = textView.string
            isEditing = false
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            undoManager
        }
    }
}
