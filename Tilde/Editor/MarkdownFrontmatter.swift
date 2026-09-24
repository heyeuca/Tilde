//
//  MarkdownFrontmatter.swift
//  Tilde
//

import Foundation

/// Detects the leading YAML frontmatter block (Jekyll / Hugo / Obsidian):
/// line 1 is `---`, closed by the next line that is `---` or `...`, and the
/// lines between are empty or include at least one top-level `key:` line.
///
/// Detection never parses YAML; the `key:` check only keeps a document that
/// opens with a `---` rule and has another rule further down from losing
/// everything in between. Anything that fails a check stays ordinary
/// Markdown. Fence lines may carry trailing spaces or tabs (and a `\r`, for
/// text that was not LF-normalized). `entries(in:block:)` reads the simple
/// top-level keys for Reader's metadata header.
nonisolated enum MarkdownFrontmatter {

    /// The whole block, from offset 0 through the closing fence line
    /// (including its newline), or nil when the text has no frontmatter.
    static func range(in string: NSString) -> NSRange? {
        candidate(in: string).flatMap { isMetadata($0, in: string) ? $0 : nil }
    }

    /// Line 1 through the first closing fence, before the `key:` check.
    static func candidate(in string: NSString) -> NSRange? {
        guard let opening = openingLine(in: string) else { return nil }
        let rest = NSRange(location: NSMaxRange(opening), length: string.length - NSMaxRange(opening))
        return closingLine(in: string, within: rest).map { NSRange(location: 0, length: NSMaxRange($0)) }
    }

    /// Whether the lines between a candidate's fences read as metadata:
    /// all blank, or at least one top-level `key:` line.
    static func isMetadata(_ candidate: NSRange, in string: NSString) -> Bool {
        let body = interior(of: candidate, in: string)
        if string.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: [], range: body).location == NSNotFound {
            return true
        }
        return keyLine.firstMatch(in: string as String, range: body) != nil
    }

    /// The lines between a block's two fences.
    private static func interior(of block: NSRange, in string: NSString) -> NSRange {
        let opening = string.lineRange(for: NSRange(location: 0, length: 0))
        let closing = string.lineRange(for: NSRange(location: NSMaxRange(block) - 1, length: 0))
        return NSRange(location: NSMaxRange(opening), length: max(0, closing.location - NSMaxRange(opening)))
    }

    /// A top-level YAML `key:` — plain or quoted, at column 0, followed by
    /// a space or the end of the line. Headings and ordinary sentences never
    /// match; a prose line such as `Note: …` does, which is the accepted
    /// cost of a check that stops short of parsing YAML.
    private static let keyLine = try! NSRegularExpression(
        pattern: "^(?:[\\w.$-]+|\"[^\"\r\n]*\"|'[^'\r\n]*')[ \t]*:(?:[ \t\r]|$)",
        options: .anchorsMatchLines
    )

    /// Line 1, when it is a `---` fence followed by at least one more line.
    static func openingLine(in string: NSString) -> NSRange? {
        // Cheap reject before lineRange: a document starting with `-` (a
        // list, say) would otherwise scan its whole first line per keystroke.
        guard string.length > 3,
              string.character(at: 0) == dash,
              string.character(at: 1) == dash,
              string.character(at: 2) == dash
        else { return nil }
        let line = string.lineRange(for: NSRange(location: 0, length: 0))
        guard NSMaxRange(line) < string.length, isFence(line, in: string, marker: dash)
        else { return nil }
        return line
    }

    /// The first `---` or `...` fence line starting within `range`.
    static func closingLine(in string: NSString, within range: NSRange) -> NSRange? {
        var location = range.location
        let end = NSMaxRange(range)
        while location < end {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            let first = string.character(at: line.location)
            if first == dash || first == dot, isFence(line, in: string, marker: first) {
                return line
            }
            guard NSMaxRange(line) > location else { break }
            location = NSMaxRange(line)
        }
        return nil
    }

    private static let dash = unichar(UInt8(ascii: "-"))
    private static let dot = unichar(UInt8(ascii: "."))

    /// Exactly three `marker` characters, then only trailing whitespace.
    private static func isFence(_ line: NSRange, in string: NSString, marker: unichar) -> Bool {
        guard line.length >= 3 else { return false }
        for offset in 0..<3 where string.character(at: line.location + offset) != marker {
            return false
        }
        for offset in 3..<line.length {
            switch string.character(at: line.location + offset) {
            case 0x20, 0x09, 0x0D, 0x0A: continue
            default: return false
            }
        }
        return true
    }
}

// MARK: - Entries (Reader's metadata header)

