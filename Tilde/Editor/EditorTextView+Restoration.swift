//
//  EditorTextView+Restoration.swift
//  Tilde
//

import AppKit

/// Quitting keeps windows (#44), so untitled text comes back on the next
/// launch. A blank untitled window isn't worth bringing back: each relaunch
/// would add to the pile, on top of the blank window a launch that restores
/// nothing opens anyway (PRODUCT.md §10).
///
/// Two things bring a window back, and a blank untitled one is kept out of
/// both:
/// - The window's restorable state. It is turned off while the window is
///   blank, and kept current as the text changes rather than decided at
///   quit: AppKit has written the state by the time `willTerminate` arrives.
/// - The document's autosave record, which reopens an edited untitled
///   document even without its window's state. Text typed and then deleted
///   leaves the document edited, so its edits are cleared: there is nothing
///   to lose, and ⌘W closes it without asking, like a fresh window.
extension EditorTextView {
    override func didChangeText() {
        super.didChangeText()
        updateWindowRestorability()
    }

    func updateWindowRestorability() {
        guard let window else { return }
        // The storage's length, not `string`: this runs on every keystroke.
        let blank = isUntitled && textStorage?.length == 0
        if window.isRestorable == blank {
            window.isRestorable = !blank
        }
        if blank, let document = window.windowController?.document as? NSDocument,
           document.isDocumentEdited {
            document.updateChangeCount(.changeCleared)
        }
    }

    /// The document counts edits from its undo manager, sometimes after
    /// `didChangeText` has cleared them, so check again once it has:
    /// - An edit that opens its own undo group (⌘A then Delete) is counted
    ///   when the group closes at the end of the event.
    /// - Undo after typing and then deleting everything returns to the same
    ///   empty text, so `didChangeText` may not fire, but the undo counts as
    ///   an edit away from the cleared state.
    func observeUndoForRestorability() {
        for name in [
            Notification.Name.NSUndoManagerDidCloseUndoGroup,
            .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
        ] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(undoManagerDidChange(_:)), name: name, object: nil
            )
        }
    }

    @objc private func undoManagerDidChange(_ notification: Notification) {
        guard let undoManager, notification.object as? UndoManager === undoManager else { return }
        DispatchQueue.main.async { [weak self] in
            self?.updateWindowRestorability()
        }
    }
}
