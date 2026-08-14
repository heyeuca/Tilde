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
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 24, height: 24)

        // Layout: grow vertically, wrap to the view's width.
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        textView.string = document.text

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
        }
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

        init(parent: TextEditorView) {
            self.parent = parent
        }

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
