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
        registerSelection(selectedRanges)
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        replaceCharacters(in: range, with: replacement)
        didChangeText()
        let after = [NSValue(range: selection)]
        selectedRanges = after
        // Registered after the text's undo, so it runs before the characters
        // change back: the selection that goes with the edited text, which
        // redo restores even if the caret moved before ⌘Z.
        registerSelection(after)
        return true
    }

    /// Registers selecting `ranges`, and when that runs, registers it again
    /// for the opposite direction. Each selection stays fixed to its own
    /// text state rather than to whatever was selected when undo ran.
    private func registerSelection(_ ranges: [NSValue]) {
        undoManager?.registerUndo(withTarget: self) { view in
            view.registerSelection(ranges)
            view.selectedRanges = ranges
        }
    }
}
