//
//  CodeSyntaxStyler.swift
//  Tilde
//

import AppKit

/// A text-storage delegate that keeps an editor's buffer styled.
/// Both the Markdown styler and the code highlighter conform, so the
/// editor can hold whichever fits the document.
///
/// Conformers write `@MainActor SyntaxHighlighting`: stylers mutate the
/// editor's live `NSTextStorage` from delegate callbacks AppKit delivers on
/// the main thread, so their `NSTextStorageDelegate` conformance is
/// main-actor-isolated, and Swift 6 requires this inheriting conformance
/// to say the same.
protocol SyntaxHighlighting: NSTextStorageDelegate {
    var fontSize: CGFloat { get set }
    func restyleAll(_ textStorage: NSTextStorage)
}

/// Very light JSON / YAML highlighting: only keys are tinted (and YAML
/// comments dimmed). Everything else keeps the default text color, so the
/// result stays quiet and never approaches IDE-level coloring
/// (PRODUCT.md §33.2).
///
/// Styling is attribute-only and per-line — JSON/YAML tokens don't span
/// lines in this lightweight model — so edits restyle just their own
/// paragraphs.
final class CodeSyntaxStyler: NSObject, @MainActor SyntaxHighlighting {
    enum Language: Equatable {
        case json
        case yaml
        case toml
    }

    var fontSize: CGFloat = EditorTheme.defaultFontSize
    var language: Language = .json

    // MARK: - NSTextStorageDelegate

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        let paragraph = (textStorage.string as NSString).paragraphRange(for: editedRange)
        applyStyles(in: paragraph, to: textStorage)
    }

    // MARK: - Styling

    func restyleAll(_ textStorage: NSTextStorage) {
        applyStyles(in: NSRange(location: 0, length: textStorage.length), to: textStorage)
    }

    private func applyStyles(in range: NSRange, to textStorage: NSTextStorage) {
        let string = textStorage.string as NSString
        guard string.length > 0 else { return }

        let body = EditorTheme.bodyAttributes(monospaced: true, size: fontSize)
        textStorage.setAttributes(body, range: range)

        let bodyFont = EditorTheme.bodyFont(monospaced: true, size: fontSize)
        let emptyLineStyle = EditorTheme.emptyLineParagraphStyle(for: bodyFont)

        var location = range.location
        let end = NSMaxRange(range)
        while location < end {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            styleLine(line, string: string, storage: textStorage, emptyLineStyle: emptyLineStyle)
            guard NSMaxRange(line) > location else { break }
            location = NSMaxRange(line)
        }
    }

    private func styleLine(
        _ line: NSRange,
        string: NSString,
        storage: NSTextStorage,
        emptyLineStyle: NSParagraphStyle
    ) {
        let text = string.substring(with: line)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            storage.addAttribute(.paragraphStyle, value: emptyLineStyle, range: line)
            return
        }
        func absolute(_ range: NSRange) -> NSRange {
            NSRange(location: line.location + range.location, length: range.length)
        }
        let full = NSRange(location: 0, length: (text as NSString).length)

        switch language {
        case .json:
            for match in Self.jsonKey.matches(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntaxKeyColor, range: absolute(match.range(at: 1)))
            }
        case .yaml:
            // A `#` comment (whole-line or trailing) recedes.
            if let comment = Self.hashComment.firstMatch(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntaxCommentColor, range: absolute(comment.range(at: 1)))
            }
            if let key = Self.yamlKey.firstMatch(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntaxKeyColor, range: absolute(key.range(at: 1)))
            }
        case .toml:
            if let comment = Self.hashComment.firstMatch(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntaxCommentColor, range: absolute(comment.range(at: 1)))
            }
            // A `[table]` / `[[array]]` header, or a `key =` assignment.
            if let table = Self.tomlTable.firstMatch(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntaxKeyColor, range: absolute(table.range(at: 1)))
            } else if let key = Self.tomlKey.firstMatch(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntaxKeyColor, range: absolute(key.range(at: 1)))
            }
        }
    }

    // MARK: - Patterns

    /// A JSON key: a `"…"` string that is immediately followed by a colon.
    private static let jsonKey = try! NSRegularExpression(pattern: "(\"(?:[^\"\\\\]|\\\\.)*\")\\s*:")

    /// A YAML key: the first token before a colon on a line, after optional
    /// indentation and an optional `- ` sequence marker.
    private static let yamlKey = try! NSRegularExpression(pattern: "^[ \\t]*(?:-[ \\t]+)?([\\w.$-]+)[ \\t]*:(?:[ \\t]|$)")

    /// A `#` comment (YAML and TOML): preceded by start-of-line or
    /// whitespace, to end of line.
    private static let hashComment = try! NSRegularExpression(pattern: "(?:^|[ \\t])(#.*)$")

    /// A TOML `[table]` or `[[array-of-tables]]` header.
    private static let tomlTable = try! NSRegularExpression(pattern: "^[ \\t]*(\\[\\[?[^\\]\\n]+\\]\\]?)")

    /// A TOML `key =` assignment: bare, dotted, or quoted key before `=`.
    private static let tomlKey = try! NSRegularExpression(pattern: "^[ \\t]*(\"(?:[^\"\\\\]|\\\\.)*\"|'[^'\\n]*'|[\\w.$-]+)[ \\t]*=")
}
