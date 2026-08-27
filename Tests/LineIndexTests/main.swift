// Tests for LineIndex, the gutter's incremental newline index: correctness
// of incremental edits against full rescans (including a randomized fuzz),
// and a loose performance bound that would catch an O(n)-per-edit
// regression on large documents (2026-08 app review P2).

import Foundation

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ name: String) {
    if condition { passed += 1; print("  ok  \(name)") }
    else { failed += 1; print("FAIL  \(name)") }
}

/// Applies `replacement` over `range` of `text` and mirrors the edit into
/// `index` the way NSTextStorage reports it: editedRange is the
/// replacement's range in the NEW text, delta the length change.
func apply(_ replacement: String, over range: NSRange, to text: NSMutableString, index: inout LineIndex) {
    text.replaceCharacters(in: range, with: replacement)
    let newLength = (replacement as NSString).length
    index.applyEdit(
        editedRange: NSRange(location: range.location, length: newLength),
        changeInLength: newLength - range.length,
        in: text
    )
}

// MARK: - Initial scan

do {
    expect(LineIndex(string: "" as NSString).lineCount == 1, "empty text is one line")
    expect(LineIndex(string: "abc" as NSString).lineCount == 1, "no newline is one line")
    expect(LineIndex(string: "a\nb\nc" as NSString).lineCount == 3, "two newlines are three lines")
    expect(LineIndex(string: "a\nb\nc\n" as NSString).lineCount == 4, "trailing newline opens a final line")
    expect(LineIndex(string: "\n\n\n" as NSString).lineCount == 4, "consecutive newlines counted")
}

// MARK: - Line number lookup

do {
    let index = LineIndex(string: "ab\ncd\nef" as NSString)
    expect(index.lineNumber(atCharacterOffset: 0) == 1, "offset 0 is line 1")
    expect(index.lineNumber(atCharacterOffset: 2) == 1, "the newline itself belongs to its line")
    expect(index.lineNumber(atCharacterOffset: 3) == 2, "first char after newline is line 2")
    expect(index.lineNumber(atCharacterOffset: 6) == 3, "offset on last line")
}

// MARK: - Incremental edits

// Typing a character (no newline) changes no line numbers but shifts offsets.
do {
    let text = NSMutableString(string: "ab\ncd\nef")
    var index = LineIndex(string: text)
    apply("X", over: NSRange(location: 1, length: 0), to: text, index: &index)
    expect(index.lineCount == 3, "plain insert keeps line count")
    expect(index.lineNumber(atCharacterOffset: 4) == 2, "offsets after insert shifted")
}

// Pressing Return inserts a line.
do {
    let text = NSMutableString(string: "ab\ncd")
    var index = LineIndex(string: text)
    apply("\n", over: NSRange(location: 4, length: 0), to: text, index: &index)
    expect(index.lineCount == 3, "inserted newline adds a line")
    expect(index.newlineOffsets == [2, 4], "inserted newline lands at the right offset")
}

// Deleting a newline joins two lines.
do {
    let text = NSMutableString(string: "ab\ncd\nef")
    var index = LineIndex(string: text)
    apply("", over: NSRange(location: 2, length: 1), to: text, index: &index)
    expect(index.lineCount == 2, "deleted newline removes a line")
    expect(index.newlineOffsets == [4], "remaining newline offset shifted")
}

// Replacing a span that contains newlines with a different number of them.
do {
    let text = NSMutableString(string: "1\n2\n3\n4")
    var index = LineIndex(string: text)
    apply("X\nY", over: NSRange(location: 1, length: 4), to: text, index: &index)
    expect(text as String == "1X\nY\n4", "replacement applied as expected")
    expect(index.lineCount == 3, "replacement collapsed two newlines into one")
    expect(index.newlineOffsets == [2, 4], "replacement offsets correct")
}

// Paste of a multi-line block at the very start and very end.
do {
    let text = NSMutableString(string: "mid")
    var index = LineIndex(string: text)
    apply("a\nb\n", over: NSRange(location: 0, length: 0), to: text, index: &index)
    apply("\nx\ny", over: NSRange(location: text.length, length: 0), to: text, index: &index)
    expect(text as String == "a\nb\nmid\nx\ny", "edge pastes applied")
    expect(index.newlineOffsets == [1, 3, 7, 9], "edge paste offsets correct")
}

// Wholesale replacement (Select All + paste).
do {
    let text = NSMutableString(string: "a\nb\nc")
    var index = LineIndex(string: text)
    apply("one\ntwo", over: NSRange(location: 0, length: text.length), to: text, index: &index)
    expect(index.lineCount == 2, "full replacement recounts lines")
    expect(index.newlineOffsets == [3], "full replacement offsets correct")
}

// MARK: - Fuzz: incremental result must equal a fresh full scan

do {
    var seed: UInt64 = 0x71DE
    func rand(_ n: Int) -> Int {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Int((seed >> 33) % UInt64(max(n, 1)))
    }
    let pieces = ["", "x", "\n", "ab\ncd", "\n\n", "word ", "한글\n줄", "🌊\n"]
    let text = NSMutableString(string: "start\nmiddle\nend")
    var index = LineIndex(string: text)
    var diverged = false
    for _ in 0..<500 {
        let location = rand(text.length + 1)
        let length = rand(min(6, text.length - location + 1))
        // NSRange must not split a surrogate pair; snap to composed bounds.
        let range = (text as NSString).rangeOfComposedCharacterSequences(
            for: NSRange(location: location, length: length)
        )
        apply(pieces[rand(pieces.count)], over: range, to: text, index: &index)
        if index.newlineOffsets != LineIndex(string: text).newlineOffsets {
            diverged = true
            break
        }
    }
    expect(!diverged, "fuzz: 500 random edits stay identical to a full rescan")
}

// MARK: - Performance: editing must not rescan the whole document

do {
    // ~4 MB document, ~100k lines.
    let line = String(repeating: "x", count: 40) + "\n"
    let text = NSMutableString(string: String(repeating: line, count: 100_000))
    var index = LineIndex(string: text)
    var seed: UInt64 = 0xBEEF
    func rand(_ n: Int) -> Int {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Int((seed >> 33) % UInt64(max(n, 1)))
    }
    let start = Date()
    for i in 0..<1000 {
        let location = rand(text.length)
        apply(i % 5 == 0 ? "\n" : "y", over: NSRange(location: location, length: 0), to: text, index: &index)
    }
    let elapsed = Date().timeIntervalSince(start)
    // A full O(n) rescan per edit takes multiple seconds here; the
    // incremental index should stay well under this generous bound.
    expect(elapsed < 2.0, "1000 edits on a 4 MB / 100k-line document in \(String(format: "%.2f", elapsed))s (< 2s)")
    expect(index.newlineOffsets.count == LineIndex(string: text).newlineOffsets.count,
           "index still consistent after the perf run")
}

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