// nonisolated like the enum itself: Reader renders large documents off the
// main thread, and extension members don't inherit the type's isolation.
nonisolated extension MarkdownFrontmatter {

    /// One top-level key and its value, flattened for display.
    struct Entry: Equatable {
        var key: String
        var value: String
        /// The value as written (dedented), because this reader can't
        /// flatten it: a nested mapping, flow mapping, anchor, alias, tag,
        /// or a multi-line quoted or flow value.
        var isRaw = false
    }

    /// The block's top-level `key: value` pairs, in order, for Reader's
    /// metadata header. Values are flattened for display: scalars as
    /// written (quotes removed), lists — flow `[a, b]` or block `- a` —
    /// joined with ", ", and `|` / `>` block scalars as their text. Keys
    /// with no value are left out.
    ///
    /// Still not a YAML parser: a value it can't flatten comes back as
    /// written, marked `isRaw`, so one unusual key never costs the others
    /// their rows. nil only when a line belongs to no key at all.
    static func entries(in string: NSString, block: NSRange) -> [Entry]? {
        let lines = string.substring(with: interior(of: block, in: string))
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }

        var entries: [Entry] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            if isBlank(line) || line.hasPrefix("#") { continue }
            guard let (key, rest) = splitKey(line) else { return nil }
            // Indented lines belong to the key's value, and so do `- `
            // items, which YAML also allows at the key's own column.
            var nested: [String] = []
            while index < lines.count {
                let next = lines[index]
                guard isBlank(next) || indentation(of: next) > 0 || isSequenceItem(next) else { break }
                nested.append(next)
                index += 1
            }
            if let value = value(rest, nested: nested) {
                if !value.isEmpty { entries.append(Entry(key: key, value: value)) }
            } else {
                entries.append(Entry(key: key, value: raw(rest, nested: nested), isRaw: true))
            }
        }
        return entries
    }

    /// A value exactly as written: the rest of the key's line, then the
    /// lines under it with their common indentation removed.
    private static func raw(_ rest: String, nested: [String]) -> String {
        let indent = nested.filter { !isBlank($0) }.map(indentation(of:)).min() ?? 0
        var lines = (rest.isEmpty ? [] : [rest]) + nested.map { isBlank($0) ? "" : String($0.dropFirst(indent)) }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// `key: rest` at column 0, the key plain or quoted.
    private static func splitKey(_ line: String) -> (key: String, rest: String)? {
        guard let first = line.first, !first.isWhitespace, !isSequenceItem(line) else { return nil }
        let key: String
        let colon: String.Index
        if first == "\"" || first == "'" {
            let open = line.index(after: line.startIndex)
            guard let close = line[open...].firstIndex(of: first) else { return nil }
            key = String(line[open..<close])
            guard let found = line[line.index(after: close)...].firstIndex(where: { $0 != " " && $0 != "\t" }),
                  line[found] == ":"
            else { return nil }
            colon = found
        } else {
            guard !"[]{}&*!|>%@`#,?".contains(first) else { return nil }
            // The first `:` that ends the line or is followed by a space.
            var search = line.startIndex
            var found: String.Index?
            while let candidate = line[search...].firstIndex(of: ":") {
                let next = line.index(after: candidate)
                if next == line.endIndex || line[next] == " " || line[next] == "\t" {
                    found = candidate
                    break
                }
                search = next
            }
            guard let found else { return nil }
            key = line[..<found].trimmingCharacters(in: .whitespaces)
            colon = found
        }
        guard !key.isEmpty else { return nil }
        return (key, line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
    }

    /// The display value for a key whose line ends in `rest`, followed by
    /// the `nested` lines under it.
    private static func value(_ rest: String, nested: [String]) -> String? {
        let content = nested.filter { !isBlank($0) && !isComment($0) }
        switch rest.first {
        case nil:
            return valueBelowKey(content)
        case "|", ">":
            return blockScalar(header: rest, lines: nested)
        case "[":
            return content.isEmpty ? flowSequence(rest) : nil
        case "\"", "'":
            return content.isEmpty ? quotedScalar(rest) : nil
        case "{", "&", "*", "!":
            return nil
        default:
            // A plain scalar may run on over more-indented lines, which
            // YAML folds with spaces.
            guard content.allSatisfy({ indentation(of: $0) > 0 }) else { return nil }
            return ([stripComment(rest)] + content.map { $0.trimmingCharacters(in: .whitespaces) })
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    /// A key with nothing after its colon: a block list, a plain scalar
    /// that starts on the next line, or no value at all.
    private static func valueBelowKey(_ content: [String]) -> String? {
        guard let first = content.first else { return "" }
        if content.allSatisfy(isSequenceItem) {
            // One flat list; deeper `- ` lines would be nested lists.
            let indent = indentation(of: first)
            guard content.allSatisfy({ indentation(of: $0) == indent }) else { return nil }
            var items: [String] = []
            for line in content {
                guard let item = listItem(String(line.dropFirst(indent + 1))) else { return nil }
                if !item.isEmpty { items.append(item) }
            }
            return items.joined(separator: ", ")
        }
        let isFoldedText = content.allSatisfy {
            indentation(of: $0) > 0 && !isSequenceItem($0)
                && splitKey($0.trimmingCharacters(in: .whitespaces)) == nil
        }
        // Anything else under a bare key is a nested mapping (or a mix).
        guard isFoldedText else { return nil }
        return content.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    /// One list item's text; nil when the item is itself structured
    /// (`- key: value`, `- [a]`, an anchor, …).
    private static func listItem(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        switch text.first {
        case nil: return ""
        case "\"", "'": return quotedScalar(text)
        case "[", "{", "&", "*", "!", "|", ">": return nil
        default:
            let plain = stripComment(text)
            return splitKey(plain) == nil ? plain : nil
        }
    }

    /// `[a, "b, c", 'd']` on one line; nested collections are not handled.
    private static func flowSequence(_ text: String) -> String? {
        guard let close = text.lastIndex(of: "]"),
              isBlankOrComment(text[text.index(after: close)...])
        else { return nil }
        var items: [String] = []
        var current = ""
        var quote: Character?
        for character in text[text.index(after: text.startIndex)..<close] {
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "[" || character == "{" {
                return nil
            } else if character == "," {
                items.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        guard quote == nil else { return nil }
        items.append(current)
        var values: [String] = []
        for item in items {
            guard let value = listItem(item) else { return nil }
            if !value.isEmpty { values.append(value) }
        }
        return values.joined(separator: ", ")
    }

    /// A quoted scalar that closes on its own line, unescaped; nil for an
    /// unclosed (multi-line) one.
    private static func quotedScalar(_ text: String) -> String? {
        guard let quote = text.first else { return nil }
        var result = ""
        func closed(after end: String.Index) -> String? {
            isBlankOrComment(text[end...]) ? result : nil
        }
        var index = text.index(after: text.startIndex)
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if quote == "'", character == "'" {
                // `''` is an escaped quote; a lone `'` closes.
                guard next < text.endIndex, text[next] == "'" else { return closed(after: next) }
                result.append("'")
                index = text.index(after: next)
                continue
            }
            if quote == "\"", character == "\"" { return closed(after: next) }
            if quote == "\"", character == "\\", next < text.endIndex {
                switch text[next] {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "\"", "\\", "/": result.append(text[next])
                default: result.append(character); result.append(text[next])
                }
                index = text.index(after: next)
                continue
            }
            result.append(character)
            index = next
        }
        return nil
    }

    /// `|` keeps its line breaks; `>` folds lines into paragraphs. Chomping
    /// and indentation indicators are accepted and otherwise ignored.
    private static func blockScalar(header: String, lines: [String]) -> String? {
        let folded = header.first == ">"
        guard isBlankOrComment(header.dropFirst().drop { "+-123456789".contains($0) }) else { return nil }
        guard let indent = lines.filter({ !isBlank($0) }).map(indentation(of:)).min() else { return "" }
        guard indent > 0 else { return nil }
        let text = lines.map { isBlank($0) ? "" : String($0.dropFirst(indent)) }
        guard folded else {
            return text.joined(separator: "\n").trimmingCharacters(in: .newlines)
        }
        // Lines join with spaces; a blank line starts a new paragraph.
        var paragraphs: [String] = []
        var current: [String] = []
        for line in text + [""] {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
                current = []
            } else {
                current.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        return paragraphs.joined(separator: "\n")
    }

    /// `text` with a trailing ` # comment` removed.
    private static func stripComment(_ text: String) -> String {
        var previous: Character = " "
        for index in text.indices {
            if text[index] == "#", previous == " " || previous == "\t" {
                return text[..<index].trimmingCharacters(in: .whitespaces)
            }
            previous = text[index]
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func isBlank<S: StringProtocol>(_ text: S) -> Bool {
        text.allSatisfy { $0 == " " || $0 == "\t" || $0 == "\r" }
    }

    private static func isBlankOrComment<S: StringProtocol>(_ text: S) -> Bool {
        let trimmed = text.drop { $0 == " " || $0 == "\t" }
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    private static func isComment(_ line: String) -> Bool {
        line.drop { $0 == " " || $0 == "\t" }.hasPrefix("#")
    }

    private static func isSequenceItem(_ line: String) -> Bool {
        let body = line.drop { $0 == " " }
        return body == "-" || body.hasPrefix("- ") || body.hasPrefix("-\t")
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.count
    }
}
