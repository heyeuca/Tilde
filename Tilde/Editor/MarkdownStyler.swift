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
/// On each edit only the touched paragraphs are restyled. Fenced code blocks
/// are the one piece of cross-line state: fence lines are located with a fast
/// substring search, and when the number of fences changes the whole document
/// is restyled once.
final class MarkdownStyler: NSObject, NSTextStorageDelegate {

    /// Current body font size; heading/code sizes derive from it.
    var fontSize: CGFloat = EditorTheme.defaultFontSize

    /// Signature of the last-seen fence structure. When it changes, a fence
    /// was opened or closed and everything after it may flip meaning.
    private var fenceCount = -1

    // MARK: - NSTextStorageDelegate

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        // Attribute-only edits are our own styling; only react to characters.
        guard editedMask.contains(.editedCharacters) else { return }
        restyle(around: editedRange, in: textStorage)
    }

    // MARK: - Styling entry points

    func restyleAll(_ textStorage: NSTextStorage) {
        fenceCount = -1
        restyle(around: NSRange(location: 0, length: textStorage.length), in: textStorage)
    }

    private func restyle(around editedRange: NSRange, in textStorage: NSTextStorage) {
        let string = textStorage.string as NSString
        guard string.length > 0 else { return }

        let fences = Self.fenceLines(in: string)
        let regions = Self.fenceRegions(fences: fences, totalLength: string.length)

        var styleRange = string.paragraphRange(for: editedRange)
        if fences.count != fenceCount {
            // Fence opened/closed: restyle everything once.
            fenceCount = fences.count
            styleRange = NSRange(location: 0, length: string.length)
        } else {
            // Edits inside a fence restyle the whole fenced region.
            for region in regions where NSIntersectionRange(region, styleRange).length > 0 {
                styleRange = NSUnionRange(styleRange, region)
            }
        }
        guard styleRange.length > 0 else { return }

        textStorage.setAttributes(EditorTheme.bodyAttributes(monospaced: false, size: fontSize), range: styleRange)
        var location = styleRange.location
        let end = NSMaxRange(styleRange)
        while location < end {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            styleLine(line, string: string, fenceRegions: regions, in: textStorage)
            guard NSMaxRange(line) > location else { break }
            location = NSMaxRange(line)
        }
    }

    // MARK: - Fences

    /// Ranges of lines that start a ``` fence marker.
    static func fenceLines(in string: NSString) -> [NSRange] {
        var lines: [NSRange] = []
        var location = 0
        while location < string.length {
            let found = string.range(
                of: "```",
                range: NSRange(location: location, length: string.length - location)
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

    // MARK: - Line rules

    private static let headingPattern = try! NSRegularExpression(pattern: "^(#{1,6})[ \\t]")
    private static let hrPattern = try! NSRegularExpression(pattern: "^ {0,3}(?:-{3,}|\\*{3,}|_{3,})[ \\t]*\\n?$")
    private static let quotePattern = try! NSRegularExpression(pattern: "^ {0,3}((?:>[ ]?)+)")
    private static let listPattern = try! NSRegularExpression(pattern: "^[ \\t]*([-*+]|\\d{1,9}[.)])[ \\t]+")

    private func styleLine(
        _ line: NSRange,
        string: NSString,
        fenceRegions: [NSRange],
        in storage: NSTextStorage
    ) {
        // Code block interior and fence marker lines.
        if fenceRegions.contains(where: { NSLocationInRange(line.location, $0) }) {
            storage.addAttributes([
                .font: EditorTheme.codeFont(size: fontSize),
                .backgroundColor: EditorTheme.codeBackgroundColor,
            ], range: line)
            if string.substring(with: line).hasPrefix("```") {
                storage.addAttribute(.foregroundColor, value: EditorTheme.markerColor, range: line)
            }
            return
        }

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

        var contentStart = 0

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

        let content = NSRange(location: contentStart, length: fullLine.length - contentStart)
        styleInline(in: lineText, range: content, lineLocation: line.location, storage: storage)
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
