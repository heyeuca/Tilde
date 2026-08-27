//
//  LineIndex.swift
//  Tilde
//

import Foundation

/// Incremental newline index for the line-number gutter.
///
/// The gutter needs two things — the total line count (gutter width) and
/// the line number at a character offset (first visible label). Rescanning
/// the whole document for either is O(n) per keystroke, which fights the
/// large-file typing target (PRODUCT.md §28), so this index keeps the
/// sorted UTF-16 offsets of every newline and updates them from the edit
/// deltas `NSTextStorage` reports: an edit removes the offsets that fell in
/// the replaced range (known without the old text — the stored offsets ARE
/// the old coordinates), shifts the tail, and inserts the newlines found in
/// the new text's edited range only.
struct LineIndex {
    /// Sorted UTF-16 offsets of each `\n` in the text.
    private(set) var newlineOffsets: [Int]

    var lineCount: Int { newlineOffsets.count + 1 }

    init(string: NSString) {
        newlineOffsets = Self.newlineOffsets(in: string, range: NSRange(location: 0, length: string.length))
    }

    /// 1-based line number of the character at `offset` — one more than the
    /// count of newlines strictly before it. O(log lines).
    func lineNumber(atCharacterOffset offset: Int) -> Int {
        countOfOffsets(before: offset) + 1
    }

    /// Applies one text edit, as reported by
    /// `NSTextStorage.didProcessEditingNotification`: `editedRange` is the
    /// replacement's range in the NEW text and `delta` the length change,
    /// so the replaced OLD range is `editedRange` widened by `-delta`.
    mutating func applyEdit(editedRange: NSRange, changeInLength delta: Int, in string: NSString) {
        let oldLength = editedRange.length - delta
        let oldRange = NSRange(location: editedRange.location, length: max(0, oldLength))

        let replaceStart = countOfOffsets(before: oldRange.location)
        let replaceEnd = countOfOffsets(before: oldRange.location + oldRange.length)

        let inserted = Self.newlineOffsets(in: string, range: editedRange)
        // Everything after the edit shifts by the length change; do it on
        // the tail once, then splice in the new offsets (already absolute).
        if delta != 0 {
            for index in replaceEnd..<newlineOffsets.count {
                newlineOffsets[index] += delta
            }
        }
        if inserted.isEmpty, replaceStart == replaceEnd { return }
        newlineOffsets.replaceSubrange(replaceStart..<replaceEnd, with: inserted)
    }

    /// Count of stored newline offsets strictly less than `offset`
    /// (binary search for the lower bound).
    private func countOfOffsets(before offset: Int) -> Int {
        var low = 0
        var high = newlineOffsets.count
        while low < high {
            let mid = (low + high) / 2
            if newlineOffsets[mid] < offset { low = mid + 1 } else { high = mid }
        }
        return low
    }

    private static func newlineOffsets(in string: NSString, range: NSRange) -> [Int] {
        var offsets: [Int] = []
        var location = range.location
        let end = range.location + range.length
        while location < end {
            let found = string.range(of: "\n", range: NSRange(location: location, length: end - location))
            guard found.location != NSNotFound else { break }
            offsets.append(found.location)
            location = found.location + 1
        }
        return offsets
    }
}
