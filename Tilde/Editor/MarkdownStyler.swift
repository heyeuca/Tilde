//
//  MarkdownStyler.swift
//  Tilde
//

import AppKit

/// Lightweight, attribute-only Markdown styling.
///
/// The buffer's characters are never modified — syntax markers stay visible
/// and recede visually. Styling is line-based with a small set of inline
/// rules; it is deliberately not a full Markdown parser (PRODUCT.md §27).
///
/// Performance model (PRODUCT.md §28): on each edit only the touched
/// paragraphs are restyled. Fenced code blocks are the one piece of
/// cross-line state; fence-line positions are cached and updated
/// incrementally (shift by the edit delta, rescan only the edited
/// paragraphs), so a keystroke never scans the whole document.
final class MarkdownStyler: NSObject, NSTextStorageDelegate {

    /// Current body font size; heading/code sizes derive from it.
    var fontSize: CGFloat = EditorTheme.defaultFontSize

    /// Sorted ranges of ``` fence-marker lines, kept in sync across edits.
    private var fenceCache: [NSRange]?
    private var cachedLength = 0

    // MARK: - NSTextStorageDelegate

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        // Attribute-only edits are our own styling; only react to characters.
        guard editedMask.contains(.editedCharacters) else { return }
        restyle(in: textStorage, editedRange: editedRange, delta: delta)
    }

    // MARK: - Styling entry points

    func restyleAll(_ textStorage: NSTextStorage) {
        fenceCache = nil
        restyle(in: textStorage, editedRange: nil, delta: 0)
    }

    private func restyle(in textStorage: NSTextStorage, editedRange: NSRange?, delta: Int) {
        // mutableString is the backing store — no bridging copy per edit.
        let string: NSString = textStorage.mutableString
        guard string.length > 0 else {
            fenceCache = []
            cachedLength = 0
            return
        }

        // Splitting a line (typing a newline) leaves the tail in a NEW
        // paragraph that paragraphRange(for: editedRange) would miss:
        // probe one character past the edit so that paragraph is included.
        var window: NSRange?
        if let editedRange {
            var probe = editedRange
            if NSMaxRange(probe) < string.length { probe.length += 1 }
            window = string.paragraphRange(for: probe)
        }

        let previousFenceCount = fenceCache?.count
        let fences = updatedFenceLines(string: string, window: window, delta: delta)
        let regions = Self.fenceRegions(fences: fences, totalLength: string.length)

        var styleRange: NSRange
        if let window, previousFenceCount == fences.count {
            styleRange = window
            // Edits inside a fence restyle the whole fenced region.
            for region in regions where NSIntersectionRange(region, styleRange).length > 0 {
                styleRange = NSUnionRange(styleRange, region)
            }
        } else {
            // Fence opened/closed (or first pass): everything after the
            // change can flip meaning, so restyle the document once.
            styleRange = NSRange(location: 0, length: string.length)
        }
        guard styleRange.length > 0 else { return }

        // Outside of an edit cycle (initial full pass), batch the thousands
        // of attribute changes into one layout invalidation. Inside
        // didProcessEditing the range is small and nesting begin/endEditing
        // there is not allowed.
        let batch = editedRange == nil
        if batch { textStorage.beginEditing() }
        applyStyles(in: styleRange, string: string, regions: regions, to: textStorage)
        if batch { textStorage.endEditing() }
    }

    // MARK: - Fences

    /// Brings the fence-line cache up to date for the given edit.
    ///
    /// Cached lines strictly before the edited paragraphs keep their
    /// positions, lines after shift by `delta`, and the edited paragraphs
    /// themselves are rescanned locally.
    private func updatedFenceLines(string: NSString, window: NSRange?, delta: Int) -> [NSRange] {
        guard
            let cache = fenceCache,
            let window,
            cachedLength + delta == string.length
        else {
            let scanned = Self.scanFenceLines(in: string, within: NSRange(location: 0, length: string.length))
            fenceCache = scanned
            cachedLength = string.length
            return scanned
        }

        let preEditWindowEnd = NSMaxRange(window) - delta

        var updated: [NSRange] = []
        updated.reserveCapacity(cache.count + 2)
        var insertIndex: Int?
        for fence in cache {
            if NSMaxRange(fence) <= window.location {
                updated.append(fence)
            } else if fence.location >= preEditWindowEnd {
                if insertIndex == nil { insertIndex = updated.count }
                updated.append(NSRange(location: fence.location + delta, length: fence.length))
            }
            // Fences inside the pre-edit window are dropped and rescanned.
        }
        updated.insert(
            contentsOf: Self.scanFenceLines(in: string, within: window),
            at: insertIndex ?? updated.count
        )

        fenceCache = updated
        cachedLength = string.length
        return updated
    }

    /// Ranges of lines within `range` that start with a ``` fence marker.
    static func scanFenceLines(in string: NSString, within range: NSRange) -> [NSRange] {
        var lines: [NSRange] = []
        var location = range.location
        let end = NSMaxRange(range)
        while location < end {
            let found = string.range(
                of: "```",
                range: NSRange(location: location, length: end - location)
            )
            guard found.location != NSNotFound else { break }
            let line = string.lineRange(for: found)
            if found.location == line.location {
                lines.append(line)
            }
            location = max(NSMaxRange(line), found.location + 3)
        }
        return lines
    }

    /// Pairs fence lines into fenced regions. An unclosed fence runs to EOF.
    static func fenceRegions(fences: [NSRange], totalLength: Int) -> [NSRange] {
        var regions: [NSRange] = []
        var index = 0
        while index < fences.count {
            let open = fences[index]
            if index + 1 < fences.count {
                let close = fences[index + 1]
                regions.append(NSRange(location: open.location, length: NSMaxRange(close) - open.location))
                index += 2
            } else {
                regions.append(NSRange(location: open.location, length: totalLength - open.location))
                index += 1
            }
        }
        return regions
    }

    // MARK: - Line walk

    private func applyStyles(in range: NSRange, string: NSString, regions: [NSRange], to storage: NSTextStorage) {
        storage.setAttributes(EditorTheme.bodyAttributes(monospaced: false, size: fontSize), range: range)

        // Regions and lines are both sorted: walk them together instead of
        // searching the region list for every line.
        var regionIndex = 0
        var location = range.location
        let end = NSMaxRange(range)
        while location < end {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            while regionIndex < regions.count, NSMaxRange(regions[regionIndex]) <= line.location {
                regionIndex += 1
            }
            let insideFence = regionIndex < regions.count
                && NSLocationInRange(line.location, regions[regionIndex])
            styleLine(line, string: string, insideFence: insideFence, in: storage)
            guard NSMaxRange(line) > location else { break }
            location = NSMaxRange(line)
        }
    }

    // MARK: - Line rules

    private static let headingPattern = try! NSRegularExpression(pattern: "^(#{1,6})[ \\t]")
    private static let hrPattern = try! NSRegularExpression(pattern: "^ {0,3}(?:-{3,}|\\*{3,}|_{3,})[ \\t]*\\n?$")
    private static let quotePattern = try! NSRegularExpression(pattern: "^ {0,3}((?:>[ ]?)+)")
    private static let listPattern = try! NSRegularExpression(pattern: "^[ \\t]*([-*+]|\\d{1,9}[.)])[ \\t]+")

    /// First UTF-16 units that can begin a line-level construct.
    private static let lineTriggers: Set<unichar> = {
        var set = Set("#>-*+_ \t".utf16)
        set.formUnion("0123456789".utf16)
        return set
    }()

    /// Characters that can begin an inline construct.
    private static let inlineTriggers = CharacterSet(charactersIn: "*_~`[!")

    private func styleLine(
        _ line: NSRange,
        string: NSString,
        insideFence: Bool,
        in storage: NSTextStorage
    ) {
        // Code block interior and fence marker lines.
        if insideFence {
            storage.addAttributes([
                .font: EditorTheme.codeFont(size: fontSize),
                .backgroundColor: EditorTheme.codeBackgroundColor,
            ], range: line)
            if string.range(of: "```", options: .anchored, range: line).location != NSNotFound {
                storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: line)
            }
            return
        }

        var contentStart = 0

        if Self.lineTriggers.contains(string.character(at: line.location)) {
            let lineText = string.substring(with: line)
            let fullLine = NSRange(location: 0, length: (lineText as NSString).length)
            func absolute(_ range: NSRange) -> NSRange {
                NSRange(location: line.location + range.location, length: range.length)
            }

            // Horizontal rule: the whole line is a marker.
            if Self.hrPattern.firstMatch(in: lineText, range: fullLine) != nil {
                storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: line)
                return
            }

            // Heading: larger bold content, dim `#` marker. No inline rules inside.
            if let match = Self.headingPattern.firstMatch(in: lineText, range: fullLine) {
                let level = match.range(at: 1).length
                storage.addAttribute(.font, value: EditorTheme.headingFont(level: level, size: fontSize), range: line)
                storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: absolute(match.range(at: 1)))
                return
            }

            // Blockquote: dim `>` marker, quiet content.
            if let match = Self.quotePattern.firstMatch(in: lineText, range: fullLine) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.quoteColor, range: line)
                storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: absolute(match.range(at: 1)))
                contentStart = NSMaxRange(match.range)
            }
            // List: slightly emphasized bullet/number.
            else if let match = Self.listPattern.firstMatch(in: lineText, range: fullLine) {
                storage.addAttribute(.font, value: EditorTheme.listMarkerFont(size: fontSize), range: absolute(match.range(at: 1)))
                contentStart = NSMaxRange(match.range)
            }
        }

        // Inline rules only when the line can contain inline syntax at all.
        let contentRange = NSRange(location: line.location + contentStart, length: line.length - contentStart)
        guard contentRange.length > 0,
              string.rangeOfCharacter(from: Self.inlineTriggers, options: [], range: contentRange).location != NSNotFound
        else { return }

        let lineText = string.substring(with: line)
        styleInline(
            in: lineText,
            range: NSRange(location: contentStart, length: (lineText as NSString).length - contentStart),
            lineLocation: line.location,
            storage: storage
        )
    }

    // MARK: - Inline rules

    private static let codeSpanPattern = try! NSRegularExpression(pattern: "`([^`\\n]+)`")
    private static let boldPattern = try! NSRegularExpression(
        pattern: "(\\*\\*|__)(?!\\s)([^\\n]+?)(?<=\\S)\\1"
    )
    private static let strikePattern = try! NSRegularExpression(
        pattern: "~~(?!\\s)([^~\\n]+?)(?<=\\S)~~"
    )
    private static let italicPattern = try! NSRegularExpression(
        pattern: "(?<!\\*)\\*(?![\\s*])([^*\\n]+?)(?<=\\S)\\*(?!\\*)|(?<![\\w_])_(?![\\s_])([^_\\n]+?)(?<=\\S)_(?![\\w_])"
    )
    private static let linkPattern = try! NSRegularExpression(
        pattern: "!?\\[([^\\]\\n]*)\\]\\(([^)\\n]*)\\)"
    )

    private func styleInline(in lineText: String, range: NSRange, lineLocation: Int, storage: NSTextStorage) {
        guard range.length > 0 else { return }
        var consumed: [NSRange] = []

        func isFree(_ range: NSRange) -> Bool {
            !consumed.contains { NSIntersectionRange($0, range).length > 0 }
        }
        func absolute(_ range: NSRange) -> NSRange {
            NSRange(location: lineLocation + range.location, length: range.length)
        }
        func dimMarkers(of match: NSTextCheckingResult, except content: NSRange) {
            let full = match.range
            let before = NSRange(location: full.location, length: content.location - full.location)
            let after = NSRange(location: NSMaxRange(content), length: NSMaxRange(full) - NSMaxRange(content))
            storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: absolute(before))
            storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: absolute(after))
        }

        // Code spans first: their contents are opaque to other inline rules.
        Self.codeSpanPattern.enumerateMatches(in: lineText, range: range) { match, _, _ in
            guard let match, isFree(match.range) else { return }
            let content = match.range(at: 1)
            storage.addAttributes([
                .font: EditorTheme.codeFont(size: fontSize),
                .backgroundColor: EditorTheme.codeBackgroundColor,
            ], range: absolute(content))
            dimMarkers(of: match, except: content)
            consumed.append(match.range)
        }

        // Links: dim brackets and URL, tint the text.
        Self.linkPattern.enumerateMatches(in: lineText, range: range) { match, _, _ in
            guard let match, isFree(match.range) else { return }
            storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: absolute(match.range))
            storage.addAttribute(.foregroundColor, value: EditorTheme.linkColor, range: absolute(match.range(at: 1)))
            consumed.append(match.range)
        }

        Self.boldPattern.enumerateMatches(in: lineText, range: range) { match, _, _ in
            guard let match, isFree(match.range) else { return }
            let content = match.range(at: 2)
            storage.addAttribute(.font, value: EditorTheme.boldBodyFont(size: fontSize), range: absolute(content))
            dimMarkers(of: match, except: content)
            consumed.append(match.range)
        }

        Self.strikePattern.enumerateMatches(in: lineText, range: range) { match, _, _ in
            guard let match, isFree(match.range) else { return }
            let content = match.range(at: 1)
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: absolute(content))
            dimMarkers(of: match, except: content)
            consumed.append(match.range)
        }

        Self.italicPattern.enumerateMatches(in: lineText, range: range) { match, _, _ in
            guard let match, isFree(match.range) else { return }
            let content = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            storage.addAttribute(.font, value: EditorTheme.italicBodyFont(size: fontSize), range: absolute(content))
            dimMarkers(of: match, except: content)
            consumed.append(match.range)
        }
    }
}
