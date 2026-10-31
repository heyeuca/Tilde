// Tests for NSTextView.replaceRestoringSelectionOnUndo, the edit path behind
// ⌘B / ⌘I / ⌘K and Tab / ⇧Tab: undo must bring back the selection that went with the text,
// and redo the selection after the edit (#42). Uses a real NSTextView and
// UndoManager, so it runs on macOS only.

import AppKit

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ name: String) {
    if condition { passed += 1; print("  ok  \(name)") }
    else { failed += 1; print("FAIL  \(name)") }
}

/// Supplies the undo manager a window would otherwise provide.
final class UndoHost: NSObject, NSTextViewDelegate {
    let undoManager: UndoManager = {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }()
    func undoManager(for view: NSTextView) -> UndoManager? { undoManager }
}

let host = UndoHost()

func makeTextView(_ text: String, selecting selection: NSRange) -> NSTextView {
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
    view.allowsUndo = true
    view.delegate = host
    view.string = text
    view.setSelectedRange(selection)
    host.undoManager.removeAllActions()
    return view
}

/// One undo group, like a menu command.
func edit(_ view: NSTextView, _ range: NSRange, _ replacement: String, _ selection: NSRange) -> Bool {
    host.undoManager.beginUndoGrouping()
    let applied = view.replaceRestoringSelectionOnUndo(range, with: replacement, selecting: selection)
    host.undoManager.endUndoGrouping()
    return applied
}

// MARK: - Bold a selected word, then undo / redo

do {
    let view = makeTextView("a word here", selecting: NSRange(location: 2, length: 4))
    expect(edit(view, NSRange(location: 2, length: 4), "**word**", NSRange(location: 4, length: 4)), "edit applied")
    expect(view.string == "a **word** here", "text after edit")
    expect(view.selectedRange() == NSRange(location: 4, length: 4), "selection after edit")

    host.undoManager.undo()
    expect(view.string == "a word here", "undo restores the text")
    expect(view.selectedRange() == NSRange(location: 2, length: 4), "undo restores the selected word (#42)")

    host.undoManager.redo()
    expect(view.string == "a **word** here", "redo reapplies the text")
    expect(view.selectedRange() == NSRange(location: 4, length: 4), "redo restores the selection after the edit")

    host.undoManager.undo()
    expect(view.selectedRange() == NSRange(location: 2, length: 4), "second undo still restores the selection")
}

// MARK: - Unbold, then undo

do {
    let view = makeTextView("a **word** here", selecting: NSRange(location: 4, length: 4))
    _ = edit(view, NSRange(location: 2, length: 8), "word", NSRange(location: 2, length: 4))
    expect(view.string == "a word here", "unbold text")
    host.undoManager.undo()
    expect(view.string == "a **word** here", "undo of unbold restores the markers")
    expect(view.selectedRange() == NSRange(location: 4, length: 4), "undo of unbold restores the inner selection")
}

// MARK: - Empty-selection insert, then undo

do {
    let view = makeTextView("ab", selecting: NSRange(location: 1, length: 0))
    _ = edit(view, NSRange(location: 1, length: 0), "****", NSRange(location: 3, length: 0))
    host.undoManager.undo()
    expect(view.string == "ab", "undo removes the inserted pair")
    expect(view.selectedRange() == NSRange(location: 1, length: 0), "undo puts the caret back")
}

// MARK: - Tab / ⇧Tab on selected lines, then undo / redo

do {
    let text = "one\ntwo\nthree"
    let selection = NSRange(location: 0, length: 7)
    let view = makeTextView(text, selecting: selection)
    let indent = IndentStyle.spaces(2).indent(in: text as NSString, selection: selection)
    _ = edit(view, indent.range, indent.replacement, indent.selection)
    expect(view.string == "  one\n  two\nthree", "indent text")
    expect(view.selectedRange() == indent.selection, "indent keeps the lines selected")
    host.undoManager.undo()
    expect(view.string == text, "undo of indent restores the text")
    expect(view.selectedRange() == selection, "undo of indent restores the selected lines")
    host.undoManager.redo()
    expect(view.selectedRange() == indent.selection, "redo of indent restores the selection after it")
}

do {
    let text = "  one\n  two\nthree"
    let selection = NSRange(location: 2, length: 9)
    let view = makeTextView(text, selecting: selection)
    guard let outdent = IndentStyle.spaces(2).outdent(in: text as NSString, selection: selection) else {
        fatalError("outdent returned nil")
    }
    _ = edit(view, outdent.range, outdent.replacement, outdent.selection)
    expect(view.string == "one\ntwo\nthree", "outdent text")
    host.undoManager.undo()
    expect(view.string == text, "undo of outdent restores the text")
    expect(view.selectedRange() == selection, "undo of outdent restores the selected lines")
}

// MARK: - Caret moved after the edit, then undo / redo

// Moving the caret isn't undoable, so redo must still land on the
// selection right after the edit, not on wherever the caret was moved.
do {
    let text = "one\ntwo\nthree"
    let selection = NSRange(location: 0, length: 7)
    let view = makeTextView(text, selecting: selection)
    let indent = IndentStyle.spaces(2).indent(in: text as NSString, selection: selection)
    _ = edit(view, indent.range, indent.replacement, indent.selection)
    view.setSelectedRange(NSRange(location: 3, length: 0))
    host.undoManager.undo()
    expect(view.selectedRange() == selection, "undo of indent after moving the caret restores the selected lines")
    host.undoManager.redo()
    expect(view.selectedRange() == indent.selection, "redo of indent after moving the caret restores the selection after it")
    host.undoManager.undo()
    expect(view.selectedRange() == selection, "second undo of indent restores the selected lines")
}

do {
    let text = "  one\n  two\nthree"
    let selection = NSRange(location: 2, length: 9)
    let view = makeTextView(text, selecting: selection)
    guard let outdent = IndentStyle.spaces(2).outdent(in: text as NSString, selection: selection) else {
        fatalError("outdent returned nil")
    }
    _ = edit(view, outdent.range, outdent.replacement, outdent.selection)
    view.setSelectedRange(NSRange(location: 1, length: 0))
    host.undoManager.undo()
    expect(view.selectedRange() == selection, "undo of outdent after moving the caret restores the selected lines")
    host.undoManager.redo()
    expect(view.selectedRange() == outdent.selection, "redo of outdent after moving the caret restores the selection after it")
}

// MARK: - Refused edit

do {
    let view = makeTextView("abc", selecting: NSRange(location: 0, length: 3))
    view.isEditable = false
    // Called outside an undo group: an empty group would still count as
    // undoable, so check the manager directly.
    expect(!view.replaceRestoringSelectionOnUndo(NSRange(location: 0, length: 3), with: "**abc**", selecting: NSRange(location: 2, length: 3)), "non-editable view refuses")
    expect(view.string == "abc", "refused edit leaves the text")
    expect(!host.undoManager.canUndo, "refused edit registers nothing")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
