//
//  NSTextView+UndoableEdit.swift
//  Tilde
//

import AppKit

extension NSTextView {
    /// Replaces `range` the way typing does — `shouldChangeText` registers
    /// undo and `didChangeText` notifies the delegate — then selects
    /// `selection`. The selection from before the edit and the one after it
    /// are registered with the undo manager too, so ⌘Z brings back the text
    /// *and* the selection, and ⌘⇧Z the edited text with its selection.
    /// Returns false when the edit was refused.
    @discardableResult
    func replaceRestoringSelectionOnUndo(_ range: NSRange, with replacement: String, selecting selection: NSRange) -> Bool {
        guard isEditable else { return false }
        // Undo runs registrations in reverse, so registering this before
        // shouldChangeText (where the text's own undo is registered) makes it
        // run after the characters are back, overriding the caret AppKit
        // leaves there.
        let before = selectedRanges
        undoManager?.registerUndo(withTarget: self) { $0.setSelectedRangesRegisteringUndo(before) }
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRangesRegisteringUndo([NSValue(range: selection)])
        return true
    }

    /// Selects `ranges` and registers the current selection as its undo, so
    /// undo and redo each land on the selection that went with their text.
    private func setSelectedRangesRegisteringUndo(_ ranges: [NSValue]) {
        let current = selectedRanges
        undoManager?.registerUndo(withTarget: self) { $0.setSelectedRangesRegisteringUndo(current) }
        selectedRanges = ranges
    }
}
