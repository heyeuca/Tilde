//
//  BlankWindowShortcut.swift
//  Tilde
//

#if canImport(KeyboardShortcuts)
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// No initial shortcut: it does nothing until one is recorded in
    /// Settings (#62).
    static let openBlankWindow = Self("openBlankWindow")
}

/// The global shortcut that brings up a blank window from any app (#62).
///
/// It works only while Tilde is running. Pressing it activates Tilde and
/// brings forward the frontmost untitled window that has no text, or opens
/// a new untitled document when there is none, so repeated presses don't
/// pile up blank windows.
enum BlankWindowShortcut {
    static func startListening() {
        KeyboardShortcuts.onKeyDown(for: .openBlankWindow) {
            openBlankWindow()
        }
    }

    private static func openBlankWindow() {
        NSApp.activate()
        if let window = NSApp.orderedWindows.first(where: isBlankUntitled) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSDocumentController.shared.newDocument(nil)
        }
    }

    private static func isBlankUntitled(_ window: NSWindow) -> Bool {
        guard let document = window.windowController?.document as? NSDocument,
              document.fileURL == nil,
              let textView = window.contentView.flatMap(editorTextView(in:))
        else { return false }
        return textView.textStorage?.length == 0
    }

    private static func editorTextView(in view: NSView) -> EditorTextView? {
        if let textView = view as? EditorTextView { return textView }
        for subview in view.subviews {
            if let textView = editorTextView(in: subview) { return textView }
        }
        return nil
    }
}
#endif
